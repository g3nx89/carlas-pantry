# Proposal: Planning Phase Enhancements

**Date:** 2026-01-31
**Author:** Claude Code Analysis
**Version:** 3.2.0
**Status:** Draft (Extended with SADD Process Patterns + Sequential Thinking Analysis Fixes)

---

## Executive Summary

This proposal enhances the `product-planning` plugin by combining **Context Improvements** (what information goes into planning) with **Process Improvements** (how planning decisions are made).

**Core Insight:**
> **Better Planning = Better Inputs (Context) × Better Decisions (Process)**

The original proposal (v2.0) focused on Context. This version adds Process improvements derived from the **SADD plugin** (Subagent-Driven Development), which implements research-backed patterns:
- Tree of Thoughts (Yao et al., 2023)
- Constitutional AI Self-Critique (Bai et al., 2022)
- Multi-Agent Debate (Du et al., 2023)
- Chain-of-Verification (Dhuliawala et al., 2023)

**Key Innovation: "Verified Exploration" Pattern**
- Every agent output is self-verified before submission
- Architecture decisions use systematic exploration (ToT) instead of predetermined options
- Quality gates between phases prevent error propagation
- Adaptive strategy selection optimizes synthesis decisions

---

## Table of Contents

1. [Analysis of Current State](#analysis-of-current-state)
2. [Part A: Context Improvements (A1-A5)](#part-a-context-improvements)
3. [Part B: Process Improvements (S1-S6)](#part-b-process-improvements-sadd-patterns)
4. [Integration Matrix](#integration-matrix)
5. [Implementation Roadmap](#implementation-roadmap)
6. [Cost Analysis](#cost-analysis)
7. [Risk Analysis](#risk-analysis)
8. [Files to Create](#files-to-create)

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
│       ↓                              Gap: no self-verification  │
│  Phase 3: Clarifying Questions ←───── Gap: no flow analysis     │
│       ↓                                                          │
│  Phase 4: Architecture Design (MPA) ← Gap: predetermined options│
│       ↓                              Gap: no exploration        │
│  Phase 5: PAL ThinkDeep                                          │
│       ↓                                                          │
│  Phase 6: Plan Validation (Consensus) ← Gap: single-round only  │
│       ↓                                 Gap: no quality gates   │
│  Phase 7: Test Strategy (V-Model)                                │
│       ↓                                                          │
│  Phase 8: Test Coverage Validation                               │
│       ↓                                                          │
│  Phase 9: Completion ←─────────────── Gap: limited options      │
└─────────────────────────────────────────────────────────────────┘
```

### Gap Analysis Summary

| Gap ID | Category | Description | Impact |
|--------|----------|-------------|--------|
| G1 | Context | No user flow analysis before architecture | Missing edge cases |
| G2 | Context | No institutional knowledge integration | Repeated errors |
| G3 | Context | Static research depth | Wasted resources |
| G4 | Context | Quantitative-only validation | Missing insights |
| G5 | Context | Limited post-planning options | Fragmented UX |
| G6 | Process | No self-verification on agents | Errors propagate |
| G7 | Process | Predetermined architecture options | Limited exploration |
| G8 | Process | No quality gates between phases | Late error detection |
| G9 | Process | Single-round validation | Shallow consensus |
| G10 | Process | Always synthesizes regardless of evaluation results | Wasted resources |

### Gap-to-Improvement Traceability Matrix

| Gap | Improvement | Implementation | Mode Availability |
|-----|-------------|----------------|-------------------|
| G1 | A1: User Flow Analysis | Phase-3 | Complete, Advanced, Standard |
| G2 | A2: Institutional Knowledge | Ongoing | Complete, Advanced, Standard |
| G3 | A3: Adaptive Research Depth | Phase-1 | All |
| G4 | A4: Expert Review | Phase-2 | Complete, Advanced |
| G5 | A5: Post-Planning Menu | Phase-1 | All |
| G6 | S1: Self-Critique Loop | Phase-1 | All |
| G6 | S2: Zero-Shot CoT Prefix | Phase-1 | All |
| G7 | S5: Hybrid ToT-MPA | Phase-3 | Complete |
| G8 | S3: Judge Gates | Phase-1 | Advanced, Complete |
| G9 | S6: Multi-Judge Debate | Phase-2 | Complete |
| G10 | S4: Adaptive Strategy | Phase-2 | Advanced, Complete |

**Legend:**
- Phase-1 = Week 1 implementation
- Phase-2 = Weeks 2-3 implementation
- Phase-3 = Weeks 3-4 implementation
- Ongoing = Continuous improvement

---

# Part A: Context Improvements

*These improvements enhance what information flows into planning decisions.*

## A1: User Flow Analysis (Phase 2b)

**Gap Addressed:** G1 - No systematic user flow analysis

**Solution:** New `flow-analyzer` agent between Phase 2 and Phase 3.

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLOW ANALYSIS (Phase 2b)                      │
├─────────────────────────────────────────────────────────────────┤
│  Step 1: Deep Flow Mapping                                       │
│  ├── Map each user journey start-to-finish                      │
│  ├── Identify decision points and branches                      │
│  └── Consider different roles/permissions                       │
│                                                                  │
│  Step 2: Permutation Discovery                                   │
│  ├── First-time vs returning user                               │
│  ├── Device context (mobile/desktop/tablet)                     │
│  ├── Network conditions (offline/slow/normal)                   │
│  └── Error recovery and retry flows                             │
│                                                                  │
│  Step 3: Gap Identification → Questions for Phase 3              │
└─────────────────────────────────────────────────────────────────┘
```

**Modes:** Complete, Advanced, Standard (not Rapid)
**Effort:** Medium | **Impact:** High

**Acceptance Criteria:**
- [ ] `agents/flow-analyzer.md` exists with complete prompt
- [ ] Flow analysis runs after Phase 2, before Phase 3
- [ ] Output includes: flow matrix, decision points, gap questions
- [ ] Gaps feed into Phase 3 clarifying questions
- [ ] State file tracks `flow_analysis_complete: true`

**Integration Points:**
- **Phase 3**: Gap questions feed clarification process
- **Phase 4**: User journey requirements inform architecture options
- **Phase 7**: Flow matrix reused for test scenario generation

---

## A2: Institutional Knowledge Integration (Phase 2)

**Gap Addressed:** G2 - Planning starts from zero each time

**Solution:** New `learnings-researcher` agent runs in parallel with code-explorer.

- Searches `docs/solutions/` for relevant past solutions
- Always checks `critical-patterns.md`
- Gracefully degrades if no learnings database exists

**Modes:** Complete, Advanced, Standard
**Effort:** Medium | **Impact:** High

**Acceptance Criteria:**
- [ ] `agents/learnings-researcher.md` exists with complete prompt
- [ ] Agent searches `docs/solutions/` and `critical-patterns.md`
- [ ] Gracefully degrades when no learnings database exists (no error)
- [ ] Output includes: relevant_patterns, warnings, recommendations
- [ ] State file includes `learnings_consulted: [list of files]`

**YAML Schema for Learnings:**
```yaml
# docs/solutions/{feature-name}.yaml
solution:
  name: "Feature Name"
  date: "YYYY-MM-DD"
  summary: "One-line description"

patterns_used:
  - name: "Pattern Name"
    rationale: "Why it was chosen"
    files: ["src/...", "src/..."]

lessons_learned:
  - category: "performance|security|architecture|testing"
    insight: "What we learned"
    avoid: "What to avoid next time"

keywords: ["auth", "api", "database"]  # For search
```

---

## A3: Adaptive Research Depth (Phase 2)

**Gap Addressed:** G3 - Static research regardless of risk

**Solution:** Decision logic that adjusts research depth based on:

1. **High-risk indicators** (payments, auth, security) → Upgrade depth
2. **Existing patterns** (similar code exists) → Reduce depth

```yaml
# Mode × Risk interaction
| Mode     | Low Risk | Medium Risk | High Risk |
|----------|----------|-------------|-----------|
| Rapid    | MINIMAL  | MINIMAL     | STANDARD  |
| Standard | MINIMAL  | STANDARD    | STANDARD  |
| Advanced | STANDARD | STANDARD    | DEEP      |
| Complete | STANDARD | DEEP        | DEEP      |
```

**Modes:** All
**Effort:** Low | **Impact:** Medium

**Acceptance Criteria:**
- [ ] Risk detection logic exists in Phase 2 workflow
- [ ] High-risk keywords defined in config: `risk_keywords: [payments, auth, security, ...]`
- [ ] Mode × Risk matrix implemented as documented
- [ ] State file includes `research_depth: MINIMAL|STANDARD|DEEP`
- [ ] Depth affects: number of agents, search scope, analysis detail

---

## A4: Expert Review Phase (Phase 6b)

**Gap Addressed:** G4 - Quantitative-only validation

**Solution:** 2 specialized reviewers after PAL Consensus:
- `security-analyst` (blocking on CRITICAL findings)
- `simplicity-reviewer` (advisory)

**Tiered Capability:**
| Tier | When | Security Review Scope |
|------|------|----------------------|
| Basic | A1 not available (Phase 2) | Code-based analysis only |
| Enhanced | A1 available (Phase 3+) | Code + user flow security analysis |

When A1 (Flow Analysis) data is available, security review includes:
- Authentication flow validation at each user journey branch
- Permission boundary checks across flow decision points
- Session handling verification for flow state transitions

**Modes:** Complete, Advanced
**Effort:** Medium | **Impact:** High

**Acceptance Criteria:**
- [ ] `agents/reviewers/security-analyst.md` exists
- [ ] `agents/reviewers/simplicity-reviewer.md` exists
- [ ] Security review runs after PAL Consensus
- [ ] CRITICAL security findings block completion (require user acknowledgment)
- [ ] Simplicity feedback is advisory (non-blocking)
- [ ] State file includes `expert_review: {security: PASS|FAIL|WARN, simplicity: {...}}`

**Security Finding Severity Definitions:**
| Severity | Definition | Blocking? |
|----------|------------|-----------|
| CRITICAL | Data breach, auth bypass, injection vulnerability, compliance violation | Yes |
| HIGH | Privilege escalation, sensitive data exposure, broken access control | Yes |
| MEDIUM | Information disclosure, missing security headers, weak crypto | No (advisory) |
| LOW | Minor hardening issues, best practice deviations | No (advisory) |

---

## A5: Post-Planning Decision Menu (Phase 9)

**Gap Addressed:** G5 - Limited options after planning

**Solution:** Structured menu with options:
1. Review in editor
2. Get expert review
3. Simplify plan
4. Create GitHub issue
5. Commit artifacts

**Modes:** All
**Effort:** Low | **Impact:** Medium

**Acceptance Criteria:**
- [ ] Menu appears after Phase 9 artifacts generated
- [ ] All 5 options functional (review, expert, simplify, issue, commit)
- [ ] Each option has clear help text
- [ ] "Expert review" triggers A4 reviewers
- [ ] "Create issue" generates GitHub-compatible markdown
- [ ] "Commit" stages and commits with conventional commit message

---

# Part B: Process Improvements (SADD Patterns)

*These improvements enhance HOW planning decisions are made, based on research-backed patterns from the SADD plugin.*

## S1: Self-Critique Loop (Universal)

**Gap Addressed:** G6 - No self-verification on agent outputs

**Research Foundation:** Constitutional AI Self-Critique (Bai et al., 2022) - catches **40-60% of issues** before delivery.

**Note on Related Techniques:**
- **Constitutional AI** (Bai et al., 2022): Self-critique against principles/rules
- **Chain-of-Verification** (Dhuliawala et al., 2023): Verification questions to reduce hallucination
- This improvement combines both: structured verification questions (CoVe-style) with principle-based self-critique (Constitutional AI-style)

**Solution:** Add mandatory self-critique section to ALL agent prompts:

```markdown
## Self-Critique Loop (MANDATORY)

Before completing, you MUST verify your work:

### 1. Generate 5 Verification Questions
Ask yourself task-specific questions:
- Does my output address all requirements from the spec?
- Have I considered edge cases and error conditions?
- Is my recommendation backed by evidence?
- Have I identified risks and assumptions?
- Is my output actionable and specific?

### 2. Answer Each Question with Evidence
For each question, provide:
- Your answer (YES/NO/PARTIAL)
- Specific evidence (file paths, code snippets, references)

### 3. Revise If Needed
If ANY question reveals a gap:
1. STOP - Do not submit incomplete work
2. FIX - Address the specific gap
3. RE-VERIFY - Confirm the fix
4. DOCUMENT - Note what was changed

### 4. Output Self-Critique Summary
```yaml
self_critique:
  questions_passed: X/5
  revisions_made: N
  revision_summary: "Description of changes made"
```
```

**Implementation:**
- Add to ALL agents in `agents/*.md`
- No workflow changes required
- ~10-15% token increase per agent

**Value:**
- Catches issues at source (before propagation)
- Creates audit trail of verification
- Improves agent output quality consistently

**Modes:** ALL (with mode-specific thresholds)
**Effort:** Low | **Impact:** HIGH

**Mode-Specific Configuration:**

| Mode | Questions | Threshold | Evidence Required |
|------|-----------|-----------|-------------------|
| Rapid | 3 | 2/3 pass | No (optional) |
| Standard | 5 | 4/5 pass | Yes |
| Advanced | 5 | 4/5 pass | Yes |
| Complete | 5 | 5/5 pass | Yes (detailed) |

**Acceptance Criteria:**
- [ ] All agents in `agents/*.md` include self-critique section
- [ ] Section follows template in `references/self-critique-template.md`
- [ ] Agent outputs include `self_critique:` YAML block
- [ ] Mode-appropriate threshold enforced (see table above)
- [ ] Revisions documented when made

---

## S2: Zero-Shot Chain-of-Thought Prefix (Universal)

**Gap Addressed:** Implicit reasoning leads to errors

**Research Foundation:** Kojima et al. (2022) - improves reasoning by **20-60%**.

**Solution:** Add reasoning structure to ALL agent prompts:

```markdown
## Reasoning Approach

Before taking any action, think through the problem systematically:

1. "Let me first understand what is being asked..."
   - What is the core objective?
   - What are the explicit requirements?
   - What constraints apply?

2. "Let me break this down into concrete steps..."
   - What are the major components?
   - What order should I tackle them?
   - What dependencies exist?

3. "Let me consider what could go wrong..."
   - What assumptions am I making?
   - What edge cases might exist?
   - What could fail?

4. "Let me verify my approach before proceeding..."
   - Does my plan address all requirements?
   - Is there a simpler approach?
   - Am I over-engineering?
```

**Implementation:**
- Add to ALL agents in `agents/*.md`
- ~5% token increase per agent

**Modes:** ALL
**Effort:** Low | **Impact:** HIGH

**Acceptance Criteria:**
- [ ] All agents in `agents/*.md` include CoT reasoning section
- [ ] Section follows template in `references/cot-prefix-template.md`
- [ ] Agent outputs demonstrate explicit reasoning steps
- [ ] Agent output includes at least 3 of 4 reasoning sections
- [ ] "Let me..." phrases appear in agent thinking (minimum 2 occurrences)

**Verification Method:**
```bash
# Check agent output includes reasoning markers
grep -c "Let me" agent_output.md  # Should be >= 2
grep -E "(understand|break.*(down|this)|consider|verify)" agent_output.md  # Should match 3+ sections
```

---

## S3: Judge Gates Between Phases (Advanced/Complete)

**Gap Addressed:** G8 - No quality gates, errors propagate

**Research Foundation:** Do-in-Steps pattern from SADD - iterative verification with retry.

**Problem:** Errors compound across phases:
- Research error → wrong architecture assumptions
- Architecture error → impossible implementation
- Each phase trusts previous output without verification

**Solution:** Add judge verification after critical phases:

```
┌─────────────────────────────────────────────────────────────────┐
│               JUDGE GATES AT PHASE BOUNDARIES                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Phase 2: Research                                               │
│       ↓                                                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ GATE 1: Research Completeness                             │  │
│  │ Criteria:                                                 │  │
│  │ - All unknowns from spec addressed?                       │  │
│  │ - Codebase patterns identified?                           │  │
│  │ - Integration points mapped?                              │  │
│  │                                                           │  │
│  │ Score ≥3.5/5.0 → PASS → Phase 3                          │  │
│  │ Score <3.5 → RETRY with feedback (max 2)                 │  │
│  │ Still failing → ESCALATE to user                         │  │
│  └───────────────────────────────────────────────────────────┘  │
│       ↓                                                          │
│  Phase 4: Architecture                                           │
│       ↓                                                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ GATE 2: Architecture Quality                              │  │
│  │ Criteria:                                                 │  │
│  │ - All requirements addressed?                             │  │
│  │ - Trade-offs documented?                                  │  │
│  │ - Risks identified?                                       │  │
│  │ - Consistent with codebase patterns?                      │  │
│  └───────────────────────────────────────────────────────────┘  │
│       ↓                                                          │
│  Phase 7: Test Strategy                                          │
│       ↓                                                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ GATE 3: Test Coverage                                     │  │
│  │ Criteria:                                                 │  │
│  │ - All ACs have tests?                                     │  │
│  │ - Critical risks mitigated?                               │  │
│  │ - UAT scripts complete?                                   │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Judge Prompt Template:**

```markdown
---
name: phase-gate-judge
model: haiku
---

# Role

You are a Quality Gate Judge verifying phase completion.

# Instructions

Evaluate the {PHASE_NAME} output against these criteria:
{CRITERIA_LIST}

For each criterion:
1. Score 1-5 (1=missing, 3=adequate, 5=excellent)
2. Provide specific evidence
3. If <3, specify what's missing

# Output Format

```yaml
---
VERDICT: [PASS/FAIL]
SCORE: [X.X]/5.0
CRITERIA_SCORES:
  criterion_1: X/5
  criterion_2: X/5
  ...
ISSUES:
  - {specific issue if any}
IMPROVEMENTS:
  - {specific improvement needed}
---
```
```

**Retry Logic:**
1. If FAIL: Provide feedback to original agent
2. Agent revises output incorporating feedback
3. Re-evaluate (max 2 retries)
4. If still failing: Escalate to user with report

**Cost-Benefit:**
- 3 judge calls: ~$0.10-0.15
- Prevents 1 cycle back: saves ~$0.30-0.50
- NET: Positive ROI if gates prevent even ONE iteration

**Modes:** Advanced, Complete
**Effort:** Medium | **Impact:** HIGH

**Acceptance Criteria:**
- [ ] `agents/judges/phase-gate-judge.md` exists
- [ ] Judge prompts include calibration examples (see below)
- [ ] Gates at: Phase 2→3, Phase 4→5, Phase 7→8
- [ ] Retry logic: max 2 retries with specific feedback
- [ ] Escalation path: user notification after max retries
- [ ] State file tracks `gate_results: [{phase, score, verdict, retries}]`

**Judge Calibration Methodology:**

Judges need calibration examples to score consistently. Each judge prompt MUST include:

1. **Explicit Rubric with Level Definitions:**
```yaml
scoring_rubric:
  1_missing: "Criterion not addressed at all"
  2_incomplete: "Criterion partially addressed, major gaps"
  3_adequate: "Criterion addressed, minor gaps acceptable"
  4_good: "Criterion well addressed, no significant gaps"
  5_excellent: "Criterion thoroughly addressed, exceeds expectations"
```

2. **Calibration Examples (2-3 per criterion):**
```markdown
### Calibration Example: Research Completeness

**Score 3 (Adequate):**
"Research identified main integration points (API, database) but
did not explore authentication flow. Missing: auth patterns,
session handling. Acceptable for Standard mode."

**Score 5 (Excellent):**
"Research comprehensively mapped: 5 integration points, 3 existing
patterns, auth flow including edge cases (session expiry, refresh
tokens), and identified 2 unknowns requiring user clarification."
```

3. **Common Failure Modes:**
```markdown
### Watch for these issues:
- Scores given without evidence citations
- All criteria scored identically (lazy evaluation)
- Missing consideration of mode-specific expectations
- Ignoring retry feedback from previous attempt
```

**Threshold Semantics:**
- Pass threshold: `score >= 3.5/5.0`
- Where 3.5 means: "All criteria at least adequate (3), with some good/excellent (4-5)"
- Scale: 1=missing, 2=incomplete, 3=adequate, 4=good, 5=excellent

---

## S4: Adaptive Strategy Selection (Advanced/Complete)

**Gap Addressed:** Wasted synthesis when clear winner exists

**Research Foundation:** Generate-Critique-Synthesize (GCS) pattern from SADD.

**Problem:** Current workflow always synthesizes architecture options, even when:
- One option is clearly superior
- All options are weak and need redesign
- Options are too similar to meaningfully synthesize

**Solution:** Adaptive strategy based on evaluation results:

```
┌─────────────────────────────────────────────────────────────────┐
│               ADAPTIVE STRATEGY SELECTION                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  After architecture evaluation, parse judge scores:              │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ IF clear winner (score gap ≥0.5)                           ││
│  │    → SELECT_AND_POLISH                                      ││
│  │    "Option A scores significantly higher. Focusing on      ││
│  │     refinement rather than synthesis."                      ││
│  │    Actions: Polish winner with judge feedback               ││
│  │    Cost: Save synthesis step (~15-20%)                      ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ IF all options weak (all scores <3.0)                      ││
│  │    → REDESIGN                                               ││
│  │    "All options have fundamental issues. Returning to      ││
│  │     exploration with learnings."                            ││
│  │    Actions: Analyze failures, re-explore with constraints   ││
│  │    Cost: +1 exploration cycle                               ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ IF split decision (scores within 0.3, all ≥3.0)            ││
│  │    → FULL_SYNTHESIS                                         ││
│  │    "Multiple strong options. Synthesizing best elements    ││
│  │     from each."                                             ││
│  │    Actions: Combine strengths, document trade-offs          ││
│  │    Cost: Normal path                                        ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Implementation:**
- Add decision logic after Phase 4 evaluation
- Route to appropriate synthesis path
- Document rationale in state file

**Modes:** Advanced, Complete
**Effort:** Low | **Impact:** Medium (cost optimization)

**Mode-Dependent Behavior:**
- **Advanced mode**: Evaluates 3 MPA options (minimal/clean/pragmatic)
- **Complete mode**: Evaluates 4+ ToT options (when S5 enabled)

S4 adapts to available input—works with both standard MPA and ToT-generated options. The strategy selection logic is input-agnostic; only the number and diversity of options changes.

**Acceptance Criteria:**
- [ ] Decision logic implemented after Phase 4 evaluation
- [ ] Three strategies: SELECT_AND_POLISH, REDESIGN, FULL_SYNTHESIS
- [ ] Strategy selection logged to state file
- [ ] Rationale documented for each selection
- [ ] REDESIGN triggers return to exploration with learned constraints
- [ ] Unit test validates strategy selection with test vectors

**Test Vectors for Strategy Selection:**
```yaml
test_cases:
  - name: "Clear winner - SELECT_AND_POLISH"
    scores: [4.5, 3.8, 3.5]
    expected_strategy: SELECT_AND_POLISH
    reason: "Gap of 0.7 >= 0.5 threshold"

  - name: "All weak - REDESIGN"
    scores: [2.8, 2.5, 2.3]
    expected_strategy: REDESIGN
    reason: "All scores < 3.0"

  - name: "Split decision - FULL_SYNTHESIS"
    scores: [4.0, 3.8, 3.7]
    expected_strategy: FULL_SYNTHESIS
    reason: "Gap of 0.3 < 0.5, all scores >= 3.0"

  - name: "Edge case - borderline winner"
    scores: [4.0, 3.5, 3.4]
    expected_strategy: SELECT_AND_POLISH
    reason: "Gap of 0.5 equals threshold (>=)"

  - name: "Edge case - borderline weak"
    scores: [3.0, 2.9, 2.8]
    expected_strategy: REDESIGN
    reason: "Not all scores >= 3.0"
```

---

## S5: Hybrid ToT-MPA Architecture Design (Complete Only)

**Gap Addressed:** G7 - Predetermined options limit exploration

**Research Foundation:** Tree of Thoughts (Yao et al., 2023) - **40-70% improvement** on complex reasoning requiring exploration.

**Problem:** Current MPA uses 3 predetermined perspectives:
- Minimal Change
- Clean Architecture
- Pragmatic Balance

This LIMITS exploration to pre-defined categories. What if the best solution doesn't fit these categories?

**Solution:** Hybrid Tree of Thoughts with MPA seeding:

```
┌─────────────────────────────────────────────────────────────────┐
│            HYBRID ToT-MPA ARCHITECTURE DESIGN                    │
│                    (Complete Mode Only)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Phase 4a: SEEDED EXPLORATION                                    │
│  ├── Minimal perspective: 2 approaches (seeded)                 │
│  ├── Clean perspective: 2 approaches (seeded)                   │
│  ├── Pragmatic perspective: 2 approaches (seeded)               │
│  └── Wildcard agent: 2 approaches (unconstrained)               │
│  Total: 8 candidate approaches                                   │
│                                                                  │
│  Each approach includes:                                         │
│  - Brief description                                             │
│  - Probability estimate (0.0-1.0)                               │
│  - Key trade-offs                                                │
│  - Self-critique verification                                    │
│                                                                  │
│  Phase 4b: MULTI-CRITERIA PRUNING                                │
│  ├── 3 judges evaluate all 8 approaches                         │
│  ├── Ranked choice voting (1st=3pts, 2nd=2pts, 3rd=1pt)        │
│  ├── Select top 4 (preserve diversity)                          │
│  └── Document elimination rationale                              │
│                                                                  │
│  Phase 4c: COMPETITIVE EXPANSION                                 │
│  ├── 4 agents develop full designs in parallel                  │
│  ├── Each incorporates pruning feedback                         │
│  ├── Constitutional AI self-critique on each                    │
│  └── Output: 4 complete architecture designs                     │
│                                                                  │
│  Phase 4d: EVALUATION + ADAPTIVE SELECTION                       │
│  ├── 3 judges evaluate all 4 designs                            │
│  ├── Structured rubric scoring                                   │
│  ├── Apply Adaptive Strategy (S4):                              │
│  │   ├── CLEAR_WINNER → Polish                                  │
│  │   ├── TIE → Synthesize top 2                                 │
│  │   └── ALL_WEAK → Return to 4a with learnings                 │
│  └── Final design with full documentation                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Why Hybrid > Pure ToT or Pure MPA:**

| Approach | Pros | Cons |
|----------|------|------|
| Pure MPA | Practical, grounded | Limited exploration |
| Pure ToT | Wide exploration | May produce impractical solutions |
| **Hybrid** | **Grounded + Innovative** | Higher cost |

**Agent Configuration:**

```yaml
tot_architecture:
  exploration:
    seeded_agents:
      - perspective: minimal
        prompt: "Generate 2 architecture approaches prioritizing minimal change..."
        approaches: 2
      - perspective: clean
        prompt: "Generate 2 architecture approaches prioritizing clean architecture..."
        approaches: 2
      - perspective: pragmatic
        prompt: "Generate 2 architecture approaches balancing constraints..."
        approaches: 2
    wildcard_agent:
      prompt: "Generate 2 innovative architecture approaches without constraints..."
      approaches: 2
      guidance: "First approach: high-probability (>0.8). Second: experimental (<0.2)"

  pruning:
    judges: 3
    voting: ranked_choice
    keep: 4  # More than standard ToT (3) to preserve diversity

  expansion:
    agents: 4
    include_self_critique: true

  evaluation:
    judges: 3
    adaptive_strategy: true
```

**Cost Analysis:**
- Exploration (4 agents × 2 approaches): ~$0.12
- Pruning (3 judges): ~$0.05
- Expansion (4 agents): ~$0.16
- Evaluation (3 judges): ~$0.05
- **Total: ~$0.38** vs current Complete mode MPA (~$0.22) = 1.7x increase

**Phase 4 Architecture Cost Comparison:**

| Approach | Phase 4 Cost | Description |
|----------|--------------|-------------|
| Standard MPA | ~$0.15 | 3 agents (minimal/clean/pragmatic), Standard mode |
| Complete MPA | ~$0.22 | 3 agents + synthesis step, Complete mode current |
| **Hybrid ToT-MPA** | ~$0.38 | 4 phases (explore/prune/expand/evaluate), Complete mode proposed |

*Note: These are Phase 4 costs only. Total workflow costs are shown in the main Cost Analysis section.*

**Value:** Significantly better architecture exploration for critical features.

**Modes:** Complete only
**Effort:** High | **Impact:** HIGH

**Acceptance Criteria:**
- [ ] Exploration phase produces 8 candidate approaches
- [ ] Pruning selects top 4 using ranked-choice voting
- [ ] Expansion produces 4 complete designs with self-critique
- [ ] Evaluation uses adaptive strategy (S4)
- [ ] Wildcard agent produces at least 1 non-traditional approach
- [ ] State tracks all 8 initial + 4 expanded + final selected
- [ ] `references/tot-workflow.md` documents complete flow

---

## S6: Multi-Judge Debate for Validation (Complete Only)

**Gap Addressed:** G9 - Single-round validation misses nuance

**Research Foundation:** Multi-Agent Debate (Du et al., 2023) - **15-25% improvement** in evaluation accuracy.

**Problem:** Current PAL Consensus is single-round:
- 3 models evaluate in parallel
- Scores aggregated
- No opportunity for models to challenge each other

**Solution:** Iterative debate until consensus:

```
┌─────────────────────────────────────────────────────────────────┐
│            MULTI-JUDGE DEBATE FOR VALIDATION                     │
│                    (Complete Mode Only)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Round 1: Independent Analysis                                   │
│  ├── Judge 1 (gemini): Analyze plan → Write report.md          │
│  ├── Judge 2 (gpt-5.2): Analyze plan → Write report.md         │
│  └── Judge 3 (grok-4): Analyze plan → Write report.md          │
│                                                                  │
│  Each report includes:                                           │
│  - Overall score (1-5)                                          │
│  - Per-dimension scores                                          │
│  - Specific evidence for each score                             │
│  - Concerns and recommendations                                  │
│                                                                  │
│  Check Consensus: All scores within 0.5?                         │
│  ├── YES → Consensus reached, proceed                           │
│  └── NO → Continue to Round 2                                   │
│                                                                  │
│  Round 2: Debate                                                 │
│  ├── Each judge reads other judges' reports                     │
│  ├── Each judge writes rebuttal:                                │
│  │   - "I agree with Judge X on... because..."                  │
│  │   - "I disagree with Judge Y on... because..."               │
│  │   - "Based on this, I revise my score to..."                 │
│  │   OR "I maintain my score because..."                        │
│  └── Document what changed minds or why positions held          │
│                                                                  │
│  Check Consensus: All scores within 0.5?                         │
│  ├── YES → Consensus reached                                    │
│  └── NO → Round 3 (final)                                       │
│                                                                  │
│  Round 3: Final Positions (if needed)                            │
│  ├── Final arguments from each judge                            │
│  ├── Force verdict (majority rules)                             │
│  └── Document minority opinion for user review                  │
│                                                                  │
│  Output:                                                         │
│  - Consensus score (or majority + minority)                     │
│  - Convergent findings (all judges agree)                       │
│  - Divergent findings (flagged for user)                        │
│  - Debate transcript (audit trail)                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Consensus Criteria:**
- Overall scores within 0.5 points
- Per-dimension scores within 1.0 points
- No unresolved CRITICAL findings

**Implementation Notes:**
- Judges write to filesystem (context isolation)
- Each judge reads others' files directly
- Max 3 rounds (diminishing returns beyond)

**Cost Analysis:**
- Best case (Round 1 consensus): 3 calls
- Typical (Round 2 consensus): 6 calls
- Worst case (Round 3): 9 calls
- Average: ~5-6 calls vs current 3 (~2x cost)

**Modes:** Complete only
**Effort:** Medium | **Impact:** Medium-High

**Acceptance Criteria:**
- [ ] Debate protocol in `references/debate-protocol.md`
- [ ] Max 3 rounds implemented
- [ ] Consensus threshold: scores within 0.5 points
- [ ] Divergent findings flagged for user review
- [ ] Minority opinion documented when majority rule applies
- [ ] Debate transcript saved to state for audit
- [ ] `agents/judges/debate-judge.md` exists

---

# Integration Matrix

How Context (A) and Process (S) improvements work together:

```
┌─────────────────────────────────────────────────────────────────┐
│                    IMPROVEMENT SYNERGIES                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PHASE 2: Research                                               │
│  ├── A2 (Learnings) provides historical context                 │
│  ├── A3 (Adaptive Depth) adjusts research level                 │
│  ├── S1 (Self-Critique) verifies research completeness          │
│  ├── S2 (CoT) improves reasoning quality                        │
│  └── S3 (Judge Gate) validates before architecture              │
│                                                                  │
│  PHASE 2b: Flow Analysis                                         │
│  ├── A1 (Flow Analyzer) discovers user journeys                 │
│  ├── S1 (Self-Critique) verifies flow completeness              │
│  └── Output feeds Phase 3 questions                             │
│                                                                  │
│  PHASE 4: Architecture                                           │
│  ├── A1 (Flow Matrix) informs user journey requirements         │
│  ├── S5 (Hybrid ToT-MPA) explores systematically                │
│  ├── S1 (Self-Critique) on each approach                        │
│  ├── S4 (Adaptive Strategy) optimizes synthesis                 │
│  └── S3 (Judge Gate) validates before ThinkDeep                 │
│                                                                  │
│  PHASE 6: Validation                                             │
│  ├── S6 (Multi-Judge Debate) reaches deep consensus             │
│  └── A4 (Expert Review) adds qualitative feedback               │
│                                                                  │
│  PHASE 7: Test Strategy                                          │
│  ├── S1 (Self-Critique) verifies coverage                       │
│  ├── S3 (Judge Gate) validates completeness                     │
│  └── A1 (Flow Matrix) reused for test scenarios                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

# Implementation Roadmap

## Phase 1: Universal Foundations (Week 1)

*High impact, low effort - applies to ALL modes*

| ID | Improvement | Effort | Files Changed |
|----|-------------|--------|---------------|
| S1 | Self-Critique Loop | Low | All `agents/*.md` |
| S2 | CoT Prefix | Low | All `agents/*.md` |
| A5 | Post-Planning Menu | Low | `skills/plan/SKILL.md` |
| A3 | Adaptive Research Depth | Low | `config/planning-config.yaml`, Phase 2 logic |

**Deliverables:**
- Updated agent prompts with self-critique and CoT
- Post-planning decision menu
- Adaptive research depth logic

**Expected Impact:**
- 20-60% reasoning improvement (CoT)
- 40-60% error reduction (Self-Critique)
- Better UX (Post-Planning Menu)

---

## Phase 2: Quality Gates (Week 2)

*Medium effort - Advanced/Complete modes*

| ID | Improvement | Effort | Files Changed |
|----|-------------|--------|---------------|
| S3 | Judge Gates | Medium | Phase 2, 4, 7 workflows |
| S4 | Adaptive Strategy | Low | Phase 4 synthesis logic |
| A4 | Expert Review | Medium | New `agents/reviewers/*.md` |

**Deliverables:**
- Judge gate agents and logic
- Adaptive strategy selection
- Security and simplicity reviewers

**Expected Impact:**
- Early error detection
- 15-20% cost savings on synthesis
- Qualitative feedback on plans

---

## Phase 3: Advanced Exploration (Weeks 3-4)

*High effort - Complete mode only*
*Extended timeline: ToT implementation is complex, budget 2 weeks*

| ID | Improvement | Effort | Files Changed |
|----|-------------|--------|---------------|
| S5 | Hybrid ToT-MPA | High | Phase 4 complete rewrite |
| S6 | Multi-Judge Debate | Medium | Phase 6 validation |
| A1 | User Flow Analysis | Medium | New Phase 2b |

**Deliverables:**
- Tree of Thoughts architecture exploration
- Multi-round debate validation
- Flow analyzer agent

**Expected Impact:**
- Significantly better architecture exploration
- Deeper validation consensus
- Complete user journey coverage

---

## Phase 4: Knowledge System (Ongoing)

*Requires organizational adoption*

| ID | Improvement | Effort | Dependencies |
|----|-------------|--------|--------------|
| A2 | Institutional Knowledge | Medium | `docs/solutions/` structure |

**Deliverables:**
- Learnings researcher agent
- YAML schema for solutions
- Graceful degradation when absent

---

# Cost Analysis

## Per-Mode Cost Comparison

| Mode | Current | Phase 1 | Phase 2 | Phase 3 | Notes |
|------|---------|---------|---------|---------|-------|
| **Rapid** | $0.05-0.12 | $0.06-0.14 | - | - | +10% (self-critique) |
| **Standard** | $0.15-0.30 | $0.17-0.33 | - | - | +10% (self-critique + CoT) |
| **Advanced** | $0.45-0.75 | $0.50-0.83 | $0.60-1.00 | - | +judge gates, adaptive strategy |
| **Complete** | $0.80-1.50 | $0.88-1.65 | $1.00-1.90 | $1.40-2.50 | +ToT, debate |

## ROI Analysis

| Improvement | Cost Increase | Expected Benefit | ROI |
|-------------|---------------|------------------|-----|
| S1 (Self-Critique) | +10% | 40-60% fewer errors | **HIGH** |
| S2 (CoT) | +5% | 20-60% better reasoning | **HIGH** |
| S3 (Judge Gates) | +$0.10-0.15 | Prevents 1+ iteration | **MEDIUM-HIGH** |
| S4 (Adaptive) | Logic only | 15-20% synthesis savings | **MEDIUM** |
| S5 (ToT) | +$0.20-0.25 | Significantly better architecture | **MEDIUM** |
| S6 (Debate) | +$0.05-0.10 | Deeper consensus | **LOW-MEDIUM** |

### ROI Measurement Methodology

The expected benefits above are derived from academic literature. To validate in practice:

**1. Self-Critique Error Reduction (S1)**
- **Measurement**: Compare `self_critique.revisions_made` rate before/after
- **Baseline**: Run 20 sessions without self-critique, count issues found in review
- **Target**: Issues found in review should decrease 40-60%
- **Source**: Bai et al. (2022) Constitutional AI reports 40-60% reduction in harmful outputs

**2. CoT Reasoning Improvement (S2)**
- **Measurement**: Judge gate scores on reasoning-heavy phases (Phase 4)
- **Baseline**: Average gate score without CoT prefix
- **Target**: Gate scores improve 0.5-1.0 points (20-60% relative)
- **Source**: Kojima et al. (2022) Zero-Shot CoT shows 20-60% improvement on reasoning benchmarks

**3. Judge Gate Iteration Prevention (S3)**
- **Measurement**: Count workflow restarts and user escalations
- **Baseline**: Track how often users reject plans and request rework
- **Target**: Rework requests decrease by preventing early errors
- **Calculation**: If gates cost $0.12 and prevent one $0.40 rework cycle, ROI is positive

**4. ToT Architecture Quality (S5)**
- **Measurement**: Diversity of solutions explored, final plan score
- **Baseline**: MPA produces 3 approaches, typically 1-2 viable
- **Target**: ToT produces 8 approaches, 3-4 viable, higher final score
- **Source**: Yao et al. (2023) Tree of Thoughts shows 40-70% improvement on complex reasoning

**5. Debate Consensus Depth (S6)**
- **Measurement**: Convergent vs divergent findings, user agreement rate
- **Baseline**: Single-round consensus misses 15-25% of nuanced issues
- **Target**: Multi-round debate surfaces more divergent findings for user review
- **Source**: Du et al. (2023) Multi-Agent Debate shows 15-25% improvement in evaluation accuracy

**Validation Protocol:**
1. Run 10 sessions with improvement OFF (baseline)
2. Run 10 sessions with improvement ON (treatment)
3. Compare metrics using t-test or Mann-Whitney U
4. Require p < 0.05 for statistical significance
5. Document results in `docs/improvement-validation.md`

---

# Risk Analysis

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Self-critique adds noise | Low | Low | Structured format, evidence required |
| Judge gates slow workflow | Medium | Medium | Threshold tuning, skip option |
| ToT produces impractical designs | Low | Medium | MPA seeding grounds exploration |
| Debate doesn't converge | Low | Low | Max 3 rounds, majority rule |
| Cost increase unacceptable | Medium | High | Per-mode enablement, feature flags |
| Implementation complexity | Medium | Medium | Phased rollout, test at each phase |
| Improvement ordering dependencies | Medium | Medium | Phase gates validate dependencies; config checks |

## MCP Tool Degradation Matrix

Several improvements depend on MCP tools. The workflow gracefully degrades when tools are unavailable:

| Improvement | MCP Tool Required | Fallback Behavior |
|-------------|-------------------|-------------------|
| S5 (Hybrid ToT-MPA) | `mcp__sequential-thinking` | Falls back to standard MPA (3 predetermined options) |
| S6 (Multi-Judge Debate) | `mcp__pal__consensus` | Falls back to single-round PAL Consensus |
| S3 (Judge Gates) | None | Always available (uses internal agent) |
| S1 (Self-Critique) | None | Always available (prompt modification only) |
| S2 (CoT Prefix) | None | Always available (prompt modification only) |
| A1 (Flow Analysis) | None | Always available (uses internal agent) |
| A4 (Expert Review) | None | Always available (uses internal agents) |

**Detection:** At workflow start, check MCP tool availability:
```yaml
mcp_availability:
  sequential_thinking: true|false
  pal_thinkdeep: true|false
  pal_consensus: true|false

# Automatic mode adjustment
if not mcp_availability.sequential_thinking:
  disable: [S5]  # ToT falls back to MPA
if not mcp_availability.pal_consensus:
  disable: [S6]  # Debate falls back to single-round
```

## Observability & Logging Strategy

To measure effectiveness and debug issues, implement structured logging.

### MVP Logging Schema (Phase 1)

Start with minimal logging to validate the approach:

```yaml
# Minimal viable logging - implement first
planning_session_mvp:
  session_id: "uuid"
  mode: "Complete|Advanced|Standard|Rapid"
  phases_completed: ["SETUP", "RESEARCH", "ARCHITECTURE", "VALIDATION"]
  total_cost_usd: 0.87
  gate_results:
    - {phase: "RESEARCH", verdict: "PASS", retries: 0}
    - {phase: "ARCHITECTURE", verdict: "PASS", retries: 1}
  improvements_active: ["self_critique", "cot_prefix", "judge_gates"]
  outcome: "completed|abandoned|error"
  duration_seconds: 180
```

### Full Logging Schema (Phase 2+)

Expand to comprehensive logging after MVP validated:

```yaml
# Full logging schema for planning sessions
planning_session:
  session_id: "uuid"
  mode: "Complete|Advanced|Standard|Rapid"
  start_time: "ISO8601"
  end_time: "ISO8601"

  phases:
    - phase: 2
      name: "Research"
      duration_ms: 12500
      agent_calls: 3
      tokens_used: 4200
      gate_result:
        score: 4.2
        verdict: "PASS"
        retries: 0

  improvements_active:
    self_critique: true
    cot_prefix: true
    judge_gates: true
    tot_architecture: false

  costs:
    total_usd: 0.87
    by_phase: {2: 0.15, 3: 0.05, 4: 0.35, ...}

  quality_metrics:
    gate_pass_rate: 1.0  # 3/3 passed
    retry_count: 0
    user_escalations: 0
    self_critique_revision_rate: 0.4  # 40% of agents revised

  outcome:
    plan_score: 17.5  # Consensus score
    user_satisfaction: null  # Optional feedback
```

**Key Metrics to Track:**
1. **Cost per mode** - Validate cost estimates
2. **Gate pass rate** - Are thresholds calibrated correctly?
3. **Self-critique revision rate** - Is it catching real issues?
4. **ToT diversity score** - Are wildcard agents producing novel approaches?
5. **Debate convergence rounds** - How often do we hit max rounds?

**Implementation:**
- Log to `{FEATURE_DIR}/.planning-metrics.local.json`
- Aggregate across sessions for tuning
- Optional: Send anonymized metrics to improve defaults

## Feature Flags for Rollback

```yaml
# config/planning-config.yaml
feature_flags:
  # Universal
  self_critique:
    enabled: true
    rollback: "Set false to remove from agents"

  cot_prefix:
    enabled: true
    rollback: "Set false to remove from agents"

  # Advanced/Complete
  judge_gates:
    enabled: true
    rollback: "Set false to skip gates"

  adaptive_strategy:
    enabled: true
    rollback: "Set false to always synthesize"

  # Complete only
  tot_architecture:
    enabled: true
    rollback: "Set false to use standard MPA"

  multi_judge_debate:
    enabled: true
    rollback: "Set false to use single-round"

  # Context improvements
  flow_analysis:
    enabled: true
    rollback: "Set false to skip Phase 2b"

  learnings_researcher:
    enabled: true
    rollback: "Set false to skip learnings search"

  adaptive_depth:
    enabled: true
    rollback: "Set false for mode-based depth only"

  expert_review:
    enabled: true
    rollback: "Set false to skip Phase 6b"
```

## Gradual Rollout Strategy

For large organizations or risk-averse deployments, enable percentage-based rollout:

```yaml
# config/planning-config.yaml
gradual_rollout:
  enabled: true

  # Percentage of sessions using new improvements
  percentages:
    self_critique: 100      # Fully rolled out
    cot_prefix: 100         # Fully rolled out
    judge_gates: 50         # 50% of Advanced/Complete sessions
    adaptive_strategy: 50   # Same cohort as judge_gates
    tot_architecture: 10    # 10% of Complete sessions (experimental)
    multi_judge_debate: 10  # Same cohort as ToT

  # Cohort assignment
  cohort_key: "session_id"  # Use session_id for randomization
  sticky_cohort: true       # Same user gets same experience

  # Metrics comparison
  compare_cohorts: true     # Log A/B comparison metrics
```

**Rollout Phases:**
1. **Internal testing** (0%): Team validates all improvements work
2. **Canary** (10%): Small percentage catches major issues
3. **Gradual** (50%): Half of sessions, compare metrics
4. **Full** (100%): All sessions use improvement

**Success Criteria for Promotion:**
- No increase in user escalations
- Cost within 20% of estimate
- Gate pass rate > 80%
- No degradation in plan quality scores

---

# Files to Create

## New Agents

| File | Purpose | Priority |
|------|---------|----------|
| `agents/flow-analyzer.md` | User flow analysis (A1) | MEDIUM |
| `agents/learnings-researcher.md` | Institutional knowledge (A2) | LOW |
| `agents/reviewers/security-analyst.md` | Security review (A4) | MEDIUM |
| `agents/reviewers/simplicity-reviewer.md` | Simplicity review (A4) | MEDIUM |
| `agents/judges/phase-gate-judge.md` | Quality gates (S3) | HIGH |
| `agents/judges/debate-judge.md` | Multi-round debate (S6) | MEDIUM |
| `agents/judges/architecture-pruning-judge.md` | ToT pruning evaluation (S5) | MEDIUM |
| `agents/explorers/wildcard-architect.md` | ToT exploration (S5) | MEDIUM |

## Modified Agents

All existing agents need updates for S1 (Self-Critique) and S2 (CoT):
- `agents/code-explorer.md`
- `agents/researcher.md`
- `agents/software-architect.md`
- `agents/tech-lead.md`
- `agents/qa-strategist.md`
- `agents/qa-security.md`
- `agents/qa-performance.md`

## New References

| File | Purpose |
|------|---------|
| `skills/plan/references/self-critique-template.md` | Standard self-critique section |
| `skills/plan/references/cot-prefix-template.md` | Standard CoT section |
| `skills/plan/references/judge-gate-rubrics.md` | Scoring criteria for gates |
| `skills/plan/references/tot-workflow.md` | ToT-MPA hybrid workflow |
| `skills/plan/references/debate-protocol.md` | Multi-judge debate rules |
| `skills/plan/references/adaptive-strategy-logic.md` | S4 decision tree documentation |

## Templates

| File | Purpose |
|------|---------|
| `templates/user-flow-analysis-template.md` | Flow analyzer output |
| `templates/judge-report-template.md` | Gate judge output |
| `templates/debate-round-template.md` | Debate round format |
| `templates/github-issue-template.md` | A5 GitHub issue format |

---

# Conclusions

This proposal transforms planning through two complementary dimensions:

**Context Improvements (A1-A5):**
- Better inputs from flow analysis and institutional knowledge
- Adaptive research depth based on risk
- Qualitative expert review
- Improved post-planning UX

**Process Improvements (S1-S6):**
- Self-verification catches errors at source (40-60% reduction)
- Chain-of-thought improves reasoning (20-60% improvement)
- Judge gates prevent error propagation
- Adaptive strategy optimizes synthesis decisions
- Tree of Thoughts enables systematic exploration
- Multi-judge debate reaches deeper consensus

**Key Innovation:** The "Verified Exploration" pattern combines:
- **Verification** at every step (Self-Critique)
- **Exploration** through systematic search (ToT)
- **Adaptation** based on results (Adaptive Strategy)

**Implementation is incremental:**
1. **Week 1:** Universal foundations (S1, S2, A3, A5) - immediate value
2. **Week 2:** Quality gates (S3, S4, A4) - prevent errors
3. **Weeks 3-4:** Advanced exploration (S5, S6, A1) - maximize quality
4. **Ongoing:** Knowledge system (A2) - compound learning

Each phase delivers value independently, allowing gradual adoption and risk mitigation.

**Measurement:** All improvements include acceptance criteria and ROI measurement methodology for validation.

---

## Academic References

1. **Yao, S., et al. (2023).** "Tree of Thoughts: Deliberate Problem Solving with Large Language Models." arXiv:2305.10601

2. **Bai, Y., et al. (2022).** "Constitutional AI: Harmlessness from AI Feedback." arXiv:2212.08073

3. **Du, Y., et al. (2023).** "Improving Factuality and Reasoning in Language Models through Multiagent Debate." arXiv:2305.14325

4. **Dhuliawala, S., et al. (2023).** "Chain-of-Verification Reduces Hallucination in Large Language Models." arXiv:2309.11495

5. **Kojima, T., et al. (2022).** "Large Language Models are Zero-Shot Reasoners." arXiv:2205.11916

6. **Zheng, L., et al. (2023).** "Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena." arXiv:2306.05685

---

*Document generated by Claude Code Analysis*
*Based on: SADD plugin patterns + product-planning plugin v2.0*
*Version 3.0.0 - Extended with Process Improvements*
