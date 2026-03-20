#!/usr/bin/env bash
# dispatch-via-ntm.sh — Parallel dual-CLI dispatch via ntm (Named Tmux Manager)
#
# Replaces dispatch-cli-agent.sh. Spawns codex + gemini agents in parallel
# via ntm, sends role-specific prompts, polls for SUMMARY block completion,
# captures output, writes metrics sidecars.
#
# Usage:
#   dispatch-via-ntm.sh \
#     --session <name> \
#     --dispatch <cli>:<role>:<prompt-file>:<output-file> \
#     [--dispatch <cli>:<role>:<prompt-file>:<output-file>] \
#     --timeout <seconds> \
#     [--poll-interval <seconds>] \
#     [--init-wait <seconds>]
#
# Exit codes:
#   0 = all CLIs produced SUMMARY output
#   1 = partial failure (some CLIs produced no output)
#   2 = timeout (no CLI produced SUMMARY before deadline)
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

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g'; }

# ─────────────────────────────────────────────────────────────────
# ARGUMENT PARSING
# ─────────────────────────────────────────────────────────────────

SESSION=""
TIMEOUT_SEC=300
POLL_INTERVAL=15
INIT_WAIT=8
declare -a DISPATCHES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session)        SESSION="$2"; shift 2 ;;
    --dispatch)       DISPATCHES+=("$2"); shift 2 ;;
    --timeout)        TIMEOUT_SEC="$2"; shift 2 ;;
    --poll-interval)  POLL_INTERVAL="$2"; shift 2 ;;
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
  [--poll-interval <seconds>] \
  [--init-wait <seconds>]

Supported CLIs: codex, gemini
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
TIMESTAMP_START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
START_EPOCH="$(date +%s)"
DEADLINE=$((START_EPOCH + TIMEOUT_SEC))

# ─────────────────────────────────────────────────────────────────
# TRAP: CLEANUP ON ANY EXIT
# ─────────────────────────────────────────────────────────────────

cleanup() {
  echo "[ntm] Cleaning up session '$SESSION'..."
  ntm kill -f "$SESSION" 2>/dev/null || true
}
trap cleanup EXIT

# ─────────────────────────────────────────────────────────────────
# SPAWN NTM SESSION
# ─────────────────────────────────────────────────────────────────

# Defensive cleanup: kill stale session with same name
ntm kill -f "$SESSION" 2>/dev/null || true
sleep 1

# Handle nested tmux: unset TMUX so ntm can create a new session
unset TMUX 2>/dev/null || true

# Build spawn args
SPAWN_ARGS=()
[[ $COD_COUNT -gt 0 ]] && SPAWN_ARGS+=("--cod=$COD_COUNT")
[[ $GMI_COUNT -gt 0 ]] && SPAWN_ARGS+=("--gmi=$GMI_COUNT")

echo "[ntm] Spawning session '$SESSION' with ${COD_COUNT} codex + ${GMI_COUNT} gemini agents..."
if ! ntm spawn "$SESSION" "${SPAWN_ARGS[@]}" 2>&1; then
  echo "[DISPATCH_ERROR] ntm spawn failed for session '$SESSION'" >&2
  exit 5
fi

# Configure tmux scrollback to prevent truncation of verbose CLI output
tmux set-option -t "$SESSION" history-limit 50000 2>/dev/null || true

# Wait for agents to initialize (shell + CLI startup)
echo "[ntm] Waiting ${INIT_WAIT}s for agent initialization..."
sleep "$INIT_WAIT"

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
# POLL FOR COMPLETION (wall-clock deadline)
# ─────────────────────────────────────────────────────────────────

echo "[ntm] Polling for SUMMARY blocks (timeout: ${TIMEOUT_SEC}s, interval: ${POLL_INTERVAL}s)..."

declare -A DONE_MAP=()
declare -A CACHED_OUTPUT=()

