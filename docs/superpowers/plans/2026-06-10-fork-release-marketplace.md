# Fork Release & Marketplace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Each slice below is one unit of work — implement them in order, one subagent per slice. Slices use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the fork as `superpowers-rails` v5.1.2-rails with its own identity, documented upstream delta, a GitHub release, and a public Fryga marketplace — without breaking installed copies.

**Architecture:** Four slices on the `fork-release-marketplace` branch: (1) the rename itself, proven by a local install under the new name; (2) the docs a visitor needs; (3) merge + tag + GitHub release; (4) the `fryga` marketplace repo. The in-repo dev marketplace keeps the name `superpowers-dev` so existing registrations keep matching.

**Spec:** docs/superpowers/specs/2026-06-10-fork-release-marketplace-design.md

**Constraint (from spec Risks):** never create a new repo named `marostr/superpowers` — existing registrations depend on GitHub's redirect from that old name to `superpowers-rails`.

---

### Slice 1: A user can install the plugin as `superpowers-rails` and it works end-to-end

- [ ] **Delivers:** Installing `superpowers-rails@superpowers-dev` from this checkout yields a fully working plugin under the new name — bootstrap injects, skills invoke under the `superpowers-rails:` namespace, the rails-conventions hook gates.
- [ ] **Touches:** `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `package.json`, `gemini-extension.json`, `hooks/session-start`, `hooks/rails-conventions.sh`, `AGENTS.md`, and every file in `skills/`, `commands/`, `tests/` containing `superpowers:<skill>` references (~111 refs across ~21 files).
- [ ] **End-to-end test (write first, watch it fail, then build the slice to green):**
  Verification script (red first: it fails against current state because the plugin is still named `superpowers`):
  1. `jq -r .name .claude-plugin/plugin.json` == `superpowers-rails` and `.version` == `5.1.2-rails`; marketplace.json name stays `superpowers-dev`, its plugin entry is `superpowers-rails`.
  2. `grep -rn "superpowers:[a-z-]" skills/ commands/ hooks/ tests/ AGENTS.md GEMINI.md` returns nothing (allowed exceptions: none in these paths — prose mentions of upstream live only in README/docs).
  3. Live check on this machine: remove the GitHub-backed `superpowers-dev` registration, `claude plugin marketplace add /Users/marcinostrowski/own/superpowers-rails`, `claude plugin install superpowers-rails@superpowers-dev`; in a fresh `claude` session confirm the session-start bootstrap mentions `superpowers-rails:using-superpowers`, invoke one skill via the Skill tool under the new namespace, and confirm `hooks/rails-conventions.sh` still resolves skill names (its `skill_loaded` checks use the new namespace).
- [ ] **Notes:**
  - plugin.json: author Marcin Ostrowski, homepage/repository `https://github.com/marostr/superpowers-rails`, description noting the Rails-focused fork. Same identity updates in the marketplace.json plugin entry (owner: Marcin).
  - Namespace rewrite is mechanical (`superpowers:` → `superpowers-rails:` in skill-reference position) but review the diff — don't touch prose like "You have superpowers." or upstream URLs.
  - The two fork behavioral tests (`tests/claude-code/test-rails-reviewer.sh`, `tests/claude-code/test-writing-plans-vertical-slices.sh`) must pass after the rewrite; they exercise renamed namespaces.
  - While the old install is still present, observe and record what Claude Code does with `superpowers@superpowers-dev` once the marketplace no longer lists it (silent-stale vs. warning) — Slice 2's migration note must describe observed behavior.

### Slice 2: A visitor can understand the fork and follow correct install/migration instructions

