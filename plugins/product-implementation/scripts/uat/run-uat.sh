#!/usr/bin/env bash
# UAT Test Orchestrator — runs an AI agent (gemini or codex) in headless mode against UAT scenarios
#
# Usage: ./scripts/uat/run-uat.sh [options] GROUP-001 GROUP-002 ...
#
# Options:
#   --engine gemini|codex   Select AI engine (default: gemini, or UAT_ENGINE env)
#   --gemini                Shorthand for --engine gemini
#   --codex                 Shorthand for --engine codex
#   --model <name>          Codex model override (e.g., o3, gpt-5.4)
#   --effort low|medium|high  Codex reasoning effort
#   --build                 Build APK before testing (runs gradle command)
#   --apk <path>            Path to APK file (required unless --build finds one)
#   --package <name>        App package name (auto-detected from APK if omitted)
#   --specs <path>          Path to UAT specs file (required, or UAT_SPECS env)
#   --system-prompt <path>  Path to system prompt (default: uat-system-prompt.md beside this script)
#   --report-dir <path>     Report output directory (default: ./uat-reports, or UAT_REPORT_DIR env)
#   --evidence-dir <path>   Evidence/screenshot directory (default: .uat-evidence)
#   --figma-refs <path>     Figma reference screenshots directory (optional, or UAT_FIGMA_REFS env)
#   --gradle-cmd <cmd>      Gradle build command (default: ./gradlew assembleDebug)
#   --apk-pattern <glob>    APK search pattern (default: **/build/outputs/apk/debug/*.apk)
#   --help                  Show this help message
#
# Environment variables:
#   UAT_ENGINE       Default engine (gemini|codex)
#   UAT_CODEX_MODEL  Default codex model
#   UAT_CODEX_EFFORT Default codex effort
#   UAT_GROUPS       Space-separated group IDs (fallback if none on CLI)
#   UAT_SPECS        Path to UAT specs file
#   UAT_REPORT_DIR   Report output directory
#   UAT_FIGMA_REFS   Figma reference screenshots directory
#   APK_PATH         Path to APK file
#   UAT_PACKAGE      App package name
#   DRY_RUN          Set to "true" to skip engine invocation

set -euo pipefail

# Portable sed -i helper (BSD vs GNU)
sed_inplace() {
    if [[ "$(uname)" == "Darwin" ]]; then sed -i '' "$@"; else sed -i "$@"; fi
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYSTEM_PROMPT="${SCRIPT_DIR}/uat-system-prompt.md"
POLICY_FILE="${SCRIPT_DIR}/policies/uat-testing.toml"

# Defaults (all overridable via flags or env)
APK_PATH="${APK_PATH:-}"
PACKAGE="${UAT_PACKAGE:-}"
UAT_FILE="${UAT_SPECS:-}"
FIGMA_REFS_DIR="${UAT_FIGMA_REFS:-}"
GRADLE_CMD="./gradlew assembleDebug"
APK_PATTERN="**/build/outputs/apk/debug/*.apk"
EVIDENCE_DIR=".uat-evidence"

# Report output
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_DIR="${UAT_REPORT_DIR:-./uat-reports}"
FINAL_REPORT=""

# Engine defaults
BUILD=false
ENGINE="${UAT_ENGINE:-gemini}"
CODEX_MODEL="${UAT_CODEX_MODEL:-}"
CODEX_EFFORT="${UAT_CODEX_EFFORT:-}"

# ── Show help ────────────────────────────────────────────────────────────────
show_help() {
    sed -n '2,/^$/{ s/^# //; s/^#//; p; }' "$0"
    exit 0
}

# ── Parse args ───────────────────────────────────────────────────────────────
TEST_GROUPS=()
NEXT_ARG=""
for arg in "$@"; do
    if [[ -n "$NEXT_ARG" ]]; then
        case "$NEXT_ARG" in
            engine)        ENGINE="$arg" ;;
            model)         CODEX_MODEL="$arg" ;;
            effort)        CODEX_EFFORT="$arg" ;;
            apk)           APK_PATH="$arg" ;;
            package)       PACKAGE="$arg" ;;
            specs)         UAT_FILE="$arg" ;;
            system-prompt) SYSTEM_PROMPT="$arg" ;;
            report-dir)    REPORT_DIR="$arg" ;;
            evidence-dir)  EVIDENCE_DIR="$arg" ;;
            figma-refs)    FIGMA_REFS_DIR="$arg" ;;
            gradle-cmd)    GRADLE_CMD="$arg" ;;
            apk-pattern)   APK_PATTERN="$arg" ;;
        esac
        NEXT_ARG=""
        continue
    fi
    case "$arg" in
        --help)           show_help ;;
        --build)          BUILD=true ;;
        --engine)         NEXT_ARG="engine" ;;
        --model)          NEXT_ARG="model" ;;
        --effort)         NEXT_ARG="effort" ;;
        --apk)            NEXT_ARG="apk" ;;
        --package)        NEXT_ARG="package" ;;
        --specs)          NEXT_ARG="specs" ;;
        --system-prompt)  NEXT_ARG="system-prompt" ;;
        --report-dir)     NEXT_ARG="report-dir" ;;
        --evidence-dir)   NEXT_ARG="evidence-dir" ;;
        --figma-refs)     NEXT_ARG="figma-refs" ;;
        --gradle-cmd)     NEXT_ARG="gradle-cmd" ;;
        --apk-pattern)    NEXT_ARG="apk-pattern" ;;
        --gemini)         ENGINE="gemini" ;;
        --codex)          ENGINE="codex" ;;
        -*)               echo "[ERROR] Unknown option: $arg. Use --help for usage."; exit 1 ;;
        *)                TEST_GROUPS+=("$arg") ;;
    esac
