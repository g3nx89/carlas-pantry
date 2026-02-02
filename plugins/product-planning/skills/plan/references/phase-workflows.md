# Phase Workflows Reference

Detailed step-by-step instructions for each planning phase.

## Phase 1: Setup & Initialization

### Step 1.1: Prerequisites Check

```
VERIFY:
  - Feature spec exists at {FEATURE_DIR}/spec.md
  - Constitution exists at specs/constitution.md

IF missing → ERROR with resolution guidance
```

### Step 1.2: Branch & Path Detection

```
GET current git branch

IF branch matches `feature/<NNN>-<kebab-case>`:
  FEATURE_NAME = part after "feature/"
  FEATURE_DIR = "specs/{FEATURE_NAME}"
ELSE:
  ASK user for feature directory
```

### Step 1.3: State Detection

```
IF {FEATURE_DIR}/.planning-state.local.md exists:
  DISPLAY state summary (phase, decisions count)
  ASK: Resume or Start Fresh?
ELSE:
  INITIALIZE new state from template
```

### Step 1.4: Lock Acquisition

```
LOCK_FILE = "{FEATURE_DIR}/.planning.lock"

IF LOCK_FILE exists AND age < 60 minutes:
  → ERROR: "Planning session in progress"

CREATE LOCK_FILE with pid, timestamp, user
```

### Step 1.5: MCP Availability Check

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

### Step 1.6: Analysis Mode Selection

Present modes based on MCP availability. Only show modes where required tools are available.

#### Mode Auto-Suggestion (Optional)

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

### Step 1.7: Workspace Preparation

```
CREATE {FEATURE_DIR}/analysis/ if not exists
COPY plan-template.md to {FEATURE_DIR}/plan.md if not exists
```

**Checkpoint: SETUP**

---

## Phase 2: Research & Codebase Exploration

### Step 2.1: Load Context

```
READ:
  - {FEATURE_DIR}/spec.md
  - specs/constitution.md
```

### Step 2.1b: Adaptive Research Depth (A3)

**Purpose:** Adjust research intensity based on risk indicators in the feature spec.

```
IF feature_flags.a3_adaptive_depth.enabled:

  1. SCAN spec.md for risk keywords from config:
     - HIGH_RISK: payment, auth, security, encryption, PII, GDPR, etc.
     - MEDIUM_RISK: API, integration, migration, database, performance, etc.

  2. DETERMINE risk level:
     IF any HIGH_RISK keyword found → risk_level = high
     ELSE IF any MEDIUM_RISK keyword found → risk_level = medium
     ELSE → risk_level = low

  3. LOOKUP research depth from matrix:
     depth = config.research_depth.depth_matrix[analysis_mode][risk_level]
     # Returns: minimal, standard, or deep

  4. UPDATE state:
     state.research_depth = depth
     state.risk_keywords_found = [list of matched keywords]

  5. DISPLAY to user:
     "Research depth: {depth} (detected {risk_level} risk from keywords: {keywords})"
```

**Depth Level Actions:**

| Depth | Agents | Search Scope | ST Templates |
|-------|--------|--------------|--------------|
| minimal | 1 | Direct matches only | None |
| standard | 2 | Related patterns | T4, T5 |
| deep | 3 | Comprehensive exploration | T4, T5, T6 |

### Step 2.1c: Research MCP Enhancement (NEW)

**Purpose:** Use research MCP servers to gather official documentation for mentioned technologies BEFORE launching researcher agents. This provides enriched context and ensures agents have access to current, authoritative information.

**Reference:** `$CLAUDE_PLUGIN_ROOT/skills/plan/references/research-mcp-patterns.md`

```
1. EXTRACT technology mentions from spec.md:
   technologies = PARSE spec.md for framework/library names
   # Examples: React, Next.js, Prisma, NextAuth, etc.

2. FOR EACH technology IN technologies:

   a. DETERMINE server using selection matrix:
      IF technology IN config.research_mcp.context7.common_library_ids:
        server = "context7"
        library_id = config.research_mcp.context7.common_library_ids[technology]
      ELSE:
        server = "ref"

   b. QUERY documentation:
      IF server == "context7":
        result = mcp__context7__query-docs(
          libraryId: library_id,
          query: "{technology} {feature_context} patterns best practices"
        )
        # Efficiency: Max 3 calls per technology
      ELSE:
        result = mcp__Ref__ref_search_documentation(
          query: "How to implement {feature_relevant_aspect} with {technology}"
        )

   c. STORE findings in research_context

3. IF risk_level >= medium OR any technology is newly released:

   # Check for recent updates/breaking changes
   FOR EACH technology IN high_priority_technologies:
     updates = mcp__tavily__tavily_search(
       query: "{technology} release notes breaking changes 2026",
       search_depth: "basic",
       time_range: "month",
       max_results: 5
     )

     # Filter by relevance
     relevant_updates = FILTER updates WHERE score > 0.5

     IF relevant_updates contains critical changes:
       # Deep dive on changelog
       changelog = mcp__Ref__ref_read_url(url: changelog_url)
       ADD changelog to research_context

4. IF any technology handles auth/payments/PII:

   # Security vulnerability check
   security_check = mcp__tavily__tavily_search(
     query: "{technology} CVE security vulnerability 2025 2026",
     search_depth: "basic",
     max_results: 5
   )

   IF security_check contains vulnerabilities:
     FLAG for immediate attention in research.md
     ADD to risk_keywords_found

5. CONSOLIDATE research_context:
   - Official documentation snippets
   - Recent updates/breaking changes
   - Security findings
   - Version compatibility notes

6. OUTPUT:
   research_context will be passed to researcher agents in Step 2.2
```

**Server Selection Quick Reference:**

| Technology Type | Server | Efficiency Rule |
|----------------|--------|-----------------|
| Mainstream libraries (React, Next.js) | Context7 | Use direct IDs, max 3 calls |
| Niche libraries | Ref | Search first, read selectively |
| Recent announcements | Tavily | time_range="month", basic depth |
| Security/CVE checks | Tavily | Filter score > 0.5 |
| Deep URL content | Ref | ref_read_url on specific URLs |

**Anti-Pattern Warning:**
- NEVER use Tavily for library documentation (returns outdated content)
- ALWAYS use Context7 or Ref for API reference

### Step 2.2: Launch Research Agents

For each unknown in Technical Context:

