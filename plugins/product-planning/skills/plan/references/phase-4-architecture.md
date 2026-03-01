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
  - "spec.md"          # requirements context: acceptance criteria, user stories, constraints
  - "research.md"
artifacts_written:
  - "design.grounding.md"
  - "design.ideality.md"
  - "design.resilience.md"
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
  - "deep_reasoning_escalation"  # algorithm awareness: flag difficulty for orchestrator
  - "s7_mpa_deliberation"
  - "s8_convergence_detection"
  - "s10_team_presets"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/tot-workflow.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/adaptive-strategy-logic.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/research-mcp-patterns.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/skill-loader-pattern.md"
---

<!-- Mode Applicability -->
| Step | Rapid | Standard | Advanced | Complete | Notes |
|------|-------|----------|----------|----------|-------|
| 4.1   | —     | ✓        | ✓        | ✓        | `(dev_skills_integration)`, parallel with 4.3 |
| 4.2   | ✓     | ✓        | ✓        | ✓        | — |
| 4.3   | —     | —        | ✓        | ✓        | Research MCP, parallel with 4.1 |
| 4.4   | ✓     | ✓        | ✓        | ✓        | Agent count varies by mode; `(s10_team_presets)` |
| 4.5   | —     | —        | —        | ✓        | `(s5_tot_architecture)`, ALT to 4.4 |
| 4.6   | —     | —        | ✓        | ✓        | `(s7_mpa_deliberation)` |
| 4.7   | —     | —        | ✓        | ✓        | `(s8_convergence_detection)` |
| 4.8   | —     | ✓        | ✓        | ✓        | `(st_tao_loops)` |
| 4.9   | —     | —        | —        | ✓        | Requires ST MCP; `(st_fork_join_architecture)` |
| 4.10  | —     | ✓        | ✓        | ✓        | ST for Adv/Complete; heuristic for Standard |
| 4.11  | ✓     | ✓        | ✓        | ✓        | — |
| 4.12  | ✓     | ✓        | ✓        | ✓        | User interaction |
| 4.13  | —     | —        | ✓        | ✓        | `(s4_adaptive_strategy)` |
| 4.14  | —     | —        | ✓        | ✓        | `(s3_judge_gates)` |

# Phase 4: Architecture Design

> **Algorithm Awareness:** If `state.deep_reasoning.algorithm_detected == true`, the
> architecture options should explicitly address the algorithmic complexity identified
> in Phase 1 (keywords: `state.deep_reasoning.algorithm_keywords`). If the architect
> agents cannot adequately design for the algorithm requirement, set
> `flags.algorithm_difficulty: true` in the phase summary so the orchestrator can
> consider deep reasoning escalation if the architecture gate fails.

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

## Decision Protocol
When `a6_context_protocol` is enabled (check feature flags):
1. **RESPECT** all prior key decisions — do not contradict HIGH-confidence decisions without explicit justification.
2. **CHECK** open questions — if your analysis resolves any, include the resolution in your `key_decisions`.
3. **CONTRIBUTE** your findings as `key_decisions`, `open_questions`, and `risks_identified` in your phase summary YAML.

## Step 4.1 [PARALLEL]: Dev-Skills Context Loading (Subagent)

**Purpose:** Load domain expertise from dev-skills plugin before launching architect agents. Steps 4.1 and 4.3 execute IN PARALLEL. Wait for both to complete before proceeding to Step 4.4.

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

  # READ result AFTER both 4.1 and 4.3 complete
  READ {FEATURE_DIR}/.phase-summaries/phase-4-skill-context.md
  IF file exists AND not empty:
    INJECT relevant sections into architect agent prompts (Step 4.4) as:
    "## Domain Reference (from dev-skills)\n{section content}"
```

## Step 4.2: Load Requirements Context

```
# Prefer requirements-anchor.md (consolidates spec + user clarifications from Phase 3)
# Fall back to raw spec.md if anchor not available or empty

