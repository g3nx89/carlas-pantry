---
phase: "2"
phase_name: "Research & Codebase Exploration"
checkpoint: "RESEARCH"
delegation: "coordinator"
modes: [complete, advanced, standard, rapid]
prior_summaries:
  - ".phase-summaries/phase-1-summary.md"
artifacts_read:
  - "spec.md"
  - "specs/constitution.md"
artifacts_written:
  - "research.md"
  - ".phase-summaries/phase-2-skill-context.md"  # conditional: dev_skills_integration enabled
agents:
  - "product-planning:code-explorer"
  - "product-planning:researcher"
  - "product-planning:learnings-researcher"
  - "product-planning:flow-analyzer"
mcp_tools:
  - "mcp__sequential-thinking__sequentialthinking"
  - "mcp__context7__resolve-library-id"
  - "mcp__context7__query-docs"
  - "mcp__Ref__ref_search_documentation"
  - "mcp__Ref__ref_read_url"
  - "mcp__tavily__tavily_search"
  - "mcp__tavily__tavily_extract"
feature_flags:
  - "a1_flow_analysis"
  - "a2_learnings_researcher"
  - "a3_adaptive_depth"
  - "s3_judge_gates"
  - "st_tao_loops"
  - "dev_skills_integration"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/research-mcp-patterns.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/skill-loader-pattern.md"
---

# Phase 2: Research & Codebase Exploration

> **COORDINATOR INSTRUCTIONS**
> You are a phase coordinator dispatched by the lean orchestrator.
> 1. Read this file completely for your phase instructions.
> 2. Read the prior phase summaries listed in `prior_summaries` frontmatter from `{FEATURE_DIR}/.phase-summaries/`.
> 3. Read the artifacts listed in `artifacts_read` frontmatter from `{FEATURE_DIR}/`.
> 4. Execute ALL steps below for the current `analysis_mode`.
> 5. Write your output artifacts to `{FEATURE_DIR}/`.
> 6. Write your phase summary to `{FEATURE_DIR}/.phase-summaries/phase-2-summary.md` using the template at `$CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md`.
> 7. You MUST NOT interact with the user directly. If user input is needed, set `status: needs-user-input` in your summary with `block_reason` explaining what is needed and what options are available.
> 8. If a sub-agent (Task) fails, retry once. If it fails again, continue with partial results and set `flags.degraded: true` in your summary.

## Decision Protocol
When `a6_context_protocol` is enabled (check feature flags):
1. **RESPECT** all prior key decisions — do not contradict HIGH-confidence decisions without explicit justification.
2. **CHECK** open questions — if your analysis resolves any, include the resolution in your `key_decisions`.
3. **CONTRIBUTE** your findings as `key_decisions`, `open_questions`, and `risks_identified` in your phase summary YAML.

## Step 2.1: Load Context

```
READ:
  - {FEATURE_DIR}/spec.md
  - specs/constitution.md
```

## Step 2.1b: Adaptive Research Depth (A3)

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

## Step 2.1c: Research MCP Enhancement

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

## Step 2.2: Launch Research Agents

For each unknown in Technical Context:

```
Task(
  subagent_type: "product-planning:researcher",
  prompt: "Research {unknown} for {feature_context}"
)
```

## Step 2.2b: Launch Learnings Researcher (A2)

**Purpose:** Search institutional knowledge base for relevant solutions and learnings.