```
Task(
  subagent_type: "product-planning:researcher",
  prompt: "Research {unknown} for {feature_context}"
)
```

### Step 2.2b: Launch Learnings Researcher (A2)

**Purpose:** Search institutional knowledge base for relevant solutions and learnings.

```
IF feature_flags.a2_institutional_knowledge.enabled:

  1. CHECK for knowledge base:
     - Glob: docs/solutions/**/*.yaml
     - Glob: docs/critical-patterns.md

  2. IF knowledge base found:
     Task(
       subagent_type: "product-planning:learnings-researcher",
       prompt: """
         Search institutional knowledge for feature: {FEATURE_NAME}

         Feature spec highlights:
         - Domain: {extracted_domain_terms}
         - Technologies: {mentioned_technologies}
         - Risk areas: {risk_keywords_found}

         Knowledge base locations:
         - docs/solutions/
         - docs/critical-patterns.md

         Find relevant:
         - Past solutions to similar problems
         - Critical patterns that must apply
         - Known pitfalls to avoid
       """
     )

  3. ELSE (no knowledge base):
     LOG: "No institutional knowledge base found at docs/solutions/"
     SUGGEST: "Consider creating docs/solutions/ for future learnings"
     → Continue without learnings input
```

**Integration with Research:**
- Learnings researcher runs in parallel with code-explorer agents
- Results merged into research.md "Institutional Knowledge" section
- High-relevance learnings highlighted in Phase 3 question generation

### Step 2.3: Launch Code Explorer Agents (MPA)

Launch 2-3 agents in parallel:

```
Task(subagent_type: "product-planning:code-explorer", prompt: "Find similar features...")
Task(subagent_type: "product-planning:code-explorer", prompt: "Map architecture...")
Task(subagent_type: "product-planning:code-explorer", prompt: "Identify integrations...")
```

### Step 2.4: Sequential Thinking (Complete Mode)

IF mode == Complete AND ST available:

```
mcp__sequential-thinking__sequentialthinking(T4: Pattern Recognition)
mcp__sequential-thinking__sequentialthinking(T5: Integration Points)
mcp__sequential-thinking__sequentialthinking(T6: Technical Constraints)
```

### Step 2.4b: TAO Loop Analysis (After Research Agents)

```
IF feature_flags.st_tao_loops.enabled AND analysis_mode in {standard, advanced, complete}:

  AFTER all research agents (code-explorer, researcher, learnings-researcher) complete:
    mcp__sequential-thinking__sequentialthinking(T-AGENT-ANALYSIS)
    mcp__sequential-thinking__sequentialthinking(T-AGENT-SYNTHESIS)
    mcp__sequential-thinking__sequentialthinking(T-AGENT-VALIDATION)

  OUTPUT: Structured synthesis of research findings
    - Convergent patterns → High confidence
    - Divergent findings → Flag for clarification in Phase 3
    - Gaps → Add to research questions

ELSE:
  # Direct consolidation without structured pause
```

### Step 2.5: Consolidate Research

Write `{FEATURE_DIR}/research.md` with:
- Technologies and decisions
- Patterns identified
- Key files to reference
- Constitution compliance notes
- **Institutional Knowledge** (if A2 enabled):
  - Highly relevant learnings
  - Critical patterns to apply
  - Warnings and anti-patterns
- **TAO Loop Synthesis** (if st_tao_loops enabled):
  - Convergent findings summary
  - Flagged divergent findings for Phase 3

**Checkpoint: RESEARCH**

### Step 2.6: Quality Gate - Research Completeness (S3)

**Purpose:** Verify research quality before proceeding to architecture.

```
IF feature_flags.s3_judge_gates.enabled AND analysis_mode in {advanced, complete}:

  1. LAUNCH judge agent:
     Task(
       subagent_type: "product-planning:phase-gate-judge",
       prompt: """
         Evaluate Research Completeness for feature: {FEATURE_NAME}

         Artifacts to evaluate:
         - {FEATURE_DIR}/research.md
         - {FEATURE_DIR}/analysis/codebase-analysis.md

         Use Gate 1 criteria from judge-gate-rubrics.md.
         Mode: {analysis_mode}
       """
     )

  2. PARSE verdict:
     IF verdict == PASS:
       LOG: "Gate 1 PASSED (score: {score}/5.0)"
       → Continue to Phase 3

     IF verdict == FAIL AND retries < 2:
       LOG: "Gate 1 FAILED (score: {score}/5.0) - retry {retries+1}/2"
       DISPLAY retry_feedback to user
       Re-run Phase 2.3-2.5 with feedback
       retries += 1
       → Re-evaluate

     IF verdict == FAIL AND retries >= 2:
       LOG: "Gate 1 FAILED after 2 retries - escalating"
       DISPLAY to user:
         "Research quality gate failed after 2 attempts.
          Issues: {issues}
          Options: (1) Force proceed, (2) Manual fix, (3) Abort"
       → Wait for user decision

  3. UPDATE state:
     gate_results.append({
       phase: 2,
       gate: "Research Completeness",
       score: {score},
       verdict: {verdict},
       retries: {retries}
     })
```

---

## Phase 3: Clarifying Questions

### Step 3.1: Sequential Thinking (Complete Mode)

IF mode == Complete AND ST available:

```
mcp__sequential-thinking__sequentialthinking(T1: Feature Understanding)
mcp__sequential-thinking__sequentialthinking(T2: Scope Boundaries)
mcp__sequential-thinking__sequentialthinking(T3: Decomposition Strategy)
```

### Step 3.2: Generate Questions

Identify gaps across categories:
- Scope boundaries
- Edge cases
- Error handling
- Integration details
- Design preferences

### Step 3.3: Collect User Responses

**BLOCKING:** Wait for user to answer ALL questions.

For "whatever you think is best" responses, use BA recommendation and mark as ASSUMED.

### Step 3.4: Update State

Save all decisions to `user_decisions` (IMMUTABLE).

**Checkpoint: CLARIFICATION**

---

## Phase 4: Architecture Design

### Step 4.0: Architecture Pattern Research (Research MCP)

**Purpose:** Fetch framework-specific architecture patterns BEFORE launching architect agents.

