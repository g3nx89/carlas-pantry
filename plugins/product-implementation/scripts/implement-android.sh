#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  implement-android.sh — Bash orchestrator for per-phase implementation     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# PURPOSE
#   Replaces LLM-driven orchestration (SKILL.md → coordinators) with a Bash
#   script that gives each phase a fresh `claude -p` session, eliminating the
#   cross-phase context accumulation that caused Phases B-E to fail.
#
# ARCHITECTURE (two levels)
#   Bash (this script)    — deterministic inter-phase flow: parse tasks.md,
#                           loop over phases, build prompts, verify builds,
#                           commit after each phase.
#   Claude (claude -p)    — intra-phase complexity: TDD cycles, subagent
#                           dispatch, Figma handoff, iteration. Each call gets
#                           a fresh context window via session isolation.
#
#   Subagents are made available to claude -p via --plugin-dir, which loads
#   the product-implementation plugin's agent definitions. Each agent's .md
#   file contains baked-in skill references (dev-skills, meta-skills) that
#   are read via progressive disclosure — no runtime skill injection needed.
#
# VERTICAL AGENT SELECTION
#   The script auto-detects the vertical agent type by scanning tasks.md,
#   plan.md, and design.md for domain indicators (Kotlin/Compose → android-
#   developer, React/Vue → frontend-developer, REST/SQL → backend-developer).
#   Override with --vertical-agent TYPE.
#
# FIGMA INTEGRATION
#   Three ways to provide the Figma file:
#     --figma-url URL     Parse file key from a Figma URL (zero cost)
#     --figma-key KEY     Provide the file key directly
#     --figma-file NAME   Resolve by file name via figma_list_open_files MCP
#   When provided, a dedicated Claude session extracts structured design specs
#   per phase BEFORE implementation ("extract once, use everywhere"), and
#   capture-figma-refs.sh exports reference PNGs for visual parity.
#
# PIPELINE (per phase, all steps enabled by default)
#   0. Figma handoff   — extract design specs + download reference PNGs
#   1. Implement (TDD) — test-writer → vertical-agent → output-verifier
#      → build check
#   2. Simplify        — code-simplifier agent, fix-or-rollback
#      → build check
#   3. UAT             — uat-tester + debugger + regression tests (UI phases)
#      → build check
#   4. Quality gate:
#      a. Augment      — Gemini→Codex gap analysis + implement gaps + verify
#      b. Native review— 3 parallel developer agents (3 perspectives)
#      c. CLI review   — Codex/Gemini specialized reviewers
#      d. Fix          — auto-fix Critical/High from all sources
#      → build check
#   5. Commit          — git commit with task-based changelog
#
#   Use --no-simplify, --no-uat, --no-augment, --no-review to disable steps,
#   or --minimal to disable all optional steps at once.
#
# PREREQUISITES
#   - claude CLI (claude.ai/code)
#   - gradlew in PROJECT_ROOT
#   - bash 4+ if using --figma-key/url/file (capture-figma-refs.sh needs it)
#   - Optional: codex CLI, gemini CLI (for CLI reviews and test augmentation)
#   - Optional: adb + running emulator (for UAT mobile testing)
#
# USAGE
#   ./implement-android.sh --feature-dir DIR --project-root DIR [options]
#
#   Examples:
#     # Basic — implement Phase B with all steps
#     ./implement-android.sh \
#       --feature-dir ~/project/docs/specs \
#       --project-root ~/project \
#       --start-from B --stop-after B
#
#     # With Figma — paste the URL from your browser
#     ./implement-android.sh \
#       --feature-dir ~/project/docs/specs \
#       --project-root ~/project \
#       --figma-url 'https://www.figma.com/design/abc123/MyApp' \
#       --figma-page 'Final' \
#       --start-from B
#
#     # Minimal — only implement + build + commit (fastest)
#     ./implement-android.sh \
#       --feature-dir ~/project/docs/specs \
#       --project-root ~/project \
#       --minimal --start-from B
#
#     # Dry run — show plan without executing
#     ./implement-android.sh \
#       --feature-dir ~/project/docs/specs \
#       --project-root ~/project \
#       --dry-run
#
# SEE ALSO
#   scripts/uat/capture-figma-refs.sh    — Figma REST API screenshot exporter
#   scripts/dispatch-cli-agent.sh        — CLI agent dispatch with 4-tier extraction
#   scripts/dispatch-test-augmenter.sh   — Dual-model test gap analysis
#   agents/*.md                          — Agent definitions with baked-in skills
#   config/profile-definitions.yaml      — Domain mapping, vertical agent rules
#
set -euo pipefail

# ── Derived paths ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
FEATURE_DIR=""
PROJECT_ROOT=""
MODEL="claude-sonnet-4-20250514"
MAX_TURNS=""
TIMEOUT=2700            # 45 min per implementation step
REVIEW_TIMEOUT=180      # 3 min per CLI reviewer
AUTO_COMMIT=true
DRY_RUN=false
START_FROM=""
STOP_AFTER=""
PERMISSION_MODE="auto"
MCP_CONFIG=""           # additional MCP config file (passed to claude -p)
VERTICAL_AGENT=""       # vertical agent type (auto-detect if empty)
FIGMA_FILE_KEY=""       # Figma file key for design handoff + screenshot export
FIGMA_URL=""            # Figma file URL (alternative to --figma-key)
FIGMA_FILE_NAME=""      # Figma file name (resolved via figma_list_open_files MCP)
FIGMA_PAGE=""           # Figma page to export from (default: all)
FIGMA_REFS_DIR=""       # directory for Figma reference screenshots (derived)
DO_REVIEW=true
DO_AUGMENT=true
DO_UAT=true
DO_SIMPLIFY=true
DO_SETUP=true              # project setup (hooks, CLAUDE.md, CLI instruction files)

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: implement-android.sh --feature-dir DIR --project-root DIR [options]

Required:
  --feature-dir DIR       Directory containing tasks.md, plan.md, etc.
  --project-root DIR      Android project root (where gradlew lives)

Options:
  --model MODEL           Claude model (default: claude-sonnet-4-20250514)
  --vertical-agent TYPE   Developer agent (auto-detect from project files if omitted)
                          Values: android-developer, frontend-developer, backend-developer, developer
  --max-turns N           Max conversation turns per phase
  --timeout SECONDS       Max time per phase (default: 2700 = 45min)
  --start-from PHASE_ID   Start from phase (e.g., "B", "C")
  --stop-after PHASE_ID   Stop after phase (e.g., "B")
  --no-commit             Don't auto-commit after each phase
  --bypass-permissions    Use bypassPermissions instead of auto mode
  --mcp-config FILE       Additional MCP config JSON (passed to claude -p)
  --figma-url URL         Figma file URL (key extracted automatically)
  --figma-key KEY         Figma file key directly (alternative to --figma-url)
  --figma-file NAME       Figma file name (resolved via figma_list_open_files MCP)
  --figma-page PAGE       Figma page to export from (default: all)
  --no-uat                Disable UAT mobile testing
  --no-review             Disable multi-model review (native + Codex/Gemini)
  --no-augment            Disable test augmentation + gap implementation
  --no-simplify           Disable code simplification after implementation
  --no-setup              Skip project setup (hooks, CLAUDE.md, CLI instruction files)
  --minimal               Disable all optional steps (only implement + build + commit)
  --dry-run               Show plan without executing
  -h, --help              Show this help

Pipeline per phase (all steps enabled by default):
  0. Figma handoff  Extract design specs + download reference PNGs (if --figma-url/key/file)
  1. Implement (TDD) test-writer → vertical-agent → output-verifier
     → build check
  2. Simplify        code-simplifier agent, fix-or-rollback
     → build check
  3. UAT             uat-tester → debugger + regression tests (UI phases)
     → build check
  4. Quality gate:
     a. Augment      Gemini→Codex gap analysis + implement gaps + verify
     b. Native review 3 parallel developer agents
     c. CLI review   Codex/Gemini specialized reviewers
     d. Fix          Auto-fix Critical/High from all sources
     → build check
  5. Commit          git commit with changelog

