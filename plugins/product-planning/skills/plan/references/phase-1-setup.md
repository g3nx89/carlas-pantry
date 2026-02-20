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
  # PAL MCP removed — CLI dispatch (Step 1.5b) replaces model availability checks
  - "mcp__sequential-thinking__sequentialthinking"
feature_flags:
  - "cli_context_isolation"
  - "cli_custom_roles"
  - "dev_skills_integration"
  - "deep_reasoning_escalation"  # Step 1.5d: abstract algorithm detection
  - "s10_team_presets"
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
  # Core MCP (optional, enhances Complete mode)
  - mcp__sequential-thinking__sequentialthinking

  # Research MCP (optional, enhances Phases 2, 4, 7)
  - mcp__context7__query-docs
  - mcp__Ref__ref_search_documentation
  - mcp__tavily__tavily_search

DISPLAY availability status

# NOTE: PAL MCP tools (thinkdeep, consensus, challenge, listmodels) have been
# replaced by CLI dispatch via dispatch-cli-agent.sh. Complete/Advanced modes
# now require CLI availability (detected in Step 1.5b) instead of PAL MCP.

IF research MCP unavailable:
  LOG: "Research MCP servers unavailable - Steps 2.1c, 4.0, 7.1b will use internal knowledge"
  SET state.research_mcp_available = false
ELSE:
  SET state.research_mcp_available = true
```

## Step 1.5b: CLI Capability Detection

```
IF feature_flags.cli_context_isolation.enabled:

  1. VERIFY dispatch infrastructure:
     SCRIPT = "$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh"
     script_available = CHECK file exists at SCRIPT AND is executable
     jq_available = CHECK "jq --version" succeeds
     python3_available = CHECK "python3 --version" succeeds

     IF NOT script_available:
       LOG: "Dispatch script not found — skipping CLI integration"
       SET state.cli.available = false
       SET state.cli.mode = "disabled"
       SKIP rest of 1.5b

  2. CHECK which CLIs are installed via dispatch script smoke test:
     # Smoke test each CLI with a 30-second timeout
     gemini_exit = Bash("{SCRIPT} --cli gemini --role smoke_test --prompt-file /dev/null --output-file /tmp/cli-smoke-gemini.txt --timeout 30")
     codex_exit = Bash("{SCRIPT} --cli codex --role smoke_test --prompt-file /dev/null --output-file /tmp/cli-smoke-codex.txt --timeout 30")
     opencode_exit = Bash("{SCRIPT} --cli opencode --role smoke_test --prompt-file /dev/null --output-file /tmp/cli-smoke-opencode.txt --timeout 30")

     gemini_available = (gemini_exit != 3)  # exit 3 = CLI not found
     codex_available = (codex_exit != 3)
     opencode_available = (opencode_exit != 3)
     available_count = COUNT(true values in [gemini_available, codex_available, opencode_available])

     # Determine CLI mode
     IF available_count == 3:
       cli_mode = "tri"
       LOG: "Tri-CLI mode: full analysis with Gemini, Codex, and OpenCode"
     ELSE IF available_count == 2:
       cli_mode = "dual"
       missing = [name for name, avail in CLIs if not avail]
       LOG: "{missing[0]} CLI not available — CLI dispatch will use dual-CLI mode"
     ELSE IF available_count == 1:
       available_cli = [name for name, avail in CLIs if avail][0]
       cli_mode = "single_{available_cli}"
       LOG: "Only {available_cli} available — CLI dispatch will use single-CLI mode"
     ELSE:
       cli_mode = "disabled"
       LOG: "No CLIs available — skipping CLI integration"

  3. IF cli_mode != "disabled" AND feature_flags.cli_custom_roles.enabled:
     # Auto-deploy role templates to project
     SOURCE = "$CLAUDE_PLUGIN_ROOT/templates/cli-roles/"
     TARGET = "PROJECT_ROOT/conf/cli_clients/"

     # Check version marker
     IF TARGET does not exist OR TARGET version marker != SOURCE version marker:
       COPY all .txt and .json files from SOURCE to TARGET
       LOG: "Deployed CLI role templates (version 1.1.0)"
       roles_deployed = true
     ELSE:
       LOG: "CLI role templates already deployed and up to date"
       roles_deployed = true

  4. UPDATE state:
     cli:
       available: {available_count >= 1}
       capabilities:
         gemini: {gemini_available}
         codex: {codex_available}
         opencode: {opencode_available}
       roles_deployed: {roles_deployed}
       mode: {cli_mode}
       dispatch_infrastructure:
         script_available: {script_available}
         jq_available: {jq_available}
         python3_available: {python3_available}

ELSE:
  SET state.cli.available = false
  SET state.cli.mode = "disabled"
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

## Step 1.5d: Abstract Algorithm Detection

**Purpose:** Detect algorithm/math complexity keywords in spec.md that may warrant deep reasoning escalation in later phases. This is **detection only** — no escalation happens in Phase 1. The orchestrator uses this flag when quality gates fail in Phase 4, 6, or 7.

