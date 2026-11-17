# Changelog

Append-only log, newest at the top. IDs (C001, ...) are permanent: never
reuse or renumber. One entry per non-trivial change: what changed, why, and
what was rejected. Started 2026-11-16 (earlier history is in git, not here).
Past ~800 lines, move the oldest entries verbatim to docs/archive/.

---

### C026 — Lobby laid out again; hub tabs fit in Greek (2026-11-18)
Playtest feedback group 4.
- **What:**
  - The lobby is built in code (`lobby.gd`, `create_player.gd`,
    `game_settings.gd`, look in `lobby/lobby_style.gd`), the scene is just
    the root: Back top-left; the room code + Copy centred on top; left, a
    "Players in lobby  n / total" panel of seats (full name with "…" if too
    long, pawn, a you / BOT tag, the owner's ✕ in the corner, border in the
    pawn's colour, yours gold) followed by faint free seats up to the
    teams' total (the user's animated question mark); under it your name
    and pawn picker (selected pawn framed gold, taken ones faded, a gold
    Lock); right, the teams as a 4-column grid (name | < | value | >, side
    names in their colours) so the columns line up in both languages, then
    Fill with bots and a gold START. Dark panels with a thin gold edge, as
    in the match dialogs.
  - Copy turned back into "Copy" in English after copying; now in the
    current language.
  - The player hub's tab buttons are as wide as their text (Greek ones
    ran into each other).
  - Removed: `create_player.tscn`, `question_mark_sprite.tscn/.gd` (now
    built in code), the unused "MIN 3 / MAX 8" text.
- **Why:** buttons were out of place and broke with Greek texts.
- **Rejected:** fixing the old fixed-position scene in place (any longer
  text breaks it again; containers size themselves).

---

### C025 — Hits you can't miss; the game ends after the last blow (2026-11-18)
- **What:**
  - `match/board/hit_fx.gd` (`HitFx`, from SignalBus events): damage puts
    a red claw slash over the pawn and over its life-track marker (which
    flashes); damage to YOU also splatters red drops around your screen's
    edges, flashing then fading over ~3.5 s (more drops for more damage).
    Healing: green "+" sparks rise from the pawn, the marker glows green.
    A steal (`notice.takes_from`): a small card flies from the victim's
    pawn to the taker's.
  - **The end isn't sudden:** after the winning blow the board keeps
    playing for `END_PAUSE` (3.2 s: lunge, damage, dice, death fall, log
    line) with all buttons gone, then the result fades in (and the
    game-over music starts).
  - The "miss" over a pawn is translated (`match.miss`).
  - Autotest: `--shot-hit=PATH`; it waits for the end screen to appear.
- **Why:** playtest feedback (item 2) and "let the attacks finish, then end".
- **Rejected:** full-screen red flash for every hit to anyone (too much
  with 8 players: the splatter is only for your own damage).

---

### C024 — Music, the rain that comes and goes, Sound button (2026-11-18)
From the playtest wish list (group 3, "ambient music with on/off"), with
tracks the user downloaded.
- **What:**
  - **`Audio` autoload** (`autoload/audio.gd`, local only, D010): a
    playlist per screen: **menu + lobby** (theme, Oriented, with a quiet
    forest bed under them), **match** (opens with *Ancient Evil Awakens*,
    then a no-repeat shuffle of the rest), **game over** (*Apocalypse*).
    Tracks crossfade into each other (last 4 s) and when the screen
    changes. Track lists: `MUSIC` / `MATCH_OPENING` at the top of the file.
  - **Rain** during a match: dry for a while, then rain fades in (~10 s),
    lasts 40-90 s, fades out; first shower 12-30 s in. The rain-and-thunder
    loop's volume follows it (starting somewhere new each time), and
    `match/board/rain_layer.gd` draws it over the board and pawns, under
    the HUD: streaks, splashes, a darker night, the odd lightning flash.
  - **Sound button** (`main/sound_button.gd`) next to the language button
    on every screen: Music on/off + volume, Rain on/off + volume. Saved in
    `user://settings.cfg` (`[audio]`).
  - Audio files in `assets/audio/{music,ambience}/`, all CC0 from
    OpenGameArt (no credit required), listed in `assets/audio/CREDITS.md`.
  - Re-encoded with ffmpeg (WSL) to Ogg Vorbis q1 (~80 kbps): 65 MB as
    downloaded → 19 MB (browser players download it all before the game
    starts). MP3/WAV became .ogg; Oriented kept as is (already smaller).
