---
stage: stage-1-setup
artifacts_written:
  - specs/{FEATURE_DIR}/.specify-state.local.md
  - specs/{FEATURE_DIR}/.specify.lock
  - specs/{FEATURE_DIR}/.stage-summaries/stage-1-summary.md
  - specs/{FEATURE_DIR}/figma_context.md (conditional)
  - specs/{FEATURE_DIR}/REQUIREMENTS-INVENTORY.md (conditional)
---

# Stage 1: Setup & Figma (Inline)

> This stage runs inline in the orchestrator — no coordinator dispatch.

## CRITICAL RULES (must follow — failure-prevention)

1. **Pre-flight validation MUST pass**: If ANY required agent, skill, or template is MISSING, ABORT immediately.
2. **Lock staleness threshold**: Only remove locks older than 60 minutes. NEVER remove fresh locks without user confirmation.
3. **User decisions are IMMUTABLE**: If resuming, NEVER re-ask decisions recorded in `user_decisions`.
4. **Figma is optional**: Never block the workflow if Figma is unavailable or user declines.
5. **Feature ID uniqueness**: Always check existing branches and specs before assigning a number.

## Step 1.1: CLI & MCP Availability Check

Before proceeding, check which tools are available:

```
CHECK ntm (Named Tmux Manager):
- command -v ntm → NTM_AVAILABLE = true/false
- If NTM_AVAILABLE: probe each CLI binary:
    command -v codex  → CODEX_AVAILABLE = true/false
    command -v gemini → GEMINI_AVAILABLE = true/false
  CLI_AVAILABLE = true if ntm AND at least one CLI binary is found
  (Both codex + gemini required for evaluation; 1+ for analysis steps)

CHECK Sequential Thinking:
- Try invoking mcp__sequential-thinking__sequentialthinking with a simple thought
- If fails: ST_AVAILABLE = false

CHECK Figma MCP:
- Check if mcp__figma-desktop__get_screenshot is available -> FIGMA_MCP_AVAILABLE = true/false
- Also check mcp__figma__get_screenshot as fallback
```

**If CLI_AVAILABLE = false:**
- Notify user: "CLI dispatch unavailable. Challenge, EdgeCase, Triangulation, and Evaluation steps will be skipped. Install ntm (`brew install dicklesworthstone/tap/ntm`) plus codex and gemini CLIs to enable multi-model analysis."

**If ST_AVAILABLE = false:**
- Notify user: "Sequential Thinking unavailable. Using internal reasoning."

## Step 1.2: Pre-flight Validation (MUST PASS)

Validate all required components exist:

```bash
# Check required agents
test -f "$CLAUDE_PLUGIN_ROOT/agents/business-analyst.md" || echo "MISSING: business-analyst"
test -f "$CLAUDE_PLUGIN_ROOT/agents/design-brief-generator.md" || echo "MISSING: design-brief-generator"
test -f "$CLAUDE_PLUGIN_ROOT/agents/gap-analyzer.md" || echo "MISSING: gap-analyzer"
test -f "$CLAUDE_PLUGIN_ROOT/agents/qa-strategist.md" || echo "MISSING: qa-strategist"
test -f "$CLAUDE_PLUGIN_ROOT/agents/gate-judge.md" || echo "MISSING: gate-judge"

# Check required reference protocols
test -f "$CLAUDE_PLUGIN_ROOT/skills/specify/references/figma-capture-protocol.md" || echo "MISSING: figma-capture-protocol"
test -f "$CLAUDE_PLUGIN_ROOT/skills/specify/references/clarification-protocol.md" || echo "MISSING: clarification-protocol"

# Check required config
test -f "$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml" || echo "MISSING: specify-config.yaml"
test -f "$CLAUDE_PLUGIN_ROOT/config/specify-profile-definitions.yaml" || echo "MISSING: specify-profile-definitions.yaml"

# Check required templates
TEMPLATE_COUNT=$(ls "$CLAUDE_PLUGIN_ROOT/templates/prompts/"*.md 2>/dev/null | wc -l)
test $TEMPLATE_COUNT -ge 6 || echo "MISSING: Prompt templates (need 6+, found $TEMPLATE_COUNT)"
```

