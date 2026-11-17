# board2D

A hidden-role board game for playing with friends over the internet. Each
player is secretly a vampire, werewolf or human. Players move around six
forest locations, draw cards, attack, and try to win for their side. The game
is in English and Greek.

It's a private hobby project made with Godot 4.3 (GDScript).

## Play

- **In the browser:** open https://play.mvrtz.com and log in with your name
  and the access code. Make or join a room, then press **Play in browser**.
- **On Windows:** download the game from the lobby page, under
  "Desktop game (Windows)". Unzip it and run `board2D.exe`; there's nothing to
  install. The first time, Windows says "Windows protected your PC": press
  More info → Run anyway.
- **On a LAN:** one player presses Host, and the others join with `IP:port`.
- **With bots:** in the lobby, the room's owner sets **Players** and
  **Teams**, then presses **Fill with bots**. Remove a bot with its ✕.

The full rules are in [docs/RULES.md](docs/RULES.md).

## Run it from source

Open this folder in the **Godot 4.3** editor and press Play.

Checks to run after changing code:

```bash
godot --headless --path . tools/check_project.tscn   # loads every scene and script
bash tools/run_autotest.sh                           # two test players play a full match over localhost
AUTOTEST_ARGS="--bots=6 --bot-log" MAX_TURNS=400 bash tools/run_autotest.sh   # ...with 6 bots, printing their decisions
```

The online part has its own tests: in `online/lobby-service`, run
`npm test`. See [docs/DEPLOY.md](docs/DEPLOY.md) → Testing locally.

## What's where

| Folder | What it holds |
|---|---|
| `main/`, `lobby/`, `match/` | Game screens and gameplay |
| `network/`, `server/` | Multiplayer: client store, RPCs, server-side rules |
| `autoload/` | Global singletons (state, settings, signals) |
| `assets/`, `data/`, `i18n/` | Art, card/location data, English + Greek text |
| `online/` | Lobby service (Node), lobby page (Vue), Docker + Caddy, server setup |
| `tools/` | Headless checks, bot autotest, release script |
| `docs/` | Rules, architecture, decisions, changelog, bugs, deployment |

The full map is in [docs/FOLDER_STRUCTURE.md](docs/FOLDER_STRUCTURE.md), and
how the parts connect is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Releasing

Pushing a version tag deploys the game to the server. From WSL:

```bash
bash tools/release.sh
```

The script picks the next version, tags it and pushes it. GitHub Actions then
does the rest:
- builds the images and the Windows game;
- deploys them to the server.

Setup, rollback and operations are covered in
[docs/DEPLOY.md](docs/DEPLOY.md).
