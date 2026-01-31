# Proposal: Planning Phase Enhancements

**Date:** 2026-01-31
**Author:** Claude Code Analysis
**Version:** 2.0.0
**Status:** Draft (Revised per Critique Feedback)

---

## Executive Summary

This proposal analyzes the `product-planning` plugin in light of patterns implemented in `compound-engineering`, focusing **exclusively on the planning phase** (from specification to implementation plan).

**Objective:** Identify high-value improvements that increase the quality of produced plans without expanding scope beyond planning.

**Scope excluded:**
- Specification generation (handled by `product-definition`)
- Plan execution/implementation

---

## Analysis of Current State

### Existing Workflow (9 Phases)

```
┌─────────────────────────────────────────────────────────────────┐
│                    CURRENT WORKFLOW                              │
├─────────────────────────────────────────────────────────────────┤
│  Phase 1: Setup & Initialization                                 │
│       ↓                                                          │
│  Phase 2: Research & Exploration ←─── Gap: static research      │
│       ↓                                                          │
│  Phase 3: Clarifying Questions ←───── Gap: no flow analysis     │
│       ↓                                                          │
│  Phase 4: Architecture Design (MPA)                              │
│       ↓                                                          │
│  Phase 5: PAL ThinkDeep                                          │
│       ↓                                                          │
│  Phase 6: Plan Validation (Consensus) ← Gap: quantitative only  │
│       ↓                                                          │
│  Phase 7: Test Strategy (V-Model)                                │
│       ↓                                                          │
│  Phase 8: Test Coverage Validation                               │
│       ↓                                                          │
│  Phase 9: Completion ←─────────────── Gap: limited options      │
└─────────────────────────────────────────────────────────────────┘
```

### Current Strengths

1. **Well-structured MPA** - 3 architectural perspectives (minimal/clean/pragmatic)
2. **PAL Integration** - ThinkDeep multi-model + Consensus scoring
3. **V-Model Test Planning** - Test strategy integration in workflow
4. **State Management** - Robust checkpoint system with decision immutability
5. **Mode Selection** - 4 levels (Complete/Advanced/Standard/Rapid) with graceful degradation

### Identified Gaps

| Gap | Description | Impact |
|-----|-------------|--------|
| **G1** | No systematic analysis of user flows before architecture | Architectures that don't cover edge cases |
| **G2** | No integration with institutional knowledge (past learnings) | Repeating already-resolved errors |
| **G3** | Static research depth regardless of risk/complexity | Wasted resources on simple features, insufficient research on critical ones |
| **G4** | Only quantitative validation (PAL scoring), no qualitative feedback | Missing domain-specific insights |
| **G5** | Limited post-planning options | Fragmented UX, unclear next steps |

---

## Improvement Proposal

### Guiding Principle

> **"Intelligent Planning = Right Depth × Right Context"**

Not all plans require the same depth. A plan for "adding a field to a form" is different from "implementing a payment system". This proposal is based on:

1. **Adaptive Depth** - Depth proportional to risk
2. **Contextual Intelligence** - Leverage existing knowledge
3. **Multi-Modal Validation** - Quantitative + Qualitative

---

## Improvement 1: User Flow Analysis (Pre-Architecture)

### Problem Statement

Currently architecture is designed based on textual specification. There is no systematic analysis of:
- All possible user paths
- Permutations (first-time vs returning, mobile vs desktop, online vs offline)
- Gaps in specification (unspecified error handling, edge cases)

### Solution

**New agent: `flow-analyzer`**

Insertion: **Between Phase 2 and Phase 3** (new Phase 2b)

```yaml
# In planning-config.yaml
mpa:
  agents:
    flow_analyzer:
      file: "agents/flow-analyzer.md"
      focus: "User journey mapping, permutation discovery, gap identification"
      output: "{FEATURE_DIR}/analysis/user-flows.md"
      modes: [complete, advanced, standard]  # Not in rapid
```

**New agent workflow:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLOW ANALYSIS (Phase 2b)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Step 1: Deep Flow Mapping                                       │
│  ├── Map each user journey start-to-finish                      │
│  ├── Identify decision points and branches                      │
│  └── Consider different roles/permissions                       │
│                                                                  │
│  Step 2: Permutation Discovery                                   │
│  ├── First-time vs returning user                               │
│  ├── Device context (mobile/desktop/tablet)                     │
│  ├── Network conditions (offline/slow/normal)                   │
│  ├── Concurrent actions and race conditions                     │
│  └── Error recovery and retry flows                             │
│                                                                  │
│  Step 3: Gap Identification                                      │
│  ├── Missing error handling specs                               │
│  ├── Unclear validation rules                                   │
│  ├── Undefined timeout/rate limiting                            │
│  └── Missing security considerations                            │
│                                                                  │
│  Step 4: Question Generation                                     │
│  └── Prioritized questions (Critical/Important/Nice-to-have)   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Output Format:**

