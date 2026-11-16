# Architecture

How the game is put together right now. Living reference: edit in place in
the same session as a change that makes it wrong. No history here (that's
CHANGELOG.md / DECISIONS.md).

> Auto-derived from a manual code read on 2026-11-16 — please review for accuracy.

## Stack
Godot 4.3, GDScript only, 1920×1080 canvas. No external plugins.

## Autoloads
| Name | Script | Role |
|---|---|---|
| `SignalBus` | `scripts/signal_bus.gd` | Cross-scene signals (turns, moves, cards, attacks, game over…). |
| `Global` | `scripts/global.gd` | Static data + the Classic art setting (`user://settings.cfg`). |
| `GameState` | `scripts/GameState.gd` | Session state. The server's copy is the truth. |
| `Network` | `scripts/network/network.gd` | Host / join / leave through a `NetworkTransport`. |

## Networking
- Listen server: the host is peer 1 and also a player (`Network.server_is_player`).
- Transport: `EnetTransport` behind the `NetworkTransport` interface, so a
  lobby service can replace it without touching game code.
- **Server-authoritative.** Clients call `GameManager.request_*` RPCs with
  `rpc_id(1, ...)`. The server checks them (`_can_act`, `_is_current_player`)
  and answers with `@rpc("authority")` calls that fire `SignalBus` signals
  on every peer.
- Hidden roles: each client is only sent its own character
  (`set_character`), plus whatever cards reveal to it (`private_character`).

## Scene flow
`main.tscn` → `MainMenu` → `MultiplayerController` (lobby: host/join, pick
name + pawn, game settings) → `play_scene.tscn` (instanced by `main.gd` on
`_start_game`). Leaving or host disconnect frees the play scene and goes back
to the menu.

## Match (play_scene.tscn)
- `GameManager` (`scripts/game_manager.gd`): server-side rules. Deals
  characters, shuffles locations and decks, runs turns
  (roll → move → location action → optional attack → end turn), resolves
  cards through `scripts/rules/card_effects.gd`, checks wins.
- Board: `ForestBoard` (code-drawn night clearing) or, with Classic art on,
  `ClassicBoard` (`scenes/classic_board.tscn`, the original tile map).
  `Locations` (`GameMap`) places the six `LocationSprite`s; `PawnLayer`
  animates pawns (hop, attack lunge, death).
- UI: `Hud/PlayerHud` (portrait, goal, ability, health), `DamageBoard`
  (life track), `PlayersSlots` (seats around the table), `DecksContainer`,
  `DicesContainer`, `CardView` (big card popup), plus prompt/action/choice
  panels built in `play_scene.gd`.

## Data
- Cards: `scripts/cards.gd` (spec in docs/CARDS.md). Each card names its
  effect; `card_effects.gd` applies it.
- Characters: `scripts/characters.gd` (species, health, goal, ability, timing).
- Locations and actions: `Global.deck.locations`, `Global.LOCATION_ACTIONS`.

## Art switch
`Global.classic_art` picks between the current art and the original Feb 2025
art (board, chapels, pawns, portraits, card backs). Read at match start.
Pawn textures are swapped centrally in `Global.pawns`; card backs come from
`Global.card_back()`; classic portraits are `assets/legacy/classic_portraits.tres`.
