#!/usr/bin/env bash
# Integration Test: writing-plans produces vertical slices, not horizontal layers
#
# Regression guard for the 37signals/Basecamp rewrite of writing-plans. Given a
# Rails feature spec, the skill must produce a plan decomposed into vertical
# slices (each a user-facing capability cut through all layers, shippable and
# end-to-end testable on its own) — NOT horizontal layers (all migrations -> all
# models -> all controllers -> all views -> write the tests) — and the plan must
# stay intent-level, not per-step TDD ceremony.
#
# A future upstream merge or "small tweak" that quietly reverts the skill to
# layer-batching / step ceremony will fail this test.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "========================================"
echo " Integration Test: writing-plans (vertical slices)"
echo "========================================"
echo ""
echo "This test:"
echo "  1. Gives the writing-plans skill a Rails feature spec"
echo "  2. Has it produce an implementation plan"
echo "  3. Blind-grades the plan (vertical-slice axis + intent-level detail)"
echo "  4. Asserts the plan is vertical + thin, not horizontal + ceremony"
echo ""

WORK=$(mktemp -d)
trap "rm -rf $WORK" EXIT

# --- Fixture: a Rails feature spec that is equally temptable toward horizontal
# layering or vertical slicing. ---
cat > "$WORK/spec.md" <<'SPEC'
# Team Reading List — Design Spec

**Goal:** Let members of a team share and triage a list of links they want the team to read.

**Context:** Existing Rails 7 app. Has `User`, `Team`, `Membership` (user belongs to many teams), Devise (`current_user`), Pundit, Hotwire (Turbo + Stimulus), RSpec + Capybara + FactoryBot. ViewComponents in use; `app/helpers` prohibited. No JSON API — Turbo only.

## Requirements
- A team member can view their team's reading list at `/teams/:team_id/reading_list`, newest first, showing title, the URL's host, who added it, and when. Only members may view (Pundit). Friendly empty state.
- A team member can add a link with a URL (required, http/https) and a title (required, max 200 chars). It associates with the team and adding user. On success it appears at the top without a full reload (Turbo Stream). Validation errors render inline.
- Each member can mark a link read/unread for themselves (per-user, not global). Read links look distinct for that user. Toggling updates in place without a full reload. Read state is a record (a per-user marker), not a boolean on the link.

## Out of scope (YAGNI)
Editing/deleting links, comments, tags, search, pagination, notifications.

## Data model
- `Link`: `team_id`, `user_id` (adder), `url`, `title`, timestamps. Validations: url presence + http(s) format; title presence + length<=200.
- `LinkRead`: `link_id`, `user_id`, timestamps. Read iff a `LinkRead` exists. Unique on `[link_id, user_id]`.

## Success criteria
A team member can load the page, add a link, see it appear at the top, and toggle its read state — all without full reloads — and non-members are forbidden.
SPEC

# --- Rubric (kept in sync with the eval that drove the rewrite). ---
cat > "$WORK/rubric.md" <<'RUBRIC'
# Grading Rubric — "Vertical-Slice Plan"

Score ONE Rails implementation plan written from spec.md. Be strict; cite task titles.

## D1 — Decomposition axis
Classify the top-level tasks:
- VERTICAL — each task is a user-facing capability cutting through all needed layers (migration+model+controller+view+test) for ONE slice (e.g. "View the reading list", "Add a link", "Mark a link read/unread").
- HORIZONTAL — tasks are layers spanning the whole feature ("Create migrations", "Create models", "Create controllers", "Create views", "Write tests").
- MIXED — some of each.
Sub-checks (yes/no):
- Shippable-on-its-own: could each task merge independently and leave the app working?
- E2E-testable-on-its-own: does each task carry a system/request test exercising its whole path (NOT deferred to a final "write the tests" task)?
- No layer-batching: is there NO task that batches one layer across the feature?
D1_VERDICT PASS only if VERTICAL and all three sub-checks yes.

## D2 — Detail level
- THIN — tasks state intent (what + where + the e2e behavior to verify), trusting a skilled executor for HOW.
- OVER-DETAILED — tasks script per-step ceremony (write failing test -> run to confirm fail with expected message -> implement -> run to confirm pass -> commit), exact commands for routine ops, restated spec prose.
Sub-checks (yes/no):
- No per-step TDD ceremony.
- No spec re-statement / HOW-scripting (conventions referenced by name; exact code only for migrations/destructive/non-obvious config). NOTE: a plan being longer than a terse spec is NOT a failure on its own — decomposition, per-slice file lists, and e2e scenarios are legitimate. Judge intent vs ceremony, not raw length.
D2_VERDICT PASS only if THIN and both sub-checks yes.

## Output EXACTLY this block:
D1_AXIS: VERTICAL|HORIZONTAL|MIXED
D1_VERDICT: PASS|FAIL — <why, cite task titles>
D2_DETAIL: THIN|OVER-DETAILED
D2_VERDICT: PASS|FAIL — <why>
OVERALL: PASS|FAIL  (PASS only if D1 and D2 both PASS)
RUBRIC

