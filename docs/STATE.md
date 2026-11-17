# State

Snapshot of where the project is right now. Rewrite in place, never append.
Update together with any change that earns a CHANGELOG.md entry.

_Last updated: 2026-11-18_

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
2026-11-18: hit/heal/steal effects and an ending that lets the last blow play
out (C025); the lobby laid out again, fits Greek (C026). All playtest
feedback is done; next is a release and a new playtest.
2026-11-18: **music and rain** (C024, D010), merged: music per screen with
crossfades (fixed match-opening and game-over tracks), rain on the board
that comes and goes with its sound, a Sound button. 17 CC0 tracks from
OpenGameArt, re-encoded to ~80 kbps: 19 MB.
2026-11-18: turn flow made clear to all (C023): the server announces each
step of a turn, a step strip under the narrator shows it to everyone, the
narrator says what the turn player is doing, and Attack / End Turn only
appear after the location step (End Turn used to skip it silently).
2026-11-18: playtest feedback group 2 done (C022): this turn's cards stay
small bottom-right, a narrator bar at the top, the life track's "Who's
who" key, a clearer one-at-a-time player drawer; BUG-010 (host's match
data leaked into the lobby, broke a 2nd match) fixed.
2026-11-17: the user's first playtest with friends gave 10 points of
feedback (in IDEAS/BUGS). Group 1 done (C021): **Play again** (BUG-009: a
table could only be played once), damage/heal/steal lines flash in the
log, the pick-a-player dialog is a small bar at the top.
Before that: **bot players** (C019, D009) and the game log (C020),
committed, not released; the user hasn't tried the bots yet.
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
- **Unreleased:** bots (C019), hits + gentle ending (C025), game log (C020), play again (C021), turn
  cards / narrator / Who's who / drawer (C022), turn steps (C023),
  music and rain (C024), lobby redraw (C026). Release with
  `bash tools/release.sh`; then check Play again online.
- **Music:** the user listens and adjusts the track lists (`MUSIC` /
  `MATCH_OPENING` in `autoload/audio.gd`). New tracks: re-encode with
  ffmpeg in WSL (`-c:a libvorbis -q:a 1`); licenses in
  assets/audio/CREDITS.md (all CC0 so far).
- **Playtest feedback (2026-11-17): all done** — groups 1-4 (C021, C022,
  C025 hits, C026 lobby), plus a turn-flow clarity pass (C023), a gentler
  ending (C025), music (C024). Only "personal notes" is left, undecided.
  Next: release, then a new playtest.
- Another Claude session may be working in this repo at the same time:
  commit only your own files, by path. Run the bot test with
  `AUTOTEST_ARGS="--port=18190"` so two sessions' bots don't join each
  other's matches (it happened 2026-11-18).
- Bots: the user hasn't tried them yet; tune `server/bots/bot_weights.gd`
  from what they see (8-player stress runs: vampires won 3 of 4).
- Later: per-turn cheat card in the player hub, phone proportions/zoom.
  Reconnect is wanted but deferred (IDEAS has the user's sketch).
- Docker stack test in WSL (`online/deploy/local-test.sh`): Ubuntu WSL has
  no Docker engine yet; the user installs one or runs it on the server.

## Open bugs
BUG-002 (GUIDE button), BUG-005 (rare bot click flake), BUG-004 (exit crash
after a network session, harmless). BUG-009 (play again) fixed, to verify
online after release. BUG-001, 003, 006, 007, 010 fixed and
verified. See BUGS.md.
