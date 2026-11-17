// The HTTP API (JSON under /api) and the WebSocket entrance (/play/ROOM/TICKET).
// Static files (the lobby page, the browser game) are served by Caddy.
//
// API (all JSON; errors are {error: "<code>"}, the page translates them):
//   POST   /api/login                {name, code}  -> sets the session cookie
//   POST   /api/logout
//   GET    /api/me
//   GET    /api/rooms                              -> open rooms + yours
//   POST   /api/rooms                {title, visibility, maxPlayers}
//   POST   /api/rooms/:code/join                   -> {code, ticket, path}
//   PATCH  /api/rooms/:code          {visibility}  (owner/admin)
//   DELETE /api/rooms/:code                        (owner/admin)
//   GET    /api/health
//
// Defences: signed HttpOnly SameSite=Strict cookie; Origin must match on
// every state change (and on WebSockets, when sent); JSON bodies only, 4 KB
// max; rate limits per IP (API, login, room-code guesses) and per name
// (login failures); strict security headers; tickets single-use + 60 s.

import { WebSocketServer, WebSocket } from 'ws';
import { Auth, cleanName } from './auth.js';
import { RoomManager, VISIBILITIES } from './rooms.js';
import { makeTicket, readTicket, UsedNonces } from './tickets.js';
import { WindowCounter, TokenBucket } from './limits.js';

const MAX_BODY = 4096;
const QUARTER_HOUR = 15 * 60_000;
const PLAY_RE = /^\/play\/([A-Z2-9]{4,16})\/([0-9a-f]{2,900}\.[0-9a-f]{64})$/;
const ROOM_RE = /^\/api\/rooms\/([A-Za-z0-9]{4,16})(\/join)?$/;

const SECURITY_HEADERS = {
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'X-Frame-Options': 'DENY',
  'Content-Security-Policy': "default-src 'none'; frame-ancestors 'none'",
  'Cross-Origin-Resource-Policy': 'same-origin',
};

class HttpError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

