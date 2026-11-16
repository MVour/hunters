# Changelog

Append-only log, newest at the top. IDs (C001, ...) are permanent: never
reuse or renumber. One entry per non-trivial change: what changed, why, and
what was rejected. Started 2026-11-16 (earlier history is in git, not here).
Past ~800 lines, move the oldest entries verbatim to docs/archive/.

---

### C003 — Restructure by feature; dead code out; test tools (2026-11-16)
- **What:** Moved every scene and script into feature folders (autoload/,
  network/, server/, data/, main/, lobby/, match/{board,hud,cards,dice,legacy}),
  scenes next to their scripts; `GameState.gd` → `autoload/game_state.gd`.
  Loose sprites into assets/pawns, portraits, ui; old art into
  assets/legacy/{board,portraits}; source sheets and drafts into
  assets/_source (ignored by Godot). Deleted: side menu, empty waiting-lobby
  sprite, empty TileMapLayer/Control in main.tscn, the "Add Player" debug
  button, card.gd's unused texture table. Kept the old damage board in
  match/legacy/. Added tools/check_project (loads every file) and
  tools/autotest + run_autotest.sh (a host bot and a client bot play a match
  headless; found BUG-003 and BUG-004).
- **Why:** The repo was flat and cluttered; the next steps (network
  refactor, deployment) need a clear layout and a way to test without a person. See D003.
- **Rejected:** Separate scenes/ and scripts/ trees (one feature spread over
  two places); deleting the old damage board (user wants it kept).

### C002 — Adopted the project-workflow docs system (2026-11-16)
- **What:** Added MANIFEST, STATE, FOLDER_STRUCTURE, ARCHITECTURE, VISION,
  CHANGELOG, DECISIONS, BUGS, IDEAS under `docs/`, `.project-workflow/tuning.yml`,
  and a short root `CLAUDE.md` pointing to the manifest. RULES.md and CARDS.md stay as they are.
- **Why:** So any session can start cold and know where things stand, what's
  next, and what's been decided. See D001.
- **Rejected:** Backfilling history from git (the skill says logs start at adoption).

### C001 — Classic art toggle (2026-11-16)
- **What:** Main menu "Classic art" switch (saved in `user://settings.cfg`).
  When on: the original path-tile board (`scenes/classic_board.tscn`) with a
  FOREST.webp backdrop, chapel art on the locations, the original
  stick-figure pawns (recovered from git into `assets/legacy/pawns/`), the
  old card backs, and the original animated 38px portraits plus every old
  variant sheet (`assets/legacy/classic_portraits.tres`; click the HUD
  portrait to cycle). When off: the current art, unchanged.
- **Why:** The user wanted all their old art back in the game without losing the new art. See D002.
- **Rejected:** Replacing the current art outright (loses work); a live
  in-match toggle (too many places to refresh for little gain).
- **Not yet verified in Godot.**
