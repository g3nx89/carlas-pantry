---
phase: "4"
phase_name: "Architecture Design"
checkpoint: "ARCHITECTURE"
delegation: "coordinator"
modes: [complete, advanced, standard, rapid]
prior_summaries:
  - ".phase-summaries/phase-2-summary.md"
  - ".phase-summaries/phase-3-summary.md"
artifacts_read:
  - "spec.md"
  - "research.md"
artifacts_written:
  - "design.minimal.md"
  - "design.clean.md"
  - "design.pragmatic.md"
  - "design.md"
  - ".phase-summaries/phase-4-skill-context.md"  # conditional: dev_skills_integration enabled
agents:
  - "product-planning:software-architect"
  - "product-planning:wildcard-architect"
  - "product-planning:architecture-pruning-judge"
  - "product-planning:phase-gate-judge"
mcp_tools:
  - "mcp__sequential-thinking__sequentialthinking"
  - "mcp__context7__query-docs"
  - "mcp__Ref__ref_search_documentation"
  - "mcp__tavily__tavily_search"
feature_flags:
  - "s5_tot_architecture"
  - "s4_adaptive_strategy"
  - "s3_judge_gates"
  - "st_fork_join_architecture"
  - "st_tao_loops"
  - "dev_skills_integration"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/tot-workflow.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/adaptive-strategy-logic.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/research-mcp-patterns.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/skill-loader-pattern.md"
---

# Phase 4: Architecture Design

> **COORDINATOR INSTRUCTIONS**
> You are a phase coordinator dispatched by the lean orchestrator.
> 1. Read this file completely for your phase instructions.
> 2. Read the prior phase summaries listed in `prior_summaries` frontmatter from `{FEATURE_DIR}/.phase-summaries/`.
> 3. Read the artifacts listed in `artifacts_read` frontmatter from `{FEATURE_DIR}/`.
> 4. Execute ALL steps below for the current `analysis_mode`.
> 5. Write your output artifacts to `{FEATURE_DIR}/`.
> 6. Write your phase summary to `{FEATURE_DIR}/.phase-summaries/phase-4-summary.md` using the template at `$CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md`.
> 7. You MUST NOT interact with the user directly. If user input is needed, set `status: needs-user-input` in your summary with `block_reason` explaining what is needed and what options are available.
> 8. If a sub-agent (Task) fails, retry once. If it fails again, continue with partial results and set `flags.degraded: true` in your summary.

## Step 4.0a: Dev-Skills Context Loading (Subagent)

**Purpose:** Load domain expertise from dev-skills plugin before launching architect agents. Runs IN PARALLEL with Step 4.0 Research MCP queries.

**Reference:** `$CLAUDE_PLUGIN_ROOT/skills/plan/references/skill-loader-pattern.md`

```
IF state.dev_skills.available AND analysis_mode != "rapid":

  DISPATCH Task(subagent_type="general-purpose", prompt="""
    You are a skill context loader for Phase 4 (Architecture Design).

    Detected domains: {state.dev_skills.detected_domains}
    Technology markers: {state.dev_skills.technology_markers}

    Load the following skills and extract ONLY the specified sections:

    1. IF "architecture" in domains:
       Skill("dev-skills:api-patterns") → extract:
         - API style decision tree (REST vs GraphQL vs tRPC)
         - Authentication pattern summary
         - OWASP API Top 10 checklist
       LIMIT: 1200 tokens

    2. IF "database" in domains:
       Skill("dev-skills:database-design") → extract:
         - Database selection decision tree
         - ORM comparison table (Drizzle vs Prisma vs Kysely)
       LIMIT: 800 tokens

       Skill("dev-skills:database-schema-designer") → extract:
         - Normalization principles + anti-patterns
       LIMIT: 600 tokens

    3. IF "frontend" in domains:
       Skill("dev-skills:frontend-design") → extract:
         - Decision framework for aesthetic direction
       Skill("dev-skills:web-design-guidelines") → extract:
         - Code quality rules (semantic HTML, CSS custom props)
       LIMIT: 800 tokens combined

    4. Skill("dev-skills:c4-architecture") → extract:
       - C4 diagram level definitions
       - Mermaid C4 syntax examples
       LIMIT: 600 tokens

    5. Skill("dev-skills:mermaid-diagrams") → extract:
       - Quick start examples for architecture diagrams
       LIMIT: 400 tokens

    WRITE condensed output to: {FEATURE_DIR}/.phase-summaries/phase-4-skill-context.md
    FORMAT: YAML frontmatter + markdown sections per skill
    TOTAL BUDGET: 3000 tokens max
    IF any Skill() call fails → log in skills_failed, continue with remaining
  """)

  # READ result AFTER both 4.0a and 4.0 complete
  READ {FEATURE_DIR}/.phase-summaries/phase-4-skill-context.md
  IF file exists AND not empty:
    INJECT relevant sections into architect agent prompts (Step 4.1) as:
    "## Domain Reference (from dev-skills)\n{section content}"
```

