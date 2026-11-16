# Folder structure

Map of who owns what, not a file listing. Update only when a folder's purpose
changes, a top-level folder is added/removed, or a file in the key-file table
moves/renames/is removed.

> Auto-derived from a manual code read on 2026-11-16 — please review for accuracy.

```
project.godot        Godot 4.3 project; autoloads: SignalBus, Global, GameState, Network
main_menu.gd         main menu (Play, Quit, Add Player, Classic art toggle)
scenes/              .tscn scenes; play_scene.tscn is the match screen,
                     classic_board.tscn the original tile board
scripts/             all GDScript
  network/           owns: how peers connect (Network autoload + transports)
  rules/             owns: card effect engine (data-driven effects)
  board/             owns: board visuals — forest board, classic board,
                     location placement, pawns
  ui/                owns: reusable UI pieces (CardView)
  (root scripts)     lobby, HUD, dice, decks, seats, game manager, data
assets/              the user's art
  legacy/            originals and superseded art, kept usable (classic mode)
  portraits/ cards/ locations/ icons/ dices/ background/
shaders/             dissolve + fake-3D card shaders
docs/                project docs (see MANIFEST.md)
```

## Key-file roles

| File | Owns (sole owner) |
|---|---|
| `scripts/game_manager.gd` | All game logic on the server: turns, moves, draws, attacks, abilities, win checks. Every `request_*` RPC lands here. |
| `scripts/network/network.gd` | Hosting/joining/leaving; the only code that picks a transport. |
| `scripts/GameState.gd` | Everything that changes during a session (players, locations, decks, turn order). |
| `scripts/global.gd` | Static data (pawns, locations, card colours, defaults) and the Classic art setting. |
| `scripts/cards.gd` / `scripts/characters.gd` | The card list and the character list (EN + EL text). |
| `scripts/rules/card_effects.gd` | Applying card effects. |
| `scripts/signal_bus.gd` | Every cross-scene signal. |
| `scripts/play_scene.gd` | The match screen UI: prompts, action bar, choices, toasts, game-over overlay. |
