#!/usr/bin/env bash
# dispatch-via-ntm.sh v2.0 — Robot-mode parallel dual-CLI dispatch via ntm
#
# Uses ntm robot mode for structured interaction:
# - --robot-spawn for session creation with JSON validation
# - --robot-status for agent readiness verification
# - --robot-ack for native completion detection (replaces manual polling)
# - --robot-metrics for native metrics capture
# - ntm send for prompt delivery (handles large payloads via tmux input)
# - ntm copy for output capture (with SUMMARY block extraction)
#
# Usage:
#   dispatch-via-ntm.sh \
#     --session <name> \
#     --dispatch <cli>:<role>:<prompt-file>:<output-file> \
#     [--dispatch <cli>:<role>:<prompt-file>:<output-file>] \
#     --timeout <seconds> \
#     [--init-wait <seconds>]
#
# Exit codes:
#   0 = all CLIs produced SUMMARY output
#   1 = partial failure (some CLIs produced no output)
#   2 = timeout (robot-ack expired before all agents idle)
#   3 = ntm not found or prerequisite failure
#   4 = no dispatches specified or invalid args
#   5 = ntm spawn failed (session could not be created)

set -euo pipefail

# ─────────────────────────────────────────────────────────────────
# PREREQUISITES
# ─────────────────────────────────────────────────────────────────

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "[DISPATCH_ERROR] bash 4+ required (found ${BASH_VERSION}). Install: brew install bash" >&2
  exit 3
fi

if ! command -v ntm &>/dev/null; then
  echo "[DISPATCH_ERROR] ntm not found in PATH. Install: brew install dicklesworthstone/tap/ntm" >&2
  exit 3
fi

# ─────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ' | tr '\r' ' '
}

# Strip ANSI escape sequences from terminal output (CSI, OSC, charset switches)
strip_ansi() {
  printf '%s' "$1" | sed 's/\x1b\[[?]*[0-9;]*[a-zA-Z]//g; s/\x1b][^\x07]*\x07//g; s/\x1b[()][A-Z0-9]//g'
}

# ─────────────────────────────────────────────────────────────────
# ARGUMENT PARSING
# ─────────────────────────────────────────────────────────────────

SESSION=""
TIMEOUT_SEC=300
INIT_WAIT=5
declare -a DISPATCHES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session)        SESSION="$2"; shift 2 ;;
    --dispatch)       DISPATCHES+=("$2"); shift 2 ;;
    --timeout)        TIMEOUT_SEC="$2"; shift 2 ;;
    --poll-interval)  shift 2 ;;  # Deprecated (robot-ack replaces polling); accept silently
    --init-wait)      INIT_WAIT="$2"; shift 2 ;;
    *) echo "[DISPATCH_ERROR] Unknown argument: $1" >&2; exit 4 ;;
  esac
done