**Validation Gate:** IF ANY component marked MISSING: ABORT with message listing required files.

## Step 1.2b: Profile Selection

Read `profile` from `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml`.
Load profile definitions from `@$CLAUDE_PLUGIN_ROOT/config/specify-profile-definitions.yaml`.

**If `profile` is set** (not null): Use the specified profile. Validate it exists in profile definitions.

**If `profile` is null** (default): Ask user interactively:
```json
{
  "questions": [{
    "question": "Select a quality profile for this specification:",
    "header": "Profile",
    "multiSelect": false,
    "options": [
      {"label": "Standard (Recommended)", "description": "Balanced quality with CLI analysis. All features enabled."},
      {"label": "Rapid", "description": "Fast drafting. No CLI dispatch, no gates, no test strategy, no retrospective."},
      {"label": "Thorough", "description": "Maximum rigor. Higher coverage targets, more iterations, 1.5x CLI timeouts."}
    ]
  }]
}
```

**Resolve profile → feature flags and thresholds:**

Read the selected profile from `profiles.{profile_name}` in profile definitions. Set the following variables:

```
PROFILE = "{rapid|standard|thorough}"
INCREMENTAL_GATES_ENABLED = profiles.{PROFILE}.features.incremental_gates
CLI_CHALLENGE_ENABLED = profiles.{PROFILE}.features.cli_challenge AND CLI_AVAILABLE
CLI_EDGE_CASES_ENABLED = profiles.{PROFILE}.features.cli_edge_cases AND CLI_AVAILABLE
CLI_TRIANGULATION_ENABLED = profiles.{PROFILE}.features.cli_triangulation AND CLI_AVAILABLE
CLI_EVALUATION_ENABLED = profiles.{PROFILE}.features.cli_evaluation AND CLI_AVAILABLE
TEST_STRATEGY_ENABLED = profiles.{PROFILE}.features.test_strategy
RTM_ENABLED = profiles.{PROFILE}.features.rtm_tracking
RETROSPECTIVE_ENABLED = profiles.{PROFILE}.features.retrospective
COVERAGE_TARGET = profiles.{PROFILE}.thresholds.coverage_target
MAX_ITERATIONS = profiles.{PROFILE}.thresholds.max_iterations
CLI_TIMEOUT_MULTIPLIER = profiles.{PROFILE}.cli_timeout_multiplier
```

Record: `user_decisions.profile: "{PROFILE}"`

## Step 1.3: Lock Detection

```bash
find specs/ -name ".specify.lock" -type f 2>/dev/null
```

**If lock file found:**
1. Read lock file content (timestamp and info)
2. Calculate lock age

**If lock age > 60 minutes (hardcoded stale threshold):**
Remove lock file, continue.

**If lock age <= threshold:**
Use AskUserQuestion directly (Stage 1 runs inline):
```json
{
  "questions": [{
    "question": "A specification session is in progress for '{FEATURE_NAME}' (locked {MINUTES} min ago). How to proceed?",
    "header": "Lock Found",
    "multiSelect": false,
    "options": [
      {"label": "Resume from last checkpoint (Recommended)", "description": "Continue from where the previous session left off"},
      {"label": "View current state", "description": "Display specification status without changes"},
      {"label": "Force restart", "description": "Remove progress and start fresh. WARNING: Unsaved work lost"},
      {"label": "Exit", "description": "Exit without any changes"}
    ]
  }]
}
```

Handle response:
- "Resume": WORKFLOW_MODE = RESUME
- "View": Display status, EXIT
- "Force restart": Remove lock AND state file, WORKFLOW_MODE = NEW
- "Exit": EXIT immediately

## Step 1.4: State Detection & Workflow Mode

```bash
find specs/ -name ".specify-state.local.md" -type f 2>/dev/null
```

