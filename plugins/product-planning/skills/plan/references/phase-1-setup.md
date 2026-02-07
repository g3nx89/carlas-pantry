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
  - "mcp__pal__clink"
  - "mcp__sequential-thinking__sequentialthinking"
feature_flags:
  - "clink_context_isolation"
  - "clink_custom_roles"
  - "dev_skills_integration"
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

## Step 1.5b: Clink Capability Detection

```
IF feature_flags.clink_context_isolation.enabled:

  1. CHECK clink MCP tool accessible:
     clink_available = CHECK mcp__pal__clink is callable

  2. IF clink_available:
     # Check which CLIs are installed
     gemini_available = CHECK "gemini" CLI responds
     codex_available = CHECK "codex" CLI responds

     # Determine clink mode
     IF gemini_available AND codex_available:
       clink_mode = "dual"
     ELSE IF gemini_available:
       clink_mode = "single_gemini"
       LOG: "Codex CLI not available — clink will use single-CLI mode (Gemini only)"
     ELSE IF codex_available:
       clink_mode = "single_codex"
       LOG: "Gemini CLI not available — clink will use single-CLI mode (Codex only)"
     ELSE:
       clink_mode = "disabled"
       LOG: "No CLIs available for clink — skipping clink integration"

  3. IF clink_mode != "disabled" AND feature_flags.clink_custom_roles.enabled:
     # Auto-deploy role templates to project
     SOURCE = "$CLAUDE_PLUGIN_ROOT/templates/clink-roles/"
     TARGET = "PROJECT_ROOT/conf/cli_clients/"

     # Check version marker
     IF TARGET does not exist OR TARGET version marker != SOURCE version marker:
       COPY all .txt and .json files from SOURCE to TARGET
       LOG: "Deployed clink role templates (version 1.0.0)"
       roles_deployed = true
     ELSE:
       LOG: "Clink role templates already deployed and up to date"
       roles_deployed = true

  4. UPDATE state:
     clink:
       available: {clink_available}
       capabilities:
         gemini: {gemini_available}
         codex: {codex_available}
       roles_deployed: {roles_deployed}
       mode: {clink_mode}

ELSE:
  SET state.clink.available = false
  SET state.clink.mode = "disabled"
```

## Step 1.5c: Dev-Skills Relevance Detection

**Purpose:** Detect whether the `dev-skills` plugin is installed and which skill domains are relevant to this feature based on spec.md content and codebase markers.

```
IF config.dev_skills_integration.enabled:

  1. CHECK dev-skills plugin installed:
     TRY: Skill("dev-skills:clean-code") with minimal invocation
     IF fails → SET state.dev_skills.available = false, SKIP rest of 1.5c

  2. SCAN spec.md for technology indicators (case-insensitive):
     FOR EACH domain IN config.dev_skills_integration.detection:
       FOR EACH keyword IN domain.keywords:
         IF spec.md contains keyword:
           ADD domain to detected_domains
           ADD keyword to technology_markers

  3. SCAN codebase root for framework markers:
     FOR EACH marker_file, domains IN config.dev_skills_integration.codebase_markers:
       IF marker_file exists at project root:
         ADD domains to detected_domains
         IF marker_file == "package.json":
           READ dependencies → scan for react, next, vue, express, etc.
           ADD matching framework names to technology_markers
         IF marker_file IN ["build.gradle.kts", "settings.gradle.kts"]:
           ADD "kotlin" to technology_markers

  4. DETERMINE applicable skill domains:
     # Always-on domains
     FOR EACH domain IN config.dev_skills_integration.domain_skills:
       IF domain.always == true:
         ADD domain to applicable_domains

     # Conditional domains
     IF "frontend" in detected_domains: ADD frontend to applicable_domains
     IF "mobile" in detected_domains: ADD mobile to applicable_domains
     IF "database" in detected_domains: ADD database to applicable_domains
     IF "figma" in detected_domains: ADD figma to applicable_domains

  5. WRITE to state:
     dev_skills:
       available: true
       detected_domains: [architecture, database, frontend, ...]
       technology_markers: {react: true, prisma: true, ...}

  6. LOG: "Dev-skills detected: {detected_domains} (markers: {technology_markers})"

ELSE:
  SET state.dev_skills.available = false
  SET state.dev_skills.detected_domains = []
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
