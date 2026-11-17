import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { WebSocket } from 'ws';
import { validateConfig } from '../src/config.js';
import { createApp } from '../src/app.js';
import { testConfig, fakeSpawn, silentLog } from './helpers.js';

let server;
let app;
let base;
const spawned = [];
const ORIGIN = 'http://localhost:8787';

before(async () => {
  app = createApp(validateConfig(testConfig()), { log: silentLog, spawnProcess: fakeSpawn(spawned) });
  server = createServer(app.handleRequest);
  server.on('upgrade', app.handleUpgrade);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => {
  app.shutdown();
  server.close();
});

async function call(method, path, { body, cookie, origin = ORIGIN, type = 'application/json' } = {}) {
  const headers = {};
  if (origin) headers.Origin = origin;
  if (cookie) headers.Cookie = cookie;
  if (body !== undefined) headers['Content-Type'] = type;
  const res = await fetch(base + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: res.status, body: await res.json(), cookie: res.headers.get('set-cookie'), headers: res.headers };
}

async function login(name, code) {
  const r = await call('POST', '/api/login', { body: { name, code } });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  return r.cookie.split(';')[0];
}

test('security headers and health', async () => {
  const r = await call('GET', '/api/health');
  assert.equal(r.status, 200);
  assert.equal(r.headers.get('x-frame-options'), 'DENY');
  assert.equal(r.headers.get('cache-control'), 'no-store');
  assert.match(r.headers.get('content-security-policy'), /default-src 'none'/);
});

test('login: cookie flags, wrong codes, wrong origin, non-JSON', async () => {
  const ok = await call('POST', '/api/login', { body: { name: 'Alex', code: 'alex-code-123' } });
  assert.equal(ok.status, 200);
  assert.match(ok.cookie, /HttpOnly/);
  assert.match(ok.cookie, /SameSite=Strict/);
  assert.equal((await call('POST', '/api/login', { body: { name: 'Alex', code: 'nope' } })).status, 401);
  assert.equal((await call('POST', '/api/login', { body: { name: 'Alex', code: 'alex-code-123' }, origin: 'https://evil.example' })).status, 403);
  assert.equal((await call('POST', '/api/login', { body: { name: 'Alex', code: 'alex-code-123' }, origin: null })).status, 403);
  assert.equal((await call('POST', '/api/login', { body: { name: 'Alex' }, type: 'text/plain' })).status, 415);
  assert.equal((await call('GET', '/api/me')).status, 401);
});

test('a name gets locked after repeated failures', async () => {
  for (let i = 0; i < 3; i++) await call('POST', '/api/login', { body: { name: 'Sam', code: 'bad' } });
  const r = await call('POST', '/api/login', { body: { name: 'Sam', code: 'sams-secret' } });
  assert.equal(r.status, 429);
});

test('rooms: create, list, privacy, join tickets, owner-only changes', async () => {
  const alex = await login('Alex', 'alex-code-123');
  const bea = await login('Bea', 'friends-code-1');
  const cid = await login('Cid', 'friends-code-1');

  const made = await call('POST', '/api/rooms', { cookie: bea, body: { title: 'Friday <b>', visibility: 'private', maxPlayers: 4 } });
  assert.equal(made.status, 201, JSON.stringify(made.body));
  const room = made.body.room;
  assert.equal(room.title, "Bea's room"); // unsafe title replaced
  assert.equal(room.maxPlayers, 4);
  assert.equal(room.secret, undefined);
  assert.equal(room.port, undefined);
  const start = spawned.at(-1);
  assert.ok(start.args.includes(`--room=${room.code}`));
  assert.equal(start.options.env.BOARD2D_ROOM_SECRET.length, 64);
  assert.ok(!start.args.join(' ').includes(start.options.env.BOARD2D_ROOM_SECRET));
  assert.equal(start.options.env.BOARD2D_SESSION_SECRET, undefined);

  // One room per player.
  assert.equal((await call('POST', '/api/rooms', { cookie: bea, body: {} })).status, 409);
  // Private: Cid doesn't see it, but can join with the code. Admin sees it.
  assert.equal((await call('GET', '/api/rooms', { cookie: cid })).body.rooms.length, 0);
  assert.equal((await call('GET', '/api/rooms', { cookie: alex })).body.rooms.length, 1);
  const join = await call('POST', `/api/rooms/${room.code}/join`, { cookie: cid });
  assert.equal(join.status, 200);
  assert.match(join.body.path, new RegExp(`^/play/${room.code}/[0-9a-f]+\\.[0-9a-f]{64}$`));
  // Only the owner (or an admin) changes or closes it.
  assert.equal((await call('PATCH', `/api/rooms/${room.code}`, { cookie: cid, body: { visibility: 'open' } })).status, 403);
  assert.equal((await call('PATCH', `/api/rooms/${room.code}`, { cookie: bea, body: { visibility: 'open' } })).status, 200);
  assert.equal((await call('GET', '/api/rooms', { cookie: cid })).body.rooms.length, 1);
  assert.equal((await call('DELETE', `/api/rooms/${room.code}`, { cookie: cid })).status, 403);
  assert.equal((await call('DELETE', `/api/rooms/${room.code}`, { cookie: alex })).status, 200);
  assert.equal((await call('POST', `/api/rooms/${room.code}/join`, { cookie: cid })).status, 404);
});

test('websocket entrance: bad tickets refused, a ticket works once', async () => {
  const dee = await login('Dee', 'friends-code-1');
  const room = (await call('POST', '/api/rooms', { cookie: dee, body: { visibility: 'open' } })).body.room;
  const wsBase = base.replace('http', 'ws');
  const tryConnect = (path, headers = {}) => new Promise((resolve) => {
    const ws = new WebSocket(wsBase + path, { headers });
    ws.on('unexpected-response', (_req, res) => resolve(res.statusCode));
    ws.on('open', () => { ws.terminate(); resolve('open'); });
    ws.on('error', () => resolve('error'));
  });
  assert.equal(await tryConnect(`/play/${room.code}/abcd.${'0'.repeat(64)}`), 403);
  assert.equal(await tryConnect('/play/NOPE22/x'), 404);
  const { path } = (await call('POST', `/api/rooms/${room.code}/join`, { cookie: dee })).body;
  assert.equal(await tryConnect(path, { Origin: 'https://evil.example' }), 403);
  // The fake room has no real server behind it, so the forwarded socket
  // closes right away; what matters is that the ticket was accepted once.
  assert.equal(await tryConnect(path), 'open');
  assert.equal(await tryConnect(path), 403);
});