```
IF analysis_mode in {advanced, complete}:

  1. IDENTIFY primary framework from research.md:
     framework = EXTRACT main framework (e.g., Next.js, Express, Django)

  2. QUERY architecture patterns:
     IF framework IN config.research_mcp.context7.common_library_ids:
       patterns = mcp__context7__query-docs(
         libraryId: config.research_mcp.context7.common_library_ids[framework],
         query: "{framework} architecture patterns folder structure best practices"
       )
     ELSE:
       patterns = mcp__Ref__ref_search_documentation(
         query: "{framework} recommended architecture patterns enterprise applications"
       )

  3. IF feature involves specific domain (auth, payments, etc.):
     domain_patterns = mcp__context7__query-docs(
       libraryId: "{relevant_library_id}",
       query: "{domain} implementation patterns {framework}"
     )

  4. INCLUDE patterns in architect agent prompts:
     architecture_context = {
       framework_patterns: patterns,
       domain_patterns: domain_patterns,
       source: "official documentation"
     }

ELSE:
  # Standard/Rapid mode - skip external research
  architecture_context = research.md findings only
```

### Step 4.1: Launch Architecture Agents (MPA)

Launch 3 agents in parallel:

```
Task(subagent_type: "product-planning:software-architect", prompt: "MINIMAL CHANGE focus...")
Task(subagent_type: "product-planning:software-architect", prompt: "CLEAN ARCHITECTURE focus...")
Task(subagent_type: "product-planning:software-architect", prompt: "PRAGMATIC BALANCE focus...")
```

Output to:
- `{FEATURE_DIR}/design.minimal.md`
- `{FEATURE_DIR}/design.clean.md`
- `{FEATURE_DIR}/design.pragmatic.md`

### Step 4.1b: TAO Loop Analysis (After MPA Agents)

```
IF feature_flags.st_tao_loops.enabled AND analysis_mode in {standard, advanced, complete}:

  # Structured pause between agent outputs and decisions
  AFTER all MPA agents complete:
    mcp__sequential-thinking__sequentialthinking(T-AGENT-ANALYSIS)
    # Categorize: Convergent (all agree), Divergent (disagree), Gaps

    mcp__sequential-thinking__sequentialthinking(T-AGENT-SYNTHESIS)
    # Define handling strategy per category

    mcp__sequential-thinking__sequentialthinking(T-AGENT-VALIDATION)
    # Verify synthesis is ready for next phase

  IF T-AGENT-VALIDATION.result == FAIL:
    LOG: "TAO validation failed - flagging for human review"
    FLAG divergent_findings for user decision in Step 4.3

ELSE:
  # Skip TAO loop, proceed directly to Step 4.2
```

**TAO Loop Purpose:**
- Prevents rushed synthesis of conflicting agent perspectives
- Explicitly categorizes findings before merging
- Provides structured pause for reflection

### Step 4.2: Sequential Thinking with Fork-Join (Complete Mode)

IF mode == Complete AND ST available:

```
# Check feature flag for Fork-Join
IF feature_flags.st_fork_join_architecture.enabled:

  # Phase 4.2a: Frame the decision point
  mcp__sequential-thinking__sequentialthinking(T7a_FRAME)

  # Phase 4.2b: Parallel branches (logically parallel, sequential execution)
  mcp__sequential-thinking__sequentialthinking(T7b_BRANCH_MINIMAL)
  mcp__sequential-thinking__sequentialthinking(T7c_BRANCH_CLEAN)
  mcp__sequential-thinking__sequentialthinking(T7d_BRANCH_PRAGMATIC)

  # Phase 4.2c: Join and synthesize
  mcp__sequential-thinking__sequentialthinking(T8_SYNTHESIS)

  # Phase 4.2d: Continue with selected approach
  mcp__sequential-thinking__sequentialthinking(T9: Component Design)
  mcp__sequential-thinking__sequentialthinking(T10: Acceptance Criteria Mapping)

ELSE:
  # Fallback to linear T7-T10
  mcp__sequential-thinking__sequentialthinking(T7: Option Generation)
  mcp__sequential-thinking__sequentialthinking(T8: Trade-off Analysis)
  mcp__sequential-thinking__sequentialthinking(T9: Component Design)
  mcp__sequential-thinking__sequentialthinking(T10: Acceptance Criteria Mapping)
```

**Fork-Join Benefits:**
- Explicit branch exploration prevents premature convergence
- Each branch explored in isolation before synthesis
- Synthesis step forces explicit comparison and rationale
- Branch IDs provide traceability

### Step 4.3: Present Options

Display comparison table with:
- Complexity scores
- Maintainability scores
- Performance scores
- Time-to-implement estimates

Include **Recommendation** with reasoning.

### Step 4.4: Record Decision

Save `architecture_choice` to state (IMMUTABLE).

### Step 4.5: Adaptive Strategy Selection (S4)

**Purpose:** Optimize synthesis based on evaluation results.

```
IF feature_flags.s4_adaptive_strategy.enabled AND analysis_mode in {advanced, complete}:

  1. COLLECT architecture option scores from evaluation
  2. APPLY strategy selection logic from adaptive-strategy-logic.md:

     sorted_scores = sort(option_scores, descending)
     score_gap = sorted_scores[0] - sorted_scores[1]
     all_above_threshold = all(score >= 3.0 for score in option_scores)

     IF score_gap >= 0.5 AND sorted_scores[0] >= 3.0:
       strategy = SELECT_AND_POLISH
       selected_option = option with highest score
       actions = polish based on judge feedback

     ELSE IF NOT all_above_threshold:
       strategy = REDESIGN
       constraints = extract from failure feedback
       → Return to Step 4.1 with constraints (max 1 retry)

     ELSE:
       strategy = FULL_SYNTHESIS
       synthesis_plan = best elements from each option

  3. EXECUTE strategy and generate design.md
  4. LOG: "Strategy: {strategy} - {rationale}"
  5. UPDATE state.architecture.strategy_selected = strategy
```

### Step 4.6: Quality Gate - Architecture Quality (S3)

**Purpose:** Verify architecture quality before proceeding to ThinkDeep.

```
IF feature_flags.s3_judge_gates.enabled AND analysis_mode in {advanced, complete}:

  1. LAUNCH judge agent:
     Task(
       subagent_type: "product-planning:phase-gate-judge",
       prompt: """
         Evaluate Architecture Quality for feature: {FEATURE_NAME}

         Artifacts to evaluate:
         - {FEATURE_DIR}/design.md
         - {FEATURE_DIR}/spec.md (for requirement coverage)

         Use Gate 2 criteria from judge-gate-rubrics.md.
         Mode: {analysis_mode}
       """
     )

  2. PARSE verdict (same retry logic as Gate 1)

  3. UPDATE state.gate_results
```

