"""Agent settings: a demo or prod profile, overridden by environment variables.

Values come from the environment, then from api3/agent/.env (which never
overrides what is already set). See docs/SUPPLIERPULSE_PLUS.md §6.3.
"""
from __future__ import annotations

import os
import shlex
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple

AGENT_DIR = Path(__file__).resolve().parent
REPO_ROOT = AGENT_DIR.parents[1]
BACKOFF_SECONDS = (30, 120, 480)

PROFILES = {
    "demo": dict(
        tick_seconds=30,
        due_lead_seconds=300,
        monitor_seconds=(600, 1800, 3600),
        daily_budget_usd=1.00,
        due_reserve_usd=0.20,
        max_fetches_per_tick=3,
        max_fetch_attempts=3,
        exhausted_wait_seconds=1800,
        payment_pause_seconds=900,
        max_gas_price_gwei=50.0,
    ),
    "prod": dict(
        tick_seconds=300,
        due_lead_seconds=86400,
        monitor_seconds=(86400, 259200, 604800),
        daily_budget_usd=5.00,
        due_reserve_usd=1.00,
        max_fetches_per_tick=10,
        max_fetch_attempts=5,
        exhausted_wait_seconds=21600,
        payment_pause_seconds=900,
        max_gas_price_gwei=50.0,
    ),
}


@dataclass
class Config:
    profile: str
    contract: str
    rpc_urls: List[str]
    agent_key: str = ""  # never logged or printed
    fetch_cmd: Tuple[str, ...] = ("api3/scripts/fetch-evidence.sh",)
    fetch_cost_usd: float = 0.01
    state_dir: Path = AGENT_DIR / "state"
    tick_seconds: int = 30
    due_lead_seconds: int = 300
    monitor_seconds: Tuple[int, int, int] = (600, 1800, 3600)
    daily_budget_usd: float = 1.00
    due_reserve_usd: float = 0.20
    max_fetches_per_tick: int = 3
    max_fetch_attempts: int = 3
    exhausted_wait_seconds: int = 1800
    payment_pause_seconds: int = 900
    max_gas_price_gwei: float = 50.0

    def monitor_interval(self, tier: int) -> int:
        return self.monitor_seconds[min(max(tier, 0), 2)]


def read_env_file(path: Path) -> dict:
    values = {}
    if not path.exists():
        return values
    for line in path.read_text().splitlines():
        line = line.split(" #", 1)[0].strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def load(env: Optional[dict] = None, profile: Optional[str] = None, require_chain: bool = True) -> Config:
    """Build the config. require_chain=False allows commands that only read local files (report)."""
    if env is None:
        env = {**read_env_file(AGENT_DIR / ".env"), **os.environ}
    name = profile or env.get("AGENT_PROFILE", "demo")
    if name not in PROFILES:
        raise ValueError("AGENT_PROFILE must be one of %s" % ", ".join(PROFILES))
    base = dict(PROFILES[name])

    def num(key, cast, default):
        return cast(env[key]) if env.get(key, "") != "" else default

    rpc = env.get("EVM_RPC_URLS") or env.get("EVM_RPC_URL", "")
    rpc_urls = [u.strip() for u in rpc.split(",") if u.strip()]
    fetch_cmd = tuple(shlex.split(env.get("FETCH_CMD") or "api3/scripts/fetch-evidence.sh"))
    local_fetch = any("fetch-local" in part for part in fetch_cmd)
    cfg = Config(
        profile=name,
        contract=env.get("PULSE_PLUS_ADDRESS", ""),
        rpc_urls=rpc_urls,
        agent_key=env.get("AGENT_PRIVATE_KEY") or env.get("EVM_PRIVATE_KEY", ""),
        fetch_cmd=fetch_cmd,
        fetch_cost_usd=num("FETCH_COST_USD", float, 0.0 if local_fetch else 0.01),
        state_dir=Path(env.get("STATE_DIR") or AGENT_DIR / "state"),
        tick_seconds=num("TICK_SECONDS", int, base["tick_seconds"]),
        due_lead_seconds=num("DUE_LEAD_SECONDS", int, base["due_lead_seconds"]),
        monitor_seconds=(
            num("MONITOR_SECONDS_STANDARD", int, base["monitor_seconds"][0]),
            num("MONITOR_SECONDS_TRUSTED", int, base["monitor_seconds"][1]),
            num("MONITOR_SECONDS_PREMIUM", int, base["monitor_seconds"][2]),
        ),
        daily_budget_usd=num("DAILY_BUDGET_USD", float, base["daily_budget_usd"]),
        due_reserve_usd=num("DUE_RESERVE_USD", float, base["due_reserve_usd"]),
        max_fetches_per_tick=num("MAX_FETCHES_PER_TICK", int, base["max_fetches_per_tick"]),
        max_fetch_attempts=num("MAX_FETCH_ATTEMPTS", int, base["max_fetch_attempts"]),
        exhausted_wait_seconds=num("EXHAUSTED_WAIT_SECONDS", int, base["exhausted_wait_seconds"]),
        payment_pause_seconds=num("PAYMENT_PAUSE_SECONDS", int, base["payment_pause_seconds"]),
        max_gas_price_gwei=num("MAX_GAS_PRICE_GWEI", float, base["max_gas_price_gwei"]),
    )
    if require_chain:
        missing = [k for k, v in (
            ("PULSE_PLUS_ADDRESS", cfg.contract),
            ("EVM_RPC_URL", cfg.rpc_urls),
            ("AGENT_PRIVATE_KEY", cfg.agent_key),
        ) if not v]
        if missing:
            raise ValueError("missing settings: %s (see api3/agent/.env.example)" % ", ".join(missing))
    return cfg
