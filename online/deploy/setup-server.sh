#!/usr/bin/env bash
# One-time server setup for board2D online (Ubuntu 22.04+/Debian 12+), as root:
#
#   sudo bash setup-server.sh play.example.com you@example.com "ssh-ed25519 AAAA... github-deploy"
#
# What it does (safe to run again):
#   - installs Docker + the compose plugin, unattended security updates, ufw
#   - firewall: only SSH, 80 and 443 open
#   - creates the "board2d" deploy user (docker access, SSH key login only)
#   - /opt/board2d: docker-compose.yml, .env (random session secret),
#     config.json (access list; starts with one random shared code, printed below)
#   - with HARDEN_SSH=1: sshd allows key logins only (no passwords)
#
# Server that already has a front door (its own Caddy/nginx on 80/443)?
#   sudo BEHIND_PROXY=127.0.0.1:8082 bash setup-server.sh ...
# board2D then listens only on that local address (plain HTTP), the firewall
# is left alone, and the script prints the lines to add to your Caddy.
set -euo pipefail

DOMAIN="${1:?usage: setup-server.sh <domain> <acme email> \"<deploy ssh public key>\"}"
EMAIL="${2:?missing ACME email}"
DEPLOY_KEY="${3:?missing deploy SSH public key (for GitHub Actions)}"
DIR=/opt/board2d
USER_NAME=board2d
HERE="$(cd "$(dirname "$0")" && pwd)"