**Checkpoint: ARCHITECTURE**

IF mode in {Complete, Advanced}: → Phase 5
ELSE: → Phase 6

---

## Phase 5: PAL ThinkDeep Analysis

### Step 5.1: Check Prerequisites

```
IF analysis_mode in {standard, rapid}: → Skip to Phase 6
IF PAL unavailable: → Skip (graceful degradation)
```

### Step 5.1b: Verify Model Availability

```
# Query available models from PAL MCP server
available_models = mcp__pal__listmodels()

# Define required models for ThinkDeep (configurable in planning-config.yaml)
required_models = ["gpt-5.2", "gemini-3-pro-preview", "openrouter/x-ai/grok-4"]

# Check availability and find alternatives if needed
model_substitutions = {}
unavailable_count = 0

FOR model IN required_models:
  IF model NOT IN available_models.models:
    LOG: "Warning: {model} unavailable"
    unavailable_count += 1

    # Try to find alternative from same provider family
    alternative = find_alternative(model, available_models.models)
    IF alternative:
      LOG: "Substituting {model} → {alternative}"
      model_substitutions[model] = alternative
    ELSE:
      LOG: "No alternative found for {model}"

# Determine if we can proceed
IF unavailable_count >= len(required_models):
  LOG: "No ThinkDeep models available - skipping to Phase 6"
  → Skip to Phase 6 (graceful degradation)

ELSE IF unavailable_count >= 2:
  LOG: "Insufficient models for full analysis - degrading to reduced ThinkDeep"
  # Continue with available models only

# Apply substitutions to models list used in Step 5.3
FOR original, substitute IN model_substitutions:
  REPLACE original with substitute in thinkdeep_models
```

### Step 5.2: Prepare Context

```
READ selected architecture: {FEATURE_DIR}/design.{selected}.md

PREPARE problem_context with:
  - Feature summary
  - Selected architecture approach
  - Codebase patterns
```

### Step 5.3: Execute ThinkDeep Matrix

| Mode | Perspectives | Models | Total Calls |
|------|--------------|--------|-------------|
| Complete | 3 (perf, maint, sec) | 3 | 9 |
| Advanced | 2 (perf, sec) | 3 | 6 |

For each perspective × model:

```
# Initialize continuation tracking per perspective
continuation_ids = {}

FOR each perspective IN [performance, maintainability, security]:
  FOR i, model IN enumerate(models):

    response = mcp__pal__thinkdeep({
      step: """
        Analyze this architecture from a {PERSPECTIVE} perspective.

        FEATURE: {FEATURE_NAME}
        ARCHITECTURE: {selected_approach}

        MY CURRENT ANALYSIS:
        {architecture_summary}

        EXTEND MY ANALYSIS - Focus on:
        {perspective_focus_areas}
      """,
      step_number: 1,
      total_steps: 1,
      next_step_required: false,
      model: "{model}",
      thinking_mode: "high",
      focus_areas: ["{perspective_focus}"],
      findings: "{initial_findings_from_architecture}",
      problem_context: "{problem_context_template}",
      relevant_files: ["{ABSOLUTE_PATH}/design.md"],
      continuation_id: continuation_ids.get(perspective) or null
    })

    # Store continuation_id for next model in same perspective
    IF i == 0:
      continuation_ids[perspective] = response.continuation_id
```

### Step 5.4: Synthesize Insights

Write `{FEATURE_DIR}/analysis/thinkdeep-insights.md`:
- Per-model findings
- **Convergent insights** (all agree) → CRITICAL priority
- **Divergent insights** (disagree) → FLAG for decision
- Recommended architecture updates

### Step 5.5: Present Findings

ASK user to:
A) Accept recommendations and update architecture
B) Review divergent points one by one
C) Proceed without changes

**Checkpoint: THINKDEEP**

---

## Phase 6: Plan Validation

### Step 6.1: PAL Consensus (Complete Mode)

IF mode == Complete AND Consensus available:

```
# Step 1: Initialize consensus workflow with models array
response = mcp__pal__consensus({
  step: """
    PLAN VALIDATION:

    Evaluate implementation plan for feature: {FEATURE_NAME}

    PLAN SUMMARY:
    {plan_summary}

    ARCHITECTURE:
    {selected_architecture}

    Score dimensions (1-5 each):
    1. Problem Understanding (20%)
    2. Architecture Quality (25%)
    3. Risk Mitigation (20%)
    4. Implementation Clarity (20%)
    5. Feasibility (15%)
  """,
  step_number: 1,
  total_steps: 4,
  next_step_required: true,
  findings: "Initial plan analysis complete.",
  models: [
    {model: "gemini-3-pro-preview", stance: "neutral", stance_prompt: "Evaluate objectively"},
    {model: "gpt-5.2", stance: "for", stance_prompt: "Advocate for strengths"},
    {model: "openrouter/x-ai/grok-4", stance: "against", stance_prompt: "Challenge weaknesses"}
  ],
  relevant_files: ["{FEATURE_DIR}/plan.md", "{FEATURE_DIR}/design.md"]
})

# Continue workflow with continuation_id until complete
WHILE response.next_step_required:
  response = mcp__pal__consensus({
    step: "Processing model response",
    step_number: response.step_number + 1,
    total_steps: 4,
    next_step_required: true,
    findings: "Model evaluation: {summary}",
    continuation_id: response.continuation_id
  })
```

### Step 6.1b: Groupthink Detection with Challenge

**Purpose:** Detect potential groupthink when all models agree too closely.