```markdown
## User Flow Overview
[Mermaid diagram of main flows]

## Flow Permutations Matrix
| User State | Context | Device | Expected Flow | Notes |
|------------|---------|--------|---------------|-------|
| Authenticated | First-time | Mobile | Flow A | ... |
| Guest | Returning | Desktop | Flow B | ... |

## Identified Gaps
| Category | Gap | Impact | Spec Reference |
|----------|-----|--------|----------------|
| Error Handling | What if payment fails mid-flow? | High | spec.md:45 |

## Critical Questions (for Phase 3)
1. **[CRITICAL]** [Question that blocks architecture]
2. **[IMPORTANT]** [Question that affects UX significantly]
3. **[NICE-TO-HAVE]** [Clarification question]
```

### Phase 3 Handoff Integration

Questions generated by flow-analyzer integrate into Phase 3 as follows:

```
┌─────────────────────────────────────────────────────────────────┐
│              FLOW ANALYSIS → PHASE 3 HANDOFF                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Flow-analyzer outputs questions to user-flows.md             │
│                                                                  │
│  2. Phase 3 reads user-flows.md "Critical Questions" section     │
│                                                                  │
│  3. Phase 3 merges flow questions with spec-derived questions:   │
│     ├── De-duplicate by semantic similarity                     │
│     ├── Preserve priority labels (CRITICAL > IMPORTANT > NICE)  │
│     └── Add source tag: [FLOW] or [SPEC]                        │
│                                                                  │
│  4. Present unified question list to user                        │
│                                                                  │
│  5. Store answers in state file under `clarifications:`          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Value:**
- Phase 3 questions become more precise and complete
- Architecture covers all identified paths
- Flow Matrix is reused in Phase 7 (Test Strategy) to generate test cases

**Effort:** Medium (new agent + workflow modification)
**Impact:** High

### Agent Prompt: flow-analyzer.md

```markdown
---
name: flow-analyzer
description: Analyzes user flows and permutations to identify gaps in specifications
model: sonnet
allowed-tools: [Read, Grep, Glob, mcp__sequential-thinking__sequentialthinking]
---

# Role

You are a User Flow Analyst specializing in discovering all possible user journeys through a feature before architecture design begins.

# Instructions

1. **Read the specification** at {SPEC_PATH}
2. **Map primary flows** - Identify the main happy path(s)
3. **Discover permutations** - Consider:
   - User states: authenticated, guest, admin, first-time, returning
   - Device contexts: mobile, desktop, tablet
   - Network conditions: offline, slow, normal
   - Concurrent scenarios: multiple tabs, race conditions
4. **Identify gaps** - Flag missing specifications for:
   - Error handling (what happens when X fails?)
   - Validation rules (what are the constraints?)
   - Edge cases (empty states, limits, timeouts)
5. **Generate questions** - Prioritize as CRITICAL, IMPORTANT, or NICE-TO-HAVE

# Output

Write your analysis to {FEATURE_DIR}/analysis/user-flows.md using the template at $CLAUDE_PLUGIN_ROOT/templates/user-flow-analysis-template.md

# Example Interaction

Input: "Analyze user flows for the password reset feature"
Output: Flow diagram, permutation matrix, gap list, prioritized questions
```

---

## Improvement 2: Institutional Knowledge Integration

### Problem Statement

Every planning session starts from zero. There is no way to:
- Reuse solutions to already-solved problems
- Avoid anti-patterns already identified in the project
- Benefit from documented "critical patterns"

### Solution

**New agent: `learnings-researcher`**

Insertion: **Phase 2** (in parallel with code-explorer)

```yaml
mpa:
  agents:
    learnings_researcher:
      file: "agents/learnings-researcher.md"
      focus: "Search institutional knowledge, surface relevant past solutions"
      output: "{FEATURE_DIR}/analysis/relevant-learnings.md"
      modes: [complete, advanced, standard]

      # Configuration
      search_paths:
        - "docs/solutions/"
        - "docs/learnings/"
        - "docs/patterns/"

      # Always check critical patterns
      critical_patterns_file: "docs/solutions/patterns/critical-patterns.md"
