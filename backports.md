# Backport Analysis: 1.2.3-rc1 vs master

**Reviewed:** 2026-04-13  
**Range considered:** `1.2.3-rc1` (`63051bf4`) through `master` (`46a8a039`)

The following commits are present in `master` but absent from `1.2.3-rc1` / `origin/1_2_stable`. They were assessed for whether they should be backported before running `1.2.3-rc1` in production.

---

## Must Backport

### `6ed0cee3` — Show duplicate report creators to staff only

**Priority: High (privacy)**

Duplicate report creator usernames were visible to any logged-in user rather than staff only. One-line fix in `duplicate_report/_list.html.slime` gating the username link behind `can?(@conn, :edit, report)`.

### `aa04455f` — Fix comments querying for moderators

**Priority: High (broken functionality)**

`Map.merge` in `comments/query.ex` was overwriting the base query aliases instead of extending them, causing moderator comment searches to lose filters like `author:`, `body:`, etc. Fix replaces the merge with a direct map containing only the moderator-specific extra aliases.

### `999b55c6` — Fix uploads_count on user indexing

**Priority: High (broken functionality)**

The DB field was renamed from `uploads_count` to `images_count` but the search index (`users/search_index.ex`) and admin UI template were never updated. The admin "Sort by uploads" option and `uploads_count.gte:N` search query are silently broken without this fix.

### `dc1eacc4` — Update reports `updated_at` in close_report_query

**Priority: Low (correctness)**

When reports are bulk-closed (e.g. on image deletion), `updated_at` was not being set, leaving the timestamp stale. Fix adds `updated_at: ^now` to the update query in `reports.ex`.

---

## Nice to Have

### `64b69ec5` — Force rule selection on reports

UX improvement: adds `required: true` and a disabled placeholder prompt to the rule dropdown on the report form so users cannot submit without selecting a rule.

### `8020ce0d` — Improve image size change (partscaled layout reservation)

CSS/JS improvement: sets `height: auto` on `.image-partscaled` and pre-populates `width`/`height` attributes on full-size images before they load to prevent layout shift. Also replaces `innerHTML` string construction with safe DOM element creation.

---

## Not Backported

- **CI/infra changes**: devcontainer v2, slim CI runners, optional pre-commit hooks, coverage gap fixes — no production impact.
- **Large package update** (`a82ee425`, 2026-04-04): bumps Elixir, Rust, and many npm/hex/cargo dependencies. No specific CVE fixes identified; would require rebuilding the `1.2.x` branch against newer base images.
- **New features**: user indexing (`#539`), image expansion improvements beyond `8020ce0d` — not appropriate for a stable backport.