**If state files found:**
Parse YAML frontmatter, determine current_stage and stage_status.
Check schema_version — if < 6, migrate per `recovery-migration.md` (chained: v2→v3→v4→v5→v6).

**Case A: User provided feature description AND no matching state exists**
WORKFLOW_MODE = NEW, proceed to Step 1.6

**Case B: State exists with incomplete workflow**
Use AskUserQuestion:
```json
{
  "questions": [{
    "question": "Found incomplete specification for '{FEATURE_NAME}' (at Stage {N}). How to proceed?",
    "header": "Resume",
    "multiSelect": false,
    "options": [
      {"label": "Resume (Recommended)", "description": "Continue from Stage {N}: {NEXT_STEP}"},
      {"label": "Re-run Clarifications", "description": "Gather additional clarifications"},
      {"label": "Re-run CLI Validation", "description": "Re-run multi-model consensus validation"},
      {"label": "Start Fresh", "description": "Discard all progress and begin new specification"}
    ]
  }]
}
```

**Case C: Completed state exists**
Use AskUserQuestion with options: Re-run Clarifications, Re-run CLI Validation, View Status, Start New Feature.

**Case D: No arguments AND no state exists**
Inform: "No feature description provided and no existing workflow found."
EXIT

**Case E: User provided feature description AND matching state exists**
Ask: Resume Existing or Create New Workflow.

## Step 1.5: Build Resume Context (If Required)

**If WORKFLOW_MODE = NEW**: `RESUME_CONTEXT = ""` (empty)

**If WORKFLOW_MODE in {RESUME, RERUN_CLARIFY, RERUN_CLI_VALIDATION}**:
1. Read STATE_FILE YAML frontmatter
2. Load template: `@$CLAUDE_PLUGIN_ROOT/templates/prompts/resume-context-builder.md`
3. Populate with state data
4. Set `RESUME_CONTEXT` variable for coordinator prompts

## Step 1.6: Generate Feature ID

Extract 2-4 word short name from feature description:
- Use action-noun format (e.g., `add-user-auth`, `fix-payment-bug`)
- Preserve technical terms/acronyms

```bash
git fetch --all --prune 2>/dev/null
# Find highest feature number across remote branches, local branches, and specs/
# Use N+1, or 1 if none found
```

## Step 1.7: Create Feature Directory

```bash
mkdir -p "specs/{NUMBER}-{SHORT_NAME}"
mkdir -p "specs/{NUMBER}-{SHORT_NAME}/analysis"
mkdir -p "specs/{NUMBER}-{SHORT_NAME}/.stage-summaries"
cp "$CLAUDE_PLUGIN_ROOT/templates/spec-template.md" "specs/{NUMBER}-{SHORT_NAME}/spec.md"
```

Set variables:
- `FEATURE_DIR` = `{NUMBER}-{SHORT_NAME}`
- `SPEC_FILE` = `specs/{FEATURE_DIR}/spec.md`
- `STATE_FILE` = `specs/{FEATURE_DIR}/.specify-state.local.md`
- `LOCK_FILE` = `specs/{FEATURE_DIR}/.specify.lock`

## Step 1.8: Create Lock File

```bash
echo "locked_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
feature: {FEATURE_NAME}
stage: INIT" > "{LOCK_FILE}"
```

## Step 1.9: Figma Capture (Optional)

Check for explicit flags in `$ARGUMENTS`:
- `--figma` present → Proceed with Figma capture
- `--no-figma` present → Skip entire Figma step
- Neither → Ask user interactively

**If interactive:**
```json
{
  "questions": [{
    "question": "Would you like to capture Figma designs for this feature?",
    "header": "Figma",
    "multiSelect": false,
    "options": [
      {"label": "Yes, capture Figma designs", "description": "Capture screens from Figma to inform specification"},
      {"label": "No, skip Figma", "description": "Proceed without design context"}
    ]
  }]
}
```

**If Figma enabled:**
Read and execute `@$CLAUDE_PLUGIN_ROOT/skills/specify/references/figma-capture-protocol.md`.