IF file_exists({FEATURE_DIR}/requirements-anchor.md) AND not_empty({FEATURE_DIR}/requirements-anchor.md):
  requirements_file = "{FEATURE_DIR}/requirements-anchor.md"
  LOG: "Requirements context: using requirements-anchor.md (enriched)"
ELSE:
  requirements_file = "{FEATURE_DIR}/spec.md"
  LOG: "Requirements context: using spec.md (raw)"

# Use requirements_file as the source for acceptance criteria, user stories,
# and constraints when preparing architect agent prompts (Step 4.4)
```

## Step 4.3 [PARALLEL]: Architecture Pattern Research (Research MCP)

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

## Step 4.4: Standard MPA Architecture

```
# S5: Team Preset filtering (s10_team_presets)
IF feature_flags.s10_team_presets.enabled AND state.team_preset == "rapid_prototype":
  # Only dispatch software-architect (skip wildcard, pruning judge)
  AGENT_LIST = ["product-planning:software-architect"]
  LOG: "Team preset rapid_prototype: dispatching software-architect only"
ELSE:
  AGENT_LIST = default agents per mode
```

**Standard/Advanced modes (when S5 ToT disabled):** Launch 3 architecture agents (Diagonal Matrix MPA) in parallel:

```
Task(subagent_type: "product-planning:software-architect", prompt: "STRUCTURAL GROUNDING focus (Inside-Out × Structure)...")
Task(subagent_type: "product-planning:software-architect", prompt: "CONTRACT IDEALITY focus (Outside-In × Data)...")
Task(subagent_type: "product-planning:software-architect", prompt: "RESILIENCE ARCHITECTURE focus (Failure-First × Behavior)...")
```

Output to:
- `{FEATURE_DIR}/design.grounding.md`
- `{FEATURE_DIR}/design.ideality.md`
- `{FEATURE_DIR}/design.resilience.md`

### Step 4.5 [ALT to 4.4, IF s5_tot_architecture]: Hybrid ToT-MPA Workflow (S5)

**Complete mode only. Feature flag: `s5_tot_architecture` (requires: `s4_adaptive_strategy`)**

1. **Phase 4a: Seeded Exploration** — Generate 8 approaches:
   - Inside-Out perspective (Structural Grounding): 2 seeded
   - Outside-In perspective (Contract Ideality): 2 seeded
   - Failure-First perspective (Resilience Architecture): 2 seeded
   - Wildcard: 2 unconstrained (via product-planning:wildcard-architect)
2. **Phase 4b: Multi-Criteria Pruning** — 3 architecture-pruning-judge agents evaluate all 8, select top 4
3. **Phase 4c: Competitive Expansion** — 4 agents develop full designs
4. **Phase 4d: Evaluation + Adaptive Selection** — Apply S4 strategy:
   - DIRECT_COMPOSITION: Clear winner (gap >=0.5, score >=3.0) — low tension
   - NEGOTIATED_COMPOSITION: Balanced (all >=3.0, gap <0.5) — user resolves tensions
   - REFRAME: Weak perspective (any <3.0) → Re-dispatch specific agent

Reference: `$CLAUDE_PLUGIN_ROOT/skills/plan/references/tot-workflow.md`
Reference: `$CLAUDE_PLUGIN_ROOT/skills/plan/references/adaptive-strategy-logic.md`

## Step 4.6 [IF s7_mpa_deliberation]: MPA Deliberation — Structured Synthesis (S1)

Follow the **MPA Deliberation** algorithm from `$CLAUDE_PLUGIN_ROOT/skills/plan/references/mpa-synthesis-pattern.md` with these parameters:

| Parameter | Value |
|-----------|-------|
| `AGENT_OUTPUTS` | `[grounding, ideality, resilience]` |
| `AGENT_LIST` | Architecture agents from Step 4.4 |
| `PHASE_ID` | `"4"` |
| `INSIGHT_FOCUS` | Key insights, unique patterns, novel approaches |
| `RESOLUTION_STRATEGY` | User decision for architectural conflicts |

## Step 4.7 [IF s8_convergence_detection]: Convergence Detection (S2)

Follow the **Convergence Detection** algorithm from `$CLAUDE_PLUGIN_ROOT/skills/plan/references/mpa-synthesis-pattern.md` with these parameters:

| Parameter | Value |
|-----------|-------|
| `AGENT_OUTPUTS` | `[grounding, ideality, resilience]` |
| `PHASE_ID` | `"4"` |
| `LOW_CONVERGENCE_STRATEGY` | `"present_all_options"` |

## Step 4.8 [IF st_tao_loops]: TAO Loop Analysis (After MPA Agents)

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
    FLAG divergent_findings for user decision in Step 4.11

ELSE:
  # Skip TAO loop, proceed directly to Step 4.9
```

