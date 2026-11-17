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
Two setups, chosen per game by what's typed in the Join box (D007):
- **Direct**: a listen server; the host is peer 1 and a player
  (`Network.server_is_player`). `EnetTransport`, invite code `address:port`
  (default port 8080).
- **Online room**: `WsTransport` (WebSocket). The invite code is the room
  link `wss://DOMAIN/play/ROOM/TICKET`; `Network.ticket` holds the ticket
  and `LobbyNet.join()` sends it. The server is a dedicated headless Godot
  (`-- --server --port=N --room=CODE`, `network/room_server.gd`,
  `server_is_player = false`) started by the lobby service (online/, see
  docs/DEPLOY.md). It listens on 127.0.0.1 only, verifies tickets with
  `RoomTicket` (HMAC, room secret from `BOARD2D_ROOM_SECRET`), reports
  `ROOM_STATUS {json}` lines on stdout, and quits 2 min after it empties.
  `main.gd` skips all screens in this mode. The browser build reads
  `#room=…&ticket=…` (`main/online_launch.gd`) and goes back to the lobby page on leave.
- WebSocket gives a client its id only once connected:
  `MultiplayerController._on_connected_to_host` resets `GameState.local_id` then.
- **Owner** (`LobbyNet._owner_id`, mirrored to `GameState.owner_id` by
  `owner_changed`): the ticket's owner flag in online rooms, else the first
  to join; passed on when they leave the lobby. Only the owner changes the
  teams (Players / Teams presets / role counts), fills with bots, starts, and
  kicks (`request_kick`, lobby only; also removes a bot).
- **Teams:** `LobbyNet._settings` holds the role counts; their total is the
  match's player count. Presets: `Global.game_settings_default.presets`.
  The counts only change by the owner, or grow when more players are in
  than the teams have places for (`_fit_settings`).
- **After a match** (BUG-009): `LobbyNet.match_over()` (on a win, or
  when only bots are left) makes the table a lobby again: players who left
  are dropped, `in_match()` is false, new players may join. The end
  screen's Play again → `LobbyNet.back_to_lobby()` → `lobby_state` (the
  whole lobby; the lobby scene was kept under the match screen); leaving
  → the menu / the web tables page. While a client is not in the LOBBY
  phase it ignores `sync_player` / `remove_player` (its match screen reads
  the same player table); `start_game` carries the player list. Clients
  always store copies of player dicts: on the host, `call_local` hands
  over the server's own `_players` entries (BUG-010).
- **Leaving mid-match** (BUG-001): `LobbyNet._on_peer_left` →
  `MatchServer.player_left()`: the player is out (`Combat.leave`, card
  revealed, no killer), pending questions/asks/rolls are answered for them
  (skip if allowed, else the first option), and the turn moves on.

## Match server (`server/`, server only)
- `MatchNet.create_server()` (called by `LobbyNet` on start) makes a
  `MatchServer` child of MatchNet with a `ServerState` copied from the lobby.
  The match begins when every player's screen reports `loaded`.
