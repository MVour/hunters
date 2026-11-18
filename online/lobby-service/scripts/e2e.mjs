// End-to-end: the real lobby service starts a real Godot room server; two
// bot players (tools/autotest.gd) log in, get tickets and play a match
// through the service's WebSocket forwarding.
//
//   node scripts/e2e.mjs "<godot console binary>" [extra bot args...]
//
// Fast by default (room server and bots with --fast: no pauses); REAL=1
// plays at real speed.
// Exit 0 only if both bots report AUTOTEST PASS.

import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = fileURLToPath(new URL('.', import.meta.url));
const project = resolve(here, '../../..');
const godot = process.argv[2];
const real = process.env.REAL === '1';
const speed = real ? [] : ['--fast'];
const botArgs = [...speed, ...process.argv.slice(3)];
if (!godot) {
  console.error('usage: node scripts/e2e.mjs <godot binary> [bot args]');
  process.exit(2);
}
const port = 18787;
const origin = `http://127.0.0.1:${port}`;
const dir = mkdtempSync(join(tmpdir(), 'b2d-e2e-'));
const out = resolve(project, '.godot/online-e2e');
mkdirSync(out, { recursive: true });
const configPath = join(dir, 'config.json');
writeFileSync(configPath, JSON.stringify({
  publicOrigin: origin,
  listen: { host: '127.0.0.1', port },
  sessionSecret: 'e2e-'.repeat(10),
  access: { users: [{ name: 'Owner', code: 'owner-code' }], sharedCodes: ['guests-code'], admins: [] },
  rooms: { maxRooms: 2, maxRoomsPerUser: 1, maxPlayers: 4, maxHours: 1, portFrom: 21000, portTo: 21005, startTimeoutSeconds: 60 },
  godot: { command: godot, args: ['--headless', '--path', project], gameArgs: speed },
}));

const service = spawn(process.execPath, [resolve(here, '../src/server.js')], {
  env: { ...process.env, BOARD2D_CONFIG: configPath, BOARD2D_ROOM_HOME: dir },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let serviceLog = '';
service.stdout.on('data', (d) => { serviceLog += d; });
service.stderr.on('data', (d) => { serviceLog += d; });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function api(method, path, body, cookie) {
  const headers = { Origin: origin };
  if (body) headers['Content-Type'] = 'application/json';
  if (cookie) headers.Cookie = cookie;
  const res = await fetch(origin + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const json = await res.json();
  if (!res.ok) throw new Error(`${method} ${path}: ${res.status} ${JSON.stringify(json)}`);
  return { json, cookie: res.headers.get('set-cookie')?.split(';')[0] };
}

function bot(role, link, extra) {
  return new Promise((resolveBot) => {
    const p = spawn(godot, ['--headless', '--path', project, '--', `--autotest=${role}`, `--join=${link}`, ...extra], { stdio: ['ignore', 'pipe', 'pipe'] });
    let text = '';
    p.stdout.on('data', (d) => { text += d; });
    p.stderr.on('data', (d) => { text += d; });
    const timer = setTimeout(() => p.kill(), real ? 900_000 : 300_000);
    p.on('exit', () => {
      clearTimeout(timer);
      writeFileSync(join(out, `${role}.log`), text);
      resolveBot(text);
    });
  });
}

let ok = false;
try {
  for (let i = 0; i < 50; i++) {
    try { await fetch(origin + '/api/health'); break; } catch { await sleep(200); }
  }
  const owner = (await api('POST', '/api/login', { name: 'Owner', code: 'owner-code' })).cookie;
  const guest = (await api('POST', '/api/login', { name: 'Guest', code: 'guests-code' })).cookie;
  const room = (await api('POST', '/api/rooms', { title: 'E2E', visibility: 'private', maxPlayers: 4 }, owner)).json.room;
  console.log(`room ${room.code} ready`);
  const ws = origin.replace('http', 'ws');
  const ownerLink = ws + (await api('POST', `/api/rooms/${room.code}/join`, {}, owner)).json.path;
  const guestLink = ws + (await api('POST', `/api/rooms/${room.code}/join`, {}, guest)).json.path;
  const [a, b] = await Promise.all([
    bot('host', ownerLink, ['--max-turns=20', ...botArgs]),
    sleep(1500).then(() => bot('client', guestLink, botArgs)),
  ]);
  for (const t of [a, b]) console.log((t.match(/AUTOTEST (PASS|FAIL).*/) ?? ['(no result line)'])[0]);
  const errors = (a + b).split('\n').filter((l) => /SCRIPT ERROR|^ERROR/.test(l)
    && !/Unreferenced|leaked|resources still|at exit|PagedAllocator|string_name|Thread|thread\.cpp/.test(l));
  if (errors.length) console.log('script errors:\n' + errors.slice(0, 10).join('\n'));
  ok = /AUTOTEST PASS/.test(a) && /AUTOTEST PASS/.test(b) && errors.length === 0;
  // The room server must have refused nobody and reported the players.
  await sleep(1500); // its status reports come once a second
  const list = (await api('GET', '/api/rooms', null, owner)).json.rooms;
  console.log('rooms after the match:', JSON.stringify(list.map((r) => ({ code: r.code, players: r.players, inMatch: r.inMatch }))));
  // BUG-009: a finished match leaves the table playable again.
  if (/AUTOTEST PASS.*game over/.test(a + b) && list.some((r) => r.inMatch)) {
    console.log('BUG-009: the room still says a match is running after it ended');
    ok = false;
  }
} catch (err) {
  console.log('E2E error:', err.message);
} finally {
  service.kill('SIGTERM');
  await sleep(1000);
  writeFileSync(join(out, 'service.log'), serviceLog);
}
console.log(ok ? 'ONLINE E2E PASSED' : `ONLINE E2E FAILED — logs in ${out}`);
process.exit(ok ? 0 : 1);
