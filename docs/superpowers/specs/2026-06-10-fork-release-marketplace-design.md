# Fork Release & Marketplace Design

**Date:** 2026-06-10
**Status:** Approved by Marcin

## Context

This repo (`fryga-io/superpowers-rails`) is a fork of `obra/superpowers` carrying Rails
conventions and planning-philosophy changes, but it still presents as upstream: the
plugin is named `superpowers`, plugin.json credits Jesse Vincent and links to
`obra/superpowers`, and the README is upstream's verbatim — including install
instructions for obra's marketplaces.

Current distribution: users (assumed public — exact audience unknown) run
`/plugin marketplace add marostr/superpowers` (old repo name; GitHub redirects),
which registers the in-repo marketplace named `superpowers-dev` and installs the
plugin as `superpowers@superpowers-dev`. Latest pushed tag is `v5.1.0-rails`;
manifests say `5.1.1-rails` but it was never tagged.

Goal: a proper fork release — own identity, documented delta vs upstream, a real
public marketplace — without breaking installed copies.

## Decisions

| Decision | Choice |
|---|---|
| Audience | Assume unknown public users; installed copies must keep working |
| Plugin name | Rename to `superpowers-rails` (Marcin's call; cost of namespace rewrite and upstream-merge friction accepted) |
| Distribution | Separate company marketplace repo `fryga-io/claude-marketplace`, marketplace name `fryga`; no official Anthropic marketplace submission |
| Versioning | Keep upstream-tracking `X.Y.Z-rails`; this release is `5.1.2-rails` |
| README | Fork preamble + targeted edits, not a rewrite |
| Migration | Legacy safety net (revised 2026-06-10 after live testing): a deprecated `superpowers` entry pinned to the frozen `legacy` branch keeps old installs working indefinitely; migration is optional via two commands |
| In-repo dev marketplace | Keep the name `superpowers-dev` so existing registrations keep matching |
| Repo home | Transferred to `fryga-io/superpowers-rails` (2026-06-10), alongside the marketplace |

## Design

### 1. Plugin identity & rename

`.claude-plugin/plugin.json`:
- `name`: `superpowers-rails`
- `version`: `5.1.2-rails`
- `author`: Marcin Ostrowski
- `homepage` / `repository`: `https://github.com/fryga-io/superpowers-rails`
- `description`: notes this is a Rails-focused fork of Superpowers

Namespace rewrite — the plugin name is the skill namespace, so every
`superpowers:<skill>` reference becomes `superpowers-rails:<skill>`:
- ~111 references across ~21 files in `skills/`, `commands/`, `tests/`,
  `hooks/rails-conventions.sh`
- the bootstrap text in `hooks/session-start`
  (`'superpowers:using-superpowers' skill`)
- one reference in `AGENTS.md`

Prose voice is untouched ("You have superpowers." stays); only namespace strings
change. `package.json` and `gemini-extension.json` `name` fields become
`superpowers-rails` (OpenCode / Gemini harnesses). `scripts/sync-to-codex-plugin.sh`
is upstream's tooling for their Codex mirror — left untouched.

Version note: the upstream-tracking scheme reserves major.minor for the upstream
base (5.1.0), so this significant release still ships as a patch bump. Release
notes carry the weight of communicating the rename.

### 2. Marketplaces

**New repo `fryga-io/claude-marketplace`** — Fryga's company marketplace, able to
host future Fryga plugins alongside this one:
- `.claude-plugin/marketplace.json`: name `fryga`, owner Fryga (Marcin), one
  plugin entry `superpowers-rails` sourced from
  `{"source": "github", "repo": "fryga-io/superpowers-rails"}`
- Short README with install instructions

Canonical install for new users:

```
/plugin marketplace add fryga-io/claude-marketplace
/plugin install superpowers-rails@fryga
```

**In-repo `.claude-plugin/marketplace.json`** keeps the name `superpowers-dev`
(the key existing registrations are bound to). Its plugin entry is renamed to
`superpowers-rails`, version updated, owner becomes Marcin. It remains the dev
marketplace for installing from a checkout.

**Migration for existing users** (using the marketplace they already have):

```
/plugin marketplace update superpowers-dev
/plugin uninstall superpowers@superpowers-dev
/plugin install superpowers-rails@superpowers-dev
```

(The first command only forces a refresh; marketplaces also auto-update, but the
note must not depend on timing.)

**Legacy safety net (added after live verification, 2026-06-10):** isolated
testing showed the original "clean break" assumption was wrong — an installed
plugin whose marketplace entry disappears goes to `✘ failed to load` on the next
auto-refresh and its skills vanish from sessions entirely. Therefore the in-repo
marketplace keeps a second, deprecated entry named `superpowers`, pinned to the
frozen `legacy` branch (pre-rename snapshot at `51339a3`, pinned by both `ref`
and `sha`). Existing installs resolve by name and keep working indefinitely at
5.1.1-rails; testing also confirmed an already-broken install heals itself once
the old name reappears. The `legacy` branch must never be deleted.

Serving *renamed* content under the old name remains impossible (the skill
namespace derives from the installed plugin name, and all internal
cross-references say `superpowers-rails:<skill>`), which is why the legacy entry
pins frozen pre-rename content instead.

### 3. Docs & attribution

- **README**: fork preamble at the top — what the fork is (Rails convention
  skills + planning-philosophy changes), explicit attribution to Jesse Vincent's
  Superpowers with a link, pointer to `docs/fork-changes.md`, and the migration
  note. Claude Code install section rewritten for the new marketplace; obra
  official-marketplace instructions removed. Other-harness install sections:
  repo URLs re-pointed to this fork where the mechanism plainly works, marked
  "untested on this fork" where it can't be verified. Sponsorship section stays
  but reframed: this fork is built on Jesse Vincent's Superpowers — sponsor his
  work.
- **`docs/fork-changes.md`**: the maintained delta vs upstream — 8 Rails
  convention skills, rails-reviewer subagent + `/codereview` command,
  rails-conventions hook, writing-plans vertical-slices rewrite,
  executing-plans / subagent-driven-development changes, contributor policy
  additions, fork tests. Updating this doc is added to the upstream-sync
  checklist in `docs/upstream-sync.md`.
- **RELEASE-NOTES.md**: new `v5.1.2-rails` entry covering the rename, the new
  marketplace, and migration instructions.
- **LICENSE**: untouched — MIT with Jesse's copyright stands. Fork authorship
  lives in plugin.json and the README.

### 4. Release mechanics & validation

Work happens on a branch → PR to `fryga-io/superpowers-rails` (always pass
`--repo fryga-io/superpowers-rails` to `gh`).

Validation before tagging:
1. Grep proves zero stale `superpowers:` namespace references remain (outside
   intentional mentions, e.g. fork-changes prose referring to upstream).
2. Local end-to-end on Marcin's machine: `/plugin marketplace update
   superpowers-dev`, install `superpowers-rails@superpowers-dev`, fresh session →
   bootstrap injects, a skill invokes under the new namespace, the
   rails-conventions hook still gates.
3. Observe what actually happens to the old `superpowers@superpowers-dev`
   install after the marketplace update (silent-but-stale vs. warning) and write
   the migration note to match observed reality.
4. Run the fork-relevant tests (`tests/claude-code/test-rails-reviewer.sh`,
   `tests/claude-code/test-writing-plans-vertical-slices.sh` at minimum).

Then:
- Tag `v5.1.2-rails`; GitHub release with release notes + migration commands.
- Create and push `fryga-io/claude-marketplace`; final fresh-install check from
  the new marketplace.

## Out of scope

- Official Anthropic marketplace submission (explicitly declined).
- Serving renamed content under the old plugin name — unworkable (namespace
  mismatch). The frozen-legacy-branch entry (see Marketplaces) is the supported
  compatibility mechanism.
- Rewriting `scripts/sync-to-codex-plugin.sh` or upstream's Codex mirror flow.
- README rewrite beyond the preamble and targeted install/attribution edits.

## Risks

- **Upstream-merge friction**: every future sync will conflict on the ~111
  namespace lines. Mitigation: document a re-application step (mechanical
  search/replace) in `docs/upstream-sync.md`.
- **Unknown Claude Code behavior** when an installed plugin disappears from its
  marketplace. Mitigation: validation step 3 observes the real behavior before
  the migration note is finalized.
- **Old repo-name redirects**: the repo was renamed (`marostr/superpowers` →
  `marostr/superpowers-rails`) and then transferred to `fryga-io/superpowers-rails`
  (2026-06-10; transfer verified non-breaking — both old URLs and the existing
  `superpowers-dev` registration still resolve). Existing registrations rely on
  this redirect chain. Creating a *new* repo named `marostr/superpowers` or
  `marostr/superpowers-rails` would silently break them — don't, ever.
