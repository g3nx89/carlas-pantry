# Deep Reasoning Escalation Prompt Templates

> Product-planning specific CTCO templates for manual submission to deep reasoning models
> (GPT-5 Pro, Google Deep Think). Adapted from `meta-skills/deep-reasoning-escalation`.
>
> **Loaded by**: Orchestrator via `deep-reasoning-dispatch-pattern.md` Step B.
> **Not loaded by**: Coordinators (they never handle escalation directly).

## Context Handoff Format

Use this structure when transferring context from the planning workflow to a deep reasoning model:

```xml
<prior_context>
## Feature Being Planned
- Feature: {FEATURE_NAME}
- Spec: {spec.md summary — 2-3 sentences}
- Tech stack: {from state or spec.md}

## Planning Decisions Made
1. Analysis mode: {analysis_mode}
2. Architecture selected: {approved_architecture or "none yet"}
3. {Other key decisions from state.user_decisions}

## Planning Artifacts Available
- design.md: {1-line summary of architecture}
- plan.md: {1-line summary of implementation plan}
- test-plan.md: {1-line summary if exists}

## Claude's Attempts
- Gate retry 1: Score {score_1}/{max}, failing dimensions: {dims_1}
- Gate retry 2: Score {score_2}/{max}, failing dimensions: {dims_2}
- What the coordinator tried differently: {retry_changes_summary}
</prior_context>

<current_request>
{Specific question for the deep reasoning model}
</current_request>
```

### Variable Sourcing

| Variable | Source |
|----------|--------|
| `{FEATURE_NAME}` | `state.feature_name` |
| `{spec.md summary}` | First 3 sentences of `{FEATURE_DIR}/spec.md` |
| `{analysis_mode}` | `state.analysis_mode` |
| `{approved_architecture}` | `state.user_decisions.architecture` or "none yet" |
| `{score_N}`, `{dims_N}` | From phase summary `gate.score`, `gate.failing_dimensions` |
| `{retry_changes_summary}` | Diff between phase summary v1 and v2 `summary` fields |

---

## Template 1: Architecture Wall Breaker

**Escalation type**: `architecture_wall`
**Trigger**: Phase 6 RED score after 2 retries (loops back to Phase 4)
**Context budget**: 16,000-32,000 tokens
**Based on**: meta-skills Template 8 (Architecture/System Design Review) + Template 4 (Second Opinion)

```xml
<review_request>
<context>
We are planning a software feature and the architecture has failed validation twice.
I need a fresh architectural perspective to identify blind spots.
Think hard about this — take your time to verify each recommendation.
</context>

<feature_requirements>
{Insert: spec.md content, trimmed to requirements and acceptance criteria}
</feature_requirements>

<current_architecture>
{Insert: design.md content — the architecture that failed validation}
</current_architecture>

<implementation_plan>
{Insert: plan.md content — the implementation plan}
</implementation_plan>

<validation_feedback>
The architecture was evaluated on 5 dimensions (max 20 points):
1. Problem Understanding (20%): scored {pu_score}/4 — {pu_feedback}
2. Architecture Quality (25%): scored {aq_score}/5 — {aq_feedback}
3. Risk Mitigation (20%): scored {rm_score}/4 — {rm_feedback}
4. Implementation Clarity (20%): scored {ic_score}/4 — {ic_feedback}
5. Feasibility (15%): scored {f_score}/3 — {f_feedback}

Total: {total_score}/20 (threshold for GREEN: 16)
Lowest dimensions: {lowest_2_dimensions}
</validation_feedback>

<architecture_options_considered>
{Insert: summary of MPA architecture options — minimal, clean, pragmatic — if available}
</architecture_options_considered>

<review_focus>
1. Why might the current architecture score poorly on {lowest_2_dimensions}?
2. What architectural alternatives or modifications would address these weaknesses?
3. Are there blind spots none of the prior analysis caught?
4. Provide a concrete revised architecture proposal with rationale.
</review_focus>

<self_reflection>
First, create an internal rubric for what defines a 'world-class' architecture review.
Use 5-7 evaluation categories. Iterate internally until your response
hits top marks across all categories. Show only the final output.
</self_reflection>

<output_format>
## Root Cause Analysis
[Why the architecture is failing validation — 2-3 specific reasons]

## Revised Architecture Proposal
[Concrete architecture with components, data flow, and key decisions]

## Changes from Original
[What changed and why — table format preferred]

## Risk Assessment
[New risks introduced by the revision and mitigations]

## Confidence Level
[HIGH/MEDIUM/LOW with rationale]
</output_format>
</review_request>
```

### Variable Sourcing (Template 1)

