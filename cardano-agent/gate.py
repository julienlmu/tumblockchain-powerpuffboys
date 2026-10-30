"""Pay-on-pass gate: run an app's executor until its work passes or time runs out.

The Cardano side does not know what the work is. An "app" is a JSON config in
apps/ that names an executor command and the job's input schema. The executor
contract:

- stdin: the job input as JSON. env ATTEMPT is the 1-based attempt number.
- stdout: the last non-empty line is a JSON object
    {"passed": bool, "retryable": bool, "summary": str, "evidence": {...}}
  "retryable" defaults to false; "summary" and "evidence" are optional.
- exit code != 0 means a technical error. It counts as not passed but retryable.

agent.py delivers the result (escrow releases) only if the gate passed.
"""
import asyncio
import json
import os
import pathlib
import sys
import time
from dataclasses import dataclass, field

BASE = pathlib.Path(__file__).resolve().parent


class ExecutorError(RuntimeError):
    pass


@dataclass
class Verdict:
    passed: bool
    retryable: bool = False
    summary: str = ""
    evidence: dict = field(default_factory=dict)


@dataclass
class App:
    name: str
    description: str
    executor: list
    input_schema: dict
    timeout_s: int = 300
    retry_interval_s: int = 30
    max_wait_s: int = 0  # 0 = one attempt unless the executor asks to retry before the deadline
    submit_margin_s: int = 300  # stop retrying this long before submitResultTime; keep it > timeout_s


def load_app(path) -> App:
    path = pathlib.Path(path)
    if not path.is_absolute():
        path = BASE / path
    cfg = json.loads(path.read_text())
    retry = cfg.get("retry", {})
    return App(
        name=cfg["name"],
        description=cfg.get("description", ""),
        executor=[sys.executable if a == "{python}" else a for a in cfg["executor"]],
        input_schema=cfg["input_schema"],
        timeout_s=int(cfg.get("timeout_s", 300)),
        retry_interval_s=int(retry.get("interval_s", 30)),
        max_wait_s=int(retry.get("max_wait_s", 0)),
        submit_margin_s=int(cfg.get("submit_margin_s", 300)),
    )


def parse_verdict(stdout: str) -> Verdict:
    lines = [l for l in stdout.splitlines() if l.strip()]
    if not lines:
        raise ExecutorError("executor printed nothing")
    try:
        out = json.loads(lines[-1])
    except json.JSONDecodeError as e:
        raise ExecutorError(f"last stdout line is not JSON: {lines[-1][:200]}") from e
    if not isinstance(out, dict) or not isinstance(out.get("passed"), bool):
        raise ExecutorError('executor output needs a boolean "passed"')
    evidence = out.get("evidence") or {}
    return Verdict(
        passed=out["passed"],
        retryable=bool(out.get("retryable", False)),
        summary=str(out.get("summary", "")),
        evidence=evidence if isinstance(evidence, dict) else {"value": evidence},
    )


async def run_executor(app: App, input_data: dict, attempt: int) -> Verdict:
    proc = await asyncio.create_subprocess_exec(
        *app.executor,
        cwd=BASE,
        env={**os.environ, "ATTEMPT": str(attempt)},
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(proc.communicate(json.dumps(input_data).encode()), timeout=app.timeout_s)
    except asyncio.TimeoutError:
        proc.kill()
        await proc.wait()
        raise ExecutorError(f"executor timed out after {app.timeout_s}s")
    if proc.returncode != 0:
        raise ExecutorError(f"executor exited {proc.returncode}: {stderr.decode()[-1000:]}")
    return parse_verdict(stdout.decode())


def deadline_for(app: App, submit_result_time=None, now=None) -> float:
    """Latest time to start another attempt: max_wait_s from now, capped by Masumi's deadline."""
    now = time.time() if now is None else now
    deadline = now + app.max_wait_s
    if submit_result_time:
        t = float(submit_result_time)
        if t > 1e12:  # Masumi sends unix milliseconds
            t /= 1000
        deadline = min(deadline, t - app.submit_margin_s)
    return deadline


async def run_gate(app: App, input_data: dict, deadline: float, log=print) -> tuple[Verdict, list[Verdict]]:
    """Run attempts until one passes, one is final, or the next would start after the deadline."""
    attempts: list[Verdict] = []
    while True:
        n = len(attempts) + 1
        try:
            verdict = await run_executor(app, input_data, n)
        except ExecutorError as e:
            verdict = Verdict(passed=False, retryable=True, summary=str(e))
        attempts.append(verdict)
        log(f"attempt {n}: passed={verdict.passed} retryable={verdict.retryable} {verdict.summary[:200]}")
        if verdict.passed or not verdict.retryable:
            return verdict, attempts
        if time.time() + app.retry_interval_s > deadline:
            return verdict, attempts
        await asyncio.sleep(app.retry_interval_s)