- [ ] **Delivers:** README presents the fork honestly (what it is, attribution to Jesse Vincent, what's different), gives working install commands for the `fryga` marketplace, and a migration note for existing users; `docs/fork-changes.md` documents the upstream delta; RELEASE-NOTES gains the v5.1.2-rails entry.
- [ ] **Touches:** `README.md`, `docs/fork-changes.md` (new), `RELEASE-NOTES.md`, `docs/upstream-sync.md`.
- [ ] **End-to-end test (write first, watch it fail, then build the slice to green):**
  Verification (red first against current docs):
  1. README contains the fork preamble, a link to `docs/fork-changes.md` that resolves, install commands exactly `/plugin marketplace add fryga-io/claude-marketplace` + `/plugin install superpowers-rails@fryga`, and the 3-command migration block from the spec.
  2. `grep -n "obra/superpowers-marketplace\|superpowers@claude-plugins-official" README.md` returns nothing.
  3. Every fork change listed in `docs/fork-changes.md` corresponds to a file in `git diff --stat upstream/main...HEAD`, and nothing material in that diff is missing from the doc.
  4. `docs/upstream-sync.md` checklist includes "update docs/fork-changes.md" and a namespace re-application step (`superpowers:` → `superpowers-rails:` on newly merged upstream content).
- [ ] **Notes:**
  - README scope is the spec's: preamble + targeted edits, not a rewrite. Sponsorship section stays, reframed to credit and sponsor Jesse. Other-harness install sections: re-point repo URLs to this fork where the mechanism plainly works; add "untested on this fork" where unverifiable.
  - Migration note must reflect the behavior observed in Slice 1, not theory.
  - RELEASE-NOTES entry covers: rename + why, new marketplace, migration commands, versioning note (upstream-tracking scheme, hence a patch-numbered release carrying a big change).

### Slice 3: A user can get v5.1.2-rails as a published GitHub release

- [ ] **Delivers:** The branch is merged to `main`, tagged `v5.1.2-rails`, and a GitHub release exists with release notes and migration commands; the GitHub-backed `superpowers-dev` marketplace now serves `superpowers-rails`.
- [ ] **Touches:** PR to `marostr/superpowers-rails` (always `--repo marostr/superpowers-rails`), `main`, tag `v5.1.2-rails`, GitHub release.
- [ ] **End-to-end test (write first, watch it fail, then build the slice to green):**
  Verification (red first: tag and release don't exist):
  1. `gh release view v5.1.2-rails --repo marostr/superpowers-rails` succeeds and the body contains the migration commands.
  2. On this machine: remove the local-path marketplace registration, re-add `marostr/superpowers-rails` as a marketplace, and `claude plugin install superpowers-rails@superpowers-dev` succeeds from GitHub — restoring the normal (non-checkout) setup.
- [ ] **Notes:** Marcin reviews and merges the PR (his repo, his call — this is the gate where he sees the complete diff). Tag from `main` after merge. Release body: the RELEASE-NOTES v5.1.2-rails entry.

### Slice 4: A new user can install from the public `fryga` marketplace

- [ ] **Delivers:** `fryga-io/claude-marketplace` has content; `/plugin marketplace add fryga-io/claude-marketplace` + `/plugin install superpowers-rails@fryga` works on a machine that has never seen `superpowers-dev`.
- [ ] **Touches:** repo `fryga-io/claude-marketplace` (already created by Marcin, currently empty) — `.claude-plugin/marketplace.json`, `README.md`.
- [ ] **End-to-end test (write first, watch it fail, then build the slice to green):**
  Verification (red first: marketplace add fails because the repo is empty):
  1. `claude plugin marketplace add fryga-io/claude-marketplace` registers a marketplace named `fryga`.
  2. `claude plugin install superpowers-rails@fryga` installs; fresh session bootstrap works. (Run alongside the existing `superpowers-dev` registration to confirm the two coexist; uninstall the duplicate after the check, keeping whichever Marcin prefers.)
- [ ] **Notes:** Marketplace JSON is config — exact content:
  ```json
  {
    "name": "fryga",
    "description": "Fryga's Claude Code plugins",
    "owner": {
      "name": "Marcin Ostrowski",
      "email": "marcin@fryga.io"
    },
    "plugins": [
      {
        "name": "superpowers-rails",
        "description": "Rails-focused fork of Superpowers: core skills plus Rails conventions, rails-reviewer, and vertical-slice planning",
        "source": {
          "source": "github",
          "repo": "marostr/superpowers-rails"
        }
      }
    ]
  }
  ```
  README: what the marketplace is, the two install commands, link to the plugin repo. The repo already exists (Marcin created it, empty) — clone/init locally and push to its default branch.