```
# Extract scores from each model's response
scores = [gemini_score, gpt_score, grok_score]
score_range = max(scores) - min(scores)

IF score_range < 0.5:  # All models agree within 0.5 points
  LOG: "GROUPTHINK WARNING: Score variance < 0.5 ({min_score}-{max_score})"

  # Use PAL Challenge to force critical examination
  challenge_response = mcp__pal__challenge({
    prompt: """
      All models scored this plan similarly ({min_score}-{max_score}/20).

      Is this genuinely well-designed, or are we missing something?

      EXAMINE CRITICALLY:
      1. Are there hidden risks not surfaced by any model?
      2. Are there alternative approaches none of the models considered?
      3. Are the scoring criteria too lenient for this problem domain?

      PLAN SUMMARY:
      {plan_summary}

      CONSENSUS RESPONSE:
      {consensus_synthesis}
    """
  })

  IF challenge_response.identifies_issues:
    # Append challenge findings to validation report
    APPEND to validation_report:
      "### Groupthink Challenge Results
       {challenge_response.analysis}"

    # Ask user if they want to address concerns
    ASK user: "Challenge analysis found potential concerns. Review before proceeding?"
    IF user wants review:
      DISPLAY challenge_response.concerns
      → Allow user to address or acknowledge

ELSE:
  LOG: "Score variance acceptable ({score_range}) - no groupthink detected"
```

### Step 6.2: Score Calculation

| Dimension | Weight | Score |
|-----------|--------|-------|
| Problem Understanding | 20% | 1-4 |
| Architecture Quality | 25% | 1-4 |
| Risk Mitigation | 20% | 1-4 |
| Implementation Clarity | 20% | 1-4 |
| Feasibility | 15% | 1-4 |

### Step 6.3: Determine Status

| Score | Status | Action |
|-------|--------|--------|
| ≥16 | GREEN | Proceed |
| 12-15 | YELLOW | Proceed with documented risks |
| <12 | RED | Revise (→ Phase 4) |

### Step 6.4: Internal Validation (Fallback)

IF Consensus not available:

```
mcp__sequential-thinking__sequentialthinking(T14: Completeness Check)
mcp__sequential-thinking__sequentialthinking(T15: Consistency Validation)
mcp__sequential-thinking__sequentialthinking(T16: Feasibility Assessment)
```

**Checkpoint: VALIDATION**

---

## Phase 6b: Expert Review (A4)

**Purpose:** Qualitative expert review of architecture and plan.

```
IF feature_flags.a4_expert_review.enabled AND analysis_mode in {advanced, complete}:

  1. LAUNCH expert review agents in parallel:

     # Security Review (blocking on CRITICAL/HIGH)
     Task(
       subagent_type: "product-planning:security-analyst",
       prompt: """
         Review architecture for security vulnerabilities.

         Artifacts:
         - {FEATURE_DIR}/design.md
         - {FEATURE_DIR}/plan.md

         Apply STRIDE methodology.
         Flag CRITICAL/HIGH findings as blocking.
       """,
       description: "Security review"
     )

     # Simplicity Review (advisory)
     Task(
       subagent_type: "product-planning:simplicity-reviewer",
       prompt: """
         Review plan for unnecessary complexity.

         Artifacts:
         - {FEATURE_DIR}/design.md
         - {FEATURE_DIR}/tasks.md

         Identify over-engineering opportunities.
         All findings are advisory.
       """,
       description: "Simplicity review"
     )

  2. CONSOLIDATE findings:
     security_findings = parse security-analyst output
     simplicity_findings = parse simplicity-reviewer output

  3. HANDLE blocking findings:
     IF any security_findings.severity in {CRITICAL, HIGH}:
       DISPLAY blocking findings to user
       ASK: "Acknowledge these security risks to proceed?"
       IF NOT acknowledged:
         → Return to Phase 4 with security constraints

  4. DISPLAY advisory findings:
     PRESENT simplicity opportunities
     ASK: "Would you like to apply any simplifications?"
     IF yes → Apply selected simplifications to tasks.md

  5. UPDATE state:
     expert_review = {
       security: {status, findings_count, blocking_count},
       simplicity: {opportunities_count, applied}
     }

  6. OUTPUT:
     Write {FEATURE_DIR}/analysis/expert-review.md with all findings
```

**Checkpoint: EXPERT_REVIEW** (only if A4 enabled)

---

## Phase 7: Test Strategy (V-Model)

### Step 7.1: Load Test Planning Context

```
READ:
  - {FEATURE_DIR}/spec.md (acceptance criteria, user stories)
  - {FEATURE_DIR}/design.md (architecture for test boundaries)
  - {FEATURE_DIR}/plan.md (implementation approach)
```

### Step 7.1b: Testing Best Practices Research (Research MCP)

**Purpose:** Fetch framework-specific testing patterns BEFORE launching QA agents.

```
IF analysis_mode in {advanced, complete}:

  1. IDENTIFY testing stack from design.md and codebase:
     test_framework = DETECT (Jest, Vitest, Playwright, Cypress, etc.)
     app_framework = EXTRACT from design.md (Next.js, Express, etc.)

  2. QUERY testing patterns:
     IF test_framework IN config.research_mcp.context7.common_library_ids:
       test_patterns = mcp__context7__query-docs(
         libraryId: config.research_mcp.context7.common_library_ids[test_framework],
         query: "{test_framework} {app_framework} testing patterns mocking async"
       )

  3. IF feature involves specific domains requiring specialized testing:

     # E2E testing patterns
     IF e2e_tests_needed:
       e2e_patterns = mcp__context7__query-docs(
         libraryId: "/microsoft/playwright",  # or cypress
         query: "Playwright {app_framework} authentication testing page objects"
       )

     # Security testing patterns
     IF security_sensitive_feature:
       security_tests = mcp__Ref__ref_search_documentation(
         query: "OWASP testing checklist web application security testing"
       )

  4. CHECK for recent testing tool updates:
     IF test_framework version is recent:
       updates = mcp__tavily__tavily_search(
         query: "{test_framework} breaking changes migration 2026",
         search_depth: "basic",
         time_range: "month"
       )

  5. INCLUDE patterns in QA agent prompts:
     testing_context = {
       test_patterns: test_patterns,
       e2e_patterns: e2e_patterns,
       security_tests: security_tests,
       source: "official documentation"
     }

ELSE:
  # Standard/Rapid mode - skip external research
  testing_context = null
```

### Step 7.2: Risk Analysis

Execute Sequential Thinking for failure point analysis:

```
mcp__sequential-thinking__sequentialthinking(T-RISK-1: Failure Mode Identification)
- Data failures: missing, malformed, stale, too large
- Integration failures: dependencies unavailable, timeouts
- State failures: race conditions, stale reads, lost updates
- User failures: invalid input, misuse, unexpected navigation

mcp__sequential-thinking__sequentialthinking(T-RISK-2: Risk Prioritization)
- Critical: Data loss, security breach, system crash
- High: Feature broken, user blocked
- Medium: Degraded experience, workaround available
- Low: Cosmetic issues, minor inconvenience

mcp__sequential-thinking__sequentialthinking(T-RISK-3: Risk to Test Mapping)
- Each Critical/High risk MUST have dedicated test coverage
```