export function createApp(config, { log = console, spawnProcess } = {}) {
  const auth = new Auth(config);
  const rooms = new RoomManager(config, { log, spawnProcess });
  const nonces = new UsedNonces();
  const L = config.limits;
  const apiPerIp = new WindowCounter(L.apiRequestsPerMinute, 60_000);
  const loginPerIp = new WindowCounter(L.loginAttemptsPerIp, QUARTER_HOUR);
  const loginFailsPerName = new WindowCounter(L.loginFailuresPerName, QUARTER_HOUR);
  const roomGuessesPerIp = new WindowCounter(20, QUARTER_HOUR);
  const socketsPerIp = new Map();
  const wss = new WebSocketServer({ noServer: true, maxPayload: L.maxMessageBytes, perMessageDeflate: false, clientTracking: false });

  function clientIp(req) {
    if (config.trustProxy) {
      const xff = String(req.headers['x-forwarded-for'] ?? '').split(',').map((s) => s.trim()).filter(Boolean);
      if (xff.length) return xff[xff.length - 1]; // the hop our own proxy added
    }
    return req.socket.remoteAddress ?? 'unknown';
  }

  function originOk(req, required) {
    const origin = req.headers.origin;
    if (!origin) return !required;
    return origin === config.publicOrigin;
  }

  function send(res, status, body, extraHeaders = {}) {
    const json = JSON.stringify(body);
    res.writeHead(status, { ...SECURITY_HEADERS, 'Content-Type': 'application/json; charset=utf-8',
      'Content-Length': Buffer.byteLength(json), ...extraHeaders });
    res.end(json);
  }

  function readJson(req) {
    return new Promise((resolve, reject) => {
      const type = String(req.headers['content-type'] ?? '');
      if (!type.startsWith('application/json')) return reject(new HttpError(415, 'json_only'));
      let size = 0;
      const chunks = [];
      req.on('data', (chunk) => {
        size += chunk.length;
        if (size > MAX_BODY) {
          reject(new HttpError(413, 'too_big'));
          req.destroy();
          return;
        }
        chunks.push(chunk);
      });
      req.on('end', () => {
        try {
          const value = JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
          if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error();
          resolve(value);
        } catch {
          reject(new HttpError(400, 'bad_json'));
        }
      });
      req.on('error', () => reject(new HttpError(400, 'bad_request')));
    });
  }

  function needSession(req) {
    const me = auth.session(req);
    if (!me) throw new HttpError(401, 'not_logged_in');
    return me;
  }

  function canManage(me, room) {
    return me.admin || room.owner.toLowerCase() === me.name.toLowerCase();
  }

  async function route(req, res) {
    const ip = clientIp(req);
    const url = new URL(req.url, 'http://local');
    const path = url.pathname;
    const method = req.method;

    if (!path.startsWith('/api/')) throw new HttpError(404, 'not_found');
    if (!apiPerIp.hit(ip)) throw new HttpError(429, 'slow_down');
    if (method !== 'GET' && method !== 'HEAD' && !originOk(req, true)) throw new HttpError(403, 'bad_origin');

    if (path === '/api/health' && method === 'GET') return send(res, 200, { ok: true });

    if (path === '/api/login' && method === 'POST') {
      if (!loginPerIp.hit(ip)) throw new HttpError(429, 'too_many_attempts');
      const body = await readJson(req);
      const nameKey = String(body.name ?? '').trim().toLowerCase().slice(0, 32);
      if (loginFailsPerName.blocked(nameKey)) throw new HttpError(429, 'too_many_attempts');
      // The name rules are public, so say so plainly instead of "don't match".
      if (!cleanName(body.name)) throw new HttpError(400, 'bad_name');
      const name = auth.check(body.name, body.code);
      if (!name) {
        loginFailsPerName.hit(nameKey);
        log.warn(`login failed for "${nameKey}" from ${ip}`);
        throw new HttpError(401, 'wrong_name_or_code');
      }
      loginFailsPerName.reset(nameKey);
      log.info(`login: ${name} from ${ip}`);
      return send(res, 200, { name, admin: auth.isAdmin(name) }, { 'Set-Cookie': auth.makeCookie(name) });
    }

    if (path === '/api/logout' && method === 'POST') {
      return send(res, 200, { ok: true }, { 'Set-Cookie': auth.clearCookie() });
    }

    if (path === '/api/me' && method === 'GET') {
      return send(res, 200, needSession(req));
    }

    if (path === '/api/rooms' && method === 'GET') {
      const me = needSession(req);
      return send(res, 200, { me, rooms: rooms.list(me), maxPlayers: config.rooms.maxPlayers });
    }

    if (path === '/api/rooms' && method === 'POST') {
      const me = needSession(req);
      const body = await readJson(req);
      const made = rooms.create(me.name, {
        title: body.title,
        visibility: body.visibility,
        maxPlayers: Number.isInteger(body.maxPlayers) ? body.maxPlayers : undefined,
      });
      if (made.error) throw new HttpError(409, made.error);
      log.info(`room ${made.room.code} made by ${me.name} (${made.room.visibility})`);
      const ok = await rooms.whenReady(made.room, config.rooms.startTimeoutSeconds * 1000);
      if (!ok) throw new HttpError(503, 'room_failed_to_start');
      return send(res, 201, { room: rooms.publicView(made.room, me) });
    }

    const m = ROOM_RE.exec(path);
    if (m) {
      const me = needSession(req);
      const room = rooms.get(m[1]);
      if (!room) {
        if (!roomGuessesPerIp.hit(ip)) throw new HttpError(429, 'too_many_attempts');
        throw new HttpError(404, 'no_such_room');
      }
      if (m[2] && method === 'POST') {
        if (room.state !== 'ready') throw new HttpError(409, 'room_starting');
        if (room.inMatch) throw new HttpError(409, 'room_playing');
        if (room.players.length >= room.maxPlayers) throw new HttpError(409, 'room_full');
        if (room.players.some((p) => p.toLowerCase() === me.name.toLowerCase())) throw new HttpError(409, 'already_in_room');
        const owner = room.owner.toLowerCase() === me.name.toLowerCase();
        const ticket = makeTicket(room, me.name, owner, L.ticketSeconds);
        return send(res, 200, { code: room.code, ticket, path: `/play/${room.code}/${ticket}` });
      }
      if (!m[2] && method === 'PATCH') {
        if (!canManage(me, room)) throw new HttpError(403, 'not_your_room');
        const body = await readJson(req);
        if (!VISIBILITIES.includes(body.visibility)) throw new HttpError(400, 'bad_visibility');
        room.visibility = body.visibility;
        return send(res, 200, { room: rooms.publicView(room, me) });
      }
      if (!m[2] && method === 'DELETE') {
        if (!canManage(me, room)) throw new HttpError(403, 'not_your_room');
        rooms.close(room, `closed by ${me.name}`);
        return send(res, 200, { ok: true });
      }
    }
    throw new HttpError(404, 'not_found');
  }

  async function handleRequest(req, res) {
    try {
      await route(req, res);
    } catch (err) {
      if (err instanceof HttpError) {
        if (!res.headersSent) send(res, err.status, { error: err.code });
      } else {
        log.error(`request failed: ${err?.stack ?? err}`);
        if (!res.headersSent) send(res, 500, { error: 'server_error' });
      }
    }
  }

  function refuse(socket, status, text) {
    socket.end(`HTTP/1.1 ${status} ${text}\r\nConnection: close\r\nContent-Length: 0\r\n\r\n`);
    socket.destroy();
  }

  /** A player connecting to their room: check, burn the ticket, forward. */
  function handleUpgrade(req, socket, head) {
    socket.on('error', () => socket.destroy());
    const ip = clientIp(req);
    const match = PLAY_RE.exec(new URL(req.url, 'http://local').pathname);
    if (!match) return refuse(socket, 404, 'Not Found');
    if (!originOk(req, false)) return refuse(socket, 403, 'Forbidden');
    const open = socketsPerIp.get(ip) ?? 0;
    if (open >= L.socketsPerIp) return refuse(socket, 429, 'Too Many Requests');
    const room = rooms.get(match[1]);
    if (!room || room.state !== 'ready') return refuse(socket, 404, 'Not Found');
    const ticket = readTicket(match[2], room);
    if (!ticket || !nonces.burn(ticket.j, ticket.e * 1000)) return refuse(socket, 403, 'Forbidden');

    socketsPerIp.set(ip, open + 1);
    wss.handleUpgrade(req, socket, head, (client) => {
      log.info(`${ticket.n} connected to room ${room.code}`);
      pipe(client, room, () => {
        const n = (socketsPerIp.get(ip) ?? 1) - 1;
        if (n <= 0) socketsPerIp.delete(ip);
        else socketsPerIp.set(ip, n);
      });
    });
  }

  /** Forward messages both ways between a player and their room's server. */
  function pipe(client, room, onDone) {
    const upstream = new WebSocket(`ws://127.0.0.1:${room.port}/`, {
      perMessageDeflate: false, maxPayload: L.maxMessageBytes, handshakeTimeout: 5000,
    });
    const bucket = new TokenBucket(L.messagesPerSecond);
    const queue = [];
    let finished = false;
    const finish = () => {
      if (finished) return;
      finished = true;
      rooms.off('closed', onRoomClosed);
      client.terminate();
      upstream.terminate();
      onDone();
    };
    const onRoomClosed = (r) => r === room && finish();
    rooms.on('closed', onRoomClosed);

    client.on('message', (data, isBinary) => {
      if (!bucket.take()) {
        client.close(1008, 'too fast');
        return finish();
      }
      if (upstream.readyState === WebSocket.OPEN) upstream.send(data, { binary: isBinary });
      else if (queue.length < 64) queue.push([data, isBinary]);
      else finish();
    });
    upstream.on('open', () => {
      for (const [data, isBinary] of queue.splice(0)) upstream.send(data, { binary: isBinary });
    });
    upstream.on('message', (data, isBinary) => {
      if (client.readyState === WebSocket.OPEN) client.send(data, { binary: isBinary });
    });
    for (const ws of [client, upstream]) {
      ws.on('close', finish);
      ws.on('error', finish);
    }
  }

  const sweeper = setInterval(() => {
    for (const c of [apiPerIp, loginPerIp, loginFailsPerName, roomGuessesPerIp]) c.sweep();
    nonces.sweep();
  }, 60_000);
  sweeper.unref?.();

  return {
    handleRequest,
    handleUpgrade,
    rooms,
    auth,
    shutdown() {
      clearInterval(sweeper);
      rooms.closeAll();
    },
  };
}
