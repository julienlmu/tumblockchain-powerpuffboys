#!/usr/bin/env python3
"""Serves demo/ like `python3 -m http.server`, plus one endpoint for the change report page (demo/changes.html).

POST /api/change-report with {"agreed": "...", "presented": "..."} runs scripts/plus-doc-diff.sh --summary on the two
texts and returns {"diff", "summary", "note"}. The language-model key stays on this machine: plus-doc-diff.sh reads it
from the environment or api3/.env, and the browser never sees it. Only the diff (first 20,000 bytes) leaves the machine,
to the model's API. The report is informational only and never affects payments.

Usage: python3 api3/scripts/change-report-server.py [port]   (default 8766, bound to 127.0.0.1 only)
"""
import json
import subprocess
import sys
import tempfile
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
DEMO = SCRIPTS.parent.parent / "demo"
MAX_BODY = 200_000  # bytes of JSON; an order document is a few KB
SUMMARY_MARK = "=== Summary"


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DEMO), **kwargs)

    def reply(self, status, obj):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path != "/api/change-report":
            return self.reply(404, {"error": "not found"})
        # a page from another site or a rebound DNS name must not spend the key: only this host, only JSON
        # (a cross-site JSON request needs a CORS preflight, which this server never answers)
        host = (self.headers.get("Host") or "").rsplit(":", 1)[0]
        if host not in ("localhost", "127.0.0.1"):
            return self.reply(403, {"error": "open the page at localhost"})
        if not (self.headers.get("Content-Type") or "").startswith("application/json"):
            return self.reply(415, {"error": "JSON only"})
        try:
            n = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            n = -1
        if not 0 < n <= MAX_BODY:
            return self.reply(413, {"error": f"send between 1 and {MAX_BODY:,} bytes"})
        try:
            data = json.loads(self.rfile.read(n))
            agreed, presented = data["agreed"], data["presented"]
            assert isinstance(agreed, str) and isinstance(presented, str)
        except Exception:
            return self.reply(400, {"error": "expected {\"agreed\": text, \"presented\": text}"})

        with tempfile.TemporaryDirectory() as tmp:
            a, p = Path(tmp, "agreed.txt"), Path(tmp, "presented.txt")
            a.write_text(agreed)
            p.write_text(presented)
            try:
                run = subprocess.run(["bash", str(SCRIPTS / "plus-doc-diff.sh"), "--summary", str(a), str(p)],
                                     capture_output=True, text=True, timeout=90)
            except subprocess.TimeoutExpired:
                return self.reply(504, {"error": "the change report took longer than 90 seconds"})
        if run.returncode != 0:
            return self.reply(500, {"error": (run.stderr or run.stdout).strip()[-500:] or "change report failed"})

        # plus-doc-diff.sh prints the diff, then either the summary block or one "(…)" line saying why there is none
        out = run.stdout
        diff, _, summary = out.partition(SUMMARY_MARK)
        lines = diff.strip().splitlines()
        if lines and lines[0].startswith("=== Changes"):
            lines = lines[1:]
        note = ""
        if lines and lines[-1].startswith("(") and lines[-1].endswith(")"):
            note = lines.pop().strip("()")
        if summary:
            summary = summary.split("\n", 1)[1] if "\n" in summary else ""
        return self.reply(200, {"diff": "\n".join(lines).strip(), "summary": summary.strip(), "note": note})

    def log_message(self, fmt, *args):  # keep the terminal quiet except for the report calls
        if "/api/" in (self.path or ""):
            super().log_message(fmt, *args)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8766
    print(f"Change report page: http://localhost:{port}/changes.html  (Ctrl+C to stop)")
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
