// Shared by index.html (dashboard) and judge.html ("Try to break it").
// Everything here mirrors docs/SUPPLIERPULSE_PLUS.md v1.1: the ABI (§4.6), request hashes (§4.2), rules and labels (§4.3),
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
    "function applySupplierFailure(uint256 orderId)",
    "function refundRemaining(uint256 orderId)",
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

  // Finding the contract without configuration (§7.2 C3). Orhun's deployer deploys v2 at C3 with a plain CREATE, so
  // its address follows from the deployer's nonce. The newest contract that answers requestHashFor with the v1.1
  // test vector (§4.2) is SupplierPulse+ v1.1; nothing else can return that value.
  const V2_DEPLOYER = "0xEb3EB6da882798062b30CeC11AAaDe306287ce41";
  const V11_VECTOR = "0x6e84889a218993dcdaaa5e41a15b5b1bba283e48ca36763248620abbe2f17f0f"; // requestHashFor(0, "09729896")
  const V1_SEPOLIA = "0x91d7dbae109029b2b1245179a68ac362799674d7"; // v1, live since 30 Oct (§3.2), the fallback

  /** Newest SupplierPulse+ v1.1 deployed by `deployer` among its last `depth` nonces, or null. */
  async function discoverV2(provider, deployer = V2_DEPLOYER, depth = 80) {
    const nonce = await provider.getTransactionCount(deployer);
    const probe = new ethers.Contract(deployer, ["function requestHashFor(uint8 source, string supplierId) pure returns (bytes32)"], provider);
    for (let hi = nonce - 1; hi >= Math.max(0, nonce - depth); hi -= 10) {
      const batch = [];
      for (let n = hi; n > hi - 10 && n >= Math.max(0, nonce - depth); n--) batch.push(ethers.getCreateAddress({ from: deployer, nonce: n }));
      const hits = await Promise.all(batch.map(async (a) => {
        try { return (await provider.getCode(a)) !== "0x" && (await probe.attach(a).requestHashFor(0, "09729896")) === V11_VECTOR; }
        catch { return false; }
      }));
      const i = hits.indexOf(true);
      if (i >= 0) return batch[i];
    }
    return null;
  }

  // v1 (api3/src/SupplierPulse.sol): same submitEvidence and the same order of checks, one signer, status only.
  const ABI_V1 = [
    "function airnode() view returns (address)",
    "function maxAge() view returns (uint256)",
    "function ordersLength() view returns (uint256)",
    "function companyNumberOf(uint256) view returns (string)",
    "function orderInfo(uint256) view returns (address buyer, address supplier, bytes32 companyRequest, bytes32 orderRef, uint256 permitTtl, uint256[] amounts, bool[] approved)",
    "function orderStatus(uint256) view returns (uint8 state, uint256 paid, uint256 remaining, uint256 nextMilestone, uint256 milestones, uint256 permitValidUntil, bool permitValid, string lastStatus, uint256 lastCheck)",
    "function usedDigests(bytes32) view returns (bool)",
    "function submitEvidence(uint256 orderId, bytes32 requestHash, uint256 timestamp, bytes data, bytes signature) returns (bool active)",
    "error WrongSigner(address recovered)", "error WrongRequest(bytes32 got, bytes32 expected)",
    "error StaleResponse(uint256 timestamp, uint256 nowTs)", "error FutureResponse(uint256 timestamp, uint256 nowTs)",
    "error Replayed(bytes32 digest)", "error NotNewer(uint256 timestamp, uint256 lastCheck)",
    "error NotActive(uint8 state)", "error NotHeld()", "error BadOrder()", "error BadCompanyNumber()", "error NotAuthorized()",
    "error InvalidSignatureLength()", "error InvalidSignatureS()", "error InvalidSignatureV()", "error InvalidSigner()",
    "error KeyNotFound()", "error NoString()",
  ];
  const requestHashV1 = (id) => ethers.id(`["getCompanyProfile",[["company_number","${id}"]],[["status","/company_status"]]]`);

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

  // Order names. Orders store orderRef as bytes32; the team scripts use keccak256(name), which cannot be decoded, so
  // known names are matched by hash. LOCAL-<id> comes from api3/scripts/plus-local.sh; bytes32 strings decode directly.
  const DEMO_NAMES = ["PO-1001 Motor supply", "PO-1002 Gearbox", "PO-1003 Sensors", "PO-1004 Cable harness (DE)", "PO-1005 Castings", "PO-1"];
  function orderNamer(extra = []) {
    const byHash = {};
    for (const n of [...DEMO_NAMES, ...extra]) byHash[ethers.id(n).toLowerCase()] = n;
    return (ref, supplierId) => {
      if (!ref) return null;
      if (!String(ref).startsWith("0x")) return String(ref); // sample data holds the plain name
      const k = ref.toLowerCase();
      if (byHash[k]) return byHash[k];
      if (supplierId && ethers.id(`LOCAL-${supplierId}`).toLowerCase() === k) return `LOCAL-${supplierId}`;
      try { const s = ethers.decodeBytes32String(ref); if (s && /^[\x20-\x7e]+$/.test(s)) return s; } catch { /* not a bytes32 string */ }
      return null;
    };
  }

  const KNOWN_SIGNERS = {
    "0x392228e5cca260313e5ed337ed3561b59a1e4bff": "Companies House Airnode",
    "0x26d83124541e89ef28b9a5fb012b4b5f4097c20c": "GLEIF Airnode",
    "0x70997970c51812dc3a010c7d01b50e0d17dc79c8": "local Companies House key, anvil #1",
    "0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc": "local GLEIF key, anvil #2",
  };

  // §4.3. Base checks are always on; bit 0x80 in failedRules means the base check failed. 0x01 is reserved since v1.1.
  const BASE_FAILED = 0x80;
  const BASE = [
    { field: "status", clean: (v) => v === "active", label: "registry status not active", rule: "status active" },
    { field: "entity_status", clean: (v) => v === "ACTIVE", label: "LEI entity not active", rule: "LEI entity active" },
  ];
  const RULES = [
    { bit: 0x02, source: 0, field: "accounts_overdue", clean: (v) => v === false, label: "accounts overdue", rule: "accounts filed" },
    { bit: 0x04, source: 0, field: "confirmation_overdue", clean: (v) => v === false, label: "confirmation statement overdue", rule: "confirmation statement filed" },
    // LAPSED means the LEI was not renewed on time, not that the entity is inactive (§4.3)
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
  async function tamper(r, mode, opts = {}) {
    const out = { ...r };
    switch (mode) {
      case "value": {
        const { raw, what } = editValue(r.source, ethers.toUtf8String(r.data));
        out.raw = raw;
        out.data = ethers.hexlify(ethers.toUtf8Bytes(raw));
        return { record: out, what: `(a) Edit value: ${what}. The signature is unchanged.`, expect: "WrongSigner" };
      }
      case "stale":
        out.timestamp = String(BigInt(r.timestamp) - 3600n);
        return { record: out, what: `(b) Too old: timestamp ${r.timestamp} → ${out.timestamp} (one hour earlier).`, expect: "StaleResponse" };
      case "request": {
        const s = SOURCES[sourceIndex(r.source)];
        const id = String(r.supplierId || "").toUpperCase() === s.otherId ? s.otherIdAlt : s.otherId;
        out.requestHash = opts.requestHashFor ? opts.requestHashFor(id) : requestHashFor(sourceIndex(r.source), id);
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
        return { record: out, what: "Submit as is: the record untouched.", expect: null };
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
    const t = (x) => dayClockS(x);
    switch (name) {
      case "WrongSigner": return `The signature recovers to ${a[0]}, not the Airnode this contract trusts for this registry${ctx.expectedSigner ? ` (${ctx.expectedSigner})` : ""}. Any edit of the signed bytes, or a different key, changes the recovered address.`;
      case "WrongRequest": return "The response answers a different request (another company, operation or projection) than the one this order was built for.";
      case "StaleResponse": return `The response was signed at ${t(a[0])}, more than the contract's maximum age (maxAge) before the chain's time ${t(a[1])}. Old evidence cannot pay today's milestone.`;
      case "FutureResponse": return `The timestamp ${t(a[0])} lies more than 60 s in the future of the chain's time ${t(a[1])}.`;
      case "Replayed": return "This exact signed response was already used once. Each record can move the order only once.";
      case "NotNewer": return "The order already accepted a record signed at the same time or later. Older evidence cannot overwrite newer evidence.";
      case "NotActive": return `The order is ${STATE[Number(a[0])] || "not active"}: a held or closed order accepts no new evidence.`;
      case "BadOrder": return "There is no order with this id.";
      case "InvalidSignatureLength": case "InvalidSignatureS": case "InvalidSignatureV": case "InvalidSigner":
        return "The signature bytes are malformed, so no signer can be recovered.";
      case "KeyNotFound": case "NoString": case "NoBool": case "NoNumber":
        return "A field the order's rules need is missing or has the wrong type in the signed data. Without it the order can never pay (fail-safe).";
      case "SupplierFailed": return `This supplier's register status failed in a record signed at ${t(a[0])}. A clean record older than that failure cannot pay, on any order of the supplier.`;
      case "NoNewerFailure": return "This supplier has no register failure newer than the order's last record, so there is nothing to apply.";
      case "NotHeld": return "Only a held order can be refunded.";
      case "BadCompanyNumber": return "The company number is not 1 to 10 characters of 0-9 and A-Z.";
      case "NotRefundable": return "Nothing to refund: the order is closed, or it still has a valid permit.";
      case "RefundNotYet": return `Not yet: from ${t(a[0])} anyone can send the remaining balance back to the buyer.`;
      case "NotAuthorized": return "Only the buyer may do this now; anyone may once the grace period ends.";
      case "NotApproved": return "The buyer has not approved this milestone yet.";
      case "NotDue": return "This milestone is not due yet.";
      case "NoValidPermit": return "There is no valid payment permit for this milestone: it needs a fresh signed record first.";
      case "PermitExpired": return "The payment permit has expired: it needs a fresh signed record first.";
      case "TransferFailed": return "The contract could not send the money: the receiving wallet refused the transfer. Nothing changed.";
      case "BadSource": return "The registry of this order is unknown to the contract.";
      case "BadSupplierId": return "The supplier id has the wrong format for its registry.";
      case "BadRules": return "These rules do not exist for this registry.";
      default: return "";
    }
  }

  // ---------------------------------------------------------------- formatting

  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const short = (h) => (h && h.length > 14 ? h.slice(0, 6) + "…" + h.slice(-4) : h);
  const nowSec = () => Math.floor(Date.now() / 1000);
  const clock = (ts) => new Date(Number(ts) * 1000).toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
  const dayClock = (ts) => new Date(Number(ts) * 1000).toLocaleString("en-GB", { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
  const dayClockS = (ts) => new Date(Number(ts) * 1000).toLocaleString("en-GB", { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit", second: "2-digit" });

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
    if (sec < 3600) return `${Math.floor(sec / 60)} min ${String(sec % 60).padStart(2, "0")} s`;
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

  /** Plain words for a failed RPC or wallet call: { kind: "wallet" | "network" | "address" | "other", text }. */
  function friendlyError(e, ctx = {}) {
    const code = e && (e.code || (e.error && e.error.code) || (e.info && e.info.error && e.info.error.code));
    const msg = (e && (e.shortMessage || e.message)) || String(e);
    if (code === "ACTION_REJECTED" || code === 4001 || /user (rejected|denied)/i.test(msg)) return { kind: "wallet", text: "You cancelled in the wallet. Nothing was sent." };
    if (code === "INSUFFICIENT_FUNDS") return { kind: "wallet", text: "The wallet has too little ETH to pay the gas. Nothing was sent." };
    const m = msg.match(/no contract at (0x[0-9a-fA-F]{40}) on chain (\d+)/);
    if (m) return { kind: "address", text: `There is no contract at ${short(m[1])} on ${NETWORKS[m[2]] || "chain " + m[2]}. Check the address, or the RPC URL if the contract lives on another network.` };
    if (["NETWORK_ERROR", "TIMEOUT", "SERVER_ERROR"].includes(code) || /failed to fetch|fetch failed|ECONNREFUSED|network|timeout|could not detect/i.test(msg))
      return { kind: "network", text: `The RPC${ctx.rpc ? " " + ctx.rpc : ""} did not answer. Check the RPC URL in Settings, or try again in a moment.` };
    // reading a contract that has code but not SupplierPulse+ v1.1's functions (for example the v1 contract)
    if (ctx.reading && (code === "BAD_DATA" || (code === "CALL_EXCEPTION" && !(e.data && e.data !== "0x"))))
      return { kind: "address", notV2: true, text: `This address answers, but not as SupplierPulse+ v1.1${ctx.contract ? ` (${short(ctx.contract)})` : ""}. If it is the v1 contract, open the v1 screen; otherwise check the address in Settings.` };
    return { kind: "other", text: msg };
  }

  // ---------------------------------------------------------------- icons (presentation only)

  // One authored inline-SVG set: 24 grid, stroke 2 (base.css .i), aria-hidden; the text label is always kept next to it.
  const ICONS = {
    check: '<path d="M20 6 9 17l-5-5"/>',
    x: '<path d="M18 6 6 18M6 6l12 12"/>',
    lock: '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    alert: '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4M12 17h.01"/>',
    stop: '<path d="M7.9 2h8.2L22 7.9v8.2L16.1 22H7.9L2 16.1V7.9z"/><path d="M8 12h8"/>',
    play: '<path d="M7 4.5v15a.8.8 0 0 0 1.2.7l12-7.5a.8.8 0 0 0 0-1.4l-12-7.5A.8.8 0 0 0 7 4.5z"/>',
    "arrow-right": '<path d="M5 12h14M13 6l6 6-6 6"/>',
    "arrow-left": '<path d="M19 12H5M11 18l-6-6 6-6"/>',
    theme: '<circle cx="12" cy="12" r="9"/><path d="M12 3v18" /><path d="M12 3a9 9 0 0 1 0 18z" fill="currentColor"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    link: '<path d="M9 17H7A5 5 0 0 1 7 7h2M15 7h2a5 5 0 0 1 0 10h-2M8 12h8"/>',
    shield: '<path d="M12 3 4 6v6c0 4.5 3.4 8.3 8 9 4.6-.7 8-4.5 8-9V6z"/><path d="m9 12 2 2 4-4"/>',
    target: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/>',
    minus: '<path d="M5 12h14"/>',
    loader: '<path d="M21 12a9 9 0 1 1-6.2-8.6"/>',
    refund: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/>',
    upload: '<path d="M12 15V3M7 8l5-5 5 5"/><path d="M4 15v4a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-4"/>',
    key: '<circle cx="7.5" cy="15.5" r="4.5"/><path d="m10.7 12.3 9.3-9.3M17 6l3 3M14 9l2 2"/>',
    agent: '<rect x="4" y="8" width="16" height="12" rx="3"/><path d="M12 4v4M9 13v2M15 13v2"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 16v-5M12 8h.01"/>',
    send: '<path d="m22 2-7 20-4-9-9-4z"/><path d="M22 2 11 13"/>',
    file: '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/>',
    copy: '<rect x="9" y="9" width="12" height="12" rx="2"/><path d="M5 15H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v1"/>',
    help: '<circle cx="12" cy="12" r="9"/><path d="M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3M12 17h.01"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>',
  };
  const icon = (name, cls = "") => `<svg class="i${cls ? " " + cls : ""}" viewBox="0 0 24 24" aria-hidden="true" focusable="false">${ICONS[name] || ""}</svg>`;
  /** Puts the icon named in data-icon in front of each static element's label. */
  function hydrateIcons(root = document) {
    for (const el of root.querySelectorAll("[data-icon]")) {
      if (el.querySelector(":scope > svg.i")) continue;
      el.insertAdjacentHTML(el.dataset.iconEnd ? "beforeend" : "afterbegin", icon(el.dataset.icon));
    }
  }

  // ---------------------------------------------------------------- copy to the clipboard (presentation only)

  /** A small Copy button for a command, address or JSON. Wired once by the click listener below. */
  const copyBtn = (text, label = "Copy") => `<button type="button" class="copy" data-copy="${esc(text)}" aria-label="${esc(label)}: ${esc(text.length > 40 ? text.slice(0, 40) + "…" : text)}">${icon("copy")}<span>${esc(label)}</span></button>`;
  async function copyText(t) {
    try { await navigator.clipboard.writeText(t); return true; } catch { /* file:// or no permission: fall back */ }
    const ta = Object.assign(document.createElement("textarea"), { value: t });
    ta.style.cssText = "position:fixed;opacity:0";
    document.body.append(ta); ta.select();
    let ok = false;
    try { ok = document.execCommand("copy"); } catch { /* not supported */ }
    ta.remove();
    return ok;
  }
  /** Shows a short confirmation in the button's label, then restores it. */
  function flashLabel(btn, text) {
    const l = btn.querySelector("span") || btn;
    if (!btn.dataset.label) btn.dataset.label = l.textContent;
    l.textContent = text;
    clearTimeout(btn._t);
    btn._t = setTimeout(() => { l.textContent = btn.dataset.label; }, 1600);
  }
  document.addEventListener("click", async (e) => {
    const b = e.target.closest && e.target.closest("[data-copy]");
    if (b) flashLabel(b, (await copyText(b.dataset.copy)) ? "Copied" : "Select and copy");
  });

  // ---------------------------------------------------------------- settings form checks (presentation only)

  const FIELD_RULES = {
    contract: [/^(0x[0-9a-fA-F]{40})?$/, "0x followed by 40 hex characters"],
    agent: [/^(0x[0-9a-fA-F]{40})?$/, "0x followed by 40 hex characters"],
    rpc: [/^https?:\/\/\S+$/, "a URL that starts with http:// or https://"],
    orders: [/^(\d+(\s*,\s*\d+)*)?$/, "order numbers separated by commas, for example 0,1,2"],
    from: [/^\d*$/, "a block number, digits only"],
    unit: [/^([1-9]\d*)?$/, "a whole number above 0"],
  };
  /** Checks each settings field as it is typed: the message sits under the field, and submit stays off until all are valid. */
  function wireSettings(form) {
    const submit = form.querySelector('[type="submit"]');
    const check = () => {
      let ok = true;
      for (const el of form.elements) {
        const rule = FIELD_RULES[el.name];
        if (!rule) continue;
        const bad = !rule[0].test(el.value.trim());
        ok = ok && !bad;
        let msg = el.parentElement.querySelector(".field-err");
        if (!msg) { msg = Object.assign(document.createElement("span"), { className: "field-err", id: `err-${form.id}-${el.name}` }); el.after(msg); }
        msg.textContent = bad ? `Expected ${rule[1]}.` : "";
        if (bad) { el.setAttribute("aria-invalid", "true"); el.setAttribute("aria-describedby", msg.id); }
        else if (!el.dataset.serverError) { el.removeAttribute("aria-invalid"); el.removeAttribute("aria-describedby"); }
      }
      if (submit) submit.disabled = !ok;
      return ok;
    };
    form.addEventListener("input", (e) => { if (e.target.dataset) delete e.target.dataset.serverError; check(); });
    check();
    return check;
  }
  /** Marks one settings field as the cause of a load error, with the message under it. */
  function markField(form, name, text) {
    const el = form.elements[name];
    if (!el) return;
    el.dataset.serverError = "1";
    el.setAttribute("aria-invalid", "true");
    let msg = el.parentElement.querySelector(".field-err");
    if (!msg) { msg = Object.assign(document.createElement("span"), { className: "field-err", id: `err-${form.id}-${name}` }); el.after(msg); }
    msg.textContent = text;
    el.setAttribute("aria-describedby", msg.id);
  }

  window.PULSE = {
    wireSettings, markField,
    copyBtn, copyText, flashLabel,
    icon, hydrateIcons,
    ABI, ABI_V1, V2_DEPLOYER, V11_VECTOR, V1_SEPOLIA, discoverV2, requestHashV1, DEFAULT_RPC, DEAD, EXPLORERS, NETWORKS, DEFAULT_AGENT, STATE, OUTCOME, TIERS,
    SOURCES, sourceIndex, KNOWN_SIGNERS, BASE_FAILED, BASE, RULES,
    ruleNames, failedLabels, evaluate, requestHashFor, supplierKeyOf, digestOf, normalizeRecord, parseFields,
    tamper, decodeRevert, explain, friendlyError,
    esc, short, nowSec, clock, dayClock, dayClockS, ago, span, duration, tokens, orderNamer, DEMO_NAMES,
  };
})();
