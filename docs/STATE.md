# State

Snapshot of where the project is right now. Rewrite in place, never append.
Update together with any change that earns a CHANGELOG.md entry.

_Last updated: 2026-11-16_

## Where things are
- **Playable end to end** over LAN/direct IP: lobby, roles dealt in secret,
  roll and move, location actions, all three decks with their effects,
  attacks, abilities, reveal, death, win screen. English + Greek throughout.
- **Two art styles**: current (forest clearing, hooded pawns, new portraits)
  and **Classic** (the original Feb 2025 art), switched in the main menu.
- **Docs system** adopted today (C002, D001).

## Most recent milestone
2026-11-16: Classic art toggle — see C001.

## In flight / needs attention
- **Classic art is untested in Godot and uncommitted.** Open the editor once
  (imports `assets/legacy/pawns/`), try both modes, then commit with the new
  `.import` files.
- Never tested with friends over the internet yet (see IDEAS.md → Online play).

## Open bugs
BUG-001 (player drops mid-match), BUG-002 (GUIDE button does nothing). See BUGS.md.
