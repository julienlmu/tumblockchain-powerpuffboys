// Off-chain checks of a signed record (§4.1), the same ones the contract runs before it acts.
// Usage: node verify.mjs <file> [--max-age 300] [--local]
//   --local also accepts the local Airnode signers (anvil #1 / #2) for that source.
// Exit: 0 valid, 1 invalid, 2 usage
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { hexToString, isAddressEqual, isHex, recoverMessageAddress } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { RULES, evaluateRules, requestHash, sourceOf } from './requests.mjs';
import { LOCAL_KEYS, digestOf } from './sign-local.mjs';

const MAX_FUTURE_SKEW = 60;

// Reads a §4.1 file. `source` falls back to what the signed fields look like, for files without it.
export function loadRecord(file) {
  const r = JSON.parse(readFileSync(file, 'utf8'));
  for (const k of ['requestHash', 'timestamp', 'data', 'signature']) {
    if (r[k] === undefined || r[k] === null) throw new Error(`${file}: missing "${k}"`);
  }
  if (!isHex(r.data)) throw new Error(`${file}: "data" must be the hex of the signed bytes`);
  r.timestamp = String(r.timestamp);
  const signed = hexToString(r.data);
  if (!r.source) r.source = /"entity_status":/.test(signed) ? 'gleif' : 'ch';
  return r;
}

// Runs every check and returns [{check, ok, detail}].
export async function verifyRecord(r, { maxAge = 300, local = false, now = Math.floor(Date.now() / 1000) } = {}) {
  const s = sourceOf(r.source);
  const results = [];
  const add = (check, ok, detail) => results.push({ check, ok, detail });

  const signer = await recoverMessageAddress({
    message: { raw: digestOf(r.requestHash, r.timestamp, r.data) },
    signature: r.signature,
  }).catch((e) => e);
  const allowed = [s.signer, ...(local ? [privateKeyToAccount(LOCAL_KEYS[r.source]).address] : [])];
  if (signer instanceof Error) add('signer', false, `signature does not recover: ${signer.shortMessage ?? signer.message}`);
  else add('signer', allowed.some((a) => isAddressEqual(a, signer)), `recovered ${signer}, expected ${allowed.join(' or ')}`);

  if (r.supplierId) {
    const expected = requestHash(r.source, r.supplierId);
    add('request', r.requestHash === expected, `${r.requestHash}${r.requestHash === expected ? '' : `, expected ${expected}`} (${r.source} ${r.supplierId})`);
  } else {
    add('request', false, 'no supplierId in the file, so the request cannot be checked');
  }

  const age = now - Number(r.timestamp);
  if (age < -MAX_FUTURE_SKEW) add('fresh', false, `${-age} s in the future (max ${MAX_FUTURE_SKEW})`);
  else add('fresh', age <= maxAge, `${age} s old (max ${maxAge})`);

  const signed = hexToString(r.data);
  let fields;
  try {
    fields = JSON.parse(signed);
  } catch {
    fields = null;
  }
  const missing = fields ? Object.keys(s.projection).filter((k) => !(k in fields)) : Object.keys(s.projection);
  add('fields', missing.length === 0, fields ? (missing.length ? `missing ${missing.join(', ')}` : signed) : 'signed data is not JSON');
  if (r.raw !== undefined && r.raw !== signed) add('raw', true, 'note: "raw" differs from "data"; only "data" is signed and submitted');

  if (fields && missing.length === 0) {
    const allRules = RULES.filter((x) => x.source === r.source).reduce((m, x) => m | x.bit, 0);
    const { labels } = evaluateRules(r.source, fields, allRules);
    add('rules', true, labels.length ? `with all rules on, would be held: ${labels.join(', ')}` : 'clean with all rules on');
  }
  return results;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  const file = args.find((a) => !a.startsWith('--') && args[args.indexOf(a) - 1] !== '--max-age');
  const maxAgeArg = args.includes('--max-age') ? args[args.indexOf('--max-age') + 1] : '300';
  if (!file || !/^\d+$/.test(maxAgeArg ?? '')) {
    console.error('usage: node verify.mjs <file> [--max-age 300] [--local]');
    process.exit(2);
  }
  let results;
  try {
    results = await verifyRecord(loadRecord(file), { maxAge: Number(maxAgeArg), local: args.includes('--local') });
  } catch (e) {
    console.error(e.message);
    process.exit(2);
  }
  for (const { check, ok, detail } of results) console.log(`${ok ? 'ok  ' : 'FAIL'}  ${check.padEnd(8)} ${detail}`);
  const valid = results.every((x) => x.ok);
  console.log(valid ? 'VALID' : 'INVALID');
  process.exit(valid ? 0 : 1);
}