Feature dir expected files:
  tasks.md (required), plan.md (required)
  design.md, test-plan.md, test-cases/ (used for implementation context)
  HANDOFF-SUPPLEMENT.md, design-supplement.md (integrated into Figma handoff)
EOF
  exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature-dir)   FEATURE_DIR="$2"; shift 2 ;;
    --project-root)  PROJECT_ROOT="$2"; shift 2 ;;
    --model)         MODEL="$2"; shift 2 ;;
    --max-turns)     MAX_TURNS="$2"; shift 2 ;;
    --timeout)       TIMEOUT="$2"; shift 2 ;;
    --start-from)    START_FROM="$2"; shift 2 ;;
    --stop-after)    STOP_AFTER="$2"; shift 2 ;;
    --no-commit)     AUTO_COMMIT=false; shift ;;
    --bypass-permissions) PERMISSION_MODE="bypassPermissions"; shift ;;
    --vertical-agent) VERTICAL_AGENT="$2"; shift 2 ;;
    --mcp-config)    MCP_CONFIG="$2"; shift 2 ;;
    --figma-url)     FIGMA_URL="$2"; shift 2 ;;
    --figma-key)     FIGMA_FILE_KEY="$2"; shift 2 ;;
    --figma-file)    FIGMA_FILE_NAME="$2"; shift 2 ;;
    --figma-page)    FIGMA_PAGE="$2"; shift 2 ;;
    --no-uat)        DO_UAT=false; shift ;;
    --no-review)     DO_REVIEW=false; shift ;;
    --no-augment)    DO_AUGMENT=false; shift ;;
    --no-simplify)   DO_SIMPLIFY=false; shift ;;
    --no-setup)      DO_SETUP=false; shift ;;
    --minimal)       DO_UAT=false; DO_REVIEW=false; DO_AUGMENT=false; DO_SIMPLIFY=false; shift ;;
    --dry-run)       DRY_RUN=true; shift ;;
    -h|--help)       usage ;;
    *)               echo "Error: Unknown option: $1"; usage ;;
  esac
done

[[ -z "$FEATURE_DIR" ]]  && { echo "Error: --feature-dir is required"; usage; }
[[ -z "$PROJECT_ROOT" ]] && { echo "Error: --project-root is required"; usage; }
FEATURE_DIR="$(cd "$FEATURE_DIR" && pwd)"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

# ── Validate inputs ──────────────────────────────────────────────────────────
TASKS_FILE="$FEATURE_DIR/tasks.md"
[[ -f "$TASKS_FILE" ]]           || { echo "Error: $TASKS_FILE not found"; exit 1; }
[[ -f "$PROJECT_ROOT/gradlew" ]] || { echo "Error: gradlew not found in $PROJECT_ROOT"; exit 1; }
command -v claude &>/dev/null    || { echo "Error: claude CLI not found"; exit 1; }

LOG_DIR="$FEATURE_DIR/.implement-logs"
mkdir -p "$LOG_DIR"

# ── Environment probes ───────────────────────────────────────────────────────
CODEX_AVAILABLE=false; GEMINI_AVAILABLE=false
command -v codex  &>/dev/null && CODEX_AVAILABLE=true
command -v gemini &>/dev/null && GEMINI_AVAILABLE=true

MOBILE_MCP_AVAILABLE=false
if $DO_UAT; then
  if command -v adb &>/dev/null && adb devices 2>/dev/null | grep -q "emulator"; then
    MOBILE_MCP_AVAILABLE=true
  else
    echo "Warning: No emulator detected (adb). UAT mobile testing disabled."
    DO_UAT=false
  fi
fi

if $DO_REVIEW && ! $CODEX_AVAILABLE && ! $GEMINI_AVAILABLE; then
  echo "Warning: No CLI reviewers found (codex/gemini). CLI review portion disabled."
fi

if $DO_AUGMENT && ! $GEMINI_AVAILABLE; then
  echo "Warning: Gemini CLI not found. Test augmentation disabled."
  DO_AUGMENT=false
fi

