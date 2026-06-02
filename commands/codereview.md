---
description: "Run three-stage code review: spec compliance, Rails conventions (if Rails), code quality"
---

# Three-Stage Code Review

Run the full review pipeline on recent changes.

## Step 1: Gather Context

Determine what to review:
- If user specified files/commits: use those
- Otherwise: review changes since last review or last commit

Get git SHAs:
```bash
git log --oneline -5  # Find BASE_SHA and HEAD_SHA
git diff --name-only BASE_SHA HEAD_SHA  # Files changed
```

## Step 2: Spec Compliance Review

Dispatch spec reviewer using prompt template from `skills/subagent-driven-development/spec-reviewer-prompt.md`:

```
Task tool (general-purpose):
  description: "Review spec compliance"
  prompt: [Use template, fill in requirements and changes]
```

**If issues found:** Report and stop. User must fix before continuing.

## Step 3: Rails Conventions Review (Rails projects only)

Check if Rails project (look for Gemfile with rails, app/controllers, etc.)

If Rails, dispatch rails reviewer using the template at `skills/subagent-driven-development/rails-reviewer-prompt.md`:

```
Task tool (general-purpose):
  Use template at skills/subagent-driven-development/rails-reviewer-prompt.md
  FILES_CHANGED: [list]
  BASE_SHA: [sha]
  HEAD_SHA: [sha]
```

**If violations found:** Report and stop. User must fix before continuing.

## Step 4: Code Quality Review

Dispatch code quality reviewer using the template at `skills/requesting-code-review/code-reviewer.md`:

```
Task tool (general-purpose):
  Fill template at skills/requesting-code-review/code-reviewer.md
  FILES_CHANGED: [list]
  BASE_SHA: [sha]
  HEAD_SHA: [sha]
```

## Step 5: Run Local CI (if available)

If `bin/ci` exists, run it. Can run in parallel with review agents. If it fails, stop and report.

## Step 6: Report

Summarize all review results:
- ✅ Spec compliance: [passed/issues]
- ✅ Rails conventions: [passed/skipped/issues]
- ✅ Code quality: [passed/issues]
- ✅ Local CI: [passed/skipped/failed]

If all passed: "Ready for merge/PR"
If any failed: List issues with file:line references
