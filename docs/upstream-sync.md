# Upstream Sync & Pre-Merge Validation

This fork (`marostr/superpowers-rails`) tracks `obra/superpowers` and layers
Rails-specific customizations on top. **`main` is the released branch** — fork
users install via `/plugin marketplace add marostr/superpowers-rails` and pull
the default branch on update, so anything merged to `main` ships to them
immediately. There is no release-tag pinning and no CI gate.

Because of that, **every change reaches `main` through a merge branch that
passes the validation gate below before its PR is merged.** Do not push
unvalidated skill/behavior changes straight to `main`.

## Sync process

1. Fetch and inspect upstream:
   ```bash
   git fetch upstream --tags
   git log --oneline --no-merges main..upstream/main
   git diff --stat main..upstream/main
   ```
2. Branch from `main`: `git checkout -b merge-upstream-main-vX.Y.Z main`
3. `git merge upstream/main --no-commit --no-ff` and resolve conflicts (see
   norms below).
4. Run the **validation gate**.
5. Open a PR into the fork's `main` with `--repo marostr/superpowers-rails`
   (gh defaults to upstream on forks — always pass `--repo`). Show Marcin the
   complete diff first.

## Conflict-resolution norms

- **Versioning.** Only `.claude-plugin/plugin.json` and
  `.claude-plugin/marketplace.json` carry the `-rails` suffix. `package.json`,
  `.cursor-plugin/plugin.json`, `.codex-plugin/plugin.json`, and
  `gemini-extension.json` track the plain upstream version. Pick the next free
  `X.Y.Z-rails` — note the fork once shipped its own `5.1.0-rails` ahead of
  upstream, so a collision is possible (we used `5.1.1-rails` for the upstream
  v5.1.0 sync).
- **RELEASE-NOTES.md.** Add a `X.Y.Z-rails` sync entry at the top; keep all
  `-rails` entries grouped above the upstream changelog block.
- **Preserve all Rails customizations.** After resolving, confirm these still
  exist and are wired:
  - `skills/rails-*-conventions/` (8 convention skills)
  - `hooks/rails-conventions.sh` + its entry in `hooks/hooks.json`
  - `skills/subagent-driven-development/rails-reviewer-prompt.md`
  - `commands/codereview.md`
  - the `hotwire-conventions` skill
- **Adapt to upstream removals.** When upstream deletes something a fork file
  references (e.g. v5.1.0 removed the named `code-reviewer` agent), update the
  fork reference to the new pattern rather than restoring the deleted file
  unless Marcin decides otherwise.

## Validation gate (run before the PR to `main`)

Requires the `claude` CLI on PATH. Tests run real headless sessions and use
`--plugin-dir` so they exercise *this working tree*, not the installed plugin.
See `docs/testing.md` for mechanics.

1. **Confirm Rails customizations survived the merge** (files present + wired):
   the list under "Conflict-resolution norms" above.

2. **Run the skill test suite:**
   ```bash
   cd tests/claude-code
   ./run-skill-tests.sh                 # fast
   ./run-skill-tests.sh --integration   # full (10-30 min)
   ```
   - `test-requesting-code-review.sh` — validates the code-review consolidation
   - `test-rails-reviewer.sh` — validates the Rails reviewer dispatch (our
     customization; the one with no upstream coverage)
   - `test-subagent-driven-development-integration.sh` — full SDD loop

3. **Manual eval in a real Rails context.** Automated Rails coverage is thin
   (only `test-rails-reviewer.sh`). For any sync that touches review, worktree,
   planning, or SDD skills, run a quick `claude -p` scenario against an actual
   Rails repo and sanity-check the behavior. Use judgment about scope.

### Known pre-existing test failures (not merge regressions, not blockers)

Two SDD tests fail independently of any upstream sync. Both were verified
against pre-merge `main` (run the same test from a `git worktree add` of the
old commit) — old `main` fails them identically, so they are not introduced by
a merge and not a behavioral defect in the merged code.

1. **`test-subagent-driven-development.sh` Test 2 ("Workflow ordering").**
   Asserts on the *word order of a free-text answer* ("what comes first, spec
   compliance or code quality?"). The fork's Rails-review insertion plus a
   rationalization row mentioning "Code quality" make the model say "code
   quality" early in its prose, so the grep-based ordering check fails. The
   skill content is correct: spec compliance → Rails conventions → code quality.

2. **`test-subagent-driven-development-integration.sh` Test 3 ("Task
   tracking").** Greps the transcript for a `TodoWrite` tool call. The model
   *narrates* "extracted tasks into TodoWrite" but often doesn't emit the actual
   tool call on a trivial 2-task plan. Confirmed: pre-merge `main` also emits 0
   `TodoWrite` calls. (Initially suspected upstream's new "Continuous execution
   … progress summaries waste their time" directive — ruled out by the control
   run.)

Everything these integration tests assert about *correctness* (full review
loop, spec compliance, working implementation, commits) passes on the merged
branch. Fixing the two brittle assertions is tracked separately from syncs.
