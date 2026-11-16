# Decisions

Append-only log of design and architecture choices, newest at the top. IDs
(D001, ...) are permanent. Every entry has a **Rejected** field. To change a
decision: confirm with the user, mark the old one superseded, add a new entry
(never edit the old text). Superseded entries move to docs/archive/ with a
one-line stub left here.

Standing constraints from before this log started (server-authoritative,
swappable transport, the user's own content and art, bilingual) are listed
in MANIFEST.md → Non-negotiable constraints.

---

### D004 — Client store + network actions + separate server state (2026-11-16)
- **Status:** active
- **What:** Pinia-style. `GameState` = per-computer store of what that
  player may know, written only by server messages. `LobbyNet`/`MatchNet`
  autoloads = the only RPC code (actions → requests → messages).
  `SignalBus` = subscriptions. Server truth lives apart from the store
  (`LobbyNet` server fields, `MatchServer`/`ServerState`), so a host
  sees no more than any player and a dedicated server needs no UI.
- **Why:** User's request; clear data flow; ready for a headless server and
  a lobby service.
- **Rejected:** RPCs on scene nodes (fragile node paths, server tied to UI);
  MultiplayerSynchronizer for state (no per-player secrecy); one shared
  GameState for host and server (host could see secrets; no dedicated server).

### D003 — Organise by feature, verify headless (2026-11-16)
- **Status:** active
- **What:** Folders follow features (lobby/, match/, server/, network/…),
  each scene beside its script. Every structural change is checked with
  `tools/check_project.tscn` and `tools/run_autotest.sh` (Godot 4.3 console
  build, headless) before committing.
- **Why:** Easier to find things; and there was no way to know a refactor
  hadn't broken multiplayer without a person playing two windows.
- **Rejected:** Type-based folders (scenes/, scripts/); manual testing only.

### D002 — Keep old art usable behind a toggle (2026-11-16)
- **Status:** active
- **What:** Superseded art isn't deleted or hidden in the repo. It goes in
  `assets/legacy/` and stays playable through `Global.classic_art`. New art
  plugs into the same switch points (`Global.pawns`, `Global.card_back()`,
  `GameMap`, `PlayerHud`, `play_scene` board choice).
- **Why:** The user values their original art and asked for it back alongside the new.
- **Rejected:** One art set only (forces choosing); per-asset settings (too many switches for a hobby game).

### D001 — Adopt the project-workflow docs system (2026-11-16)
- **Status:** active
- **What:** Docs live in `docs/` with MANIFEST.md as the index; sessions start
  by reading STATE.md. Root `CLAUDE.md` only points at the manifest.
- **Why:** The user wanted a backlog and a clear "where do we stand" across sessions.
- **Rejected:** Making `CLAUDE.md` itself the manifest (the skill keeps
  docs in `docs/`; a pointer keeps Claude Code auto-loading it); no system
  (status gets rebuilt from git every session).
