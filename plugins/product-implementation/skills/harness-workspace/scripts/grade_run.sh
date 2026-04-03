#!/bin/bash
# Grade a single eval run by checking assertions against outputs
# Usage: grade_run.sh <outputs_dir> <eval_id>
#
# Reads assertions from evals.json and checks them against files in outputs_dir.
# Writes grading.json to the run directory.

set -euo pipefail

OUTPUTS_DIR="$1"
EVAL_ID="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
EVALS_FILE="$WORKSPACE_DIR/evals/evals.json"

if [ ! -d "$OUTPUTS_DIR" ]; then
  echo "ERROR: Outputs directory not found: $OUTPUTS_DIR"
  exit 1
fi

# Extract assertions for this eval
ASSERTIONS=$(jq -r --argjson id "$EVAL_ID" '.evals[] | select(.id == $id) | .assertions' "$EVALS_FILE")
ASSERTION_COUNT=$(echo "$ASSERTIONS" | jq 'length')

echo "Grading eval $EVAL_ID with $ASSERTION_COUNT assertions..."
echo "Outputs dir: $OUTPUTS_DIR"
echo ""

RESULTS="[]"
PASSED=0
FAILED=0

for i in $(seq 0 $((ASSERTION_COUNT - 1))); do
  TEXT=$(echo "$ASSERTIONS" | jq -r ".[$i].text")
  TYPE=$(echo "$ASSERTIONS" | jq -r ".[$i].type")
  PATH_VAL=$(echo "$ASSERTIONS" | jq -r ".[$i].path // empty")
  PATTERN=$(echo "$ASSERTIONS" | jq -r ".[$i].pattern // empty")
  QUERY=$(echo "$ASSERTIONS" | jq -r ".[$i].query // empty")

  FULL_PATH="$OUTPUTS_DIR/$PATH_VAL"
  # Normalize: try dot-claude variant if .claude path not found
  if [ -n "$PATH_VAL" ] && [ ! -e "$FULL_PATH" ]; then
    ALT_PATH="${PATH_VAL/.claude/dot-claude}"
    if [ -e "$OUTPUTS_DIR/$ALT_PATH" ]; then
      FULL_PATH="$OUTPUTS_DIR/$ALT_PATH"
    fi
  fi
  RESULT_PASSED=false
  EVIDENCE=""

  case "$TYPE" in
    file_exists)
      if [ -f "$FULL_PATH" ]; then
        RESULT_PASSED=true
        EVIDENCE="File exists: $PATH_VAL"
      else
        EVIDENCE="File NOT found: $PATH_VAL"
      fi
      ;;

    file_json_valid)
      if [ -f "$FULL_PATH" ] && jq . "$FULL_PATH" > /dev/null 2>&1; then
        RESULT_PASSED=true
        EVIDENCE="Valid JSON file: $PATH_VAL"
      elif [ ! -f "$FULL_PATH" ]; then
        EVIDENCE="File NOT found: $PATH_VAL"
      else
        EVIDENCE="File exists but is NOT valid JSON: $PATH_VAL"
      fi
      ;;

    file_contains)
      if [ -f "$FULL_PATH" ] && grep -qE "$PATTERN" "$FULL_PATH" 2>/dev/null; then
        RESULT_PASSED=true
        MATCH=$(grep -oE "$PATTERN" "$FULL_PATH" 2>/dev/null | head -1)
        EVIDENCE="Found pattern '$MATCH' in $PATH_VAL"
      elif [ ! -f "$FULL_PATH" ]; then
        EVIDENCE="File NOT found: $PATH_VAL"
      else
        EVIDENCE="Pattern '$PATTERN' NOT found in $PATH_VAL"
      fi
      ;;

    file_not_contains)
      if [ ! -f "$FULL_PATH" ]; then
        EVIDENCE="File NOT found: $PATH_VAL (cannot verify absence)"
      elif ! grep -qE "$PATTERN" "$FULL_PATH" 2>/dev/null; then
        RESULT_PASSED=true
        EVIDENCE="Pattern '$PATTERN' correctly absent from $PATH_VAL"
      else
        MATCH=$(grep -oE "$PATTERN" "$FULL_PATH" 2>/dev/null | head -1)
        EVIDENCE="Pattern '$MATCH' FOUND in $PATH_VAL (should be absent)"
      fi
      ;;

    json_query)
      if [ -f "$FULL_PATH" ] && jq -e "$QUERY" "$FULL_PATH" > /dev/null 2>&1; then
        RESULT_PASSED=true
        EVIDENCE="JSON query '$QUERY' returned true"
      elif [ ! -f "$FULL_PATH" ]; then
        EVIDENCE="File NOT found: $PATH_VAL"
      else
        ACTUAL=$(jq "$QUERY" "$FULL_PATH" 2>/dev/null || echo "query error")
        EVIDENCE="JSON query '$QUERY' returned: $ACTUAL"
      fi
      ;;

    file_contains_any)
      PATHS=$(echo "$ASSERTIONS" | jq -r ".[$i].paths[]")
      FOUND=false
      for P in $PATHS; do
        FP="$OUTPUTS_DIR/$P"
        if [ -f "$FP" ] && grep -qE "$PATTERN" "$FP" 2>/dev/null; then
          FOUND=true
          MATCH=$(grep -oE "$PATTERN" "$FP" 2>/dev/null | head -1)
          EVIDENCE="Found pattern '$MATCH' in $P"
          break
        fi
      done
      if [ "$FOUND" = true ]; then
        RESULT_PASSED=true
      else
        EVIDENCE="Pattern '$PATTERN' not found in any of the checked files"
      fi
      ;;

    *)
      EVIDENCE="Unknown assertion type: $TYPE"
      ;;
  esac

  if [ "$RESULT_PASSED" = true ]; then
    PASSED=$((PASSED + 1))
    STATUS_ICON="PASS"
  else
    FAILED=$((FAILED + 1))
    STATUS_ICON="FAIL"
  fi

  echo "  [$STATUS_ICON] $TEXT"
  echo "         $EVIDENCE"

  RESULTS=$(echo "$RESULTS" | jq \
    --arg text "$TEXT" \
    --argjson passed "$RESULT_PASSED" \
    --arg evidence "$EVIDENCE" \
    '. + [{"text": $text, "passed": $passed, "evidence": $evidence}]')
done

echo ""
echo "Results: $PASSED passed, $FAILED failed out of $ASSERTION_COUNT"

# Write grading.json
RUN_DIR="$(dirname "$OUTPUTS_DIR")"
GRADING_FILE="$RUN_DIR/grading.json"

jq -n \
  --argjson eval_id "$EVAL_ID" \
  --argjson passed "$PASSED" \
  --argjson failed "$FAILED" \
  --argjson total "$ASSERTION_COUNT" \
  --argjson expectations "$RESULTS" \
  '{
    eval_id: $eval_id,
    pass_rate: (($passed / $total) * 100 | round),
    passed: $passed,
    failed: $failed,
    total: $total,
    expectations: $expectations
  }' > "$GRADING_FILE"

echo "Grading saved to: $GRADING_FILE"