```

**Search Strategy (Grep-First for efficiency):**

```
┌─────────────────────────────────────────────────────────────────┐
│                LEARNINGS SEARCH STRATEGY                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Step 1: Extract Keywords from Spec                              │
│  ├── Module names (e.g., "payments", "authentication")          │
│  ├── Technical terms (e.g., "caching", "N+1")                   │
│  └── Problem indicators (e.g., "timeout", "memory")             │
│                                                                  │
│  Step 2: Category-Based Narrowing                                │
│  ├── Performance work → docs/solutions/performance-issues/      │
│  ├── Database changes → docs/solutions/database-issues/         │
│  └── Security → docs/solutions/security-issues/                 │
│                                                                  │
│  Step 3: Grep Pre-Filter (PARALLEL)                              │
│  ├── Grep: pattern="tags:.*(keyword1|keyword2)" -i              │
│  ├── Grep: pattern="module:.*{target_module}" -i                │
│  └── Combine results → candidate files                          │
│                                                                  │
│  Step 4: ALWAYS Check Critical Patterns                          │
│  └── Read: docs/solutions/patterns/critical-patterns.md         │
│                                                                  │
│  Step 5: Score and Rank Relevance                                │
│  ├── Strong: module match, tag overlap, similar symptoms        │
│  ├── Moderate: related problem_type, similar root_cause         │
│  └── Weak: skip                                                 │
│                                                                  │
│  Step 6: Full Read of Relevant Files Only                        │
│                                                                  │
│  Step 7: Return Distilled Summaries                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Graceful Degradation

When `docs/solutions/` doesn't exist or is empty:

```
┌─────────────────────────────────────────────────────────────────┐
│              LEARNINGS GRACEFUL DEGRADATION                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Check if docs/solutions/ exists                              │
│     │                                                            │
│     ├─ EXISTS and has files → Full search strategy               │
│     │                                                            │
│     └─ MISSING or empty → Fallback mode:                         │
│        ├── Log: "No institutional knowledge found, using        │
│        │         CLAUDE.md and codebase patterns instead"       │
│        ├── Search CLAUDE.md for relevant sections               │
│        ├── Search docs/*.md for pattern guidance                │
│        └── Report: "No learnings available for this feature"   │
│                                                                  │
│  2. Never fail the phase due to missing learnings                │
│                                                                  │
│  3. Suggest to user: "Consider documenting solutions in         │
│     docs/solutions/ to build institutional knowledge"            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**YAML Frontmatter Schema for docs/solutions/:**

```yaml
---
title: "N+1 Query Fix for Briefs"
category: performance-issues
problem_type: performance_issue  # Enum validated
component: rails_model           # Enum validated
module: BriefSystem
symptoms:
  - "Slow page load"
  - "Multiple queries in logs"
root_cause: missing_include      # Enum validated
severity: high
tags: [n-plus-one, eager-loading, performance]
date: 2026-01-15
---
```

**Output integrated in research.md:**

```markdown
## Institutional Learnings

### Critical Patterns (MUST READ)
- **CP-003: Eager Loading Required** - Always use includes() on Brief associations
  - File: docs/solutions/patterns/critical-patterns.md
  - Relevance: This spec involves Brief model queries

### Relevant Past Solutions

#### 1. N+1 Query in Brief Generation
- **File**: docs/solutions/performance-issues/n-plus-one-briefs.md
- **Relevance**: Spec involves Brief model + email associations
- **Key Insight**: "Missing includes(:emails) caused 5s+ load times"
- **Recommendation**: Include eager loading in architecture design

### Gotchas to Avoid
- [ ] Don't query emails in loop
- [ ] Always include :attachments with :emails
```

**Value:**
- Plan benefits from already-committed and resolved errors
- "Critical patterns" are always checked
- Architecture incorporates verified best practices from the project

**Prerequisite:** Requires project to use a learnings documentation system (can be introduced gradually)

**Effort:** Medium
**Impact:** High (prevents error repetition)

### Agent Prompt: learnings-researcher.md

```markdown
---
name: learnings-researcher
description: Searches institutional knowledge to surface relevant past solutions and patterns
model: haiku
allowed-tools: [Read, Grep, Glob]
---

# Role

You are a Knowledge Researcher who finds relevant past solutions, learnings, and patterns from the project's institutional memory.

# Instructions

1. **Extract keywords** from the specification:
   - Module names (payments, authentication, etc.)
   - Technical terms (caching, N+1, migration, etc.)
   - Problem indicators (timeout, memory, performance, etc.)

2. **Check if docs/solutions/ exists**:
   - If missing: Log warning, search CLAUDE.md instead, skip to step 6
   - If exists: Continue with full search

