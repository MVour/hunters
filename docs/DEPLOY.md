# Online play: setup and operations

How the game runs on your own server (decision D007, D008). Living
reference: update it in the same session as anything under `online/`,
`.github/workflows/online.yml`, `export_presets.cfg` or the network code changes.

## What players need
- **Nothing to install.** They open `https://<your domain>`, log in with
  their name + access code, make or join a room, and press **Play in browser**.
- Optional: the **desktop game** (Windows build, made by every release or
  "Run workflow", artifact `board2D-windows`). In the lobby page press
  **Desktop link**, then paste it into the game's Join box within a minute.
- LAN / direct play is unchanged: Host on one computer, others join by `IP:port`.

So each game is either a **direct game** (someone hosts, no server) or an
**online room** (on your server). Rooms are **private** (join by code) or
**open** (listed for every logged-in player). The player who made the room is
its **owner**: role counts, Start, removing players, open/private, closing it.

## How it fits together
```
browser / desktop game
   │ https://DOMAIN            (lobby page, /game/ browser build)
   │ https://DOMAIN/api/...    (login, rooms, join tickets)
   │ wss://DOMAIN/play/ROOM/TICKET
   ▼
[web]   Caddy: HTTPS (auto certificates), security headers, static files
   │ internal Docker network (no internet access)
   ▼
[lobby] Node service (online/lobby-service): logins, rooms, tickets,
        forwards each player's WebSocket to their room
   │ 127.0.0.1:20000-20049 inside the container
   ▼
        one headless Godot server per room (`-- --server`, network/room_server.gd)
```

## Behind an existing Caddy (the user's server)
The user's server already runs Caddy (a system service) on 80/443 for other
sites. Then board2D doesn't take those ports:
```
sudo BEHIND_PROXY=127.0.0.1:8082 bash setup-server.sh play.yourdomain.com you@email.com "ssh-ed25519 ..."
```
- board2D's web container listens only on `127.0.0.1:8082`, plain HTTP
  (`online/docker/behind-proxy.Caddyfile`, chosen by
  `/opt/board2d/docker-compose.override.yml`, which deploys never replace).
- The firewall and Docker's settings are left alone; Docker is never
  restarted while other containers run.
- Add the site to the existing Caddy and reload it (`sudo systemctl reload caddy`):
  ```
  play.yourdomain.com {
      reverse_proxy 127.0.0.1:8082
  }
  ```
  That Caddy gets the certificate. WebSockets pass through on their own.
  If it logs requests, `/play/...` lines contain join tickets (single-use,
  60 s), which is harmless.
- Player IPs: the outer Caddy sets `X-Forwarded-For`; the inner one trusts
  it from private (Docker) addresses and hands the service only the
  player's address, so rate limits stay per player.
- The site rules (headers, CSP, routes) are the same in both modes:
  `online/docker/site.caddy`.