```
IF config.deep_reasoning_escalation.abstract_algorithm_detection.enabled:

  1. SCAN spec.md for algorithm keywords (case-insensitive):

     high_confidence_matches = []
     moderate_confidence_matches = []

     FOR EACH keyword IN config.deep_reasoning_escalation.algorithm_keywords.high_confidence:
       IF spec.md contains keyword (case-insensitive):
         ADD keyword to high_confidence_matches

     FOR EACH keyword IN config.deep_reasoning_escalation.algorithm_keywords.moderate_confidence:
       IF spec.md contains keyword (case-insensitive):
         ADD keyword to moderate_confidence_matches

  2. DETERMINE detection result:

     IF high_confidence_matches.length >= 1:
       algorithm_detected = true
       confidence = "high"
       LOG: "DEEP REASONING PRE-ALERT: High-confidence algorithm keywords detected: {high_confidence_matches}"
     ELSE IF moderate_confidence_matches.length >= 3:
       algorithm_detected = true
       confidence = "moderate"
       LOG: "DEEP REASONING PRE-ALERT: Multiple moderate-confidence algorithm keywords: {moderate_confidence_matches}"
     ELSE:
       algorithm_detected = false
       confidence = null

  3. UPDATE state:
     deep_reasoning:
       available: true
       algorithm_detected: {algorithm_detected}
       algorithm_keywords: {high_confidence_matches + moderate_confidence_matches}
       algorithm_confidence: {confidence}
       escalations: []
       pending_escalation: null

  4. LOG: "Deep reasoning detection: algorithm_detected={algorithm_detected}, keywords={all_matches}"

ELSE:
  SET state.deep_reasoning:
    available: false
    algorithm_detected: false
    algorithm_keywords: []
    algorithm_confidence: null
    escalations: []
    pending_escalation: null
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

  2. OPTIONAL: Run EHRB risk hook for supplemental signal:

     SCRIPT = "$CLAUDE_PLUGIN_ROOT/scripts/planning-hint.sh"
     IF file exists at SCRIPT AND is executable:
       hint_json = Bash("cat {FEATURE_DIR}/spec.md | {SCRIPT}")
       IF hint_json parses successfully AND hint_json.error is absent:
         hint_mode = hint_json.suggested_mode
         hint_categories = hint_json.risk_categories
         hint_keyword_count = hint_json.keyword_count
         LOG: "EHRB risk hook: suggested={hint_mode}, categories={hint_categories}, keywords={hint_keyword_count}"
       ELSE:
         hint_mode = null
         LOG: "EHRB risk hook: skipped (parse error or Bash <4)"
     ELSE:
       hint_mode = null

  3. EVALUATE rules in order (first match wins):

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

     # Reconcile with EHRB hint (upgrade only, never downgrade)
     IF hint_mode is not null:
       mode_rank = {rapid: 0, standard: 1, advanced: 2, complete: 3}
       IF mode_rank[hint_mode] > mode_rank[suggested_mode]:
         suggested_mode = hint_mode
         rationale = rationale + " (upgraded by EHRB risk categories: {hint_categories})"
         cost_estimate = LOOKUP cost for new mode

  4. DISPLAY suggestion:

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

  5. ASK user to confirm or override:
     - Accept suggestion
     - Choose different mode
```

## Step 1.6b: Team Preset Selection (S5)

```
IF feature_flags.s10_team_presets.enabled:

  1. DISPLAY preset options:

     ┌─────────────────────────────────────────────────────────────┐
     │ TEAM PRESET (optional)                                       │
     ├─────────────────────────────────────────────────────────────┤
     │                                                              │
     │ 1. balanced (Recommended)                                    │
     │    All MPA agents active. Full convergence + deliberation.   │
     │    Best for: Most features, comprehensive analysis.          │
     │                                                              │
     │ 2. rapid_prototype                                           │
     │    software-architect + qa-strategist only. Skip security    │
     │    and performance specialists. Faster, lower cost.          │
     │    Best for: Prototypes, internal tools, low-risk features.  │
     │                                                              │
     │ 3. Skip preset                                               │
     │    Use default agent configuration for selected mode.        │
     │                                                              │
     └─────────────────────────────────────────────────────────────┘

  2. ASK user via AskUserQuestion:
     header: "Team Preset"
     question: "Which agent team preset would you like?"
     options:
       - label: "balanced (Recommended)"
         description: "All MPA agents, full analysis"
       - label: "rapid_prototype"
         description: "Minimal agents, faster execution"
       - label: "Skip"
         description: "Use default mode configuration"

  3. SAVE to state:
     team_preset: {selected_preset or null}

  4. LOG: "Team preset: {selected_preset or 'default'}"
```

## Step 1.6c: Requirements Digest Extraction

**Purpose:** Extract a compact requirements digest from spec.md to inject into every coordinator dispatch prompt. This ensures every phase has baseline visibility into the original requirements, regardless of whether it reads spec.md directly.

```
READ {FEATURE_DIR}/spec.md

EXTRACT requirements_digest (budget: config.requirements_context.digest_max_tokens, default 300 tokens):

  ## Requirements Digest
  **Feature:** {one-line summary of what the feature does}
  **Acceptance Criteria:**
  {numbered list of acceptance criteria — abbreviated if needed to stay within budget}
  **Key Constraints:** {2-3 bullet points: technical constraints, dependencies, non-functional requirements}

# If spec.md has no explicit acceptance criteria, synthesize from the feature description
# If spec.md is very short (<100 words), use the full text as the digest

STORE in state:
  requirements_digest: |
    {the extracted digest text}

LOG: "Requirements digest extracted ({word_count} words, estimated {token_count} tokens)"
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
- Requirements digest (compact summary for downstream injection)

**Checkpoint: SETUP**
