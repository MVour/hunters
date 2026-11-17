import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateConfig } from '../src/config.js';
import { Auth, cleanName } from '../src/auth.js';
import { makeTicket, readTicket, UsedNonces } from '../src/tickets.js';
import { hashCode, checkCodeHash, randomRoomCode, ROOM_ALPHABET } from '../src/crypto.js';
import { WindowCounter, TokenBucket } from '../src/limits.js';
import { testConfig } from './helpers.js';

test('config refuses unsafe setups', () => {
  assert.throws(() => validateConfig(testConfig({ sessionSecret: 'short' })), /sessionSecret/);
  assert.throws(() => validateConfig(testConfig({ access: { users: [], sharedCodes: [], admins: [] } })), /Nobody can log in/);
  assert.throws(() => validateConfig(testConfig({ access: { users: [], sharedCodes: ['short'], admins: [] } })), /8\+/);
  assert.throws(() => validateConfig(testConfig({ publicOrigin: 'https://x.com/path' })), /no path/);
  const ok = validateConfig(testConfig({ publicOrigin: 'https://play.example.com' }));
  assert.equal(ok.secureCookies, true);
});

test('names are cleaned and limited', () => {
  assert.equal(cleanName('  Μαρία  '), 'Μαρία');
  assert.equal(cleanName('a   b'), 'a b');
  assert.equal(cleanName('<script>'), '');
  assert.equal(cleanName('x'.repeat(17)), '');
  assert.equal(cleanName(''), '');
  assert.equal(cleanName(42), '');
});

test('login: listed users need their own code; shared codes cannot take their names', () => {
  const auth = new Auth(validateConfig(testConfig()));
  assert.equal(auth.check('alex', 'alex-code-123'), 'Alex');
  assert.equal(auth.check('Alex', 'friends-code-1'), null);
  assert.equal(auth.check('Sam', 'sams-secret'), 'Sam'); // codeHash
  assert.equal(auth.check('Sam', 'wrong'), null);
  assert.equal(auth.check('Newbie', 'friends-code-1'), 'Newbie');
  assert.equal(auth.check('Newbie', 'nope'), null);
  // pasted from a chat: spaces / a line break around the code
  assert.equal(auth.check('Newbie', '  friends-code-1\n'), 'Newbie');
  assert.equal(auth.check('Newbie', '   '), null);
  assert.equal(auth.isAdmin('ALEX'), true);
  assert.equal(auth.isAdmin('Newbie'), false);
});

test('session cookie: signed, expiring, epoch-bound', () => {
  const config = validateConfig(testConfig());
  const auth = new Auth(config);
  const cookie = auth.makeCookie('Alex').split(';')[0];
  const req = { headers: { cookie } };
  assert.deepEqual(auth.session(req), { name: 'Alex', admin: true });
  const [payload, sig] = cookie.split('=')[1].split('.');
  const forged = Buffer.from(JSON.stringify({ n: 'Alex', a: true, e: Date.now() + 1e9, v: 1 })).toString('base64url');
  assert.equal(auth.session({ headers: { cookie: `b2d_session=${forged}.${sig}` } }), null);
  assert.equal(auth.session(req, Date.now() + 30 * 86400_000), null); // expired
  config.sessionEpoch = 2;
  assert.equal(auth.session(req), null); // everyone logged out
  assert.ok(payload);
});

test('code hashes', () => {
  const h = hashCode('hello-world');
  assert.ok(checkCodeHash('hello-world', h));
  assert.ok(!checkCodeHash('hello-worlD', h));
  assert.ok(!checkCodeHash('x', 'plain'));
});

test('tickets: room-bound, expiring, tamper-proof, single-use', () => {
  const room = { code: 'ABCDEF', secret: 'a'.repeat(64) };
  const other = { code: 'GHJKLM', secret: 'a'.repeat(64) };
  const t = makeTicket(room, 'Alex', true, 60);
  const data = readTicket(t, room);
  assert.equal(data.n, 'Alex');
  assert.equal(data.o, true);
  assert.equal(readTicket(t, other), null);
  assert.equal(readTicket(t, { ...room, secret: 'b'.repeat(64) }), null);
  assert.equal(readTicket(t, room, Date.now() + 61_000), null);
  const [payload, sig] = t.split('.');
  const evil = Buffer.from(JSON.stringify({ ...data, o: true, n: 'Sam' })).toString('hex');
  assert.equal(readTicket(`${evil}.${sig}`, room), null);
  assert.ok(payload);
  const used = new UsedNonces();
  assert.ok(used.burn(data.j, data.e * 1000));
  assert.ok(!used.burn(data.j, data.e * 1000));
});

test('room codes use the readable alphabet', () => {
  for (let i = 0; i < 200; i++) {
    const code = randomRoomCode();
    assert.equal(code.length, 6);
    for (const c of code) assert.ok(ROOM_ALPHABET.includes(c));
  }
});

test('rate limits', () => {
  const w = new WindowCounter(2, 1000);
  assert.ok(w.hit('a', 0));
  assert.ok(w.hit('a', 1));
  assert.ok(!w.hit('a', 2));
  assert.ok(w.blocked('a', 3));
  assert.ok(w.hit('a', 1001));
  const b = new TokenBucket(1, 2);
  assert.ok(b.take(b.last));
  assert.ok(b.take(b.last));
  assert.ok(!b.take(b.last));
});
