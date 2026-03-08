#!/usr/bin/env bash
# verify_protocol.sh — Mechanical protocol compliance verification
#
# Parses stage summary YAML files to check for required protocol_evidence fields.
# Breaks the LLM-checking-LLM trust boundary with actual file parsing.
#
# Usage:
#   verify_protocol.sh <feature_dir> [stage_number]
#
# Examples:
#   verify_protocol.sh /path/to/feature          # Check all stages (2-5)
#   verify_protocol.sh /path/to/feature 2        # Check Stage 2 only
#
# Exit codes:
#   0 — All checked stages are compliant
#   1 — One or more violations detected
#   2 — Usage error or missing dependencies

set -euo pipefail

# --- Argument parsing ---
if [[ $# -lt 1 ]]; then
  echo "Usage: verify_protocol.sh <feature_dir> [stage_number]" >&2
  exit 2
fi

FEATURE_DIR="$1"
SPECIFIC_STAGE="${2:-}"
SUMMARY_DIR="$FEATURE_DIR/.stage-summaries"

if [[ ! -d "$SUMMARY_DIR" ]]; then
  echo "ERROR: Summary directory not found: $SUMMARY_DIR" >&2
  exit 2
fi

# --- Determine which stages to check ---
if [[ -n "$SPECIFIC_STAGE" ]]; then
  STAGES=("$SPECIFIC_STAGE")
else
  STAGES=(2 3 4 5)
fi

# --- State ---
violations=0
checked=0
results=()

# --- Helper: extract YAML frontmatter from markdown ---
extract_frontmatter() {
  local file="$1"
  # Extract content between first --- and second ---
  sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d'
}

# --- Helper: check if a field exists in YAML text ---
field_exists() {
  local yaml="$1"
  local field="$2"
  echo "$yaml" | grep -q "^[[:space:]]*${field}:" 2>/dev/null
}

# --- Helper: check if a field has non-empty array content ---
field_has_entries() {
  local yaml="$1"
  local field="$2"
  # Check for inline array with content: field: [{...}] or field: ["..."]
  if echo "$yaml" | grep -q "^[[:space:]]*${field}:.*\[.\+\]" 2>/dev/null; then
    return 0
  fi
  # Check for block array: field:\n  - ...
  local in_field=false
  while IFS= read -r line; do
    if echo "$line" | grep -q "^[[:space:]]*${field}:" 2>/dev/null; then
      in_field=true
      continue
    fi
    if $in_field; then
      if echo "$line" | grep -q "^[[:space:]]*-" 2>/dev/null; then
        return 0
      fi
      # Non-continuation line means field ended without entries
      if echo "$line" | grep -q "^[[:space:]]*[a-z_]" 2>/dev/null; then
        return 1
      fi
    fi
  done <<< "$yaml"
  return 1
}

# --- Per-stage checks ---
check_stage() {
  local stage="$1"
  local stage_violations=0

  # Find summary file (handle per-phase naming variants)
  local summary_file=""
  for pattern in "stage-${stage}-summary.md" "final-stage-${stage}-summary.md" "phase-*-stage-${stage}-summary.md"; do
    local found
    found=$(find "$SUMMARY_DIR" -name "$pattern" -maxdepth 1 2>/dev/null | head -1)
    if [[ -n "$found" ]]; then
      summary_file="$found"
      break
    fi
  done

  if [[ -z "$summary_file" ]]; then
    results+=("Stage $stage: SKIP (no summary file found)")
    return
  fi

  checked=$((checked + 1))
  local yaml
  yaml=$(extract_frontmatter "$summary_file")

  if [[ -z "$yaml" ]]; then
    results+=("Stage $stage: FAIL — no YAML frontmatter found in $(basename "$summary_file")")
    violations=$((violations + 1))
    return
  fi

  # Check 1: protocol_evidence field exists
  if ! field_exists "$yaml" "protocol_evidence"; then
    results+=("Stage $stage: FAIL — protocol_evidence field missing entirely")
    violations=$((violations + 1))
    return
  fi

  # Extract the protocol_evidence block (everything from protocol_evidence: to next top-level field)
  local pe_block
  pe_block=$(echo "$yaml" | sed -n '/^[[:space:]]*protocol_evidence:/,/^[a-z]/p' | sed '$d')

  if [[ -z "$pe_block" ]]; then
    # protocol_evidence exists but has no content (or is the last field)
    pe_block=$(echo "$yaml" | sed -n '/^[[:space:]]*protocol_evidence:/,$p')
  fi

  # Check 2: agents_dispatched has entries
  if ! field_has_entries "$pe_block" "agents_dispatched"; then
    results+=("Stage $stage: FAIL — protocol_evidence.agents_dispatched is empty or missing")
    stage_violations=$((stage_violations + 1))
  fi

  # Check 3: prompt_templates_used has entries
  if ! field_has_entries "$pe_block" "prompt_templates_used"; then
    results+=("Stage $stage: FAIL — protocol_evidence.prompt_templates_used is empty or missing")
    stage_violations=$((stage_violations + 1))
  fi

  # Check 4: phases_executed_sequentially is present and true
  if ! echo "$pe_block" | grep -q "phases_executed_sequentially:.*true" 2>/dev/null; then
    if echo "$pe_block" | grep -q "phases_executed_sequentially:.*false" 2>/dev/null; then
      results+=("Stage $stage: FAIL — phases_executed_sequentially is false (parallel execution detected)")
      stage_violations=$((stage_violations + 1))
    elif ! field_exists "$pe_block" "phases_executed_sequentially"; then
      results+=("Stage $stage: FAIL — phases_executed_sequentially field missing")
      stage_violations=$((stage_violations + 1))
    fi
  fi

  # Check 5: Stage-specific agent requirements
  case "$stage" in
    2)
      # Must have developer in agents_dispatched
      if ! echo "$pe_block" | grep -q 'type:.*developer' 2>/dev/null; then
        results+=("Stage $stage: FAIL — no developer agent in agents_dispatched")
        stage_violations=$((stage_violations + 1))
      fi
      ;;
    3)
      if ! echo "$pe_block" | grep -q 'type:.*developer' 2>/dev/null; then
        results+=("Stage $stage: FAIL — no developer agent in agents_dispatched")
        stage_violations=$((stage_violations + 1))
      fi
      ;;
    4)
      # Must have 3+ developer entries with Quality Review Prompt
      local reviewer_count
      reviewer_count=$(echo "$pe_block" | grep -c 'template_used:.*Quality Review Prompt' 2>/dev/null || true)
      if [[ "$reviewer_count" -lt 3 ]]; then
        results+=("Stage $stage: FAIL — only $reviewer_count Quality Review Prompt dispatches (expected >= 3)")
        stage_violations=$((stage_violations + 1))
      fi
      ;;
    5)
      if ! echo "$pe_block" | grep -q 'type:.*tech-writer' 2>/dev/null; then
        results+=("Stage $stage: FAIL — no tech-writer agent in agents_dispatched")
        stage_violations=$((stage_violations + 1))
      fi
      ;;
  esac

  if [[ $stage_violations -eq 0 ]]; then
    results+=("Stage $stage: PASS")
  else
    violations=$((violations + stage_violations))
  fi
}

# --- Main ---
echo "Protocol Compliance Verification"
echo "================================"
echo "Feature: $FEATURE_DIR"
echo ""

for stage in "${STAGES[@]}"; do
  check_stage "$stage"
done

# --- Output ---
for result in "${results[@]}"; do
  if echo "$result" | grep -q "PASS"; then
    echo "  ✓ $result"
  elif echo "$result" | grep -q "SKIP"; then
    echo "  - $result"
  else
    echo "  ✗ $result"
  fi
done

echo ""
echo "Checked: $checked stages | Violations: $violations"

if [[ $violations -gt 0 ]]; then
  exit 1
else
  exit 0
fi