| Variable | Source |
|----------|--------|
| `{pu_score}` ... `{f_score}` | Phase 6 summary `gate.dimension_scores` |
| `{pu_feedback}` ... `{f_feedback}` | Phase 6 `analysis/validation-report.md` per-dimension feedback |
| `{total_score}` | Phase 6 summary `gate.score` |
| `{lowest_2_dimensions}` | Sort dimensions by score, take bottom 2 |
| `{architecture_options_considered}` | From Phase 4 summary or `design.md` options section |

---

## Template 2: Circular Failure Recovery

**Escalation type**: `circular_failure`
**Trigger**: Any quality gate RED after 2 retries
**Context budget**: 10,000-20,000 tokens
**Based on**: meta-skills Template 10 (Development Plan Review)

```xml
<plan_review>
<context>
A feature planning workflow quality gate has failed twice despite retry attempts.
I need analysis of what is being systematically missed.
Think hard about this.
</context>

<feature_summary>
{Insert: spec.md summary — 5-10 sentences}
</feature_summary>

<gate_that_failed>
Gate: {gate_name} (Phase {phase_number})
Evaluation criteria:
{Insert: gate criteria from judge-gate-rubrics.md for this specific gate}
</gate_that_failed>

<attempt_history>
## Attempt 1
- Score: {score_1}/{max_score}
- Dimensions below threshold: {failing_dims_1}
- Feedback received: {feedback_1}

## Attempt 2 (after addressing feedback)
- Score: {score_2}/{max_score}
- Dimensions still below threshold: {failing_dims_2}
- Feedback received: {feedback_2}
- Changes made between attempts: {what_changed}
</attempt_history>

<artifacts_produced>
{Insert: relevant artifacts for this gate — e.g., design.md for Gate 2, test-plan.md for Gate 3}
</artifacts_produced>

<task>
Review this planning workflow failure.
1. What is being systematically missed across both attempts?
2. Are the gate criteria appropriate for this type of feature, or is there a mismatch?
3. What specific improvements would bring the score above threshold?
4. Are there requirements or constraints that make this gate inherently difficult?

Provide the answer in sections: Root Cause, Recommendations, Edge Cases.
</task>

<output_format>
## Root Cause (why gate keeps failing)
[Systematic issue, not surface symptoms]

## Specific Recommendations
[Numbered list of actionable changes to artifacts]

## Potential Gate Mismatch
[If criteria seem inappropriate for this feature, explain why]

## Edge Cases to Consider
[Requirements or scenarios that may have been overlooked]
</output_format>
</plan_review>
```

### Variable Sourcing (Template 2)

| Variable | Source |
|----------|--------|
| `{gate_name}` | Phase summary `gate.name` |
| `{phase_number}` | Current phase |
| `{score_N}`, `{failing_dims_N}` | Phase summary history (retry 1 and 2) |
| `{feedback_N}` | Judge agent output from each retry |
| `{what_changed}` | Diff between retry 1 and retry 2 artifact versions |

---

## Template 3: Security Deep Dive

**Escalation type**: `security_deep_dive`
**Trigger**: 2+ CRITICAL security findings in Phase 6b
**Context budget**: 32,000-64,000 tokens
**Based on**: meta-skills Template 2 (Security Vulnerability Deep Analysis)

```xml
<security_audit>
<context>
A feature planning security review has identified multiple CRITICAL vulnerabilities.
I need a CVE-level deep security analysis to validate and expand on these findings.
Think hard about this — take your time to verify each vulnerability.
</context>

<feature_architecture>
{Insert: design.md content — full architecture with components and data flow}
</feature_architecture>

<threat_model>
## STRIDE Analysis (from automated review)
{Insert: STRIDE findings from analysis/expert-review.md}

## Trust Boundaries
{Insert: trust boundary definitions from design.md or expert-review.md}

## User Roles and Access Levels
{Insert: from spec.md or design.md}

## Sensitive Data
{Insert: data classification from spec.md or design.md}
</threat_model>

<existing_findings>
## CRITICAL Findings (require deep analysis)
{Insert: CRITICAL severity findings from expert-review.md — full details}

## HIGH Findings (validate these too)
{Insert: HIGH severity findings from expert-review.md — summaries}

## Clink Security Audit (if available)
{Insert: analysis/clink-security-report.md summary — if exists}
</existing_findings>

<scope>
Focus on:
- Validate each CRITICAL finding — is the severity assessment correct?
- Identify vulnerabilities the automated review may have missed
- OWASP Top 10 analysis against the proposed architecture
- Authentication and authorization bypass scenarios
- Supply chain and dependency risks
- Data exposure through logging, error messages, or API responses
</scope>

<self_reflection>
You are a senior security auditor with CVE discovery experience.
First, create an internal rubric for a thorough security review.
Iterate internally until your analysis would satisfy a SOC2 audit.
Show only the final output.
</self_reflection>

<output_format>
For each vulnerability (existing or new):
- **CWE ID** (if applicable)
- **Severity**: Critical / High / Medium / Low
- **STRIDE Category**: Which STRIDE threat
- **Attack Scenario**: Step-by-step exploitation path
- **Affected Component**: Component from the architecture
- **Remediation**: Specific architectural change or code pattern
- **Verification**: How to test the fix

## Summary Table
| # | CWE | Severity | Component | Status (Confirmed/New/Downgraded) |

## Overall Risk Assessment
[1-paragraph executive summary of security posture]
</output_format>
</security_audit>
```

