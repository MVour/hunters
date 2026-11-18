# Bugs

Status log. Newest at the top. IDs (BUG-001, ...) are permanent: never reuse
or renumber. Each entry: area, what happens, root-cause hypothesis, impact,
status (open → fix implemented → fix verified / won't fix). Flag entries
that sit open for more than ~2 weeks.

---

### BUG-015 — Dialog buttons over the player hub can't be clicked
- **Logged:** 2026-11-18 (user, testing C030 locally)
- **Area:** `match/play_scene.gd` (the order of its children)
- **What happens:** a dialog (e.g. a location's "Draw a card / Do nothing")
  is drawn over the player hub, but clicking its buttons does nothing; the
  hub's buttons underneath react instead.
- **Root cause:** Godot gives a click to the control that comes later in
  the scene tree; `z_index` only orders the drawing. The dialog was made
  before the hub (and big card popups, made later, did the same to the
  dialog). The UI bot pressed dialog buttons by code, not by a click, so
  the tests never noticed.
- **Fix (C031):** the play scene keeps its children in drawing order
  (`_stack_by_layer`, again whenever something is added), so what's drawn
  on top also gets the click. The UI bot now clicks dialog buttons with the
  mouse and fails if anything else is under it (checked: with the fix off,
  the test fails on exactly this).
- **Status:** fixed, verified by the UI-clicking test runs.

### BUG-014 — Phones: the browser bar takes room; the game can't be installed
- **Logged:** 2026-11-18 (user, after the v0.1.4 release)
- **Area:** `online/lobby-ui` (index.html, public/), web export preset
- **What happens:** on a phone in portrait, the browser's address bar takes
  a big slice of the screen, so the game can't use the full screen; and the
  site can't be installed as an app (PWA).
- **Root cause:** the site had no web app manifest or icons, so phones
  offer no install and a normal tab always keeps the browser's bars.
- **Fix (C027):** a site-wide manifest (`/manifest.webmanifest`, scope `/`,
  display fullscreen, the user's red card art as the icon) linked from the
  lobby page and from the game page (`html/head_include`), plus the iOS
  "home screen app" tags. Installed, the lobby and the game open full
  screen with no browser bars.
- **Status:** fix implemented, not verified (needs a release and a phone).

### BUG-013 — Cards look short and cut through the middle
- **Logged:** 2026-11-18 (user)
- **Area:** `match/cards/card_view.gd` (`card_face`), `match/hud/turn_cards.gd`
- **What happens:** card popups and this turn's small cards show a thin
  strip from the middle of the card art, so cards look squashed and cut.
- **Root cause:** the art (420 × 646) was drawn in a 380 × 180 box (62 px
  in the small cards) with "keep aspect, covered": only the middle strip shows.
- **Fix (C027):** cards keep the art's shape: the whole art is the card,
  with the name, type and text on a dark plate over its lower part. The
  small cards show the whole art with the name at the bottom; the draw
  packs use the same shape.
- **Status:** fix implemented, not verified in a real match.

### BUG-012 — A card you must decide on opens squeezed inside the dialog
- **Logged:** 2026-11-18 (user)
- **Area:** `match/play_scene.gd` (`_open_choice`, the old `choice_card_slot`)
- **What happens:** drawing a card at a location and then being asked
  about it ("use it now?", "choose…"): the card's popup closed and a small
  copy (230 px) appeared inside the black dialog, hard to read.
- **Fix (C027):** the card stays big above the dialog (`CardView.hold`:
  no buttons, clicks pass through) and closes when the dialog is answered.
- **Status:** fix implemented, not verified in a real match.

### BUG-011 — No music in the browser game
- **Logged:** 2026-11-18 (user, after the v0.1.4 release)
- **Area:** `autoload/audio.gd`, `project.godot` (audio)
- **What happens:** music and rain play on the desktop, but not in the
  browser build at play.mvrtz.com.
- **Root cause (likely; can't be reproduced locally: the local editor is
  the .NET build, which can't export to Web):** Godot 4.3's single-threaded
  web export plays sounds as browser "samples" by default. That mode
  doesn't handle what `audio.gd` does: tracks start at -80 dB and fade in,
  start mid-file, crossfade by playback position, on buses added at
  runtime. The tracks are in the build.
- **Fix (C027):** `audio/general/default_playback_type.web=0` (Stream): the
  web build mixes through Godot's own mixer, like the desktop.
- **Watch for:** crackles on slow phones (the known cost of Stream mode
  without threads). If so: bigger output latency, or rework the fades.
- **Status:** fix implemented, not verified (needs a release).

---

### BUG-010 — The host's match data leaked into the lobby's player list
- **Logged:** 2026-11-18 (found by a 2-game autotest with a Greek client)
- **Area:** `network/lobby_net.gd` (`sync_player`, `start_game`, `_players`)
- **What happens:** on the host, `call_local` messages hand over the same
  dictionaries the server keeps in `LobbyNet._players`, so the match
  writing damage / deaths / characters into `GameState.players` changed
  the lobby's entries too. A second match on the same table started with
  players already dead (a green card couldn't be handed over: stalled),
  and characters from the last match were sent around with the lobby.
- **Impact:** every "Play again" (after C021); never seen before, because a
  table could only be played once.
- **Fix (C022):** clients store copies; `match_over()` resets lobby
  entries to name / pawn / bot only. Verified: 3 matches in a row, twice,
  with bots and a Greek client.
- **Status:** fix verified

---

### BUG-009 — After a match ends, the room can't be played again
- **Logged:** 2026-11-17 (playtest)
- **Area:** `network/lobby_net.gd` (`_in_match`), `network/room_server.gd`
  status, `online/lobby-ui` RoomsView
- **What happens:** when a game ends and you pick return to lobby / exit,
  you land on the web lobby, but the room's Play button stays disabled.
- **Root cause:** `LobbyNet._in_match` turns true on start and only resets
  on a new session, so the room keeps reporting `inMatch: true` after the
  game is over; the lobby service refuses joins (`room_playing`) and the UI
  disables Play until the room empties and quits.
- **Wanted (user):** at the end, offer "play again" (same table) or "exit
  to the web lobby"; after exiting you can join any table again.
- **Impact:** every online game: a table can only be played once.
- **Fix (C021):** `LobbyNet.match_over()` makes the table a lobby again at
  the end; end screen has Play again / leave. Tested: two matches in a row
  on one table, LAN and online (`--games=2`, room reports `inMatch: false`).
- **Status:** fix implemented (verify in a real online game)

---

### BUG-008 — Two questions at once to one player: the first waits forever
- **Logged:** 2026-11-17 (found by reading, during the bot hang audit)
- **Area:** `server/match_server.gd` `_await_answer()`
- **What happens:** `_awaiting` holds one open question per player. A kill's
  "take an equipment card" pick runs alongside the rest of the attack
  (`_kill` isn't awaited), so in rare cases (e.g. a bear-trap kill in the
  same attack) a second question to the same player overwrote the first,
  which then waited forever: the turn could never end.
- **Impact:** rare, but a stuck match (people and bots alike).
- **Fix (C020):** a new question to a player who already has one open
  waits until that one is answered.
- **Status:** fix implemented; bot stress runs pass. Not reproduced on purpose.

### BUG-007 — Browser game: Host/Join buttons over the lobby; Classic art by default
- **Logged:** 2026-11-17 (first browser session, v0.1.0)
- **Area:** `lobby/multiplayer_controller.gd`, `autoload/global.gd`, `main/main.gd`
- **What happens:**
  1. When the game opens from the lobby page, the Host/Join buttons stay
     on screen, mixed into the waiting room.
  2. A new browser shows only the Classic (original) art.
  3. Esc (or Exit) quits, which leaves a dead page in a browser.
- **Cause (confirmed by reading):**
  1. The page goes straight to "connect", but only the Join button hid the
     Host/Join buttons.
  2. `classic_art` defaulted to `true`. The user's PC had "off" saved in
     settings.cfg, so they never saw it; a new browser has no saved setting.
  3. `get_tree().quit()` on the web.
- **Fix (C016):**
  1. Connecting now hides the buttons itself.
  2. `classic_art` defaults to `false`.
  3. On the web, Esc and Exit leave the session and go back to the lobby page.
- **Status:** fix verified (2026-11-17): the user played a real browser
  game on v0.1.3 with no problems.

### BUG-006 — Online rooms never started on the server ("didn't start in time")
- **Logged:** 2026-11-17 (first deploy)
- **Area:** exported room server (release build) ↔ `online/lobby-service/src/rooms.js`
- **What happens:** Every room closed after 30 s with `start_timeout`. The
  lobby log showed no output at all from the Godot process.
- **Cause (confirmed):** release builds don't flush stdout after `print()`
  (`application/run/flush_stdout_on_print` is off by default; only the
  `.debug` variant is on). On Linux, stdout into a pipe is fully buffered,
  so `ROOM_READY` stayed in the buffer. Local end-to-end tests used the
  editor (debug) binary on Windows, so they never saw it.
- **Fix (C014):** `run/flush_stdout_on_print=true` in project.godot. The
  Docker build now starts the exported room server and fails unless
  `ROOM_READY` comes through a pipe.
- **Status:** fix verified locally. Linux release export run in WSL with
  stdout piped: without the setting, 0 lines in 15 s; with it, ROOM_READY at
  once. The new build check fails on the old binary (exit 1) and passes on
  the new one (4 s). Verified on the server (2026-11-17): the user started
  and played a real online room on v0.1.3.

### BUG-005 — Rare: a bot's click on a pawn didn't register (test flake?)
- **Logged:** 2026-11-16
- **Area:** `tools/autotest.gd --ui` clicking pawns (`match/board/pawn_layer.gd` pick areas)
- **What happens:** Once in ~17 click-mode runs, a simulated click at a
  pickable pawn's centre didn't pick it; another pawn's click area was under
  the mouse. Not seen again in 11 runs after the bot learned to tell a new
  pick from a missed one (pick_serial).
- **Hypothesis:** Either that bot false alarm, or the pawn was mid-animation
  (hop/lunge/shake) when clicked, or two pawns' click areas overlap at a
  location. The failure report now prints the owner of the area under the mouse.
- **Impact:** Low; at worst a player clicks twice.
- **2026-11-16 update:** One cause found and fixed: with a Greek client the
  "pick a player" dialog wraps taller and covered a pawn at the bottom of the
  board; the dialog is now click-through during picks (only its buttons
  catch clicks). Still seen once in 9 `--ui` runs afterwards, now with the
  right pawn's (pickable) area under the mouse when checked a frame later —
  so something transient was on top at click time. Suspect: the bot clicks
  one frame after the pick opens, while the attacker's pawn is still in its
  (now longer, ~3 s) landing animation at the same spot (raised z_index).
  A person would rarely click that fast.
- **2026-11-17:** seen once more in 3 `--ui` runs after the switch to
  fractional scaling (C017), same pattern: the right pawn was under the mouse a
  frame later. The bot now converts its clicks to window pixels.
- **Status:** open (partly fixed, watching)

### BUG-004 — Godot crashes on exit after a network session (headless)
- **Logged:** 2026-11-16
- **Area:** engine shutdown (Godot 4.3 mono), seen in `tools/run_autotest.sh`
- **What happens:** After a networked match, quitting sometimes segfaults
  (signal 11). Runs without networking exit cleanly.
- **Hypothesis:** Engine teardown with an ENet peer / pending coroutines; the
  official build has no debug symbols to confirm.
- **Impact:** Low: only at exit. The smoke test reports it as a warning.
- **Status:** open

### BUG-003 — Leaving a match leaves server logic running
- **Logged:** 2026-11-16
- **Area:** the old `server/game_manager.gd` (functions that `await` choices/timers)
- **What happens:** If the host leaves while the server is mid-effect (e.g.
  waiting for "take one of their equipment cards" after a kill), the paused
  function resumes after GameState is reset and throws script errors.
  Reproduced by `tools/run_autotest.sh`.
- **Hypothesis:** Server functions never check the match still exists after an `await`.
- **Impact:** Medium: errors on "Back to menu"; worse for a future dedicated
  server running several matches.
- **Status:** fix verified (2026-11-16, C004). The match now lives in a
  `MatchServer` node that waits only on its own signals/timers;
  `MatchNet.stop()` frees it on leave/disconnect, cancelling everything.
  Verified with `MAX_TURNS=4/9/13 tools/run_autotest.sh` (host leaves mid-match: no errors).

### BUG-002 — GUIDE button in the main menu does nothing
- **Logged:** 2026-11-16
- **Area:** `main/main_menu.tscn`, `main/main_menu.gd`
- **What happens:** Clicking GUIDE has no effect.
- **Hypothesis:** The button has no `pressed` connection and there's no guide screen yet.
- **Impact:** Low. Looks broken to new players; no way to read the rules in-game.
- **Note (2026-11-18, C030):** in a match, the player hub's "This turn" tab
  is now the cheat sheet (the user's idea for the guide). The main menu's
  GUIDE button itself still does nothing: remove it, or open a short guide.
- **Status:** open

### BUG-001 — A player leaving mid-match isn't handled
- **Logged:** 2026-11-16
- **Area:** `network/lobby_net.gd` `_on_peer_left`, `server/match_server.gd` turn flow
- **What happens:** The server only logs a warning. The player stays in the
  turn order, so when it's their turn nobody can act. The match likely stalls.
  (Not reproduced yet; read from code.)
- **Hypothesis:** Only the lobby case was written (see `_on_peer_left`). Also: a pending
  `ask()` to the missing player would wait forever.
- **Impact:** High for online play: one dropped connection can end the game night.
- **Fix (2026-11-17, C011):** `MatchServer.player_left()`: the player is out
  like a death with no killer (character revealed, win checked), any choice,
  dice throw or green card waiting on them is resolved for them, the turn
  moves on; nothing is sent to the gone peer afterwards. Leaving while match
  screens load is handled too.
- **Status:** fix verified — 3 runs of 4 bots with one leaving after 5 turns:
  the match went on (to 24 turns or a normal win), no script errors; 2-bot
  leave runs end in the right win.