## Step 4.0: Architecture Pattern Research (Research MCP)

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

## Step 4.1: Standard MPA Architecture

**Standard/Advanced modes (when S5 ToT disabled):** Launch 3 architecture agents (MPA) in parallel:

```
Task(subagent_type: "product-planning:software-architect", prompt: "MINIMAL CHANGE focus...")
Task(subagent_type: "product-planning:software-architect", prompt: "CLEAN ARCHITECTURE focus...")
Task(subagent_type: "product-planning:software-architect", prompt: "PRAGMATIC BALANCE focus...")
```

Output to:
- `{FEATURE_DIR}/design.minimal.md`
- `{FEATURE_DIR}/design.clean.md`
- `{FEATURE_DIR}/design.pragmatic.md`

### Step 4.1-alt: Hybrid ToT-MPA Workflow (S5)

**Complete mode only. Feature flag: `s5_tot_architecture` (requires: `s4_adaptive_strategy`)**

1. **Phase 4a: Seeded Exploration** — Generate 8 approaches:
   - Minimal perspective: 2 seeded
   - Clean perspective: 2 seeded
   - Pragmatic perspective: 2 seeded
   - Wildcard: 2 unconstrained (via product-planning:wildcard-architect)
2. **Phase 4b: Multi-Criteria Pruning** — 3 architecture-pruning-judge agents evaluate all 8, select top 4
3. **Phase 4c: Competitive Expansion** — 4 agents develop full designs
4. **Phase 4d: Evaluation + Adaptive Selection** — Apply S4 strategy:
   - SELECT_AND_POLISH: Clear winner (gap >=0.5, score >=3.0)
   - FULL_SYNTHESIS: Tie (all >=3.0, gap <0.5)
   - REDESIGN: All weak (any <3.0) → Return to 4a

Reference: `$CLAUDE_PLUGIN_ROOT/skills/plan/references/tot-workflow.md`
Reference: `$CLAUDE_PLUGIN_ROOT/skills/plan/references/adaptive-strategy-logic.md`

## Step 4.2: TAO Loop Analysis (After MPA Agents)

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
    FLAG divergent_findings for user decision in Step 4.4

ELSE:
  # Skip TAO loop, proceed directly to Step 4.3
```

**TAO Loop Purpose:**
- Prevents rushed synthesis of conflicting agent perspectives
- Explicitly categorizes findings before merging
- Provides structured pause for reflection

## Step 4.3: Sequential Thinking with Fork-Join (Complete Mode)

IF mode == Complete AND ST available:

```
# Check feature flag for Fork-Join
IF feature_flags.st_fork_join_architecture.enabled:

  # Phase 4.3a: Frame the decision point
  mcp__sequential-thinking__sequentialthinking(T7a_FRAME)

  # Phase 4.3b: Parallel branches (logically parallel, sequential execution)
  mcp__sequential-thinking__sequentialthinking(T7b_BRANCH_MINIMAL)
  mcp__sequential-thinking__sequentialthinking(T7c_BRANCH_CLEAN)
  mcp__sequential-thinking__sequentialthinking(T7d_BRANCH_PRAGMATIC)

  # Phase 4.3c: Join and synthesize
  mcp__sequential-thinking__sequentialthinking(T8_SYNTHESIS)

  # Phase 4.3d: Continue with selected approach
  mcp__sequential-thinking__sequentialthinking(T9: Component Design)
  mcp__sequential-thinking__sequentialthinking(T10: Acceptance Criteria Mapping)

