"""SupplierPulsePlus access through Foundry's cast: reads, simulations and sends.

Signatures come from docs/SUPPLIERPULSE_PLUS.md §4.6. Every call tries the RPCs
in order (EVM_RPC_URLS) and moves on when one fails at the RPC level; a revert is
the contract's answer and is raised as Reverted with its error name. A transaction
is broadcast once and then followed by its hash, so a failover never sends it twice.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Callable, List, Optional
from urllib.parse import urlparse

from model import CLOSED, Order, Snapshot, Supplier

SIGNATURES = {
    "ordersLength": "ordersLength()(uint256)",
    "orderInfo": "orderInfo(uint256)(address,address,uint8,string,bytes32,bytes32,uint64,uint8)",
    "orderStatus": "orderStatus(uint256)(uint8,uint256,uint256,uint256,uint256,uint64,bool,uint256)",
    "orderSchedule": "orderSchedule(uint256)(uint64,bool,uint8,uint64,uint64,uint8)",
    "supplierRecord": "supplierRecord(bytes32)(uint32,uint32,uint32,uint64,uint64,uint64,uint8)",
    "supplierKeyOf": "supplierKeyOf(uint8,string)(bytes32)",
    "submitEvidence": "submitEvidence(uint256,bytes32,uint256,bytes,bytes)(bool)",
    "checkAndRelease": "checkAndRelease(uint256,bytes32,uint256,bytes,bytes)(uint8)",
    "release": "release(uint256)",
    "applySupplierFailure": "applySupplierFailure(uint256)",
    "refundRemaining": "refundRemaining(uint256)",
}
OUTCOME_NAMES = {0: "Paid", 1: "AwaitingApproval", 2: "NotDue", 3: "Held"}
# Fixed gas limit for every write. cast send would use the exact estimate, and on a chain that mines in intervals
# (Sepolia) a transaction often lands a block later, where more storage is written (for example the verification
# history after tierCountGap): 18 of 24 sends ran out of gas in Batu's test. Unused gas is refunded, and every
# write is simulated first, so the fixed limit only removes the estimate's lack of headroom.
GAS_LIMIT = 600_000

# 4-byte selectors of every error the contract and its libraries can raise (cast sig "Name(types)")
ERROR_SELECTORS = {
    "0x32c15fc2": "WrongSigner",
    "0x1d8dd39f": "WrongRequest",
    "0x4a3ed0da": "StaleResponse",
    "0xa5b14fcf": "FutureResponse",
    "0x2a113fdf": "Replayed",
    "0xa3051cad": "NotNewer",
    "0xa7167e8f": "NoValidPermit",
    "0xe37c206e": "PermitExpired",
    "0x676e2fd4": "NotApproved",
    "0x39c32aeb": "NotDue",
    "0x1d61e8ee": "NotActive",
    "0x845eadf1": "NotHeld",  # v1 only
    "0x3742d1f6": "NotRefundable",
    "0x3ea8fb25": "RefundNotYet",
    "0x4c9c8ee2": "SupplierFailed",
    "0x98788583": "NoNewerFailure",
    "0x98c2c368": "BadOrder",
    "0x7bbdd1c9": "BadSource",
    "0xe7a46501": "BadSupplierId",
    "0x0e3264aa": "BadRules",
    "0xea8e4eb5": "NotAuthorized",
    "0x90b8ec18": "TransferFailed",
    "0x4be6321b": "InvalidSignatureLength",
    "0xbf4bf5b8": "InvalidSignatureS",
    "0xff551e89": "InvalidSignatureV",
    "0x815e1d64": "InvalidSigner",
    "0x5f3f479c": "KeyNotFound",
    "0x8c81f483": "NoNumber",
    "0x951745e9": "NoString",
    "0xa8363ae8": "NoBool",
}


class ChainError(RuntimeError):
    """RPC or transport problem. The agent retries on the next tick."""


class Reverted(Exception):
    """The contract refused the call."""

    def __init__(self, name: str, selector: str = "", detail: str = ""):
        super().__init__(name)
        self.name, self.selector, self.detail = name, selector, detail

    def __str__(self) -> str:
        return self.name + self.detail


def cast_binary() -> str:
    return shutil.which("cast") or str(Path.home() / ".foundry" / "bin" / "cast")


def input_signature(sig: str) -> str:
    """'f(uint256)(bool)' -> 'f(uint256)': cast send takes only the inputs."""
    return sig[: sig.index(")") + 1]


def revert_from_text(text: str) -> Optional[Reverted]:
    """The revert in cast's output (JSON envelope or plain text), or None if it is another error."""
    detail = ""
    m = re.search(r"execution reverted: ([A-Za-z_]\w*)(\([^)]*\))?", text)
    if m:
        detail = m.group(2) or ""
    sel = re.search(r'data: \\*"(0x[0-9a-fA-F]{8})', text) or re.search(r"custom error (0x[0-9a-fA-F]{8})", text)
    if sel:
        selector = sel.group(1).lower()
        return Reverted(ERROR_SELECTORS.get(selector, m.group(1) if m else "Unknown(%s)" % selector), selector, detail)
    if m:
        return Reverted(m.group(1), "", detail)
    if "execution reverted" in text:
        return Reverted("Reverted")
    return None


