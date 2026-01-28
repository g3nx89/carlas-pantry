# Phase 1: Initialization

> **Source:** Extracted from `/product-definition:requirements` main orchestration

**Checkpoint:** `INITIALIZATION`

**Goal:** Validate environment, check locks, detect existing state, and determine workflow mode.

## Step 1.0: MCP Availability Check (Graceful Degradation)

Before proceeding, check which MCP tools are available:

```
CHECK PAL tools:
- Try invoking mcp__pal__listmodels
- If fails: PAL_AVAILABLE = false

CHECK Sequential Thinking:
- Try invoking mcp__sequential-thinking__sequentialthinking with a simple thought
- If fails: ST_AVAILABLE = false
```

**If PAL_AVAILABLE = false:**
- Notify user: "PAL tools unavailable. Analysis modes limited to Standard and Rapid."
- Limit mode selection in Phase 3

**If ST_AVAILABLE = false:**
- Notify user: "Sequential Thinking unavailable. Using internal reasoning (may be less structured)."
- Use internal reasoning instead of ST calls

## Step 1.1: Pre-flight Validation (MUST PASS)

Validate all required components exist:

```bash
# Check required agents (relative to plugin root)
AGENT_CHECK=""
test -f "$CLAUDE_PLUGIN_ROOT/agents/requirements-product-strategy.md" && AGENT_CHECK+="requirements-product-strategy.md\n" || AGENT_CHECK+="MISSING: requirements-product-strategy.md\n"
test -f "$CLAUDE_PLUGIN_ROOT/agents/requirements-user-experience.md" && AGENT_CHECK+="requirements-user-experience.md\n" || AGENT_CHECK+="MISSING: requirements-user-experience.md\n"
test -f "$CLAUDE_PLUGIN_ROOT/agents/requirements-business-ops.md" && AGENT_CHECK+="requirements-business-ops.md\n" || AGENT_CHECK+="MISSING: requirements-business-ops.md\n"
test -f "$CLAUDE_PLUGIN_ROOT/agents/requirements-question-synthesis.md" && AGENT_CHECK+="requirements-question-synthesis.md\n" || AGENT_CHECK+="MISSING: requirements-question-synthesis.md\n"
test -f "$CLAUDE_PLUGIN_ROOT/agents/requirements-prd-generator.md" && AGENT_CHECK+="requirements-prd-generator.md\n" || AGENT_CHECK+="MISSING: requirements-prd-generator.md\n"
echo -e "$AGENT_CHECK"

# Check config
test -f "$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml" && echo "requirements-config.yaml" || echo "MISSING: requirements-config.yaml"
```

**Validation Gate:**
IF ANY component marked `MISSING`:
ABORT with message listing required files
EXIT

ELSE: Continue to Step 1.2

---

## Step 1.2: Check for Lock Files

```bash
find requirements/ -name ".requirements-lock" -type f 2>/dev/null
```

**If lock file found:**

1. Read lock file content (timestamp and info)
2. Calculate lock age

**If lock age > 2 hours (stale):**
Log: "Removing stale lock (age: {HOURS}h)"
Remove lock file
Continue to Step 1.3

**If lock age <= 2 hours (active):**
Use `AskUserQuestion`:

```json
{
  "questions": [{
    "question": "A requirements session is in progress (locked {MINUTES} min ago). How to proceed?",
    "header": "Lock Found",
    "multiSelect": false,
    "options": [
      {"label": "Resume from last checkpoint (Recommended)", "description": "Continue from where the previous session left off"},
      {"label": "View current state", "description": "Display current PRD status without changes"},
      {"label": "Force restart", "description": "Remove progress and start fresh. WARNING: Unsaved work lost"},
      {"label": "Exit", "description": "Exit without any changes"}
    ]
  }]
}
```

Handle response:
- "Resume": `WORKFLOW_MODE = RESUME`
- "View": Display status, exit
- "Force restart": Remove lock AND state file, `WORKFLOW_MODE = NEW`
- "Exit": EXIT immediately

---

## Step 1.3: Check for Existing PRD.md

```bash
test -f requirements/PRD.md && echo "PRD_EXISTS=true" || echo "PRD_EXISTS=false"
```

**If PRD.md exists:**
`PRD_MODE = "EXTEND"`
Parse PRD.md sections, identify completeness status per section

**If PRD.md does NOT exist:**
`PRD_MODE = "NEW"`

---

## Step 1.4: Check for State Files

```bash
test -f requirements/.requirements-state.local.md && echo "STATE_EXISTS=true" || echo "STATE_EXISTS=false"
```

**If state file found:**

1. Parse YAML frontmatter
2. Determine `current_phase` and `phase_status`

---

## Step 1.5: Determine Workflow Mode

**Case A: User provided draft filename AND no state exists**
`WORKFLOW_MODE = NEW`, proceed to Phase 2

**Case B: State exists with `waiting_for_user: true`**
Check for filled QUESTIONS file
Resume to appropriate phase

**Case C: PRD.md exists AND no state exists**
Use `AskUserQuestion`:

```json
{
  "questions": [{
    "question": "PRD.md found. Analysis shows:\n\n| Section | Status |\n|---------|--------|\n| Product Definition | COMPLETE |\n| Target Users | PARTIAL |\n| Problem Analysis | PLACEHOLDER |\n\nHow to proceed?",
    "header": "PRD Found",
    "multiSelect": false,
    "options": [
      {"label": "Extend incomplete sections (Recommended)", "description": "Generate questions only for gaps"},
      {"label": "Regenerate entire PRD", "description": "Start fresh, discard existing PRD"},
      {"label": "Review specific sections", "description": "Choose which sections to extend"}
    ]
  }]
}
```

**Case D: No arguments AND no state AND no PRD**
Inform user:
```
No draft provided and no existing workflow found.

To start:
1. Copy the template: cp $CLAUDE_PLUGIN_ROOT/templates/draft-template.md requirements/draft/{product-name}-draft.md
2. Fill in at least PART 1 (Essential) - takes ~5 minutes
3. Run: /product-definition:requirements {product-name}-draft.md

Template structure:
- PART 1 (Required): Vision, Problem, Target Users (~5 min)
- PART 2 (Recommended): Is/Is Not, Value Prop, Unknowns (~10 min)
- PART 3 (Optional): Workflows, Features, Screens, Business (~15 min)
```
EXIT

---

## Step 1.6: Validate Draft Input

If `WORKFLOW_MODE = NEW` and draft provided:

```bash
test -f "requirements/draft/$ARGUMENTS" && echo "DRAFT_VALID=true" || echo "DRAFT_VALID=false"
```

**If draft not found:**
List available drafts in `requirements/draft/`
Ask user to select or provide correct filename