Context available:
- `FEATURE_DIR`
- `ARGUMENTS` (for flag detection)

**Returns:**
- `FIGMA_ENABLED`: true/false
- `FIGMA_CONTEXT_FILE`: path or null
- `SCREENS_CAPTURED`: count

## Step 1.9b: Load Handoff Supplement (Optional)

Check for design-handoff output from the previous workflow step:

```bash
# Primary: feature-scoped supplement
test -f "design-handoff/HANDOFF-SUPPLEMENT.md" && echo "FOUND"
# Also check: briefs directory
ls design-handoff/figma-screen-briefs/FSB-*.md 2>/dev/null | wc -l
```

**If `HANDOFF-SUPPLEMENT.md` found:**
1. Set `HANDOFF_SUPPLEMENT_PATH = "design-handoff/HANDOFF-SUPPLEMENT.md"`
2. Set `HANDOFF_SUPPLEMENT_AVAILABLE = true`
3. Read the file — extract:
   - Screen inventory (from `## Screen Reference Table` or manifest)
   - Cross-screen patterns (from `## Cross-Screen Patterns`)
   - Figma briefs index (from `## Figma Screen Briefs` if present) → `EXISTING_BRIEFS[]`
4. Notify user: "Found design-handoff supplement ({N} screens). Spec will reference Figma for visual design."

**If NOT found:**
- Set `HANDOFF_SUPPLEMENT_AVAILABLE = false`
- Notify user: "No design-handoff supplement found. Run `/product-definition:design-handoff` first for Figma-backed specs (recommended). Proceeding without."
- Continue normally — supplement is recommended but not blocking.

**Set variable `HANDOFF_CONTEXT`:**
```
IF HANDOFF_SUPPLEMENT_AVAILABLE:
    HANDOFF_CONTEXT = "HANDOFF-SUPPLEMENT.md available. Figma is the visual source of truth.
    Use screen names and node IDs from the Screen Reference Table when writing Figma references in US."
ELSE:
    HANDOFF_CONTEXT = "No handoff supplement. Specify Figma references as [Frame: ScreenName] placeholders."
```

This variable is injected into the BA agent dispatch context in Stage 2.

## Step 1.9c: Requirements Inventory Extraction (Optional)

**Check:** `RTM_ENABLED` (from profile, Step 1.2b) AND `WORKFLOW_MODE == NEW`

**If disabled OR WORKFLOW_MODE != NEW:** Skip. Set `RTM_ENABLED = false`.

**If enabled:**

1. Parse `user_input` to extract discrete requirements. Look for:
   - Imperative sentences ("Users must be able to...", "The system shall...")
   - Must/should/shall clauses
   - Bullet points describing capabilities
   - Performance/quality constraints ("search results in <2s", "GDPR compliant")
   - Each distinct capability or constraint = one REQ entry

   **Minimum threshold:** If fewer than 2 requirements are extracted, notify user:
   "Only {N} requirement(s) extracted — RTM tracking works best with 2+ discrete requirements.
   Consider adding more detail to your input, or skip RTM tracking."
   Still allow the user to proceed with RTM if they choose (the threshold is advisory, not blocking).

2. Load template: `@$CLAUDE_PLUGIN_ROOT/templates/requirements-inventory-template.md`

3. Assign REQ IDs sequentially: REQ-001, REQ-002, etc.

4. Categorize each: Functional, NFR, or Constraint

5. Write to `specs/{FEATURE_DIR}/REQUIREMENTS-INVENTORY.md`

6. Present to user via AskUserQuestion:
```json
{
  "questions": [{
    "question": "I've extracted {N} requirements from your input and written them to REQUIREMENTS-INVENTORY.md. Review the file, then select how to proceed.",
    "header": "RTM",
    "multiSelect": false,
    "options": [
      {"label": "Continue (Recommended)", "description": "Requirements inventory looks good — proceed with RTM tracking"},
      {"label": "I've edited the inventory", "description": "I've added/removed/changed requirements in the file — re-read it"},
      {"label": "Skip RTM tracking", "description": "Proceed without requirements traceability"}
    ]
  }]
}
```

