---
stage: stage-1-setup
artifacts_written:
  - requirements/.requirements-state.local.md
  - requirements/.requirements-lock
  - requirements/.panel-config.local.md (conditional — absent in rapid mode)
  - requirements/.stage-summaries/stage-1-summary.md
---

# Stage 1: Setup & Initialization (Inline)

> This stage runs inline in the orchestrator — no coordinator dispatch.

## CRITICAL RULES (must follow — failure-prevention)

1. **Pre-flight validation MUST pass**: If ANY required agent or config file is MISSING, ABORT immediately. Do NOT proceed with partial setup.
2. **Lock staleness threshold**: Only remove locks older than `state.lock_staleness_hours` (default: 2 hours). NEVER remove fresh locks without user confirmation.
3. **User decisions are IMMUTABLE**: If resuming, NEVER re-ask mode selection recorded in `user_decisions`.

## Step 1.1: MCP Availability Check

Before proceeding, check which MCP tools are available:

```
CHECK PAL tools:
- Try invoking mcp__pal__listmodels
- If fails: PAL_AVAILABLE = false

CHECK Sequential Thinking:
- Try invoking mcp__sequential-thinking__sequentialthinking with a simple thought
- If fails: ST_AVAILABLE = false

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

**If RESEARCH_MCP_TAVILY = false AND RESEARCH_MCP_REF = false:**
- (No notification needed — manual research flow is the default)

## Step 1.2: Pre-flight Validation (MUST PASS)

Validate all required components exist:

```bash
# Check required agents — panel system
test -f "$CLAUDE_PLUGIN_ROOT/agents/requirements-panel-member.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/agents/requirements-panel-builder.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/agents/requirements-question-synthesis.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/agents/requirements-prd-generator.md" || echo "MISSING"

# Check required agents — research discovery (used in Stage 2)
test -f "$CLAUDE_PLUGIN_ROOT/agents/research-discovery-business.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/agents/research-discovery-ux.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/agents/research-discovery-technical.md" || echo "MISSING"
test -f "$CLAUDE_PLUGIN_ROOT/agents/research-question-synthesis.md" || echo "MISSING"

# Check required references — panel builder protocol
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
Use AskUserQuestion directly (Stage 1 runs inline in the orchestrator):
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
Check for schema_version — if v1, migrate per orchestrator-loop.md.

**If PRD.md exists:** PRD_MODE = "EXTEND"
**If PRD.md does NOT exist:** PRD_MODE = "NEW"

**Case A: User provided draft filename AND no state exists**
WORKFLOW_MODE = NEW, proceed to Step 1.6

**Case B: State exists with waiting_for_user: true**
Check for filled QUESTIONS file or research reports.
Resume to appropriate stage (handled by orchestrator).

**Case C: PRD.md exists AND no state exists**
Use AskUserQuestion directly (Stage 1 runs inline):
```json
{
  "questions": [{
    "question": "An existing PRD.md was found but no workflow state. How would you like to proceed?",
    "header": "PRD Mode",
    "multiSelect": false,
    "options": [
      {"label": "Extend incomplete sections (Recommended)", "description": "Analyze PRD for gaps and generate questions for missing content"},
      {"label": "Regenerate entire PRD", "description": "Start fresh PRD generation from draft"},
      {"label": "Review specific sections", "description": "Choose which sections to improve"}
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
2. Fill in at least PART 1 (Essential)
3. Run: /product-definition:requirements {product-name}-draft.md
```
EXIT

## Step 1.5: Validate Draft Input

If WORKFLOW_MODE = NEW and draft provided:

```bash
test -f "requirements/draft/$ARGUMENTS" && echo "DRAFT_VALID=true" || echo "DRAFT_VALID=false"
```

If draft not found: list available drafts, ask user to select.

## Step 1.6: Workspace Creation

```bash
mkdir -p requirements/draft
mkdir -p requirements/working
mkdir -p requirements/research/questions
mkdir -p requirements/research/reports
mkdir -p requirements/analysis
mkdir -p requirements/.stage-summaries
```

Copy draft to working:
```bash
cp "requirements/draft/{DRAFT_FILE}" requirements/working/draft-copy.md
```

Extract product name from draft:
```
Read the first H1 heading (# ...) from the draft file.
Strip any trailing suffixes like "Draft", "PRD", "Requirements".
Store as PRODUCT_NAME.
Fallback: use the draft filename without extension.
```

Create lock file:
```bash
echo "locked_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
workflow_mode: {NEW|EXTEND}
prd_mode: {NEW|EXTEND}" > requirements/.requirements-lock
```

## Step 1.7: Analysis Mode Selection

**Check for --mode flag in $ARGUMENTS:**
- --mode=complete -> ANALYSIS_MODE = "complete"
- --mode=advanced -> ANALYSIS_MODE = "advanced"
- --mode=standard -> ANALYSIS_MODE = "standard"
- --mode=rapid -> ANALYSIS_MODE = "rapid"
If flag found, skip to Step 1.8.

**If PAL_AVAILABLE = false:**
Only offer Standard and Rapid modes.