ELSE:
  # Fallback to linear T7-T10
  mcp__sequential-thinking__sequentialthinking(T7: Option Generation)
  mcp__sequential-thinking__sequentialthinking(T8: Trade-off Analysis)
  mcp__sequential-thinking__sequentialthinking(T9: Component Design)
  mcp__sequential-thinking__sequentialthinking(T10: Acceptance Criteria Mapping)
```

**Fork-Join Architecture Pattern:**
```
┌─────────────────────────────────────────────────────────────────┐
│                     FORK-JOIN ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐                                                 │
│  │  T7a_FRAME  │  ← Frame decision, spawn branches              │
│  └──────┬──────┘                                                 │
│         │                                                        │
│    ┌────┴────┬────────────┐                                     │
│    ↓         ↓            ↓                                     │
│ ┌──────┐ ┌──────┐ ┌──────────┐                                  │
│ │T7b   │ │T7c   │ │T7d       │  ← Parallel exploration         │
│ │MINIMAL│ │CLEAN │ │PRAGMATIC │    (branchId per path)         │
│ └──┬───┘ └──┬───┘ └────┬─────┘                                  │
│    │        │          │                                        │
│    └────────┴──────────┘                                        │
│              ↓                                                   │
│      ┌────────────┐                                              │
│      │T8_SYNTHESIS│  ← Join and synthesize                      │
│      └──────┬─────┘                                              │
│             ↓                                                    │
│    Continue with T9, T10 using selected approach                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Fork-Join Benefits:**
- Explicit branch exploration prevents premature convergence
- Each branch explored in isolation before synthesis
- Synthesis step forces explicit comparison and rationale
- Branch IDs provide traceability

## Step 4.3c: Risk Assessment for Selected Architecture (Advanced/Complete)

**Purpose:** Apply structured risk analysis (T11-T13) to the architecture options BEFORE presenting to user.

