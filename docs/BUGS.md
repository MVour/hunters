# Bugs

Status log. Newest at the top. IDs (BUG-001, ...) are permanent: never reuse
or renumber. Each entry: area, what happens, root-cause hypothesis, impact,
status (open → fix implemented → fix verified / won't fix). Flag entries
that sit open for more than ~2 weeks.

---

### BUG-002 — GUIDE button in the main menu does nothing
- **Logged:** 2026-11-16
- **Area:** `scenes/main_menu.tscn`, `main_menu.gd`
- **What happens:** Clicking GUIDE has no effect.
- **Hypothesis:** The button has no `pressed` connection and there's no guide screen yet.
- **Impact:** Low. Looks broken to new players; no way to read the rules in-game.
- **Status:** open

### BUG-001 — A player leaving mid-match isn't handled
- **Logged:** 2026-11-16
- **Area:** `scripts/lobby.gd` `_on_peer_left`, `scripts/game_manager.gd` turn flow
- **What happens:** The server only logs a warning. The player stays in the
  turn order, so when it's their turn nobody can act. The match likely stalls.
  (Not reproduced yet; read from code.)
- **Hypothesis:** Only the lobby case was written (`# TODO` at `lobby.gd:96`).
- **Impact:** High for online play: one dropped connection can end the game night.
- **Status:** open