# MCP server visibility
probe_mcp() {
  local found=false
  # Check project-level settings
  local project_settings="$PROJECT_ROOT/.claude/settings.json"
  if [[ -f "$project_settings" ]]; then
    local mcp_out
    mcp_out=$(python3 -c "
import json
with open('$project_settings') as f:
    s = json.load(f)
for name in s.get('mcpServers', {}):
    print(f'    - {name}')
" 2>/dev/null) || true
    echo "  MCP (project): ${mcp_out:-(none)}"
    found=true
  fi
  # Check user-level settings
  local user_settings="$HOME/.claude/settings.json"
  if [[ -f "$user_settings" ]]; then
    local mcp_out
    mcp_out=$(python3 -c "
import json
with open('$user_settings') as f:
    s = json.load(f)
for name in s.get('mcpServers', {}):
    print(f'    - {name}')
" 2>/dev/null) || true
    echo "  MCP (user): ${mcp_out:-(none)}"
    found=true
  fi
  $found || echo "  MCP: no settings found"
  if [[ -n "$MCP_CONFIG" ]]; then echo "  MCP extra: $MCP_CONFIG"; fi
}

# ── CLI instruction file management ────────────────────────────────────────
# Manages AGENTS.md (Codex) and GEMINI.md (Gemini) at PROJECT_ROOT with
# marker-based idempotent lifecycle. Content from config/cli_clients/shared/.
SHARED_CLI_SOURCE="$PLUGIN_ROOT/config/cli_clients/shared"

# Idempotent create/append/update of a managed section in a target file.
# Content outside markers is always preserved.
manage_cli_file() {
  local target="$1" marker_prefix="$2" shared_file="$3" extra_file="$4"
  local begin="<!-- ${marker_prefix}-begin -->"
  local end="<!-- ${marker_prefix}-end -->"

  # Build managed content
  local managed
  managed=$(printf '%s\n## CLI Agent Standards (managed by product-implementation)\n\n%s\n\n%s\n%s' \
    "$begin" \
    "$(cat "$shared_file" 2>/dev/null)" \
    "$(cat "$extra_file" 2>/dev/null)" \
    "$end")

  if [[ ! -f "$target" ]]; then
    echo "$managed" > "$target"
    echo "created"
  elif ! grep -q "$begin" "$target"; then
    printf '\n%s\n' "$managed" >> "$target"
    echo "appended"
  else
    # Compare existing managed section
    local existing
    existing=$(sed -n "/^${begin}$/,/^${end}$/p" "$target")
    if [[ "$existing" == "$managed" ]]; then
      echo "unchanged"
    else
      # Replace managed section in-place, preserve everything else
      local tmp
      tmp=$(mktemp)
      awk -v b="$begin" -v e="$end" -v new="$managed" '
        $0 == b { print new; skip=1; next }
        $0 == e && skip { skip=0; next }
        !skip { print }
      ' "$target" > "$tmp"
      mv "$tmp" "$target"
      echo "updated"
    fi
  fi
}

setup_cli_instructions() {
  if $CODEX_AVAILABLE; then
    local status
    status=$(manage_cli_file \
      "$PROJECT_ROOT/AGENTS.md" "pi-codex" \
      "$SHARED_CLI_SOURCE/cli-instruction-shared.md" \
      "$SHARED_CLI_SOURCE/codex-instruction-extra.md")
    echo "  AGENTS.md: $status"
  fi
  if $GEMINI_AVAILABLE; then
    local status
    status=$(manage_cli_file \
      "$PROJECT_ROOT/GEMINI.md" "pi-gemini" \
      "$SHARED_CLI_SOURCE/cli-instruction-shared.md" \
      "$SHARED_CLI_SOURCE/gemini-instruction-extra.md")
    echo "  GEMINI.md: $status"
  fi
}

# ── Project setup (hooks, CLAUDE.md) ───────────────────────────────────────
# One-time project analysis + Claude Code configuration. Skipped on re-runs.
SETUP_MARKER="$LOG_DIR/.project-setup-done"

run_project_setup() {
  # Skip if already done
  if [[ -f "$SETUP_MARKER" ]]; then
    echo "  ○ Project setup: already done"
    return 0
  fi

  echo "  ▶ Project setup: analyzing project and configuring Claude Code..."

  # Extract tech context from plan.md if available
  local tech_context="(no plan.md found)"
  if [[ -f "$FEATURE_DIR/plan.md" ]]; then
    tech_context=$(head -100 "$FEATURE_DIR/plan.md" | grep -iE 'tech|stack|architecture|framework|language|kotlin|compose|react|database' | head -10)
    tech_context="${tech_context:-(no tech context found in plan.md)}"
  fi

  local setup_prompt
  setup_prompt="You are configuring a project for optimal Claude Code usage before implementation begins.

PROJECT: ${PROJECT_ROOT}

## Tech Context (from plan.md)
${tech_context}

## Step 1: Analyze
Scan the project to understand:
- Build system (look for gradlew, package.json, Cargo.toml, etc.)
- Languages and frameworks (scan src/ directories)
- Existing test infrastructure (JUnit, Jest, Pytest, etc.)
- Existing Claude config: CLAUDE.md, .claude/settings.json, .claude/hooks/

## Step 2: Generate hooks
Create the following hooks in \`${PROJECT_ROOT}/.claude/hooks/\` ONLY if they don't already exist.
Each hook must use \`#!/usr/bin/env bash\`, \`set -euo pipefail\`, and include a jq availability check.

### protect-specs.sh (PreToolUse — Edit, Write)
Block edits to planning artifacts: spec.md, design.md, plan.md, test-plan.md, tasks.md, test-cases/.
Read tool input from stdin as JSON, extract file_path with jq, check against protected list. Exit 2 to block.

### tdd-reminder.sh (PreToolUse — Edit, Write)
When editing a source file (not test), check if a corresponding test file exists. If not, print a reminder
to write tests first. Do NOT block (exit 0), just warn.

### safe-bash.sh (PreToolUse — Bash)
Block dangerous commands: rm -rf /, git push --force, DROP TABLE, git reset --hard.
Read command from stdin JSON, check against blocklist patterns. Exit 2 to block.

## Step 3: Register hooks
Read \`${PROJECT_ROOT}/.claude/settings.json\` (create if missing).
For each new hook script, add an entry to the appropriate event array (PreToolUse, PostToolUse).
Preserve ALL existing entries. Create a backup at \`${PROJECT_ROOT}/.claude/settings.json.bak\` first.

Hook registration format:
\`\`\`json
{
  \"hooks\": {
    \"PreToolUse\": [
      {
        \"matcher\": \"Edit|Write\",
        \"command\": \".claude/hooks/protect-specs.sh\"
      }
    ]
  }
}
\`\`\`

## Step 4: Augment CLAUDE.md
If \`${PROJECT_ROOT}/CLAUDE.md\` exists, append missing sections wrapped in markers:
\`\`\`
<!-- BEGIN: implement-setup -->
## Build & Test Commands
[detected build/test commands]

## Architecture
[from plan.md]

## Conventions
[detected from existing code patterns]
<!-- END: implement-setup -->
\`\`\`
Skip sections that already exist. If CLAUDE.md doesn't exist, create it with these sections.

## Rules
- APPEND-ONLY: never overwrite existing content (hooks, CLAUDE.md, settings.json)
- Skip hooks that already exist in .claude/hooks/
- Backup settings.json before modifying
- Validate settings.json parses as JSON after writing (restore backup if invalid)
- All hooks must be executable (chmod +x)"

  if invoke_claude "$setup_prompt" "$LOG_DIR/project-setup.log" 600; then
    touch "$SETUP_MARKER"
    echo "  ✓ Project setup complete"
  else
    echo "  ⚠ Project setup failed (continuing without)"
  fi
}

# ── Figma key resolution ────────────────────────────────────────────────────
# Extract file key from a Figma URL
# Supports: figma.com/file/<KEY>/..., figma.com/design/<KEY>/...
extract_figma_key_from_url() {
  local url="$1"
  echo "$url" | grep -oE 'figma\.com/(file|design)/[^/?]+' | head -1 | rev | cut -d/ -f1 | rev
}

# Resolve file key from file name via figma_list_open_files MCP
resolve_figma_key_from_name() {
  local file_name="$1"
  echo "  ▶ Resolving Figma file key for '$file_name' via MCP..."
  local resolve_prompt="Call figma_list_open_files to list all open Figma files.
Find the file whose name contains '${file_name}'.
Output ONLY the file key (the short alphanumeric ID from the URL path, e.g. 'abc123XyZ').
No explanation, no markdown, just the key string on a single line."
  local result
  result=$(timeout 90 claude -p --model claude-haiku-4-5-20251001 --max-turns 5 \
    --permission-mode "$PERMISSION_MODE" \
    ${MCP_CONFIG:+--mcp-config "$MCP_CONFIG"} \
    "$resolve_prompt" 2>/dev/null | tail -5 | grep -oE '[a-zA-Z0-9_-]{10,}' | head -1) || true
  echo "$result"
}

# ── Vertical agent detection ───────────────────────────────────────────────
# Auto-detect vertical agent from tasks.md + plan.md content
# Greps files directly to avoid issues with large content in echo pipes
detect_vertical_agent() {
  local files=("$TASKS_FILE")
  [[ -f "$FEATURE_DIR/plan.md" ]] && files+=("$FEATURE_DIR/plan.md")
  [[ -f "$FEATURE_DIR/design.md" ]] && files+=("$FEATURE_DIR/design.md")

  # Priority-ordered matching (mirrors profile-definitions.yaml vertical_agents)
  if grep -qliE 'AndroidManifest|\.kt|Kotlin|Composable|Compose|ViewModel|android|gradle' "${files[@]}" 2>/dev/null; then
    echo "android-developer"
  elif grep -qliE '\.tsx|\.jsx|\.vue|\.svelte|React|Next\.js|CSS|HTML' "${files[@]}" 2>/dev/null; then
    echo "frontend-developer"
  elif grep -qliE 'endpoint|route|controller|REST|GraphQL|database|schema|migration' "${files[@]}" 2>/dev/null; then
    echo "backend-developer"
  else
    echo "developer"
  fi
}

# ── Resolve Figma file key ──────────────────────────────────────────────────
# Priority: --figma-key > --figma-url > --figma-file (MCP resolution)
if [[ -z "$FIGMA_FILE_KEY" ]] && [[ -n "$FIGMA_URL" ]]; then
  FIGMA_FILE_KEY=$(extract_figma_key_from_url "$FIGMA_URL")
  if [[ -z "$FIGMA_FILE_KEY" ]]; then
    echo "Error: could not extract file key from URL: $FIGMA_URL"
    echo "  Expected format: https://www.figma.com/design/<KEY>/..."
    exit 1
  fi
  echo "  Figma key (from URL): $FIGMA_FILE_KEY"
fi
if [[ -z "$FIGMA_FILE_KEY" ]] && [[ -n "$FIGMA_FILE_NAME" ]]; then
  FIGMA_FILE_KEY=$(resolve_figma_key_from_name "$FIGMA_FILE_NAME")
  if [[ -z "$FIGMA_FILE_KEY" ]]; then
    echo "Error: could not resolve Figma file key for '$FIGMA_FILE_NAME'"
    echo "  Make sure the file is open in Figma Desktop and figma-console MCP is connected."
    exit 1
  fi
  echo "  Figma key (from name): $FIGMA_FILE_KEY"
fi

# Figma references setup
FIGMA_REFS_DIR="$FEATURE_DIR/.figma-references"
FIGMA_HANDOFF_AVAILABLE=false
if [[ -n "$FIGMA_FILE_KEY" ]]; then
  FIGMA_HANDOFF_AVAILABLE=true
  mkdir -p "$FIGMA_REFS_DIR"
fi

# ── Resolve vertical agent ─────────────────────────────────────────────────
if [[ -z "$VERTICAL_AGENT" ]]; then
  VERTICAL_AGENT=$(detect_vertical_agent)
  echo "  Vertical agent (auto-detected): $VERTICAL_AGENT"
else
  echo "  Vertical agent (override): $VERTICAL_AGENT"
fi

# Verify dev-skills availability (warn-only — agents degrade gracefully)
DEV_SKILLS_DIR="$PLUGIN_ROOT/../dev-skills/skills"
if [[ ! -d "$DEV_SKILLS_DIR" ]]; then
  echo "  Warning: dev-skills plugin not found — agents will work without domain skills"
fi

# ── Phase parsing ─────────────────────────────────────────────────────────────
parse_phases() {
  grep -n "^## Phase" "$TASKS_FILE" | while IFS=: read -r lineno rest; do
    phase_id=$(echo "$rest" | sed -n 's/.*Phase \([A-Za-z0-9]*\).*/\1/p')
    phase_name=$(echo "$rest" | sed 's/^## //')
    echo "${lineno}|${phase_id}|${phase_name}"
  done
}

extract_phase_tasks() {
  local start_line="$1" tasks_file="$2"
  local total_lines end_line
  total_lines=$(wc -l < "$tasks_file")
  end_line=$(tail -n +"$((start_line + 1))" "$tasks_file" | grep -n "^## Phase" | head -1 | cut -d: -f1 || true)
  [[ -n "$end_line" ]] && end_line=$((start_line + end_line - 1)) || end_line=$total_lines
  sed -n "${start_line},${end_line}p" "$tasks_file"
}

# ── Claude invocation helper ─────────────────────────────────────────────────
invoke_claude() {
  local prompt="$1" log_file="$2" step_timeout="${3:-$TIMEOUT}"
  local claude_args=(-p --model "$MODEL" --permission-mode "$PERMISSION_MODE")
  claude_args+=(--plugin-dir "$PLUGIN_ROOT")
  [[ -n "$MAX_TURNS" ]] && claude_args+=(--max-turns "$MAX_TURNS")
  [[ -n "$MCP_CONFIG" ]] && claude_args+=(--mcp-config "$MCP_CONFIG")

  timeout "$step_timeout" claude "${claude_args[@]}" "$prompt" > "$log_file" 2>&1
}

# ── Build verification helper ────────────────────────────────────────────────
# Runs build, attempts fix if broken. Returns 0 if green, 1 if still broken.
verify_build() {
  local phase_id="$1" phase_name="$2" step_label="$3"
  if (cd "$PROJECT_ROOT" && ./gradlew assembleDebug > /dev/null 2>&1); then
    echo "  ✓ Build green (after ${step_label})"
    return 0
  fi
  echo "  ⚠ Build broken after ${step_label} — attempting fix..."
  local fix_prompt
  fix_prompt=$(build_fix_prompt "$phase_name" "BUILD ERRORS after ${step_label}:
$(cd "$PROJECT_ROOT" && ./gradlew assembleDebug 2>&1 | tail -60)" "Build")
  if invoke_claude "$fix_prompt" "$LOG_DIR/phase-${phase_id}-fix-${step_label// /-}.log"; then
    if (cd "$PROJECT_ROOT" && ./gradlew assembleDebug > /dev/null 2>&1); then
      echo "  ✓ Build fixed (after ${step_label})"
      return 0
    fi
  fi
  echo "  ✗ Build still broken after ${step_label}. Continuing."
  return 1
}

# ── Prompt builders ───────────────────────────────────────────────────────────
build_implement_prompt() {
  local phase_name="$1" phase_tasks="$2" phase_id="$3"
  local handoff_file="$LOG_DIR/phase-${phase_id}-figma-handoff.md"

  # Build Figma context section if handoff exists
  local figma_section=""
  if [[ -f "$handoff_file" ]] && [[ -s "$handoff_file" ]]; then
    figma_section="
## Design Handoff (from Figma — use these exact values)
Read the full handoff: ${handoff_file}
It contains exact dp/sp values, color tokens, layout specs for every screen in this phase.
Do NOT call figma_get_component_for_development — the handoff already has everything."

    # Add reference screenshots if available
    local screen_ids ref_list=""
    screen_ids=$(extract_screen_ids "$phase_tasks")
    if [[ -n "$screen_ids" ]] && [[ -d "$FIGMA_REFS_DIR" ]]; then
      for sid in $screen_ids; do
        local png
        png=$(ls "$FIGMA_REFS_DIR"/${sid}*.png 2>/dev/null | head -1)
        if [[ -n "$png" ]]; then ref_list="${ref_list}
- ${sid}: ${png}"; fi
      done
      if [[ -n "$ref_list" ]]; then
        figma_section="${figma_section}

## Reference Screenshots (visual targets)
${ref_list}
Use the Read tool to view these PNGs when implementing UI. Match the visual layout exactly."
      fi
    fi
  fi

  # Discover available context files
  local context_files=""
  for doc in plan.md design.md test-plan.md HANDOFF-SUPPLEMENT.md design-supplement.md; do
    if [[ -f "$FEATURE_DIR/$doc" ]]; then
      context_files="${context_files}
- ${FEATURE_DIR}/${doc}"
    fi
  done
  # Test specifications
  local test_specs=""
  if [[ -d "$FEATURE_DIR/test-cases" ]]; then
    test_specs="
## Test Specifications
Read the relevant test specs from ${FEATURE_DIR}/test-cases/ before writing tests:
$(for subdir in unit integration e2e uat; do
    if [[ -d "$FEATURE_DIR/test-cases/$subdir" ]]; then
      echo "- ${subdir}/: $(ls "$FEATURE_DIR/test-cases/$subdir"/*.md 2>/dev/null | wc -l | tr -d ' ') spec files"
    fi
  done)
Match test IDs from the task specs (UT-*, E2E-*, INT-*, UAT-*) to the corresponding spec files."
  fi

  cat <<PROMPT
You are implementing ${phase_name} using strict TDD with subagent delegation.

PROJECT: ${PROJECT_ROOT}
${figma_section}
${test_specs}

## Tasks
${phase_tasks}

## TDD Process (for each task)

Follow this cycle for EVERY task:

### 1. RED — Write failing tests first
Dispatch a test-writer agent for unit tests (test IDs matching UT-*):
  Agent(subagent_type="product-implementation:test-writer", prompt="Write failing tests for [TASK_ID]. Test specs: ${FEATURE_DIR}/test-cases/. Project: ${PROJECT_ROOT}")

For E2E or integration tests (E2E-*, INT-*), dispatch integration-test-writer instead:
  Agent(subagent_type="product-implementation:integration-test-writer", prompt="Write failing integration tests for [TASK_ID]. Test specs: ${FEATURE_DIR}/test-cases/. Project: ${PROJECT_ROOT}")

### 2. GREEN — Implement until tests pass
Dispatch the vertical developer agent:
  Agent(subagent_type="product-implementation:${VERTICAL_AGENT}", prompt="Implement [TASK_ID]: [task description]. Make all failing tests pass. Design handoff: ${handoff_file}. Project: ${PROJECT_ROOT}")

The ${VERTICAL_AGENT} has FULL AUTONOMY — build, test, fix, iterate.
It uses domain skills baked into its agent .md file via progressive disclosure (read first 50 lines, grep on-demand).

### 3. VERIFY — Check output quality
Dispatch an output-verifier agent:
  Agent(subagent_type="product-implementation:output-verifier", prompt="Verify test quality for [TASK_ID] in ${PROJECT_ROOT}. Check for empty test bodies, tautological assertions, spec-test alignment.")

If verifier finds issues, re-dispatch the appropriate agent to fix them.

## Context files (read as needed)
${context_files}

## Rules
- Follow TDD strictly: tests FIRST, then implementation
- Run ./gradlew assembleDebug after each task
- Run ./gradlew test to verify tests
- Do NOT skip the test-writer step
- For UI tasks: use the design handoff values, not guesses
PROMPT
}

build_fix_prompt() {
  local phase_name="$1" error_context="$2" fix_type="$3"
  cat <<PROMPT
${fix_type} issues found after implementing ${phase_name}.

${error_context}

PROJECT: ${PROJECT_ROOT}

Dispatch the developer agent to fix:
  Agent(subagent_type="product-implementation:${VERTICAL_AGENT}", prompt="Fix these ${fix_type} issues. Run ./gradlew assembleDebug && ./gradlew test to verify. Project: ${PROJECT_ROOT}")

The ${VERTICAL_AGENT} has full autonomy — read files, diagnose, fix, iterate until resolved.
PROMPT
}

build_uat_prompt() {
  local phase_name="$1" phase_id="$2" phase_tasks="$3"
  local evidence_dir="$FEATURE_DIR/.uat-evidence/${phase_id}"
  local uat_specs_dir="$FEATURE_DIR/test-cases/uat"
  mkdir -p "$evidence_dir"

  cat <<PROMPT
You are performing UAT (User Acceptance Testing) after implementing ${phase_name}.

PROJECT: ${PROJECT_ROOT}
EVIDENCE DIR: ${evidence_dir}

## Setup
1. Install the app: cd ${PROJECT_ROOT} && ./gradlew installDebug
2. Verify emulator: use mobile_list_available_devices

## UAT Execution
Dispatch uat-tester:
  Agent(subagent_type="product-implementation:uat-tester", prompt="Execute UAT for ${phase_name}. Specs: ${uat_specs_dir}/. Evidence: ${evidence_dir}. Find package in AndroidManifest.xml. Test each scenario with SAV loop.")

## Phase context
${phase_tasks}

## On Failures
For EACH Critical/High finding:

1. Dispatch debugger to diagnose and fix:
   Agent(subagent_type="product-implementation:debugger", prompt="Bug: [description]. Steps: [steps]. Screenshot: [path]. Project: ${PROJECT_ROOT}. Fix it.")

2. Dispatch test-writer for regression test:
   Agent(subagent_type="product-implementation:test-writer", prompt="Write a regression test proving this bug is fixed: [description]. Test should PASS now. Project: ${PROJECT_ROOT}")

3. Verify: ./gradlew test && ./gradlew assembleDebug

After all fixes, re-install and re-run failed scenarios to confirm.
PROMPT
}

# ── Figma handoff ─────────────────────────────────────────────────────────────

# Extract screen IDs mentioned in phase tasks (ONB-01, WK-02, SET-03, JRN-01, etc.)
extract_screen_ids() {
  local phase_tasks="$1"
  echo "$phase_tasks" | grep -oE '(ONB|JRN|WK|SET|HIS|PRO|STAT)-[0-9]+[a-z0-9]*' | sort -u
}

# Download Figma reference screenshots for the whole file (runs once)
run_figma_screenshot_export() {
  if [[ -d "$FIGMA_REFS_DIR" ]] && [[ -n "$(ls -A "$FIGMA_REFS_DIR"/*.png 2>/dev/null)" ]]; then
    local existing_count
    existing_count=$(ls "$FIGMA_REFS_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')
    echo "  ○ Figma screenshots: $existing_count PNGs already exported"
    return 0
  fi

  echo "  ▶ Exporting Figma reference screenshots..."
  local capture_args=("$FIGMA_FILE_KEY" "$FIGMA_REFS_DIR" --scale 2)
  if [[ -n "$FIGMA_PAGE" ]]; then
    capture_args+=(--page "$FIGMA_PAGE")
  fi

  if "$PLUGIN_ROOT/scripts/uat/capture-figma-refs.sh" "${capture_args[@]}" 2>&1 | tail -5; then
    local count
    count=$(ls "$FIGMA_REFS_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')
    echo "  ✓ Exported $count Figma reference PNGs"
  else
    echo "  ⚠ Figma screenshot export failed (continuing without)"
  fi
}

# Generate design handoff document for a phase via figma-console MCP
run_figma_handoff() {
  local phase_id="$1" phase_name="$2" phase_tasks="$3"
  local handoff_file="$LOG_DIR/phase-${phase_id}-figma-handoff.md"

  # Skip if handoff already exists (resume scenario)
  if [[ -f "$handoff_file" ]] && [[ -s "$handoff_file" ]]; then
    echo "  ○ Figma handoff: reusing existing ($handoff_file)"
    return 0
  fi

  local screen_ids
  screen_ids=$(extract_screen_ids "$phase_tasks")
  if [[ -z "$screen_ids" ]]; then
    echo "  ○ Figma handoff: no screen IDs found in phase tasks"
    return 0
  fi

  local screen_count
  screen_count=$(echo "$screen_ids" | wc -l | tr -d ' ')
  echo "  ▶ Figma design handoff ($screen_count screens: $(echo "$screen_ids" | tr '\n' ' '))..."

  # Build list of reference PNGs for these screens
  local ref_screenshots=""
  if [[ -d "$FIGMA_REFS_DIR" ]]; then
    for sid in $screen_ids; do
      local png
      png=$(ls "$FIGMA_REFS_DIR"/${sid}*.png 2>/dev/null | head -1)
      if [[ -n "$png" ]]; then
        ref_screenshots="${ref_screenshots}
- ${sid}: ${png}"
      fi
    done
  fi

  # Discover supplementary docs in feature dir
  local supplement_section=""
  for doc in HANDOFF-SUPPLEMENT.md design-supplement.md design.md; do
    if [[ -f "$FEATURE_DIR/$doc" ]]; then
      supplement_section="${supplement_section}
- ${FEATURE_DIR}/${doc}"
    fi
  done

  local handoff_prompt
  handoff_prompt="You are a design handoff specialist. Extract complete implementation specs from Figma for the screens in this phase.

## Screens to extract
$(echo "$screen_ids" | sed 's/^/- /')

## Phase context
${phase_tasks}

## Supplementary documents (read for behavioral context relevant to the screens above)
${supplement_section:-  (none found)}
Extract from these files ONLY the sections relevant to the screens listed above — navigation flows, transitions, interaction logic, state descriptions, cross-screen patterns.

## Process

For EACH screen ID above:

1. Search for the component in Figma:
   - Call figma_search_components with the screen ID (e.g., 'ONB-01')
   - If not found, try partial match (e.g., 'ONB')

2. Extract full development spec:
   - Call figma_get_component_for_development with the nodeId found
   - This gives you: layout structure, dimensions, spacing, typography, colors, constraints

3. Extract design tokens:
   - Call figma_get_variables(format='filtered') for referenced token values

4. For complex components, get additional detail:
   - Call figma_get_component_details for variant properties
   - Call figma_execute if needed for text content extraction

## Reference screenshots available
${ref_screenshots:-None exported yet}

## Output format

Write a structured handoff document to: ${handoff_file}

For each screen, include:
- **Screen ID** and name
- **Layout**: frame dimensions, padding, gap, direction (column/row)
- **Typography**: font family, weight, size (sp), line height, color token
- **Colors**: background, foreground, accent — use token names where available
- **Spacing**: margins, padding, gaps in dp
- **Components**: buttons (height, corner radius, colors), inputs, images (aspect ratio, fill mode)
- **States**: variants, pressed/disabled/selected states
- **Behavioral notes**: navigation targets, transitions, interaction logic (from supplement docs)
- **Screenshot reference**: path to the reference PNG if available

Keep it factual and precise — dp values, sp values, hex colors, token names. No prose descriptions."

  if invoke_claude "$handoff_prompt" "$LOG_DIR/phase-${phase_id}-figma-handoff.log" 900; then
    if [[ -f "$handoff_file" ]] && [[ -s "$handoff_file" ]]; then
      echo "  ✓ Design handoff: $screen_count screens extracted"
    else
      echo "  ⚠ Handoff session completed but no output file produced"
    fi
  else
    echo "  ⚠ Figma handoff timed out or failed (continuing without)"
  fi
}

# ── Step functions ────────────────────────────────────────────────────────────

# Step 2: Code simplification
run_simplify() {
  local phase_id="$1" phase_name="$2"

  local modified_files
  modified_files=$(cd "$PROJECT_ROOT" && git diff --name-only HEAD 2>/dev/null | \
    grep -vE '(Test\.|test/|__tests__|\.md$|\.json$|\.yaml$|\.yml$)' || true)

  if [[ -z "$modified_files" ]]; then
    echo "  ○ Step 2: No source files to simplify"
    return 0
  fi

  local file_count
  file_count=$(echo "$modified_files" | wc -l | tr -d ' ')
  if [[ "$file_count" -gt 15 ]]; then
    echo "  ○ Step 2: Too many files ($file_count > 15) — skipping simplification"
    return 0
  fi

  echo "  ▶ Step 2: Code simplification ($file_count files)..."

  local prompt
  prompt="Simplify recently modified code in ${phase_name}.
PROJECT: ${PROJECT_ROOT}

Dispatch code-simplifier:
  Agent(subagent_type=\"product-implementation:code-simplifier\", prompt=\"Simplify these files for clarity and maintainability without changing behavior:
${modified_files}
Project: ${PROJECT_ROOT}
Run ./gradlew test after changes. If ANY test fails, revert ALL changes with git checkout.\")
"
  if invoke_claude "$prompt" "$LOG_DIR/phase-${phase_id}-simplify.log" 600; then
    # Verify tests still pass
    if (cd "$PROJECT_ROOT" && ./gradlew test > /dev/null 2>&1); then
      echo "  ✓ Code simplified (tests pass)"
    else
      echo "  ⚠ Tests broke after simplification — attempting fix..."
      local fix_prompt
      fix_prompt=$(build_fix_prompt "$phase_name" "Tests failed after code simplification. Fix the simplified code or tests to make them pass again.
FAILING TESTS:
$(cd "$PROJECT_ROOT" && ./gradlew test 2>&1 | tail -60)" "Simplification")
      if invoke_claude "$fix_prompt" "$LOG_DIR/phase-${phase_id}-fix-simplify.log" 600; then
        if (cd "$PROJECT_ROOT" && ./gradlew test > /dev/null 2>&1); then
          echo "  ✓ Simplification issues fixed"
        else
          echo "  ⚠ Fix failed — reverting simplification..."
          (cd "$PROJECT_ROOT" && git checkout -- .)
          echo "  ✓ Reverted to pre-simplification state"
        fi
      else
        echo "  ⚠ Fix timed out — reverting simplification..."
        (cd "$PROJECT_ROOT" && git checkout -- .)
        echo "  ✓ Reverted to pre-simplification state"
      fi
    fi
  else
    echo "  ⚠ Simplification timed out or failed"
  fi
}

# Step 3: UAT mobile testing
run_uat() {
  local phase_id="$1" phase_name="$2" phase_tasks="$3"
  echo "  ▶ Step 3: UAT mobile testing..."

  local uat_prompt
  uat_prompt=$(build_uat_prompt "$phase_name" "$phase_id" "$phase_tasks")
  echo "$uat_prompt" > "$LOG_DIR/phase-${phase_id}-uat-prompt.md"

  local start_time
  start_time=$(date +%s)
  if invoke_claude "$uat_prompt" "$LOG_DIR/phase-${phase_id}-uat.log"; then
    echo "  ✓ UAT completed ($(($(date +%s) - start_time))s)"
  else
    local ec=$?
    [[ $ec -eq 124 ]] && echo "  ⚠ UAT timed out" || echo "  ⚠ UAT exited ($ec)"
  fi

  # Build check after UAT fixes
  if ! (cd "$PROJECT_ROOT" && ./gradlew assembleDebug > /dev/null 2>&1); then
    echo "  ⚠ Build broken after UAT fixes — repairing..."
    local fix_prompt
    fix_prompt=$(build_fix_prompt "$phase_name" "Build errors after UAT fixes:
$(cd "$PROJECT_ROOT" && ./gradlew assembleDebug 2>&1 | tail -60)" "Build")
    invoke_claude "$fix_prompt" "$LOG_DIR/phase-${phase_id}-fix-uat.log"
  fi
}

# Step 4a: Test augmentation + implement gaps
run_augment() {
  local phase_id="$1" phase_name="$2"
  local phase_slug
  phase_slug=$(echo "$phase_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
  local context_file="$LOG_DIR/phase-${phase_id}-augment-context.md"

  echo "  ▶ Step 4a: Test augmentation (Gemini→Codex)..."

  {
    echo "# Phase: $phase_name"
    echo "## Project: $PROJECT_ROOT"
    echo ""
    echo "## Changed files"
    (cd "$PROJECT_ROOT" && git diff --name-only HEAD~1 2>/dev/null || echo "(first commit)")
    echo ""
    echo "## Existing test files"
    (cd "$PROJECT_ROOT" && find . -name "*Test.kt" -o -name "*Test.java" 2>/dev/null | head -50)
  } > "$context_file"

  local aug_exit=0
  "$PLUGIN_ROOT/scripts/dispatch-test-augmenter.sh" \
    --feature-dir "$FEATURE_DIR" \
    --plugin-root "$PLUGIN_ROOT" \
    --phase "$phase_name" \
    --context-file "$context_file" \
    --timeout "$REVIEW_TIMEOUT" \
    || aug_exit=$?

  case $aug_exit in
    0)  echo "  ✓ Augmentation: gaps found" ;;
    10) echo "  ○ No actionable test gaps"; return 0 ;;
    *)  echo "  ⚠ Augmentation failed (exit $aug_exit)"; return 0 ;;
  esac

  # Implement discovered gaps
  local gap_file="$FEATURE_DIR/.test-augmentation-${phase_slug}.md"
  if [[ -f "$gap_file" ]] && [[ -s "$gap_file" ]]; then
    echo "  ▶ Implementing test gaps..."
    local impl_prompt
    impl_prompt="Test augmentation found gaps. Write the missing tests and make them pass.
PROJECT: ${PROJECT_ROOT}

## Discovered Gaps
$(cat "$gap_file")

## Process
1. Dispatch test-writer for each gap:
   Agent(subagent_type=\"product-implementation:test-writer\", prompt=\"Write tests for these gaps: [gap descriptions]. Project: ${PROJECT_ROOT}\")

2. Run ./gradlew test to verify ALL tests pass.

3. If new tests FAIL because they expose real bugs, dispatch the developer to fix the code:
   Agent(subagent_type=\"product-implementation:${VERTICAL_AGENT}\", prompt=\"Tests are failing — fix the production code to make them pass. Project: ${PROJECT_ROOT}\")

4. If new tests fail because they are incorrect, fix the tests.

5. Repeat until ./gradlew test passes."

    if invoke_claude "$impl_prompt" "$LOG_DIR/phase-${phase_id}-augment-impl.log" 600; then
      if (cd "$PROJECT_ROOT" && ./gradlew test > /dev/null 2>&1); then
        echo "  ✓ Test gaps implemented (tests pass)"
      else
        echo "  ⚠ Some augmented tests still failing — attempting fix..."
        local fix_prompt
        fix_prompt=$(build_fix_prompt "$phase_name" "Tests failing after test augmentation:
$(cd "$PROJECT_ROOT" && ./gradlew test 2>&1 | tail -60)" "Test augmentation")
        invoke_claude "$fix_prompt" "$LOG_DIR/phase-${phase_id}-fix-augment.log" 600 \
          && echo "  ✓ Augmentation issues fixed" \
          || echo "  ⚠ Some augmented tests may still be failing"
      fi
    else
      echo "  ⚠ Gap implementation failed"
    fi
  fi
}

# Step 4b: Native code review (3 parallel developer agents)
run_native_review() {
  local phase_id="$1" phase_name="$2"
  local findings_file="$LOG_DIR/phase-${phase_id}-native-review-findings.md"

  echo "  ▶ Step 4b: Native code review (3 perspectives)..."

  local modified_files
  modified_files=$(cd "$PROJECT_ROOT" && git diff --name-only HEAD~1 2>/dev/null || echo "(no diff available)")

  local review_prompt
  review_prompt="Review code changes from ${phase_name} with 3 independent perspectives.
PROJECT: ${PROJECT_ROOT}

Changed files:
${modified_files}

Launch 3 parallel review agents:

1. Agent(subagent_type=\"product-implementation:developer\", prompt=\"Review for **Simplicity / DRY / Elegance**: duplicated code, unnecessary complexity, dead code, unclear naming. Read each changed file. Project: ${PROJECT_ROOT}. Changed files: ${modified_files}\")

2. Agent(subagent_type=\"product-implementation:developer\", prompt=\"Review for **Bugs / Functional Correctness**: logic errors, edge cases, race conditions, null handling, off-by-one errors. Read each changed file. Project: ${PROJECT_ROOT}. Changed files: ${modified_files}\")

3. Agent(subagent_type=\"product-implementation:developer\", prompt=\"Review for **Project Conventions / Abstractions**: pattern violations, inconsistent style, wrong abstractions, convention drift. Read CLAUDE.md first, then each changed file. Project: ${PROJECT_ROOT}. Changed files: ${modified_files}\")

Consolidate findings. Write consolidated review to: ${findings_file}
Classify each finding: Critical / High / Medium / Low with file:line references."

  if invoke_claude "$review_prompt" "$LOG_DIR/phase-${phase_id}-native-review.log" 900; then
    echo "  ✓ Native review complete"
  else
    echo "  ⚠ Native review timed out or failed"
  fi
}

# Step 4c: CLI multi-model review
build_cli_review_prompt() {
  local cli="$1" role="$2" phase_name="$3"
  local role_file="$PLUGIN_ROOT/config/cli_clients/${cli}_${role}.txt"
  local shared_file="$PLUGIN_ROOT/config/cli_clients/shared/severity-output-conventions.md"
  [[ -f "$role_file" ]] || { echo "# Role prompt not found: $role_file"; return 1; }

  cat "$role_file"
  [[ -f "$shared_file" ]] && cat "$shared_file"
  local extra="$PLUGIN_ROOT/config/cli_clients/shared/${cli}-instruction-extra.md"
  [[ -f "$extra" ]] && cat "$extra"

  cat <<CTX

## Coordinator-Injected Context
- Phase: ${phase_name}
- Project: ${PROJECT_ROOT}
- Changed files:
$(cd "$PROJECT_ROOT" && git diff --name-only HEAD~1 2>/dev/null || echo "(no previous commit)")
CTX
}

dispatch_reviewer() {
  local cli="$1" role="$2" phase_id="$3" phase_name="$4"
  local prompt_file="$LOG_DIR/phase-${phase_id}-${role}-prompt.txt"
  local output_file="$LOG_DIR/phase-${phase_id}-${role}-output.json"

  build_cli_review_prompt "$cli" "$role" "$phase_name" > "$prompt_file" || return 1
  echo "    ▸ ${cli}:${role}..."
  "$PLUGIN_ROOT/scripts/dispatch-cli-agent.sh" \
    --cli "$cli" --role "$role" \
    --prompt-file "$prompt_file" --output-file "$output_file" \
    --timeout "$REVIEW_TIMEOUT" \
    && echo "    ✓ ${cli}:${role}" \
    || echo "    ⚠ ${cli}:${role} failed"
}

phase_has_ui() { echo "$1" | grep -qiE 'Compose|Screen|UI|Layout|onboarding|carousel|button|dialog|theme|navigation'; }
phase_has_api() { echo "$1" | grep -qiE 'API|network|database|Room|DataStore|repository|endpoint|retrofit|ktor'; }

run_cli_review() {
  local phase_id="$1" phase_name="$2" phase_tasks="$3"
  echo "  ▶ Step 4c: CLI multi-model review..."

  # Core reviewers
  $CODEX_AVAILABLE  && dispatch_reviewer codex correctness_reviewer "$phase_id" "$phase_name"
  $GEMINI_AVAILABLE && dispatch_reviewer gemini android_domain_reviewer "$phase_id" "$phase_name"
  $GEMINI_AVAILABLE && dispatch_reviewer gemini spec_validator "$phase_id" "$phase_name"

  # Conditional
  $CODEX_AVAILABLE && phase_has_ui "$phase_tasks"  && dispatch_reviewer codex ux_reviewer "$phase_id" "$phase_name"
  $CODEX_AVAILABLE && phase_has_api "$phase_tasks" && dispatch_reviewer codex security_reviewer "$phase_id" "$phase_name"

  echo "  ✓ CLI review complete"
}

# Step 4d: Consolidate findings + fix
run_quality_fix() {
  local phase_id="$1" phase_name="$2" phase_tasks="$3"
  local all_findings="$LOG_DIR/phase-${phase_id}-all-findings.md"
  > "$all_findings"

  # Collect all finding sources
  echo "# Review Findings: ${phase_name}" >> "$all_findings"
  echo "" >> "$all_findings"

  # Native review findings
  local native_file="$LOG_DIR/phase-${phase_id}-native-review-findings.md"
  if [[ -f "$native_file" ]] && [[ -s "$native_file" ]]; then
    echo "## Native Review" >> "$all_findings"
    cat "$native_file" >> "$all_findings"
    echo "" >> "$all_findings"
  fi

  # CLI review findings
  for output in "$LOG_DIR"/phase-"${phase_id}"-*-output.json; do
    [[ -f "$output" ]] || continue
    local role
    role=$(basename "$output" | sed "s/phase-${phase_id}-//; s/-output.json//")
    echo "## CLI Review: ${role}" >> "$all_findings"
    cat "$output" >> "$all_findings"
    echo "" >> "$all_findings"
  done

  # Pattern propagation if Critical/High found
  if $GEMINI_AVAILABLE && grep -qiE 'Critical|High' "$all_findings" 2>/dev/null; then
    echo "    ▸ Critical/High detected — pattern propagation..."
    dispatch_reviewer gemini codebase_pattern_reviewer "$phase_id" "$phase_name"
  fi

  # Count severity
  local critical_count
  critical_count=$(grep -ciE '^.*Critical\|^.*High' "$all_findings" 2>/dev/null || echo 0)

  # Save findings to feature dir for user visibility
  cp "$all_findings" "$FEATURE_DIR/.review-findings-phase-${phase_id}.md" 2>/dev/null || true

  if [[ "$critical_count" -gt 0 ]]; then
    echo "  ▶ Step 4d: Fixing $critical_count Critical/High findings..."
    local fix_prompt
    fix_prompt=$(build_fix_prompt "$phase_name" "CONSOLIDATED REVIEW FINDINGS:
$(cat "$all_findings")" "Review")

    if invoke_claude "$fix_prompt" "$LOG_DIR/phase-${phase_id}-fix-review.log"; then
      echo "  ✓ Review fixes applied"
    else
      echo "  ⚠ Fix attempt completed with issues"
    fi
  else
    echo "  ✓ No Critical/High findings to fix"
  fi
}

# ── Execute phase ─────────────────────────────────────────────────────────────
run_phase() {
  local phase_id="$1" phase_name="$2" phase_tasks="$3"
  local phase_log="$LOG_DIR/phase-${phase_id}.log"
  local prompt_file="$LOG_DIR/phase-${phase_id}-prompt.md"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ${phase_name}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # ── Extract task summary for changelog ──────────────────────────────────────
  # Pull task IDs and one-line descriptions from phase_tasks
  local task_summary
  task_summary=$(echo "$phase_tasks" | grep -oE '\[T[0-9]+\].*' | \
    sed 's/\[T\([0-9]*\)\] \(\[.*\] \)\{0,1\}/T\1: /' | \
    sed 's/ — `.*//' | head -20)

  if $DRY_RUN; then
    local prompt
    prompt=$(build_implement_prompt "$phase_name" "$phase_tasks" "$phase_id")
    echo "$prompt" > "$prompt_file"
    echo "[DRY RUN] Prompt: $prompt_file ($(echo "$prompt" | wc -c | tr -d ' ') bytes)"
    local steps=""
    $FIGMA_HANDOFF_AVAILABLE && steps="figma-handoff → "
    steps="${steps}implement → build"
    $DO_SIMPLIFY && steps="$steps → simplify → build"
    $DO_UAT && phase_has_ui "$phase_tasks" && steps="$steps → UAT → build"
    $DO_AUGMENT && steps="$steps → augment → build"
    $DO_REVIEW && steps="$steps → native-review → cli-review → fix → build"
    echo "[DRY RUN] Pipeline: $steps → commit"
    local screen_ids
    screen_ids=$(extract_screen_ids "$phase_tasks")
    if [[ -n "$screen_ids" ]]; then
      echo "[DRY RUN] Screens: $(echo "$screen_ids" | tr '\n' ' ')"
    fi
    return 0
  fi

  # ── Figma design handoff (before implementation) ────────────────────────────
  if $FIGMA_HANDOFF_AVAILABLE; then
    run_figma_handoff "$phase_id" "$phase_name" "$phase_tasks"
  fi

  local prompt
  prompt=$(build_implement_prompt "$phase_name" "$phase_tasks" "$phase_id")
  echo "$prompt" > "$prompt_file"

  # ── Step 1: Implement (TDD) ───────────────────────────────────────────────
  echo "  ▶ Step 1: TDD Implementation (model=$MODEL, timeout=${TIMEOUT}s)..."
  local start_time
  start_time=$(date +%s)
  if invoke_claude "$prompt" "$phase_log"; then
    echo "  ✓ Implementation ($(($(date +%s) - start_time))s)"
  else
    local ec=$?
    [[ $ec -eq 124 ]] && echo "  ⚠ Timed out (${TIMEOUT}s)" || echo "  ⚠ Exit $ec ($(($(date +%s) - start_time))s)"
  fi

  # ── Build check after implementation ─────────────────────────────────────
  verify_build "$phase_id" "$phase_name" "implementation" || true

  # ── Step 2: Code simplification ────────────────────────────────────────────
  if $DO_SIMPLIFY; then
    run_simplify "$phase_id" "$phase_name"
    verify_build "$phase_id" "$phase_name" "simplification" || true
  fi

  # ── Step 3: UAT (UI phases only) ──────────────────────────────────────────
  if $DO_UAT && phase_has_ui "$phase_tasks"; then
    run_uat "$phase_id" "$phase_name" "$phase_tasks"
    verify_build "$phase_id" "$phase_name" "UAT fixes" || true
  elif $DO_UAT; then
    echo "  ○ Step 3: UAT skipped (no UI tasks in this phase)"
  fi

  # ── Step 4: Quality gate ───────────────────────────────────────────────────
  if $DO_AUGMENT || $DO_REVIEW; then
    echo "  ▶ Step 4: Quality gate..."

    if $DO_AUGMENT; then
      run_augment "$phase_id" "$phase_name"
      verify_build "$phase_id" "$phase_name" "test augmentation" || true
    fi

    if $DO_REVIEW; then
      run_native_review "$phase_id" "$phase_name"
      if $CODEX_AVAILABLE || $GEMINI_AVAILABLE; then
        run_cli_review "$phase_id" "$phase_name" "$phase_tasks"
      fi
    fi

    if $DO_REVIEW || $DO_AUGMENT; then
      run_quality_fix "$phase_id" "$phase_name" "$phase_tasks"
      verify_build "$phase_id" "$phase_name" "quality fixes" || true
    fi
  fi

  # ── Commit ─────────────────────────────────────────────────────────────────
  if $AUTO_COMMIT; then
    if (cd "$PROJECT_ROOT" && ! git diff --quiet HEAD 2>/dev/null) || \
       [[ -n "$(cd "$PROJECT_ROOT" && git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
      echo "  ▶ Committing..."

      # Build changelog from actual task content + pipeline steps
      local steps_done="TDD"
      $DO_SIMPLIFY && steps_done="$steps_done, simplification"
      $DO_UAT && phase_has_ui "$phase_tasks" && steps_done="$steps_done, UAT"
      $DO_AUGMENT && steps_done="$steps_done, test augmentation"
      $DO_REVIEW && steps_done="$steps_done, code review"

      local commit_msg
      commit_msg="$(cat <<COMMIT_EOF
feat: implement ${phase_name}

Tasks:
${task_summary}

Pipeline: ${steps_done}

Files changed:
$(cd "$PROJECT_ROOT" && git diff --stat HEAD 2>/dev/null || echo "(new files)")
COMMIT_EOF
)"

      (cd "$PROJECT_ROOT" && git add -A && git commit -m "$commit_msg")
      echo "  ✓ Committed"
    else
      echo "  ○ No changes to commit"
    fi
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
echo "implement-android.sh"
echo "  Feature dir:  $FEATURE_DIR"
echo "  Project root: $PROJECT_ROOT"
echo "  Model:        $MODEL"
echo "  Agent:        $VERTICAL_AGENT"
echo "  Timeout:      ${TIMEOUT}s per phase"
echo "  Auto-commit:  $AUTO_COMMIT"
echo "  Simplify:     $DO_SIMPLIFY"
echo "  UAT:          $DO_UAT"
echo "  Augment:      $DO_AUGMENT"
echo "  Review:       $DO_REVIEW"
echo "  Setup:        $DO_SETUP"
echo "  Figma:        ${FIGMA_FILE_KEY:-(none)}"
probe_mcp
echo ""

# ── CLI instruction files (AGENTS.md / GEMINI.md) ────────────────────────────
if $DO_SETUP && ! $DRY_RUN; then
  if $CODEX_AVAILABLE || $GEMINI_AVAILABLE; then
    echo "Setting up CLI instruction files..."
    setup_cli_instructions
    echo ""
  fi
fi

# ── Project setup (hooks, CLAUDE.md, settings.json) ──────────────────────────
if $DO_SETUP && ! $DRY_RUN; then
  run_project_setup
  echo ""
fi

# ── Figma reference screenshots (one-time export) ────────────────────────────
if $FIGMA_HANDOFF_AVAILABLE && ! $DRY_RUN; then
  run_figma_screenshot_export
fi

# Parse phases (bash 3.x compatible)
phase_entries=()
while IFS= read -r line; do
  phase_entries+=("$line")
done < <(parse_phases)

[[ ${#phase_entries[@]} -eq 0 ]] && { echo "Error: No phases found in $TASKS_FILE"; exit 1; }

echo "Found ${#phase_entries[@]} phases:"
skip_mode=true
[[ -z "$START_FROM" ]] && skip_mode=false

phases_to_run=()
for entry in "${phase_entries[@]}"; do
  IFS='|' read -r lineno phase_id phase_name <<< "$entry"
  if $skip_mode; then
    if [[ "$(echo "$phase_id" | tr '[:lower:]' '[:upper:]')" == "$(echo "$START_FROM" | tr '[:lower:]' '[:upper:]')" ]]; then
      skip_mode=false
    else
      echo "  ○ ${phase_name} (skipped)"
      continue
    fi
  fi
  echo "  ▸ ${phase_name}"
  phases_to_run+=("$entry")
  # Stop collecting after the specified phase
  if [[ -n "$STOP_AFTER" ]] && [[ "$(echo "$phase_id" | tr '[:lower:]' '[:upper:]')" == "$(echo "$STOP_AFTER" | tr '[:lower:]' '[:upper:]')" ]]; then
    break
  fi
done

[[ ${#phases_to_run[@]} -eq 0 ]] && { echo "No phases to run. Check --start-from."; exit 0; }

echo ""
echo "Starting ${#phases_to_run[@]} phase(s)..."

completed=0
for entry in "${phases_to_run[@]}"; do
  IFS='|' read -r lineno phase_id phase_name <<< "$entry"
  phase_tasks=$(extract_phase_tasks "$lineno" "$TASKS_FILE")
  run_phase "$phase_id" "$phase_name" "$phase_tasks"
  ((completed++))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Done: ${completed}/${#phases_to_run[@]} phases"
echo "  Logs:     $LOG_DIR"
echo "  Findings: $FEATURE_DIR/.review-findings-phase-*.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