[[ $EUID -eq 0 ]] || { echo "Run as root (sudo)."; exit 1; }
[[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || { echo "Bad domain: $DOMAIN"; exit 1; }
BEHIND_PROXY="${BEHIND_PROXY:-}"
if [[ -n "$BEHIND_PROXY" ]]; then
  [[ "$BEHIND_PROXY" =~ ^127\.0\.0\.1:[0-9]{2,5}$ ]] || { echo "BEHIND_PROXY must look like 127.0.0.1:8082"; exit 1; }
  if ss -tln | awk '{print $4}' | grep -qx "$BEHIND_PROXY"; then
    echo "Something already listens on $BEHIND_PROXY; pick another port."; exit 1
  fi
elif ss -tlnp | grep -qE ':(80|443)\s'; then
  echo "Ports 80/443 are already in use:"
  ss -tlnp | grep -E ':(80|443)\s'
  echo "Run again with BEHIND_PROXY=127.0.0.1:8082 to sit behind that front door."
  exit 1
fi

echo "== packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q ca-certificates curl gnupg ufw unattended-upgrades openssl
if ! command -v docker >/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  . /etc/os-release
  curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -q
  apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "== docker daemon defaults"
if [[ -f /etc/docker/daemon.json ]]; then
  echo "   /etc/docker/daemon.json exists; left as is"
elif [[ -n "$(docker ps -q)" ]]; then
  # Restarting Docker would stop the containers already running here.
  echo "   other containers are running: Docker NOT reconfigured/restarted"
  echo "   (board2D sets its own log limits and no-new-privileges per container)"
else
  cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "no-new-privileges": true,
  "live-restore": true
}
JSON
  systemctl restart docker
fi

compose_version="$(docker compose version --short 2>/dev/null || echo 0)"
if [[ "$(printf '%s\n2.24.0\n' "${compose_version#v}" | sort -V | head -1)" != "2.24.0" ]]; then
  echo "docker compose $compose_version is too old (need 2.24+): apt-get install --only-upgrade docker-compose-plugin"
  exit 1
fi

if [[ -n "$BEHIND_PROXY" ]]; then
  echo "== firewall: left as is (behind your front door)"
  ufw status 2>/dev/null | head -12 || true
else
echo "== firewall"
ufw default deny incoming
ufw default allow outgoing
# Keep whatever port(s) SSH really listens on open, so this can't lock you out.
for port in $(sshd -T 2>/dev/null | awk '$1=="port"{print $2}'); do ufw allow "$port/tcp"; done
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable
fi

echo "== deploy user"
id "$USER_NAME" >/dev/null 2>&1 || useradd --create-home --shell /bin/bash "$USER_NAME"
usermod -aG docker "$USER_NAME"
install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/.ssh"
grep -qxF "$DEPLOY_KEY" "/home/$USER_NAME/.ssh/authorized_keys" 2>/dev/null \
  || echo "$DEPLOY_KEY" >> "/home/$USER_NAME/.ssh/authorized_keys"
chown "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.ssh/authorized_keys"
chmod 600 "/home/$USER_NAME/.ssh/authorized_keys"

# Opt-in (HARDEN_SSH=1), because it would lock out anyone who logs in with a
# password today. Make sure YOUR key login works first.
if [[ "${HARDEN_SSH:-0}" == "1" ]]; then
  echo "== sshd: keys only"
  cat > /etc/ssh/sshd_config.d/60-board2d-hardening.conf <<'CONF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
MaxAuthTries 4
CONF
  sshd -t && { systemctl reload ssh 2>/dev/null || systemctl reload sshd; }
else
  echo "== sshd left as is (run again with HARDEN_SSH=1 to allow key logins only)"
fi

echo "== $DIR"
install -d -m 750 -o "$USER_NAME" -g "$USER_NAME" "$DIR"
install -m 640 -o "$USER_NAME" -g "$USER_NAME" "$HERE/docker-compose.yml" "$DIR/docker-compose.yml"
install -m 750 -o "$USER_NAME" -g "$USER_NAME" "$HERE/deploy.sh" "$DIR/deploy.sh"
if [[ ! -f "$DIR/.env" ]]; then
  umask 077
  sed -e "s|^DOMAIN=.*|DOMAIN=$DOMAIN|" \
      -e "s|^ACME_EMAIL=.*|ACME_EMAIL=$EMAIL|" \
      -e "s|^SESSION_SECRET=.*|SESSION_SECRET=$(openssl rand -hex 32)|" \
      "$HERE/.env.example" > "$DIR/.env"
  chown "$USER_NAME:$USER_NAME" "$DIR/.env"
  chmod 600 "$DIR/.env"
fi
if [[ ! -f "$DIR/config.json" ]]; then
  SHARED="$(openssl rand -hex 6)-$(openssl rand -hex 6)"
  cat > "$DIR/config.json" <<JSON
{
  "trustProxy": true,
  "listen": { "host": "0.0.0.0", "port": 8787 },
  "access": {
    "sharedCodes": ["$SHARED"],
    "users": [],
    "admins": []
  },
  "rooms": { "maxRooms": 6, "maxRoomsPerUser": 1, "maxPlayers": 8, "maxHours": 8 }
}
JSON
  # Readable by the container user (uid 1000), not by others.
  chown "$USER_NAME:1000" "$DIR/config.json"
  chmod 640 "$DIR/config.json"
  echo
  echo "   First access code for friends: $SHARED"
  echo "   (edit $DIR/config.json to add named users/admins, then: cd $DIR && docker compose restart lobby)"
fi

if [[ -n "$BEHIND_PROXY" ]]; then
  # docker compose loads this next to docker-compose.yml on every deploy
  # (the workflow only replaces docker-compose.yml).
  cat > "$DIR/docker-compose.override.yml" <<YML
# Written by setup-server.sh: this server's own front door does HTTPS for
# $DOMAIN and forwards to board2D on $BEHIND_PROXY (local only, plain HTTP).
services:
  web:
    command: ["caddy", "run", "--config", "/etc/caddy/behind-proxy.Caddyfile", "--adapter", "caddyfile"]
    ports: !override ["$BEHIND_PROXY:80"]
YML
  chown "$USER_NAME:$USER_NAME" "$DIR/docker-compose.override.yml"
  chmod 640 "$DIR/docker-compose.override.yml"
fi

echo
echo "Done. Next:"
if [[ -n "$BEHIND_PROXY" ]]; then
  echo " 0. Add this to your Caddy (usually /etc/caddy/Caddyfile), then: sudo systemctl reload caddy"
  echo
  echo "      $DOMAIN {"
  echo "          reverse_proxy $BEHIND_PROXY"
  echo "      }"
  echo
fi
echo " 1. DNS (GoDaddy): A record  ${DOMAIN%%.*}  ->  this server's public IP"
echo " 2. GitHub repo settings (see docs/DEPLOY.md): DEPLOY_HOST, DEPLOY_USER=$USER_NAME, DOMAIN,"
echo "    DEPLOY_SSH_KEY (the private half of the key above), DEPLOY_KNOWN_HOSTS:"
ssh-keyscan -t ed25519 localhost 2>/dev/null | sed "s/^localhost/<server IP>/" || true
echo " 3. Run the 'Online: build & deploy' workflow."
