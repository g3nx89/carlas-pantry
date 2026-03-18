---
stage: stage-1-init
artifacts_written:
  - requirements/.requirements-state.local.md
  - requirements/.requirements-lock
  - requirements/.panel-config.local.md (conditional -- absent in rapid mode)
  - requirements/.stage-summaries/stage-1-summary.md
---

# Stage 1 Initialization: Workspace, Mode Selection, Panel, State

> Loaded only for NEW or EXTEND workflows (not RESUME).
> Prerequisite: `stage-1-routing.md` has already run, setting WORKFLOW_MODE, PRD_MODE, and MCP availability.

## Critical Rules

1. **Lock staleness threshold**: Only remove locks older than `state.lock_staleness_hours` (default: 2 hours).
2. **User decisions are immutable**: Never re-ask mode selection recorded in `user_decisions`.

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
If flag found, skip to Step 1.9.

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
      {"label": "Complete Analysis (MPA + PAL + ST) (Recommended)", "description": "Panel members + PAL perspectives + Sequential Thinking. Maximum depth, ~$0.50-1.00/round, ~15-30 min"},
      {"label": "Advanced Analysis (MPA + PAL)", "description": "Panel members + PAL ThinkDeep perspectives. Good depth, ~$0.30-0.50/round, ~10-20 min"},
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

## Step 1.8: Panel Composition

Build the MPA panel -- the set of specialist perspectives that will generate questions.

```
IF ANALYSIS_MODE = rapid:
    -> Panel fixed to single panelist (product-strategist default)
    -> Skip Panel Builder dispatch
    -> Set PANEL_CONFIG_PATH = null (use default single-agent mode)
    -> Proceed to Step 1.9

IF ANALYSIS_MODE in {standard, advanced, complete}:
    -> Continue to panel composition below
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

- **"Use existing panel":** Set `PANEL_CONFIG_PATH = "requirements/.panel-config.local.md"`, skip to Step 1.9
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
1. Notify user: "Panel Builder failed."
2. Present preset selection via AskUserQuestion:
```json
{
  "questions": [{
    "question": "Panel Builder could not analyze the draft. Select a panel preset:",
    "header": "Fallback",
    "multiSelect": false,
    "options": [
      {"label": "Product-focused (Recommended)", "description": "Product Strategist + UX Researcher + Functional Analyst"},
      {"label": "Consumer", "description": "Product Strategist + UX Researcher + Growth Specialist"},
      {"label": "Marketplace", "description": "Product Strategist + UX Researcher + Marketplace Dynamics + Growth"},
      {"label": "Enterprise", "description": "Product Strategist + UX Researcher + Compliance & Regulatory"}
    ]
  }]
}
```
3. Build panel config from selected preset + `panel.available_perspectives`
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

Show additional options from config `panel.available_perspectives` if relevant to the detected domain.

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

## Step 1.9: State Initialization (CHECKPOINT)

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
git add requirements/.requirements-state.local.md requirements/.requirements-lock requirements/.panel-config.local.md
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
  - requirements/.panel-config.local.md  # conditional -- absent in rapid mode
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

## Self-Verification (Mandatory before writing summary)

Before writing the summary file, verify:
1. `requirements/.requirements-state.local.md` exists with `schema_version: 2`
2. `requirements/.requirements-lock` exists with timestamp
3. All workspace directories created (`working/`, `research/`, `analysis/`, `.stage-summaries/`)
4. `analysis_mode` is one of: `complete`, `advanced`, `standard`, `rapid`
5. Summary YAML frontmatter has no placeholder values
6. **Reasoning quality**: if panel mode (not rapid), panel has 2-5 members with distinct perspective names

## Critical Rules Reminder

Rules 1-2 above apply. Key: fresh locks require confirmation, user decisions are immutable.
