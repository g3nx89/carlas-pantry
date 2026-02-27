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

> Obstacle-Aware JTBD Format — AC grouped by obstacle, tabular by default.
> Atomicity rule: each AC row has exactly ONE Action (= When) and ONE Outcome (= Then).
> Expand to Gherkin `<details>` block only when preconditions are complex or multi-step.

### US-001: {Verb + Object — scannable action title}

**As a** {persona within specific context},
**I want** {specific goal},
**so that** {concrete value delivered},
**but** {primary obstacle or risk that makes this story non-trivial}.

**Figma:** Happy→[{FrameName}] · Error→[{FrameName}] · *(use `[FSB-NNN pending]` for undocumented screens)*

**Happy path**

| # | Scenario | Precondition | Action | Outcome | Test |
|---|----------|--------------|--------|---------|------|
| AC-01 | {brief scenario title} | {setup state} | {user does X} | {system does Y} | E2E |

**Obstacle: {name the barrier — mirrors the "but" clause}**

| # | Scenario | Precondition | Action | Outcome | Test |
|---|----------|--------------|--------|---------|------|
| AC-02 | {error/edge scenario} | {setup state} | {user does X} | {system does Y} | Unit |
| AC-03 | {another variant} | {setup state} | {user does X} | {system does Y} | Integration |

<!-- Use <details> only when preconditions are multi-step or the scenario logic is non-obvious from the table -->
<!-- Example:
<details><summary>AC-04 — {complex scenario name}</summary>

**Given** {precondition 1 — rich context}
- And **Given** {precondition 2}
**When** {ONE atomic user action}
**Then** {ONE observable outcome}

</details>
-->

---

### US-002: {Verb + Object}

**As a** {persona within specific context},
**I want** {specific goal},
**so that** {concrete value delivered},
**but** {obstacle}.

**Figma:** Happy→[{FrameName}]

**Happy path**

| # | Scenario | Precondition | Action | Outcome | Test |
|---|----------|--------------|--------|---------|------|
| AC-01 | {scenario} | {setup} | {action} | {outcome} | E2E |

**Obstacle: {barrier name}**

| # | Scenario | Precondition | Action | Outcome | Test |
|---|----------|--------------|--------|---------|------|
| AC-02 | {scenario} | {setup} | {action} | {outcome} | Unit |

---

### Story Atomicity Rules

> **Action column = ONE atomic user action** (equivalent to Gherkin `When`).
> **Outcome column = ONE observable system response** (equivalent to Gherkin `Then`).
> If a row needs multiple actions or outcomes → apply story splitting criteria.
>
> **Obstacle grouping:** AC rows that exist because of the "but" clause go under the Obstacle group.
> AC rows for the success path go under Happy path. Use additional obstacle groups if the story
> has multiple distinct barriers (rare — usually signals story splitting needed instead).

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

## 6. Constraints & Boundaries

### 6.1 Operating Environment

- {Platform or environment constraint - e.g., Must work with intermittent connectivity}
- {Environment constraint - e.g., Must support offline usage with data synchronization}
- {Compatibility constraint - e.g., Must work across target platforms and browsers}

### 6.2 Integration Boundaries

- {Integration boundary - e.g., Must integrate with existing authentication system}
- {Integration boundary - e.g., Must support import/export from external calendar services}
- {Data boundary - e.g., Must respect existing user data and preferences}

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

## 8. Information Architecture

> Describe conceptual entities, their relationships, and lifecycle — no field names, data types, or schema definitions.

### 8.1 Core Concepts

| Concept | Description | Lifecycle |
|---------|-------------|-----------|
| {Concept 1 - e.g., Recipe} | {What it represents to the user} | {Created when... / Updated when... / Archived when...} |
| {Concept 2 - e.g., Meal Plan} | {What it represents to the user} | {Lifecycle description} |

### 8.2 Relationships

- {Relationship - e.g., A meal plan contains one or more recipes}
- {Relationship - e.g., A user can have multiple shopping lists, each derived from a meal plan}
- {Ownership - e.g., Recipes belong to the user who created them but can be shared read-only}

### 8.3 Information Flows

- {Flow - e.g., When a user adds a recipe to a meal plan, ingredients are automatically aggregated into a shopping list}
- {Flow - e.g., Changes to a recipe update all meal plans that include it}

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
