# Fork Changes vs Upstream

This fork tracks [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent. **Current upstream base: v5.1.0.**

This is the maintained delta — what this fork adds or changes relative to upstream. It is updated on every upstream sync (see [upstream-sync.md](upstream-sync.md)) and every fork release. Derived from `git diff --stat upstream/main...HEAD`.

## Rails convention enforcement

- **Eight Rails convention skills** (`skills/rails-*-conventions/`): model, controller, view, policy, job, migration, stimulus, testing. Each encodes project conventions (e.g. State as Records, Pundit policies, Turbo/Stimulus boundaries, RSpec patterns) that agents load before touching the corresponding file type.
- **`hooks/rails-conventions.sh`** + its `PreToolUse` entry in `hooks/hooks.json`: a deny-until-skill-loaded gate. Edits/writes to Rails files are blocked until the matching convention skill appears in the session transcript.
- **`skills/executing-plans/SKILL.md`**: for Rails projects, mandates loading all eight convention skills before the first task and adds a Rails-conventions check to each batch review.

## Rails-aware code review

- **`skills/subagent-driven-development/rails-reviewer-prompt.md`**: a dedicated Rails reviewer dispatched as a third review stage. The pipeline is spec compliance → Rails conventions (if Rails) → code quality, replacing upstream's two-stage review. `skills/subagent-driven-development/SKILL.md` wires the stage into the process flowchart; references to "two-stage review" in `README.md` and `skills/writing-skills/SKILL.md` are updated to match.
- **`commands/codereview.md`**: a `/codereview` slash command that runs the full three-stage pipeline on demand, outside the SDD loop.

## Planning philosophy: vertical slices, intent-level steps

- **`skills/writing-plans/SKILL.md`**: rewritten around vertical slices (37signals/Basecamp style). Every slice delivers a user-visible capability end-to-end; horizontal layer-by-layer plans are treated as a red flag. Steps are intent-level (WHAT to build, not full code); exact code is reserved for fragile operations like migrations. Includes a mandatory Rails section (load convention skills while planning) and a scope check.
- **`skills/subagent-driven-development/SKILL.md` + `implementer-prompt.md`**: model-selection guidance adjusted for intent-level plans — cheap models only for tasks with exact code in the plan or trivial gem calls; intent-level tasks need at least a standard model. The implementer runs `bin/ci` before handoff.

## Fork tests

- **`tests/claude-code/test-rails-reviewer.sh`**: behavioral smoke test asserting the Rails reviewer stage is dispatched in a Rails project.
- **`tests/claude-code/test-writing-plans-vertical-slices.sh`**: committed eval asserting writing-plans produces vertical slices, not horizontal layers.
- Both registered in `tests/claude-code/run-skill-tests.sh` (`--integration`).

## Fork identity and distribution (v5.1.2-rails)

- **Plugin renamed** `superpowers` → `superpowers-rails`; authored by Marcin Ostrowski; repo home `fryga-io/superpowers-rails`. The skill namespace follows the plugin name, so every `superpowers:<skill>` reference is rewritten to `superpowers-rails:<skill>` (~111 references across ~21 files in `skills/`, `commands/`, `hooks/`, `tests/`, `CLAUDE.md`, including the `hooks/session-start` bootstrap text).
- **Manifests renamed** across harnesses: `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.codex-plugin/plugin.json`, `gemini-extension.json`, `package.json` (OpenCode), `.opencode/INSTALL.md`. All carry the fork's `X.Y.Z-rails` version.
- **Marketplaces**: the in-repo dev marketplace (`.claude-plugin/marketplace.json`, name `superpowers-dev`) lists `superpowers-rails` plus a deprecated `superpowers` legacy entry pinned by `ref`+`sha` to the frozen `legacy` branch, so pre-rename installs keep working at 5.1.1-rails. Public installs come from the separate `fryga-io/claude-marketplace` repo (marketplace name `fryga`).
- **README**: fork preamble, attribution, fryga install instructions, migration note; `RELEASE-NOTES.md` carries `-rails` entries above upstream's changelog.

## Maintenance process

- **`docs/upstream-sync.md`**: the upstream sync process, conflict-resolution norms, and pre-merge validation gate (including the legacy-entry invariants).
- **`docs/fork-changes.md`**: this file.
- **`docs/superpowers/`**: design specs and implementation plans for fork work (internal records).

## What is NOT a fork change

- **`CLAUDE.md` / `AGENTS.md` contributor policy** (AI-agent guidelines, disclosure requirements, dev-branch targeting) is upstream content — the fork's only delta there is one namespace line.
- **`LICENSE`** is untouched: MIT, Jesse Vincent's copyright.
- **`scripts/sync-to-codex-plugin.sh`** is upstream's Codex mirror tooling, left as-is.
