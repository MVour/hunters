# Bugs

Status log. Newest at the top. IDs (BUG-001, ...) are permanent: never reuse
or renumber. Each entry: area, what happens, root-cause hypothesis, impact,
status (open → fix implemented → fix verified / won't fix). Flag entries
that sit open for more than ~2 weeks.

---

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
- **Area:** `server/game_manager.gd` (functions that `await` choices/timers)
- **What happens:** If the host leaves while the server is mid-effect (e.g.
  waiting for "take one of their equipment cards" after a kill), the paused
  function resumes after GameState is reset and throws script errors.
  Reproduced by `tools/run_autotest.sh`.
- **Hypothesis:** Server functions never check the match still exists after an `await`.
- **Impact:** Medium: errors on "Back to menu"; worse for a future dedicated
  server running several matches.
- **Status:** open

### BUG-002 — GUIDE button in the main menu does nothing
- **Logged:** 2026-11-16
- **Area:** `main/main_menu.tscn`, `main/main_menu.gd`
- **What happens:** Clicking GUIDE has no effect.
- **Hypothesis:** The button has no `pressed` connection and there's no guide screen yet.
- **Impact:** Low. Looks broken to new players; no way to read the rules in-game.
- **Status:** open

### BUG-001 — A player leaving mid-match isn't handled
- **Logged:** 2026-11-16
- **Area:** `lobby/lobby.gd` `_on_peer_left`, `server/game_manager.gd` turn flow
- **What happens:** The server only logs a warning. The player stays in the
  turn order, so when it's their turn nobody can act. The match likely stalls.
  (Not reproduced yet; read from code.)
- **Hypothesis:** Only the lobby case was written (`# TODO` at `lobby.gd:96`).
- **Impact:** High for online play: one dropped connection can end the game night.
- **Status:** open
