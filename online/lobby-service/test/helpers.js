import { EventEmitter } from 'node:events';
import { PassThrough } from 'node:stream';
import { hashCode } from '../src/crypto.js';

const SAM_HASH = hashCode('sams-secret');

export function testConfig(overrides = {}) {
  return {
    publicOrigin: 'http://localhost:8787',
    listen: { host: '127.0.0.1', port: 0 },
    trustProxy: false,
    sessionSecret: 'x'.repeat(40),
    sessionEpoch: 1,
    sessionDays: 14,
    access: {
      sharedCodes: ['friends-code-1'],
      users: [{ name: 'Alex', code: 'alex-code-123' }, { name: 'Sam', codeHash: SAM_HASH }],
      admins: ['Alex'],
    },
    rooms: { maxRooms: 3, maxRoomsPerUser: 1, maxPlayers: 8, maxHours: 8, portFrom: 20000, portTo: 20009, startTimeoutSeconds: 5 },
    godot: { command: 'fake-godot', args: ['--headless'] },
    limits: { loginAttemptsPerIp: 50, loginFailuresPerName: 3, apiRequestsPerMinute: 1000, socketsPerIp: 10,
      messagesPerSecond: 80, maxMessageBytes: 65536, ticketSeconds: 60 },
    ...overrides,
  };
}

/** A pretend Godot room server: says ROOM_READY, records how it was started. */
export function fakeSpawn(record = []) {
  return (command, args, options) => {
    const child = new EventEmitter();
    child.stdout = new PassThrough();
    child.stderr = new PassThrough();
    child.exitCode = null;
    child.kill = () => {
      child.exitCode = 0;
      setImmediate(() => child.emit('exit', 0, 'SIGTERM'));
    };
    record.push({ command, args, options, child });
    setImmediate(() => child.stdout.write('ROOM_READY\n'));
    return child;
  };
}

export const silentLog = { info() {}, warn() {}, error() {} };
