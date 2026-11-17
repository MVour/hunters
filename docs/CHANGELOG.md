# Changelog

Append-only log, newest at the top. IDs (C001, ...) are permanent: never
reuse or renumber. One entry per non-trivial change: what changed, why, and
what was rejected. Started 2026-11-16 (earlier history is in git, not here).
Past ~800 lines, move the oldest entries verbatim to docs/archive/.

---

### C010 — You throw the dice to attack; showier pawn moves (2026-11-16)
- **What:** Attacks no longer roll by themselves: after picking a target
  (and Frederick/Gregor's ability question), the server waits for the
  attacker to press the dice (`MatchServer.ask_roll()`, `MatchNet.prompt_roll`,
  `SignalBus.roll_requested`; prompt "Attacking X: roll the dice!"). Same for
  Mel striking back and Old Map's second roll. Dice bob and glow whenever
  they're yours to throw, jump and bounce when thrown, and the tumble slows
  down as they settle (~0.9 s). Pawn moves: crouch, pop up big above
  everything with the player's name over it, a high arc with a ground
  shadow and fading afterimages in the pawn's colour, squash + dust ring on
  landing, the location bounces. Pick-a-player dialog is click-through so it
  can't hide pawns (BUG-005, part).
- **Why:** User wants the game interactive (throwing your own attack dice)
  and moves easier to follow.
- **Rejected:** A "Roll" button inside the black dialog (the dice by the
  campfire are the thing to click, same as moving); client-side dice values
  (the server still decides every throw).
- **Verified:** check_project 71 files + 163 keys clean; plain bot runs
  (normal + leave after 6 turns) pass with attacks rolled by the bots;
  `--ui` runs with a Greek client click the dice: 8 of 9 pass, the 9th is
  BUG-005 (see there). Not yet looked at by a person in a window.

### C009 — Strings file for translations; server sends message keys (2026-11-16)
- **What:** All UI text moved into `i18n/strings.csv` (160 keys, en + el),
  imported as Godot translations; `Global.text(key, {params})` replaces the
  inline `Global.t("en","el")` pairs; `Global.pick()` removed. Scene-file
  texts are keys and switch language by themselves (stray line breaks
  removed; HUD help text rewritten). The server now sends `Msg` keys + params
  (`data/msg.gd`) for every notice, prompt, option label, private info and
  lobby problem, so announcements are finally in Greek too. Species shown
  translated. The Classic art toggle and its tooltip are keyed. The checker
  validates the strings file (missing/unused keys, missing language,
  placeholder mismatch). Bots set their own language (never the player's
  saved one); loading settings no longer rewrites the file. Picking a player
  keeps a compact dialog (no card inside) so it can't cover bottom pawns.
- **Why:** User asked for a front-end-style string dictionary. See D006.
- **Rejected:** Keeping inline pairs (D005, superseded).
- **Verified:** check_project 71 files + 160 keys clean; the checker catches a
  bad key and a placeholder typo (tested); 11 `--ui` matches in a row pass
  with English and Greek clients (status lines and announcements seen in
  Greek on the Greek client, English on the host); plain runs pass.

### C008 — Language switch, chat, card dialogs, tighter packs (2026-11-16)
- **What:** Language button bottom-left (every screen): the game shows
  English *or* Greek, saved in settings (D005); Greek names added for
  locations and location actions. Chat box above it (`network/chat_net.gd`
  + `main/chat_box.gd`): server checks the speaker, newcomers get the recent
  history. The black dialog is used more: the location offer shows the decks
  as packs ("Draw · count") to click; "which deck?" choices too; picking an
  equipment card (steal, take, give) shows the whole cards; a card that asks
  you something next ("use it now?", "choose a player") moves into the
  dialog beside the choices, so no OK first. Announcements are small black
  boxes. Decks are tight piles (3 px steps, no grey box) on the left under
  the life track. Cards pushed aside during a pick go bottom-right.
- **Why:** User requests.
- **Rejected:** Separate action-button row (removed; the dialog does it).
- **Verified:** check_project 70/70; bots: normal match, `--ui` match with
  the client in Greek (pack/card/button clicks in the dialog, player picks,
  chat both ways) — all pass. The chat check found late joiners missed
  earlier lines (fixed: history on join).

### C007 — Player list right, life track left (2026-11-16)
- **What:** Swapped sides: the player list sits in the top-right corner
  (decks are bottom-right), the life track back on the left edge.
  `DamageBoard.dock_right()` stays available but unused.
- **Why:** User preference.
- **Rejected:** —
- **Verified:** check_project 67/67; 2 `--ui` runs (32 clicks) + 1 normal run pass.

### C006 — Player list on the left; pick players by clicking them (2026-11-16)
- **What:** The seats around the board are replaced by a player list down
  the left edge (`match/hud/player_list.gd`, `player_row.gd`): play-order
  number, pawn, name, known character or "?????", damage, equipment; the
  current player highlighted; an arrow opens a drawer (character details if
  known, location, equipment with text). Whenever the server asks you to
  pick a player (attack, card targets) — and for handing over your green
  card — the pickable players light up in the list and on the board (pulsing
  ring at the pawn's feet, others faded) and you click either; the choice
  panel only shows the prompt (+ Skip if allowed). While picking, open card
  popups shrink to the bottom-left (still readable, no longer blocking), and
  the Attack/End Turn/action buttons step aside (they cover the bottom pawns).
  The life track moved to the right edge. Old seats kept in match/legacy/.
  `tools/autotest` gained `--ui`: the bots pick players by real mouse clicks
  on rows and pawns; the checker now also compiles tools/.
- **Why:** User's design: a clearer table, players as clickable things
  instead of a row of name buttons.
- **Rejected:** Keeping name buttons alongside (two ways to do one thing);
  closing open cards when a pick starts (you'd lose the card's text).
- **Verified:** check_project 67/67; 4 `--ui` runs (54 clicks, all
  registered) + normal runs pass. The click tests found two real blockers,
  both fixed: an open card popup ate the clicks, and the turn buttons
  covered pawns at the bottom location.

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