while [[ $(date +%s) -lt $DEADLINE ]]; do
  sleep "$POLL_INTERVAL"

  for i in "${!CLIS[@]}"; do
    # Skip already-completed agents
    [[ -n "${DONE_MAP[$i]:-}" ]] && continue

    cli="${CLIS[$i]}"
    pane_output=""

    case "$cli" in
      codex)  pane_output="$(ntm copy "$SESSION" --cod 2>/dev/null || true)" ;;
      gemini) pane_output="$(ntm copy "$SESSION" --gmi 2>/dev/null || true)" ;;
    esac

    if printf '%s' "$pane_output" | grep -q '</SUMMARY>'; then
      DONE_MAP[$i]="done"
      CACHED_OUTPUT[$i]="$pane_output"
      ELAPSED=$(( $(date +%s) - START_EPOCH ))
      echo "[ntm] ${cli} (${ROLES[$i]}) completed at ${ELAPSED}s"
    fi
  done

  # Check if all done
  if [[ ${#DONE_MAP[@]} -eq $AGENT_COUNT ]]; then
    ELAPSED=$(( $(date +%s) - START_EPOCH ))
    echo "[ntm] All agents completed in ${ELAPSED}s"
    break
  fi

  ELAPSED=$(( $(date +%s) - START_EPOCH ))
  echo "[ntm] Progress: ${#DONE_MAP[@]}/${AGENT_COUNT} completed (${ELAPSED}s/${TIMEOUT_SEC}s)"
done

ALL_DONE=false
[[ ${#DONE_MAP[@]} -eq $AGENT_COUNT ]] && ALL_DONE=true

# ─────────────────────────────────────────────────────────────────
# CAPTURE OUTPUT
# ─────────────────────────────────────────────────────────────────

EXIT_CODE=0
CAPTURE_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
CAPTURE_EPOCH="$(date +%s)"
WALL_CLOCK_MS=$(( (CAPTURE_EPOCH - START_EPOCH) * 1000 ))

for i in "${!CLIS[@]}"; do
  cli="${CLIS[$i]}"
  role="${ROLES[$i]}"
  output_file="${OUTPUTS[$i]}"

  # Ensure output directory exists
  mkdir -p "$(dirname "$output_file")"

  # Use cached output from polling if available, otherwise re-capture
  raw_output=""
  if [[ -n "${CACHED_OUTPUT[$i]:-}" ]]; then
    raw_output="${CACHED_OUTPUT[$i]}"
  else
    case "$cli" in
      codex)  raw_output="$(ntm copy "$SESSION" --cod 2>/dev/null || true)" ;;
      gemini) raw_output="$(ntm copy "$SESSION" --gmi 2>/dev/null || true)" ;;
    esac
  fi

  # Strip ANSI escape codes from terminal output
  raw_output="$(printf '%s' "$raw_output" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')"

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
timed_out: $([ "$ALL_DONE" = "true" ] && echo "false" || echo "true")
wall_clock_seconds: $((CAPTURE_EPOCH - START_EPOCH))
EOF
      echo "[ntm] ERROR: No output captured from $cli ($role)"
      EXIT_CODE=1
    fi
  fi

  # ─── Per-dispatch metrics sidecar ───
  METRICS_FILE="${output_file}.metrics.json"
  OUTPUT_BYTES="$(wc -c < "$output_file" 2>/dev/null | tr -d ' ' || echo 0)"

  cat > "$METRICS_FILE" <<SIDECAR
{
  "dispatch_id": "$(json_escape "$DISPATCH_ID")",
  "timestamp_start": "$(json_escape "$TIMESTAMP_START")",
  "timestamp_end": "$(json_escape "$CAPTURE_TIMESTAMP")",
  "wall_clock_ms": ${WALL_CLOCK_MS},
  "cli": "$(json_escape "$cli")",
  "role": "$(json_escape "$role")",
  "exit_code": ${EXIT_CODE},
  "timeout_configured_ms": $((TIMEOUT_SEC * 1000)),
  "timed_out": $([ "$ALL_DONE" = "true" ] && echo "false" || echo "true"),
  "output_bytes": ${OUTPUT_BYTES},
  "summary_block_found": ${SUMMARY_FOUND},
  "dispatch_method": "ntm",
  "capture_method": "ntm_copy_summary_extract",
  "parallel": true,
  "agent_count": ${AGENT_COUNT},
  "session": "$(json_escape "$SESSION")"
}
SIDECAR
done

# ─────────────────────────────────────────────────────────────────
# FINAL EXIT CODE (cleanup runs via trap)
# ─────────────────────────────────────────────────────────────────

if [[ "$ALL_DONE" != "true" ]]; then
  if [[ $EXIT_CODE -eq 0 ]]; then
    EXIT_CODE=2  # timeout, but some may have partial output
  fi
fi

echo "[ntm] Dispatch complete. Exit code: $EXIT_CODE (0=success, 1=partial, 2=timeout, 3=prereq, 4=bad args, 5=spawn fail)"
exit $EXIT_CODE