### Step 7.3: Launch QA Agents (MPA Pattern)

Launch 3 QA agents in parallel for multi-perspective test coverage:

**Complete/Advanced modes:** All 3 agents
**Standard mode:** qa-strategist only
**Rapid mode:** qa-strategist only (minimal output)

```
# Agent 1: General Test Strategy (all modes)
Task(
  subagent_type: "product-planning:qa-strategist",
  prompt: """
    Generate V-Model test strategy for feature: {FEATURE_NAME}

    Context:
    - Spec: {FEATURE_DIR}/spec.md
    - Design: {FEATURE_DIR}/design.md
    - Plan: {FEATURE_DIR}/plan.md

    Required Output:
    1. Risk Assessment with test mapping
    2. Unit Test Specifications (TDD-ready)
    3. Integration Test Specifications
    4. E2E Test Scenarios
    5. UAT Scripts (Given-When-Then)
    6. Coverage Matrix
  """,
  description: "Generate V-Model test plan"
)

# Agent 2: Security Test Focus (Complete/Advanced modes)
Task(
  subagent_type: "product-planning:qa-security",
  prompt: """
    Generate security-focused test specifications for feature: {FEATURE_NAME}

    Context:
    - Spec: {FEATURE_DIR}/spec.md
    - Design: {FEATURE_DIR}/design.md
    - ThinkDeep Security Insights: {FEATURE_DIR}/analysis/thinkdeep-insights.md (if exists)

    Required Output:
    1. STRIDE Threat Assessment
    2. Authentication Test Cases
    3. Authorization Test Cases
    4. Input Validation Test Cases
    5. Security Edge Cases
    6. Reconciliation with Phase 5 ThinkDeep findings
  """,
  description: "Generate security tests"
)

# Agent 3: Performance Test Focus (Complete/Advanced modes)
Task(
  subagent_type: "product-planning:qa-performance",
  prompt: """
    Generate performance-focused test specifications for feature: {FEATURE_NAME}

    Context:
    - Spec: {FEATURE_DIR}/spec.md
    - Design: {FEATURE_DIR}/design.md
    - ThinkDeep Performance Insights: {FEATURE_DIR}/analysis/thinkdeep-insights.md (if exists)

    Required Output:
    1. Performance Requirements (latency, load targets)
    2. Response Time Test Cases
    3. Load Test Scenarios
    4. Stress Test Scenarios
    5. Resource Monitoring Points
    6. Reconciliation with Phase 5 ThinkDeep findings
  """,
  description: "Generate performance tests"
)
```

Output to:
- `{FEATURE_DIR}/analysis/test-strategy-general.md`
- `{FEATURE_DIR}/analysis/test-strategy-security.md`
- `{FEATURE_DIR}/analysis/test-strategy-performance.md`

### Step 7.3.1: Risk Reconciliation with ST Revision

**Purpose:** Ensure Phase 5 ThinkDeep security/performance insights are aligned with Phase 7 test risk analysis using ST Revision.

```
IF {FEATURE_DIR}/analysis/thinkdeep-insights.md exists:

  1. EXTRACT security findings from ThinkDeep:
     - Identified threats (STRIDE categories)
     - Compliance requirements
     - Vulnerability concerns

  2. EXTRACT performance findings from ThinkDeep:
     - Scalability bottlenecks
     - Latency concerns
     - Resource efficiency issues

  3. CHECK for contradictions with T-RISK-2 output:
     has_contradictions = compare(thinkdeep_findings, t_risk_2_output)

  4. IF has_contradictions AND feature_flags.st_revision_reconciliation.enabled:

     # Invoke ST Revision to reconcile
     mcp__sequential-thinking__sequentialthinking({
       thought: "REVISION of Risk Prioritization: ThinkDeep identified...",
       thoughtNumber: 2,
       totalThoughts: 3,
       nextThoughtNeeded: true,
       isRevision: true,
       revisesThought: 2,  # References T-RISK-2
       hypothesis: "Phase 5 insights update risk; {N} conflicts resolved",
       confidence: "high"
     })

     # Update test-plan.md with reconciliation section
     WRITE reconciliation report to test-plan.md

  5. ELSE (no contradictions or flag disabled):
     # Manual reconciliation fallback
     FOR each gap (ThinkDeep finding without test coverage):
       - Add new risk to Phase 7 risk list
       - Generate corresponding test case
       - Update coverage matrix

     FOR each conflict (different severity assessment):
       - Document both assessments
       - Use higher severity as default
       - FLAG for human decision if significantly different

ELSE:
  SKIP reconciliation (Phase 5 not executed in Standard/Rapid modes)
```

**Reconciliation Output:** Add section to test-plan.md:

```markdown
## Phase 5 ↔ Phase 7 Reconciliation

### ThinkDeep Security Insights → Test Coverage
| Insight | Severity | Test ID | Status |
|---------|----------|---------|--------|
| {insight} | {sev} | SEC-XX | ✅ Covered |

### ThinkDeep Performance Insights → Test Coverage
| Insight | Severity | Test ID | Status |
|---------|----------|---------|--------|
| {insight} | {sev} | PERF-XX | ✅ Covered |

### Gaps Addressed
- {gap description} → Added {test_id}

### Conflicts Flagged
- {conflict description} → Using {resolution}

### ST Revision Applied
- isRevision: {true/false}
- revisesThought: {thought_number or N/A}
- Conflicts resolved: {count}
```

### Step 7.3.2: Red Team Branch (Complete/Advanced)

**Purpose:** Add adversarial perspective to risk analysis by thinking like an attacker.

