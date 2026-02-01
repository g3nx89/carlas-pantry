# Judge Gate Rubrics Reference

Detailed scoring criteria and calibration examples for phase gate judges.

## Scoring Scale (Universal)

All gates use the same 1-5 scale:

| Score | Label | Definition | Key Indicator |
|-------|-------|------------|---------------|
| 1 | Missing | Not addressed at all | Criterion entirely absent |
| 2 | Incomplete | Partially addressed, major gaps | Some effort but fundamental issues |
| 3 | Adequate | Addressed with minor gaps | Meets minimum bar, acceptable |
| 4 | Good | Well addressed, no significant gaps | Solid work, minor improvements possible |
| 5 | Excellent | Thoroughly addressed, exceeds expectations | Exemplary, nothing to improve |

## Pass Threshold

**Threshold: 3.5 / 5.0 (weighted average)**

This means:
- All criteria at least adequate (3)
- With some good/excellent (4-5) scores to pull up average
- No criterion at 1 (missing)

## Gate 1: Research Completeness

### Criteria Detail

#### Unknown Resolution (25%)

**What to evaluate:** Are all technical unknowns from spec addressed with research findings?

| Score | Indicators |
|-------|------------|
| 1 | Unknowns not listed or not researched |
| 2 | Some unknowns researched, major gaps remain |
| 3 | All unknowns addressed, some answers shallow |
| 4 | Unknowns thoroughly researched with recommendations |
| 5 | Unknowns resolved with multiple options, trade-offs documented |

**Calibration Example (Score 3):**
```
Spec listed 3 unknowns: authentication library, database choice, caching strategy.
Research addressed auth (recommends JWT) and database (PostgreSQL with reasons).
Caching strategy mentioned but no concrete recommendation given.
Gap: Caching needs more analysis but not blocking.
```

#### Pattern Discovery (25%)

**What to evaluate:** Are codebase patterns identified with file:line references?

| Score | Indicators |
|-------|------------|
| 1 | No patterns identified |
| 2 | Patterns mentioned without evidence |
| 3 | Main patterns identified with file references |
| 4 | Patterns thoroughly documented with file:line refs |
| 5 | Patterns mapped with rationale, anti-patterns noted |

**Calibration Example (Score 4):**
```
Research identified:
- Repository pattern: src/repositories/userRepository.ts:15-45
- Service layer: src/services/authService.ts:1-120
- DTO mapping: src/dtos/userDto.ts
- Error handling: src/utils/errors.ts:10 (custom error classes)
Minor gap: Could note where patterns are inconsistently applied.
```

#### Integration Mapping (25%)

**What to evaluate:** Are integration points with existing code mapped?

| Score | Indicators |
|-------|------------|
| 1 | No integration points identified |
| 2 | High-level integration mentioned, no specifics |
| 3 | Key integration points listed with file locations |
| 4 | Integration points with interfaces and data contracts |
| 5 | Complete integration map with sequence diagrams or flows |

#### Constitution Compliance (15%)

**What to evaluate:** Does research align with constitution.md guidelines?

| Score | Indicators |
|-------|------------|
| 1 | Constitution not referenced |
| 2 | Constitution mentioned but not applied |
| 3 | Key guidelines referenced |
| 4 | Explicit mapping of research to guidelines |
| 5 | Research actively shaped by constitution constraints |

#### Completeness (10%)

**What to evaluate:** Are there obvious gaps or missing areas?

| Score | Indicators |
|-------|------------|
| 1 | Multiple major areas missing |
| 2 | One major area missing |
| 3 | All areas covered, some thin |
| 4 | Comprehensive coverage |
| 5 | Exhaustive, proactively identifies areas spec missed |

---

## Gate 2: Architecture Quality

### Criteria Detail

#### Requirement Coverage (20%)

**What to evaluate:** Does design address all requirements from spec?

| Score | Indicators |
|-------|------------|
| 1 | Requirements not referenced |
| 2 | Some requirements addressed, major gaps |
| 3 | All explicit requirements have design elements |
| 4 | Requirements traced to specific components |
| 5 | Requirements + edge cases addressed, traceable |

**Calibration Example (Score 2):**
```
Spec has 5 acceptance criteria. Design addresses:
- AC-1 (user registration): ✓ UserService.register()
- AC-2 (email verification): ✗ Not mentioned
- AC-3 (password reset): ✗ Not mentioned
- AC-4 (profile update): ✓ UserService.updateProfile()
- AC-5 (account deletion): ✗ Not mentioned
Major gap: 3 of 5 ACs not addressed in design.
```

#### Trade-off Documentation (20%)

**What to evaluate:** Are pros/cons clearly documented for chosen approach?

| Score | Indicators |
|-------|------------|
| 1 | No alternatives considered |
| 2 | Alternatives mentioned, no comparison |
| 3 | Pros/cons listed for chosen approach |
| 4 | Structured comparison of 2-3 options |
| 5 | Decision matrix with scoring, clear rationale |

