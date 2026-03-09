#!/usr/bin/env bash
# dispatch-test-augmenter.sh — Sequential dual-model test gap analysis
# Gemini produces a DRAFT, Codex REFINES it into a FINAL report.
# Analytical only — never modifies source or test code.
#
# Exit codes:
#   0  — Both models succeeded (final report written)
#   1  — Partial: one model succeeded (draft or fallback used as final)
#   2  — Both models failed (no usable output)
#   10 — Analysis complete, zero actionable gaps found (check `actionable_gaps: 0` in SUMMARY)

set -euo pipefail

# ── Logging helpers ───────────────────────────────────────────────────────────
log()  { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [test-augmenter] $*" >&2; }
warn() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [test-augmenter] WARN: $*" >&2; }
err()  { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [test-augmenter] ERROR: $*" >&2; }

# ── Argument parsing ──────────────────────────────────────────────────────────
FEATURE_DIR=""
PLUGIN_ROOT=""
PHASE=""
CONTEXT_FILE=""
CODEX_MODEL="gpt-5.4"  # Fallback default — caller should pass --codex-model from cli_defaults.codex.model in config
CODEX_EFFORT="high"
MAX_GAPS=20
TIMEOUT=300

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature-dir)   FEATURE_DIR="$2";   shift 2 ;;
    --plugin-root)   PLUGIN_ROOT="$2";   shift 2 ;;
    --phase)         PHASE="$2";         shift 2 ;;
    --context-file)  CONTEXT_FILE="$2";  shift 2 ;;
    --codex-model)   CODEX_MODEL="$2";   shift 2 ;;
    --codex-effort)  CODEX_EFFORT="$2";  shift 2 ;;
    --max-gaps)      MAX_GAPS="$2";      shift 2 ;;
    --timeout)       TIMEOUT="$2";       shift 2 ;;
    *) err "Unknown argument: $1"; exit 1 ;;
  esac
done

# ── Required arg validation ───────────────────────────────────────────────────
MISSING=()
[[ -z "$FEATURE_DIR" ]]  && MISSING+=("--feature-dir")
[[ -z "$PLUGIN_ROOT" ]]  && MISSING+=("--plugin-root")
[[ -z "$PHASE" ]]        && MISSING+=("--phase")
[[ -z "$CONTEXT_FILE" ]] && MISSING+=("--context-file")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  err "Missing required arguments: ${MISSING[*]}"
  err "Usage: dispatch-test-augmenter.sh --feature-dir <path> --plugin-root <path> --phase <name> --context-file <path> [--codex-model <model>] [--codex-effort <effort>] [--max-gaps <n>] [--timeout <sec>]"
  exit 1
fi

if [[ ! -d "$FEATURE_DIR" ]]; then
  err "Feature directory does not exist: $FEATURE_DIR"
  exit 1
fi

if [[ ! -f "$CONTEXT_FILE" ]]; then
  err "Context file does not exist: $CONTEXT_FILE"
  exit 1
fi

# ── Derived values ────────────────────────────────────────────────────────────
PHASE_SLUG="$(echo "$PHASE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GEMINI_ROLE_PROMPT="$PLUGIN_ROOT/config/cli_clients/gemini_test_augmenter.txt"
CODEX_ROLE_PROMPT="$PLUGIN_ROOT/config/cli_clients/codex_test_augmenter.txt"

DRAFT_FILE="$FEATURE_DIR/.test-augmentation-${PHASE_SLUG}.draft.md"
FINAL_FILE="$FEATURE_DIR/.test-augmentation-${PHASE_SLUG}.md"

# Temp files — cleaned up on exit
GEMINI_PROMPT_FILE=""
CODEX_PROMPT_FILE=""
GEMINI_OUTPUT_FILE=""
CODEX_OUTPUT_FILE=""

cleanup() {
  local files=("$GEMINI_PROMPT_FILE" "$CODEX_PROMPT_FILE" "$GEMINI_OUTPUT_FILE" "$CODEX_OUTPUT_FILE")
  for f in "${files[@]}"; do
    [[ -n "$f" && -f "$f" ]] && rm -f "$f"
  done
  # Also clean up metrics sidecars written by dispatch-cli-agent.sh
  [[ -n "$GEMINI_OUTPUT_FILE" ]] && rm -f "${GEMINI_OUTPUT_FILE}.metrics.json" 2>/dev/null || true
  [[ -n "$CODEX_OUTPUT_FILE" ]]  && rm -f "${CODEX_OUTPUT_FILE}.metrics.json"  2>/dev/null || true
}
trap cleanup EXIT

# ── Validate role prompt files ────────────────────────────────────────────────
if [[ ! -f "$GEMINI_ROLE_PROMPT" ]]; then
  err "Gemini role prompt not found: $GEMINI_ROLE_PROMPT"
  exit 1
fi

if [[ ! -f "$CODEX_ROLE_PROMPT" ]]; then
  err "Codex role prompt not found: $CODEX_ROLE_PROMPT"
  err "Expected at: $CODEX_ROLE_PROMPT"
  err "Create config/cli_clients/codex_test_augmenter.txt to enable the Codex refinement pass."
  exit 1
fi

# ── Read context file ─────────────────────────────────────────────────────────
CONTEXT_CONTENT="$(cat "$CONTEXT_FILE")"