PLAN_FILE="$WORK/plan.md"
GRADE_FILE="$WORK/grade.txt"

# --- Step 1: generate the plan with the working-tree writing-plans skill ---
echo "Generating plan (plugin-dir: $PLUGIN_DIR)..."
echo "================================================================================"
cd "$WORK" && timeout 600 claude -p \
  "Use the superpowers-rails:writing-plans skill to write an implementation plan for the spec at $WORK/spec.md. This is a Rails project. Save the finished plan to $PLAN_FILE using the Write tool. Do not implement any code. Your final message should only name the file you wrote." \
  --plugin-dir "$PLUGIN_DIR" \
  --add-dir "$WORK" \
  --permission-mode bypassPermissions 2>&1 | tail -5 || {
    echo "EXECUTION FAILED (generate, exit $?)"; exit 1; }
echo "================================================================================"

if [ ! -s "$PLAN_FILE" ]; then
    echo "  [FAIL] No plan was produced at $PLAN_FILE"
    exit 1
fi
echo "Plan written: $(wc -l < "$PLAN_FILE") lines"
echo ""

# --- Step 2: blind-grade the plan ---
echo "Grading plan (blind)..."
cd "$WORK" && timeout 300 claude -p \
  "You are a strict, blind grader. You do not know what produced the plan. Read $WORK/rubric.md, $WORK/spec.md, and $PLAN_FILE. Apply the rubric and output ONLY the exact result block it specifies. Judge D2 on intent-vs-ceremony, not raw length." \
  --plugin-dir "$PLUGIN_DIR" \
  --add-dir "$WORK" \
  --permission-mode bypassPermissions 2>&1 | tee "$GRADE_FILE" || {
    echo "EXECUTION FAILED (grade, exit $?)"; exit 1; }
echo ""

FAILED=0
echo "=== Verification ==="
echo ""

# Test 1 (PRIMARY): blind grade is OVERALL PASS.
echo "Test 1: blind grade OVERALL PASS..."
if grep -qE "OVERALL:[[:space:]]*PASS" "$GRADE_FILE"; then
    echo "  [PASS] Grader rated the plan vertical-slice + thin (OVERALL PASS)"
else
    echo "  [FAIL] Grader did not rate the plan OVERALL PASS"
    echo "         Grade: $(grep -E 'D1_VERDICT|D2_VERDICT|OVERALL' "$GRADE_FILE" | tr '\n' ' ')"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 2 (PRIMARY): grader classified the axis VERTICAL.
echo "Test 2: decomposition axis is VERTICAL..."
if grep -qE "D1_AXIS:[[:space:]]*VERTICAL" "$GRADE_FILE"; then
    echo "  [PASS] Grader classified the decomposition as VERTICAL"
else
    echo "  [FAIL] Grader did not classify the decomposition as VERTICAL"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 3 (STRUCTURAL backstop): no per-step TDD ceremony in the plan itself.
# Guards against grader leniency — the old skill's hallmark ceremony phrasing
# ("Run test to verify it fails", "Expected: FAIL") must not reappear.
echo "Test 3: no per-step TDD ceremony in the plan..."
if grep -qiE "run test to verify it fails|verify it fails|expected:[[:space:]]*fail|step [0-9].*write the failing test" "$PLAN_FILE"; then
    echo "  [FAIL] Plan contains per-step TDD ceremony (reverted to over-detailed steps)"
    FAILED=$((FAILED + 1))
else
    echo "  [PASS] No per-step write-fail-run-implement-run-commit ceremony"
fi
echo ""

# Test 4 (STRUCTURAL backstop): no purely-horizontal layer task headings.
# A task heading that is JUST a layer name ("Create models", "Migrations",
# "Controllers", "Write the tests") is the horizontal anti-pattern.
echo "Test 4: no horizontal layer-only task headings..."
if grep -iE "^#+.*(create (the )?(models|migrations|controllers|views|policies)$|^#+[[:space:]]*(task|slice|step)[[:space:]0-9:.-]*(create )?(all )?(migrations|models|controllers|views|routes|policies)$|write (the )?tests$)" "$PLAN_FILE"; then
    echo "  [FAIL] Plan has a layer-only task heading (horizontal decomposition)"
    grep -inE "^#+.*(migrations|models|controllers|views|policies|write (the )?tests)$" "$PLAN_FILE" | head
    FAILED=$((FAILED + 1))
else
    echo "  [PASS] No layer-only task headings"
fi
echo ""

echo "========================================"
echo " Test Summary"
echo "========================================"
echo ""
if [ $FAILED -eq 0 ]; then
    echo "STATUS: PASSED"
    echo "writing-plans produced a vertical-slice, intent-level plan:"
    echo "  ✓ Blind grade OVERALL PASS"
    echo "  ✓ Decomposition axis VERTICAL"
    echo "  ✓ No per-step TDD ceremony"
    echo "  ✓ No horizontal layer-only task headings"
    exit 0
else
    echo "STATUS: FAILED ($FAILED checks)"
    echo "Plan: $PLAN_FILE"
    echo "Grade: $GRADE_FILE"
    exit 1
fi