```
IF feature_flags.a2_learnings_researcher.enabled:

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

## Step 2.2c-a: Dev-Skills Context Loading (Subagent)

**Purpose:** Load accessibility, mobile, and Figma domain expertise before flow analysis and code exploration. Runs IN PARALLEL with Steps 2.2, 2.2b, and 2.3.

**Reference:** `$CLAUDE_PLUGIN_ROOT/skills/plan/references/skill-loader-pattern.md`

```
IF state.dev_skills.available AND analysis_mode != "rapid":

  DISPATCH Task(subagent_type="general-purpose", prompt="""
    You are a skill context loader for Phase 2 (Research & Exploration).

    Detected domains: {state.dev_skills.detected_domains}
    Technology markers: {state.dev_skills.technology_markers}

    Load the following skills and extract ONLY the specified sections:

    1. IF "frontend" in domains OR "mobile" in domains:
       Skill("dev-skills:accessibility-auditor") → extract:
         - Quick audit checklist (critical + important items)
         - Semantic HTML vs ARIA summary
       LIMIT: 800 tokens

    2. IF "mobile" in domains:
       IF "kotlin" in technology_markers:
         Skill("dev-skills:kotlin-expert") → extract:
           - Flow patterns, sealed hierarchy summary
         LIMIT: 500 tokens
       IF "compose" in technology_markers:
         Skill("dev-skills:compose-expert") → extract:
           - Shared composable anatomy
         LIMIT: 500 tokens
       IF "gradle" in technology_markers:
         Skill("dev-skills:gradle-expert") → extract:
           - Build architecture layers
         LIMIT: 400 tokens
       COMBINED MOBILE LIMIT: 1000 tokens

    3. IF "figma" in domains:
       Skill("dev-skills:figma-implement-design") → extract:
         - Quick workflow overview
       Skill("dev-skills:figma-design-toolkit") → extract:
         - Token extraction workflow
       LIMIT: 600 tokens combined

    WRITE condensed output to: {FEATURE_DIR}/.phase-summaries/phase-2-skill-context.md
    FORMAT: YAML frontmatter + markdown sections per skill
    TOTAL BUDGET: 2500 tokens max
    IF any Skill() call fails → log in skills_failed, continue with remaining
  """)

  # Skill loader runs in parallel with code-explorer and researcher agents
  # READ result BEFORE dispatching flow-analyzer (if a11y context needed in Step 2.2c)
  READ {FEATURE_DIR}/.phase-summaries/phase-2-skill-context.md
  IF file exists AND not empty:
    INJECT relevant sections into flow-analyzer prompt (Step 2.2c) as:
    "## Domain Reference (from dev-skills)\n{matching section content}"
```

## Step 2.2c: User Flow Analysis (A1)

**Complete mode only. Feature flag: `a1_flow_analysis`**

Launch flow-analyzer agent to map user journeys:

```
IF feature_flags.a1_flow_analysis.enabled AND analysis_mode == "complete":

  Task(
    subagent_type: "product-planning:flow-analyzer",
    prompt: """
      Analyze user flows for feature: {FEATURE_NAME}

      Spec: {FEATURE_DIR}/spec.md

      Map:
      - Identify all entry points and exit points
      - Map decision points and branching logic
      - Calculate permutation matrix
      - Generate gap questions for Phase 3
    """
  )
```

Reference: `$CLAUDE_PLUGIN_ROOT/templates/user-flow-analysis-template.md`
Output: Flow diagrams, decision tree, test scenario recommendations

## Step 2.3: Launch Code Explorer Agents (MPA)

Launch 2-3 agents in parallel:

```
Task(subagent_type: "product-planning:code-explorer", prompt: "Find similar features...")
Task(subagent_type: "product-planning:code-explorer", prompt: "Map architecture...")
Task(subagent_type: "product-planning:code-explorer", prompt: "Identify integrations...")
```

## Step 2.4: Sequential Thinking (Complete Mode)

IF mode == Complete AND ST available:

```
mcp__sequential-thinking__sequentialthinking(T4: Pattern Recognition)
mcp__sequential-thinking__sequentialthinking(T5: Integration Points)
mcp__sequential-thinking__sequentialthinking(T6: Technical Constraints)
```

## Step 2.4b: TAO Loop Analysis (After Research Agents)

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

## Step 2.5: Consolidate Research

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

## Step 2.6: Quality Gate - Research Completeness (S3)

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
       SET status: needs-user-input
       SET block_reason: "Research quality gate failed after 2 attempts. Issues: {issues}. Options: (1) Force proceed, (2) Manual fix, (3) Abort"
       → Write summary and return to orchestrator

  3. UPDATE state:
     gate_results.append({
       phase: 2,
       gate: "Research Completeness",
       score: {score},
       verdict: {verdict},
       retries: {retries}
     })
```