```
IF analysis_mode in {advanced, complete} AND mcp__sequential-thinking__sequentialthinking available:

  # After architecture options are generated but BEFORE user selection
  # Consolidated risk assessment: single 5-thought chain covering all options
  # Uses RISK-C (Consolidated) naming to avoid collision with template IDs T11-T16

  # RISK-C1: Frame risk assessment across all options
  mcp__sequential-thinking__sequentialthinking({
    thought: "RISK ASSESSMENT FRAME for all architecture options. OPTIONS: [minimal, clean, pragmatic]. RISK CATEGORIES: Technical (complexity, unknowns), Integration (API, migration, external), Schedule (dependencies, learning curve), Security (attack surfaces, compliance). Analyzing each option against all categories.",
    thoughtNumber: 1,
    totalThoughts: 5,
    nextThoughtNeeded: true
  })

  # RISK-C2: Risk Identification per option
  mcp__sequential-thinking__sequentialthinking({
    thought: "RISK IDENTIFICATION across all options. MINIMAL: TECHNICAL: [list], INTEGRATION: [list], SCHEDULE: [list], SECURITY: [list]. CLEAN: TECHNICAL: [list], INTEGRATION: [list], SCHEDULE: [list], SECURITY: [list]. PRAGMATIC: TECHNICAL: [list], INTEGRATION: [list], SCHEDULE: [list], SECURITY: [list]. TOTAL RISKS: minimal={N}, clean={M}, pragmatic={P}. HYPOTHESIS: {option} has highest risk count due to {reason}. CONFIDENCE: medium.",
    thoughtNumber: 2,
    totalThoughts: 5,
    nextThoughtNeeded: true
  })

  # RISK-C3: Risk Prioritization per option
  mcp__sequential-thinking__sequentialthinking({
    thought: "RISK PRIORITIZATION using probability x impact. MINIMAL: Critical=[list], Monitor=[list], Accept=[list], SCORE={X}/10. CLEAN: Critical=[list], Monitor=[list], Accept=[list], SCORE={Y}/10. PRAGMATIC: Critical=[list], Monitor=[list], Accept=[list], SCORE={Z}/10. HYPOTHESIS: {option} has lowest risk score, critical risks concentrated in {area}. CONFIDENCE: high.",
    thoughtNumber: 3,
    totalThoughts: 5,
    nextThoughtNeeded: true
  })

  # RISK-C4: Mitigation strategies for critical risks
  mcp__sequential-thinking__sequentialthinking({
    thought: "MITIGATION STRATEGIES for critical risks across options. MINIMAL: [risk → mitigation pairs], effort={low|med|high}, residual={low|med|high}. CLEAN: [risk → mitigation pairs], effort={low|med|high}, residual={low|med|high}. PRAGMATIC: [risk → mitigation pairs], effort={low|med|high}, residual={low|med|high}. HYPOTHESIS: Mitigations reduce critical count by {N}, {option} has lowest residual risk. CONFIDENCE: high.",
    thoughtNumber: 4,
    totalThoughts: 5,
    nextThoughtNeeded: true
  })

  # RISK-C5: Cross-option comparison and recommendation
  mcp__sequential-thinking__sequentialthinking({
    thought: "RISK COMPARISON COMPLETE. RANKINGS: 1. {lowest_risk_option} (score: X/10, critical: N), 2. {middle_option} (score: Y/10, critical: M), 3. {highest_risk_option} (score: Z/10, critical: P). RECOMMENDATION ADJUSTMENT: {if risk changes recommendation from trade-off analysis}. HYPOTHESIS: Risk analysis informs architecture recommendation.",
    thoughtNumber: 5,
    totalThoughts: 5,
    nextThoughtNeeded: false
  })

  # Include risk summary in architecture comparison table
  ADD risk_scores to comparison_table
  ADD critical_risks_count to comparison_table
  ADD mitigation_effort to comparison_table

ELSE IF analysis_mode == standard:
  # Skip ST-based risk assessment
  # Use simpler heuristic-based risk indicators
  ESTIMATE risks based on:
    - Pattern alignment (matches existing = low risk)
    - Component count (more = higher risk)
    - Integration points (more = higher risk)
```

**Risk Assessment Output:** Adds these columns to architecture comparison:

| Option | Risk Score | Critical Risks | Mitigation Effort |
|--------|------------|----------------|-------------------|
| Minimal | X/10 | N | Low/Med/High |
| Clean | Y/10 | M | Low/Med/High |
| Pragmatic | Z/10 | P | Low/Med/High |

## Step 4.4: Present Options

Display comparison table with:
- Complexity scores
- Maintainability scores
- Performance scores
- Time-to-implement estimates
- **Risk scores** (from Step 4.3c, Advanced/Complete modes)
- **Critical risks count** (from Step 4.3c)
- **Mitigation effort** (from Step 4.3c)

Include **Recommendation** with reasoning that considers:
1. Trade-off analysis from T8
2. Risk assessment from T11-T13 (if available)
3. Pattern alignment from research phase

## Step 4.5: Record Architecture Decision

**USER INTERACTION:** The user must select an architecture option.

Set `status: needs-user-input` in your summary with:
- `block_reason`: The comparison table and recommendation, asking user to select an option
- Include all option names and key differentiators
- Provide a clear default recommendation

On re-dispatch after user input, read `{FEATURE_DIR}/.phase-summaries/phase-4-user-input.md` for the selection.

Save `architecture_choice` to decisions (IMMUTABLE).

## Step 4.6: Adaptive Strategy Selection (S4)

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

## Step 4.7: Quality Gate - Architecture Quality (S3)

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
