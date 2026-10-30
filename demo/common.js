// Shared by index.html (dashboard) and judge.html ("Try to break it").
// Everything here mirrors docs/SUPPLIERPULSE_PLUS.md: the ABI (§4.6), request hashes (§4.2), rules and labels (§4.3),
// tamper semantics (§4.7, same as api3/x402/tamper.mjs). A classic script, so the pages also open from file://.
(() => {
  const ABI = [
    "function ordersLength() view returns (uint256)",
    "function orderInfo(uint256) view returns (address buyer, address supplier, uint8 source, string supplierId, bytes32 requestHash, bytes32 orderRef, uint64 permitTtl, uint8 rules)",
    "function orderMilestones(uint256) view returns (uint256[] amounts, uint64[] dueDates, bool[] approved)",
    "function orderStatus(uint256) view returns (uint8 state, uint256 paid, uint256 remaining, uint256 nextMilestone, uint256 milestones, uint64 permitValidUntil, bool permitValid, uint256 lastCheck)",
    "function orderSchedule(uint256) view returns (uint64 nextDueDate, bool nextApproved, uint8 lastFailedRules, uint64 heldAt, uint64 autoRefundAt, uint8 tier)",
    "function supplierRecord(bytes32) view returns (uint32 cleanStreak, uint32 checks, uint32 failures, uint64 lastCountedAt, uint64 lastCheckAt, uint64 lastBaseFailureAt, uint8 tier)",
    "function supplierKeyOf(uint8 source, string supplierId) pure returns (bytes32)",
    "function requestHashFor(uint8 source, string supplierId) pure returns (bytes32)",
    "function airnodeOf(uint8) view returns (address)",
    "function maxAge() view returns (uint256)",
    "function tierCountGap() view returns (uint64)",
    "function refundGrace() view returns (uint64)",
    "function usedDigests(bytes32) view returns (bool)",
    "function createOrder(uint8 source, string supplierId, address supplier, bytes32 orderRef, uint256[] amounts, uint64[] dueDates, uint64 permitTtl, uint8 rules) payable returns (uint256)",
    "function approveMilestone(uint256 orderId, uint256 milestone)",
    "function submitEvidence(uint256 orderId, bytes32 requestHash, uint256 timestamp, bytes data, bytes signature) returns (bool clean)",
    "function release(uint256 orderId)",
    "function checkAndRelease(uint256 orderId, bytes32 requestHash, uint256 timestamp, bytes data, bytes signature) returns (uint8 outcome)",
    "function refundRemaining(uint256 orderId)",
    "function applySupplierFailure(uint256 orderId)",
    "event OrderCreated(uint256 indexed orderId, address indexed buyer, bytes32 indexed supplierKey, address supplier, uint8 source, string supplierId, bytes32 requestHash, bytes32 orderRef, uint256 total, uint8 rules)",
    "event MilestoneApproved(uint256 indexed orderId, uint256 milestone)",
    "event EvidenceAccepted(uint256 indexed orderId, bytes32 indexed supplierKey, bool clean, uint8 failedRules, uint256 timestamp, bytes32 digest, address submitter, bytes data)",
    "event PermitIssued(uint256 indexed orderId, uint256 milestone, uint256 amount, uint64 validUntil, bytes32 evidence)",
    "event MilestonePaid(uint256 indexed orderId, uint256 milestone, address supplier, uint256 amount, bytes32 evidence)",
    "event OrderHeld(uint256 indexed orderId, uint8 failedRules, uint256 remaining, uint64 autoRefundAt)",
    "event OrderRefunded(uint256 indexed orderId, address buyer, uint256 amount, address triggeredBy, bool noDataExit)",
    "event TierChanged(bytes32 indexed supplierKey, uint8 oldTier, uint8 newTier, uint32 cleanStreak)",
    "error WrongSigner(address recovered)", "error WrongRequest(bytes32 got, bytes32 expected)",
    "error StaleResponse(uint256 timestamp, uint256 nowTs)", "error FutureResponse(uint256 timestamp, uint256 nowTs)",
    "error Replayed(bytes32 digest)", "error NotNewer(uint256 timestamp, uint256 lastCheck)",
    "error NoValidPermit(uint256 milestone)", "error PermitExpired(uint256 validUntil, uint256 nowTs)",
    "error NotApproved(uint256 milestone)", "error NotDue(uint256 dueDate, uint256 nowTs)",
    "error NotActive(uint8 state)", "error NotRefundable()", "error RefundNotYet(uint256 refundableAt)",
    "error SupplierFailed(uint256 failedAt)", "error NoNewerFailure()",
    "error BadOrder()", "error BadSource()", "error BadSupplierId()", "error BadRules()",
    "error NotAuthorized()", "error TransferFailed()",
    "error InvalidSignatureLength()", "error InvalidSignatureS()", "error InvalidSignatureV()", "error InvalidSigner()",
    "error KeyNotFound()", "error NoNumber()", "error NoString()", "error NoBool()",
  ];

  const DEFAULT_RPC = "https://ethereum-sepolia-rpc.publicnode.com";
  const DEAD = "0x000000000000000000000000000000000000dEaD"; // eth_call sender for judge simulations: no wallet, no gas
  const EXPLORERS = { 11155111: "https://sepolia.etherscan.io" };
  const NETWORKS = { 11155111: "Ethereum Sepolia", 31337: "Local test chain (anvil)" };
  const DEFAULT_AGENT = {
    11155111: "0xED3418aE93669a640650728E70f7aA712083253a", // Julien's agent wallet (§3.2)
    31337: "0x90F79bf6EB2c4f870365E785982E1f101E93b906",    // anvil #3 (§4.8)
  };
  const STATE = ["Active", "Held", "Closed"];
  const OUTCOME = ["Paid", "AwaitingApproval", "NotDue", "Held"];
  const TIERS = ["Standard", "Trusted", "Premium"];
  // §4.2 request templates. Index = contract source id.
  const SOURCES = [
    {
      key: "ch", badge: "CH", name: "Companies House",
      request: (id) => `["getCompanyProfile",[["company_number","${id}"]],[["accounts_overdue","/accounts/next_accounts/overdue"],["confirmation_overdue","/confirmation_statement/overdue"],["status","/company_status"]]]`,
      body: (id) => `{"operation":"getCompanyProfile","parameters":{"company_number":"${id}"},"responseProjection":{"accounts_overdue":"/accounts/next_accounts/overdue","confirmation_overdue":"/confirmation_statement/overdue","status":"/company_status"}}`,
      registerUrl: (id) => `https://find-and-update.company-information.service.gov.uk/company/${encodeURIComponent(id)}`,
      otherId: "00000001", otherIdAlt: "00000002",
    },
    {
      key: "gleif", badge: "GLEIF", name: "GLEIF (LEI)",
      request: (id) => `["getLegalEntity",[["lei","${id}"]],[["entity_status","/data/attributes/entity/status"],["registration_status","/data/attributes/registration/status"]]]`,
      body: (id) => `{"operation":"getLegalEntity","parameters":{"lei":"${id}"},"responseProjection":{"entity_status":"/data/attributes/entity/status","registration_status":"/data/attributes/registration/status"}}`,
      registerUrl: (id) => `https://search.gleif.org/#/record/${encodeURIComponent(id)}`,
      otherId: "TESTLEI0000000000001", otherIdAlt: "TESTLEI0000000000002",
    },
  ];
  const sourceIndex = (key) => SOURCES.findIndex((s) => s.key === key);

  const KNOWN_SIGNERS = {
    "0x392228e5cca260313e5ed337ed3561b59a1e4bff": "Companies House Airnode",
    "0x26d83124541e89ef28b9a5fb012b4b5f4097c20c": "GLEIF Airnode",
    "0x70997970c51812dc3a010c7d01b50e0d17dc79c8": "local Companies House key (anvil #1)",
    "0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc": "local GLEIF key (anvil #2)",
  };

  // §4.3. Base checks are always on; bit 0x80 in failedRules means the base check failed.
  const BASE_FAILED = 0x80;
  const BASE = [
    { field: "status", clean: (v) => v === "active", label: "registry status not active", rule: "status active" },
    { field: "entity_status", clean: (v) => v === "ACTIVE", label: "LEI entity not active", rule: "LEI entity active" },
  ];
  const RULES = [
    { bit: 0x02, source: 0, field: "accounts_overdue", clean: (v) => v === false, label: "accounts overdue", rule: "accounts filed" },
    { bit: 0x04, source: 0, field: "confirmation_overdue", clean: (v) => v === false, label: "confirmation statement overdue", rule: "confirmation statement filed" },
    { bit: 0x08, source: 1, field: "registration_status", clean: (v) => v === "ISSUED", label: "LEI renewal overdue", rule: "LEI registration issued" },
  ];

  /** Rule chips for an order: the base check plus each enabled bit. */
  function ruleNames(source, rules) {
    return [BASE[source].rule, ...RULES.filter((r) => r.source === source && (rules & r.bit)).map((r) => r.rule)];
  }
  /** Plain-word labels for a failedRules byte. */
  function failedLabels(source, failed) {
    failed = Number(failed);
    const out = [];
    if (failed & BASE_FAILED) out.push(BASE[source] ? BASE[source].label : "base status check failed");
    for (const r of RULES) if (failed & r.bit) out.push(r.label);
    return out;
  }
  /** The contract's rule evaluation (§4.3) for parsed signed fields. Missing fields count as failed here; the contract reverts instead. */
  function evaluate(source, fields, rules) {
    let failed = 0;
    if (!BASE[source].clean(fields[BASE[source].field])) failed |= BASE_FAILED;
    for (const r of RULES) if (r.source === source && (rules & r.bit) && !r.clean(fields[r.field])) failed |= r.bit;
    return failed;
  }

  const requestHashFor = (source, id) => ethers.id(SOURCES[source].request(id));
  const supplierKeyOf = (source, id) => ethers.solidityPackedKeccak256(["uint8", "string"], [source, id]);
  const digestOf = (requestHash, timestamp, data) =>
    ethers.solidityPackedKeccak256(["bytes32", "uint256", "bytes"], [requestHash, BigInt(timestamp), data]);

  /** Accepts a §4.1 record (or the v1 subset) and returns it with hex `data`, string `timestamp` and a known source. */
  function normalizeRecord(obj, fallbackSource) {
    if (!obj || typeof obj !== "object") throw new Error("not a JSON object");
    const r = { ...obj };
    if (!r.data && typeof r.raw === "string") r.data = ethers.hexlify(ethers.toUtf8Bytes(r.raw));
    for (const k of ["requestHash", "timestamp", "data", "signature"]) if (r[k] === undefined || r[k] === null || r[k] === "") throw new Error(`missing field "${k}"`);
    if (!ethers.isHexString(r.data)) throw new Error('"data" must be 0x-hex of the signed bytes');
    if (!ethers.isHexString(r.requestHash, 32)) throw new Error('"requestHash" must be 32 bytes of 0x-hex');
    if (!ethers.isHexString(r.signature)) throw new Error('"signature" must be 0x-hex');
    r.timestamp = String(r.timestamp);
    if (!/^\d+$/.test(r.timestamp)) throw new Error('"timestamp" must be unix seconds');
    if (r.source !== "ch" && r.source !== "gleif") r.source = SOURCES[fallbackSource] ? SOURCES[fallbackSource].key : "ch";
    try { r.raw = ethers.toUtf8String(r.data); } catch { r.raw = null; }
    return r;
  }

  function parseFields(dataHex) {
    try { return JSON.parse(ethers.toUtf8String(dataHex)); } catch { return null; }
  }

  // §4.7: replaces one value in the signed string and keeps every other byte as signed (same as tamper.mjs).
  function editValue(source, signed) {
    const swap = (key, from, to) => {
      const m = signed.match(new RegExp(`"${key}":\\s*"([^"]*)"`));
      if (!m) return null;
      const next = m[1] === from ? to : from;
      return { raw: signed.replace(m[0], m[0].replace(`"${m[1]}"`, `"${next}"`)), what: `${key} "${m[1]}" → "${next}"` };
    };
    const edit = source === "gleif" ? swap("entity_status", "ACTIVE", "INACTIVE") : swap("status", "active", "liquidation");
    if (edit) return edit;
    const b = signed.match(/"([^"]+)":\s*(true|false)/);
    if (!b) throw new Error("nothing to edit: no status field and no boolean in the signed data");
    const flipped = b[2] === "true" ? "false" : "true";
    return { raw: signed.replace(b[0], b[0].replace(b[2], flipped)), what: `${b[1]} ${b[2]} → ${flipped}` };
  }

  /** Builds a tampered copy of a normalized record. Returns { record, what, expect }. */
  async function tamper(r, mode) {
    const out = { ...r };
    switch (mode) {
      case "value": {
        const { raw, what } = editValue(r.source, ethers.toUtf8String(r.data));
        out.raw = raw;
        out.data = ethers.hexlify(ethers.toUtf8Bytes(raw));
        return { record: out, what: `(a) Edited value: ${what}. The signature is unchanged.`, expect: "WrongSigner" };
      }
      case "stale":
        out.timestamp = String(BigInt(r.timestamp) - 3600n);
        return { record: out, what: `(b) Too old: timestamp ${r.timestamp} → ${out.timestamp} (one hour earlier).`, expect: "StaleResponse" };
      case "request": {
        const s = SOURCES[sourceIndex(r.source)];
        const id = String(r.supplierId || "").toUpperCase() === s.otherId ? s.otherIdAlt : s.otherId;
        out.requestHash = requestHashFor(sourceIndex(r.source), id);
        return { record: out, what: `(c) Different request: the request hash of ${s.name} ${id}.`, expect: "WrongRequest" };
      }
      case "key": {
        const w = ethers.Wallet.createRandom();
        out.signature = await w.signMessage(ethers.getBytes(digestOf(r.requestHash, r.timestamp, r.data)));
        return { record: out, what: `(d) Wrong key: the untouched response, re-signed by a random key ${w.address}.`, expect: "WrongSigner", signer: w.address };
      }
      case "replay":
        return { record: out, what: "Replay: the response unchanged. It is rejected once the original was accepted on chain.", expect: "Replayed" };
      default:
        return { record: out, what: "Submitted as is.", expect: null };
    }
  }

  /** Decodes a revert from an ethers error. Returns { name, args, signature } or null. */
  function decodeRevert(iface, err) {
    const candidates = [err && err.data, err && err.info && err.info.error && err.info.error.data, err && err.error && err.error.data, err && err.revert && err.revert.data];
    for (let d of candidates) {
      if (d && typeof d === "object" && d.data) d = d.data;
      if (typeof d !== "string" || !d.startsWith("0x") || d.length < 10) continue;
      try { const e = iface.parseError(d); if (e) return { name: e.name, args: [...e.args], signature: e.signature }; } catch { /* try next */ }
    }
    if (err && err.revert && err.revert.name) return { name: err.revert.name, args: [...(err.revert.args || [])], signature: err.revert.signature };
    return null;
  }

  /** One plain sentence per contract error, for judges. */
  function explain(name, args, ctx = {}) {
    const a = args || [];
    const t = (x) => new Date(Number(x) * 1000).toLocaleString("en-GB");
    switch (name) {
      case "WrongSigner": return `The signature recovers to ${a[0]}, not the Airnode this contract trusts for this registry${ctx.expectedSigner ? ` (${ctx.expectedSigner})` : ""}. Any edit of the signed bytes, or a different key, changes the recovered address.`;
      case "WrongRequest": return "The response answers a different request (another company, operation or projection) than the one this order was built for.";
      case "StaleResponse": return `The response was signed at ${t(a[0])}, more than maxAge before the chain's time ${t(a[1])}. Old evidence cannot pay today's milestone.`;
      case "FutureResponse": return `The timestamp ${t(a[0])} lies more than 60 s in the future of the chain's time ${t(a[1])}.`;
      case "Replayed": return "This exact signed response was already used once. Each record can move the order only once.";
      case "NotNewer": return "The order already accepted a record signed at the same time or later. Older evidence cannot overwrite newer evidence.";
      case "NotActive": return `The order is ${STATE[Number(a[0])] || "not active"}: a held or closed order accepts no new evidence.`;
      case "BadOrder": return "There is no order with this id.";
      case "InvalidSignatureLength": case "InvalidSignatureS": case "InvalidSignatureV": case "InvalidSigner":
        return "The signature bytes are malformed, so no signer can be recovered.";
      case "KeyNotFound": case "NoString": case "NoBool": case "NoNumber":
        return "A field the order's rules need is missing or has the wrong type in the signed data. Without it the order can never pay (fail-safe).";
      case "NotRefundable": return "The order does not meet either refund path: it is not held long enough, or no-data exit conditions are not met.";
      case "RefundNotYet": return `Before ${t(a[0])} only the buyer can claim the remaining balance.`;
      case "SupplierFailed": return `A newer failed base-status record at ${t(a[0])} blocks this older permit.`;
      case "NoNewerFailure": return "There is no newer verified base-status failure to apply to this order.";
      case "NotAuthorized": return "Only the buyer may do this.";
      default: return "";
    }
  }

  // ---------------------------------------------------------------- formatting

  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const short = (h) => (h && h.length > 14 ? h.slice(0, 6) + "…" + h.slice(-4) : h);
  const nowSec = () => Math.floor(Date.now() / 1000);
  const clock = (ts) => new Date(Number(ts) * 1000).toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
  const dayClock = (ts) => new Date(Number(ts) * 1000).toLocaleString("en-GB", { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });

  function ago(sec) {
    if (sec < 0) return "in the future";
    if (sec < 90) return `${sec} s ago`;
    if (sec < 5400) return `${Math.round(sec / 60)} min ago`;
    if (sec < 172800) return `${(sec / 3600).toFixed(1)} h ago`;
    return `${Math.round(sec / 86400)} days ago`;
  }
  function span(sec) {
    sec = Math.max(0, Math.round(sec));
    if (sec < 120) return `${sec} s`;
    if (sec < 7200) return `${Math.floor(sec / 60)} min ${String(sec % 60).padStart(2, "0")} s`;
    if (sec < 172800) return `${Math.floor(sec / 3600)} h ${String(Math.floor((sec % 3600) / 60)).padStart(2, "0")} min`;
    return `${Math.round(sec / 86400)} days`;
  }
  function duration(sec) {
    sec = Number(sec);
    if (sec % 86400 === 0 && sec >= 86400) return `${sec / 86400} d`;
    if (sec % 3600 === 0 && sec >= 3600) return `${sec / 3600} h`;
    if (sec % 60 === 0 && sec >= 60) return `${sec / 60} min`;
    return `${sec} s`;
  }
  /** wei → token string, with 1 token = `unit` wei (default 1e12, §2.5). */
  function tokens(wei, unit) {
    const u = BigInt(unit), w = BigInt(wei);
    const whole = w / u, rest = w % u;
    if (rest === 0n) return whole.toLocaleString("en");
    const frac = (Number(rest) / Number(u)).toFixed(3).slice(1).replace(/0+$/, "");
    return whole.toLocaleString("en") + frac;
  }

  window.PULSE = {
    ABI, DEFAULT_RPC, DEAD, EXPLORERS, NETWORKS, DEFAULT_AGENT, STATE, OUTCOME, TIERS,
    SOURCES, sourceIndex, KNOWN_SIGNERS, BASE_FAILED, BASE, RULES,
    ruleNames, failedLabels, evaluate, requestHashFor, supplierKeyOf, digestOf, normalizeRecord, parseFields,
    tamper, decodeRevert, explain,
    esc, short, nowSec, clock, dayClock, ago, span, duration, tokens,
  };
})();
