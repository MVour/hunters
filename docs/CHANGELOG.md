# Changelog

Append-only log, newest at the top. IDs (C001, ...) are permanent: never
reuse or renumber. One entry per non-trivial change: what changed, why, and
what was rejected. Started 2026-11-16 (earlier history is in git, not here).
Past ~800 lines, move the oldest entries verbatim to docs/archive/.

---

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