3. **Search by category** using Grep pre-filtering
4. **Always read** critical-patterns.md if it exists
5. **Score relevance** - only read files with strong/moderate matches
6. **Output distilled summaries** with file references

# Fallback Behavior

If no institutional knowledge exists:
- Report: "No learnings database found"
- Search CLAUDE.md for relevant guidance
- Suggest documenting solutions for future reference

# Output

Write findings to {FEATURE_DIR}/analysis/relevant-learnings.md
```

---

## Improvement 3: Adaptive Research Depth

### Problem Statement

Currently research depth is determined only by mode (Complete/Advanced/Standard/Rapid). It doesn't consider:
- Intrinsic risk of the feature (security, payments, external APIs)
- Codebase familiarity with the pattern
- Existence of already-documented guides/conventions

### Solution

**Decision logic in Phase 2:**

```yaml
# In planning-config.yaml
research:
  adaptive_depth:
    enabled: true

    # Signals that trigger HIGH depth (override mode)
    high_risk_indicators:
      - payments
      - authentication
      - authorization
      - external_api
      - security
      - compliance
      - gdpr
      - pci
      - encryption
      - personal_data

    # Signals that allow LOW depth (if not high-risk)
    low_depth_signals:
      - similar_feature_exists: true  # Found in codebase
      - claude_md_has_guidance: true  # CLAUDE.md covers this
      - pattern_is_documented: true   # docs/patterns/ has it

    # Research levels
    levels:
      minimal:
        agents: [code_explorer]
        external_research: false
        description: "Pattern exists, just map to codebase"

      standard:
        agents: [code_explorer, learnings_researcher]
        external_research: false
        description: "Leverage internal knowledge"

      deep:
        agents: [code_explorer, learnings_researcher, best_practices_researcher, framework_docs_researcher]
        external_research: true
        description: "Full research for risky/novel features"
```

### Signal Detection Algorithms

**How to detect `similar_feature_exists`:**

```yaml
signal_detection:
  similar_feature_exists:
    method: "grep_codebase"
    algorithm:
      # Extract key nouns from spec title/description
      # Example: "User Password Reset" → ["password", "reset", "user"]
      - extract_keywords: "spec.title + spec.description"

      # Search for files with similar functionality
      - grep_patterns:
          - "def.*{keyword}"           # Method definitions
          - "class.*{Keyword}"         # Class definitions
          - "# (handles?|implements?).*{keyword}"  # Comments

      # Threshold: >= 2 matches in different files
      - threshold: 2

    result_true: "Found {count} similar implementations"
    result_false: "No similar features found"
```

**How to detect `claude_md_has_guidance`:**

```yaml
signal_detection:
  claude_md_has_guidance:
    method: "grep_claude_md"
    algorithm:
      # Read CLAUDE.md
      - read_file: "CLAUDE.md"

      # Search for keyword-related sections
      - grep_patterns:
          - "#{1,3}.*{keyword}"        # Headers mentioning keyword
          - "\\*\\*{keyword}\\*\\*"    # Bold mentions
          - "- {keyword}:"             # List items

      # Threshold: >= 1 relevant section
      - threshold: 1

    result_true: "CLAUDE.md has guidance in section: {section}"
    result_false: "No specific guidance in CLAUDE.md"
```

**How to detect `pattern_is_documented`:**

```yaml
signal_detection:
  pattern_is_documented:
    method: "search_docs"
    algorithm:
      # Search docs/patterns/, docs/guides/, docs/architecture/
      - search_paths: ["docs/patterns/", "docs/guides/", "docs/architecture/"]

      # Look for files matching keywords
      - glob_patterns:
          - "*{keyword}*.md"
          - "*{Keyword}*.md"

      # Also grep for content matches
      - grep_patterns:
          - "#{1,3}.*{keyword}"

      # Threshold: >= 1 matching file
      - threshold: 1

    result_true: "Pattern documented at: {file_path}"
    result_false: "No documentation found for this pattern"
