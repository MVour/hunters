// Small crypto helpers (Node's built-in crypto only).

import { createHmac, randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';

export function hmacHex(secret, text) {
  return createHmac('sha256', secret).update(text).digest('hex');
}

/** Constant-time string comparison (different lengths are just "no"). */
export function sameString(a, b) {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && timingSafeEqual(x, y);
}

export function randomHex(bytes) {
  return randomBytes(bytes).toString('hex');
}

/** Room codes: no 0/O/1/I so they're easy to read out loud. */
export const ROOM_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export function randomRoomCode(length = 6) {
  const bytes = randomBytes(length * 2);
  let code = '';
  for (let i = 0; code.length < length && i < bytes.length; i++) {
    // 32 symbols: one byte & 31 is unbiased.
    code += ROOM_ALPHABET[bytes[i] & 31];
  }
  return code;
}

/** "scrypt$<salt hex>$<hash hex>" for the config file (npm run hash-code). */
export function hashCode(code) {
  const salt = randomBytes(16);
  const hash = scryptSync(String(code), salt, 32);
  return `scrypt$${salt.toString('hex')}$${hash.toString('hex')}`;
}

export function checkCodeHash(code, stored) {
  const [kind, saltHex, hashHex] = String(stored).split('$');
  if (kind !== 'scrypt' || !saltHex || !hashHex) return false;
  const hash = scryptSync(String(code), Buffer.from(saltHex, 'hex'), 32);
  const expected = Buffer.from(hashHex, 'hex');
  return expected.length === hash.length && timingSafeEqual(hash, expected);
}
