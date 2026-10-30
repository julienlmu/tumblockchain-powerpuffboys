"""Drive the live v1 contract (api3/src/SupplierPulse.sol) with the same agent.

This is the hedge for the agent bonus (docs/SUPPLIERPULSE_PLUS.md §6.3): the
autonomous cycles build up on the deployed v1 contract even if v2 is late.
v1 has one registry (Companies House status), no due dates, no tiers and
buyer-only refunds, so the snapshot maps it onto the v2 shapes:
- an approved next milestone counts as due now (checkAndRelease pays it);
- other milestones are only re-checked by the monitoring interval;
- no refunds and no supplier-wide stop (v1 has neither).
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor

from chain import Chain, _bool, _int
from model import CLOSED, FAIL_BASE, HELD, Order, Snapshot, Supplier

V1_SIGNATURES = {
    "ordersLength": "ordersLength()(uint256)",
    "orderStatus": "orderStatus(uint256)(uint8,uint256,uint256,uint256,uint256,uint256,bool,string,uint256)",
    "orderInfo": "orderInfo(uint256)(address,address,bytes32,bytes32,uint256,uint256[],bool[])",
    "companyNumberOf": "companyNumberOf(uint256)(string)",
    "submitEvidence": "submitEvidence(uint256,bytes32,uint256,bytes,bytes)(bool)",
    "checkAndRelease": "checkAndRelease(uint256,bytes32,uint256,bytes,bytes)(uint8)",
    "release": "release(uint256)",
    "refundRemaining": "refundRemaining(uint256)",
}
V1_OUTCOME_NAMES = {0: "Paid", 1: "AwaitingApproval", 2: "Held"}  # v1's Outcome enum has no NotDue


class ChainV1(Chain):
    signatures = V1_SIGNATURES
    outcome_names = V1_OUTCOME_NAMES

    def snapshot(self) -> Snapshot:
        now = self.now()
        count = _int(self.call("ordersLength")[0])
        with ThreadPoolExecutor(self.workers) as pool:
            new_ids = [i for i in range(count) if i not in self._static]
            numbers = list(pool.map(lambda i: self.call("companyNumberOf", i)[0], new_ids))
            for i, number in zip(new_ids, numbers):
                self._static[i] = [0, str(number), 0, None, 0]
            open_ids = [i for i in range(count) if i not in self._closed]
            statuses = list(pool.map(lambda i: self.call("orderStatus", i), open_ids))
            infos = list(pool.map(lambda i: self.call("orderInfo", i), open_ids))
        orders = []
        for i, st, info in zip(open_ids, statuses, infos):
            state = _int(st[0])
            if state == CLOSED:
                self._closed.add(i)
                continue
            key = str(info[2])  # v1 binds an order to its company request hash: one key per company
            m = _int(st[3])
            approved = [_bool(a) for a in info[6]]
            next_approved = m < len(approved) and approved[m]
            orders.append(Order(
                id=i, source=0, supplier_id=self._static[i][1], supplier_key=key, rules=0, state=state,
                remaining=_int(st[2]), permit_valid=_bool(st[6]), permit_valid_until=_int(st[5]), last_check=_int(st[8]),
                next_due_date=1 if next_approved else 0, next_approved=next_approved,
                last_failed_rules=FAIL_BASE if state == HELD else 0, auto_refund_at=0, tier=0,
                permit_ttl=_int(info[4]),
            ))
        suppliers = {}
        for o in orders:
            sup = suppliers.setdefault(o.supplier_key, Supplier(key=o.supplier_key, tier=0, last_check_at=0))
            sup.last_check_at = max(sup.last_check_at, o.last_check)
        return Snapshot(now, orders, suppliers)