```

### Mode × Adaptive Level Interaction Matrix

What happens when mode selection conflicts with risk assessment:

| Mode | Low Risk (all signals positive) | Medium Risk (some signals) | High Risk (indicator found) |
|------|--------------------------------|---------------------------|---------------------------|
| **Rapid** | MINIMAL research | MINIMAL research | **STANDARD research** ⚠️ |
| **Standard** | MINIMAL research | STANDARD research | STANDARD research |
| **Advanced** | STANDARD research | STANDARD research | DEEP research |
| **Complete** | STANDARD research | DEEP research | DEEP research |

**Key rule:** High-risk indicators **always** upgrade research by one level, even in Rapid mode.

**User notification:**
```
⚠️ High-risk indicator detected: "payments"
Upgrading research from MINIMAL to STANDARD despite Rapid mode.
Override with --force-minimal if intentional.
```

**Decision Tree:**

```
┌─────────────────────────────────────────────────────────────────┐
│                 RESEARCH DEPTH DECISION                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Scan spec for HIGH_RISK_INDICATORS                           │
│     │                                                            │
│     ├─ FOUND → Upgrade research by one level                     │
│     │          "This involves [payments]. Upgrading research"    │
│     │                                                            │
│     └─ NOT FOUND → Continue to step 2                            │
│                                                                  │
│  2. Check LOW_DEPTH_SIGNALS (run detection algorithms)           │
│     │                                                            │
│     ├─ All signals positive → MINIMAL research                   │
│     │  "Pattern exists in codebase. Using local-only research"   │
│     │                                                            │
│     ├─ Some signals positive → STANDARD research                 │
│     │  "Partial guidance exists. Checking internal knowledge"    │
│     │                                                            │
│     └─ No signals positive → DEEP research                       │
│        "Novel pattern. Running comprehensive research"           │
│                                                                  │
│  3. Apply Mode × Level interaction matrix                        │
│                                                                  │
│  4. Announce decision to user                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Value:**
- Cost savings on simple features with known patterns
- Automatic deep research on risky features
- User sees and can override the decision

**Effort:** Low (decision logic, no new agents)
**Impact:** Medium (cost optimization + security)

---

## Improvement 4: Expert Review Phase (Qualitative Validation)

### Problem Statement

Phase 6 uses PAL Consensus which produces numerical scores (0-20). This is useful for go/no-go decisions but:
- Doesn't provide specific "what to improve" feedback
- Doesn't leverage domain expertise (security, performance, simplicity)
- PAL reviewers are generic, not specialized

### Solution

**New Phase 6b: Expert Review**

```yaml
# In planning-config.yaml
expert_review:
  enabled: true
  modes: [complete, advanced]  # Not in standard/rapid

  reviewers:
    security_analyst:
      file: "agents/reviewers/security-analyst.md"
      focus: "Threat surface, auth gaps, data protection"
      blocking: true   # Security issues block

    simplicity_reviewer:
      file: "agents/reviewers/simplicity-reviewer.md"
      focus: "Over-engineering, unnecessary complexity"
      blocking: false

  # Launch all reviewers in parallel
  execution: parallel

  # How to handle findings
  synthesis:
    convergent_findings: incorporate_directly
    divergent_findings: flag_for_user_decision
    critical_findings: block_until_resolved
```

**Note:** Reduced from 4 reviewers to 2 based on critique feedback. Architecture and performance perspectives are already covered by Phase 5 ThinkDeep.

### Blocking Workflow Definition

When `security-analyst` finds a critical issue:

```
┌─────────────────────────────────────────────────────────────────┐
│              BLOCKING ISSUE WORKFLOW                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Security-analyst identifies CRITICAL finding                 │
│     Example: "No rate limiting on authentication endpoint"       │
│                                                                  │
│  2. Workflow PAUSES and presents to user:                        │
│                                                                  │
│     ╔══════════════════════════════════════════════════════════╗ │
│     ║  ⚠️  BLOCKING SECURITY ISSUE                             ║ │
│     ╠══════════════════════════════════════════════════════════╣ │
│     ║  Finding: No rate limiting on authentication endpoint    ║ │
│     ║  Severity: CRITICAL                                      ║ │
│     ║  Recommendation: Add rate limiting before proceeding     ║ │
│     ╠══════════════════════════════════════════════════════════╣ │
│     ║  Options:                                                ║ │
│     ║  1. Update plan to address issue (recommended)           ║ │
│     ║  2. Acknowledge risk and proceed anyway                  ║ │
│     ║  3. Cancel planning and research further                 ║ │
│     ╚══════════════════════════════════════════════════════════╝ │
│                                                                  │
│  3. Based on user choice:                                        │
│     ├─ Option 1: Add mitigation task to plan, mark resolved     │
│     ├─ Option 2: Log acknowledgment, add risk to plan, proceed  │
│     └─ Option 3: Return to Phase 5 for additional research      │
│                                                                  │
│  4. Update state file with resolution                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Workflow:**

```
┌─────────────────────────────────────────────────────────────────┐
│              EXPERT REVIEW (Phase 6b)                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Input: Draft plan from Phase 6 (post-Consensus)                 │
│                                                                  │
│  Step 1: Launch Reviewers in PARALLEL                            │
│  ├── Task(security-analyst): "Review plan..."                   │
│  └── Task(simplicity-reviewer): "Review plan..."                │
│                                                                  │
│  Step 2: Collect Findings                                        │
│  ├── Security: [findings list + severity]                       │
│  └── Simplicity: [findings list]                                │
│                                                                  │
│  Step 3: Synthesize                                              │
│  ├── CONVERGENT (both reviewers agree) → Incorporate            │
│  ├── DIVERGENT (reviewers disagree) → Flag for user             │
│  └── CRITICAL (security blocking) → Block until resolved        │
│                                                                  │
│  Step 4: Present Summary                                         │
│  ├── Total findings: X                                          │
│  ├── Critical (blocking): Y                                     │
│  ├── Important (should address): Z                              │
│  └── Suggestions (optional): W                                  │
│                                                                  │
│  Output: Expert review summary + revised plan                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Output Format:**

