#!/usr/bin/env bash

# Ralph Implement Setup Script
# Validates preconditions, calculates iteration budget, and outputs the prompt
# for the ralph-loop plugin to consume.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONFIG_FILE="$PLUGIN_ROOT/config/implementation-config.yaml"
PROMPT_TEMPLATE="$PLUGIN_ROOT/templates/ralph-implement-prompt.md"

# --- YAML Value Helper ---
# Extracts a value from the config YAML. Uses yq if available, falls back to grep+sed.
# RECOMMENDED: Install yq (https://github.com/mikefarah/yq) for reliable nested YAML parsing.
# The grep+sed fallback only matches leaf key names and takes the first match — it works
# for the current config (leaf keys are unique) but is fragile against future key additions.
# Usage: yaml_val "ralph_loop.iteration_budget.per_phase_multiplier"
yaml_val() {
  local key_path="$1"
  if command -v yq &>/dev/null; then
    yq ".$key_path" "$CONFIG_FILE" 2>/dev/null | tr -d '"'
  else
    local leaf_key="${key_path##*.}"
    grep -E "^\s+${leaf_key}:" "$CONFIG_FILE" | head -1 | sed 's/.*: *//' | sed 's/^"//;s/"$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
  fi
}

# --- Argument Parsing ---

FEATURE_DIR=""
PROFILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Ralph Implement - Autonomous implementation via Ralph Loop

USAGE:
  /product-implementation:ralph-implement FEATURE_DIR [OPTIONS]

ARGUMENTS:
  FEATURE_DIR    Path to the feature directory (e.g., specs/001-user-auth)

OPTIONS:
  --profile <name>    Quality profile: quick, standard, thorough (default: from config ralph.default_profile)
  -h, --help          Show this help message

EXAMPLES:
  /product-implementation:ralph-implement specs/001-user-auth
  /product-implementation:ralph-implement specs/001-feature --profile thorough
HELP_EOF
      exit 0
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    *)
      if [[ -z "$FEATURE_DIR" ]]; then
        FEATURE_DIR="$1"
      fi
      shift
      ;;
  esac
done

# --- Input Validation ---

if [[ -n "$PROFILE" ]] && [[ ! "$PROFILE" =~ ^(quick|standard|thorough)$ ]]; then
  echo "Error: Invalid --profile value: $PROFILE" >&2
  echo "Valid values: quick, standard, thorough" >&2
  exit 1
fi


# --- Precondition Validation ---

# Validate feature directory
if [[ -z "$FEATURE_DIR" ]]; then
  echo "Error: No feature directory provided." >&2
  echo "" >&2
  echo "Usage: /product-implementation:ralph-implement FEATURE_DIR" >&2
  echo "Example: /product-implementation:ralph-implement specs/001-user-auth" >&2
  exit 1
fi

if [[ ! -d "$FEATURE_DIR" ]]; then
  echo "Error: Feature directory not found: $FEATURE_DIR" >&2
  exit 1
fi

# Validate required files
if [[ ! -f "$FEATURE_DIR/tasks.md" ]]; then
  echo "Error: tasks.md not found in $FEATURE_DIR" >&2
  echo "Run /product-planning:tasks first to generate the task list." >&2
  exit 1
fi

if [[ ! -f "$FEATURE_DIR/plan.md" ]]; then
  echo "Error: plan.md not found in $FEATURE_DIR" >&2
  echo "Run /product-planning:plan first to generate the implementation plan." >&2
  exit 1
fi

# Validate config and template exist
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: implementation-config.yaml not found at $CONFIG_FILE" >&2
  exit 1
fi

if [[ ! -f "$PROMPT_TEMPLATE" ]]; then
  echo "Error: ralph-implement-prompt.md not found at $PROMPT_TEMPLATE" >&2
  exit 1
fi

# --- Calculate Iteration Budget ---