```
IF analysis_mode in {Complete, Advanced} AND feature_flags.st_redteam_analysis.enabled:

  1. INVOKE Red Team branch:
     mcp__sequential-thinking__sequentialthinking({
       thought: "BRANCH: Red Team. ATTACKER PERSPECTIVE: Entry points...",
       thoughtNumber: 2,
       totalThoughts: 4,
       nextThoughtNeeded: true,
       branchFromThought: 1,  # Branches from T-RISK-1
       branchId: "redteam",
       hypothesis: "Adversarial analysis reveals {N} additional vectors",
       confidence: "medium"
     })

  2. SYNTHESIZE red team findings:
     mcp__sequential-thinking__sequentialthinking({
       thought: "SYNTHESIS: Merging red team findings. NEW ATTACKS...",
       thoughtNumber: 3,
       totalThoughts: 4,
       nextThoughtNeeded: true,
       hypothesis: "Red team adds {N} new test cases",
       confidence: "high"
     })

  3. ADD red team findings to test plan:
     - New attack vectors → Security test cases
     - Overlooked entry points → Additional E2E scenarios
     - Update coverage matrix with SEC-RT-XX IDs

ELSE:
  SKIP red team (not enabled or Standard/Rapid mode)
```

**Red Team Focus Areas:**
- Input validation bypasses
- Authentication/authorization weaknesses
- Data exfiltration paths
- Service disruption vectors
- Injection vulnerabilities (SQL, XSS, command)

### Step 7.3.3: TAO Loop for QA Synthesis

```
IF feature_flags.st_tao_loops.enabled:

  AFTER all QA agents (qa-strategist, qa-security, qa-performance) complete:
    mcp__sequential-thinking__sequentialthinking(T-AGENT-ANALYSIS)
    mcp__sequential-thinking__sequentialthinking(T-AGENT-SYNTHESIS)
    mcp__sequential-thinking__sequentialthinking(T-AGENT-VALIDATION)

  MERGE findings:
    - Convergent → Incorporate directly into test-plan.md
    - Divergent → Present to user for decision OR use higher severity
    - Gaps → Document as known testing gaps
```

### Step 7.3.5: Synthesize QA Agent Outputs

After all QA agents complete AND reconciliation is done:

1. **Merge test cases** - Combine into unified test-plan.md
2. **Deduplicate** - Remove duplicate test coverage
3. **Prioritize** - Use convergent findings (all agents agree) as highest priority
4. **Flag conflicts** - Note where agents disagree for human decision
5. **Verify reconciliation** - All ThinkDeep insights have test coverage

### Step 7.4: Generate UAT Scripts

For each user story in spec.md, generate:

```markdown
## UAT-{id}: {Story Title}

**User Story:** As a {persona}, I want {action} so that {benefit}

**Given:** {preconditions}
**When:** {user actions}
**Then:** {expected outcomes}

**Test Data:** {specific data needed}

**Evidence Checklist:**
- [ ] Screenshot of initial state
- [ ] Screenshot of action
- [ ] Screenshot of result
- [ ] User confirmation
```

### Step 7.5: Structure Test Directories

```
CREATE {FEATURE_DIR}/test-cases/unit/ if not exists
CREATE {FEATURE_DIR}/test-cases/integration/ if not exists
CREATE {FEATURE_DIR}/test-cases/e2e/ if not exists
CREATE {FEATURE_DIR}/test-cases/uat/ if not exists

WRITE unit test specs to test-cases/unit/
WRITE integration test specs to test-cases/integration/
WRITE e2e scenarios to test-cases/e2e/
WRITE uat scripts to test-cases/uat/
```

### Step 7.6: Generate Test Plan Document

Write `{FEATURE_DIR}/test-plan.md` using template from `$CLAUDE_PLUGIN_ROOT/templates/test-plan-template.md`

### Step 7.7: Quality Gate - Test Coverage (S3)

**Purpose:** Verify test coverage quality before coverage validation.

```
IF feature_flags.s3_judge_gates.enabled AND analysis_mode in {advanced, complete}:

  1. LAUNCH judge agent:
     Task(
       subagent_type: "product-planning:phase-gate-judge",
       prompt: """
         Evaluate Test Coverage for feature: {FEATURE_NAME}

         Artifacts to evaluate:
         - {FEATURE_DIR}/test-plan.md
         - {FEATURE_DIR}/spec.md (for AC coverage check)
         - {FEATURE_DIR}/analysis/test-strategy-*.md

         Use Gate 3 criteria from judge-gate-rubrics.md.
         Mode: {analysis_mode}
       """
     )

  2. PARSE verdict (same retry logic as Gates 1 and 2)

  3. UPDATE state.gate_results
```

**Checkpoint: TEST_STRATEGY**

---

## Phase 8: Test Coverage Validation

### Step 8.1: Prepare Coverage Matrix

```
COLLECT all acceptance criteria from spec.md
COLLECT all identified risks from Phase 7
COLLECT all user stories from spec.md

MAP each AC to test IDs
MAP each risk to mitigation tests
MAP each story to UAT script
```

### Step 8.2: PAL Consensus Validation (Complete/Advanced)

IF mode in {Complete, Advanced} AND Consensus available:

```
# Step 1: Initialize test coverage consensus workflow
response = mcp__pal__consensus({
  step: """
    TEST COVERAGE VALIDATION:

    Evaluate test coverage completeness for feature: {FEATURE_NAME}

    TEST PLAN SUMMARY:
    {test_plan_summary}

    COVERAGE MATRIX:
    {coverage_matrix}

    Score dimensions (weighted percentage):
    1. AC Coverage (25%) - All acceptance criteria mapped to tests
    2. Risk Coverage (25%) - All Critical/High risks have tests
    3. UAT Completeness (20%) - Scripts clear for non-technical users
    4. Test Independence (15%) - Tests can run in isolation
    5. Maintainability (15%) - Tests verify behavior, not implementation
  """,
  step_number: 1,
  total_steps: 4,
  next_step_required: true,
  findings: "Initial test coverage analysis complete.",
  models: [
    {model: "gemini-3-pro-preview", stance: "neutral", stance_prompt: "Evaluate test coverage objectively"},
    {model: "gpt-5.2", stance: "for", stance_prompt: "Highlight test coverage strengths"},
    {model: "openrouter/x-ai/grok-4", stance: "against", stance_prompt: "Find coverage gaps and missing edge cases"}
  ],
  relevant_files: ["{FEATURE_DIR}/test-plan.md", "{FEATURE_DIR}/spec.md"]
})

# Continue workflow with continuation_id until complete
WHILE response.next_step_required:
  response = mcp__pal__consensus({
    step: "Processing model response",
    step_number: response.step_number + 1,
    total_steps: 4,
    next_step_required: true,
    findings: "Model evaluation: {summary}",
    continuation_id: response.continuation_id
  })
```

### Step 8.3: Score Calculation

