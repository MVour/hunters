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
2026-11-17: **bot players** (C019, D009): lobby Players / Teams presets /
Fill with bots; bots play fair from inside the match server. Not released
yet; the user will test them.
Earlier 2026-11-17: live at https://play.mvrtz.com — online rooms on the user's
server: lobby service, Vue lobby page, dedicated Godot room servers, Docker +
Caddy, tag-only GitHub deploy (C011–C013, D007/D008, docs/DEPLOY.md). Then:
rooms start (C014), Windows download (C015), browser fixes (C016, v0.1.1),
fits smaller windows (C017, v0.1.2), clearer login (C018, v0.1.3). The user
played a real online game on v0.1.3: all good.
2026-11-16: you press the dice to throw them for attacks; showier pawn moves — see C010.
Before that: all text in `i18n/strings.csv`, server sends message keys (C009).
Before that: language switch, chat, card dialogs, tighter packs (C008).
Before that: player list + click to pick (C006/C007).
Before that: clearer match screen (C005), network/state refactor (C004).

## Next
- **Live at https://play.mvrtz.com**, release v0.1.3 (2026-11-17),
  confirmed in a real game.
  - Ubuntu server 46.225.188.241, behind its existing Caddy (C012);
  - GitHub repo MVour/hunters;
  - deploys only for `v*` tags, made with `bash tools/release.sh` from WSL
    (C013). Only WSL has the user's GitHub key.
- **Bots built (C019) + game log and hang fixes (C020)**, uncommitted and
  unreleased. Next: the user tests them (LAN and online), then tune
  `server/bots/bot_weights.gd` from what they see (in 8-player bot
  stress runs with 2/2/4 teams, vampires won 3 of 4: watch the balance);
  release with `bash tools/release.sh`.
- Then: per-turn cheat card in the player hub, phone proportions/zoom.
  Reconnect is wanted but deferred (IDEAS has the user's sketch).
- Docker stack test in WSL (`online/deploy/local-test.sh`): Ubuntu WSL has
  no Docker engine yet; the user installs one or runs it on the server.

## Open bugs
BUG-002 (GUIDE button), BUG-005 (rare bot click flake), BUG-004 (exit crash
after a network session, harmless). BUG-001, 003, 006, 007 fixed and
verified. See BUGS.md.