## One-time setup
1. **Server**: Ubuntu 22.04+ or Debian 12+, 2 GB RAM is plenty. Either ports
   80/443 are free (board2D's Caddy takes them), or the server already has a
   front door there: see **Behind an existing Caddy** below. Copy
   `online/deploy/` there and run, as root:
   ```
   sudo bash setup-server.sh play.yourdomain.com you@email.com "ssh-ed25519 AAAA... github-deploy"
   ```
   The last argument is the **public** half of a new key pair made only for
   GitHub (`ssh-keygen -t ed25519 -f board2d-deploy -C github-deploy`). The
   script installs Docker, opens only SSH/80/443, creates the `board2d` user,
   writes `/opt/board2d/{.env,config.json,docker-compose.yml}` and prints the
   **first access code**. `HARDEN_SSH=1` additionally turns off password logins
   (only after you've checked your own key login works).
2. **DNS at GoDaddy**: DNS → Add record → type **A**, name `play` (or `@`
   for the bare domain), value = the server's public IP, TTL 1 hour.
3. **GitHub** (repo → Settings → Secrets and variables → Actions):
   - Variables: `DEPLOY_HOST` (IP), `DEPLOY_DOMAIN` (`play.yourdomain.com`; `DOMAIN` also works),
     optional `DEPLOY_USER` (default `board2d`), `DEPLOY_PORT` (default 22).
   - Secrets: `DEPLOY_SSH_KEY` (the private key file's contents),
     `DEPLOY_KNOWN_HOSTS` (the line setup-server.sh printed, with the IP).
4. Release: `bash tools/release.sh` (from WSL, where the GitHub key is).
   See **Releasing** below.

## Releasing (= deploying)
Only version tags deploy. Pushing to `main` runs the tests and nothing else.
```
bash tools/release.sh            # next patch version, e.g. v0.1.0 -> v0.1.1
bash tools/release.sh minor      # v0.1.1 -> v0.2.0   (major, or v2.0.0, also work)
bash tools/release.sh -n         # dry run: show the version and the changes
```
- The script checks that you're on `main`, nothing is uncommitted, and
  GitHub has nothing you don't have. It shows the commits since the last
  tag and asks before going ahead.
- It creates an annotated tag listing those commits, then pushes `main`
  and the tag in one atomic push.
- The tag starts the workflow: tests → images tagged with the version
  (`board2d-lobby:v0.1.1`) → deploy → check
  `https://DOMAIN/api/health` from the internet. It also builds the
  Windows game (artifact `board2D-windows`).
- A deploy restarts the rooms, so release when nobody is playing.
- Changes to the game also need a release: the browser game and the room
  servers are inside the images.
- By hand: Actions → **Online: build & deploy** → Run workflow. Choose a
  branch or tag under "Use workflow from". You can also type another
  host/domain there for one run.

## Who may log in (`/opt/board2d/config.json`)
```json
"access": {
  "users":       [{ "name": "Alex", "code": "alex's code" },
                  { "name": "Sam",  "codeHash": "scrypt$..." }],
  "sharedCodes": ["one-code-for-all-friends"],
  "admins":      ["Alex"]
}
```
- `users`: fixed names, each with its own code. Nobody else can use that name.
- `sharedCodes`: anyone with the code picks any other name (8+ characters).
- `admins`: may see, change and close every room.
- `codeHash` instead of `code`: `npm run hash-code -- "the code"` in
  `online/lobby-service` so the plain code isn't stored on the server.
- After editing: `cd /opt/board2d && docker compose restart lobby`. Removed
  users lose access at once. To log **everyone** out, raise `"sessionEpoch"`.
- Room limits live under `"rooms"` (max rooms, rooms per player, players per
  room, hours a room may live). See `online/lobby-service/config.example.json`.

## Security, in short
- Only Caddy is exposed. The lobby service and the game rooms have no
  internet access, run as uid 1000 on a read-only filesystem, every Linux
  capability dropped, `no-new-privileges`, memory/CPU/process limits.
- HTTPS everywhere (HSTS), strict Content-Security-Policy on the lobby page,
  no framing, no referrers. The browser game's page needs `unsafe-eval` /
  `unsafe-inline` (Godot's web shell) but may only talk to this site.
- Logins: signed HttpOnly `SameSite=Strict` cookie (Secure on https);
  constant-time code checks; rate limits per IP and per name (lock after
  repeated failures); every state change must come from your own origin.
- Rooms: random 6-character codes, guesses rate-limited. Joining needs a
  **ticket**: single-use, valid 60 s, signed with that room's own secret,
  checked by the service *and* by the Godot room (which takes the player's
  name and owner flag from it, so names can't be faked in-game).
- Every player action is still checked by the server-authoritative game code;
  secret characters exist only in the room server.
- Deploys: SSH key only for a dedicated user, host key pinned, registry token
  passed over stdin and logged out after. Note: that user is in the `docker`
  group, which is root-equivalent on the server; keep the key in GitHub only.

## Operations
- Logs: `cd /opt/board2d && docker compose logs -f lobby` (logins, rooms,
  connections; tickets are never logged). `docker compose ps` for health.
- Restart everything: `docker compose restart`. Stop: `docker compose down`.
- Roll back: Actions → Run workflow → "Use workflow from" = the older tag (e.g. `v0.1.0`). Or on the server: `./deploy.sh ghcr.io/<owner> v0.1.0`.
- A room closes by itself 2 minutes after its last player leaves, or after
  `maxHours`. Owners/admins can close it from the lobby page.

## Testing locally
- `node online/lobby-service/scripts/e2e.mjs <godot console binary>`: the
  real service starts a real room; two bots log in and play through it.
- `cd online/lobby-service && npm test`: service unit + API tests.
- In WSL (Docker): `bash online/deploy/local-test.sh` builds both images and
  checks the stack at `https://localhost:8443` (HTTPS, headers, login, a room
  server starting inside the locked-down container). `GODOT=<linux godot>`
  also has two bots play through it; `KEEP=1` leaves it running.
- Lobby page development: run the service, then `npm run dev` in
  `online/lobby-ui` (proxies `/api` and `/play` to localhost:8787).

## Known limits
- A player who drops mid-match is out (character revealed, the match goes
  on, BUG-001). Rejoining the same seat isn't supported yet (IDEAS: Reconnect).
- Rooms in a match can't be joined; full rooms can't be joined.
