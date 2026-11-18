// Rooms: one dedicated Godot server process per room (network/room_server.gd).
//
// A room has a code (the thing friends type), an owner (the player who made
// it: settings, start, kick; may close it), and is "open" (listed for every
// logged-in player) or "private" (join by code only). Its Godot server
// listens on 127.0.0.1:<port> and is only reachable through this service.
// The room's secret signs its join tickets and goes to Godot in an
// environment variable, never on the command line.

import { spawn } from 'node:child_process';
import { EventEmitter } from 'node:events';
import { randomHex, randomRoomCode } from './crypto.js';

export const VISIBILITIES = ['open', 'private'];
const TITLE_RE = /^[\p{L}\p{N} _.,!?'&()-]{1,32}$/u;

export function cleanTitle(title, fallback) {
  const t = typeof title === 'string' ? title.normalize('NFC').trim().replace(/\s+/g, ' ') : '';
  return TITLE_RE.test(t) ? t : fallback;
}

export class RoomManager extends EventEmitter {
  constructor(config, { spawnProcess = spawn, log = console } = {}) {
    super();
    this.config = config;
    this.spawnProcess = spawnProcess;
    this.log = log;
    this.rooms = new Map(); // code -> room
  }

  /** What a player may see about a room (never its secret or port). */
  publicView(room, viewer) {
    return {
      code: room.code,
      title: room.title,
      owner: room.owner,
      visibility: room.visibility,
      maxPlayers: room.maxPlayers,
      players: room.players,
      inMatch: room.inMatch,
      state: room.state,
      createdAt: room.createdAt,
      mine: !!viewer && room.owner.toLowerCase() === viewer.name.toLowerCase(),
    };
  }

  /** Open rooms, plus private ones the viewer owns or is playing in. */
  list(viewer) {
    const lower = viewer.name.toLowerCase();
    return [...this.rooms.values()]
      .filter((r) => r.state !== 'closed')
      .filter((r) => r.visibility === 'open' || viewer.admin || r.owner.toLowerCase() === lower
        || r.players.some((p) => p.toLowerCase() === lower))
      .map((r) => this.publicView(r, viewer));
  }

  get(code) {
    if (typeof code !== 'string' || code.length > 16) return null;
    const room = this.rooms.get(code.toUpperCase());
    return room && room.state !== 'closed' ? room : null;
  }

  /** Make a room and start its server. Returns {room} or {error}. */
  create(owner, { title, visibility, maxPlayers } = {}) {
    const limits = this.config.rooms;
    const live = [...this.rooms.values()].filter((r) => r.state !== 'closed');
    if (live.length >= limits.maxRooms) return { error: 'too_many_rooms' };
    const lower = owner.toLowerCase();
    if (live.filter((r) => r.owner.toLowerCase() === lower).length >= limits.maxRoomsPerUser) {
      return { error: 'you_have_a_room' };
    }
    const port = this.freePort();
    if (!port) return { error: 'too_many_rooms' };

    let code;
    do code = randomRoomCode(6); while (this.rooms.has(code));
    const players = Number.isInteger(maxPlayers) ? maxPlayers : limits.maxPlayers;
    const room = {
      code,
      title: cleanTitle(title, `${owner}'s room`),
      owner,
      visibility: VISIBILITIES.includes(visibility) ? visibility : 'private',
      maxPlayers: Math.min(Math.max(players, 2), limits.maxPlayers),
      players: [],
      inMatch: false,
      state: 'starting',
      createdAt: Date.now(),
      port,
      secret: randomHex(32),
      process: null,
      timers: [],
    };
    this.rooms.set(code, room);
    this.start(room);
    return { room };
  }

  freePort() {
    const used = new Set([...this.rooms.values()].filter((r) => r.state !== 'closed').map((r) => r.port));
    for (let p = this.config.rooms.portFrom; p <= this.config.rooms.portTo; p++) if (!used.has(p)) return p;
    return 0;
  }

  start(room) {
    const { command, args } = this.config.godot;
    const argv = [...args, '--', '--server', `--port=${room.port}`, `--room=${room.code}`, `--max-players=${room.maxPlayers}`,
      ...(this.config.godot.gameArgs ?? [])];
    // A minimal environment: no service secrets leak into the game process.
    const env = {
      PATH: process.env.PATH ?? '/usr/bin:/bin',
      HOME: process.env.BOARD2D_ROOM_HOME || '/tmp',
      BOARD2D_ROOM_SECRET: room.secret,
    };
    if (process.platform === 'win32') { // local testing on Windows
      for (const k of ['SystemRoot', 'TEMP', 'TMP', 'APPDATA', 'LOCALAPPDATA', 'USERPROFILE']) {
        if (process.env[k]) env[k] = process.env[k];
      }
    }
    const child = this.spawnProcess(command, argv, { stdio: ['ignore', 'pipe', 'pipe'], env });
    room.process = child;

    let buffer = '';
    child.stdout.setEncoding('utf8');
    child.stdout.on('data', (chunk) => {
      buffer += chunk;
      if (buffer.length > 1_000_000) buffer = buffer.slice(-10_000); // runaway output
      let nl;
      while ((nl = buffer.indexOf('\n')) !== -1) {
        this.onLine(room, buffer.slice(0, nl).trim());
        buffer = buffer.slice(nl + 1);
      }
    });
    child.stderr.setEncoding('utf8');
    child.stderr.on('data', (chunk) => {
      for (const line of chunk.split('\n')) if (line.trim()) this.log.warn(`[room ${room.code}] ${line.trim().slice(0, 300)}`);
    });
    child.on('error', (err) => {
      this.log.error(`[room ${room.code}] could not start: ${err.message}`);
      this.close(room, 'start_failed');
    });
    child.on('exit', (code, signal) => {
      this.log.info(`[room ${room.code}] server exited (${signal ?? code})`);
      this.close(room, 'exited');
    });

    const limits = this.config.rooms;
    room.timers.push(setTimeout(() => {
      if (room.state === 'starting') {
        this.log.error(`[room ${room.code}] didn't start in time`);
        this.close(room, 'start_timeout');
      }
    }, limits.startTimeoutSeconds * 1000));
    room.timers.push(setTimeout(() => this.close(room, 'max_age'), limits.maxHours * 3600_000));
    for (const t of room.timers) t.unref?.();
  }

  onLine(room, line) {
    if (line === 'ROOM_READY') {
      room.state = 'ready';
      this.log.info(`[room ${room.code}] ready on port ${room.port}`);
      this.emit('ready', room);
    } else if (line.startsWith('ROOM_STATUS ')) {
      try {
        const s = JSON.parse(line.slice(12));
        room.players = Array.isArray(s.players) ? s.players.map(String).slice(0, 8) : [];
        room.inMatch = !!s.inMatch;
        room.connected = Number(s.connected) || 0;
      } catch {
        /* ignore a garbled line */
      }
    } else if (line.startsWith('ROOM_ERROR')) {
      this.log.error(`[room ${room.code}] ${line.slice(0, 300)}`);
    } else if (line) {
      this.log.info(`[room ${room.code}] ${line.slice(0, 300)}`);
    }
  }

  /** Wait until a room's server is listening (or failed). */
  whenReady(room, timeoutMs = 30_000) {
    if (room.state === 'ready') return Promise.resolve(true);
    if (room.state === 'closed') return Promise.resolve(false);
    return new Promise((resolve) => {
      const done = (ok) => {
        clearTimeout(timer);
        this.off('ready', onReady);
        this.off('closed', onClosed);
        resolve(ok);
      };
      const onReady = (r) => r === room && done(true);
      const onClosed = (r) => r === room && done(false);
      const timer = setTimeout(() => done(false), timeoutMs);
      this.on('ready', onReady);
      this.on('closed', onClosed);
    });
  }

  close(room, reason) {
    if (room.state === 'closed') return;
    room.state = 'closed';
    for (const t of room.timers) clearTimeout(t);
    if (room.process && room.process.exitCode === null) {
      room.process.kill('SIGTERM');
      const p = room.process;
      setTimeout(() => p.exitCode === null && p.kill('SIGKILL'), 5000).unref?.();
    }
    this.rooms.delete(room.code);
    this.log.info(`[room ${room.code}] closed (${reason})`);
    this.emit('closed', room);
  }

  closeAll() {
    for (const room of [...this.rooms.values()]) this.close(room, 'shutdown');
  }
}
