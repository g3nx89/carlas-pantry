#!/usr/bin/env bash
# dispatch-cli-agent.sh — Process-group-safe CLI agent dispatch with 4-tier output extraction
# Replaces PAL MCP clink dispatch. Called by coordinators via Bash().
#
# Exit codes: 0=success, 1=CLI failure, 2=timeout, 3=CLI not found, 4=Tier 4 no content

set -euo pipefail

# --- Argument parsing ---
CLI_NAME="" ROLE="" PROMPT_FILE="" OUTPUT_FILE="" TIMEOUT_SEC=300 EXPECTED_FIELDS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cli)          CLI_NAME="$2"; shift 2 ;;
    --role)         ROLE="$2"; shift 2 ;;
    --prompt-file)  PROMPT_FILE="$2"; shift 2 ;;
    --output-file)  OUTPUT_FILE="$2"; shift 2 ;;
    --timeout)      TIMEOUT_SEC="$2"; shift 2 ;;
    --expected-fields) EXPECTED_FIELDS="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$CLI_NAME" || -z "$ROLE" || -z "$PROMPT_FILE" || -z "$OUTPUT_FILE" ]]; then
  echo "Usage: dispatch-cli-agent.sh --cli <name> --role <role> --prompt-file <path> --output-file <path> [--timeout <sec>] [--expected-fields <fields>]" >&2
  exit 1
fi

# --- Build CLI command ---
RAW_OUTPUT="${OUTPUT_FILE}.raw"
METRICS_FILE="${OUTPUT_FILE}.metrics.json"
DISPATCH_ID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "unknown-$$-$(date +%s)")"
PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"
TIMESTAMP_START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
START_EPOCH="$(date +%s)"

# CLI version capture (optional, ~0.1s)
CLI_VERSION=""
if command -v "$CLI_NAME" &>/dev/null; then
  CLI_VERSION="$("$CLI_NAME" --version 2>/dev/null | head -1 || echo "unknown")"
else
  # Write metrics sidecar before exiting
  echo "{\"dispatch_id\":\"$DISPATCH_ID\",\"cli\":\"$CLI_NAME\",\"role\":\"$ROLE\",\"exit_code\":3,\"platform\":\"$PLATFORM\",\"error\":\"CLI not found\"}" > "$METRICS_FILE"
  echo "[DISPATCH_ERROR] CLI '$CLI_NAME' not found in PATH" > "$OUTPUT_FILE"
  exit 3
fi

# Build the CLI invocation command
case "$CLI_NAME" in
  codex)
    CLI_CMD="codex exec --json -C $PROMPT_FILE"
    ;;
  gemini)
    CLI_CMD="gemini --non-interactive --yolo --output-format json < $PROMPT_FILE"
    ;;
  *)
    CLI_CMD="$CLI_NAME < $PROMPT_FILE"
    ;;
esac

# --- Platform-aware dispatch ---
TIMED_OUT=false
DISPATCH_METHOD=""

if command -v setsid &>/dev/null && command -v timeout &>/dev/null; then
  # Linux path (or macOS with Homebrew coreutils + util-linux)
  DISPATCH_METHOD="setsid_timeout"
  set +e
  setsid timeout --signal=TERM --kill-after=10 "$TIMEOUT_SEC" \
    bash -c "$CLI_CMD" > "$RAW_OUTPUT" 2>&1
  EXIT_CODE=$?
  set -e
elif command -v gsetsid &>/dev/null && command -v gtimeout &>/dev/null; then
  # macOS with Homebrew gnu coreutils (prefixed)
  DISPATCH_METHOD="gsetsid_gtimeout"
  set +e
  gsetsid gtimeout --signal=TERM --kill-after=10 "$TIMEOUT_SEC" \
    bash -c "$CLI_CMD" > "$RAW_OUTPUT" 2>&1
  EXIT_CODE=$?
  set -e
else
  # macOS fallback: set -m enables job control (new process group per job)
  DISPATCH_METHOD="set_m_fallback"
  set +e
  set -m
  bash -c "$CLI_CMD" > "$RAW_OUTPUT" 2>&1 &
  CLI_PID=$!
  (
    sleep "$TIMEOUT_SEC"
    kill -- -$CLI_PID 2>/dev/null
    sleep 10
    kill -9 -- -$CLI_PID 2>/dev/null
  ) &
  TIMER_PID=$!
  wait $CLI_PID 2>/dev/null
  EXIT_CODE=$?
  kill $TIMER_PID 2>/dev/null
  wait $TIMER_PID 2>/dev/null || true
  set +m
  set -e
fi

