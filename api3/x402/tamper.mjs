// Writes a tampered copy of a signed record (§4.1) to stdout and explains the change on stderr.
// The modes and the rejection each must cause are in docs/SUPPLIERPULSE_PLUS.md §4.7; demo/judge.html does the same.
// Usage: node tamper.mjs <file> <value|stale|request|key|replay>
// Exit: 0 ok, 2 usage
import { hexToString, toHex } from 'viem';
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts';
import { pathToFileURL } from 'node:url';
import { requestHash } from './requests.mjs';
import { digestOf } from './sign-local.mjs';
import { loadRecord } from './verify.mjs';

const OTHER_ID = { ch: '00000001', gleif: 'TESTLEI0000000000001' };
const OTHER_ID_ALT = { ch: '00000002', gleif: 'TESTLEI0000000000002' };

// Replaces one value in the signed string, keeping every other byte as signed.
function editValue(source, signed) {
  const swap = (key, from, to) => {
    const m = signed.match(new RegExp(`"${key}":\\s*"([^"]*)"`));
    if (!m) return null;
    const next = m[1] === from ? to : from;
    return { raw: signed.replace(m[0], m[0].replace(`"${m[1]}"`, `"${next}"`)), what: `${key} "${m[1]}" -> "${next}"` };
  };
  const edit = source === 'gleif' ? swap('entity_status', 'ACTIVE', 'INACTIVE') : swap('status', 'active', 'liquidation');
  if (edit) return edit;
  const b = signed.match(/"([^"]+)":\s*(true|false)/);
  if (!b) throw new Error('nothing to edit: no status field and no boolean in the signed data');
  const flipped = b[2] === 'true' ? 'false' : 'true';
  return { raw: signed.replace(b[0], b[0].replace(b[2], flipped)), what: `${b[1]} ${b[2]} -> ${flipped}` };
}

export async function tamper(r, mode) {
  const out = { ...r };
  const signed = hexToString(r.data);
  switch (mode) {
    case 'value': {
      const { raw, what } = editValue(r.source, signed);
      out.data = toHex(raw);
      out.raw = raw;
      return { record: out, why: `(a) edited value: ${what}; signature unchanged. Expected: WrongSigner` };
    }
    case 'stale':
      out.timestamp = String(BigInt(r.timestamp) - 3600n);
      return { record: out, why: `(b) too old: timestamp ${r.timestamp} -> ${out.timestamp} (-1 h). Expected: StaleResponse` };
    case 'request': {
      const id = (r.supplierId ?? '').toUpperCase() === OTHER_ID[r.source] ? OTHER_ID_ALT[r.source] : OTHER_ID[r.source];
      out.requestHash = requestHash(r.source, id);
      return { record: out, why: `(c) different request: requestHash of ${r.source} ${id}. Expected: WrongRequest` };
    }
    case 'key': {
      const account = privateKeyToAccount(generatePrivateKey());
      out.signature = await account.signMessage({ message: { raw: digestOf(r.requestHash, r.timestamp, r.data) } });
      return { record: out, why: `(d) wrong key: untouched response re-signed by random ${account.address}. Expected: WrongSigner(${account.address})` };
    }
    case 'replay':
      return { record: out, why: 'replay: unchanged; submit it after the original was accepted. Expected: Replayed' };
    default:
      throw new Error(`unknown mode "${mode}"`);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [file, mode] = process.argv.slice(2);
  try {
    if (!file || !mode) throw new Error('usage: node tamper.mjs <file> <value|stale|request|key|replay>');
    const { record, why } = await tamper(loadRecord(file), mode);
    console.error(why);
    console.log(JSON.stringify(record));
  } catch (e) {
    console.error(e.message);
    process.exit(2);
  }
}
