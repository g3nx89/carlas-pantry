# QA Strategist: Sequential Thinking Templates

> Reference file for `qa-strategist.md` agent.
> Load when starting test strategy analysis.
> 4 structured thoughts for risk assessment and testability verification.

---

## Template Overview

The QA Strategist uses **4 structured thoughts** to generate a test strategy focused on
risk assessment and testability verification. Individual test definitions are deferred
to the planning phase.

| Thought | Focus | Output |
|---------|-------|--------|
| T1 | Risk Assessment | Failure modes, severity, affected requirements |
| T2 | Testability Verification | Every AC checked for testability |
| T3 | Critical Journeys & Edge Cases | User flows, boundary conditions |
| T4 | Synthesis | Test level guidance, deferred items |

---

## T1: Risk Assessment

```json
{
  "thought": "Step 1/4: Risk Assessment — Identifying failure modes\n\n## Failure Mode Analysis for {FEATURE_NAME}\n\n### Network Failures\n{What operations depend on connectivity? What happens when they fail?}\n\n### Permission Denials\n{What permissions are required? How to handle denial?}\n\n### Empty States\n{What UI depends on data? What shows when data is absent?}\n\n### Data Edge Cases\n{Null values? Empty strings? Maximum lengths? Special characters?}\n\n### Concurrency\n{What operations can happen simultaneously? Race conditions?}\n\n### State Transitions\n{What state needs restoration? What happens during interruption?}\n\n### Scalability Degradation\n{What is the behavior at 10x current load? Which operations are O(n) or worse? Where are the DB, network, or compute bottlenecks? What happens when rate limits are hit? How does latency change at p95 and p99 under sustained load?}\n\n### External Dependency Failure\n{What external services, APIs, or libraries does this feature depend on? What happens when each is unavailable, slow (>5s), or returns errors? Is there circuit breaking? Does the feature degrade gracefully or fail completely?}\n\n### Deployment & Rollback\n{Are all schema migrations fully reversible? How are in-flight requests handled during deployment? Are there feature flag conflicts with concurrent releases? What is the blast radius of a failed deployment? Can the feature be safely rolled back without data loss?}\n\n### Compliance & Privacy\n{What data is collected, under which legal basis, and with which retention period? How are deletion and portability requests handled (right to be forgotten)? Is PII encrypted at rest and in transit? Are audit logs required by regulation? Which GDPR/CCPA obligations apply: consent, data minimization, breach notification?}\n\n## Risk Assessment Table\n\n| Risk Area | Severity | Affected Requirements | Mitigation Approach |\n|-----------|----------|----------------------|---------------------|\n{For each identified risk}\n\n## Summary\n- Critical risks: {N}\n- High risks: {N}\n- Medium risks: {N}",
  "thoughtNumber": 1,
  "totalThoughts": 4,
  "nextThoughtNeeded": true
}
```

**Key instructions:**
- Analyze ALL failure categories listed above, even if some yield no risks (mark N/A with brief justification where genuinely inapplicable)
- For MVP or internal tools with no PII and low scale: the 4 extended categories (Scalability Degradation, External Dependency Failure, Deployment & Rollback, Compliance & Privacy) may be marked N/A — do not force analysis where inapplicable
- Severity: Critical (blocks user), High (degrades experience), Medium (edge case)
- Every risk must reference affected requirements (US-xxx, AC-xxx)
- Mitigation approach describes WHAT to test, not specific test IDs

---

## T2: Testability Verification

```json
{
  "thought": "Step 2/4: Testability Verification — Checking every AC\n\n## Testability Criteria\n- Has clear preconditions (Given)\n- Has a single atomic action (When)\n- Has a single observable outcome (Then)\n- Outcome is measurable/verifiable\n\n## Verification Table\n\n| AC ID | Description | Testable? | Test Level | Notes |\n|-------|-------------|-----------|------------|-------|\n{For each AC in the spec}\n\n## Non-Testable ACs\n{For each AC marked NEEDS_REVISION:}\n- {AC ID}: {Why not testable} — Suggested revision: {specific fix}\n\n## Summary\n- Total ACs: {N}\n- Testable: {N}\n- Needs revision: {N}",
  "thoughtNumber": 2,
  "totalThoughts": 4,
  "nextThoughtNeeded": true
}
```

**Key instructions:**
- Check EVERY acceptance criterion — no sampling or skipping
- Test Level assignment: Unit (pure logic), Integration (boundaries), E2E (journeys), Visual (appearance)
- NEEDS_REVISION means the AC is ambiguous, compound, or has unmeasurable outcomes
- Provide specific revision suggestions for non-testable ACs

---

## T3: Critical Journeys & Edge Cases

```json
{
  "thought": "Step 3/4: Critical Journeys & Edge Cases\n\n## Critical User Journeys (3-5)\n\n### Journey 1: {Primary Flow}\nPriority: Primary\nEntry: {Starting point}\nActions: {Key action sequence}\nSuccess: {End state}\nACs exercised: {AC-xxx, AC-xxx}\nTest level: E2E\n\n### Journey 2: {Secondary Flow}\n{Same structure}\n\n### Journey 3: {Error Recovery}\n{Same structure}\n\n## Edge Cases\n\n### From Specification\n{Boundary conditions, state transitions}\n\n### From MPA Reports (if available)\n{Edge cases from mpa-edgecases reports}\n\n| Edge Case | Severity | Source | Test Level |\n|-----------|----------|--------|------------|\n{For each identified edge case}\n\n## Summary\n- Critical journeys: {N}\n- Edge cases identified: {N}",
  "thoughtNumber": 3,
  "totalThoughts": 4,
  "nextThoughtNeeded": true
}
```

**Key instructions:**
- Identify 3-5 journeys maximum — focus on the most critical paths
- Each journey maps to specific ACs that it exercises
- Edge cases come from spec analysis AND MPA reports (if available)
- Classify edge cases by severity and appropriate test level

---

## T4: Synthesis

```json
{
  "thought": "Step 4/4: Synthesis — Complete Test Strategy\n\n## Test Level Guidance\n\n### Unit Test Targets\n{Categories of logic requiring unit coverage}\n\n### Integration Test Targets\n{Component boundaries requiring integration coverage}\n\n### E2E Test Targets\n{User journeys requiring end-to-end coverage}\n\n### Visual Test Targets\n{Screens and states requiring visual regression coverage}\n\n## Deferred to Planning Phase\n- Individual test IDs (requires architecture)\n- Unit test specifics (requires class structure)\n- Integration boundaries (requires dependency graph)\n- Visual baselines (requires implemented UI)\n- E2E scripts (requires navigation architecture)\n\n## Quality Assessment\n- Risk coverage: {all risks have mitigation approach}\n- Testability: {N}/{TOTAL} ACs verified testable\n- Journey coverage: {N} critical paths identified\n- Edge cases: {N} identified and categorized\n\nReady to generate test-plan.md.",
  "thoughtNumber": 4,
  "totalThoughts": 4,
  "nextThoughtNeeded": false
}
```

**Key instructions:**
- Test level guidance uses CATEGORIES not individual test IDs
- No implementation references (no class names, component names, architecture patterns)
- Deferred section is explicit about what needs architecture decisions first
- Quality assessment summarizes coverage across all dimensions
