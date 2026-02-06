---
phase: "1"
phase_name: "Setup & Initialization"
checkpoint: "SETUP"
delegation: "inline"
modes: [complete, advanced, standard, rapid]
prior_summaries: []
artifacts_read: []
artifacts_written: []
agents: []
mcp_tools:
  - "mcp__pal__listmodels"
  - "mcp__sequential-thinking__sequentialthinking"
feature_flags: []
additional_references: []
---

# Phase 1: Setup & Initialization

> **INLINE PHASE:** This phase executes directly in the orchestrator's context.
> After completion, the orchestrator MUST write a Phase 1 summary to
> `{FEATURE_DIR}/.phase-summaries/phase-1-summary.md` using the summary template.

## Step 1.1: Prerequisites Check

```
VERIFY:
  - Feature spec exists at {FEATURE_DIR}/spec.md
  - Constitution exists at specs/constitution.md

IF missing → ERROR with resolution guidance
```

## Step 1.2: Branch & Path Detection

```
GET current git branch

IF branch matches `feature/<NNN>-<kebab-case>`:
  FEATURE_NAME = part after "feature/"
  FEATURE_DIR = "specs/{FEATURE_NAME}"
ELSE:
  ASK user for feature directory
```

## Step 1.3: State Detection

```
IF {FEATURE_DIR}/.planning-state.local.md exists:
  DISPLAY state summary (phase, decisions count)

  # v2 migration check
  IF state.version == 1 OR state.version is missing:
    See $CLAUDE_PLUGIN_ROOT/skills/plan/references/orchestrator-loop.md for migration logic.

  ASK: Resume or Start Fresh?
ELSE:
  INITIALIZE new state from template
```

## Step 1.4: Lock Acquisition

```
LOCK_FILE = "{FEATURE_DIR}/.planning.lock"

IF LOCK_FILE exists AND age < 60 minutes:
  → ERROR: "Planning session in progress"

CREATE LOCK_FILE with pid, timestamp, user
```

## Step 1.5: MCP Availability Check

```
CHECK tools:
  # Core MCP (required for Complete/Advanced modes)
  - mcp__sequential-thinking__sequentialthinking
  - mcp__pal__thinkdeep
  - mcp__pal__consensus

  # Research MCP (optional, enhances Phases 2, 4, 7)
  - mcp__context7__query-docs
  - mcp__Ref__ref_search_documentation
  - mcp__tavily__tavily_search

DISPLAY availability status

IF research MCP unavailable:
  LOG: "Research MCP servers unavailable - Steps 2.1c, 4.0, 7.1b will use internal knowledge"
  SET state.research_mcp_available = false
ELSE:
  SET state.research_mcp_available = true
```

## Step 1.6: Analysis Mode Selection

Present modes based on MCP availability. Only show modes where required tools are available.

### Mode Auto-Suggestion (Optional)

```
IF config.mode_suggestion.enabled:

  1. ANALYZE spec.md for mode indicators:

     # Count high-risk keywords
     high_risk_count = COUNT matches of config.research_depth.risk_keywords.high
     keywords_sample = FIRST 3 matched keywords

     # Estimate affected files
     file_patterns = EXTRACT file paths and patterns from spec
     estimated_files = COUNT unique file patterns

     # Count spec words
     word_count = COUNT words in spec.md

  2. EVALUATE rules in order (first match wins):

     IF word_count >= 2000 OR high_risk_count >= 3:
       suggested_mode = "complete"
       rationale = "Large spec or multiple high-risk areas"
       cost_estimate = "$0.80-1.50"

     ELSE IF high_risk_count >= 2 OR estimated_files >= 15:
       suggested_mode = "advanced"
       rationale = "Significant risk or large scope"
       cost_estimate = "$0.45-0.75"

     ELSE IF word_count >= 500 OR estimated_files >= 5:
       suggested_mode = "standard"
       rationale = "Moderate complexity"
       cost_estimate = "$0.15-0.30"

     ELSE:
       suggested_mode = "rapid"
       rationale = "Simple feature"
       cost_estimate = "$0.05-0.12"

  3. DISPLAY suggestion:

     ┌─────────────────────────────────────────────────────────────┐
     │ MODE SUGGESTION                                              │
     ├─────────────────────────────────────────────────────────────┤
     │ Detected: {high_risk_count} high-risk keywords              │
     │           ({keywords_sample})                                │
     │ Estimated: {estimated_files} files affected                  │
     │ Spec size: {word_count} words                               │
     │                                                              │
     │ Recommended: {suggested_mode} mode (~{cost_estimate})       │
     │ Rationale: {rationale}                                       │
     └─────────────────────────────────────────────────────────────┘

  4. ASK user to confirm or override:
     - Accept suggestion
     - Choose different mode
```

## Step 1.7: Workspace Preparation

```
CREATE {FEATURE_DIR}/analysis/ if not exists
CREATE {FEATURE_DIR}/.phase-summaries/ if not exists
COPY plan-template.md to {FEATURE_DIR}/plan.md if not exists
```

## Step 1.8: Write Phase 1 Summary

After completing all setup steps, the orchestrator writes `{FEATURE_DIR}/.phase-summaries/phase-1-summary.md` containing:
- Selected analysis mode and rationale
- MCP availability status (which tools are available)
- Feature directory and branch paths
- Whether this is a fresh start or resume
- Any mode auto-suggestion details

**Checkpoint: SETUP**
