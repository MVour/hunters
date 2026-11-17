# syntax=docker/dockerfile:1.7
# board2D online: two images from one build (context = repository root).
#   docker build -f online/docker/Dockerfile --target lobby -t board2d-lobby .
#   docker build -f online/docker/Dockerfile --target web   -t board2d-web .
#
# lobby: the Node lobby service + the exported Godot room server (Linux).
#        Runs as an unprivileged user, read-only, no ports to the internet.
# web:   Caddy: HTTPS (automatic certificates), the lobby page, the browser
#        game, and forwarding /api + /play to the lobby service.

# --- Export the game with Godot 4.3 (official templates included) ----------
FROM barichello/godot-ci:4.3 AS godot
WORKDIR /src
COPY . .
RUN mkdir -p /out/web /out/server \
 && (godot --headless --import >/dev/null 2>&1 || true) \
 && godot --headless --export-release "Web" /out/web/index.html \
 && godot --headless --export-release "Linux Server" /out/server/board2D.x86_64 \
 && test -s /out/web/index.wasm && test -x /out/server/board2D.x86_64

# --- Build the lobby page (Vue) ---------------------------------------------
FROM node:22.12-bookworm-slim AS ui
WORKDIR /ui
COPY online/lobby-ui/package.json online/lobby-ui/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY online/lobby-ui/ ./
RUN npm run build

# --- Lobby service + room server -----------------------------------------------
FROM node:22.12-bookworm-slim AS lobby
ENV NODE_ENV=production \
    BOARD2D_CONFIG=/config/config.json \
    BOARD2D_ROOM_HOME=/tmp
WORKDIR /app
COPY online/lobby-service/package.json online/lobby-service/package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force
COPY online/lobby-service/src ./src
COPY --from=godot /out/server /app/game-server
# Everything owned by root and read-only to the service user.
RUN chmod -R a-w /app && chmod 0555 /app/game-server/board2D.x86_64
USER node
EXPOSE 8787
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:8787/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
CMD ["node", "src/server.js"]

# --- Caddy: HTTPS + static files + proxy --------------------------------------
FROM caddy:2.8.4-alpine AS web
COPY online/docker/Caddyfile online/docker/behind-proxy.Caddyfile online/docker/site.caddy /etc/caddy/
# Both front-door modes must parse, or the build (and so the deploy) stops here.
RUN DOMAIN=play.example.com ACME_EMAIL=ci@example.com sh -c \
      'caddy adapt --config /etc/caddy/Caddyfile >/dev/null && caddy adapt --config /etc/caddy/behind-proxy.Caddyfile >/dev/null'
COPY --from=ui /ui/dist /srv/lobby
COPY --from=godot /out/web /srv/game
