# Changelog

Append-only log, newest at the top. IDs (C001, ...) are permanent: never
reuse or renumber. One entry per non-trivial change: what changed, why, and
what was rejected. Started 2026-11-16 (earlier history is in git, not here).
Past ~800 lines, move the oldest entries verbatim to docs/archive/.

---

### C005 — Clearer match screen: disabled buttons, status line, card popup (2026-11-16)
- **What:** Attack / End Turn / Use Ability / Reveal grey out when the
  server would refuse them, with a tooltip saying why (nobody in reach, give
  your green card first, only on your turn…). A status line above the HUD
  always says what to do or who everyone is waiting on ("Waiting for Bob to
  answer your green card", "Waiting for Bob to decide…", "Bob's turn").
  New public message `MatchNet.waiting_for` (who is choosing, not what).
  Reach/attack-target rules moved to `data/rules.gd` (`Rules`), used by
  both server and UI so they can't disagree. Card popup: heading, card and
  buttons in one centred column, so buttons never cover long card text
  (checked on every card: lowest edge y=785, above the choice panel). The
  whole dice area rolls on your turn. Roll/End Turn labels bilingual.
  Removed the dead `_end_game` signal (game over now sets game_finished).
- **Why:** User feedback: unclear whose move it was, buttons that did
  nothing, card text hidden behind buttons, roll only clickable at its edge.
- **Rejected:** Client-only guesses for "who's deciding" (the client can't
  know without a message).
- **Note:** The roll-button "only the border works" report couldn't be
  reproduced headless (clicks land everywhere on it); making the whole dice
  area clickable is the likely intent. Ask the user if it persists.

### C004 — Network & state as a store; game manager split (2026-11-16)
- **What:** New autoloads `LobbyNet` and `MatchNet` hold every `@rpc`:
  actions (UI calls), requests (server checks the sender), messages (update
  `GameState`, emit `SignalBus`). UI files (lobby, game settings, avatar
  picker, play scene, dice, seats) have no network code left. Removed both
  `MultiplayerSynchronizer`s; role counts are now real messages, not copied
  label text. `GameState` is the client store only; server truth moved to
  `LobbyNet` (lobby) and `ServerState` (match: secret characters, decks).
  The 895-line `game_manager.gd` became `MatchServer` + `CardFlow` +
  `Combat` (+ `CardEffects`), created by MatchNet on the server only.
  Dice are thrown server-side. The choice system keeps an answer that arrives
  before the server starts waiting. Shared board rules in `data/board.gd`.
- **Why:** The user asked for state/network to work "like a Pinia store";
  the next goal (deployment, lobby service) needs server logic that doesn't
  live inside a UI scene. Fixes BUG-003. See D004.
- **Rejected:** Keeping RPCs on scene nodes (paths must match on every
  computer, and server logic would stay tied to the play screen); replicating
  state with MultiplayerSynchronizer (hard to keep secrets per player).
- **Verified:** check_project 63/63; run_autotest 8 full games + 3 mid-match leaves, all pass.

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
