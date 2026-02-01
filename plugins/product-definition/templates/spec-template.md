# Feature Specification Template

> Use this template when creating feature specs via `/sdd:01-specify`
> Enhanced with PM Patterns: Problem Framing Canvas, JTBD, Epic Hypothesis, Obstacle-Aware Stories

---

# {Feature Name} Specification

## Metadata

| Field | Value |
|-------|-------|
| **Feature ID** | {number}-{short-name} |
| **Author** | {name} |
| **Created** | {date} |
| **Status** | Draft / In Review / Approved |
| **Priority** | Critical / High / Medium / Low |

---

## 1. Problem Framing Canvas

> Understand the problem deeply before jumping to solutions.

### 1.1 Persona in Context

**I am**: {Describe the key persona experiencing this problem}

- {Pain point 1 about their underserved need}
- {Pain point 2 about their underserved need}
- {Pain point 3 about their underserved need}

### 1.2 Goals (Trying To)

**Trying to**: {A single sentence listing the desired outcomes the persona cares most about}

### 1.3 Barriers (But)

**But**:

- {Barrier preventing the persona from achieving desired outcomes 1}
- {Barrier preventing the persona from achieving desired outcomes 2}
- {Barrier preventing the persona from achieving desired outcomes 3}

### 1.4 Root Cause (Because)

**Because**: {Describe the root cause of the problem - empathetically}

### 1.5 Emotional Impact

