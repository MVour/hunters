# Bugs

Status log. Newest at the top. IDs (BUG-001, ...) are permanent: never reuse
or renumber. Each entry: area, what happens, root-cause hypothesis, impact,
status (open → fix implemented → fix verified / won't fix). Flag entries
that sit open for more than ~2 weeks.

---

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
