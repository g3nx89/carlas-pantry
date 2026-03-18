---
stage: stage-1-routing
artifacts_written:
  - (none -- routing only; artifacts written by stage-1-init.md)
---

# Stage 1 Routing: MCP Check, Pre-flight, Lock, State Detection

> Always loaded when Stage 1 runs inline. Determines WORKFLOW_MODE then hands off
> to `stage-1-init.md` for workspace creation, mode selection, and panel composition.
>
> **Delegation note:** Stage 1 is the only stage that uses AskUserQuestion directly (per Rule 22).

## Critical Rules

1. **Pre-flight validation**: If any required agent or config file is missing, abort. Do not proceed with partial setup.
2. **Lock staleness threshold**: Only remove locks older than `state.lock_staleness_hours` (default: 2 hours). Never remove fresh locks without user confirmation.
3. **User decisions are immutable**: If resuming, never re-ask mode selection recorded in `user_decisions`.

## Step 1.1: MCP Availability Check

Check which MCP tools are available:

```
CHECK PAL tools:
- Try invoking mcp__pal__listmodels
- If fails: PAL_AVAILABLE = false

CHECK Sequential Thinking:
- Check if mcp__sequential-thinking__sequentialthinking appears in available tools
- Do not invoke for detection -- tool-list check is sufficient
- If not found: ST_AVAILABLE = false

CHECK Research MCP (for auto-research in Stage 2):
- Check if mcp__tavily__tavily_search is available -> RESEARCH_MCP_TAVILY = true/false
- Check if mcp__Ref__ref_search_documentation is available -> RESEARCH_MCP_REF = true/false
```

**If PAL_AVAILABLE = false:**
- Notify user: "PAL tools unavailable. Analysis modes limited to Standard and Rapid."

**If ST_AVAILABLE = false:**
- Notify user: "Sequential Thinking unavailable. Using internal reasoning."

**If RESEARCH_MCP_TAVILY = true:**
- Notify user: "Tavily MCP available. Auto-research will be offered in Stage 2."

## Step 1.2: Pre-flight Validation (Must Pass)

Validate all required components exist:

```bash
# Check required agents -- panel system
test -f "$CLAUDE_PLUGIN_ROOT/agents/requirements-panel-member.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/agents/requirements-panel-builder.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/agents/requirements-question-synthesis.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/agents/requirements-prd-generator.md" || echo "MISSING"

# Check required agents -- research discovery (used in Stage 2)
test -f "$CLAUDE_PLUGIN_ROOT/agents/research-discovery-business.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/agents/research-discovery-ux.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/agents/research-discovery-technical.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/agents/research-question-synthesis.md" || echo "MISSING"

# Check required references -- panel builder protocol
test -f "$CLAUDE_PLUGIN_ROOT/skills/refinement/references/panel-builder-protocol.md" || echo "MISSING"

# Check required config
test -f "$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml" || echo "MISSING"
```

**Validation Gate:** IF ANY component marked MISSING: ABORT with message listing required files.

## Step 1.3: Lock Management

```bash
find requirements/ -name ".requirements-lock" -type f 2>/dev/null
```

**If lock file found:**
1. Read lock file content (timestamp and info)
2. Calculate lock age

**If lock age > config `state.lock_staleness_hours` (default: 2h):**
Remove lock file, continue.

**If lock age <= config `state.lock_staleness_hours`:**
Use AskUserQuestion:
```json
{
  "questions": [{
    "question": "An active lock file was found (less than 2 hours old). How would you like to proceed?",
    "header": "Lock",
    "multiSelect": false,
    "options": [
      {"label": "Resume from last checkpoint (Recommended)", "description": "Continue where you left off"},
      {"label": "View current state", "description": "Display workflow status and exit"},
      {"label": "Force restart", "description": "WARNING: Remove lock and state file. Unsaved work will be lost."},
      {"label": "Exit", "description": "Exit without changes"}
    ]
  }]
}
```

Handle response:
- "Resume": WORKFLOW_MODE = RESUME
- "View": Display status, exit
- "Force restart": Remove lock AND state file, WORKFLOW_MODE = NEW
- "Exit": EXIT immediately

## Step 1.4: State Detection & Workflow Mode

```bash
test -f requirements/.requirements-state.local.md && echo "STATE_EXISTS=true" || echo "STATE_EXISTS=false"
test -f requirements/PRD.md && echo "PRD_EXISTS=true" || echo "PRD_EXISTS=false"
```

**If state file found:**
Parse YAML frontmatter, determine current_stage and phase_status.
Check for schema_version -- if v1, migrate per orchestrator-loop.md.

**If PRD.md exists:** PRD_MODE = "EXTEND"
**If PRD.md does NOT exist:** PRD_MODE = "NEW"

**Decision table:**

| Condition | Draft Provided | State Exists | PRD Exists | Action |
|-----------|---------------|-------------|------------|--------|
| A | Yes | No | -- | WORKFLOW_MODE = NEW, proceed to `stage-1-init.md` |
| B | -- | Yes (waiting_for_user) | -- | Resume to pause_stage (handled by orchestrator) |
| C | -- | No | Yes | Ask user: Extend / Regenerate / Review sections |
| D | No | No | No | Display template instructions, EXIT |

**Case C prompt:** Use AskUserQuestion with options: "Extend incomplete sections (Recommended)", "Regenerate entire PRD", "Review specific sections".

**Case D message:**
```
No draft provided and no existing workflow found.
To start:
1. Copy the template: cp $CLAUDE_PLUGIN_ROOT/templates/draft-template.md requirements/draft/{product-name}-draft.md
2. Fill in at least PART 1 (Essential)
3. Run: /product-definition:requirements {product-name}-draft.md
```
EXIT

---

## Handoff

After routing completes (WORKFLOW_MODE determined, MCP availability known):

- **RESUME**: Orchestrator takes over (routes to pause_stage or current_stage)
- **NEW / EXTEND**: Load and execute `@$CLAUDE_PLUGIN_ROOT/skills/refinement/references/stage-1-init.md`

## Critical Rules Reminder

Rules 1-3 above apply. Key: pre-flight must pass, fresh locks require confirmation, user decisions are immutable.