**TAO Loop Purpose:**
- Prevents rushed synthesis of conflicting agent perspectives
- Explicitly categorizes findings before merging
- Provides structured pause for reflection

## Step 4.9 [IF Complete mode]: Sequential Thinking with Diagonal Matrix Fork-Join

IF mode == Complete AND ST available:

```
# Check feature flag for Fork-Join
IF feature_flags.st_fork_join_architecture.enabled:

  # Fork phase (i): Frame the decision point with Diagonal Matrix
  mcp__sequential-thinking__sequentialthinking(T7a_FRAME)

  # Fork phase (ii): Diagonal branches (logically parallel, sequential execution)
  mcp__sequential-thinking__sequentialthinking(T7b_BRANCH_GROUNDING)     # Inside-Out × Structure
  mcp__sequential-thinking__sequentialthinking(T7c_BRANCH_IDEALITY)      # Outside-In × Data
  mcp__sequential-thinking__sequentialthinking(T7d_BRANCH_RESILIENCE)    # Failure-First × Behavior

  # Fork phase (iii): Two-pass join
  mcp__sequential-thinking__sequentialthinking(T8a_RECONCILE)  # Pass 1: Tension map
  # T-CHECKPOINT here (between thought 5 and 6)
  mcp__sequential-thinking__sequentialthinking(T8b_COMPOSE)    # Pass 2: Merge with resolution

  # Fork phase (iv): Continue with composed architecture
  mcp__sequential-thinking__sequentialthinking(T9: Component Design)
  mcp__sequential-thinking__sequentialthinking(T10: Acceptance Criteria Mapping)

ELSE:
  # Fallback to linear T7-T10
  mcp__sequential-thinking__sequentialthinking(T7: Option Generation)
  mcp__sequential-thinking__sequentialthinking(T8: Trade-off Analysis)
  mcp__sequential-thinking__sequentialthinking(T9: Component Design)
  mcp__sequential-thinking__sequentialthinking(T10: Acceptance Criteria Mapping)
```