| Dimension | Weight | Criteria |
|-----------|--------|----------|
| AC Coverage | 25% | All acceptance criteria mapped to tests |
| Risk Coverage | 25% | All Critical/High risks have tests |
| UAT Completeness | 20% | Scripts are clear for non-technical users |
| Test Independence | 15% | Tests can run in isolation |
| Maintainability | 15% | Tests verify behavior, not implementation |

### Step 8.4: Determine Status

| Score | Status | Action |
|-------|--------|--------|
| ≥80% | GREEN | Proceed to completion |
| 65-79% | YELLOW | Proceed with documented gaps |
| <65% | RED | Return to Phase 7 |

### Step 8.5: Internal Validation (Fallback)

IF Consensus not available:

```
Self-Assessment Checklist:
- [ ] Every AC has at least one test
- [ ] Every Critical risk has mitigation test
- [ ] Every High risk has mitigation test
- [ ] UAT scripts use Given-When-Then
- [ ] UAT scripts have evidence checklists
- [ ] Tests don't depend on each other
```

### Step 8.6: Generate Coverage Report

Write `{FEATURE_DIR}/analysis/test-coverage-validation.md`

**Checkpoint: TEST_COVERAGE_VALIDATION**

IF status == RED: → Return to Phase 7

---

## Phase 9: Completion

### Step 9.1: Generate Final Artifacts

Launch agents for final documents:

```
Task(subagent_type: "product-planning:software-architect", prompt: "Create final design.md...")
Task(subagent_type: "product-planning:tech-lead", prompt: "Break down into tasks with TDD structure...")
```

### Step 9.2: Structure Tasks with TDD

For each implementation task, structure as:

```markdown
## Task: {component_name}

### 1. TEST (RED)
- Write failing unit tests: UT-{ids}
- Verify tests fail for right reason

### 2. IMPLEMENT (GREEN)
- Write minimal code to pass tests
- Run tests, verify GREEN

### 3. VERIFY
- Run integration tests: INT-{ids}
- Code review

### Dependencies
- Blocked by: {task_ids}
- Blocks: {task_ids}
- Test refs: UT-{ids}, INT-{ids}
```

### Step 9.3: Output Artifacts

| Artifact | Content |
|----------|---------|
| `design.md` | Final architecture |
| `plan.md` | Implementation plan |
| `tasks.md` | Task breakdown with TDD structure |
| `test-plan.md` | V-Model test strategy |
| `test-cases/` | Test specifications by level |
| `data-model.md` | Entity definitions (optional) |
| `contract.md` | API contracts (optional) |

### Step 9.4: Generate Summary Report

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    PLANNING COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Feature: {FEATURE_NAME}
Mode: {analysis_mode}

Architecture:
├── Design: {selected_approach}
├── Validation: {GREEN/YELLOW} ({score}/20)

Test Strategy (V-Model):
├── Unit Tests: {count} (TDD-ready)
├── Integration Tests: {count}
├── E2E Tests: {count}
├── UAT Scripts: {count}
├── Coverage: {GREEN/YELLOW} ({score}%)

Tasks: {task_count} structured as TEST → IMPLEMENT → VERIFY

Artifacts Generated:
├── design.md
├── plan.md
├── tasks.md
├── test-plan.md
└── test-cases/{unit,integration,e2e,uat}/

Next Steps:
1. Review artifacts
2. Commit: git add . && git commit -m "feat: plan {FEATURE_NAME}"
3. Begin TDD: Start with unit tests (RED phase)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 9.5: Cleanup

```
DELETE lock file
UPDATE state to COMPLETED
DISPLAY summary report
```

### Step 9.6: Post-Planning Menu (A5)

**Purpose:** Provide structured options for next steps after planning completion.

```
IF feature_flags.a5_post_planning_menu.enabled:

  DISPLAY:
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                      WHAT WOULD YOU LIKE TO DO NEXT?
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. [Review]   Open artifacts in editor for review
  2. [Expert]   Get expert review (security + simplicity)
  3. [Simplify] Reduce plan complexity
  4. [GitHub]   Create GitHub issue from plan
  5. [Commit]   Commit all planning artifacts
  6. [Quit]     Exit planning session

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  USE AskUserQuestion to present options
```

**Option Handlers:**

**1. Review:**
```
OPEN {FEATURE_DIR}/design.md in editor
OPEN {FEATURE_DIR}/plan.md in editor
OPEN {FEATURE_DIR}/tasks.md in editor
SUGGEST: "Review artifacts and let me know if you'd like changes"
```

**2. Expert Review:**
```
IF analysis_mode in {complete, advanced}:
  LAUNCH security-analyst agent → review design.md + plan.md
  LAUNCH simplicity-reviewer agent → review tasks.md
  CONSOLIDATE feedback
  PRESENT findings to user
ELSE:
  DISPLAY: "Expert review available in Advanced/Complete modes"
```

**3. Simplify:**
```
ANALYZE tasks.md for:
  - Tasks that can be combined
  - Phases that can be merged
  - Complexity that can be deferred
PRESENT simplification options
IF user approves → UPDATE tasks.md
```

**4. GitHub Issue:**
```
READ template from $CLAUDE_PLUGIN_ROOT/templates/github-issue-template.md
EXTRACT values from:
  - {FEATURE_DIR}/spec.md (ACs)
  - {FEATURE_DIR}/design.md (architecture decisions)
  - {FEATURE_DIR}/tasks.md (task summary)
  - {FEATURE_DIR}/test-plan.md (test counts)
GENERATE issue body
RUN: gh issue create --title "{title}" --body "{body}"
DISPLAY: Issue URL
```

**5. Commit:**
```
STAGE files:
  - {FEATURE_DIR}/design.md
  - {FEATURE_DIR}/plan.md
  - {FEATURE_DIR}/tasks.md
  - {FEATURE_DIR}/test-plan.md
  - {FEATURE_DIR}/research.md (if exists)
  - {FEATURE_DIR}/analysis/*.md
  - {FEATURE_DIR}/test-cases/**/*.md

COMMIT with message:
  "feat(planning): complete plan for {FEATURE_NAME}

  Architecture: {selected_approach}
  Tasks: {task_count}
  Test Coverage: {coverage_status}

  Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

**6. Quit:**
```
DISPLAY: "Planning session complete. Artifacts saved to {FEATURE_DIR}/"
EXIT
```

**Checkpoint: COMPLETION**
