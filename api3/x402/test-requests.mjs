// Asserts the test vectors of docs/SUPPLIERPULSE_PLUS.md §4.2, and the local signer, verify and tamper tools (§4.7).
// Run: node api3/x402/test-requests.mjs
import assert from 'node:assert/strict';
import { buildRequest, evaluateRules, hashRequest, normalizeId, requestHash, supplierKey } from './requests.mjs';
import { signRecord } from './sign-local.mjs';
import { tamper } from './tamper.mjs';
import { verifyRecord } from './verify.mjs';

const CLEAN_CH = '{"accounts_overdue":false,"confirmation_overdue":false,"insolvency":false,"status":"active"}';
const failing = async (r) => (await verifyRecord(r, { local: true })).filter((x) => !x.ok).map((x) => x.check);

const tests = {
  'requestHash ch 09729896': () =>
    assert.equal(requestHash('ch', '09729896'), '0xde8d697c8cd5e5ead92f39da40c08b65459caf8ba0b60d4543b39369c65e7775'),
  'requestHash gleif TESTLEI0000000000000': () =>
    assert.equal(requestHash('gleif', 'TESTLEI0000000000000'), '0x82e8da1da50a59eb4941e8461f35869cb1a4a95183dc1ea84075b99af97d790f'),
  'supplierKey ch 09729896': () =>
    assert.equal(supplierKey('ch', '09729896'), '0xabf8d9a610a62d829c8b4ecdf8bee9db7988e3386692f4e1667c46a4698b3d2a'),
  'supplierKey gleif TESTLEI0000000000000': () =>
    assert.equal(supplierKey('gleif', 'TESTLEI0000000000000'), '0x31b072a73946faf810268129043fd17faebcf51b0756ab720dffc03eaaefe0f6'),
  'v1 one-field template (real signed sample)': () =>
    assert.equal(
      hashRequest({ operation: 'getCompanyProfile', parameters: { company_number: '09729896' }, responseProjection: { status: '/company_status' } }),
      '0xcae416f2dce5fb6bb595eafe8c5f11ce9df4b33f8664042e10f8f776739fab48'
    ),
  'key order of the body does not change the hash': () => {
    const body = buildRequest('ch', '09729896');
    const reversed = { ...body, responseProjection: Object.fromEntries(Object.entries(body.responseProjection).reverse()) };
    assert.equal(hashRequest(reversed), requestHash('ch', '09729896'));
  },
  'ids: uppercased, leading zeros kept, bad ones rejected': () => {
    assert.equal(normalizeId('ch', 'sc193794'), 'SC193794');
    assert.equal(normalizeId('ch', '00000001'), '00000001');
    for (const bad of ['', '12345678901', 'AB-123']) assert.throws(() => normalizeId('ch', bad));
    assert.throws(() => normalizeId('gleif', 'TESTLEI000000000000')); // 19 characters
    assert.throws(() => normalizeId('nope', '1'));
  },
  'rules: clean and each failure': () => {
    const clean = { accounts_overdue: false, confirmation_overdue: false, insolvency: false, status: 'active' };
    assert.deepEqual(evaluateRules('ch', clean, 0x07), { failedRules: 0, labels: [] });
    assert.equal(evaluateRules('ch', { ...clean, insolvency: true }, 0x07).failedRules, 0x01);
    assert.equal(evaluateRules('ch', { ...clean, accounts_overdue: true }, 0x07).failedRules, 0x02);
    assert.equal(evaluateRules('ch', { ...clean, confirmation_overdue: true }, 0x07).failedRules, 0x04);
    assert.equal(evaluateRules('ch', { ...clean, accounts_overdue: true }, 0x01).failedRules, 0); // rule disabled
    const liquidation = { accounts_overdue: true, confirmation_overdue: false, insolvency: true, status: 'liquidation' };
    assert.deepEqual(evaluateRules('ch', liquidation, 0x07), {
      failedRules: 0x83,
      labels: ['registry status not active', 'insolvency history', 'accounts overdue'],
    });
    assert.equal(evaluateRules('gleif', { entity_status: 'ACTIVE', registration_status: 'ISSUED' }, 0x08).failedRules, 0);
    assert.equal(evaluateRules('gleif', { entity_status: 'ACTIVE', registration_status: 'LAPSED' }, 0x08).failedRules, 0x08);
    assert.equal(evaluateRules('gleif', { entity_status: 'INACTIVE', registration_status: 'ISSUED' }, 0x08).failedRules, 0x80);
  },
  'local record verifies with --local only': async () => {
    const r = await signRecord('ch', '01234567', CLEAN_CH);
    assert.deepEqual(await failing(r), []);
    assert.deepEqual((await verifyRecord(r)).filter((x) => !x.ok).map((x) => x.check), ['signer']);
  },
  'tamper modes break the expected checks': async () => {
    const r = await signRecord('ch', '01234567', CLEAN_CH);
    const t = async (mode) => (await tamper(r, mode)).record;
    const value = await t('value');
    assert.equal(value.raw, CLEAN_CH.replace('"active"', '"liquidation"'));
    assert.equal(value.signature, r.signature);
    assert.deepEqual(await failing(value), ['signer']);
    assert.deepEqual(await failing(await t('stale')), ['signer', 'fresh']);
    assert.deepEqual(await failing(await t('request')), ['signer', 'request']);
    assert.deepEqual(await failing(await t('key')), ['signer']);
    assert.deepEqual(await t('replay'), r);
  },
  'tamper value: GLEIF and boolean fallback': async () => {
    const g = await signRecord('gleif', 'TESTLEI0000000000000', '{"entity_status":"ACTIVE","registration_status":"ISSUED"}');
    assert.equal((await tamper(g, 'value')).record.raw, '{"entity_status":"INACTIVE","registration_status":"ISSUED"}');
    const b = await signRecord('ch', '01234567', '{"accounts_overdue":false,"insolvency":false}');
    assert.equal((await tamper(b, 'value')).record.raw, '{"accounts_overdue":true,"insolvency":false}');
  },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try {
    await fn();
    console.log(`ok   ${name}`);
  } catch (e) {
    failed++;
    console.log(`FAIL ${name}\n     ${e.message.split('\n').join('\n     ')}`);
  }
}
console.log(failed ? `${failed} failed` : `all ${Object.keys(tests).length} passed`);
process.exit(failed ? 1 : 0);