def rpc_host(url: str) -> str:
    """The host of an RPC URL: safe to log, while the path or query may hold an API key."""
    return urlparse(url).netloc or "rpc"


def _int(value) -> int:
    return int(str(value).split()[0])


def _bool(value) -> bool:
    return value if isinstance(value, bool) else str(value).strip().lower() == "true"


def _run(cmd: List[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=90)


class Chain:
    signatures = SIGNATURES
    outcome_names = OUTCOME_NAMES

    def __init__(self, contract: str, rpc_urls: List[str], private_key: str = "",
                 runner: Optional[Callable[[List[str]], subprocess.CompletedProcess]] = None, workers: int = 4,
                 receipt_timeout: int = 180, receipt_poll: float = 3.0):
        self.contract = contract
        self.rpc_urls = list(rpc_urls)
        self._key = private_key
        self._run = runner or _run
        self.workers = workers
        self.receipt_timeout, self.receipt_poll = receipt_timeout, receipt_poll
        self._static = {}  # order id -> [source, supplierId, rules, supplierKey]; never changes
        self._closed = set()  # closed orders are never read again
        self._address = None
        self._preferred = 0  # index of the RPC that answered last: tried first, so a dead one costs one miss

    # ---- low level
    def redact(self, text: str) -> str:
        """Error text without the agent key or full RPC URLs."""
        for secret in (self._key, self._key[2:] if self._key.startswith("0x") else ""):
            if len(secret) >= 32:
                text = text.replace(secret, "<agent key>")
        for url in self.rpc_urls:
            text = text.replace(url, rpc_host(url))
        return text

    def _rpc_order(self) -> List[int]:
        first = self._preferred if self._preferred < len(self.rpc_urls) else 0
        return [first] + [i for i in range(len(self.rpc_urls)) if i != first]

    def _cast(self, args: List[str], json_out: bool = True):
        last = "no RPC configured"
        for index in self._rpc_order():
            url = self.rpc_urls[index]
            cmd = [cast_binary()] + args + (["--json"] if json_out else []) + ["--rpc-url", url]
            try:
                res = self._run(cmd)
            except subprocess.TimeoutExpired:  # never log the command: a send holds the key
                last = "timeout on %s" % rpc_host(url)
                continue
            out = (res.stdout or "").strip()
            envelope = None
            if json_out and out:
                try:
                    parsed = json.loads(out)
                except ValueError:
                    parsed = None
                if isinstance(parsed, dict) and "success" in parsed:
                    envelope = parsed
                elif res.returncode == 0 and parsed is not None:
                    self._preferred = index
                    return parsed
            if envelope is not None and envelope.get("success"):
                self._preferred = index
                return envelope.get("data")
            if res.returncode == 0 and envelope is None:
                # success without JSON: plain output (block, gas-price), or a call to a function without
                # return values, which cast prints as a bare "0x" even with --json
                self._preferred = index
                return out if not json_out else ([out] if out else [])
            text = " ".join(e.get("message", "") for e in (envelope or {}).get("errors") or [])
            text = text or (out + " " + (res.stderr or "")).strip()
            reverted = revert_from_text(text)
            if reverted:
                self._preferred = index  # the RPC works; the contract said no
                raise reverted  # another RPC would say the same
            last = self.redact(text)[-300:]  # RPC-level problem: try the next one
        raise ChainError(last)

    @property
    def address(self) -> str:
        if self._address is None:
            try:
                res = self._run([cast_binary(), "wallet", "address", "--private-key", self._key])
            except subprocess.TimeoutExpired:  # its message would contain the command, key included
                raise ChainError("timeout deriving the agent address") from None
            if res.returncode != 0:
                raise ChainError("cannot derive the agent address from AGENT_PRIVATE_KEY")
            self._address = res.stdout.strip()
        return self._address

    def call(self, name: str, *args) -> list:
        return self._cast(["call", self.contract, self.signatures[name]] + [str(a) for a in args])

    def simulate(self, name: str, *args) -> list:
        """eth_call as the agent: the result the transaction would have, or Reverted."""
        return self._cast(["call", "--from", self.address, self.contract, self.signatures[name]] + [str(a) for a in args])

    def send(self, name: str, *args) -> str:
        """Broadcast once (cast send --async), then poll the receipt by hash, with failover. A slow block or
        an RPC hiccup while waiting never sends the transaction again."""
        out = self._cast(["send", "--async", "--gas-limit", str(GAS_LIMIT), "--private-key", self._key, self.contract,
                          input_signature(self.signatures[name])] + [str(a) for a in args])
        tx = str(out[0] if isinstance(out, list) and out else out).strip().strip('"')
        if not re.fullmatch(r"0x[0-9a-fA-F]{64}", tx):
            raise ChainError("cast send printed no transaction hash: %s" % self.redact(str(out))[:200])
        deadline = time.time() + self.receipt_timeout
        while True:
            try:
                receipt = self._cast(["rpc", "eth_getTransactionReceipt", tx])  # null while pending
            except ChainError:
                receipt = None  # ask again; the transaction is out already
            if isinstance(receipt, dict):
                if str(receipt.get("status")).lower() not in ("0x1", "1", "true"):
                    raise ChainError("transaction failed: %s" % tx)
                return tx
            if time.time() >= deadline:
                raise ChainError("transaction %s not mined after %ss" % (tx, self.receipt_timeout))
            time.sleep(self.receipt_poll)

    def now(self) -> int:
        return _int(self._cast(["block", "latest", "-f", "timestamp"], json_out=False))

    def gas_price_gwei(self) -> float:
        return _int(self._cast(["gas-price"], json_out=False)) / 1e9

    def balance_wei(self) -> int:
        return _int(self._cast(["balance", self.address], json_out=False))

    # ---- state
    def snapshot(self) -> Snapshot:
        now = self.now()
        count = _int(self.call("ordersLength")[0])
        with ThreadPoolExecutor(self.workers) as pool:
            new_ids = [i for i in range(count) if i not in self._static]
            for i, info in zip(new_ids, pool.map(lambda i: self.call("orderInfo", i), new_ids)):
                self._static[i] = [_int(info[2]), str(info[3]), _int(info[7]), None, _int(info[6])]
            missing = sorted({(s[0], s[1]) for s in self._static.values() if s[3] is None})
            keys = dict(zip(missing, pool.map(lambda k: self.call("supplierKeyOf", k[0], k[1])[0], missing)))
            for s in self._static.values():
                if s[3] is None:
                    s[3] = str(keys[(s[0], s[1])])

            open_ids = [i for i in range(count) if i not in self._closed]
            statuses = list(pool.map(lambda i: self.call("orderStatus", i), open_ids))
            schedules = list(pool.map(lambda i: self.call("orderSchedule", i), open_ids))
            orders = []
            for i, st, sc in zip(open_ids, statuses, schedules):
                source, supplier_id, rules, key, permit_ttl = self._static[i]
                if _int(st[0]) == CLOSED:
                    self._closed.add(i)
                    continue
                orders.append(Order(
                    id=i, source=source, supplier_id=supplier_id, supplier_key=key, rules=rules,
                    state=_int(st[0]), remaining=_int(st[2]), permit_valid=_bool(st[6]),
                    permit_valid_until=_int(st[5]), last_check=_int(st[7]),
                    next_due_date=_int(sc[0]), next_approved=_bool(sc[1]), last_failed_rules=_int(sc[2]),
                    auto_refund_at=_int(sc[4]), tier=_int(sc[5]), permit_ttl=permit_ttl,
                ))
            supplier_keys = sorted({o.supplier_key for o in orders})
            records = dict(zip(supplier_keys, pool.map(lambda k: self.call("supplierRecord", k), supplier_keys)))
        suppliers = {k: Supplier(key=k, tier=_int(r[6]), last_check_at=_int(r[4]), clean_streak=_int(r[0]),
                              last_base_failure_at=_int(r[5]))
                     for k, r in records.items()}
        return Snapshot(now, orders, suppliers)
