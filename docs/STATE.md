# State

Snapshot of where the project is right now. Rewrite in place, never append.
Update together with any change that earns a CHANGELOG.md entry.

_Last updated: 2026-11-17_

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
2026-11-17: online rooms on the user's server — lobby service, Vue lobby
page, dedicated Godot room servers, Docker + Caddy, GitHub deploy (C011,
D007/D008, docs/DEPLOY.md). Built and tested locally; not deployed yet.
BUG-001 fixed.
2026-11-16: you press the dice to throw them for attacks; showier pawn moves — see C010.
Before that: all text in `i18n/strings.csv`, server sends message keys (C009).
Before that: language switch, chat, card dialogs, tighter packs (C008).
Before that: player list + click to pick (C006/C007).
Before that: clearer match screen (C005), network/state refactor (C004).

## Next
- **Live at https://play.mvrtz.com**, release v0.1.0 (2026-11-17):
  - Ubuntu server 46.225.188.241, behind its existing Caddy (C012);
  - GitHub repo MVour/hunters;
  - deploys only for `v*` tags, made with `bash tools/release.sh` from WSL
    (C013). Only WSL has the user's GitHub key.
  Next: a person creates a room and plays (the BUG-006 fix is in v0.1.0;
  the build already checks ROOM_READY); try the Windows download (C015).
- Docker stack test in WSL (`online/deploy/local-test.sh`): Ubuntu WSL has
  no Docker engine yet; the user installs one or runs it on the server.
- First real browser session: open `/game/` from the lobby page and play.
- Later: reconnect to the same seat (IDEAS).

## Open bugs
BUG-006 (rooms never started on the server: fixed, waiting for the next release), BUG-002 (GUIDE button), BUG-005 (rare bot click flake), BUG-004 (exit crash
after a network session, harmless). BUG-001 and BUG-003 fixed. See BUGS.md.
