// Fetch a signed Companies House profile status from AirnodeHub and print it as JSON:
//   {"airnode","requestHash","timestamp","data"(hex of the exact signed bytes),"signature","raw","paymentTx"}
// getCompanyProfile costs $0.01, paid over x402 in aUSD on Base Sepolia (the payer needs aUSD, no ETH).
// Usage: PAYER_PRIVATE_KEY=0x... node ch-fetch.mjs <company number>
import { ExactEvmScheme } from '@x402/evm';
import { decodePaymentResponseHeader, wrapFetchWithPaymentFromConfig } from '@x402/fetch';
import { isAddressEqual, keccak256, recoverMessageAddress, encodePacked, toHex } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

const AIRNODE_URL = process.env.CH_URL ?? 'https://airnode-companies-house.fly.dev/';
const CH_AIRNODE = '0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF';
const BASE_SEPOLIA = 'eip155:84532';
const AUSD = '0xbeA34973e5f67F18F656A2C6070C64326C791808';

const number = (process.argv[2] ?? '').trim().toUpperCase();
if (!/^[A-Z0-9]{1,10}$/.test(number)) throw new Error('usage: node ch-fetch.mjs <company number>');
const key = process.env.PAYER_PRIVATE_KEY;
if (!key) throw new Error('PAYER_PRIVATE_KEY is not set (a Base Sepolia wallet holding aUSD)');

const payingFetch = wrapFetchWithPaymentFromConfig(fetch, {
  schemes: [{ network: BASE_SEPOLIA, client: new ExactEvmScheme(privateKeyToAccount(key)) }],
  spendControls: {
    maxAmountPerPayment: '$0.05',
    allowedAssets: [{ network: BASE_SEPOLIA, asset: AUSD, maxAmountPerPayment: '50000' }],
  },
  policies: [(_v, reqs) => reqs.filter((r) => r.asset.toLowerCase() === AUSD.toLowerCase())],
});

// the same request the contract hashes in companyRequestHash()
const request = {
  operation: 'getCompanyProfile',
  parameters: { company_number: number },
  responseProjection: { status: '/company_status' },
};
const expectedHash = keccak256(
  toHex(JSON.stringify(['getCompanyProfile', [['company_number', number]], [['status', '/company_status']]]))
);

const res = await payingFetch(AIRNODE_URL, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(request),
});
if (!res.ok) {
  console.error(`Airnode responded ${res.status}: ${await res.text()}`);
  process.exit(3); // no data
}
const signed = await res.json();
if (signed.requestHash !== expectedHash) throw new Error(`unexpected request hash ${signed.requestHash}`);

// check the signature here too, so a bad response is caught before it costs gas
const digest = keccak256(encodePacked(['bytes32', 'uint256', 'bytes'], [signed.requestHash, BigInt(signed.timestamp), toHex(signed.data)]));
const signer = await recoverMessageAddress({ message: { raw: digest }, signature: signed.signature });
if (!isAddressEqual(signer, CH_AIRNODE)) throw new Error(`signed by ${signer}, not the Companies House Airnode`);

const header = res.headers.get('PAYMENT-RESPONSE');
const settlement = header ? decodePaymentResponseHeader(header) : undefined;
console.log(
  JSON.stringify({
    airnode: signed.airnode,
    requestHash: signed.requestHash,
    timestamp: String(signed.timestamp),
    data: toHex(signed.data),
    signature: signed.signature,
    raw: signed.data,
    paymentTx: settlement?.transaction ?? null,
  })
);