- **Why:** the playtest asked for mood music with an on/off; the user
  wanted the rain track behind the music, switchable, with rain on the map
  that comes and goes; one or two lobby tracks; fixed tracks for match
  start and end; fades between tracks.
- **Rejected:** streaming tracks from Suno or another site at runtime
  (fragile links, terms, a download every time); playing the rain in the
  menu (it belongs to the board).
- **Open:** track picks are guesses from file names until the user listens.

---

### C023 — Turn steps everyone can follow; no skipping by accident (2026-11-18)
User: turns and options must be intuitive, with no skips or misses, and
clear to everyone.
- **What:**
  - **Server announces the turn's step** (`MatchServer.set_step` →
    `MatchNet.turn_step`, kept in `GameState.game_info.step`): roll,
    choose_location (after a 7), location, attack_or_end, end (after the
    attack).
  - **Step strip** under the narrator line, for everyone: Roll & move ›
    Location › Attack (optional) › End turn; done steps ticked, the current
    one lit.
  - **Narrator for other players' turns** says what they're doing: rolling,
    picking a place after a 7, "is at X, deciding what to do there", may
    attack or end, ending; and "Y is answering X's green card" while one is
    out.
  - **No skipping by accident:** Attack and End Turn only appear once the
    location step is done (used, or "Do nothing here"). Before, End Turn
    was clickable while the location dialog was open and silently threw
    the location action away. The dialog's Skip now reads "Do nothing here".
  - The game log always sits under the player list (a long list no longer
    slides under it); the list fits 8 players without scrolling.
  - Fixes: a 7's "pick a location" state could stay on after the pawn had
    moved (Attack / End Turn stayed greyed); dice animations no longer
    error when the match screen closes mid-roll (Play again); card popups
    start below the taller narrator.
  - Autotest `--ui` now presses the real Attack / End Turn buttons, only
    when shown and enabled (a turn that never offers End Turn fails), and
    its stall report shows the buttons' state.