### Variable Sourcing (Template 3)

| Variable | Source |
|----------|--------|
| STRIDE findings | `{FEATURE_DIR}/analysis/expert-review.md` security section |
| Trust boundaries | `{FEATURE_DIR}/design.md` or extracted from expert review |
| CRITICAL/HIGH findings | `{FEATURE_DIR}/analysis/expert-review.md` findings list |
| Clink security report | `{FEATURE_DIR}/analysis/clink-security-report.md` (if exists) |
| User roles | `{FEATURE_DIR}/spec.md` or `design.md` |

---

## Template 4: Abstract Algorithm Escalation

**Escalation type**: `algorithm_escalation`
**Trigger**: Algorithm keywords detected in Phase 1 + gate failure in Phase 4 or 7
**Context budget**: 4,000-16,000 tokens
**Based on**: meta-skills Template 3 (Abstract Reasoning Problem)

```xml
<reasoning_task>
<context>
A feature requires algorithmic design that the planning agents could not adequately address.
Algorithm keywords detected: {detected_keywords}
Think hard about this — take your time to verify each step.
</context>

<problem>
## Feature Requirement
{Insert: the algorithmic requirement from spec.md — the specific section}

## What the Planning Agents Attempted
{Insert: from Phase 4 or 7 summary — what approach was tried and why it was insufficient}
</problem>

<constraints>
## Technical Constraints
{Insert: from design.md — language, framework, performance requirements}

## Non-Functional Requirements
{Insert: from spec.md — latency, throughput, memory, correctness guarantees}

## Codebase Context
{Insert: relevant existing patterns from research.md — what the codebase already uses}
</constraints>

<self_reflection>
Create an internal rubric for solving this type of algorithmic problem.
Verify your reasoning at each step before proceeding.
Consider time complexity, space complexity, and correctness.
Show only the final, verified solution.
</self_reflection>

<output_format>
## Algorithm Design
1. **Approach**: [Name of algorithm/technique and why it fits]
2. **Time Complexity**: [Big-O with explanation]
3. **Space Complexity**: [Big-O with explanation]
4. **Correctness Argument**: [Why this is correct — informal proof or invariant]

## Pseudocode
[Language-agnostic pseudocode with comments]

## Edge Cases
[List of edge cases with expected behavior]

## Integration Notes
[How this algorithm fits into the feature architecture from design.md]

## Alternative Approaches Considered
[1-2 alternatives with trade-off explanation]

## Confidence Level
[HIGH/MEDIUM/LOW with rationale]
</output_format>
</reasoning_task>
```

### Variable Sourcing (Template 4)

| Variable | Source |
|----------|--------|
| `{detected_keywords}` | `state.deep_reasoning.algorithm_keywords` |
| Algorithmic requirement | `{FEATURE_DIR}/spec.md` — relevant section |
| Planning agent attempt | Phase 4 or 7 summary `summary` field + `flags.algorithm_difficulty` |
| Technical constraints | `{FEATURE_DIR}/design.md` — technology section |
| Non-functional requirements | `{FEATURE_DIR}/spec.md` — NFRs section |
| Codebase patterns | `{FEATURE_DIR}/research.md` — patterns section |

---

## Template Selection Matrix

| Escalation Type | Template | Trigger Phase | Context Budget |
|-----------------|----------|---------------|----------------|
| `architecture_wall` | Template 1 | Phase 6 RED → Phase 4 | 16-32K tokens |
| `circular_failure` | Template 2 | Any gate RED after 2 retries | 10-20K tokens |
| `security_deep_dive` | Template 3 | Phase 6b (2+ CRITICAL) | 32-64K tokens |
| `algorithm_escalation` | Template 4 | Phase 4/7 + algorithm flag | 4-16K tokens |

## Context Best Practices

- **Summarize, don't dump**: Trim artifacts to relevant sections before inserting
- **Include attempt history**: Deep reasoning models perform best when they know what failed
- **Frame as fresh review**: Use neutral language, not "Claude failed at this"
- **No contradicting instructions**: Ensure CTCO sections don't conflict with each other
- **Respect context budgets**: Exceeding optimal context leads to diminishing returns