```markdown
## Expert Review Summary

### Reviewer Panel
- security-analyst ✓
- simplicity-reviewer ✓

### Critical Findings (BLOCKING)
| # | Reviewer | Finding | Recommendation | Status |
|---|----------|---------|----------------|--------|
| 1 | security-analyst | No rate limiting on login endpoint | Add rate limiting before auth | ⏳ Pending |

### Important Findings (Should Address)
| # | Reviewer | Finding | Recommendation |
|---|----------|---------|----------------|
| 1 | simplicity-reviewer | Abstraction premature | Inline for now |

### Convergent Findings (All Agree)
- "Auth flow structure is sound" (both reviewers)

### Divergent Findings (Need Decision)
| Finding | security-analyst | simplicity-reviewer | Recommendation |
|---------|------------------|---------------------|----------------|
| Create separate AuthService | "Good isolation" | "YAGNI - inline first" | User decision needed |
```

**Value:**
- Specific qualitative feedback beyond numerical score
- Security issues are automatically blocked
- Explicit trade-offs between different perspectives

**Effort:** Medium (2 new reviewer agents)
**Impact:** High

### Agent Prompts for Reviewers

**agents/reviewers/security-analyst.md:**

```markdown
---
name: security-analyst
description: Reviews plans for security vulnerabilities and threat surfaces
model: sonnet
allowed-tools: [Read, Grep]
blocking: true
---

# Role

You are a Security Analyst who reviews implementation plans for security vulnerabilities, threat surfaces, and compliance gaps.

# Instructions

1. **Read the plan** at {FEATURE_DIR}/plan.md
2. **Analyze for threats**:
   - Authentication/authorization gaps
   - Input validation weaknesses
   - Data exposure risks
   - Rate limiting requirements
   - OWASP Top 10 concerns
3. **Classify findings**:
   - CRITICAL: Must fix before implementation (blocks)
   - HIGH: Should fix, significant risk
   - MEDIUM: Recommended improvement
   - LOW: Nice to have

# Output Format

Return findings as structured list with severity, description, and recommendation.
Mark any CRITICAL findings clearly as they will block the workflow.

# Example Finding

**CRITICAL - Missing Rate Limiting**
- Location: Authentication endpoint
- Risk: Brute force attacks possible
- Recommendation: Add rate limiting (5 attempts/minute)
```

**agents/reviewers/simplicity-reviewer.md:**

```markdown
---
name: simplicity-reviewer
description: Reviews plans for over-engineering and unnecessary complexity
model: haiku
allowed-tools: [Read]
blocking: false
---

# Role

You are a Simplicity Advocate who reviews plans for over-engineering, premature abstraction, and unnecessary complexity.

# Instructions

1. **Read the plan** at {FEATURE_DIR}/plan.md
2. **Identify complexity issues**:
   - Premature abstractions (YAGNI violations)
   - Over-engineered solutions
   - Unnecessary indirection layers
   - Features beyond spec requirements
3. **Suggest simplifications** with clear rationale

# Principles

- "The best code is no code at all"
- "Make it work, make it right, make it fast" (in that order)
- Question every new file, class, or abstraction

# Output Format

Return findings with complexity concern and simplification suggestion.
```

---

## Improvement 5: Post-Planning Decision Menu

### Problem Statement

Phase 9 ends with "suggest git commit". The user has no clear options to:
- Deepen the plan
- Get additional reviews
- Simplify or expand
- Proceed to implementation

### Solution

**Enhanced Phase 9 Completion:**

