# Ideas

Backlog: a reference pool, **not** a queue or a commitment. Something here
gets built only when the user asks for it. When an idea is implemented,
remove it and add a CHANGELOG.md entry. Ideas that contradict a DECISIONS.md
entry need the user's call first (see MANIFEST.md, approval gates).
Format: `- **Name** — what and why. (added YYYY-MM-DD)`

## Play & online
- **Reconnect** — let a dropped player rejoin the same seat (pairs with BUG-001).
  User's sketch (2026-11-17): keep a short record per player (seat, name,
  colour, character, their match), and show a Rejoin button if that table
  still exists. Wanted, but deferred: not ready to go this deep yet. (added 2026-11-16)
- **Bot difficulty** — easy / normal bots: more noise and less memory for
  easy (`BotBrain.NOISE`, ignore soft evidence). (added 2026-11-17)
- **Bots read public card results** — e.g. Wolf's Bite doing 3 instead of 2
  shows a vampire to everyone; bots only learn from their own questions
  today. (added 2026-11-17)
- **In-game rules guide** — user's take (2026-11-17): not a full rules
  screen but a per-turn cheat card ("what you can do this turn", a bit more
  detailed) inside the player hub. EN/EL. Fixes BUG-002. (added 2026-11-16)
- **Phones: proportions and zoom** — the game works on a phone, but you
  can't zoom, and the layout (made for a 1920×1080 PC screen) isn't
  comfortable there. Revisit the proportions in general. (added 2026-11-17)
- **Lobby redraw** — several lobby buttons are out of place or break with
  longer (Greek) texts. Lay the lobby out again. Same for the player hub's
  tabs in Greek (ΑΠΟΚΡΥΨΗ / ΠΛΗΡΟΦ. run together). Playtest 2026-11-17. (added 2026-11-17)
- **Personal notes** — a notepad for your suspicions during a match. User
  undecided ("don't love it, don't hate it"). (added 2026-11-17)

## Art & feel
- **User-drawn forest board** — replace the code-drawn ForestBoard placeholder
  with the user's own art, keeping its layout constants. (added 2026-11-16)
- **Sound effects** — dice, card draw, hits, death. (Music, rain and the
  Sound button are done: C024.) The user may look for effects on the free
  sites (OpenGameArt, Kenney, Pixabay). (added 2026-11-16)
- **Hit and steal feedback** — damage (cards and attacks), heals and steals
  happen without a clear sign. User's sketch: red splatter dots on the hit
  player's screen (flash 3-4 s, fade), a slash on their pawn and on the life
  track; similar for heals and steals. (The quick step, flashing log
  lines, is done: C021.) Playtest 2026-11-17. (added 2026-11-17)
- **Old human portrait** — there was never a classic human; draw one so
  Classic art is complete. (added 2026-11-16)

## Balance
- **Playtest balance pass** — after a few real games, tune character health,
  abilities and card counts. (added 2026-11-16)
