// Logging in with a name + access code, and the session cookie.
//
// Who may log in comes from config.access:
//   - users: fixed names, each with its own code (or codeHash)
//   - sharedCodes: anyone with the code picks a name (not one of the users')
// The session is a signed cookie (HttpOnly, SameSite=Strict, Secure on
// https): {n: name, a: admin, e: expiry, v: epoch}. Nothing is stored on
// the server; raising sessionEpoch logs everybody out.

import { hmacHex, sameString, checkCodeHash } from './crypto.js';

export const COOKIE = 'b2d_session';
const NAME_RE = /^[\p{L}\p{N}][\p{L}\p{N} _.-]{0,15}$/u;

export function cleanName(name) {
  if (typeof name !== 'string') return '';
  const n = name.normalize('NFC').trim().replace(/\s+/g, ' ');
  return NAME_RE.test(n) ? n : '';
}

export class Auth {
  constructor(config) {
    this.config = config;
    this.secret = config.sessionSecret;
  }

  /** The canonical name if name + code may log in, else null. */
  check(name, code) {
    const clean = cleanName(name);
    if (!clean || typeof code !== 'string' || code.length === 0 || code.length > 200) return null;
    const lower = clean.toLowerCase();
    const user = this.config.access.users.find((u) => u.name.trim().toLowerCase() === lower);
    if (user) {
      const ok = user.codeHash ? checkCodeHash(code, user.codeHash) : sameString(code, user.code);
      return ok ? user.name.trim() : null;
    }
    // Shared codes can't be used to take a listed user's name (checked above).
    let ok = false;
    for (const shared of this.config.access.sharedCodes) {
      if (sameString(code, shared)) ok = true; // no early exit: same time either way
    }
    return ok ? clean : null;
  }

  isAdmin(name) {
    const lower = String(name).toLowerCase();
    return this.config.access.admins.some((a) => String(a).trim().toLowerCase() === lower);
  }

  makeCookie(name, now = Date.now()) {
    const payload = Buffer.from(JSON.stringify({
      n: name,
      a: this.isAdmin(name),
      e: now + this.config.sessionDays * 86400_000,
      v: this.config.sessionEpoch,
    })).toString('base64url');
    const value = `${payload}.${hmacHex(this.secret, 'session:' + payload)}`;
    return this.cookieHeader(value, this.config.sessionDays * 86400);
  }

  clearCookie() {
    return this.cookieHeader('', 0);
  }

  cookieHeader(value, maxAge) {
    const parts = [`${COOKIE}=${value}`, 'Path=/', 'HttpOnly', 'SameSite=Strict', `Max-Age=${maxAge}`];
    if (this.config.secureCookies) parts.push('Secure');
    return parts.join('; ');
  }

  /** {name, admin} from the request's cookie, or null. */
  session(req, now = Date.now()) {
    const raw = readCookie(req.headers.cookie, COOKIE);
    if (!raw || raw.length > 1024) return null;
    const [payload, sig] = raw.split('.');
    if (!payload || !sig || !sameString(sig, hmacHex(this.secret, 'session:' + payload))) return null;
    let data;
    try {
      data = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    } catch {
      return null;
    }
    if (!data || data.v !== this.config.sessionEpoch || !(data.e > now)) return null;
    const name = cleanName(data.n);
    if (!name) return null;
    // Re-check against the current config: removed users lose access at once.
    const lower = name.toLowerCase();
    const listed = this.config.access.users.some((u) => u.name.trim().toLowerCase() === lower);
    if (!listed && this.config.access.sharedCodes.length === 0) return null;
    return { name, admin: this.isAdmin(name) };
  }
}

export function readCookie(header, wanted) {
  if (typeof header !== 'string') return '';
  for (const part of header.split(';')) {
    const eq = part.indexOf('=');
    if (eq > 0 && part.slice(0, eq).trim() === wanted) return part.slice(eq + 1).trim();
  }
  return '';
}