#### Risk Identification (20%)

**What to evaluate:** Are risks identified with mitigation strategies?

| Score | Indicators |
|-------|------------|
| 1 | No risks mentioned |
| 2 | Risks mentioned without mitigation |
| 3 | Major risks identified with mitigations |
| 4 | Comprehensive risk analysis with severity ratings |
| 5 | Risk register with monitoring/escalation plans |

#### Pattern Consistency (20%)

**What to evaluate:** Does design follow discovered codebase patterns?

| Score | Indicators |
|-------|------------|
| 1 | Ignores existing patterns |
| 2 | Partially aligns, introduces inconsistencies |
| 3 | Follows main patterns |
| 4 | Explicit pattern references from research |
| 5 | Extends patterns appropriately, notes where deviation needed |

#### Actionability (20%)

**What to evaluate:** Can developers implement without asking questions?

| Score | Indicators |
|-------|------------|
| 1 | Vague concepts only |
| 2 | Some specifics, major gaps |
| 3 | File paths and component names clear |
| 4 | Interfaces defined, integration specified |
| 5 | Copy-pastable starting points, complete specifications |

---

## Gate 3: Test Coverage

### Criteria Detail

#### AC Coverage (30%)

**What to evaluate:** Does every acceptance criterion have a test?

| Score | Indicators |
|-------|------------|
| 1 | Coverage matrix missing or empty |
| 2 | Some ACs have tests, gaps exist |
| 3 | All ACs have at least one test |
| 4 | ACs have multiple test levels (unit + integration) |
| 5 | ACs have comprehensive test suites with edge cases |

**Calibration Example (Score 3):**
```
Coverage Matrix:
| AC | Unit | Integration | E2E | UAT |
|----|------|-------------|-----|-----|
| AC-1 | UT-01 | INT-01 | - | UAT-01 |
| AC-2 | UT-02 | - | - | - |
| AC-3 | UT-03 | - | E2E-01 | - |

All ACs have at least one test. Minor gap: AC-2 only has unit test,
could benefit from integration test.
```

#### Risk Coverage (25%)

**What to evaluate:** Do Critical/High risks have test coverage?

| Score | Indicators |
|-------|------------|
| 1 | Risks not mapped to tests |
| 2 | Some risks have tests |
| 3 | All Critical/High risks have tests |
| 4 | Risks have dedicated test scenarios |
| 5 | Risk mitigation verified through multiple test levels |

#### UAT Clarity (20%)

**What to evaluate:** Are UAT scripts understandable by non-technical users?

| Score | Indicators |
|-------|------------|
| 1 | UAT scripts missing or technical jargon |
| 2 | Scripts exist but unclear steps |
| 3 | Given-When-Then format, mostly clear |
| 4 | Clear scripts with test data and evidence checklists |
| 5 | Scripts usable by product owner with no clarification |

#### Level Appropriateness (15%)

**What to evaluate:** Are tests at correct levels (unit/integration/E2E)?

| Score | Indicators |
|-------|------------|
| 1 | All tests at same level |
| 2 | Levels exist but inappropriate assignment |
| 3 | Reasonable distribution across levels |
| 4 | Test pyramid followed, clear rationale |
| 5 | Optimal distribution with efficiency considerations |

#### No Redundancy (10%)

**What to evaluate:** Is there unnecessary duplicate coverage?

| Score | Indicators |
|-------|------------|
| 1 | Same test repeated at every level |
| 2 | Significant redundancy |
| 3 | Minimal necessary overlap |
| 4 | Clean separation of concerns |
| 5 | Each test adds unique value, no redundancy |

---

## Mode Adjustments

Calibrate expectations based on analysis mode:

| Mode | Expectation Adjustment |
|------|----------------------|
| Complete | Apply full rubric, expect scores of 4-5 |
| Advanced | Apply full rubric, expect scores of 3-4 |
| Standard | Focus on must-have criteria, accept 3s |
| Rapid | Minimal evaluation, pass if no 1s |

## Retry Feedback Template

When gate fails, provide structured feedback:

```markdown
## Gate Failure: {GATE_NAME}

**Score:** {X.X} / 5.0 (threshold: 3.5)
**Verdict:** FAIL

### Issues to Address

#### Issue 1: {Criterion Name} scored {X}/5

**Current State:** {What exists}
**Gap:** {What's missing}
**Required Action:** {Specific fix}
**Evidence Needed:** {What to add}

### Retry Guidance

Focus on these specific improvements:
1. {Concrete action 1}
2. {Concrete action 2}

Do NOT:
- Inflate existing content without adding substance
- Add filler to appear more complete
- Copy from other sections

After retry, I will re-evaluate only the failing criteria.
```