**If PAL available (full options):**
Use AskUserQuestion:
```json
{
  "questions": [{
    "question": "Which analysis level do you want for this round?",
    "header": "Analysis",
    "multiSelect": false,
    "options": [
      {"label": "Complete Analysis (MPA + PAL + ST) (Recommended)", "description": "Panel members + 3 PAL perspectives + Sequential Thinking. Maximum depth, ~$0.50-1.00/round, ~15-30 min"},
      {"label": "Advanced Analysis (MPA + PAL)", "description": "Panel members + 2 PAL ThinkDeep perspectives. Good depth, ~$0.30-0.50/round, ~10-20 min"},
      {"label": "Standard Analysis (MPA only)", "description": "Panel members only. Solid coverage, ~$0.15-0.25/round, ~3-8 min"},
      {"label": "Rapid Analysis (Single agent)", "description": "Single BA agent. Fast and minimal cost, ~$0.05-0.10/round, ~1-3 min"}
    ]
  }]
}
```

**If PAL NOT available (degraded options):**
```json
{
  "questions": [{
    "question": "Which analysis level do you want for this round?\n\n**Note:** PAL tools unavailable. Complete and Advanced modes disabled.",
    "header": "Analysis",
    "multiSelect": false,
    "options": [
      {"label": "Standard Analysis (MPA only) (Recommended)", "description": "Panel members only. Solid coverage, ~$0.15-0.25/round, ~3-8 min"},
      {"label": "Rapid Analysis (Single agent)", "description": "Single BA agent. Fast and minimal cost, ~$0.05-0.10/round, ~1-3 min"}
    ]
  }]
}
```

## Step 1.7.5: Panel Composition

**Purpose:** Build the MPA panel — the set of specialist perspectives that will generate questions.

```
IF ANALYSIS_MODE = rapid:
    → Panel fixed to single panelist (product-strategist default)
    → Skip Panel Builder dispatch
    → Set PANEL_CONFIG_PATH = null (use default single-agent mode)
    → Proceed to Step 1.8

IF ANALYSIS_MODE in {standard, advanced, complete}:
    → Continue to panel composition below
```

### 1. Check for Existing Panel Config

```bash
test -f requirements/.panel-config.local.md && echo "PANEL_EXISTS=true" || echo "PANEL_EXISTS=false"
```

### 2a. If Panel Config Exists

Read panel config, display summary to user via AskUserQuestion:

```json
{
  "questions": [{
    "question": "Existing analysis panel found:\n\n{MEMBER_LIST_FROM_CONFIG}\n\nUse this panel or reconfigure?",
    "header": "Panel",
    "multiSelect": false,
    "options": [
      {"label": "Use existing panel (Recommended)", "description": "Continue with the same specialist perspectives"},
      {"label": "Reconfigure panel", "description": "Choose a different preset or customize members"}
    ]
  }]
}
```

- **"Use existing panel":** Set `PANEL_CONFIG_PATH = "requirements/.panel-config.local.md"`, skip to Step 1.8
- **"Reconfigure":** Continue to step 3

### 2b. If No Panel Config Exists

Continue to step 3.

### 3. Dispatch Panel Builder

```
Task(subagent_type="general-purpose", model="sonnet", prompt="""
Read and follow: @$CLAUDE_PLUGIN_ROOT/skills/refinement/references/panel-builder-protocol.md

You are the Panel Builder. Read your agent definition at:
@$CLAUDE_PLUGIN_ROOT/agents/requirements-panel-builder.md

## Context
- Draft file: requirements/working/draft-copy.md
- Product name: {PRODUCT_NAME}
- Analysis mode: {ANALYSIS_MODE}
{IF PRESET_OVERRIDE:}- Preset override: {PRESET_OVERRIDE}{END IF}
{IF CUSTOM_MEMBERS:}- Custom members: {CUSTOM_MEMBERS}{END IF}

## Config
Read available perspectives from: @$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml -> panel.available_perspectives

## Output
- Proposed panel: requirements/.panel-proposed.local.md
- Summary: requirements/.stage-summaries/panel-builder-summary.md

Analyze the draft, detect domain signals, and propose a panel.
""")
```

### 3.1 Panel Builder Failure Fallback

**If Panel Builder dispatch fails** (no summary produced, crash, or timeout):
1. Notify user: "Panel Builder failed. Falling back to default preset."
2. Use default preset from config (`panel.default_preset`, default: `product-focused`)
3. Build panel config directly from `config/requirements-config.yaml` -> `panel.presets.{default_preset}` + `panel.available_perspectives`
4. Write panel config to `requirements/.panel-config.local.md` using the template
5. Skip steps 4-7, proceed to step 8 (Finalize Panel)

### 4. Read Panel Builder Output

Read `requirements/.stage-summaries/panel-builder-summary.md`.
The summary will have `status: needs-user-input` with `question_context`.

### 5. Present Panel to User

Use `AskUserQuestion` with the question from the Panel Builder summary:

```json
{
  "questions": [{
    "question": "{question from panel-builder-summary.flags.question_context.question}",
    "header": "Panel",
    "multiSelect": false,
    "options": [
      {"label": "Accept panel (Recommended)", "description": "{preset description}"},
      {"label": "Choose different preset", "description": "Select from: product-focused, consumer, marketplace, enterprise"},
      {"label": "Customize members", "description": "Pick individual perspectives from the available registry"}
    ]
  }]
}
```

### 6. Handle "Choose Different Preset"

```json
{
  "questions": [{
    "question": "Which panel preset do you want?",
    "header": "Preset",
    "multiSelect": false,
    "options": [
      {"label": "Product-focused", "description": "Product Strategist + UX Researcher + Functional Analyst"},
      {"label": "Consumer", "description": "Product Strategist + UX Researcher + Growth Specialist"},
      {"label": "Marketplace", "description": "Product Strategist + UX Researcher + Marketplace Dynamics + Growth"},
      {"label": "Enterprise", "description": "Product Strategist + UX Researcher + Compliance & Regulatory"}
    ]
  }]
}
```

Re-dispatch Panel Builder (step 3) with `PRESET_OVERRIDE` set to user's choice.

### 7. Handle "Customize Members"

```json
{
  "questions": [{
    "question": "Select the perspectives for your panel (2-5 members):",
    "header": "Members",
    "multiSelect": true,
    "options": [
      {"label": "Product Strategist", "description": "Market positioning, competitive differentiation, business model"},
      {"label": "UX Researcher", "description": "Personas, user journeys, pain points, accessibility"},
      {"label": "Functional Analyst", "description": "Feature completeness, workflow edge cases, data requirements"},
      {"label": "Growth Specialist", "description": "Onboarding, engagement loops, churn prevention"}
    ]
  }]
}
```

**Note:** Show additional options from config `panel.available_perspectives` if relevant to the detected domain.

Re-dispatch Panel Builder (step 3) with `CUSTOM_MEMBERS` set to user's selections.

### 8. Finalize Panel

```bash
mv requirements/.panel-proposed.local.md requirements/.panel-config.local.md
```

Set `PANEL_CONFIG_PATH = "requirements/.panel-config.local.md"`

Record user decision:
```yaml
user_decisions:
  panel_round_1: "{PRESET_NAME or 'custom'}"
```

---

## Step 1.8: State Initialization (CHECKPOINT)

Create `requirements/.requirements-state.local.md` from template at `$CLAUDE_PLUGIN_ROOT/templates/.requirements-state-template.local.md`.

Set:
- schema_version: 2
- prd_mode: "{NEW|EXTEND}"
- product_name: "{PRODUCT_NAME}"
- current_stage: 1
- current_round: 1
- analysis_mode: "{ANALYSIS_MODE}"
- panel_preset: "{PRESET_NAME or null if rapid}"
- panel_members_count: {N or 0 if rapid}
- panel_config_path: "{PANEL_CONFIG_PATH or null if rapid}"
- mcp_availability.pal_available: {true|false}
- mcp_availability.st_available: {true|false}
- mcp_availability.research_mcp.tavily: {true|false}
- mcp_availability.research_mcp.ref: {true|false}

Record user decisions:
```yaml
user_decisions:
  analysis_mode_round_1: "{ANALYSIS_MODE}"
  panel_round_1: "{PRESET_NAME or 'rapid-default'}"
```

**Git Suggestion:**
```
git add requirements/
git commit -m "wip(req): initialize requirements structure"
```

## Summary Contract

Write to `requirements/.stage-summaries/stage-1-summary.md`:

```yaml
---
stage: "setup"
stage_number: 1
status: completed
checkpoint: SETUP
artifacts_written:
  - requirements/.requirements-state.local.md
  - requirements/.requirements-lock
  - requirements/.panel-config.local.md  # conditional — absent in rapid mode
summary: "Initialized workspace in {PRD_MODE} mode with {ANALYSIS_MODE} analysis, {N}-member panel ({PRESET_NAME})"
flags:
  analysis_mode: "{ANALYSIS_MODE}"
  prd_mode: "{PRD_MODE}"
  panel_preset: "{PRESET_NAME or null}"
  panel_members_count: {N or 0}
  panel_config_path: "{PANEL_CONFIG_PATH or null}"
  pal_available: {true|false}
  st_available: {true|false}
  research_mcp_tavily: {true|false}
  research_mcp_ref: {true|false}
  round_number: 1
---
```

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. `requirements/.requirements-state.local.md` exists with `schema_version: 2`
2. `requirements/.requirements-lock` exists with timestamp
3. All workspace directories created (`working/`, `research/`, `analysis/`, `.stage-summaries/`)
4. `analysis_mode` is one of: `complete`, `advanced`, `standard`, `rapid`
5. Summary YAML frontmatter has no placeholder values

## CRITICAL RULES REMINDER

- Pre-flight validation MUST pass before proceeding
- Lock staleness threshold from config — never remove fresh locks without confirmation
- Resumed user decisions are IMMUTABLE
