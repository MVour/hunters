#!/usr/bin/env bash
# Runs ON the server (as the board2d user), called by the GitHub workflow:
#   GHCR_USER=... GHCR_TOKEN=... ./deploy.sh <image prefix> <tag> [domain]
# Pulls the new images, restarts, checks health, and logs out of the registry
# (the token is only valid during the workflow run anyway).
set -euo pipefail
cd "$(dirname "$0")"

PREFIX="${1:?image prefix, e.g. ghcr.io/owner}"
TAG="${2:?image tag}"
DOMAIN_ARG="${3:-}"
[[ "$PREFIX" =~ ^[a-z0-9./_-]+$ ]] || { echo "bad image prefix"; exit 1; }
[[ "$TAG" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "bad tag"; exit 1; }

set_env() { # key value: replace or add a line in .env
  if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi
}
set_env IMAGE_PREFIX "$PREFIX"
set_env IMAGE_TAG "$TAG"
if [[ -n "$DOMAIN_ARG" ]]; then
  [[ "$DOMAIN_ARG" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || { echo "bad domain"; exit 1; }
  set_env DOMAIN "$DOMAIN_ARG"
fi

if [[ -n "${GHCR_TOKEN:-}" ]]; then
  echo "$GHCR_TOKEN" | docker login ghcr.io -u "${GHCR_USER:?}" --password-stdin >/dev/null
  trap 'docker logout ghcr.io >/dev/null 2>&1 || true' EXIT
fi

docker compose pull --quiet
docker compose up -d --remove-orphans
docker image prune -f >/dev/null

echo "waiting for the lobby service..."
for i in $(seq 1 30); do
  status="$(docker inspect --format '{{.State.Health.Status}}' "$(docker compose ps -q lobby)" 2>/dev/null || echo starting)"
  [[ "$status" == "healthy" ]] && { echo "deployed $TAG: healthy"; exit 0; }
  sleep 2
done
echo "lobby service is not healthy:"
docker compose logs --tail 50 lobby
exit 1
