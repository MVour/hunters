# Ideas

Backlog: a reference pool, **not** a queue or a commitment. Something here
gets built only when the user asks for it. When an idea is implemented,
remove it and add a CHANGELOG.md entry. Ideas that contradict a DECISIONS.md
entry need the user's call first (see MANIFEST.md, approval gates).
Format: `- **Name** — what and why. (added YYYY-MM-DD)`

## Play & online
- **Reconnect** — let a dropped player rejoin the same seat (pairs with BUG-001). (added 2026-11-16)
- **Bot players** — fill empty seats with computer players. A start exists:
  `tools/autotest.gd` already plays full matches through the real actions
  (random choices); it would need smarter decisions and a "add bot" lobby
  button. (added 2026-11-16)
- **In-game rules guide** — a readable EN/EL rules screen, from docs/RULES.md (fixes BUG-002). (added 2026-11-16)

## Art & feel
- **User-drawn forest board** — replace the code-drawn ForestBoard placeholder
  with the user's own art, keeping its layout constants. (added 2026-11-16)
- **Sound** — dice, card draw, hits, death, ambient night forest, music. (added 2026-11-16)
- **Old human portrait** — there was never a classic human; draw one so
  Classic art is complete. (added 2026-11-16)

## Balance
- **Playtest balance pass** — after a few real games, tune character health,
  abilities and card counts. (added 2026-11-16)
