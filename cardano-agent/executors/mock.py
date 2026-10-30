#!/usr/bin/env python3
"""Mock executor: test the pay-on-pass flow without a real app.

Input: {"task": str, "outcome": "pass" | "fail" | "retry"}. "retry" fails
retryably on the first attempt and passes from the second attempt on.
"""
import json
import os
import sys

OUTCOMES = ["pass", "fail", "retry"]


def outcome(value) -> str:
    # Option fields may arrive as a string, a list, or an index into "values".
    if isinstance(value, list):
        value = value[0] if value else ""
    if isinstance(value, int) or (isinstance(value, str) and value.isdigit()):
        return OUTCOMES[int(value)]
    return str(value).strip().lower()


def main():
    data = json.load(sys.stdin)
    want = outcome(data.get("outcome", "pass"))
    attempt = int(os.getenv("ATTEMPT", "1"))
    passed = want == "pass" or (want == "retry" and attempt >= 2)
    print(json.dumps({
        "passed": passed,
        "retryable": want == "retry" and not passed,
        "summary": f"mock '{want}', attempt {attempt}: {'passed' if passed else 'did not pass'}",
        "evidence": {"task": str(data.get("task", ""))[:500], "attempt": attempt},
    }))


if __name__ == "__main__":
    main()
