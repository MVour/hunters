// Join tickets: short-lived, single-use proof that a logged-in player may
// enter one room. Checked twice: here when the connection comes in (and
// burned), and by the room's Godot server (network/room_ticket.gd), which
// takes the player's name and owner flag from it.
//
// Format: <payload hex>.<HMAC-SHA256 hex>, signed with the ROOM's secret.
// Payload JSON: {r: room, n: name, o: owner, e: expiry (unix s), j: nonce}.
// Hex (not base64) so it's safe in a URL path and easy to read in GDScript.

import { hmacHex, randomHex, sameString } from './crypto.js';

export function makeTicket(room, name, owner, seconds, now = Date.now()) {
  const payload = Buffer.from(JSON.stringify({
    r: room.code,
    n: name,
    o: !!owner,
    e: Math.floor(now / 1000) + seconds,
    j: randomHex(16),
  }), 'utf8').toString('hex');
  return `${payload}.${hmacHex(room.secret, payload)}`;
}

/** The ticket's payload if it's genuine and fresh for this room, else null. */
export function readTicket(ticket, room, now = Date.now()) {
  if (typeof ticket !== 'string' || ticket.length > 1024 || !/^[0-9a-f]+\.[0-9a-f]{64}$/.test(ticket)) return null;
  const [payload, sig] = ticket.split('.');
  if (!sameString(sig, hmacHex(room.secret, payload))) return null;
  let data;
  try {
    data = JSON.parse(Buffer.from(payload, 'hex').toString('utf8'));
  } catch {
    return null;
  }
  if (!data || data.r !== room.code || !(data.e * 1000 > now) || typeof data.j !== 'string') return null;
  return data;
}

/** Nonces already used, kept until their tickets would have expired anyway. */
export class UsedNonces {
  constructor() {
    this.used = new Map(); // nonce -> expiry ms
  }

  /** true the first time a nonce is seen. */
  burn(nonce, expiresAtMs) {
    if (this.used.has(nonce)) return false;
    this.used.set(nonce, expiresAtMs);
    return true;
  }

  sweep(now = Date.now()) {
    for (const [nonce, exp] of this.used) if (exp <= now) this.used.delete(nonce);
  }
}
