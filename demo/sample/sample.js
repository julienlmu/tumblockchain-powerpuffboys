// Sample mode for demo/index.html (?sample=1): snapshots in the shape of the SupplierPulse+ view functions (§4.4, v1.1),
// plus the events each order would have emitted. Nothing here is read from a chain. A .js file rather than .json,
// so sample mode also works when the page is opened straight from disk (file:// cannot fetch JSON).
// Suppliers and signed fields are the real demo suppliers (docs/data-sources.md, api3/fixtures/); amounts, wallets,
// digests and times are illustrative. Times are relative to page load, so countdowns move. Every state appears:
// paid, permit valid, awaiting approval, not due, permit expired, held (refund pending / open to anyone),
// supplier-wide stop, no-data exit, refunded, fully paid, and the histories Standard, Trusted and Premium.
window.PULSE_SAMPLE = (now) => {
  const T = (n) => (BigInt(n) * 10n ** 12n).toString(); // tokens → wei (1 token = 1e12 wei, §2.5)
  const m = (x) => now + x * 60;                         // minutes from now
  const BUYER = "0xEb3EB6da882798062b30CeC11AAaDe306287ce41";
  const AGENT = "0xED3418aE93669a640650728E70f7aA712083253a";
  const SUP1 = "0x1111111111111111111111111111111111111111";
  const SUP2 = "0x2222222222222222222222222222222222222222";
  const CLEAN_CH = '{"accounts_overdue":false,"confirmation_overdue":false,"status":"active"}';
  const CLEAN_LEI = '{"entity_status":"ACTIVE","registration_status":"ISSUED"}';
  const LIQ = '{"accounts_overdue":true,"confirmation_overdue":true,"status":"liquidation"}';
  const dg = (n) => "0x" + n.repeat(64 / n.length).slice(0, 64); // illustrative digests
  const ev = (name, time, from, args) => ({ name, time, from, args });
  const NONE = { heldAt: 0, autoRefundAt: 0 };

  // Supplier records are shared by every order of the supplier (§2.4).
  const B_REC = { cleanStreak: 0, checks: 1, failures: 1, lastCountedAt: 0, lastCheckAt: m(-4), lastBaseFailureAt: m(-4) - 3, tier: 0 };

  return {
    agent: AGENT,
    maxAge: 300, tierCountGap: 300, refundGrace: 600,
    airnodes: ["0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF", "0x26d83124541e89ef28B9A5FB012B4B5f4097C20c"],
    orders: [
      {
        id: 0,
        info: { buyer: BUYER, supplier: SUP1, source: 0, supplierId: "03778796", orderRef: "PO-1001 Motor supply", permitTtl: 1800, rules: 0x06 },
        milestones: { amounts: [T(500), T(1000), T(1500)], dueDates: [m(-50), m(20), m(240)], approved: [true, true, false] },
        status: { state: 0, paid: T(500), remaining: T(2500), nextMilestone: 1, milestones: 3, permitValidUntil: m(-6) + 1800, permitValid: true, lastCheck: m(-6) },
        schedule: { nextDueDate: m(20), nextApproved: true, lastFailedRules: 0, ...NONE, tier: 2 },
        supplier: { cleanStreak: 7, checks: 7, failures: 0, lastCountedAt: m(-6), lastCheckAt: m(-6), lastBaseFailureAt: 0, tier: 2 },
        events: [
          ev("OrderCreated", m(-75), BUYER, { total: T(3000), rules: 0x06 }),
          ev("MilestoneApproved", m(-74), BUYER, { milestone: 0 }),
          ev("MilestoneApproved", m(-74), BUYER, { milestone: 1 }),
          ev("EvidenceAccepted", m(-50), AGENT, { clean: true, failedRules: 0, timestamp: m(-50) - 4, digest: dg("5a0c3be1"), submitter: AGENT, raw: CLEAN_CH }),
          ev("PermitIssued", m(-50), AGENT, { milestone: 0, amount: T(500), validUntil: m(-50) + 1800 }),
          ev("MilestonePaid", m(-50), AGENT, { milestone: 0, supplier: SUP1, amount: T(500) }),
          ev("TierChanged", m(-36), AGENT, { oldTier: 0, newTier: 1, cleanStreak: 3 }),
          ev("TierChanged", m(-18), AGENT, { oldTier: 1, newTier: 2, cleanStreak: 6 }),
          ev("EvidenceAccepted", m(-6), AGENT, { clean: true, failedRules: 0, timestamp: m(-6), digest: dg("9e8d7c6b"), submitter: AGENT, raw: CLEAN_CH }),
          ev("PermitIssued", m(-6), AGENT, { milestone: 1, amount: T(1000), validUntil: m(-6) + 1800 }),
        ],
      },
      {
        id: 1,
        info: { buyer: BUYER, supplier: SUP2, source: 0, supplierId: "07418033", orderRef: "PO-1002 Gearbox", permitTtl: 1800, rules: 0x06 },
        milestones: { amounts: [T(1000), T(2000)], dueDates: [m(-10), m(180)], approved: [true, false] },
        status: { state: 1, paid: "0", remaining: T(3000), nextMilestone: 0, milestones: 2, permitValidUntil: 0, permitValid: false, lastCheck: m(-4) - 3 },
        schedule: { nextDueDate: m(-10), nextApproved: true, lastFailedRules: 0x86, heldAt: m(-4), autoRefundAt: m(6), tier: 0 },
        supplier: B_REC,
        events: [
          ev("OrderCreated", m(-75), BUYER, { total: T(3000), rules: 0x06 }),
          ev("MilestoneApproved", m(-74), BUYER, { milestone: 0 }),
          ev("EvidenceAccepted", m(-4), AGENT, { clean: false, failedRules: 0x86, timestamp: m(-4) - 3, digest: dg("1c2b3a49"), submitter: AGENT, raw: LIQ }),
          ev("OrderHeld", m(-4), AGENT, { failedRules: 0x86, remaining: T(3000), autoRefundAt: m(6) }),
        ],
      },
      {
        id: 2,
        info: { buyer: BUYER, supplier: SUP1, source: 0, supplierId: "09729896", orderRef: "PO-1003 Sensors", permitTtl: 1800, rules: 0x02 },
        milestones: { amounts: [T(500), T(500)], dueDates: [m(-15), m(200)], approved: [true, false] },
        status: { state: 1, paid: "0", remaining: T(1000), nextMilestone: 0, milestones: 2, permitValidUntil: 0, permitValid: false, lastCheck: m(-21) },
        schedule: { nextDueDate: m(-15), nextApproved: true, lastFailedRules: 0x02, heldAt: m(-21), autoRefundAt: m(-11), tier: 0 },
        supplier: { cleanStreak: 1, checks: 1, failures: 0, lastCountedAt: m(-21), lastCheckAt: m(-21), lastBaseFailureAt: 0, tier: 0 },
        events: [
          ev("OrderCreated", m(-75), BUYER, { total: T(1000), rules: 0x02 }),
          ev("MilestoneApproved", m(-74), BUYER, { milestone: 0 }),
          ev("EvidenceAccepted", m(-21), AGENT, { clean: false, failedRules: 0x02, timestamp: m(-21) - 5, digest: dg("77aa66bb"), submitter: AGENT, raw: '{"accounts_overdue":true,"confirmation_overdue":true,"status":"active"}' }),
          ev("OrderHeld", m(-21), AGENT, { failedRules: 0x02, remaining: T(1000), autoRefundAt: m(-11) }),
        ],
      },
      {
        id: 3,
        info: { buyer: BUYER, supplier: SUP1, source: 1, supplierId: "391200JI69LS8L648F30", orderRef: "PO-1004 Cable harness (DE)", permitTtl: 1800, rules: 0x08 },
        milestones: { amounts: [T(500), T(1000)], dueDates: [m(-120), m(15)], approved: [true, true] },
        status: { state: 0, paid: T(500), remaining: T(1000), nextMilestone: 1, milestones: 2, permitValidUntil: m(-75) + 1800, permitValid: false, lastCheck: m(-75) },
        schedule: { nextDueDate: m(15), nextApproved: true, lastFailedRules: 0, ...NONE, tier: 1 },
        supplier: { cleanStreak: 4, checks: 4, failures: 0, lastCountedAt: m(-75), lastCheckAt: m(-75), lastBaseFailureAt: 0, tier: 1 },
        events: [
          ev("OrderCreated", m(-160), BUYER, { total: T(1500), rules: 0x08 }),
          ev("MilestoneApproved", m(-159), BUYER, { milestone: 0 }),
          ev("MilestoneApproved", m(-159), BUYER, { milestone: 1 }),
          ev("EvidenceAccepted", m(-120), AGENT, { clean: true, failedRules: 0, timestamp: m(-120) - 2, digest: dg("0f1e2d3c"), submitter: AGENT, raw: CLEAN_LEI }),
          ev("PermitIssued", m(-120), AGENT, { milestone: 0, amount: T(500), validUntil: m(-120) + 1800 }),
          ev("MilestonePaid", m(-120), AGENT, { milestone: 0, supplier: SUP1, amount: T(500) }),
          ev("TierChanged", m(-90), AGENT, { oldTier: 0, newTier: 1, cleanStreak: 3 }),
          ev("EvidenceAccepted", m(-75), AGENT, { clean: true, failedRules: 0, timestamp: m(-75), digest: dg("abcdef01"), submitter: AGENT, raw: CLEAN_LEI }),
          ev("PermitIssued", m(-75), AGENT, { milestone: 1, amount: T(1000), validUntil: m(-75) + 1800 }),
        ],
      },
      {
        id: 4,
        info: { buyer: BUYER, supplier: SUP2, source: 1, supplierId: "52990092KBQJF8QBGJ50", orderRef: "PO-1005 Castings", permitTtl: 1800, rules: 0x08 },
        milestones: { amounts: [T(500), T(500)], dueDates: [m(-40), m(160)], approved: [true, false] },
        status: { state: 2, paid: "0", remaining: "0", nextMilestone: 0, milestones: 2, permitValidUntil: 0, permitValid: false, lastCheck: m(-31) },
        schedule: { nextDueDate: 0, nextApproved: false, lastFailedRules: 0x08, heldAt: m(-31), autoRefundAt: 0, tier: 0 },
        supplier: { cleanStreak: 1, checks: 1, failures: 0, lastCountedAt: m(-31), lastCheckAt: m(-31), lastBaseFailureAt: 0, tier: 0 },
        events: [
          ev("OrderCreated", m(-75), BUYER, { total: T(1000), rules: 0x08 }),
          ev("MilestoneApproved", m(-74), BUYER, { milestone: 0 }),
          ev("EvidenceAccepted", m(-31), AGENT, { clean: false, failedRules: 0x08, timestamp: m(-31) - 2, digest: dg("2468ace0"), submitter: AGENT, raw: '{"entity_status":"ACTIVE","registration_status":"LAPSED"}' }),
          ev("OrderHeld", m(-31), AGENT, { failedRules: 0x08, remaining: T(1000), autoRefundAt: m(-21) }),
          ev("OrderRefunded", m(-20), AGENT, { buyer: BUYER, amount: T(1000), triggeredBy: AGENT, noDataExit: false }),
        ],
      },
      {
        id: 5,
        info: { buyer: BUYER, supplier: SUP2, source: 0, supplierId: "07418033", orderRef: "PO-1006 Gear shafts", permitTtl: 1800, rules: 0x04 },
        milestones: { amounts: [T(400), T(400)], dueDates: [m(30), m(300)], approved: [true, false] },
        status: { state: 0, paid: "0", remaining: T(800), nextMilestone: 0, milestones: 2, permitValidUntil: 0, permitValid: false, lastCheck: 0 },
        schedule: { nextDueDate: m(30), nextApproved: true, lastFailedRules: 0, ...NONE, tier: 0 },
        supplier: B_REC,
        events: [
          ev("OrderCreated", m(-60), BUYER, { total: T(800), rules: 0x04 }),
          ev("MilestoneApproved", m(-59), BUYER, { milestone: 0 }),
        ],
      },
      {
        id: 6,
        info: { buyer: BUYER, supplier: SUP1, source: 0, supplierId: "03778796", orderRef: "PO-1007 Mounting brackets", permitTtl: 1800, rules: 0x06 },
        milestones: { amounts: [T(300), T(300)], dueDates: [m(-8), m(120)], approved: [true, false] },
        status: { state: 0, paid: "0", remaining: T(600), nextMilestone: 0, milestones: 2, permitValidUntil: 0, permitValid: false, lastCheck: 0 },
        schedule: { nextDueDate: m(-8), nextApproved: true, lastFailedRules: 0, heldAt: 0, autoRefundAt: m(2), tier: 2 },
        supplier: { cleanStreak: 7, checks: 7, failures: 0, lastCountedAt: m(-6), lastCheckAt: m(-6), lastBaseFailureAt: 0, tier: 2 },
        events: [
          ev("OrderCreated", m(-90), BUYER, { total: T(600), rules: 0x06 }),
          ev("MilestoneApproved", m(-89), BUYER, { milestone: 0 }),
        ],
      },
      {
        id: 7,
        info: { buyer: BUYER, supplier: SUP2, source: 0, supplierId: "03778796", orderRef: "PO-1008 Fasteners", permitTtl: 1800, rules: 0x04 },
        milestones: { amounts: [T(300), T(300)], dueDates: [m(-110), m(-30)], approved: [true, true] },
        status: { state: 2, paid: T(600), remaining: "0", nextMilestone: 2, milestones: 2, permitValidUntil: 0, permitValid: false, lastCheck: m(-30) },
        schedule: { nextDueDate: 0, nextApproved: false, lastFailedRules: 0, ...NONE, tier: 2 },
        supplier: { cleanStreak: 7, checks: 7, failures: 0, lastCountedAt: m(-6), lastCheckAt: m(-6), lastBaseFailureAt: 0, tier: 2 },
        events: [
          ev("OrderCreated", m(-130), BUYER, { total: T(600), rules: 0x04 }),
          ev("MilestoneApproved", m(-129), BUYER, { milestone: 0 }),
          ev("MilestoneApproved", m(-129), BUYER, { milestone: 1 }),
          ev("EvidenceAccepted", m(-110), AGENT, { clean: true, failedRules: 0, timestamp: m(-110) - 2, digest: dg("13579bdf"), submitter: AGENT, raw: CLEAN_CH }),
          ev("MilestonePaid", m(-110), AGENT, { milestone: 0, supplier: SUP2, amount: T(300) }),
          ev("EvidenceAccepted", m(-30), AGENT, { clean: true, failedRules: 0, timestamp: m(-30) - 2, digest: dg("fedcba98"), submitter: AGENT, raw: CLEAN_CH }),
          ev("MilestonePaid", m(-30), AGENT, { milestone: 1, supplier: SUP2, amount: T(300) }),
        ],
      },
    ],
  };
};
