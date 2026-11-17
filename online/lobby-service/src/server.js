// Entry point: node src/server.js (config: see config.js / config.example.json).
import { createServer } from 'node:http';
import { loadConfig } from './config.js';
import { createApp } from './app.js';

const log = {
  info: (m) => console.log(`${new Date().toISOString()} INFO ${m}`),
  warn: (m) => console.warn(`${new Date().toISOString()} WARN ${m}`),
  error: (m) => console.error(`${new Date().toISOString()} ERROR ${m}`),
};

let config;
try {
  config = loadConfig();
} catch (err) {
  log.error(err.message);
  process.exit(1);
}

const app = createApp(config, { log });
const server = createServer(app.handleRequest);
server.on('upgrade', app.handleUpgrade);
server.headersTimeout = 10_000;
server.requestTimeout = 15_000;
server.keepAliveTimeout = 5_000;
server.maxHeadersCount = 50;
server.on('clientError', (err, socket) => socket.destroy());

server.listen(config.listen.port, config.listen.host, () => {
  log.info(`lobby service on ${config.listen.host}:${config.listen.port} for ${config.publicOrigin}`);
});

function stop(signal) {
  log.info(`${signal}: closing rooms and stopping`);
  app.shutdown();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 8000).unref();
}
process.on('SIGTERM', () => stop('SIGTERM'));
process.on('SIGINT', () => stop('SIGINT'));