if [[ -z "$SESSION" || ${#DISPATCHES[@]} -eq 0 ]]; then
  cat >&2 <<'USAGE'
Usage: dispatch-via-ntm.sh \
  --session <name> \
  --dispatch <cli>:<role>:<prompt-file>:<output-file> \
  [--dispatch ...] \
  --timeout <seconds> \
  [--init-wait <seconds>]

Supported CLIs: codex, gemini
Note: --poll-interval is deprecated (robot-ack replaces polling).
USAGE
  exit 4
fi

# ─────────────────────────────────────────────────────────────────
# PARSE DISPATCH SPECS
# ─────────────────────────────────────────────────────────────────

declare -a CLIS=() ROLES=() PROMPTS=() OUTPUTS=()
COD_COUNT=0
GMI_COUNT=0

for d in "${DISPATCHES[@]}"; do
  IFS=':' read -r cli role prompt_file output_file <<< "$d"

  # Validate CLI type and count
  case "$cli" in
    codex)  COD_COUNT=$((COD_COUNT + 1)) ;;
    gemini) GMI_COUNT=$((GMI_COUNT + 1)) ;;
    *) echo "[DISPATCH_ERROR] Unsupported CLI '$cli'. Supported: codex, gemini" >&2; exit 4 ;;
  esac

  # Resolve prompt to absolute path
  if [[ "$prompt_file" != /* ]]; then
    prompt_file="$(realpath "$prompt_file" 2>/dev/null || echo "$prompt_file")"
  fi

  # Validate prompt file exists
  if [[ ! -f "$prompt_file" ]]; then
    echo "[DISPATCH_ERROR] Prompt file not found: $prompt_file" >&2
    exit 4
  fi

  CLIS+=("$cli")
  ROLES+=("$role")
  PROMPTS+=("$prompt_file")
  OUTPUTS+=("$output_file")
done

# Guard: ntm send/copy cannot disambiguate multiple panes of the same CLI type
if [[ $COD_COUNT -gt 1 || $GMI_COUNT -gt 1 ]]; then
  echo "[DISPATCH_ERROR] Multiple instances of same CLI not supported (codex=${COD_COUNT}, gemini=${GMI_COUNT}). Use 1 per type." >&2
  exit 4
fi

AGENT_COUNT=${#CLIS[@]}

# ─────────────────────────────────────────────────────────────────
# METRICS SETUP
# ─────────────────────────────────────────────────────────────────

DISPATCH_ID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "dispatch-$$-$(date +%s)")"
START_EPOCH="$(date +%s)"

# ─────────────────────────────────────────────────────────────────
# TRAP: CLEANUP ON ANY EXIT
# ─────────────────────────────────────────────────────────────────

cleanup() {
  echo "[ntm] Cleaning up session '$SESSION'..."
  ntm kill -f "$SESSION" 2>/dev/null || true
}
trap cleanup EXIT

# ─────────────────────────────────────────────────────────────────
# SPAWN VIA ROBOT MODE
# ─────────────────────────────────────────────────────────────────

# Defensive cleanup: kill stale session with same name
ntm kill -f "$SESSION" 2>/dev/null || true
sleep 1

# Handle nested tmux: unset TMUX so ntm can create a new session
unset TMUX 2>/dev/null || true

# Build robot-spawn args
SPAWN_ARGS=("--robot-spawn=$SESSION")
[[ $COD_COUNT -gt 0 ]] && SPAWN_ARGS+=("--spawn-cod=$COD_COUNT")
[[ $GMI_COUNT -gt 0 ]] && SPAWN_ARGS+=("--spawn-gmi=$GMI_COUNT")

echo "[ntm] Spawning session '$SESSION' via robot-spawn (${COD_COUNT} codex + ${GMI_COUNT} gemini)..."
SPAWN_RESULT=$(ntm "${SPAWN_ARGS[@]}" --json 2>&1) || {
  echo "[DISPATCH_ERROR] ntm robot-spawn failed for session '$SESSION': $SPAWN_RESULT" >&2
  exit 5
}

# Validate spawn success from JSON envelope
if echo "$SPAWN_RESULT" | grep -q '"success"[[:space:]]*:[[:space:]]*false'; then
  SPAWN_ERROR=$(echo "$SPAWN_RESULT" | grep -o '"error"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"$//')
  echo "[DISPATCH_ERROR] ntm spawn reported failure: ${SPAWN_ERROR:-unknown}" >&2
  exit 5
fi

# Configure tmux scrollback to prevent truncation of verbose CLI output
tmux set-option -t "$SESSION" history-limit 50000 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────
# WAIT FOR AGENT READINESS (robot-status replaces blind sleep)
# ─────────────────────────────────────────────────────────────────

echo "[ntm] Verifying agent readiness (max ${INIT_WAIT}s)..."
READY_DEADLINE=$(($(date +%s) + INIT_WAIT))
AGENTS_READY=false

while [[ $(date +%s) -lt $READY_DEADLINE ]]; do
  sleep 2
  STATUS_JSON=$(ntm --robot-status --json 2>/dev/null || echo '{}')
  # Check if session appears in status output (agents registered) — word-boundary match
  if echo "$STATUS_JSON" | grep -qw "$SESSION"; then
    AGENTS_READY=true
    echo "[ntm] Session '$SESSION' confirmed active"
    break
  fi
done

if [[ "$AGENTS_READY" == "false" ]]; then
  echo "[ntm] WARNING: Could not confirm agent readiness via robot-status — proceeding anyway"
  sleep 2  # Grace period before sending
fi

# ─────────────────────────────────────────────────────────────────
# SEND PROMPTS
# ─────────────────────────────────────────────────────────────────

echo "[ntm] Sending ${AGENT_COUNT} prompts..."

for i in "${!CLIS[@]}"; do
  cli="${CLIS[$i]}"
  role="${ROLES[$i]}"
  prompt_file="${PROMPTS[$i]}"

  # Read prompt content (role instructions + spec content are pre-assembled by coordinator)
  prompt_content="$(cat "$prompt_file")"

  # Size guard: warn if prompt exceeds 200KB (ntm send passes as shell argument)
  prompt_len=${#prompt_content}
  if [[ $prompt_len -gt 200000 ]]; then
    echo "[DISPATCH_ERROR] Prompt too large (${prompt_len} bytes) for ntm send argument delivery" >&2
    exit 4
  fi

  # NOTE: Uses `ntm send` (not --robot-send) deliberately.
  # ntm send delivers via tmux terminal input — proven for large payloads (up to 200KB).
  # --robot-send --msg= uses shell arguments with the same size limit but adds no benefit
  # here (we don't need the JSON envelope for send confirmation). Migrate if structured
  # send-error diagnostics become needed.
  send_ok=true
  case "$cli" in
    codex)  ntm send "$SESSION" --cod "$prompt_content" || send_ok=false ;;
    gemini) ntm send "$SESSION" --gmi "$prompt_content" || send_ok=false ;;
  esac

  if [[ "$send_ok" == "true" ]]; then
    echo "[ntm] Sent prompt to $cli ($role) [${prompt_len} bytes]"
  else
    echo "[ntm] WARNING: ntm send failed for $cli ($role) — agent may not have received prompt" >&2
  fi
done

# ─────────────────────────────────────────────────────────────────
# WAIT FOR COMPLETION VIA ROBOT-ACK
# ─────────────────────────────────────────────────────────────────
# robot-ack blocks until all agents return to WAITING state (idle)
# or the timeout expires. Replaces the manual poll-for-SUMMARY loop.

echo "[ntm] Waiting for agent completion via robot-ack (timeout: ${TIMEOUT_SEC}s)..."
ACK_SUCCESS=true
ACK_STDERR=""
ACK_STDERR=$(ntm --robot-ack="$SESSION" --ack-timeout="${TIMEOUT_SEC}s" 2>&1 >/dev/null) || ACK_SUCCESS=false

CAPTURE_EPOCH="$(date +%s)"
WALL_CLOCK_MS=$(( (CAPTURE_EPOCH - START_EPOCH) * 1000 ))
ELAPSED_SEC=$((CAPTURE_EPOCH - START_EPOCH))

if [[ "$ACK_SUCCESS" == "true" ]]; then
  echo "[ntm] All agents completed in ${ELAPSED_SEC}s"
else
  echo "[ntm] robot-ack timed out after ${TIMEOUT_SEC}s — capturing available output"
  [[ -n "$ACK_STDERR" ]] && echo "[ntm] ack diagnostic: $ACK_STDERR" >&2
fi

# ─────────────────────────────────────────────────────────────────
# CAPTURE OUTPUT
# ─────────────────────────────────────────────────────────────────

EXIT_CODE=0

for i in "${!CLIS[@]}"; do
  cli="${CLIS[$i]}"
  role="${ROLES[$i]}"
  output_file="${OUTPUTS[$i]}"

  # Ensure output directory exists
  mkdir -p "$(dirname "$output_file")"

  # Capture agent output
  raw_output=""
  case "$cli" in
    codex)  raw_output="$(ntm copy "$SESSION" --cod 2>/dev/null || true)" ;;
    gemini) raw_output="$(ntm copy "$SESSION" --gmi 2>/dev/null || true)" ;;
  esac

  # Strip ANSI escape codes (CSI with ?, OSC, charset switches)
  raw_output="$(strip_ansi "$raw_output")"

  # Extract SUMMARY block (handles both multi-line and single-line cases)
  SUMMARY_FOUND=false
  if printf '%s' "$raw_output" | grep -q '<SUMMARY>'; then
    summary="$(printf '%s\n' "$raw_output" | sed -n '/<SUMMARY>/,/<\/SUMMARY>/{/<SUMMARY>/d;/<\/SUMMARY>/d;p}')"
    if [[ -n "$summary" ]]; then
      printf '%s\n' "$summary" > "$output_file"
      SUMMARY_FOUND=true
    else
      # Single-line <SUMMARY>content</SUMMARY> — extract inline
      summary="$(printf '%s\n' "$raw_output" | grep '<SUMMARY>' | sed 's/.*<SUMMARY>//;s/<\/SUMMARY>.*//')"
      if [[ -n "$summary" ]]; then
        printf '%s\n' "$summary" > "$output_file"
        SUMMARY_FOUND=true
      fi
    fi
  fi

  if [[ "$SUMMARY_FOUND" == "false" ]]; then
    if [[ -n "$raw_output" ]]; then
      # No SUMMARY block — save raw output (best-effort)
      printf '%s\n' "$raw_output" > "$output_file"
      echo "[ntm] WARNING: No SUMMARY block from $cli ($role) — raw output saved"
    else
      # No output at all
      cat > "$output_file" <<EOF
[DISPATCH_CAPTURE_FAILURE]
cli: $cli
role: $role
session: $SESSION
timed_out: $([ "$ACK_SUCCESS" = "true" ] && echo "false" || echo "true")
wall_clock_seconds: ${ELAPSED_SEC}
EOF
      echo "[ntm] ERROR: No output captured from $cli ($role)"
      EXIT_CODE=1
    fi
  fi
done

# ─────────────────────────────────────────────────────────────────
# METRICS VIA ROBOT MODE (consolidated, replaces per-CLI sidecars)
# ─────────────────────────────────────────────────────────────────

METRICS_DIR="$(dirname "${OUTPUTS[0]}")/../cli-metrics"
mkdir -p "$METRICS_DIR" 2>/dev/null || true
METRICS_FILE="$METRICS_DIR/dispatch-${DISPATCH_ID}.json"

# Capture native ntm session metrics (token counts, velocities, durations)
NTM_METRICS=$(ntm --robot-metrics="$SESSION" --json 2>/dev/null || echo '{}')

cat > "$METRICS_FILE" <<METRICS
{
  "dispatch_id": "$(json_escape "$DISPATCH_ID")",
  "session": "$(json_escape "$SESSION")",
  "timestamp_start": "$(date -u -r "$START_EPOCH" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)",
  "timestamp_end": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "wall_clock_ms": ${WALL_CLOCK_MS},
  "timeout_configured_ms": $((TIMEOUT_SEC * 1000)),
  "ack_success": ${ACK_SUCCESS},
  "exit_code": ${EXIT_CODE},
  "agent_count": ${AGENT_COUNT},
  "dispatch_method": "ntm_robot_v2",
  "agents": [$(
    sep=""
    for i in "${!CLIS[@]}"; do
      printf '%s{"cli":"%s","role":"%s"}' "$sep" "$(json_escape "${CLIS[$i]}")" "$(json_escape "${ROLES[$i]}")"
      sep=","
    done
  )],
  "ntm_native_metrics": ${NTM_METRICS}
}
METRICS

echo "[ntm] Metrics written to $METRICS_FILE"

# ─────────────────────────────────────────────────────────────────
# FINAL EXIT CODE (cleanup runs via trap)
# ─────────────────────────────────────────────────────────────────

if [[ "$ACK_SUCCESS" != "true" && $EXIT_CODE -eq 0 ]]; then
  EXIT_CODE=2  # timeout, but some agents may have partial output
fi

echo "[ntm] Dispatch complete. Exit code: $EXIT_CODE (0=success, 1=partial, 2=timeout, 3=prereq, 4=bad args, 5=spawn fail)"
exit $EXIT_CODE
