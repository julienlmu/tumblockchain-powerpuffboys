// Signs a record like an Airnode would, with a local key per source, and prints it in the §4.1 format.
// Free and offline, for the local test chain (docs/SUPPLIERPULSE_PLUS.md §4.8).
// Usage: node sign-local.mjs <ch|gleif> <id> '<data json>' [timestamp]
// env: LOCAL_CH_KEY, LOCAL_GLEIF_KEY (default: anvil accounts #1 and #2, public test keys, never use them on a real network)
import { encodePacked, keccak256, toHex } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { normalizeId, requestHash, sourceOf } from './requests.mjs';

export const LOCAL_KEYS = {
  ch: process.env.LOCAL_CH_KEY ?? '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d',
  gleif: process.env.LOCAL_GLEIF_KEY ?? '0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a',
};

// keccak256(abi.encodePacked(bytes32 requestHash, uint256 timestamp, bytes data)), the digest the Airnode signs.
export function digestOf(reqHash, timestamp, dataHex) {
  return keccak256(encodePacked(['bytes32', 'uint256', 'bytes'], [reqHash, BigInt(timestamp), dataHex]));
}

// Signs `raw` (the exact data string) with `key` (EIP-191 over the digest) and returns a §4.1 record.
export async function signRecord(source, id, raw, { key = LOCAL_KEYS[source], timestamp, reqHash } = {}) {
  sourceOf(source);
  const supplierId = normalizeId(source, id);
  const account = privateKeyToAccount(key);
  const ts = String(timestamp ?? Math.floor(Date.now() / 1000));
  const rh = reqHash ?? requestHash(source, supplierId);
  const data = toHex(raw);
  const signature = await account.signMessage({ message: { raw: digestOf(rh, ts, data) } });
  return {
    source,
    supplierId,
    airnode: account.address,
    requestHash: rh,
    timestamp: ts,
    data,
    raw,
    signature,
    paymentTx: null,
    priceUsd: '0',
    fetchedAt: new Date().toISOString(),
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [source, id, raw, timestamp] = process.argv.slice(2);
  try {
    if (!source || !id || !raw) throw new Error('usage: node sign-local.mjs <ch|gleif> <id> \'<data json>\' [timestamp]');
    JSON.parse(raw); // must be JSON, but is signed exactly as given
    if (timestamp !== undefined && !/^\d+$/.test(timestamp)) throw new Error(`bad timestamp "${timestamp}"`);
    console.log(JSON.stringify(await signRecord(source, id, raw, { timestamp })));
  } catch (e) {
    console.error(e.message);
    process.exit(2);
  }
}