- `MatchServer` (`match_server.gd`): lifecycle, turns
  (roll → move → location action → optional attack → end turn), server-side
  dice, the choice system (`ask()` → `present_choice` → `choice()`; an early
  answer is kept, never lost), `ask_roll()` (same system: waits for that
  player to press Roll — `prompt_roll` → their `MatchNet.roll()` — before
  an attack throw or Old Map's second roll), `wait()`.
- `CardFlow` (`card_flow.gd`): drawing, green questions, equipment, protection.
- `Combat` (`combat.gd`): damage/heal/death, attacks, reveal, abilities, winning.
- `CardEffects` (`card_effects.gd`): runs a card's effect steps (spec in docs/CARDS.md).
- Everything that waits does so on signals/timers owned by `MatchServer`, so
  `MatchNet.stop()` (on leave, host disconnect, new session) frees it and
  cancels all of it.
- **One-player messages** (your character, prompts, peeks, private info,
  green cards) always go through `MatchServer.tell(id, method, args)`: an
  RPC to a person, or straight to a bot's seat. Never `rpc_id` a player id
  directly from server code (a bot id isn't a peer).

## Bots (`server/bots/`, server only, D009)
- A bot is a lobby player with `bot: true` and an id from
  `LobbyNet.BOT_ID_BASE` (added by `request_fill_bots`). No computer, no
  connection; `MatchServer` makes a `BotSeat` for it and counts it as loaded.
- `BotSeat`: gets the seat's private messages (`receive`, from `tell`),
  answers `ask()`s (`on_choice`, with the server-only `hint`) and dice
  throws (`on_roll`), learns from public events (`observe`: who hurt or
  helped whom, answered questions), and plays its turn (`take_turn`, started
  by `_start_turn`). It calls the same `MatchServer` functions a person's
  requests reach, and waits on `MatchServer.wait()`.
- `BotMind`: beliefs. Reads only public fields of `ServerState.players` and
  what the seat was told; a hidden character is never read.
- `BotBrain`: one scoring function per choice point; `bot_weights.gd`: all
  tuning numbers. `-- --bot-log` prints beliefs and decisions.
- A match where only bots are left stops (`player_left`). Room status
  reports list people only, plus a `bots` count.

## Scenes
`main/main.tscn` → `MainMenu` → `MultiplayerController` (host/join) →
`lobby/lobby.tscn` (players, avatar picker, role counts) → on `start_game`,
`main.gd` instances `match/play_scene.tscn`. Leaving or a host disconnect
frees the play scene and returns to the menu.

Match screen (`match/play_scene.tscn` + `play_scene.gd`): board
(`ForestBoard` or, with Classic art, `ClassicBoard`), `Locations` (`GameMap`),
`PawnLayer`, `PlayerList` (right edge, play order, drawers), `Hud/PlayerHud`,
`DamageBoard` (life track, left edge; its "Who's who" key floats beside it),
`DecksContainer`, `DicesContainer`,
`CardView` popups (a player row's details drawer floats to the row's left,
`top_level`, one open at a time), the narrator bar (top centre: holds
`status_label`), `TurnCards` (this turn's cards, small, between the hub
and the right column; the passive popup sits just above them), `GameLog`
(right column under the player list: every
action from the events this screen gets, kept as Msgs and redrawn on a
language switch; damage/heal/steal lines pulse for a few seconds), and the
prompt/action/choice panels and the status line built in `play_scene.gd`.
`_refresh_buttons()` sets every turn button's visible/enabled state and the
status text ("waiting for …") from GameState; the server broadcasts
`waiting_for` (who's choosing) so other screens can show it.

**Picking a player:** a server choice whose options are all players (and
handing over a green card) becomes pick mode, `_start_pick()`: `PlayerList`
and `PawnLayer` highlight the pickable players and emit `player_picked`; the
dialog shrinks to a bar at the top of the screen (`compact`), clicks pass through it;
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
  `AUTOTEST_ARGS=--ui` makes the bots pick players by clicking rows/pawns;
  `AUTOTEST_ARGS="--bots=N --bot-log"` adds N real bots (through the lobby
  buttons' actions) and prints their decisions; `--games=N` plays N
  matches on one table (Play again). The online e2e takes the
  same args (`node scripts/e2e.mjs <godot> --bots=2`) and fails if the room
  still says "in a match" after one ended. Pictures (windowed runs):
  `--shot-lobby=`, `--shot-match=` (`--shot-drawer`, `--shot-key`), `--shot-pick=`, `--shot-end=`.

## Language
Like a front-end i18n file (D006):
- **`i18n/strings.csv`** (`keys,en,el`, sorted): every UI text. Godot imports
  it as `strings.en/.el.translation` (generated, git-ignored); registered in
  `project.godot` → internationalization.
- **Code:** `Global.text("status.your_turn_roll")`, with `{named}` blanks:
  `Global.text("notice.attack", {"attacker": name, ...})`. Some older texts
  use `%s` and are formatted with `%` after the lookup.
- **Scene files:** a Label/Button's text is its key (e.g. `"PLAY"`); Godot
  translates it by itself when the language changes.
- **Server:** sends `Msg` (`data/msg.gd`): `{"k": key, "p": params}`. Params
  may be plain values, other Msgs, or `Msg.named(card/location/character)`
  (both names + uid). Each computer renders it with `Global.msg()`, so the
  host and a Greek client see the same event in their own language.
- **Data** (cards, characters, locations, decks): `name` / `name_el` in the
  data files, shown with `Global.field()`; species via `Global.species_name()`.
- `Global.lang` ("en"/"el", saved) sets `TranslationServer`'s locale; code
  that builds text listens to `Global.language_changed`. The main scene's
  overlay layer has the language button and the chat (`main/chat_box.gd`).
- `tools/check_project` fails on: a key used but missing, a missing language,
  different placeholders in en/el, or a key nobody uses.

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