- **Rejected:** enforcing "location first" on the server (a location whose
  action finds nothing to do could leave the turn unable to end; the
  server stays lenient, the screen guides); a confirm box on End Turn
  (one more click every turn; the step strip already shows what's left).

---

### C022 — Turn cards, narrator bar, "Who's who", new player drawer (2026-11-18)
From the user's playtest feedback, group 2.
- **What:**
  - **This turn's cards** (`match/hud/turn_cards.gd`): every card shown
    this turn (drawn by anyone, your green card, a green card you were
    asked) stays as a small card between the player hub and the right
    column until the next turn; click to see it big again.
  - **Narrator bar:** the status line moved from above the hub to a
    fixed, centred bar at the top of the board (bigger text, gold edge).
    The pick-a-player bar sits right under it; card popups start below it;
    announcements start lower.
  - **Life track "Who's who":** a button on the track opens a key: how many
    of each side are in this game, every character with their health,
    grouped and coloured by side, and who is known to be whom (revealed,
    dead, you). The track's initials are in the current language and in
    their side's colour, with the names on hover.
  - **Player drawer:** one open at a time; laid out with the name in its
    colour, side + character, a damage bar (when the health is known),
    and small headings for goal, ability (marked when used), where, and
    each equipment card on its own line.
  - The small "passive" card (while picking a player) now sits above the
    turn cards instead of over the game log.
  - **Fix (BUG-010):** on the host, the lobby's player entries were the
    same dictionaries as the host's match screen data, so damage, deaths
    and characters from a match stayed in the lobby: a second match on the
    table started with dead players (stalled), and characters could reach
    other players. Clients now keep copies, and `match_over()` resets the
    lobby entries.
  - Autotest: `--shot-key`; `--shot-match` waits a moment into turn 8.
- **Why:** playtest feedback (items 1, 3, 7, 10).
- **Rejected:** a separate "last card" popup that stays open (blocks the
  board); listing only the characters actually dealt in the key (that's
  secret: the key lists all who might be in play).

---

### C021 — Play again; damage flashes in the log; pick bar on top (2026-11-17)
From the user's first playtest with friends (group 1 of their feedback).
- **What:**
  - **BUG-009, play again:** when a match ends, the table becomes a lobby
    again (`LobbyNet.match_over()`, called on a win and when only bots are
    left): people who left during the match are removed, the room reports
    `inMatch: false` (the web page's Play works again), and the owner can
    start a new match. The end screen has **Play again** (back to this
    table's lobby, `LobbyNet.back_to_lobby()` → `lobby_state`) and **Back
    to menu** / **Leave the table** (browser: back to the tables page).
    `start_game` now carries the player list, so a second match starts
    clean even for someone still on the last end screen. While a player
    is on the end screen, lobby joins/leaves aren't applied to their
    match screen (they get the whole lobby when they come back).
  - **Game log flashes:** damage and attacks (red), heals (green) and
    steals (amber) get a coloured dot, and pulse for 4 s when they happen;
    the folded header takes the same colour. The user's fuller idea
    (splatter on screen, slashes on the pawn / life track) stays in IDEAS.
  - **Picking a player:** the dialog is a small bar at the top of the
    screen (question + Skip) instead of a box at the bottom covering the
    lower board; the "click a highlighted player" line was dropped from it
    (the status line already says it).
  - End screen buttons styled; announcements no longer sit over the result.
  - Autotest: `--games=N` (Play again between matches; online e2e checks
    the room isn't left "in a match"), `--shot-pick=PATH`, `--shot-end=PATH`.
- **Why:** a table could only be played once online; damage went
  unnoticed; the pick dialog hid pawns at the bottom of the board.
- **Rejected:** sending lobby changes to players still on the end screen
  (their match screen reads the same player table and would break);
  moving the pick dialog to the middle of the board (covers the campfire
  area and pawns there).

---

### C020 — Game log; no turn can get stuck on a bot (2026-11-17)
- **What:**
  - **Game log** (`match/hud/game_log.gd`, right column under the player
    list; its header folds it to one line showing the latest entry; first
    tried top-left, but it hid the life track): every turn (with round),
    roll → location, card drawn, green card drawn / given / answered, every
    server announcement (attacks with dice, reveals, steals, protection…),
    damage and healing with totals, abilities, deaths (with killer and
    character), game over. Your own private results (peeks, Whispered
    Name…) appear marked "only you". Names in their pawn colour; redrawn
    in the other language on switch. Built only from the events this
    screen already gets, so it shows nothing a player may not know.
  - **Hang audit (bots):** the bot now keeps trying to roll, to hand over
    its green card, and to end its turn until the server takes it (each
    was a single try; a refusal at a busy moment would have stuck the turn).
  - BUG-008: a second question to a player waits for the first.
  - **Player drawers open to the LEFT of their row** (floating, over the
    board) instead of below it, so the list keeps its size and doesn't
    slide under the log. The log ends above the bottom-right card spot.
  - **Fix:** `Msg.named()` used a location's `name` (its id) before its
    `label`, so Shortcut's options and Old Map's prompts showed
    "old_chapel" instead of "Old Chapel" / "Παλιό Παρεκκλήσι".
  - Autotest `--port=N` (run a second test beside another one) and
    `--shot-match=PATH` (autotest, not headless): a match screenshot at turn 8.
- **Why:** the user asked to be sure no bot can leave a green card (or
  anything) hanging, and for an in-game log of who did what.
- **Rejected:** putting the log in the chat box (chat is for people; the
  log is long and would push messages away); building the log on the
  server and sending it (it would need its own filtering of private info;
  the client's events are already filtered).

### C019 — Bot players; lobby Players / Teams / Fill with bots (2026-11-17)
- **What:**
  - **Lobby:** the owner sets **Players** (the teams' total; applies that
    count's default teams) and cycles **Teams** presets
    (`Global.game_settings_default.presets`, e.g. 6 = 2/2/2, 3/3/0, 1/1/4;
    "own" when hand-tuned with the role buttons). **Fill with bots** adds
    bots up to the player count (and removes extra bots); ✕ removes one.
    The teams no longer reset when someone joins or leaves; they only grow
    when more people are in than the teams have places for. A person joining
    a full room takes a bot's place; a person with a bot's name gets it
    (the bot takes another). With no people left in a lobby, its bots go.
    Bots show a "(bot)" tag in the lobby and the player list.
  - **Bots (D009, `server/bots/`):** `BotSeat` plays the turn (roll → action
    → abilities → maybe attack → end), answers every server prompt, gives
    and answers green cards. `BotMind` keeps species odds per player
    (unknown characters per species × ruled out by question results and
    told health × soft evidence from who hit / helped whom, capped) and
    turns them into a relation for its own goal (vampire, werewolf, Elias,
    Ada/Iris, Hope backing her neighbour). `BotBrain` scores the options at
    each choice point. All numbers in `bot_weights.gd`.
  - **Server:** `MatchServer.tell()` for every one-player message,
    `ask(..., hint)` (context only bots get, never sent), `observe()` for
    public events bots learn from. A match with only bots left stops.
  - Room status reports count people only (+ a `bots` number), so the
    lobby service doesn't refuse joins to a room "full" of bots.
  - **Fix:** the role buttons were disabled for anyone but the server,
    so an online room's owner (a client) couldn't change the teams.
  - **Fix:** the owner's ✕ on a lobby tile went into the tile's VBox and
    shrank that player's pawn; it now sits on the tile's corner (as meant),
    and so does the BOT tag.
  - `--shot-lobby=PATH` (autotest, not headless) saves a lobby screenshot.
  - Tests: `--bots=N` for `tools/autotest.gd` (also with the online e2e),
    `--bot-log` prints each bot's beliefs and decisions.
- **Why:** the user's next big thing: games playable with bots.
- **Verified:** check_project; autotest plain, `--bots=2`, `--bots=6`
  (8 players, a full game to a win, 66 turns), `--ui --bots=2`, host leaving
  with bots; lobby-service `npm test` (13) and online e2e with and without
  bots.
- **Rejected:** see D009. Also: a separate "Add bot" button (Fill with bots
  plus ✕ covers it); keeping a separate target count next to the role counts
  (two numbers that can disagree; the teams' total is the target).

### C018 — Login: clearer errors, codes pasted with spaces work (2026-11-17)
- **What:**
  - The service trims spaces and line breaks around the access code.
    Codes never contain them, and chats often add them when copying.
  - A name that breaks the name rules now gets `400 bad_name`, with its own
    message in English and Greek, instead of "name and code don't match".
  - The login page shows the name rules under the Name field.
  - Tests cover both (unit + API).
- **Why:** a friend of the user got "don't match". The two likeliest causes
  were a pasted code with a trailing space, and a name with a character
  that isn't allowed, which was reported as a wrong code.
- **Rejected:** comparing codes without regard to case. It would weaken
  custom codes, and phones don't capitalise password fields.

### C017 — The game shrinks to fit smaller windows and screens (2026-11-17)
- **What:** `display/window/stretch/scale_mode` changed from `integer` (set
  2025-01-27) to `fractional`. The game is drawn at 1920×1080. Before, in
  any smaller window (laptops, browser windows) it couldn't scale below 1×,
  so it was cut off. Now it scales to fit and keeps its shape, with bars on
  the sides when needed. Screenshots at 1280×650 confirm both behaviours.
  The `--ui` bot converts its clicks to window pixels
  (`get_final_transform()`), because real mouse input arrives in window
  pixels too.
- **Why:** the user said it was awkward on smaller screens in the browser.
- **Rejected:**
  - Fractional scaling only on the web: desktop windows smaller or larger
    than 1080p had the same problem.
  - "expand" aspect: the screens are laid out for 16:9.
- **Note:** browser zoom (Ctrl +/-) doesn't change the game's size, because
  the game always fills the window. Use F11 for fullscreen.

### C016 — Browser game fixes: clean join screen, current art, no dead page (2026-11-17)
- **What:** fixes BUG-007:
  - joining by link hides the Host/Join buttons;
  - `Global.classic_art` defaults to off (a saved choice still wins);
  - on the web, Esc and the menu's Exit go back to the lobby page instead
    of quitting.
- **Why:** these were the first things the user saw in the browser build
  (v0.1.0).
- **Rejected:** hiding the Classic toggle on the web. The user's own art
  history stays one click away everywhere.

### C015 — The Windows game can be downloaded from the lobby page (2026-11-17)
- **What:** the Docker build exports "Windows Desktop": one .exe with the
  game packed inside. It zips it into the web image at
  `/srv/download/board2D-windows.zip`. Caddy serves `/download/*` as a file
  download only (`Content-Disposition: attachment` plus a sandboxing CSP).
  The rooms page has a "Desktop game (Windows)" section with the button
  (showing the size), three steps (unzip, the SmartScreen warning, Desktop
  link → "Host's code or room link"), in English and Greek. It shows only if
  a HEAD request finds the zip. `local-test.sh` checks the download header.
- **Why:** the user wanted friends to be able to get the desktop app from
  the site, not from GitHub.
- **Rejected:**
  - Code signing: a yearly cost, not worth it for a group of friends.
  - An installer: there's nothing to install.
  - Linking to GitHub artifacts: those need a GitHub login and expire.
- **Notes:** about 36 MB to download (88 MB unzipped, measured on a local
  export). The page builds; the image build and the download itself are
  checked by the next release.

### C014 — Room servers report back on Linux release builds (2026-11-17)
- **What:** `application/run/flush_stdout_on_print=true` fixes BUG-006, where
  no online room could start on the server. The Dockerfile's godot stage
  now runs the exported room server and needs `ROOM_READY` through a pipe,
  so a broken room server can never be deployed.
- **Why:** release builds held back piped output, so the lobby service never
  heard that a room was ready.
- **Rejected:** having the lobby service probe the room's port instead of
  reading `ROOM_READY`. It would hide the room's other output (`ROOM_STATUS`,
  errors) too.

### C013 — Deploys happen only for version tags; tools/release.sh (2026-11-17)
- **What:** the workflow now runs:
  - pushes to `main` and PRs: tests only;
  - `v*` tags: tests, images tagged with the version, deploy, Windows build;
  - Run workflow (by hand): the same as a tag, for any branch or tag
    (also used to roll back).
  Only one deploy runs at a time (`concurrency: online-deploy`).
  `tools/release.sh [patch|minor|major|vX.Y.Z] [-n] [-y]`:
  - checks that you're on `main`, nothing is uncommitted, and you aren't
    behind GitHub;
  - works out the next version and shows the commits since the last tag;
  - asks before going ahead;
  - creates an annotated tag, then pushes `main` and the tag in one
    atomic push (if the push fails, the tag is removed again).
  Also: the Windows build finds Godot's export templates on GitHub runners
  (HOME differs there), and the workflow reads the domain from
  `DEPLOY_DOMAIN` (`DOMAIN` still works).
- **Why:** the user didn't want every push to go live. A deploy restarts
  the rooms, so a match in progress is cut off.
- **Rejected:** approving each deploy in GitHub environments, and deploying
  only by hand. The user chose tags plus a script.
- **Verified:** the script was run against a throwaway repo with a local
  stand-in for GitHub: dry run, first release v0.1.0, refusal when nothing
  is new, minor bump to v0.2.0 with unpushed commits, refusal with
  uncommitted changes. The workflow changes take effect on the next push.

### C012 — board2D can sit behind the server's existing Caddy (2026-11-17)
- **What:** The user's server already runs Caddy on 80/443 (for another
  project, "oikos"). New front-door mode: `BEHIND_PROXY=127.0.0.1:8082`
  for `setup-server.sh` writes `/opt/board2d/docker-compose.override.yml`.
  The web container then serves plain HTTP on that local port
  (`online/docker/behind-proxy.Caddyfile`), and the server's Caddy forwards
  `play.<domain>` to it. Site rules moved to `online/docker/site.caddy`,
  shared by both modes. The service now gets exactly one client IP via
  `header_up X-Forwarded-For {client_ip}`; the inner Caddy trusts the outer
  one's header from private addresses.
- `setup-server.sh` is safer on a shared server:
  - It refuses to run if 80/443 are taken and `BEHIND_PROXY` isn't set.
  - It never restarts Docker while other containers run.
  - It leaves the firewall alone in proxy mode.
  - It checks for compose 2.24+.
- The Dockerfile parses both Caddy configs during the build, so a broken
  config stops the deploy.
- **Why:** Taking over 80/443 would break the existing sites. Without the
  IP fix, every player would share the outer proxy's address for rate limits.
- **Rejected:**
  - board2D's Caddy as the front door for everything: it would take over
    the user's existing setup.
  - A second public port: friends would have to type `:8443`.
- **Not verified:** Docker isn't available here (only from WSL, no engine
  yet), and downloading Caddy to check the configs was blocked. The first
  GitHub build checks the syntax; the first deploy is the real test.

### C011 — Online rooms on your own server; players can leave mid-match (2026-11-17)
- **What:** D007/D008 built.
  - Godot: `WsTransport` (WebSocket) next to ENet, chosen per game by the
    Join box (`IP:port` vs room link); dedicated room server mode
    (`-- --server`, `network/room_server.gd`); join tickets checked in-game
    (`network/room_ticket.gd`, names come from the login); a lobby owner
    everyone sees (`owner_changed`), owner-only kick; the browser build joins
    straight from the lobby page (`main/online_launch.gd`); export presets
    (Web, Linux Server, Windows Desktop). BUG-001 fixed (see BUGS.md).
  - `online/lobby-service` (Node 22, only dependency `ws`): logins (users /
    shared codes / admins, signed cookies), rooms (private/open, owner,
    limits), one Godot process per room, single-use tickets, WebSocket
    forwarding, rate limits, strict headers. 13 tests + an end-to-end script.
  - `online/lobby-ui` (Vue 3 + Vite): log in, make/join/list rooms, play in
    the browser or copy a desktop link, owner controls; English/Greek.
  - `online/docker` + `online/deploy`: Dockerfile (Godot export, page build,
    two images), Caddyfile, locked-down compose, server setup and deploy
    scripts, a WSL local stack test. `.github/workflows/online.yml`: tests,
    images to GHCR, SSH deploy to a configurable host/domain, Windows build.
  - Bots: `--join=<link>`, `--leave-after=N`, `--pawn=`, `--players=N`.
  - Docs: new DEPLOY.md; ARCHITECTURE, RULES (leaving), MANIFEST updated.
- **Why:** User's goal: game nights over the internet on their own server,
  secure, dockerised, deployable by script.
- **Rejected:** see D007/D008. Also: reconnecting to the same seat (later,
  IDEAS); a Roll/lobby UI inside Godot for online rooms (the Vue page does it).
- **Verified:** check_project 75 files + 165 keys; bots: normal, `--ui`
  Greek, host leaves; 4 bots with one leaving mid-match (3 runs); service
  `npm test` 13/13; `scripts/e2e.mjs`: real service + real room server, two
  bots log in and finish a match through the forwarding (3 runs). Docker:
  both images built and the workflow passed actionlint; the stack itself was
  NOT run (Docker is only to be used from WSL, which has no engine yet).
  Not deployed; the browser build not opened by a person yet.

### C010 — You throw the dice to attack; showier pawn moves (2026-11-16)
- **What:** Attacks no longer roll by themselves: after picking a target
  (and Frederick/Gregor's ability question), the server waits for the
  attacker to press the dice (`MatchServer.ask_roll()`, `MatchNet.prompt_roll`,
  `SignalBus.roll_requested`; prompt "Attacking X: roll the dice!"). Same for
  Mel striking back and Old Map's second roll. Dice bob and glow whenever
  they're yours to throw, jump and bounce when thrown, and the tumble slows
  down as they settle (~0.9 s). Pawn moves: crouch, pop up big above
  everything with the player's name over it, a high arc with a ground
  shadow and fading afterimages in the pawn's colour, squash + dust ring on
  landing, the location bounces. Pick-a-player dialog is click-through so it
  can't hide pawns (BUG-005, part).
- **Why:** User wants the game interactive (throwing your own attack dice)
  and moves easier to follow.
- **Rejected:** A "Roll" button inside the black dialog (the dice by the
  campfire are the thing to click, same as moving); client-side dice values
  (the server still decides every throw).
- **Verified:** check_project 71 files + 163 keys clean; plain bot runs
  (normal + leave after 6 turns) pass with attacks rolled by the bots;
  `--ui` runs with a Greek client click the dice: 8 of 9 pass, the 9th is
  BUG-005 (see there). Not yet looked at by a person in a window.

### C009 — Strings file for translations; server sends message keys (2026-11-16)
- **What:** All UI text moved into `i18n/strings.csv` (160 keys, en + el),
  imported as Godot translations; `Global.text(key, {params})` replaces the
  inline `Global.t("en","el")` pairs; `Global.pick()` removed. Scene-file
  texts are keys and switch language by themselves (stray line breaks
  removed; HUD help text rewritten). The server now sends `Msg` keys + params
  (`data/msg.gd`) for every notice, prompt, option label, private info and
  lobby problem, so announcements are finally in Greek too. Species shown
  translated. The Classic art toggle and its tooltip are keyed. The checker
  validates the strings file (missing/unused keys, missing language,
  placeholder mismatch). Bots set their own language (never the player's
  saved one); loading settings no longer rewrites the file. Picking a player
  keeps a compact dialog (no card inside) so it can't cover bottom pawns.
- **Why:** User asked for a front-end-style string dictionary. See D006.
- **Rejected:** Keeping inline pairs (D005, superseded).
- **Verified:** check_project 71 files + 160 keys clean; the checker catches a
  bad key and a placeholder typo (tested); 11 `--ui` matches in a row pass
  with English and Greek clients (status lines and announcements seen in
  Greek on the Greek client, English on the host); plain runs pass.

### C008 — Language switch, chat, card dialogs, tighter packs (2026-11-16)
- **What:** Language button bottom-left (every screen): the game shows
  English *or* Greek, saved in settings (D005); Greek names added for
  locations and location actions. Chat box above it (`network/chat_net.gd`
  + `main/chat_box.gd`): server checks the speaker, newcomers get the recent
  history. The black dialog is used more: the location offer shows the decks
  as packs ("Draw · count") to click; "which deck?" choices too; picking an
  equipment card (steal, take, give) shows the whole cards; a card that asks
  you something next ("use it now?", "choose a player") moves into the
  dialog beside the choices, so no OK first. Announcements are small black
  boxes. Decks are tight piles (3 px steps, no grey box) on the left under
  the life track. Cards pushed aside during a pick go bottom-right.
- **Why:** User requests.
- **Rejected:** Separate action-button row (removed; the dialog does it).
- **Verified:** check_project 70/70; bots: normal match, `--ui` match with
  the client in Greek (pack/card/button clicks in the dialog, player picks,
  chat both ways) — all pass. The chat check found late joiners missed
  earlier lines (fixed: history on join).

### C007 — Player list right, life track left (2026-11-16)
- **What:** Swapped sides: the player list sits in the top-right corner
  (decks are bottom-right), the life track back on the left edge.
  `DamageBoard.dock_right()` stays available but unused.
- **Why:** User preference.
- **Rejected:** —
- **Verified:** check_project 67/67; 2 `--ui` runs (32 clicks) + 1 normal run pass.

### C006 — Player list on the left; pick players by clicking them (2026-11-16)
- **What:** The seats around the board are replaced by a player list down
  the left edge (`match/hud/player_list.gd`, `player_row.gd`): play-order
  number, pawn, name, known character or "?????", damage, equipment; the
  current player highlighted; an arrow opens a drawer (character details if
  known, location, equipment with text). Whenever the server asks you to
  pick a player (attack, card targets) — and for handing over your green
  card — the pickable players light up in the list and on the board (pulsing
  ring at the pawn's feet, others faded) and you click either; the choice
  panel only shows the prompt (+ Skip if allowed). While picking, open card
  popups shrink to the bottom-left (still readable, no longer blocking), and
  the Attack/End Turn/action buttons step aside (they cover the bottom pawns).
  The life track moved to the right edge. Old seats kept in match/legacy/.
  `tools/autotest` gained `--ui`: the bots pick players by real mouse clicks
  on rows and pawns; the checker now also compiles tools/.
- **Why:** User's design: a clearer table, players as clickable things
  instead of a row of name buttons.
- **Rejected:** Keeping name buttons alongside (two ways to do one thing);
  closing open cards when a pick starts (you'd lose the card's text).
- **Verified:** check_project 67/67; 4 `--ui` runs (54 clicks, all
  registered) + normal runs pass. The click tests found two real blockers,
  both fixed: an open card popup ate the clicks, and the turn buttons
  covered pawns at the bottom location.

### C005 — Clearer match screen: disabled buttons, status line, card popup (2026-11-16)
- **What:** Attack / End Turn / Use Ability / Reveal grey out when the
  server would refuse them, with a tooltip saying why (nobody in reach, give
  your green card first, only on your turn…). A status line above the HUD
  always says what to do or who everyone is waiting on ("Waiting for Bob to
  answer your green card", "Waiting for Bob to decide…", "Bob's turn").
  New public message `MatchNet.waiting_for` (who is choosing, not what).
  Reach/attack-target rules moved to `data/rules.gd` (`Rules`), used by
  both server and UI so they can't disagree. Card popup: heading, card and
  buttons in one centred column, so buttons never cover long card text
  (checked on every card: lowest edge y=785, above the choice panel). The
  whole dice area rolls on your turn. Roll/End Turn labels bilingual.
  Removed the dead `_end_game` signal (game over now sets game_finished).
- **Why:** User feedback: unclear whose move it was, buttons that did
  nothing, card text hidden behind buttons, roll only clickable at its edge.
- **Rejected:** Client-only guesses for "who's deciding" (the client can't
  know without a message).
- **Note:** The roll-button "only the border works" report couldn't be
  reproduced headless (clicks land everywhere on it); making the whole dice
  area clickable is the likely intent. Ask the user if it persists.

### C004 — Network & state as a store; game manager split (2026-11-16)
- **What:** New autoloads `LobbyNet` and `MatchNet` hold every `@rpc`:
  actions (UI calls), requests (server checks the sender), messages (update
  `GameState`, emit `SignalBus`). UI files (lobby, game settings, avatar
  picker, play scene, dice, seats) have no network code left. Removed both
  `MultiplayerSynchronizer`s; role counts are now real messages, not copied
  label text. `GameState` is the client store only; server truth moved to
  `LobbyNet` (lobby) and `ServerState` (match: secret characters, decks).
  The 895-line `game_manager.gd` became `MatchServer` + `CardFlow` +
  `Combat` (+ `CardEffects`), created by MatchNet on the server only.
  Dice are thrown server-side. The choice system keeps an answer that arrives
  before the server starts waiting. Shared board rules in `data/board.gd`.
- **Why:** The user asked for state/network to work "like a Pinia store";
  the next goal (deployment, lobby service) needs server logic that doesn't
  live inside a UI scene. Fixes BUG-003. See D004.
- **Rejected:** Keeping RPCs on scene nodes (paths must match on every
  computer, and server logic would stay tied to the play screen); replicating
  state with MultiplayerSynchronizer (hard to keep secrets per player).
- **Verified:** check_project 63/63; run_autotest 8 full games + 3 mid-match leaves, all pass.

### C003 — Restructure by feature; dead code out; test tools (2026-11-16)
- **What:** Moved every scene and script into feature folders (autoload/,
  network/, server/, data/, main/, lobby/, match/{board,hud,cards,dice,legacy}),
  scenes next to their scripts; `GameState.gd` → `autoload/game_state.gd`.
  Loose sprites into assets/pawns, portraits, ui; old art into
  assets/legacy/{board,portraits}; source sheets and drafts into
  assets/_source (ignored by Godot). Deleted: side menu, empty waiting-lobby
  sprite, empty TileMapLayer/Control in main.tscn, the "Add Player" debug
  button, card.gd's unused texture table. Kept the old damage board in
  match/legacy/. Added tools/check_project (loads every file) and
  tools/autotest + run_autotest.sh (a host bot and a client bot play a match
  headless; found BUG-003 and BUG-004).
- **Why:** The repo was flat and cluttered; the next steps (network
  refactor, deployment) need a clear layout and a way to test without a person. See D003.
- **Rejected:** Separate scenes/ and scripts/ trees (one feature spread over
  two places); deleting the old damage board (user wants it kept).

### C002 — Adopted the project-workflow docs system (2026-11-16)
- **What:** Added MANIFEST, STATE, FOLDER_STRUCTURE, ARCHITECTURE, VISION,
  CHANGELOG, DECISIONS, BUGS, IDEAS under `docs/`, `.project-workflow/tuning.yml`,
  and a short root `CLAUDE.md` pointing to the manifest. RULES.md and CARDS.md stay as they are.
- **Why:** So any session can start cold and know where things stand, what's
  next, and what's been decided. See D001.
- **Rejected:** Backfilling history from git (the skill says logs start at adoption).

### C001 — Classic art toggle (2026-11-16)
- **What:** Main menu "Classic art" switch (saved in `user://settings.cfg`).
  When on: the original path-tile board (`scenes/classic_board.tscn`) with a
  FOREST.webp backdrop, chapel art on the locations, the original
  stick-figure pawns (recovered from git into `assets/legacy/pawns/`), the
  old card backs, and the original animated 38px portraits plus every old
  variant sheet (`assets/legacy/classic_portraits.tres`; click the HUD
  portrait to cycle). When off: the current art, unchanged.
- **Why:** The user wanted all their old art back in the game without losing the new art. See D002.
- **Rejected:** Replacing the current art outright (loses work); a live
  in-match toggle (too many places to refresh for little gain).
- **Not yet verified in Godot.**
