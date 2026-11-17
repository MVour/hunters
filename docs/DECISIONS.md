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

### D007 — Online play: dedicated server per room behind a lobby/relay service (2026-11-17)
- **Status:** active (not built yet)
- **What:** The user's own server runs everything. A small lobby service
  (Node.js) keeps the list of rooms: each has an id/code, an owner (the
  player who created it: settings, start, kick) and is private (join by
  code/link) or open (listed). For each room it starts one headless Godot
  process as a dedicated server (`Network.server_is_player = false`; the
  match code stays one-match-per-process) and forwards players' WebSocket
  connections to it by room id. Clients use a WebSocket transport (works in
  the browser and in desktop builds). Domain: an A record at GoDaddy,
  nginx + Let's Encrypt for wss/https.
- **Why:** User chose relay over direct P2P; with all traffic through the
  server anyway, running the match there too means a leaving host doesn't
  end the game and no player's machine holds the secrets.
- **Rejected:** Host-authoritative P2P with the server only relaying (host
  leaving ends the match; host machine holds secrets); direct WebRTC with
  signaling (needs TURN fallback and a desktop add-on); many rooms in one
  Godot process (LobbyNet/MatchNet are single-match autoloads, big refactor).

### D006 — Translations in one strings file; server sends keys (2026-11-16)
- **Status:** active (supersedes D005; refines MANIFEST constraint 5)
- **What:** Every UI text lives in `i18n/strings.csv` (`keys,en,el`), imported
  by Godot as translations. Code uses `Global.text(key, {named})`; scene-file
  texts are keys and switch by themselves. The server never sends sentences:
  it sends `Msg` (`{"k": key, "p": params}`, names via `Msg.named`) and each
  computer shows it in its own language (`Global.msg`). Card / character /
  location content stays in its data (`name` / `name_el`, `Global.field`).
  `tools/check_project` fails on missing keys, a missing language, unequal
  placeholders or unused keys. One language on screen, switched by the
  button (unchanged from D005).
- **Why:** User asked for a front-end-style string dictionary. Also the only
  way to get server announcements and prompts into both languages.
- **Rejected:** Inline pairs `Global.t("en", "el")` (D005: scattered, no
  checks, server text stuck in English); a GDScript dictionary file (no
  editor/auto-translate support); gettext .po (heavier for two languages).

### D005 — Superseded by D006, full text: docs/archive/DECISIONS_superseded.md

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
