#!/usr/bin/env bash
# test-cli-dispatch.sh — Smoke test for CLI dispatch across all configured CLIs.
# Validates: CLI binary availability, command format, output extraction tiers.
#
# Usage: bash scripts/test-cli-dispatch.sh [--verbose]
# Exit codes: 0 = all available CLIs pass, 1 = at least one failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH_SCRIPT="$SCRIPT_DIR/dispatch-cli-agent.sh"
VERBOSE="${1:-}"

CLIS=("gemini" "codex" "opencode")
PASS=0
FAIL=0
SKIP=0
RESULTS=()

# Create a minimal test prompt
TEST_PROMPT_FILE="$(mktemp /tmp/cli-dispatch-test-XXXXXX.txt)"
cat > "$TEST_PROMPT_FILE" <<'PROMPT'
You are a smoke test. Respond with exactly this JSON:
{"status": "ok", "message": "CLI dispatch smoke test passed"}
Do not include any other text.
PROMPT

cleanup() {
  rm -f "$TEST_PROMPT_FILE"
  rm -f /tmp/cli-dispatch-test-*.txt
  rm -f /tmp/cli-dispatch-output-*.txt
  rm -f /tmp/cli-dispatch-output-*.txt.metrics.json
}
trap cleanup EXIT

echo "=== CLI Dispatch Smoke Test ==="
echo "Dispatch script: $DISPATCH_SCRIPT"
echo ""

for cli in "${CLIS[@]}"; do
  printf "%-12s " "$cli:"

  # Check if CLI binary exists
  if ! command -v "$cli" &>/dev/null; then
    printf "SKIP (not installed)\n"
    SKIP=$((SKIP + 1))
    RESULTS+=("$cli: SKIP")
    continue
  fi

  # Run dispatch with short timeout
  OUTPUT_FILE="$(mktemp /tmp/cli-dispatch-output-XXXXXX.txt)"

  if bash "$DISPATCH_SCRIPT" \
    --cli "$cli" \
    --role "smoketest" \
    --prompt-file "$TEST_PROMPT_FILE" \
    --output-file "$OUTPUT_FILE" \
    --timeout 30 \
    > /dev/null 2>&1; then

    # Check output file has content
    if [[ -s "$OUTPUT_FILE" ]]; then
      printf "PASS"
      # Show parse tier from metrics if available
      METRICS_FILE="${OUTPUT_FILE}.metrics.json"
      if [[ -f "$METRICS_FILE" ]] && command -v jq &>/dev/null; then
        TIER=$(jq -r '.parse_tier // "?"' "$METRICS_FILE" 2>/dev/null)
        METHOD=$(jq -r '.parse_method // "?"' "$METRICS_FILE" 2>/dev/null)
        printf " (tier=%s, method=%s)" "$TIER" "$METHOD"
      fi
      printf "\n"
      PASS=$((PASS + 1))
      RESULTS+=("$cli: PASS")

      if [[ "$VERBOSE" == "--verbose" ]]; then
        echo "  Output (first 3 lines):"
        head -3 "$OUTPUT_FILE" | sed 's/^/    /'
        echo ""
      fi
    else
      printf "FAIL (empty output)\n"
      FAIL=$((FAIL + 1))
      RESULTS+=("$cli: FAIL (empty output)")
    fi
  else
    EXIT_CODE=$?
    printf "FAIL (exit code %d)\n" "$EXIT_CODE"
    FAIL=$((FAIL + 1))
    RESULTS+=("$cli: FAIL (exit $EXIT_CODE)")
  fi

  rm -f "$OUTPUT_FILE" "${OUTPUT_FILE}.metrics.json"
done

echo ""
echo "=== Results ==="
echo "Pass: $PASS  Fail: $FAIL  Skip: $SKIP  Total: ${#CLIS[@]}"
echo ""

# Determine overall CLI mode
AVAILABLE=$((PASS))
if [[ $AVAILABLE -ge 3 ]]; then
  echo "CLI Mode: tri (all 3 CLIs available)"
elif [[ $AVAILABLE -eq 2 ]]; then
  echo "CLI Mode: dual (reduced — 1 CLI missing)"
elif [[ $AVAILABLE -eq 1 ]]; then
  echo "CLI Mode: single (degraded — 2 CLIs missing)"
else
  echo "CLI Mode: disabled (no CLIs available)"
fi

# Exit with failure if any available CLI failed
[[ $FAIL -eq 0 ]]