log "Starting test augmentation for phase: $PHASE (slug: $PHASE_SLUG)"
log "Feature dir:  $FEATURE_DIR"
log "Plugin root:  $PLUGIN_ROOT"
log "Context file: $CONTEXT_FILE"
log "Codex model:  $CODEX_MODEL  effort: $CODEX_EFFORT"
log "Max gaps:     $MAX_GAPS  Timeout: ${TIMEOUT}s"

# ── Step 1: Gemini DRAFT pass ─────────────────────────────────────────────────
log "Step 1/2: Dispatching Gemini (draft pass)..."

GEMINI_PROMPT_FILE="$(mktemp /tmp/test-aug-gemini-prompt-XXXXXX.md)"
GEMINI_OUTPUT_FILE="$(mktemp /tmp/test-aug-gemini-output-XXXXXX.md)"

# Build composite Gemini prompt: role prompt + phase context + max-gaps directive
{
  cat "$GEMINI_ROLE_PROMPT"
  printf '\n\n## Phase Context\n\n'
  printf '%s' "$CONTEXT_CONTENT"
  printf '\n\nMax gaps to report: %d\n' "$MAX_GAPS"
} > "$GEMINI_PROMPT_FILE"

GEMINI_EXIT=0
"$SCRIPT_DIR/dispatch-cli-agent.sh" \
  --cli gemini \
  --role test_augmenter \
  --timeout "$TIMEOUT" \
  --prompt-file "$GEMINI_PROMPT_FILE" \
  --output-file "$GEMINI_OUTPUT_FILE" \
  || GEMINI_EXIT=$?

GEMINI_SUCCESS=false
if [[ "$GEMINI_EXIT" -eq 0 ]] && [[ -s "$GEMINI_OUTPUT_FILE" ]]; then
  cp "$GEMINI_OUTPUT_FILE" "$DRAFT_FILE"
  GEMINI_SUCCESS=true
  log "Gemini draft succeeded — written to: $DRAFT_FILE"
else
  warn "Gemini draft failed (exit code: $GEMINI_EXIT). Proceeding to Codex without a draft."
fi

# ── Step 2: Codex REFINE pass ─────────────────────────────────────────────────
log "Step 2/2: Dispatching Codex (refine pass, model=$CODEX_MODEL, effort=$CODEX_EFFORT)..."

CODEX_PROMPT_FILE="$(mktemp /tmp/test-aug-codex-prompt-XXXXXX.md)"
CODEX_OUTPUT_FILE="$(mktemp /tmp/test-aug-codex-output-XXXXXX.md)"

# Build composite Codex prompt: role prompt + phase context + draft (or fallback)
{
  cat "$CODEX_ROLE_PROMPT"
  printf '\n\n## Phase Context\n\n'
  printf '%s' "$CONTEXT_CONTENT"
  printf '\n\nMax gaps to report: %d\n' "$MAX_GAPS"
  printf '\n\n'
  if [[ "$GEMINI_SUCCESS" == "true" ]] && [[ -s "$DRAFT_FILE" ]]; then
    printf '## Draft Report to Review and Finalize\n\n'
    cat "$DRAFT_FILE"
  else
    printf '## No Draft Available\nNo draft available — produce full analysis from scratch.\n'
  fi
} > "$CODEX_PROMPT_FILE"

CODEX_EXIT=0
"$SCRIPT_DIR/dispatch-cli-agent.sh" \
  --cli codex \
  --role test_augmenter \
  --model "$CODEX_MODEL" \
  --effort "$CODEX_EFFORT" \
  --timeout "$TIMEOUT" \
  --prompt-file "$CODEX_PROMPT_FILE" \
  --output-file "$CODEX_OUTPUT_FILE" \
  || CODEX_EXIT=$?

CODEX_SUCCESS=false
if [[ "$CODEX_EXIT" -eq 0 ]] && [[ -s "$CODEX_OUTPUT_FILE" ]]; then
  cp "$CODEX_OUTPUT_FILE" "$FINAL_FILE"
  CODEX_SUCCESS=true
  log "Codex refinement succeeded — final report written to: $FINAL_FILE"
elif [[ "$GEMINI_SUCCESS" == "true" ]]; then
  warn "Codex refinement failed (exit code: $CODEX_EXIT). Falling back to Gemini draft as final report."
  cp "$DRAFT_FILE" "$FINAL_FILE"
  log "Fallback final report written to: $FINAL_FILE"
else
  err "Both Gemini and Codex failed. No output produced."
fi

# ── Exit code decision ────────────────────────────────────────────────────────

# Check for zero actionable gaps in the final report (exit code 10)
if [[ -s "$FINAL_FILE" ]]; then
  if grep -q 'actionable_gaps: 0' "$FINAL_FILE" 2>/dev/null; then
    log "Zero actionable gaps found in final report. Exiting with code 10."
    exit 10
  fi
fi

if [[ "$GEMINI_SUCCESS" == "true" && "$CODEX_SUCCESS" == "true" ]]; then
  log "Both passes succeeded. Exiting with code 0."
  exit 0
elif [[ "$GEMINI_SUCCESS" == "true" || "$CODEX_SUCCESS" == "true" ]]; then
  warn "Partial success (one model failed). Exiting with code 1."
  exit 1
else
  err "Both models failed. Exiting with code 2."
  exit 2
fi
