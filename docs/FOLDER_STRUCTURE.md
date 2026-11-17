# Folder structure

Map of who owns what, not a file listing. Update only when a folder's purpose
changes, a top-level folder is added/removed, or a file in the key-file table
moves/renames/is removed.

> Auto-derived from a manual code read on 2026-11-16 — please review for accuracy.

```
Scenes sit next to their scripts, grouped by feature.

project.godot        Godot 4.3 project; autoloads: SignalBus, Global, GameState, Network, LobbyNet, MatchNet
autoload/            static data (global), the client store (game_state), events (signal_bus)
network/             owns: everything sent over the network: connecting (network + transports),
                     lobby and match actions/requests/messages (lobby_net, match_net)
server/              owns: match rules, server only (match_server, card_flow, combat,
                     card_effects, server_state)
data/                card list, character list (EN + EL), shared board rules
main/                entry scene (main.tscn), main menu, chat box + language button overlay
lobby/               host/join screen, waiting room, avatar picker, role settings
match/               the match screen (play_scene) and its parts:
  board/             forest board, classic board, locations, pawns
  hud/               player HUD, player list (+rows), life track
  cards/             card, deck, deck pack, CardView popup (+ card_face), card shaders
  dice/              d6, d4, dice panel
  legacy/            old damage-board HUD and old seats, kept for possible reuse (in no scene)
assets/              the user's art: pawns/ portraits/ cards/ locations/ icons/ dices/ ui/
  legacy/            original art kept usable (Classic art): board/ portraits/ pawns/ cards/
  _source/           full source sheets + drafts; .gdignore'd (not imported, not exported)
i18n/                owns: every UI text, strings.csv (keys,en,el); .translation files are generated
tools/               dev tools: check_project (loads every file + checks i18n), autotest (bots play a match),
                     release.sh (tag + push = deploy)
docs/                project docs (see MANIFEST.md)
online/              owns: everything for online rooms on the server (D007/D008); .gdignore'd
  lobby-service/     Node service: logins, rooms, tickets, starts room servers, forwards WebSockets
  lobby-ui/          Vue lobby page (log in, rooms, play in browser / desktop link)
  docker/            Dockerfile (game export, page build, two images); Caddy configs:
                     site.caddy (rules) + Caddyfile (own HTTPS) / behind-proxy.Caddyfile
  deploy/            server setup, deploy script, docker-compose.yml, WSL local stack test
.github/workflows/   online.yml: tests, images to GHCR, SSH deploy, Windows build
export_presets.cfg   Godot exports: Web, Linux Server (room server), Windows Desktop
```

## Key-file roles

| File | Owns (sole owner) |
|---|---|
| `network/match_net.gd` / `network/lobby_net.gd` | The only `@rpc` code. Every client action, server request and server message. |
| `server/match_server.gd` | The match on the server: lifecycle, turns, moving, choices. Helpers: `card_flow.gd` (cards, questions, equipment), `combat.gd` (health, attacks, abilities, winning). |
| `server/server_state.gd` | The server's full truth for a match (secret characters, deck order). |
| `network/network.gd` | Hosting/joining/leaving; the only code that picks a transport (ENet or WebSocket, per game). |
| `network/room_server.gd` | Dedicated server mode for one online room (`-- --server`). |
| `online/lobby-service/src/app.js` | The lobby service's API and WebSocket entrance (all access checks). |
| `autoload/game_state.gd` | The client store: what this computer may know. Written only by LobbyNet/MatchNet messages. |
| `autoload/global.gd` | Static data (pawns, locations, card colours, defaults) and the Classic art setting. |
| `data/cards.gd` / `data/characters.gd` | The card list and the character list (EN + EL text). |
| `data/rules.gd` | Rules both sides need (reach, attack targets, equipment mods). Never duplicate these in UI or server. |
| `i18n/strings.csv` | Every player-facing UI text, English + Greek. No hard-coded text elsewhere. |
| `server/card_effects.gd` | Applying card effects. |
| `autoload/signal_bus.gd` | Every cross-scene signal. |
| `match/play_scene.gd` | The match screen UI: prompts, action bar, choices, toasts, game-over overlay. |
