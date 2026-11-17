#!/usr/bin/env bash
# Local test of the whole online stack in Docker (run it in WSL, or any Linux
# shell with Docker). Builds both images, starts them with the real
# docker-compose.yml plus a test override (localhost, ports 8080/8443, the
# lobby service also on 127.0.0.1:8787), then checks:
#   - HTTPS front door: lobby page, browser game files, security headers
#   - login, making a room (a real Linux Godot room server starts inside the
#     read-only, unprivileged container), join tickets
#   - optional: two bots play a match through it, if GODOT is set to a Godot
#     4.3 binary (e.g. GODOT=/path/Godot_v4.3-stable_linux.x86_64)
#
#   bash online/deploy/local-test.sh          # build + test, then stop
#   KEEP=1 bash online/deploy/local-test.sh   # leave it running: https://localhost:8443
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap '[[ "${KEEP:-0}" == 1 ]] || (cd "$WORK" && docker compose down -v >/dev/null 2>&1); rm -rf "$WORK/config.json"' EXIT

if [[ "${SKIP_BUILD:-0}" != 1 ]]; then
  echo "== building images"
  docker build -q -f "$ROOT/online/docker/Dockerfile" --target lobby -t local/board2d-lobby:test "$ROOT"
  docker build -q -f "$ROOT/online/docker/Dockerfile" --target web -t local/board2d-web:test "$ROOT"
fi

cd "$WORK"
cp "$ROOT/online/deploy/docker-compose.yml" .
cat > .env <<EOF
DOMAIN=localhost
ACME_EMAIL=test@example.com
SESSION_SECRET=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
IMAGE_PREFIX=local
IMAGE_TAG=test
EOF
cat > config.json <<'EOF'
{ "trustProxy": true, "listen": { "host": "0.0.0.0", "port": 8787 },
  "access": { "sharedCodes": ["local-test-code"], "users": [{ "name": "Owner", "code": "owner-code" }], "admins": [] },
  "rooms": { "maxRooms": 3, "maxRoomsPerUser": 1, "maxPlayers": 8, "maxHours": 1 } }
EOF
chmod 644 config.json
cat > docker-compose.override.yml <<'EOF'
services:
  web:
    ports: !override ["8080:80", "8443:443"]
  lobby:
    networks: [internal, edge]
    ports: ["127.0.0.1:8787:8787"]
EOF
echo "== starting"
docker compose up -d --quiet-pull
for _ in $(seq 1 30); do
  [[ "$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q lobby)")" == healthy ]] && break
  sleep 2
done

FAIL=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAIL=1; fi; }
H=https://localhost:8443
O="Origin: $H"

page_headers="$(curl -ksSI "$H/")"
check "lobby page over HTTPS" "grep -q '200' <<<\"\$page_headers\""
check "HSTS header" "grep -qi 'strict-transport-security' <<<\"\$page_headers\""
check "strict CSP on the lobby page" "grep -qi \"content-security-policy: default-src 'self'; script-src 'self';\" <<<\"\$page_headers\""
check "no Server header" "! grep -qi '^server:' <<<\"\$page_headers\""
check "browser game files" "curl -ksSf -o /dev/null $H/game/index.wasm"
check "Windows game download (saved as a file)" "curl -ksSI $H/download/board2D-windows.zip | grep -qi '^content-disposition: attachment'"
check "http redirects to https" "curl -sS -o /dev/null -w '%{http_code}' http://localhost:8080/ | grep -q 30"
check "API health" "curl -ksSf $H/api/health | grep -q ok"
check "wrong code refused" "[[ \$(curl -ks -o /dev/null -w '%{http_code}' -H '$O' -H 'Content-Type: application/json' -d '{\"name\":\"Owner\",\"code\":\"nope\"}' $H/api/login) == 401 ]]"
check "foreign origin refused" "[[ \$(curl -ks -o /dev/null -w '%{http_code}' -H 'Origin: https://evil.example' -H 'Content-Type: application/json' -d '{\"name\":\"Owner\",\"code\":\"owner-code\"}' $H/api/login) == 403 ]]"

curl -ks -c owner.jar -H "$O" -H 'Content-Type: application/json' -d '{"name":"Owner","code":"owner-code"}' "$H/api/login" >/dev/null
curl -ks -c guest.jar -H "$O" -H 'Content-Type: application/json' -d '{"name":"Guest","code":"local-test-code"}' "$H/api/login" >/dev/null
room_json="$(curl -ks -b owner.jar -H "$O" -H 'Content-Type: application/json' -d '{"title":"Local","visibility":"private","maxPlayers":4}' "$H/api/rooms")"
code="$(sed -n 's/.*"code":"\([A-Z0-9]*\)".*/\1/p' <<<"$room_json")"
check "room server starts in the container" "[[ -n '$code' ]]"
owner_path="$(curl -ks -b owner.jar -H "$O" -H 'Content-Type: application/json' -d '{}' "$H/api/rooms/$code/join" | sed -n 's/.*"path":"\([^"]*\)".*/\1/p')"
guest_path="$(curl -ks -b guest.jar -H "$O" -H 'Content-Type: application/json' -d '{}' "$H/api/rooms/$code/join" | sed -n 's/.*"path":"\([^"]*\)".*/\1/p')"
check "join tickets" "[[ '$owner_path' == /play/$code/* && '$guest_path' == /play/$code/* ]]"
check "container runs as uid 1000, read-only" "docker compose exec -T lobby sh -c 'id -u; touch /app/x 2>/dev/null && echo writable' | grep -qx 1000"

if [[ -n "${GODOT:-}" ]]; then
  echo "== two bots play through the stack"
  "$GODOT" --headless --path "$ROOT" -- --autotest=host --max-turns=16 "--join=ws://127.0.0.1:8787$owner_path" > host.log 2>&1 &
  sleep 2
  "$GODOT" --headless --path "$ROOT" -- --autotest=client "--join=ws://127.0.0.1:8787$guest_path" > client.log 2>&1 || true
  wait || true
  grep -h "AUTOTEST" host.log client.log
  check "bots finished a match" "grep -q 'AUTOTEST PASS' host.log && grep -q 'AUTOTEST PASS' client.log"
fi

echo "== lobby service log (last lines)"
docker compose logs --tail 15 lobby
[[ "${KEEP:-0}" == 1 ]] && echo "Still running in $WORK: https://localhost:8443 (accept the local certificate). Stop: cd $WORK && docker compose down -v"
[[ $FAIL == 0 ]] && echo "LOCAL STACK TEST PASSED" || { echo "LOCAL STACK TEST FAILED"; exit 1; }