# Check for timeout (exit code 124 from timeout command)
if [[ "$EXIT_CODE" -eq 124 || "$EXIT_CODE" -eq 137 ]]; then
  TIMED_OUT=true
  EXIT_CODE=2
fi

TIMESTAMP_END="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
END_EPOCH="$(date +%s)"
DURATION_MS=$(( (END_EPOCH - START_EPOCH) * 1000 ))
OUTPUT_BYTES="$(wc -c < "$RAW_OUTPUT" 2>/dev/null || echo 0)"

# --- 4-tier content extraction ---
PARSE_TIER=0
PARSE_METHOD="none"
SUMMARY_FOUND=false

# Tier 1: jq JSON envelope extraction
if command -v jq &>/dev/null && [[ -s "$RAW_OUTPUT" ]]; then
  jq -r '.message // .response // empty' "$RAW_OUTPUT" > "$OUTPUT_FILE" 2>/dev/null
  if [[ -s "$OUTPUT_FILE" ]] && [[ "$(head -c 1 "$OUTPUT_FILE")" != "{" ]]; then
    PARSE_TIER=1
    PARSE_METHOD="json_jq"
  else
    : > "$OUTPUT_FILE"  # Clear for next tier
  fi
fi

# Tier 2: python3 partial JSON recovery
if [[ "$PARSE_TIER" -eq 0 ]] && command -v python3 &>/dev/null && [[ -s "$RAW_OUTPUT" ]]; then
  python3 -c "
import re, sys
text = open(sys.argv[1]).read()
# Try .message first (Codex), then .response (Gemini)
for field in ['message', 'response']:
    m = re.search(r'\"' + field + r'\"\s*:\s*\"((?:[^\"\\\\]|\\\\.)*)\"', text, re.DOTALL)
    if m:
        val = m.group(1)
        val = val.replace('\\\\n', '\n').replace('\\\\\"', '\"').replace('\\\\t', '\t')
        sys.stdout.write(val)
        sys.exit(0)
sys.exit(1)
" "$RAW_OUTPUT" > "$OUTPUT_FILE" 2>/dev/null
  if [[ -s "$OUTPUT_FILE" ]]; then
    PARSE_TIER=2
    PARSE_METHOD="json_python3_partial"
  fi
fi

# Tier 3: Raw text with <SUMMARY> scan
if [[ "$PARSE_TIER" -eq 0 ]] && [[ -s "$RAW_OUTPUT" ]]; then
  cp "$RAW_OUTPUT" "$OUTPUT_FILE"
  if grep -q '<SUMMARY>' "$OUTPUT_FILE" 2>/dev/null; then
    PARSE_TIER=3
    PARSE_METHOD="raw_summary_scan"
  fi
fi

# Tier 4: Diagnostic capture
if [[ "$PARSE_TIER" -eq 0 ]]; then
  PARSE_TIER=4
  PARSE_METHOD="diagnostic_capture"
  {
    echo "[DISPATCH_PARSE_FAILURE]"
    echo "cli: $CLI_NAME"
    echo "role: $ROLE"
    echo "exit_code: $EXIT_CODE"
    echo "raw_output_bytes: $OUTPUT_BYTES"
    echo "raw_output_head:"
    head -5 "$RAW_OUTPUT" 2>/dev/null || echo "(empty)"
    echo "raw_output_tail:"
    tail -5 "$RAW_OUTPUT" 2>/dev/null || echo "(empty)"
  } > "$OUTPUT_FILE"
  EXIT_CODE=4
fi

# Check if SUMMARY block exists in final output
if grep -q '<SUMMARY>' "$OUTPUT_FILE" 2>/dev/null; then
  SUMMARY_FOUND=true
fi

# Clean up raw output
rm -f "$RAW_OUTPUT"

# --- Metrics sidecar ---
cat > "$METRICS_FILE" <<SIDECAR
{
  "dispatch_id": "$DISPATCH_ID",
  "timestamp_start": "$TIMESTAMP_START",
  "timestamp_end": "$TIMESTAMP_END",
  "duration_ms": $DURATION_MS,
  "cli": "$CLI_NAME",
  "role": "$ROLE",
  "exit_code": $EXIT_CODE,
  "timeout_configured_ms": $((TIMEOUT_SEC * 1000)),
  "timed_out": $TIMED_OUT,
  "output_bytes": $OUTPUT_BYTES,
  "parse_tier": $PARSE_TIER,
  "parse_method": "$PARSE_METHOD",
  "summary_block_found": $SUMMARY_FOUND,
  "platform": "$PLATFORM",
  "dispatch_method": "$DISPATCH_METHOD",
  "cli_version": "$CLI_VERSION"
}
SIDECAR

exit $EXIT_CODE
