// AirnodeHub requests for SupplierPulse+ (docs/SUPPLIERPULSE_PLUS.md §4.2, §4.3).
// Every tool builds requests, request hashes and supplier keys through this file, so they match the contract.
import { encodePacked, keccak256, toHex } from 'viem';

// `index` is the contract's uint8 source (0 CompaniesHouse, 1 Gleif).
export const SOURCES = {
  ch: {
    index: 0,
    name: 'Companies House',
    url: process.env.CH_URL ?? 'https://airnode-companies-house.fly.dev/',
    signer: '0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF',
    operation: 'getCompanyProfile',
    param: 'company_number',
    idPattern: /^[0-9A-Z]{1,10}$/,
    projection: {
      accounts_overdue: '/accounts/overdue',
      confirmation_overdue: '/confirmation_statement/overdue',
      insolvency: '/has_insolvency_history',
      status: '/company_status',
    },
  },
  gleif: {
    index: 1,
    name: 'GLEIF',
    url: process.env.GLEIF_URL ?? 'https://airnode-gleif.fly.dev/',
    signer: '0x26d83124541e89ef28B9A5FB012B4B5f4097C20c',
    operation: 'getLegalEntity',
    param: 'lei',
    idPattern: /^[0-9A-Z]{20}$/,
    projection: {
      entity_status: '/data/attributes/entity/status',
      registration_status: '/data/attributes/registration/status',
    },
  },
};

// §4.3: the base check is always on; the other rules are bits the buyer picks per order.
export const BASE_FAILED = 0x80;
export const RULES = [
  { bit: 0x01, source: 'ch', field: 'insolvency', clean: (v) => v === false, label: 'insolvency history' },
  { bit: 0x02, source: 'ch', field: 'accounts_overdue', clean: (v) => v === false, label: 'accounts overdue' },
  { bit: 0x04, source: 'ch', field: 'confirmation_overdue', clean: (v) => v === false, label: 'confirmation statement overdue' },
  { bit: 0x08, source: 'gleif', field: 'registration_status', clean: (v) => v === 'ISSUED', label: 'LEI registration not issued (e.g. lapsed)' },
];
const BASE = {
  ch: { field: 'status', clean: (v) => v === 'active', label: 'registry status not active' },
  gleif: { field: 'entity_status', clean: (v) => v === 'ACTIVE', label: 'LEI entity not active' },
};

export function sourceOf(name) {
  const s = SOURCES[name];
  if (!s) throw new Error(`unknown source "${name}" (use ch or gleif)`);
  return s;
}

// Uppercases and validates an id; throws like the contract's BadSupplierId.
export function normalizeId(source, id) {
  const s = sourceOf(source);
  const n = String(id ?? '').trim().toUpperCase();
  if (!s.idPattern.test(n)) throw new Error(`bad ${s.name} id "${id}"`);
  return n;
}

// The HTTP body for a POST to the Airnode.
export function buildRequest(source, id) {
  const s = sourceOf(source);
  return {
    operation: s.operation,
    parameters: { [s.param]: normalizeId(source, id) },
    responseProjection: { ...s.projection },
  };
}

// UTF-8 byte order, as the starter's deriveRequestHash sorts.
const byteOrder = (a, b) => Buffer.compare(Buffer.from(a[0], 'utf8'), Buffer.from(b[0], 'utf8'));

// keccak256(utf8(JSON.stringify([operation, sortedParameters, sortedProjection]))) for any request body.
export function hashRequest({ operation, parameters, responseProjection }) {
  const params = Object.entries(parameters).sort(byteOrder);
  const projection = Object.entries(responseProjection).sort(byteOrder);
  return keccak256(toHex(JSON.stringify([operation, params, projection])));
}

export function requestHash(source, id) {
  return hashRequest(buildRequest(source, id));
}

// keccak256(abi.encodePacked(uint8 source, bytes(supplierId))), the contract's supplierKeyOf.
export function supplierKey(source, id) {
  return keccak256(encodePacked(['uint8', 'string'], [sourceOf(source).index, normalizeId(source, id)]));
}

// The contract's rule evaluation for a parsed signed record. Returns failedRules and the labels of the failures.
export function evaluateRules(source, fields, rules) {
  const base = BASE[source];
  let failed = 0;
  const labels = [];
  if (!base.clean(fields[base.field])) {
    failed |= BASE_FAILED;
    labels.push(base.label);
  }
  for (const r of RULES) {
    if (r.source === source && rules & r.bit && !r.clean(fields[r.field])) {
      failed |= r.bit;
      labels.push(r.label);
    }
  }
  return { failedRules: failed, labels };
}