# Count phases in tasks.md (lines matching "## Phase" or "### Phase")
PHASE_COUNT=$(grep -cE '^#{2,3}\s+Phase\s+' "$FEATURE_DIR/tasks.md" 2>/dev/null || echo "0")

if [[ "$PHASE_COUNT" -eq 0 ]]; then
  echo "Error: No phases found in $FEATURE_DIR/tasks.md" >&2
  echo "Expected phase headers like '## Phase 1: Setup'" >&2
  exit 1
fi

# Read config values (uses yq if available, falls back to grep+sed)
PER_PHASE_MULT=$(yaml_val "ralph_loop.iteration_budget.per_phase_multiplier")
STAGE1_BUDGET=$(yaml_val "ralph_loop.iteration_budget.stage1_budget")
STAGE6_BUDGET=$(yaml_val "ralph_loop.iteration_budget.stage6_budget")
SAFETY_MARGIN=$(yaml_val "ralph_loop.iteration_budget.safety_margin")
COMPLETION_PROMISE=$(yaml_val "ralph_loop.completion_promise")

# Defaults if config parsing fails
PER_PHASE_MULT="${PER_PHASE_MULT:-8}"
STAGE1_BUDGET="${STAGE1_BUDGET:-2}"
STAGE6_BUDGET="${STAGE6_BUDGET:-2}"
SAFETY_MARGIN="${SAFETY_MARGIN:-1.5}"
COMPLETION_PROMISE="${COMPLETION_PROMISE:-IMPLEMENTATION COMPLETE}"

# Calculate: (phases * per_phase_multiplier + stage1_budget + stage6_budget) * safety_margin
# Use awk for float arithmetic
RAW_BUDGET=$((PHASE_COUNT * PER_PHASE_MULT + STAGE1_BUDGET + STAGE6_BUDGET))
MAX_ITERATIONS=$(echo "$RAW_BUDGET $SAFETY_MARGIN" | awk '{printf "%d", $1 * $2 + 0.5}')

# --- Resolve Profile ---

# Use CLI arg > config profile > ralph.default_profile
if [[ -z "$PROFILE" ]]; then
  CONFIG_PROFILE=$(yaml_val "profile")
  if [[ "$CONFIG_PROFILE" == "null" || -z "$CONFIG_PROFILE" ]]; then
    PROFILE=$(yaml_val "ralph.default_profile")
  else
    PROFILE="$CONFIG_PROFILE"
  fi
fi
PROFILE="${PROFILE:-standard}"

# --- Extract Feature Name ---

# Derive from directory name (last path component)
FEATURE_NAME=$(basename "$FEATURE_DIR")

# --- Generate Prompt ---

# Read template and substitute variables
PROMPT=$(cat "$PROMPT_TEMPLATE")
PROMPT="${PROMPT//\{profile\}/$PROFILE}"
PROMPT="${PROMPT//\{feature_name\}/$FEATURE_NAME}"
PROMPT="${PROMPT//\{feature_dir\}/$FEATURE_DIR}"
PROMPT="${PROMPT//\{completion_promise\}/$COMPLETION_PROMISE}"

# --- Output ---

cat <<EOF
Ralph Implement Setup Complete
==============================
Feature: $FEATURE_NAME
Feature dir: $FEATURE_DIR
Phases found: $PHASE_COUNT
Max iterations: $MAX_ITERATIONS (${PHASE_COUNT}p x ${PER_PHASE_MULT} + ${STAGE1_BUDGET} + ${STAGE6_BUDGET}) x ${SAFETY_MARGIN}
Profile: $PROFILE
Completion promise: $COMPLETION_PROMISE

--- RALPH ARGS ---
MAX_ITERATIONS=$MAX_ITERATIONS
COMPLETION_PROMISE=$COMPLETION_PROMISE

--- PROMPT START ---
$PROMPT
--- PROMPT END ---

To start the Ralph loop, invoke:
/ralph-loop:ralph-loop <prompt above> --max-iterations $MAX_ITERATIONS --completion-promise '$COMPLETION_PROMISE'
EOF
