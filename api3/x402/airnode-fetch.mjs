// Fetch a signed registry record from AirnodeHub, paying the x402 price in aUSD on Base Sepolia, and print it
// in the §4.1 format. Generalises ch-fetch.mjs (v1) to both SupplierPulse+ sources.
// Usage: PAYER_PRIVATE_KEY=0x... node airnode-fetch.mjs <ch|gleif> <id>
// Exit: 0 ok, 2 usage, 3 no data, 4 payment failed, 5 verification failed
import { ExactEvmScheme } from '@x402/evm';
import { decodePaymentResponseHeader, wrapFetchWithPaymentFromConfig } from '@x402/fetch';
import { isAddressEqual, recoverMessageAddress, toHex } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { buildRequest, normalizeId, requestHash, sourceOf } from './requests.mjs';
import { digestOf } from './sign-local.mjs';

const BASE_SEPOLIA = 'eip155:84532';
const AUSD = '0xbeA34973e5f67F18F656A2C6070C64326C791808';

const fail = (code, msg) => {
  console.error(msg);
  process.exit(code);
};

const [source, rawId] = process.argv.slice(2);
let s, id;
try {
  s = sourceOf(source);
  id = normalizeId(source, rawId);
} catch (e) {
  fail(2, `${e.message}\nusage: node airnode-fetch.mjs <ch|gleif> <id>`);
}
const key = process.env.PAYER_PRIVATE_KEY;
if (!key) fail(2, 'PAYER_PRIVATE_KEY is not set (a Base Sepolia wallet holding aUSD)');

const payingFetch = wrapFetchWithPaymentFromConfig(fetch, {
  schemes: [{ network: BASE_SEPOLIA, client: new ExactEvmScheme(privateKeyToAccount(key)) }],
  spendControls: {
    maxAmountPerPayment: '$0.05',
    allowedAssets: [{ network: BASE_SEPOLIA, asset: AUSD, maxAmountPerPayment: '50000' }],
  },
  policies: [(_v, reqs) => reqs.filter((r) => r.asset.toLowerCase() === AUSD.toLowerCase())],
});

let res;
try {
  res = await payingFetch(s.url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(buildRequest(source, id)),
  });
} catch (e) {
  fail(4, `payment failed: ${e.message}`);
}
const header = res.headers.get('PAYMENT-RESPONSE');
const settlement = header ? decodePaymentResponseHeader(header) : undefined;
if (res.status === 402) fail(4, `payment failed: Airnode still answers 402: ${await res.text()}`);
if (!res.ok) {
  fail(3, `no data: ${s.name} answered ${res.status}: ${await res.text()}${settlement?.transaction ? ` (payment ${settlement.transaction})` : ''}`);
}
const signed = await res.json();

// the request and signer checks the contract runs, so a bad record is caught before it costs gas
const expected = requestHash(source, id);
if (signed.requestHash !== expected) fail(5, `verification failed: request hash ${signed.requestHash}, expected ${expected}`);
const data = toHex(signed.data);
const signer = await recoverMessageAddress({
  message: { raw: digestOf(signed.requestHash, signed.timestamp, data) },
  signature: signed.signature,
}).catch(() => null);
if (!signer || !isAddressEqual(signer, s.signer)) fail(5, `verification failed: signed by ${signer}, not the ${s.name} Airnode`);

console.log(
  JSON.stringify({
    source,
    supplierId: id,
    airnode: signed.airnode,
    requestHash: signed.requestHash,
    timestamp: String(signed.timestamp),
    data,
    raw: signed.data,
    signature: signed.signature,
    paymentTx: settlement?.transaction ?? null,
    priceUsd: '0.01',
    fetchedAt: new Date().toISOString(),
  })
);