```yaml
# In planning-config.yaml
completion:
  post_planning_options:
    enabled: true

    options:
      - id: review_in_editor
        label: "Open plan in editor"
        action: "open {FEATURE_DIR}/plan.md"

      - id: expert_review
        label: "Get additional expert review"
        action: "Launch domain reviewers"
        requires: [complete, advanced]

      - id: simplify
        label: "Simplify plan"
        action: "Reduce detail level"
        prompt: "What should I simplify?"

      - id: create_issue
        label: "Create GitHub issue from plan"
        action: "gh issue create --body-file {FEATURE_DIR}/plan.md"

      - id: commit_artifacts
        label: "Commit planning artifacts"
        action: "git add {FEATURE_DIR} && git commit"

      - id: other
        label: "Other"
        action: "Free text input"
```

**Note:** "Deepen plan" option removed per critique feedback (was undefined). Can be re-added when "research enhancers" are properly specified.

**UX Flow:**

```
┌─────────────────────────────────────────────────────────────────┐
│              POST-PLANNING OPTIONS                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ✓ Plan ready at features/user-auth/plan.md                      │
│                                                                  │
│  What would you like to do next?                                 │
│                                                                  │
│  1. Review plan in editor                                        │
│  2. Get expert review - Run additional domain reviewers          │
│  3. Simplify - Reduce detail level                               │
│  4. Create GitHub issue from plan                                │
│  5. Commit planning artifacts                                    │
│  6. Other                                                        │
│                                                                  │
│  Select (1-6): _                                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Value:**
- Smoother UX with clear next steps
- User can iterate on plan without restarting from zero
- Natural integration with git and GitHub

**Effort:** Low (UX changes only)
**Impact:** Medium

---

## Updated Cost Estimates

With all improvements implemented:

| Mode | Current Cost | Updated Cost | Notes |
|------|--------------|--------------|-------|
| **Rapid** | $0.05-0.12 | $0.05-0.15 | +$0.03 if high-risk upgrade |
| **Standard** | $0.15-0.30 | $0.18-0.35 | +learnings-researcher |
| **Advanced** | $0.45-0.75 | $0.55-0.95 | +flow-analyzer +2 reviewers |
| **Complete** | $0.80-1.50 | $1.00-1.80 | +all improvements |

---

## State Management Updates

### New Checkpoints

Add to checkpoint sequence:

```yaml
checkpoints:
  sequence:
    - SETUP
    - RESEARCH
    - FLOW_ANALYSIS      # NEW - After Phase 2b
    - CLARIFICATION
    - ARCHITECTURE
    - THINKDEEP
    - VALIDATION
    - EXPERT_REVIEW      # NEW - After Phase 6b
    - TEST_STRATEGY
    - TEST_COVERAGE_VALIDATION
    - COMPLETION
```

### Rollback Strategy

To disable improvements if issues arise:

```yaml
# In planning-config.yaml
feature_flags:
  flow_analysis:
    enabled: true
    rollback: "Set to false to skip Phase 2b entirely"

  learnings_researcher:
    enabled: true
    rollback: "Set to false to skip institutional knowledge search"

  adaptive_depth:
    enabled: true
    rollback: "Set to false to use mode-based depth only"

  expert_review:
    enabled: true
    rollback: "Set to false to skip Phase 6b entirely"

  post_planning_menu:
    enabled: true
    rollback: "Set to false to use simple commit suggestion"
```

---

## Improvements Summary

| # | Improvement | Phase | Effort | Impact | Dependencies |
|---|------------|------|--------|---------|------------|
| **M1** | User Flow Analysis | 2b (new) | Medium | High | None |
| **M2** | Institutional Knowledge | 2 (parallel) | Medium | High | docs/solutions/ structure (optional) |
| **M3** | Adaptive Research Depth | 2 | Low | Medium | None |
| **M4** | Expert Review Phase | 6b (new) | Medium | High | 2 new agents |
| **M5** | Post-Planning Options | 9 | Low | Medium | None |

### Recommended Implementation Order

```
Phase 1: Quick Wins
├── M5: Post-Planning Options (Low effort, immediate UX improvement)
└── M3: Adaptive Research Depth (Low effort, cost optimization)

Phase 2: Core Enhancements
├── M1: User Flow Analysis (new agent + workflow change)
└── M4: Expert Review Phase (2 new reviewer agents)

