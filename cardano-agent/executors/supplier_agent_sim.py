#!/usr/bin/env python3
"""Stand-in for the SupplierPulse agent script (api3/scripts/supplier-agent.sh).

SIMULATED: no registry call, no EVM transaction. It lets the Cardano side run
end to end on preprod until the real script and contract are deployed. Every
output says "simulated": true and has no txHash.

Same interface as the real script: env ORDER_ID and COMPANY_NUMBER, last
stdout line is the outcome JSON. The fake registry uses the company numbers
from api3/test/SupplierPulse.t.sol; any other number has no data.
"""
import json
import os
import sys

REGISTRY = {"01234567": "active", "07654321": "dissolved"}


def main():
    order_id = int(os.environ["ORDER_ID"])
    status = REGISTRY.get(os.environ["COMPANY_NUMBER"])
    if status is None:
        sys.exit("simulated: no signed registry profile for this company")
    print(json.dumps({
        "outcome": "Paid" if status == "active" else "Held",
        "txHash": None,
        "orderId": order_id,
        "milestone": 0,
        "status": status,
        "simulated": True,
    }))


if __name__ == "__main__":
    main()
