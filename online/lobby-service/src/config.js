// Loads and checks the service configuration. Refuses to start on anything
// unsafe (missing secret, no way to log in, bad ranges) rather than guessing.
//
// Where it comes from:
//   - BOARD2D_CONFIG: path to a JSON file (default ./config.json). See
//     config.example.json for every option.
//   - BOARD2D_SESSION_SECRET: overrides "sessionSecret" (keep it out of the file).
//   - BOARD2D_PUBLIC_ORIGIN: overrides "publicOrigin" (e.g. https://play.example.com).

import { readFileSync } from 'node:fs';

const DEFAULTS = {
  publicOrigin: 'http://localhost:8787',
  listen: { host: '127.0.0.1', port: 8787 },
  // Behind Caddy: client IP = last X-Forwarded-For entry (the one Caddy added).
  trustProxy: false,
  sessionSecret: '',
  // Bump to log everyone out (invalidates every session cookie).
  sessionEpoch: 1,
  sessionDays: 14,
  access: {
    // Anyone who knows one of these codes may log in with any free name.
    sharedCodes: [],
    // Named players with their own code: [{ "name", "code" | "codeHash" }].
    users: [],
    // Names that may close/change any room.
    admins: [],
  },
  rooms: {
    maxRooms: 6,
    maxRoomsPerUser: 1,
    maxPlayers: 8,
    maxHours: 8,
    portFrom: 20000,
    portTo: 20049,
    startTimeoutSeconds: 30,
  },
  godot: {
    // The exported server binary, run as: command ...args -- --server ...
    command: '/app/game-server/board2D.x86_64',
    args: ['--headless'],
    // Extra game options after "--" (tests: ['--fast']). Empty in production.
    gameArgs: [],
  },
  limits: {
    loginAttemptsPerIp: 10,        // per 15 minutes
    loginFailuresPerName: 8,       // per 15 minutes, then that name is locked
    apiRequestsPerMinute: 120,     // per IP
    socketsPerIp: 10,
    messagesPerSecond: 80,         // per connection (burst 2x)
    maxMessageBytes: 65536,
    ticketSeconds: 60,
  },
};

function merge(base, extra) {
  const out = { ...base };
  for (const [key, value] of Object.entries(extra ?? {})) {
    if (value && typeof value === 'object' && !Array.isArray(value) && base[key] && typeof base[key] === 'object') {
      out[key] = merge(base[key], value);
    } else {
      out[key] = value;
    }
  }
  return out;
}

export function loadConfig(env = process.env) {
  const path = env.BOARD2D_CONFIG || './config.json';
  let fromFile = {};
  try {
    fromFile = JSON.parse(readFileSync(path, 'utf8'));
  } catch (err) {
    if (err.code !== 'ENOENT') throw new Error(`Can't read config ${path}: ${err.message}`);
    if (!env.BOARD2D_ALLOW_NO_CONFIG) throw new Error(`Config file ${path} not found (see config.example.json).`);
  }
  const config = merge(DEFAULTS, fromFile);
  if (env.BOARD2D_SESSION_SECRET) config.sessionSecret = env.BOARD2D_SESSION_SECRET;
  if (env.BOARD2D_PUBLIC_ORIGIN) config.publicOrigin = env.BOARD2D_PUBLIC_ORIGIN;
  return validateConfig(config);
}

export function validateConfig(config) {
  const problems = [];
  if (typeof config.sessionSecret !== 'string' || config.sessionSecret.length < 32) {
    problems.push('sessionSecret (or BOARD2D_SESSION_SECRET) must be at least 32 characters; e.g. `openssl rand -hex 32`.');
  }
  let origin;
  try {
    origin = new URL(config.publicOrigin);
  } catch {
    problems.push('publicOrigin must be a URL like https://play.example.com');
  }
  if (origin && origin.origin !== config.publicOrigin.replace(/\/$/, '')) {
    problems.push('publicOrigin must be just scheme://host[:port], no path.');
  }
  const a = config.access;
  if (!Array.isArray(a.sharedCodes) || !Array.isArray(a.users) || !Array.isArray(a.admins)) {
    problems.push('access.sharedCodes, access.users and access.admins must be lists.');
  } else {
    if (a.sharedCodes.length === 0 && a.users.length === 0) {
      problems.push('Nobody can log in: add access.users and/or access.sharedCodes.');
    }
    for (const code of a.sharedCodes) {
      if (typeof code !== 'string' || code.length < 8) problems.push('Every shared code needs 8+ characters.');
    }
    for (const user of a.users) {
      if (!user || typeof user.name !== 'string' || !user.name.trim()) problems.push('Every user needs a name.');
      else if (!user.codeHash && (typeof user.code !== 'string' || user.code.length < 6)) {
        problems.push(`User ${user.name} needs a code (6+ characters) or a codeHash.`);
      }
    }
  }
  const r = config.rooms;
  if (!(r.portFrom > 1024 && r.portTo >= r.portFrom && r.portTo < 65536)) problems.push('rooms.portFrom..portTo must be a range above 1024.');
  if (!(r.maxPlayers >= 2 && r.maxPlayers <= 8)) problems.push('rooms.maxPlayers must be 2..8.');
  if (!(r.maxRooms >= 1)) problems.push('rooms.maxRooms must be at least 1.');
  if (typeof config.godot.command !== 'string' || !config.godot.command) problems.push('godot.command is required.');
  const gameArgs = config.godot.gameArgs ?? [];
  if (!Array.isArray(gameArgs) || !gameArgs.every((a) => typeof a === 'string' && /^--[a-z-]+$/.test(a))) {
    problems.push('godot.gameArgs must be a list of plain --flags.');
  }
  if (problems.length) throw new Error('Unsafe or incomplete config:\n - ' + problems.join('\n - '));
  config.publicOrigin = origin.origin;
  config.secureCookies = origin.protocol === 'https:';
  return config;
}