**Diagonal Matrix Fork-Join Pattern:**
```
┌─────────────────────────────────────────────────────────────────┐
│                 DIAGONAL MATRIX FORK-JOIN                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐                                                │
│  │  T7a_FRAME   │  ← Frame decision, define Perspective×Concern │
│  └──────┬───────┘    matrix and diagonal coverage                │
│         │                                                        │
│    ┌────┴────┬──────────────┐                                   │
│    ↓         ↓              ↓                                   │
│ ┌────────┐ ┌────────┐ ┌──────────┐                               │
│ │T7b     │ │T7c     │ │T7d       │  ← Diagonal exploration     │
│ │GROUNDING│ │IDEALITY│ │RESILIENCE│   (1 primary + 2 secondary) │
│ │Inside-Out│ │Outside │ │Failure-  │                              │
│ │×Structure│ │In×Data │ │First     │                              │
│ └──┬──────┘ └──┬─────┘ │×Behavior │                              │
│    │           │       └────┬─────┘                              │
│    └───────────┴────────────┘                                    │
│              ↓                                                   │
│      ┌─────────────┐                                             │
│      │T8a_RECONCILE│  ← Pass 1: Build 9-cell tension map        │
│      └──────┬──────┘                                             │
│             ↓                                                    │
│      ┌────────────┐                                              │
│      │T8b_COMPOSE │  ← Pass 2: Merge primaries + resolve        │
│      └──────┬─────┘    tensions                                  │
│             ↓                                                    │
│    Continue with T9, T10 using composed architecture             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Diagonal Matrix Benefits:**
- Orthogonal dimensions prevent exploring the same spectrum (avoids "Pragmatic always wins")
- Each branch covers unique territory (3 primary + 6 secondary = 9 cells)
- Two-pass join uses 100% of agent output (composition, not selection)
- Tension map surfaces real architectural trade-offs for user decision

## Step 4.10 [IF Advanced/Complete]: Risk Assessment for Selected Architecture

**Purpose:** Apply structured risk analysis (T11-T13) to the architecture options BEFORE presenting to user.

```
IF analysis_mode in {advanced, complete} AND mcp__sequential-thinking__sequentialthinking available:

  # After architecture options are generated but BEFORE user selection
  # Consolidated risk assessment: single 5-thought chain covering all options
  # Uses RISK-C (Consolidated) naming to avoid collision with template IDs T11-T16

  # RISK-C1: Frame risk assessment across all options
  mcp__sequential-thinking__sequentialthinking({
    thought: "RISK ASSESSMENT FRAME for all architecture perspectives. PERSPECTIVES: [grounding, ideality, resilience]. RISK CATEGORIES: Technical (complexity, unknowns), Integration (API, migration, external), Schedule (dependencies, learning curve), Security (attack surfaces, compliance), Operational (scalability, external dependencies, deployment rollback, compliance/privacy — may be N/A for MVP/internal tools). Analyzing each perspective against all categories.",
    thoughtNumber: 1,
    totalThoughts: 5,
    nextThoughtNeeded: true
  })

  # RISK-C2: Risk Identification per option
  mcp__sequential-thinking__sequentialthinking({
    thought: "RISK IDENTIFICATION across all perspectives. GROUNDING: TECHNICAL: [list], INTEGRATION: [list], SCHEDULE: [list], SECURITY: [list], OPERATIONAL: [list or N/A]. IDEALITY: TECHNICAL: [list], INTEGRATION: [list], SCHEDULE: [list], SECURITY: [list], OPERATIONAL: [list or N/A]. RESILIENCE: TECHNICAL: [list], INTEGRATION: [list], SCHEDULE: [list], SECURITY: [list], OPERATIONAL: [list or N/A]. TOTAL RISKS: grounding={N}, ideality={M}, resilience={P}. HYPOTHESIS: {perspective} has highest risk count due to {reason}. CONFIDENCE: medium.",
    thoughtNumber: 2,
    totalThoughts: 5,
    nextThoughtNeeded: true
  })

  # RISK-C3: Risk Prioritization per option
  mcp__sequential-thinking__sequentialthinking({
    thought: "RISK PRIORITIZATION using probability x impact. GROUNDING: Critical=[list], Monitor=[list], Accept=[list], SCORE={X}/10. IDEALITY: Critical=[list], Monitor=[list], Accept=[list], SCORE={Y}/10. RESILIENCE: Critical=[list], Monitor=[list], Accept=[list], SCORE={Z}/10. HYPOTHESIS: {perspective} has lowest risk score, critical risks concentrated in {area}. CONFIDENCE: high.",
    thoughtNumber: 3,
    totalThoughts: 5,
    nextThoughtNeeded: true
  })

  # RISK-C4: Mitigation strategies for critical risks
  mcp__sequential-thinking__sequentialthinking({
    thought: "MITIGATION STRATEGIES for critical risks across perspectives. GROUNDING: [risk → mitigation pairs], effort={low|med|high}, residual={low|med|high}. IDEALITY: [risk → mitigation pairs], effort={low|med|high}, residual={low|med|high}. RESILIENCE: [risk → mitigation pairs], effort={low|med|high}, residual={low|med|high}. HYPOTHESIS: Mitigations reduce critical count by {N}, {perspective} has lowest residual risk. CONFIDENCE: high.",
    thoughtNumber: 4,
    totalThoughts: 5,
    nextThoughtNeeded: true
  })

  # RISK-C5: Cross-option comparison and recommendation
  mcp__sequential-thinking__sequentialthinking({
    thought: "RISK COMPARISON COMPLETE. RANKINGS: 1. {lowest_risk_perspective} (score: X/10, critical: N), 2. {middle_perspective} (score: Y/10, critical: M), 3. {highest_risk_perspective} (score: Z/10, critical: P). RECOMMENDATION ADJUSTMENT: {if risk changes recommendation from tension analysis}. HYPOTHESIS: Risk analysis informs composition strategy.",
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

| Perspective | Risk Score | Critical Risks | Mitigation Effort | Tension Level |
|-------------|------------|----------------|-------------------|---------------|
| Grounding (Inside-Out × Structure) | X/10 | N | Low/Med/High | Low/Med/High |
| Ideality (Outside-In × Data) | Y/10 | M | Low/Med/High | Low/Med/High |
| Resilience (Failure-First × Behavior) | Z/10 | P | Low/Med/High | Low/Med/High |

## Step 4.11: Present Options

Display comparison table with:
- Complexity scores
- Maintainability scores
- Performance scores
- Time-to-implement estimates
- **Risk scores** (from Step 4.10, Advanced/Complete modes)
- **Critical risks count** (from Step 4.10)
- **Mitigation effort** (from Step 4.10)

Include **Recommendation** with reasoning that considers:
1. Trade-off analysis from T8
2. Risk assessment from T11-T13 (if available)
3. Pattern alignment from research phase

## Step 4.12 [USER]: Record Architecture Decision

**USER INTERACTION:** The user must review the tension map and confirm the composition strategy.

Set `status: needs-user-input` in your summary with:
- `block_reason`: The comparison table, tension map, and composition strategy recommendation
- For **DIRECT_COMPOSITION**: Ask user to confirm the winning perspective as composition anchor
- For **NEGOTIATED_COMPOSITION**: Present high-tension cells and ask user to resolve specific trade-offs
- For **REFRAME**: No user interaction needed (automatic re-dispatch)

On re-dispatch after user input, read `{FEATURE_DIR}/.phase-summaries/phase-4-user-input.md` for the resolutions.

Save `architecture_choice` to decisions (IMMUTABLE).

## Step 4.13 [IF s4_adaptive_strategy]: Adaptive Strategy Selection (S4)

**Purpose:** Optimize synthesis based on evaluation results.

```
IF feature_flags.s4_adaptive_strategy.enabled AND analysis_mode in {advanced, complete}:

  1. COLLECT architecture option scores from evaluation
  2. APPLY strategy selection logic from adaptive-strategy-logic.md:

     sorted_scores = sort(perspective_scores, descending)
     score_gap = sorted_scores[0] - sorted_scores[1]
     all_above_threshold = all(score >= 3.0 for score in perspective_scores)

     IF score_gap >= 0.5 AND sorted_scores[0] >= 3.0:
       strategy = DIRECT_COMPOSITION
       winning_perspective = perspective with highest score
       actions = compose from winner, enrich with secondary insights

     ELSE IF NOT all_above_threshold:
       strategy = REFRAME
       weak_perspective = perspective(s) below threshold
       → Re-dispatch specific agent with constraints (max 1 retry)

     ELSE:
       strategy = NEGOTIATED_COMPOSITION
       tension_map = build from T8a_RECONCILE output
       → Present high-tension cells to user for resolution

  3. EXECUTE strategy and generate design.md
  4. LOG: "Strategy: {strategy} - {rationale}"
  5. UPDATE state.architecture.strategy_selected = strategy
```

## Step 4.14 [IF s3_judge_gates]: Quality Gate - Architecture Quality (S3)

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