**Which makes me feel**: {Describe the emotions from the persona's perspective}

### 1.6 Context & Constraints

- {Geographic, technological, time-based, or demographic factors}
- {Technical constraints from environment}
- {Business constraints}

### 1.7 Final Problem Statement

> {Single concise statement that provides a powerful and empathetic summary - captures WHO, WHAT, WHY, and emotional impact}

---

## 2. Jobs-to-be-Done Analysis

> Understand what the user is really trying to accomplish - functional, social, AND emotional.

### 2.1 Customer Jobs

#### Functional Jobs (What they need to DO)

- {Task 1 the customer needs to perform}
- {Task 2 the customer needs to perform}
- {Task 3 the customer needs to perform}

#### Social Jobs (How they want to be PERCEIVED)

- {How they want to appear to others}
- {Social status or recognition they seek}

#### Emotional Jobs (How they want to FEEL)

- {Emotional state they seek to achieve}
- {Emotional state they seek to avoid}

### 2.2 Pains

#### Challenges

- {Obstacle 1 they currently face}
- {Obstacle 2 they currently face}

#### Costliness (Time/Money/Effort)

- {What's too costly in time}
- {What's too costly in money or effort}

#### Common Mistakes

- {Frequent error 1 that could be prevented}
- {Frequent error 2 that could be prevented}

#### Unresolved Problems

- {Problem 1 not solved by current solutions}
- {Problem 2 not solved by current solutions}

### 2.3 Gains

#### Expectations

- {What would exceed current expectations}

#### Savings

- {Desired savings in time}
- {Desired savings in money or effort}

#### Adoption Factors

- {Factor 1 that would increase adoption likelihood}
- {Factor 2 that would increase adoption likelihood}

#### Life Improvement

- {How solution makes their life easier or better}

---

## 3. Epic Hypothesis

> Frame the feature as a hypothesis to be validated, not a certainty to be built.

### 3.1 If/Then Statement

**If we** {action or solution we're proposing}
**for** {target persona of this solution}
**Then we will** {attainable outcome or JTBD fulfillment}

### 3.2 Tiny Acts of Discovery (Experiments)

**We will test our assumption by:**

1. {Experiment 1 - e.g., prototype test with 5 users}
2. {Experiment 2 - e.g., A/B test on landing page}
3. {Experiment 3 - e.g., user interview with power users}

### 3.3 Validation Measures

**We know our hypothesis is valid if within** {X days/weeks} **we observe:**

- {Quantitative measure 1 - e.g., 40% increase in task completion}
- {Quantitative measure 2 - e.g., average time < 3 minutes}
- {Qualitative measure - e.g., NPS score > 8}

### 3.4 Pivot Criteria

**We will pivot or abandon if:**

- {Failure threshold 1 - e.g., adoption rate < 10%}
- {Failure threshold 2 - e.g., negative user feedback > 30%}

---

## 4. User Stories

> Obstacle-Aware JTBD Format with Gherkin Acceptance Criteria

### US-001: {Human-readable summary of value delivered}

#### Use Case (Obstacle-Aware JTBD Format)

**As a** {persona within specific context},
**I [want | need | must be able to]** {desired outcome or goal},
**so that I can** {complete specific job or functional objective},
**but** {barrier, obstacle, or constraint that might prevent success}.

#### Acceptance Criteria (Gherkin)

**Scenario**: {Concise, human-readable behavior description}

**Given** {precondition 1 - sets the stage}
- And **Given** {precondition 2 - adds needed context}
- And **Given** {precondition N - as many as needed to load context}
**When** {ONE atomic user action - simple, unchained, decisive}
**Then** {ONE observable outcome - tied to the job-to-be-done}

---

### US-002: {Human-readable summary}

#### Use Case (Obstacle-Aware JTBD Format)

**As a** {persona within specific context},
**I [want | need | must be able to]** {desired outcome or goal},
**so that I can** {complete specific job or functional objective},
**but** {barrier, obstacle, or constraint}.

#### Acceptance Criteria (Gherkin)

**Scenario**: {Behavior description}

**Given** {precondition 1}
- And **Given** {precondition 2}
**When** {ONE atomic action}
**Then** {ONE observable outcome}

---

### US-003: {Add more stories as needed}

{Follow the same format}

---

### Story Atomicity Note

> Each user story should have exactly ONE `When` and ONE `Then` in its acceptance criteria.
> If a story has compound actions or multiple outcomes, the BA agent applies story splitting criteria.

---

## 5. Non-Functional Requirements

### 5.1 Performance

- [ ] NFR-PERF-01: {Performance criterion - e.g., Screen loads in < 2 seconds on 3G}
- [ ] NFR-PERF-02: {Performance criterion}

### 5.2 Accessibility

- [ ] NFR-A11Y-01: {Accessibility criterion - e.g., WCAG 2.1 AA compliance}
- [ ] NFR-A11Y-02: {Accessibility criterion}

### 5.3 Security

- [ ] NFR-SEC-01: {Security criterion - e.g., All data encrypted at rest}
- [ ] NFR-SEC-02: {Security criterion}

### 5.4 Scalability

- [ ] NFR-SCALE-01: {Scalability criterion - e.g., Supports 10,000 concurrent users}

---

## 6. Technical Constraints

### 6.1 Must Use (per Constitution)

- Kotlin 2.0+ (K2 compiler)
- Jetpack Compose (Material 3)
- Hilt for DI
- Coroutines/Flow for async

### 6.2 Feature-Specific Constraints

- {Constraint 1 - e.g., Must work offline}
- {Constraint 2 - e.g., Must integrate with existing auth system}

---

## 7. UI/UX Requirements

### 7.1 Screens

| Screen | Description | States |
|--------|-------------|--------|
| {Screen 1} | {Purpose} | Empty, Loading, Content, Error |
| {Screen 2} | {Purpose} | {States} |

### 7.2 Design References

- **Figma**: {link or frame reference}
- **Design System**: {component references from Material 3}

### 7.3 Key Interactions

- {Interaction 1 - e.g., Swipe to delete with undo}
- {Interaction 2 - e.g., Pull to refresh}

---

## 8. Data Requirements

### 8.1 Entities

```kotlin
// Domain entity (technology-agnostic description)
data class {EntityName}(
    val id: String,
    // {field descriptions}
)
```

### 8.2 API Contracts

| Endpoint | Method | Purpose | Request | Response |
|----------|--------|---------|---------|----------|
| `/api/v1/{resource}` | GET | {description} | {params} | {response shape} |

---

## 9. Dependencies

### 9.1 Internal

- {Module or feature this depends on}
- {Shared component required}

### 9.2 External

- {External service or API}
- {Third-party library}

---

## 10. Success Criteria

> Technology-agnostic, measurable outcomes from user/business perspective.

| Criterion | Target | Measurement Method |
|-----------|--------|-------------------|
| {User outcome 1} | {Specific metric} | {How to measure} |
| {User outcome 2} | {Specific metric} | {How to measure} |
| {Business outcome} | {Specific metric} | {How to measure} |

**Good examples:**
- "Users complete checkout in under 3 minutes"
- "Task completion rate improves by 40%"
- "95% of searches return results in under 1 second"

**Bad examples (avoid):**
- "API response time under 200ms" (too technical)
- "React components render efficiently" (framework-specific)

---

## 11. Open Questions

- [ ] Q1: {Question requiring stakeholder input}
- [ ] Q2: {Question about scope or approach}
- [ ] Q3: {Question about edge case handling}

---

## 12. Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| {Risk 1} | High/Medium/Low | High/Medium/Low | {Mitigation strategy} |
| {Risk 2} | {Probability} | {Impact} | {Mitigation} |

---

## 13. Out of Scope

> Explicit boundaries to prevent scope creep.

- {What this feature explicitly does NOT include 1}
- {What this feature explicitly does NOT include 2}
- {Future enhancement deferred to later iteration}

---

## 14. Assumptions

> Documented assumptions that, if proven false, would require spec revision.

- {Assumption 1 - e.g., Users have stable internet connection}
- {Assumption 2 - e.g., Authentication system supports OAuth2}
- {Assumption 3 - e.g., Design system components are available}

---

## Approval

| Role | Name | Date | Approved |
|------|------|------|----------|
| Product | | | [ ] |
| Engineering | | | [ ] |
| Design | | | [ ] |
