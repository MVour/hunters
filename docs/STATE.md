# State

Snapshot of where the project is right now. Rewrite in place, never append.
Update together with any change that earns a CHANGELOG.md entry.

_Last updated: 2026-11-16_

## Where things are
- **Playable end to end** over LAN/direct IP: lobby, roles dealt in secret,
  roll and move, location actions, all three decks, attacks, abilities,
  reveal, death, win screen. English + Greek throughout.
- **Architecture** (C003, C004): code by feature; network and state as a
  store — `GameState` (client store) ← `LobbyNet`/`MatchNet` (all RPCs) →
  server-only `MatchServer` + `ServerState`. See ARCHITECTURE.md.
- **Headless testing**: `tools/check_project.tscn` + `tools/run_autotest.sh`
  (bots play full matches over localhost). Run both after code changes.
- Classic art toggle: only for the user to look at their past work.

## Most recent milestone
2026-11-16: language switch, chat, card dialogs, tighter packs — see C008.
Before that: player list + click to pick (C006/C007).
Before that: clearer match screen (C005), network/state refactor (C004).

## Next
- **Deployment and a lobby/matchmaking service** (user's stated next goal).
  The code is ready for it: transport is swappable, server logic has no UI.
- BUG-001 (player drops mid-match) matters for online play; fix before or with deployment.

## Open bugs
BUG-001 (player drops mid-match), BUG-002 (GUIDE button), BUG-004 (exit crash
after a network session, harmless). BUG-003 fixed. See BUGS.md.