done

# Validate engine
if [[ "$ENGINE" != "gemini" && "$ENGINE" != "codex" ]]; then
    echo "[ERROR] Unknown engine: $ENGINE. Use 'gemini' or 'codex'."
    exit 1
fi

# Fallback groups to env var
if [[ ${#TEST_GROUPS[@]} -eq 0 ]] && [[ -n "${UAT_GROUPS:-}" ]]; then
    read -ra TEST_GROUPS <<< "$UAT_GROUPS"
fi

# Require groups
if [[ ${#TEST_GROUPS[@]} -eq 0 ]]; then
    echo "[ERROR] No test groups specified. Provide group IDs as arguments or set UAT_GROUPS env."
    echo "  Example: ./run-uat.sh --specs specs.md --apk app.apk US-001 US-002"
    exit 1
fi

# Require specs file
if [[ -z "$UAT_FILE" ]]; then
    echo "[ERROR] UAT specs file not specified. Use --specs <path> or set UAT_SPECS env."
    exit 1
fi
if [[ ! -f "$UAT_FILE" ]]; then
    echo "[ERROR] UAT specs file not found: $UAT_FILE"
    exit 1
fi

# Build APK if requested
if [[ "$BUILD" == true ]]; then
    echo "[BUILD] Running: $GRADLE_CMD"
    read -ra _gradle_args <<< "$GRADLE_CMD"
    "${_gradle_args[@]}" --quiet
    echo "[BUILD] Done."
fi

# Auto-detect APK if not specified
if [[ -z "$APK_PATH" ]]; then
    # Search for APK using pattern
    APK_PATH=$(find . -path "$APK_PATTERN" -type f 2>/dev/null | head -1 || true)
    if [[ -z "$APK_PATH" ]]; then
        echo "[ERROR] No APK found matching pattern: $APK_PATTERN"
        echo "  Build first with --build or specify --apk <path>."
        exit 1
    fi
    echo "[INFO] Auto-detected APK: $APK_PATH"
fi

# Verify APK exists
if [[ ! -f "$APK_PATH" ]]; then
    echo "[ERROR] APK not found at $APK_PATH. Run with --build or build manually."
    exit 1
fi

# Auto-detect package from APK if not specified
if [[ -z "$PACKAGE" ]]; then
    if command -v aapt2 &>/dev/null; then
        PACKAGE=$(aapt2 dump badging "$APK_PATH" 2>/dev/null | sed -n "s/.*package: name='\([^']*\)'.*/\1/p" | head -1 || true)
    elif command -v aapt &>/dev/null; then
        PACKAGE=$(aapt dump badging "$APK_PATH" 2>/dev/null | sed -n "s/.*package: name='\([^']*\)'.*/\1/p" | head -1 || true)
    fi
    if [[ -z "$PACKAGE" ]]; then
        echo "[ERROR] Could not auto-detect package name. Use --package <name> or set UAT_PACKAGE env."
        exit 1
    fi
    echo "[INFO] Auto-detected package: $PACKAGE"
fi

# Verify engine is available
if [[ "$ENGINE" == "gemini" ]]; then
    if ! command -v gemini &>/dev/null; then
        echo "[ERROR] gemini-cli not found. Install via: npm i -g @google/gemini-cli"
        exit 1
    fi
elif [[ "$ENGINE" == "codex" ]]; then
    if ! command -v codex &>/dev/null; then
        echo "[ERROR] codex-cli not found. Install via: npm i -g @openai/codex"
        exit 1
    fi
fi

# Verify system prompt exists
if [[ ! -f "$SYSTEM_PROMPT" ]]; then
    echo "[ERROR] System prompt not found: $SYSTEM_PROMPT"
    exit 1
fi

# Create report directory
REPORT_DIR="${REPORT_DIR}/uat-${TIMESTAMP}"
FINAL_REPORT="$REPORT_DIR/uat-report.md"
mkdir -p "$REPORT_DIR"

# Track child PIDs for cleanup on Ctrl+C
CHILD_PIDS=()
cleanup() {
    echo ""
    echo "[CLEANUP] Caught signal, killing child processes..."
    for pid in "${CHILD_PIDS[@]}"; do
        kill "$pid" 2>/dev/null && echo "[CLEANUP] Killed PID $pid"
    done
    exit 130
}
trap cleanup INT TERM

# Extract UAT scenarios for a given group from the UAT file
extract_scenarios() {
    local group="$1"
    # Use awk to extract from "## GROUP:" to next "## GROUP-" or "## Summary"
    awk -v grp="## ${group}:" '
        $0 ~ grp { found=1; print; next }
        found && /^## ([A-Z]+-[0-9]+|Summary)/ { exit }
        found { print }
    ' "$UAT_FILE"
}

# Run a single UAT group
run_group() {
    local group="$1"
    local group_report="$REPORT_DIR/${group}.md"

    echo ""
    echo "============================================"
    echo "[UAT] Running group: $group"
    echo "============================================"

    # Extract relevant scenarios
    local scenarios
    scenarios=$(extract_scenarios "$group")

    if [[ -z "$scenarios" ]]; then
        echo "[WARN] No scenarios found for $group, skipping."
        echo "# $group — SKIPPED (no scenarios found)" > "$group_report"
        return
    fi

    # Build the task prompt
    local figma_refs_section=""
    if [[ -n "$FIGMA_REFS_DIR" ]] && [[ -d "$FIGMA_REFS_DIR" ]]; then
        figma_refs_section="- Figma reference screenshots: ${FIGMA_REFS_DIR}/ (files named SCREEN-ID.png)"
    fi

    local task_prompt
    task_prompt="Execute the following UAT test scenarios on the Android emulator.

## Setup
- APK path: $APK_PATH
- Package: $PACKAGE
- Device: use the first available device from mobile_list_available_devices
${figma_refs_section}

## Scenarios to Test

$scenarios

## Instructions
1. **CRITICAL: Clean install** — ALWAYS start by calling mobile_uninstall_app (package: $PACKAGE) to remove any previous data, then mobile_install_app with the APK, then mobile_launch_app. This guarantees a fresh state.
2. Execute each UAT scenario using the SAV loop (State-Action-Verify)
3. For each scenario, report PASS/FAIL/BLOCKED with evidence
4. Save screenshots for any FAIL results to: $REPORT_DIR/
5. **Mid-test resets** — Follow the \"App State Reset\" rules in your system prompt:
   - If a scenario says \"fresh install\": do full reset (uninstall → install → launch)
   - If a scenario says \"force-close and relaunch\": do process death (terminate → launch), data must be preserved
   - Always verify app state with mobile_list_elements_on_screen after any reset
6. After completing functional tests for each screen, perform a Visual Parity Check:
   - Take a screenshot with mobile_take_screenshot
   - Load the Figma reference PNG from the figma references directory using read_file for visual comparison
   - Compare the mobile screenshot against the Figma reference: layout, colors, typography, spacing
   - Report discrepancies in the Visual Parity table format
7. After all scenarios, compile the final UAT report including the Visual Parity Summary"

    echo "[UAT] Launching $ENGINE for $group..."

    # Dry-run mode: skip engine invocation
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo "[DRY RUN] Would execute $ENGINE with ${#scenarios} chars of scenarios for $group" | tee "$group_report"
        return
    fi

    # Combine system prompt + task prompt for engines that don't support separate system prompts
    local full_prompt
    full_prompt="$(cat "$SYSTEM_PROMPT")

---

$task_prompt"

    set +e
    local engine_pid
    if [[ "$ENGINE" == "gemini" ]]; then
        # Gemini: system prompt via stdin, task prompt via -p
        cat "$SYSTEM_PROMPT" | gemini \
            -p "$task_prompt" \
            --yolo \
            --output-format text \
            > "$group_report" 2>&1 &
        engine_pid=$!
    elif [[ "$ENGINE" == "codex" ]]; then
        # Codex: full prompt via stdin, non-interactive exec mode
        # --dangerously-bypass-approvals-and-sandbox is needed for MCP tool calls
        # without manual approval (equivalent to gemini --yolo)
        local codex_args=(exec - --dangerously-bypass-approvals-and-sandbox -o "$group_report")
        [[ -n "$CODEX_MODEL" ]]  && codex_args+=(-m "$CODEX_MODEL")
        [[ -n "$CODEX_EFFORT" ]] && codex_args+=(-c "model_reasoning_effort=\"$CODEX_EFFORT\"")
        echo "$full_prompt" | codex "${codex_args[@]}" \
            > "${group_report}.log" 2>&1 &
        engine_pid=$!
    fi
    CHILD_PIDS+=("$engine_pid")
    wait "$engine_pid"
    local exit_code=$?
    set -e

    # Strip engine bootstrap noise from report
    if [[ -f "$group_report" ]]; then
        if [[ "$ENGINE" == "gemini" ]]; then
            sed_inplace '/^YOLO mode is enabled/d; /^Loaded cached credentials/d; /^Loading extension:/d; /^Registering extension/d; /^Registered theme:/d; /^Server .* supports .* updates/d' "$group_report"
        elif [[ "$ENGINE" == "codex" ]]; then
            # Codex -o writes only the final agent message, minimal noise
            # But strip any ANSI escape codes that may leak through
            sed_inplace $'s/\x1b\\[[0-9;]*m//g' "$group_report" 2>/dev/null || true
        fi
    fi

    if [[ $exit_code -eq 0 ]]; then
        echo "[UAT] $group completed. Report: $group_report"
    else
        echo "[ERROR] $ENGINE failed for $group (exit code: $exit_code)"
        # Prepend error header to the report
        local tmp_file="${group_report}.tmp"
        echo "# $group — ERROR ($ENGINE exit code: $exit_code)" > "$tmp_file"
        cat "$group_report" >> "$tmp_file"
        mv "$tmp_file" "$group_report"
    fi
}

# Assemble final consolidated report
assemble_report() {
    echo ""
    echo "============================================"
    echo "[REPORT] Assembling final report"
    echo "============================================"

    cat > "$FINAL_REPORT" <<EOF
# UAT Test Report

**Date:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Engine:** $ENGINE
**APK:** $APK_PATH
**Package:** $PACKAGE
**Groups Tested:** ${TEST_GROUPS[*]}

---

EOF

    # Append each group report
    for group in "${TEST_GROUPS[@]}"; do
        local group_report="$REPORT_DIR/${group}.md"
        if [[ -f "$group_report" ]]; then
            echo "" >> "$FINAL_REPORT"
            echo "---" >> "$FINAL_REPORT"
            echo "" >> "$FINAL_REPORT"
            echo "## Group: $group" >> "$FINAL_REPORT"
            echo "" >> "$FINAL_REPORT"
            cat "$group_report" >> "$FINAL_REPORT"
        fi
    done

    echo ""
    echo "[DONE] Final report: $FINAL_REPORT"
    echo "[DONE] Individual reports in: $REPORT_DIR/"
}

# Main execution
echo "========================================"
echo "  UAT Test Orchestrator"
echo "  $(date)"
echo "========================================"
echo ""
echo "Engine:  $ENGINE"
[[ -n "$CODEX_MODEL" ]]  && echo "Model:   $CODEX_MODEL"
[[ -n "$CODEX_EFFORT" ]] && echo "Effort:  $CODEX_EFFORT"
echo "Groups:  ${TEST_GROUPS[*]}"
echo "APK:     $APK_PATH"
echo "Package: $PACKAGE"
echo "Specs:   $UAT_FILE"
echo "Report:  $REPORT_DIR"

for group in "${TEST_GROUPS[@]}"; do
    run_group "$group"
done

assemble_report
