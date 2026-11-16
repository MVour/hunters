# Manifest

The index for this project's docs: what each doc is, when to read it, when to
update it, plus the locked constraints. Update this file in the same edit as
any doc being created, renamed, moved or archived.

## Documentation system — core rules

(Core rules synced from the project-workflow skill, 2026-11-16. This is a condensed,
always-read copy for daily use — the skill itself is the full spec and owns Setup Modes, the
experimental Feature-Scoped Docs mode, the worked example, and error-mode handling. Re-run this
skill's setup step to re-sync this block if the skill's rules change.)

### Session start (do this first, every session)
1. Read `.project-workflow/tuning.yml` if present — it overrides any defaults below.
2. Read `docs/STATE.md` in full.
3. Read the latest entry only of each Log doc relevant to today's task (CHANGELOG.md,
   DECISIONS.md, BUGS.md, IDEAS.md — whichever apply).
4. Read this manifest's constraints below, and the key-file table in docs/FOLDER_STRUCTURE.md.
5. Staleness check: any BUGS.md entry stuck non-terminal past ~2 weeks? Flag it once. Any
   IDEAS.md entry under an ad-hoc heading? Fold it into house style next time you're in that file.
6. Do not read docs/archive/ or temp_docs/ — these are on-demand only, never session-start.

### Doc types — how to treat each one

| File | Type | Rule |
|---|---|---|
| docs/VISION.md | Charter | Written once. Touch only on a real change in what the project is for. Read when a scope call is unclear. |
| docs/STATE.md | Snapshot | Rewrite in place, never append. Update at the same time as any change that earns a CHANGELOG.md entry. |
| docs/CHANGELOG.md | Log | Sequential IDs (C001, ...), never reused/renumbered. One entry per non-trivial change: what changed, why, what was rejected. |
| docs/DECISIONS.md | Log | Append only. Sequential IDs (D001, ...), never reused/renumbered. Every entry requires a Rejected field (alternative + why not). Conflict with an existing entry → stop and confirm before superseding. |
| docs/BUGS.md | Status log | Sequential IDs (BUG-001, ...). Log area, root-cause hypothesis, impact. Update status field when addressed — distinguish fix implemented from fix verified. |
| docs/IDEAS.md | Backlog | Reference pool, not a queue — implementing an entry only happens if the user asks. Remove on implementation + add a Log entry. |
| docs/ARCHITECTURE.md | Living reference | Edit in place, same session as the invalidating change. No history kept — risk is drift, not bloat. |
| docs/RULES.md, docs/CARDS.md | Living reference (game design spec) | Edit in place, same session as a rules/card change in code (`data/cards.gd`, `data/characters.gd`, `server/*.gd`). |
| docs/FOLDER_STRUCTURE.md | Folder map | Update only when a folder's purpose changes, a top-level folder is added/removed, or a key-file-roles-table file moves/renames/is removed. Not on every file rename. |

### Approval gates — stop and ask before proceeding when:
1. A change would violate a non-negotiable constraint (see list below) — always a gate, not a judgment call.
2. A new idea/choice contradicts an existing DECISIONS.md entry — hard stop, no exceptions. Do not write it to IDEAS.md or DECISIONS.md in any form yet. Name the conflicting decision's ID, state the contradiction plainly, and wait for the user's explicit call:
   - Old decision stands → don't add the new item (or log it in IDEAS.md as rejected, citing the decision ID, only if the user wants it kept for history).
   - New direction approved → supersede the old entry, add the new one as a fresh DECISIONS.md ID — never edit the old entry's text.
   - Approved but not committed yet → add to IDEAS.md only, explicitly flagged as conflicting. ("Contradicts" = genuinely incompatible with the decision's substance, not just adjacent to its topic.)
3. The choice is genuinely ambiguous, with no existing decision or constraint covering it, and reasonable engineers could land differently.

Everything else — routine implementation detail that doesn't touch a constraint, doesn't contradict a decision, isn't genuinely ambiguous — doesn't need a gate. Make the call, log it, move on.

### Before ending a task or session
0. Code changed? Run `tools/check_project.tscn` and `tools/run_autotest.sh` headless (see ARCHITECTURE.md → Testing).
1. Does STATE.md still match reality? Rewrite if this session's work made it stale.
2. Any BUGS.md entry touched this session — is its status field actually updated?
3. Any IDEAS.md entry implemented — removed, with a Log entry added?
4. Any key-file-roles-table file moved/renamed this session — is FOLDER_STRUCTURE.md updated?
5. Rules or cards changed in code — are RULES.md / CARDS.md still true?

### Non-negotiable constraints
1. **Server-authoritative, store pattern.** The server decides everything. All `@rpc` code lives
   in `LobbyNet` / `MatchNet`; UI calls their actions and listens to `SignalBus`, never RPCs
   directly, never writes `GameState`. Server truth stays in `LobbyNet`'s server fields and
   `ServerState`, never in `GameState`. Hidden info (other players' characters) is never sent to a
   client that shouldn't see it — the host's screen included.
2. **Transport stays swappable.** Game code never touches ENet directly — only the `Network`
   autoload and a `NetworkTransport` (today `EnetTransport`). A lobby/matchmaking service
   should be able to replace it later.
3. **The user's own game.** Genre-similar to a famous hidden-role board game, but every
   character, card, location and piece of art is the user's own. Never recreate that game's
   specific content.
4. **The user's own art.** Characters and card art come from the user's images (or light
   remasters of them). No code-drawn replacements. Archive originals in `assets/legacy/`
   before replacing anything, and keep old art usable (see the Classic art toggle).
5. **Bilingual.** Every player-facing text is in English and Greek (EL).

### Key-file roles
Kept in docs/FOLDER_STRUCTURE.md (one place only).

### Read/update table

| Doc | Read when | Update when |
|---|---|---|
| docs/STATE.md | Every session | Same time as any CHANGELOG.md-worthy change |
| docs/CHANGELOG.md | Latest entry, every session | Any non-trivial change |
| docs/DECISIONS.md | Latest entry, every session | Any architectural/design choice |
| docs/BUGS.md | Latest entry + staleness check | Bug found/status changed |
| docs/IDEAS.md | If task touches backlog / "what's next" | New idea, or one implemented |
| docs/VISION.md | When a scope call is unclear | Real pivot only |
| docs/ARCHITECTURE.md | Task touches networking, turn flow, or scene structure | Those change |
| docs/RULES.md | Task touches game rules | Rules change in code |
| docs/CARDS.md | Task touches cards | A card is added/changed/removed |
| docs/FOLDER_STRUCTURE.md | If task touches unfamiliar code | Folder purpose changes, or a key-file-roles-table file moves/renames |