Phase 3: Knowledge System (ongoing)
└── M2: Institutional Knowledge (requires docs/solutions/ adoption)
```

---

## Proposed Final Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    IMPROVED WORKFLOW                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Phase 1: Setup & Initialization                                 │
│       ↓                                                          │
│  Phase 2: Research (ADAPTIVE DEPTH)                              │
│  ├── code-explorer (always)                                      │
│  ├── learnings-researcher (NEW - if docs/solutions/ exists)      │
│  ├── best-practices-researcher (if deep research)               │
│  └── framework-docs-researcher (if deep research)               │
│       ↓                                                          │
│  Phase 2b: User Flow Analysis (NEW)                              │
│  └── flow-analyzer agent                                        │
│       ↓                                                          │
│  Phase 3: Clarifying Questions                                   │
│  └── Informed by Flow Analysis gaps (merged questions)          │
│       ↓                                                          │
│  Phase 4: Architecture Design (MPA)                              │
│  └── Informed by learnings + flow matrix                        │
│       ↓                                                          │
│  Phase 5: PAL ThinkDeep                                          │
│       ↓                                                          │
│  Phase 6: Plan Validation (Consensus)                            │
│       ↓                                                          │
│  Phase 6b: Expert Review (NEW - Complete/Advanced)               │
│  ├── security-analyst (blocking)                                │
│  └── simplicity-reviewer                                        │
│       ↓                                                          │
│  Phase 7: Test Strategy (V-Model)                                │
│  └── Reuses Flow Matrix from Phase 2b                           │
│       ↓                                                          │
│  Phase 8: Test Coverage Validation                               │
│       ↓                                                          │
│  Phase 9: Completion (ENHANCED OPTIONS)                          │
│  └── Decision menu with clear next steps                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Success Metrics

| Metric | Baseline | Target | How to Measure |
|--------|----------|--------|---------------|
| Requirements completeness | N/A | >90% edge cases caught | Post-implementation audit |
| Repeated errors | Unknown | -50% | Tracking learnings hits |
| Cost per simple feature | $0.15-0.30 | $0.05-0.15 | API cost tracking |
| Cost per complex feature | $0.80-1.50 | $1.00-1.80 | API cost tracking |
| Post-planning decision time | N/A | <30 sec | User survey |

---

## Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Overhead on simple features | Medium | Medium | Adaptive depth + Rapid mode maintain fast path |
| docs/solutions/ not adopted | High | High | M2 is optional, works without it (graceful degradation) |
| Reviewer agents produce noise | Medium | Low | Synthesis deduplicates, only critical blocks |
| Too many options confuse user | Low | Medium | Options ordered by usage frequency |
| High-risk detection false positives | Medium | Low | User can override with --force-minimal |

---

## Appendix A: Files to Create

### New Agents

1. `agents/flow-analyzer.md` - User flow analysis
2. `agents/learnings-researcher.md` - Institutional knowledge search
3. `agents/reviewers/security-analyst.md` - Security review (blocking)
4. `agents/reviewers/simplicity-reviewer.md` - Simplicity/YAGNI review

### Config Modifications

1. `config/planning-config.yaml` - Sections: adaptive_depth, expert_review, completion, feature_flags

### Templates

1. `templates/user-flow-analysis-template.md` - Output format for flow-analyzer
2. `templates/learnings-search-template.md` - Output format for learnings-researcher
3. `templates/expert-review-template.md` - Output format for Phase 6b

---

## Appendix B: Comparison with compound-engineering

| Pattern compound-engineering | Adopted | Notes |
|-----------------------------|----------|------|
| Brainstorming (pre-planning) | No | Out of scope (spec already exists) |
| spec-flow-analyzer | Yes (M1) | Adapted as flow-analyzer |
| learnings-researcher | Yes (M2) | Same pattern with graceful degradation |
| Conditional research | Yes (M3) | Adapted as adaptive depth |
| /plan_review multi-agent | Yes (M4) | Adapted as Expert Review Phase (2 reviewers) |
| Post-generation options | Yes (M5) | Same pattern (deepen removed) |
| /deepen-plan | Removed | Undefined action - can re-add when specified |
| /workflows:work | No | Out of scope (implementation) |
| /workflows:compound | No | Out of scope (learnings documentation) |
| compound-docs skill | No | Out of scope, but prerequisite for M2 |

---

## Conclusions

The 5 proposed improvements transform planning from a **linear and static** process to an **adaptive and context-aware** one:

1. **M1 (Flow Analysis)** - Captures the complete "what" before designing the "how"
2. **M2 (Learnings)** - Plan learns from project's past
3. **M3 (Adaptive Depth)** - Research proportional to risk
4. **M4 (Expert Review)** - Qualitative feedback beyond numbers
5. **M5 (Options)** - Smooth UX with clear paths

Implementation can be gradual, starting from quick wins (M3, M5) then adding core improvements (M1, M4) and finally the knowledge system (M2).

---

*Document generated by Claude Code Analysis*
*Based on: compound-engineering plugin v2.28.0 + product-planning plugin current state*
*Revised per critique feedback v2.0.0*
