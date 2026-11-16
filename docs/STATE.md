# State

Snapshot of where the project is right now. Rewrite in place, never append.
Update together with any change that earns a CHANGELOG.md entry.

_Last updated: 2026-11-16_

## Where things are
- **Playable end to end** over LAN/direct IP: lobby, roles dealt in secret,
  roll and move, location actions, all three decks, attacks, abilities,
  reveal, death, win screen. English + Greek throughout.
- **Repo restructured by feature** (C003). Headless tools: `tools/check_project.tscn`
  and `tools/run_autotest.sh` (bots play a full match).
- Classic art toggle: only for the user to look at their past work.

## Most recent milestone
2026-11-16: restructure + test tools — see C003.

## In flight
- **Network/state refactor** (agreed with the user, "like a Pinia store"):
  one store for client state, all network calls in two places (lobby, match),
  UI only listens. Then split `server/game_manager.gd` into smaller server pieces.
- Next after that: deployment and a lobby/matchmaking service.

## Open bugs
BUG-001 (player drops mid-match), BUG-002 (GUIDE button), BUG-003 (leaving
leaves server logic running), BUG-004 (exit crash after network session). See BUGS.md.
