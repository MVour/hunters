# Folder structure

Map of who owns what, not a file listing. Update only when a folder's purpose
changes, a top-level folder is added/removed, or a file in the key-file table
moves/renames/is removed.

> Auto-derived from a manual code read on 2026-11-16 — please review for accuracy.

```
Scenes sit next to their scripts, grouped by feature.

project.godot        Godot 4.3 project; autoloads: SignalBus, Global, GameState, Network
autoload/            global singletons: static data (global), session state (game_state), signals
network/             owns: how peers connect (Network autoload + transports)
server/              owns: match rules, server only (game_manager, card_effects)
data/                card list and character list (EN + EL)
main/                entry scene (main.tscn) + main menu
lobby/               host/join screen, waiting room, avatar picker, role settings
match/               the match screen (play_scene) and its parts:
  board/             forest board, classic board, locations, pawns
  hud/               player HUD, life track, seats
  cards/             card, deck, CardView popup, card shaders
  dice/              d6, d4, dice panel
  legacy/            old damage-board HUD, kept for possible reuse (in no scene)
assets/              the user's art: pawns/ portraits/ cards/ locations/ icons/ dices/ ui/
  legacy/            original art kept usable (Classic art): board/ portraits/ pawns/ cards/
  _source/           full source sheets + drafts; .gdignore'd (not imported, not exported)
tools/               dev tools: check_project (loads every file), autotest (bots play a match)
docs/                project docs (see MANIFEST.md)
```

## Key-file roles

| File | Owns (sole owner) |
|---|---|
| `server/game_manager.gd` | All game logic on the server: turns, moves, draws, attacks, abilities, win checks. Every `request_*` RPC lands here. |
| `network/network.gd` | Hosting/joining/leaving; the only code that picks a transport. |
| `autoload/game_state.gd` | Everything that changes during a session (players, locations, decks, turn order). |
| `autoload/global.gd` | Static data (pawns, locations, card colours, defaults) and the Classic art setting. |
| `data/cards.gd` / `data/characters.gd` | The card list and the character list (EN + EL text). |
| `server/card_effects.gd` | Applying card effects. |
| `autoload/signal_bus.gd` | Every cross-scene signal. |
| `match/play_scene.gd` | The match screen UI: prompts, action bar, choices, toasts, game-over overlay. |
