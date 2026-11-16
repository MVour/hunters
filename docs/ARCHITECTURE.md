# Architecture

How the game is put together right now. Living reference: edit in place in
the same session as a change that makes it wrong. No history here (that's
CHANGELOG.md / DECISIONS.md).

## Stack
Godot 4.3, GDScript only, 1920×1080 canvas. No external plugins.

## The big picture: store, actions, server

Like a Pinia store (D004):

```
 UI (lobby/, match/)            reads GameState, listens to SignalBus,
   │  calls actions              calls LobbyNet / MatchNet actions. No RPCs.
   ▼
 LobbyNet / MatchNet  ──request (rpc_id 1)──►  server side
 (network/, autoloads)                         LobbyNet._players/_settings
   ▲                                           MatchServer + ServerState
   │  messages (rpc to all / one)  ◄───────────┘
   ▼
 GameState (store) ──► SignalBus ──► UI redraws
```

- **GameState** (`autoload/game_state.gd`): what *this* computer knows: the
  players' public info, your own character, locations, turn order, role
  counts. The UI never writes it; only LobbyNet/MatchNet messages do.
- **LobbyNet / MatchNet** (`network/`): the only code with `@rpc`.
  *Actions* (`MatchNet.roll()`, `LobbyNet.choose_avatar()`…) send a request to
  the server. *Requests* run on the server with the real sender id
  (`Network.sender_id()`). *Messages* run on every (or one) computer: they
  update GameState and emit a SignalBus event. They're autoloads, so their
  node path is the same everywhere, whatever scene is open.
- **Server truth** never lives in GameState. Lobby: `LobbyNet._players`,
  `_settings`. Match: `MatchServer.state` (a `ServerState`: everyone's
  characters, deck order, discards). The host's own screen only gets what
  any other player would.

## Autoloads (load order)
| Name | Script | Role |
|---|---|---|
| `SignalBus` | `autoload/signal_bus.gd` | Every cross-scene event (store subscriptions). |
| `Global` | `autoload/global.gd` | Static data (cards, characters, locations, pawns, `DRAW_ACTIONS`) + the Classic art setting. |
| `GameState` | `autoload/game_state.gd` | The client store (see above). |
| `Network` | `network/network.gd` | Connect/host/leave through a `NetworkTransport`; emits `session_closed`, `host_disconnected`, `peer_joined/left`. |
| `LobbyNet` | `network/lobby_net.gd` | Lobby actions/requests/messages + the lobby's server truth. |
| `MatchNet` | `network/match_net.gd` | Match actions/requests/messages; owns the `MatchServer` on the server. |
| `ChatNet` | `network/chat_net.gd` | Session chat: say → server checks speaker → everyone; history to newcomers. |

## Networking
- Listen server today: the host is peer 1 and a player (`Network.server_is_player`).
- Transport: `EnetTransport` behind `NetworkTransport` (invite code = `address:port`,
  default port 8080), so a lobby service can replace it without touching game code.
- The lobby's owner is the first player to join (the host today); only they
  change role counts and start.

## Match server (`server/`, server only)
- `MatchNet.create_server()` (called by `LobbyNet` on start) makes a
  `MatchServer` child of MatchNet with a `ServerState` copied from the lobby.
  The match begins when every player's screen reports `loaded`.
- `MatchServer` (`match_server.gd`): lifecycle, turns
  (roll → move → location action → optional attack → end turn), server-side
  dice, the choice system (`ask()` → `present_choice` → `choice()`; an early
  answer is kept, never lost), `wait()`.
- `CardFlow` (`card_flow.gd`): drawing, green questions, equipment, protection.
- `Combat` (`combat.gd`): damage/heal/death, attacks, reveal, abilities, winning.
- `CardEffects` (`card_effects.gd`): runs a card's effect steps (spec in docs/CARDS.md).
- Everything that waits does so on signals/timers owned by `MatchServer`, so
  `MatchNet.stop()` (on leave, host disconnect, new session) frees it and
  cancels all of it.

## Scenes
`main/main.tscn` → `MainMenu` → `MultiplayerController` (host/join) →
`lobby/lobby.tscn` (players, avatar picker, role counts) → on `start_game`,
`main.gd` instances `match/play_scene.tscn`. Leaving or a host disconnect
frees the play scene and returns to the menu.

Match screen (`match/play_scene.tscn` + `play_scene.gd`): board
(`ForestBoard` or, with Classic art, `ClassicBoard`), `Locations` (`GameMap`),
`PawnLayer`, `PlayerList` (right edge, play order, drawers), `Hud/PlayerHud`,
`DamageBoard` (life track, left edge), `DecksContainer`, `DicesContainer`,
`CardView` popups, and the
prompt/action/choice panels and the status line built in `play_scene.gd`.
`_refresh_buttons()` sets every turn button's visible/enabled state and the
status text ("waiting for …") from GameState; the server broadcasts
`waiting_for` (who's choosing) so other screens can show it.

**Picking a player:** a server choice whose options are all players (and
handing over a green card) becomes pick mode, `_start_pick()`: `PlayerList`
and `PawnLayer` highlight the pickable players and emit `player_picked`;
open `CardView`s go passive (small, bottom-left, non-blocking); turn
buttons hide until the pick ends.

## Data
- Cards: `data/cards.gd` (spec in docs/CARDS.md). Characters: `data/characters.gd`.
- Rules shared by client and server: `data/board.gd` (`Board`: locations,
  reach) and `data/rules.gd` (`Rules`: equipment mods, in reach, attack
  targets). The UI uses them to grey out buttons the server would refuse.

## Testing (headless, Godot 4.3 console build)
- `tools/check_project.tscn`: loads and compiles every script/scene/resource.
- `tools/run_autotest.sh`: a host bot and a client bot play a match over
  localhost (port 18080) through the same actions as the UI; fails on any
  script error. `MAX_TURNS=N` makes the host leave mid-match;
  `AUTOTEST_ARGS="--show-status --slow"` prints every status line the bots saw;
  `AUTOTEST_ARGS=--ui` makes the bots pick players by clicking rows/pawns.

## Language
`Global.lang` ("en"/"el", saved). Client text: `Global.t("en", "el")`;
data fields: `Global.field(card, "name")` → `name_el` in Greek. Server-sent
bilingual text is `"en  ·  el"`, split with `Global.pick()`. UI that sets
text once listens to `Global.language_changed`. The main scene adds an
overlay layer with the language button and the chat (`main/chat_box.gd`).

## The dialog
`play_scene._open_choice()`: one black dialog for choices, info and the
location offer. Options render as `DeckPack`s (value = a deck), whole cards
(value = an equipment uid, via `CardView.card_face()`), or buttons. The card
a server question is about (`_context_card`) shows on the left.

## Art switch
`Global.classic_art` picks the current art or the original Feb 2025 art (for
the user to look at past work). Pawn textures swap in `Global.pawns`; card
backs come from `Global.card_back()`; classic portraits are
`assets/legacy/portraits/classic_portraits.tres`.
