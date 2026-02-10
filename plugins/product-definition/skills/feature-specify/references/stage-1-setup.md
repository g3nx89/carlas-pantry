---
stage: stage-1-setup
artifacts_written:
  - specs/{FEATURE_DIR}/.specify-state.local.md
  - specs/{FEATURE_DIR}/.specify.lock
  - specs/{FEATURE_DIR}/.stage-summaries/stage-1-summary.md
  - specs/{FEATURE_DIR}/figma_context.md (conditional)
---

# Stage 1: Setup & Figma (Inline)

> This stage runs inline in the orchestrator — no coordinator dispatch.

## CRITICAL RULES (must follow — failure-prevention)

1. **Pre-flight validation MUST pass**: If ANY required agent, skill, or template is MISSING, ABORT immediately.
2. **Lock staleness threshold**: Only remove locks older than `limits.lock_staleness_hours` (default: 2 hours). NEVER remove fresh locks without user confirmation.
3. **User decisions are IMMUTABLE**: If resuming, NEVER re-ask decisions recorded in `user_decisions`.
4. **Figma is optional**: Never block the workflow if Figma is unavailable or user declines.
5. **Feature ID uniqueness**: Always check existing branches and specs before assigning a number.

## Step 1.1: MCP Availability Check

Before proceeding, check which MCP tools are available:

```
CHECK PAL tools:
- Try invoking mcp__pal__thinkdeep or mcp__pal__consensus probe
- If fails: PAL_AVAILABLE = false

CHECK Sequential Thinking:
- Try invoking mcp__sequential-thinking__sequentialthinking with a simple thought
- If fails: ST_AVAILABLE = false

CHECK Figma MCP:
- Check if mcp__figma-desktop__get_screenshot is available -> FIGMA_MCP_AVAILABLE = true/false
- Also check mcp__figma__get_screenshot as fallback
```

**If PAL_AVAILABLE = false:**
- Notify user: "PAL tools unavailable. ThinkDeep and Consensus steps will be skipped."

**If ST_AVAILABLE = false:**
- Notify user: "Sequential Thinking unavailable. Using internal reasoning."

## Step 1.2: Pre-flight Validation (MUST PASS)

Validate all required components exist:

```bash
# Check required agents
test -f "$CLAUDE_PLUGIN_ROOT/agents/business-analyst.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/agents/design-brief-generator.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/agents/gap-analyzer.md" || echo "MISSING"

# Check required skills
test -f "$CLAUDE_PLUGIN_ROOT/skills/specify-figma-capture/SKILL.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/skills/specify-clarification/SKILL.md" || echo "MISSING"

# Check required templates
TEMPLATE_COUNT=$(ls "$CLAUDE_PLUGIN_ROOT/templates/prompts/"*.md 2>/dev/null | wc -l)
test $TEMPLATE_COUNT -ge 6 || echo "MISSING: Prompt templates (need 6+, found $TEMPLATE_COUNT)"
```

**Validation Gate:** IF ANY component marked MISSING: ABORT with message listing required files.

## Step 1.3: Lock Detection

```bash
find specs/ -name ".specify.lock" -type f 2>/dev/null
```

**If lock file found:**
1. Read lock file content (timestamp and info)
2. Calculate lock age

**If lock age > `limits.lock_staleness_hours` (default: 2h):**
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
Check schema_version — if v2, migrate per `recovery-migration.md`.

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
      {"label": "Re-run PAL Gate", "description": "Re-run multi-model consensus validation"},
      {"label": "Start Fresh", "description": "Discard all progress and begin new specification"}
    ]
  }]
}
```

**Case C: Completed state exists**
Use AskUserQuestion with options: Re-run Clarifications, Re-run PAL, View Status, Start New Feature.

**Case D: No arguments AND no state exists**
Inform: "No feature description provided and no existing workflow found."
EXIT

**Case E: User provided feature description AND matching state exists**
Ask: Resume Existing or Create New Workflow.

## Step 1.5: Build Resume Context (If Required)

**If WORKFLOW_MODE = NEW**: `RESUME_CONTEXT = ""` (empty)

**If WORKFLOW_MODE in {RESUME, RERUN_CLARIFY, RERUN_PAL}**:
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
Delegate to `specify-figma-capture` sub-skill via Skill tool.

Pass context:
- `FEATURE_DIR`
- `ARGUMENTS` (for flag detection)

**Returns:**
- `FIGMA_ENABLED`: true/false
- `FIGMA_CONTEXT_FILE`: path or null
- `SCREENS_CAPTURED`: count

## Step 1.10: Initialize/Update State (CHECKPOINT)

Create state file from template or update existing:

```yaml
schema_version: 3
feature_id: "{NUMBER}-{SHORT_NAME}"
feature_name: "{FEATURE_NAME}"
user_input: "{USER_INPUT}"
created: "{ISO_TIMESTAMP}"
updated: "{ISO_TIMESTAMP}"
current_stage: 1
stage_status: "completed"
mcp_availability:
  pal_available: {true|false}
  st_available: {true|false}
  figma_mcp_available: {true|false}
user_decisions:
  figma_enabled: {true|false}
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
summary: "Initialized workspace for {FEATURE_NAME}. Figma: {enabled|disabled}."
flags:
  pal_available: {true|false}
  st_available: {true|false}
  figma_mcp_available: {true|false}
  figma_enabled: {true|false}
  figma_screens: {N|0}
  workflow_mode: "{NEW|RESUME}"
---
```

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. `specs/{FEATURE_DIR}/.specify-state.local.md` exists with `schema_version: 3`
2. `specs/{FEATURE_DIR}/.specify.lock` exists with timestamp
3. All workspace directories created (`analysis/`, `.stage-summaries/`)
4. If Figma enabled: `figma_context.md` exists in feature directory
5. Summary YAML frontmatter has no placeholder values

## CRITICAL RULES REMINDER

- Pre-flight validation MUST pass before proceeding
- Lock staleness threshold from config — never remove fresh locks without confirmation
- Resumed user decisions are IMMUTABLE
- Figma is optional — never block the workflow
