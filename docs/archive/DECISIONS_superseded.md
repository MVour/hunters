# Superseded decisions

Full text of decisions that were replaced, moved here verbatim (status line
updated). Read-only; the live log keeps a one-line stub per ID.

---

### D005 — One language at a time, with a switch (2026-11-16)
- **Status:** superseded by D006 (2026-11-16)
- **What:** Texts exist in English and Greek, but the screen shows only the
  chosen one. `Global.lang` (saved), button bottom-left on every screen.
  Client code uses `Global.t("en", "el")` and `Global.field(data, key)`;
  the few bilingual texts the server sends are written `"en  ·  el"` and
  split by `Global.pick()`.
- **Why:** User request: both side by side was too busy.
- **Rejected:** Godot's translation files (.po/CSV) — heavier for two
  languages and texts that live in GDScript data; keeping both visible.

