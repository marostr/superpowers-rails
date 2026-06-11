#!/bin/bash
# PreToolUse hook: Enforce Rails conventions skills when editing Rails files
# Uses deny-until-skill-loaded pattern - blocks edits until required skill is loaded

LOG_FILE="/tmp/claude-skill-usage.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
  echo "[$TIMESTAMP] $1" >> "$LOG_FILE"
}

# Read JSON input from stdin
input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
skill_name=$(echo "$input" | jq -r '.tool_input.skill // empty')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

log "HOOK START: tool=$tool_name path=$file_path skill=$skill_name"

# Log skill usage - always allow Skill tool
if [[ "$tool_name" == "Skill" && -n "$skill_name" ]]; then
  log "BRANCH: Skill tool -> loaded: $skill_name"
  exit 0
fi

# Exit early if no file_path (not a file operation)
if [[ -z "$file_path" ]]; then
  log "BRANCH: No file_path -> exit early"
  exit 0
fi

# Function to check if skill was loaded in transcript
skill_loaded() {
  local skill="$1"
  if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    if grep -q "\"skill\": \"$skill\"" "$transcript_path" 2>/dev/null || \
       grep -q "\"skill\":\"$skill\"" "$transcript_path" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

# Function to deny with message - uses exit code 2 to block
deny_without_skill() {
  local skill="$1"
  local file_type="$2"

  log "BRANCH: $file_type matched -> DENIED (skill $skill not loaded)"

  cat >&2 << EOF
BLOCKED: You must load the $skill skill before editing $file_type files.

STOP. Do not immediately retry your edit.
1. Load the skill: Skill(skill: "$skill")
2. Read the conventions carefully
3. Reconsider whether your planned edit follows them
4. Adjust your approach if needed, then edit
EOF
  exit 2
}

# Function to allow after skill loaded
allow_with_skill() {
  local skill="$1"
  local file_type="$2"

  log "BRANCH: $file_type matched -> ALLOWED (skill $skill already loaded)"
  exit 0
}

# Check if this is a Rails controller file
if [[ "$file_path" == */app/controllers/*.rb ]]; then
  if skill_loaded "superpowers-rails:rails-controller-conventions"; then
    allow_with_skill "superpowers-rails:rails-controller-conventions" "controller"
  else
    deny_without_skill "superpowers-rails:rails-controller-conventions" "controller"
  fi
  exit 0
fi

# Check if this is a Rails model file
if [[ "$file_path" == */app/models/*.rb ]]; then
  if skill_loaded "superpowers-rails:rails-model-conventions"; then
    allow_with_skill "superpowers-rails:rails-model-conventions" "model"
  else
    deny_without_skill "superpowers-rails:rails-model-conventions" "model"
  fi
  exit 0
fi

# Check if this is a Rails view file
if [[ "$file_path" == */app/views/*.erb ]]; then
  if skill_loaded "superpowers-rails:rails-view-conventions"; then
    allow_with_skill "superpowers-rails:rails-view-conventions" "view"
  else
    deny_without_skill "superpowers-rails:rails-view-conventions" "view"
  fi
  exit 0
fi

# Check if this is a Rails helper file (prohibited - should migrate to ViewComponents)
if [[ "$file_path" == */app/helpers/*.rb ]]; then
  if skill_loaded "superpowers-rails:rails-view-conventions"; then
    allow_with_skill "superpowers-rails:rails-view-conventions" "helper"
  else
    deny_without_skill "superpowers-rails:rails-view-conventions" "helper"
  fi
  exit 0
fi

# Check if this is a ViewComponent file (Ruby, not Stimulus JS)
if [[ "$file_path" == */app/components/*.rb ]] && [[ "$file_path" != *_controller.js ]]; then
  if skill_loaded "superpowers-rails:rails-view-conventions"; then
    allow_with_skill "superpowers-rails:rails-view-conventions" "ViewComponent"
  else
    deny_without_skill "superpowers-rails:rails-view-conventions" "ViewComponent"
  fi
  exit 0
fi

# Check if this is a Stimulus controller file
if [[ "$file_path" == */app/components/*_controller.js ]] || [[ "$file_path" == */app/packs/controllers/*_controller.js ]]; then
  if skill_loaded "superpowers-rails:rails-stimulus-conventions"; then
    allow_with_skill "superpowers-rails:rails-stimulus-conventions" "Stimulus controller"
  else
    deny_without_skill "superpowers-rails:rails-stimulus-conventions" "Stimulus controller"
  fi
  exit 0
fi

# Check if this is a Rails policy file
if [[ "$file_path" == */app/policies/*.rb ]]; then
  if skill_loaded "superpowers-rails:rails-policy-conventions"; then
    allow_with_skill "superpowers-rails:rails-policy-conventions" "policy"
  else
    deny_without_skill "superpowers-rails:rails-policy-conventions" "policy"
  fi
  exit 0
fi

# Check if this is a Rails job file
if [[ "$file_path" == */app/jobs/*.rb ]]; then
  if skill_loaded "superpowers-rails:rails-job-conventions"; then
    allow_with_skill "superpowers-rails:rails-job-conventions" "job"
  else
    deny_without_skill "superpowers-rails:rails-job-conventions" "job"
  fi
  exit 0
fi

# Check if this is a database migration file
if [[ "$file_path" == */db/migrate/*.rb ]]; then
  if skill_loaded "superpowers-rails:rails-migration-conventions"; then
    allow_with_skill "superpowers-rails:rails-migration-conventions" "migration"
  else
    deny_without_skill "superpowers-rails:rails-migration-conventions" "migration"
  fi
  exit 0
fi

# Check if this is a spec file
if [[ "$file_path" == */spec/*.rb ]]; then
  if skill_loaded "superpowers-rails:rails-testing-conventions"; then
    allow_with_skill "superpowers-rails:rails-testing-conventions" "spec"
  else
    deny_without_skill "superpowers-rails:rails-testing-conventions" "spec"
  fi
  exit 0
fi

# For other files, proceed normally
log "BRANCH: No pattern matched -> allowing without skill requirement"
exit 0