7. Handle response:
   - **"Continue"**: Set `RTM_ENABLED = true`. Read file, store confirmed count.
   - **"I've edited the inventory"**: Re-read `REQUIREMENTS-INVENTORY.md`, update count, set `RTM_ENABLED = true`.
   - **"Skip RTM tracking"**: Set `RTM_ENABLED = false`. All subsequent RTM steps become no-ops.

8. If `RTM_ENABLED = true`:
   - Update inventory file frontmatter: set `confirmed: true`, update `requirements_count`
   - Record `user_decisions.rtm_enabled: true`

9. If `RTM_ENABLED = false`:
   - Record `user_decisions.rtm_enabled: false`

## Step 1.10: Initialize/Update State (CHECKPOINT)

Create state file from template or update existing:

```yaml
schema_version: 6
feature_id: "{NUMBER}-{SHORT_NAME}"
feature_name: "{FEATURE_NAME}"
user_input: "{USER_INPUT}"
profile: "{rapid|standard|thorough}"
created: "{ISO_TIMESTAMP}"
updated: "{ISO_TIMESTAMP}"
current_stage: 1
stage_status: "completed"
rtm_enabled: {true|false|null}
requirements_inventory:
  file_path: "{specs/{FEATURE_DIR}/REQUIREMENTS-INVENTORY.md | null}"
  count: {N|0}
  confirmed: {true|false}
mcp_availability:
  ntm_available: {true|false}
  cli_available: {true|false}
  codex_available: {true|false}
  gemini_available: {true|false}
  st_available: {true|false}
  figma_mcp_available: {true|false}
handoff_supplement:
  available: {true|false}
  path: "{design-handoff/HANDOFF-SUPPLEMENT.md | null}"
  existing_briefs_count: {N}
user_decisions:
  profile: "{rapid|standard|thorough}"
  figma_enabled: {true|false}
  rtm_enabled: {true|false}
```

## Summary Contract

Write to `specs/{FEATURE_DIR}/.stage-summaries/stage-1-summary.md`:

```yaml
---
stage: "setup-figma"
stage_number: 1
status: completed
checkpoint: INIT
artifacts_written:
  - specs/{FEATURE_DIR}/.specify-state.local.md
  - specs/{FEATURE_DIR}/.specify.lock
summary: "Initialized workspace for {FEATURE_NAME}. Profile: {PROFILE}. Figma: {enabled|disabled}. RTM: {enabled|disabled}."
flags:
  profile: "{rapid|standard|thorough}"
  ntm_available: {true|false}
  cli_available: {true|false}
  codex_available: {true|false}
  gemini_available: {true|false}
  st_available: {true|false}
  figma_mcp_available: {true|false}
  figma_enabled: {true|false}
  figma_screens: {N|0}
  handoff_supplement_available: {true|false}
  existing_briefs_count: {N|0}
  rtm_enabled: {true|false}
  requirements_inventory_count: {N|0}
  workflow_mode: "{NEW|RESUME}"
  # Resolved feature flags (from profile + MCP availability)
  incremental_gates_enabled: {true|false}
  cli_challenge_enabled: {true|false}
  cli_edge_cases_enabled: {true|false}
  cli_triangulation_enabled: {true|false}
  cli_evaluation_enabled: {true|false}
  test_strategy_enabled: {true|false}
  retrospective_enabled: {true|false}
  coverage_target: {85|90}
  max_iterations: {5|10|15}
  cli_timeout_multiplier: {1.0|1.5}
---
```

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. `specs/{FEATURE_DIR}/.specify-state.local.md` exists with `schema_version: 6`
2. `specs/{FEATURE_DIR}/.specify.lock` exists with timestamp
3. All workspace directories created (`analysis/`, `.stage-summaries/`)
4. If Figma enabled: `figma_context.md` exists in feature directory
5. If RTM enabled: `REQUIREMENTS-INVENTORY.md` exists with confirmed requirements
6. Summary YAML frontmatter has no placeholder values

