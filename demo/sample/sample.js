// Sample mode for demo/index.html (?sample=1): snapshots in the shape of the SupplierPulse+ view functions (§4.4),
// plus the events each order would have emitted. Nothing here is read from a chain. A .js file rather than .json,
// so sample mode also works when the page is opened straight from disk (file:// cannot fetch JSON).
// Times are relative to page load, so countdowns move. Every state the dashboard renders appears at least once:
// paid, permit valid, awaiting approval, not due, permit expired, held (refund pending / open to anyone),
// refunded, fully paid, and the tiers Standard, Trusted and Premium.
window.PULSE_SAMPLE = (now) => {
  const T = (n) => (BigInt(n) * 10n ** 12n).toString(); // tokens → wei (1 token = 1e12 wei, §2.5)
  const m = (x) => now + x * 60;                         // minutes from now
  const BUYER = "0xEb3EB6da882798062b30CeC11AAaDe306287ce41";
  const AGENT = "0xED3418aE93669a640650728E70f7aA712083253a";
  const SUP1 = "0x1111111111111111111111111111111111111111";
  const SUP2 = "0x2222222222222222222222222222222222222222";
  const CLEAN_CH = '{"accounts_overdue":false,"confirmation_overdue":false,"insolvency":false,"status":"active"}';
  const CLEAN_LEI = '{"entity_status":"ACTIVE","registration_status":"ISSUED"}';
  const ev = (name, time, from, args) => ({ name, time, from, args });

  return {
    agent: AGENT,
    maxAge: 300, tierCountGap: 300, refundGrace: 600,
    airnodes: ["0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF", "0x26d83124541e89ef28B9A5FB012B4B5f4097C20c"],
    orders: [
      {
        id: 0,
        info: { buyer: BUYER, supplier: SUP1, source: 0, supplierId: "09729896", orderRef: "PO-1001 Motor supply", permitTtl: 1800, rules: 0x07 },
        milestones: { amounts: [T(500), T(1000), T(1500)], dueDates: [m(-50), m(40), m(240)], approved: [true, true, false] },
        status: { state: 0, paid: T(500), remaining: T(2500), nextMilestone: 1, milestones: 3, permitValidUntil: m(-6) + 7200, permitValid: true, lastCheck: m(-6) },
        schedule: { nextDueDate: m(40), nextApproved: true, lastFailedRules: 0, heldAt: 0, autoRefundAt: 0, tier: 2 },
        supplier: { cleanStreak: 7, checks: 7, failures: 0, lastCountedAt: m(-6), lastCheckAt: m(-6), tier: 2 },
        effectivePermitTtl: 7200,
        events: [
          ev("OrderCreated", m(-75), BUYER, { total: T(3000), rules: 0x07 }),
          ev("MilestoneApproved", m(-74), BUYER, { milestone: 0 }),
          ev("MilestoneApproved", m(-74), BUYER, { milestone: 1 }),
          ev("EvidenceAccepted", m(-50), AGENT, { clean: true, failedRules: 0, timestamp: m(-50) - 4, digest: "0x5a0c3be1d1c1f0f1e4f6f2b2c6b3c3e6d0a4c1b2e3f405162738495a6b7c8d9e", submitter: AGENT, raw: CLEAN_CH }),
          ev("PermitIssued", m(-50), AGENT, { milestone: 0, amount: T(500), validUntil: m(-50) + 1800 }),
          ev("MilestonePaid", m(-50), AGENT, { milestone: 0, supplier: SUP1, amount: T(500) }),
          ev("TierChanged", m(-36), AGENT, { oldTier: 0, newTier: 1, cleanStreak: 3 }),
          ev("TierChanged", m(-18), AGENT, { oldTier: 1, newTier: 2, cleanStreak: 6 }),
          ev("EvidenceAccepted", m(-6), AGENT, { clean: true, failedRules: 0, timestamp: m(-6), digest: "0x9e8d7c6b5a49382716051f2e3d4c5b6a79881726354a5b6c7d8e9f0a1b2c3d4e", submitter: AGENT, raw: CLEAN_CH }),
          ev("PermitIssued", m(-6), AGENT, { milestone: 1, amount: T(1000), validUntil: m(-6) + 7200 }),
        ],
      },
      {
        id: 1,
        info: { buyer: BUYER, supplier: SUP2, source: 0, supplierId: "07418033", orderRef: "PO-1002 Gearbox", permitTtl: 1800, rules: 0x07 },
        milestones: { amounts: [T(1000), T(2000)], dueDates: [m(-10), m(180)], approved: [true, false] },
        status: { state: 1, paid: "0", remaining: T(3000), nextMilestone: 0, milestones: 2, permitValidUntil: 0, permitValid: false, lastCheck: m(-4) },
        schedule: { nextDueDate: m(-10), nextApproved: true, lastFailedRules: 0x83, heldAt: m(-4), autoRefundAt: m(6), tier: 0 },
        supplier: { cleanStreak: 0, checks: 1, failures: 1, lastCountedAt: 0, lastCheckAt: m(-4), tier: 0 },
        effectivePermitTtl: 1800,
        events: [
          ev("OrderCreated", m(-75), BUYER, { total: T(3000), rules: 0x07 }),
          ev("MilestoneApproved", m(-74), BUYER, { milestone: 0 }),
          ev("EvidenceAccepted", m(-4), AGENT, { clean: false, failedRules: 0x83, timestamp: m(-4) - 3, digest: "0x1c2b3a4958677685940a1b2c3d4e5f60718293a4b5c6d7e8f9011223344556677", submitter: AGENT, raw: '{"accounts_overdue":true,"confirmation_overdue":false,"insolvency":true,"status":"liquidation"}' }),
          ev("OrderHeld", m(-4), AGENT, { failedRules: 0x83, remaining: T(3000), autoRefundAt: m(6) }),
        ],
      },
      {
        id: 2,
        info: { buyer: BUYER, supplier: SUP1, source: 0, supplierId: "SAMPLE03", orderRef: "PO-1003 Sensors", permitTtl: 1800, rules: 0x02 },
        milestones: { amounts: [T(500), T(500)], dueDates: [m(-15), m(200)], approved: [true, false] },
        status: { state: 1, paid: "0", remaining: T(1000), nextMilestone: 0, milestones: 2, permitValidUntil: 0, permitValid: false, lastCheck: m(-21) },
        schedule: { nextDueDate: m(-15), nextApproved: true, lastFailedRules: 0x02, heldAt: m(-21), autoRefundAt: m(-11), tier: 0 },
        supplier: { cleanStreak: 0, checks: 1, failures: 1, lastCountedAt: 0, lastCheckAt: m(-21), tier: 0 },
        effectivePermitTtl: 1800,
        events: [
          ev("OrderCreated", m(-75), BUYER, { total: T(1000), rules: 0x02 }),
          ev("MilestoneApproved", m(-74), BUYER, { milestone: 0 }),
          ev("EvidenceAccepted", m(-21), AGENT, { clean: false, failedRules: 0x02, timestamp: m(-21) - 5, digest: "0x77aa66bb55cc44dd33ee22ff1100998877665544332211ffeeddccbbaa009988", submitter: AGENT, raw: '{"accounts_overdue":true,"confirmation_overdue":false,"insolvency":false,"status":"active"}' }),
          ev("OrderHeld", m(-21), AGENT, { failedRules: 0x02, remaining: T(1000), autoRefundAt: m(-11) }),
        ],
      },
      {
        id: 3,
        info: { buyer: BUYER, supplier: SUP1, source: 1, supplierId: "TESTLEI0000000000000", orderRef: "PO-1004 Cable harness (DE)", permitTtl: 1800, rules: 0x08 },
        milestones: { amounts: [T(500), T(1000)], dueDates: [m(-120), m(15)], approved: [true, true] },
        status: { state: 0, paid: T(500), remaining: T(1000), nextMilestone: 1, milestones: 2, permitValidUntil: m(-75) + 3600, permitValid: false, lastCheck: m(-75) },
        schedule: { nextDueDate: m(15), nextApproved: true, lastFailedRules: 0, heldAt: 0, autoRefundAt: 0, tier: 1 },
        supplier: { cleanStreak: 4, checks: 4, failures: 0, lastCountedAt: m(-75), lastCheckAt: m(-75), tier: 1 },
        effectivePermitTtl: 3600,
        events: [
          ev("OrderCreated", m(-160), BUYER, { total: T(1500), rules: 0x08 }),
          ev("MilestoneApproved", m(-159), BUYER, { milestone: 0 }),
          ev("MilestoneApproved", m(-159), BUYER, { milestone: 1 }),
          ev("EvidenceAccepted", m(-120), AGENT, { clean: true, failedRules: 0, timestamp: m(-120) - 2, digest: "0x0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4c3d2e1f0", submitter: AGENT, raw: CLEAN_LEI }),
          ev("PermitIssued", m(-120), AGENT, { milestone: 0, amount: T(500), validUntil: m(-120) + 1800 }),
          ev("MilestonePaid", m(-120), AGENT, { milestone: 0, supplier: SUP1, amount: T(500) }),
          ev("TierChanged", m(-90), AGENT, { oldTier: 0, newTier: 1, cleanStreak: 3 }),
          ev("EvidenceAccepted", m(-75), AGENT, { clean: true, failedRules: 0, timestamp: m(-75), digest: "0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789", submitter: AGENT, raw: CLEAN_LEI }),
          ev("PermitIssued", m(-75), AGENT, { milestone: 1, amount: T(1000), validUntil: m(-75) + 3600 }),
        ],
      },
      {
        id: 4,
        info: { buyer: BUYER, supplier: SUP2, source: 1, supplierId: "TESTLEI0000000000001", orderRef: "PO-1005 Castings", permitTtl: 1800, rules: 0x08 },
        milestones: { amounts: [T(500), T(500)], dueDates: [m(-40), m(160)], approved: [true, false] },
        status: { state: 2, paid: "0", remaining: "0", nextMilestone: 0, milestones: 2, permitValidUntil: 0, permitValid: false, lastCheck: m(-31) },
        schedule: { nextDueDate: 0, nextApproved: false, lastFailedRules: 0x08, heldAt: m(-31), autoRefundAt: 0, tier: 0 },
        supplier: { cleanStreak: 0, checks: 1, failures: 1, lastCountedAt: 0, lastCheckAt: m(-31), tier: 0 },
        effectivePermitTtl: 1800,
        events: [
          ev("OrderCreated", m(-75), BUYER, { total: T(1000), rules: 0x08 }),
          ev("MilestoneApproved", m(-74), BUYER, { milestone: 0 }),
          ev("EvidenceAccepted", m(-31), AGENT, { clean: false, failedRules: 0x08, timestamp: m(-31) - 2, digest: "0x2468ace02468ace02468ace02468ace02468ace02468ace02468ace02468ace0", submitter: AGENT, raw: '{"entity_status":"ACTIVE","registration_status":"LAPSED"}' }),
          ev("OrderHeld", m(-31), AGENT, { failedRules: 0x08, remaining: T(1000), autoRefundAt: m(-21) }),
          ev("OrderRefunded", m(-20), AGENT, { buyer: BUYER, amount: T(1000), triggeredBy: AGENT }),
        ],
      },
      {
        id: 5,
        info: { buyer: BUYER, supplier: SUP2, source: 0, supplierId: "01234567", orderRef: "PO-1006 Fasteners", permitTtl: 1800, rules: 0x01 },
        milestones: { amounts: [T(300), T(300)], dueDates: [m(-110), m(-30)], approved: [true, true] },
        status: { state: 2, paid: T(600), remaining: "0", nextMilestone: 2, milestones: 2, permitValidUntil: 0, permitValid: false, lastCheck: m(-30) },
        schedule: { nextDueDate: 0, nextApproved: false, lastFailedRules: 0, heldAt: 0, autoRefundAt: 0, tier: 1 },
        supplier: { cleanStreak: 3, checks: 3, failures: 0, lastCountedAt: m(-30), lastCheckAt: m(-30), tier: 1 },
        effectivePermitTtl: 3600,
        events: [
          ev("OrderCreated", m(-130), BUYER, { total: T(600), rules: 0x01 }),
          ev("MilestoneApproved", m(-129), BUYER, { milestone: 0 }),
          ev("MilestoneApproved", m(-129), BUYER, { milestone: 1 }),
          ev("EvidenceAccepted", m(-110), AGENT, { clean: true, failedRules: 0, timestamp: m(-110) - 2, digest: "0x13579bdf13579bdf13579bdf13579bdf13579bdf13579bdf13579bdf13579bdf", submitter: AGENT, raw: CLEAN_CH }),
          ev("MilestonePaid", m(-110), AGENT, { milestone: 0, supplier: SUP2, amount: T(300) }),
          ev("TierChanged", m(-30), AGENT, { oldTier: 0, newTier: 1, cleanStreak: 3 }),
          ev("EvidenceAccepted", m(-30), AGENT, { clean: true, failedRules: 0, timestamp: m(-30) - 2, digest: "0xfedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210", submitter: AGENT, raw: CLEAN_CH }),
          ev("MilestonePaid", m(-30), AGENT, { milestone: 1, supplier: SUP2, amount: T(300) }),
        ],
      },
    ],
  };
};
