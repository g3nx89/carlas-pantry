# Sequential Thinking Templates for Business Analyst

This reference contains all Sequential Thinking MCP templates organized by task type.
The BA agent loads these on-demand when performing structured analysis.

---

## Template Selection Matrix

| Task | Templates | Total Steps | When to Use |
|------|-----------|-------------|-------------|
| Problem Framing | T1-T3 | 3 | Initial problem understanding |
| JTBD Analysis | T4-T6 | 3 | Understanding user jobs, pains, gains |
| Requirements Discovery | T7-T10 | 4 | Root cause and true need identification |
| Context Analysis | T11-T13 | 3 | Competitive landscape and standards |
| Stakeholder Analysis | T14-T16 | 3 | Stakeholder mapping and conflict resolution |
| Requirements Specification | T17-T21 | 5 | FRs, NFRs, acceptance criteria |
| Story Splitting | T22-T23 | 2 | Atomic story validation |
| Self-Critique | T24-T25 | 2 | Rubric evaluation and gap remediation |

---

## Group 1: Problem Framing (T1-T3)

### T1: Persona in Context

```json
{
  "thought": "Step 1/3: Understanding the persona experiencing this problem. Who are they? What is their context? Key characteristics: [list]. Pain points about their underserved needs: [list].",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "The persona is [description] facing [situation]",
  "confidence": "exploring"
}
```

**Purpose:** Establish deep empathy with the target user.

**Key Questions:**
- Who is experiencing this problem?
- What is their daily context?
- What characterizes this persona?
- What are their underserved needs?

---

### T2: Barriers and Root Cause

```json
{
  "thought": "Step 2/3: Identifying barriers preventing success. The persona is TRYING TO [desired outcome], BUT [barrier 1], [barrier 2], [barrier 3]. This happens BECAUSE [root cause - empathetic understanding]. This makes them FEEL [emotions].",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Root cause is [X], barriers are [list]",
  "confidence": "medium"
}
```

**Purpose:** Identify what prevents the persona from success.

**Pattern:** `TRYING TO... BUT... BECAUSE... FEEL...`

---

### T3: Problem Statement Synthesis

```json
{
  "thought": "Step 3/3: Synthesizing final problem statement. Context & Constraints: [geographic, technological, time-based factors]. FINAL PROBLEM STATEMENT: [Single concise statement that is powerful and empathetic, capturing who, what, why, and the emotional impact].",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false,
  "hypothesis": "Problem statement: [final statement]",
  "confidence": "high"
}
```

**Purpose:** Craft the definitive problem statement.

**Quality Criteria:**
- Single concise statement
- Captures who, what, why
- Includes emotional impact
- Empathetic in tone

---

## Group 2: Jobs-to-be-Done Analysis (T4-T6)

### T4: Customer Jobs

```json
{
  "thought": "Step 1/3: Identifying all customer jobs. FUNCTIONAL JOBS (tasks to perform): [list]. SOCIAL JOBS (how they want to be perceived): [list]. EMOTIONAL JOBS (how they want to feel): [list].",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Primary job is [functional], supported by [social/emotional] jobs",
  "confidence": "medium"
}
```

**Purpose:** Map the full spectrum of user jobs.

**Job Categories:**
- **Functional:** Tasks to perform
- **Social:** How they want to be perceived
- **Emotional:** How they want to feel

---

### T5: Pains Mapping

```json
{
  "thought": "Step 2/3: Mapping customer pains. CHALLENGES: [obstacles they face]. COSTLINESS: [what's too costly in time/money/effort]. COMMON MISTAKES: [frequent errors that could be prevented]. UNRESOLVED PROBLEMS: [what current solutions don't solve].",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Primary pains are [list], biggest unresolved problem is [X]",
  "confidence": "medium"
}
```

**Purpose:** Identify all pain points.

**Pain Categories:**
- Challenges (obstacles)
- Costliness (time/money/effort)
- Common Mistakes (preventable errors)
- Unresolved Problems (gaps in current solutions)

---

### T6: Gains Mapping

```json
{
  "thought": "Step 3/3: Mapping customer gains. EXPECTATIONS: [what would exceed current expectations]. SAVINGS: [desired savings in time/money/effort]. ADOPTION FACTORS: [what would increase likelihood of adopting solution]. LIFE IMPROVEMENT: [how solution makes life easier/better].",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false,
  "hypothesis": "Key gains to deliver: [list], primary adoption factor is [X]",
  "confidence": "high"
}
```

**Purpose:** Identify desired outcomes.

**Gain Categories:**
- Expectations (exceed current state)
- Savings (time/money/effort)
- Adoption Factors (what drives acceptance)
- Life Improvement (quality of life)

---

## Group 3: Requirements Discovery (T7-T10)

### T7: Surface Analysis

```json
{
  "thought": "Step 1/4: Analyzing user's stated request. The user says they want [X]. Let me identify the explicit requirements and any implicit assumptions in this request.",
  "thoughtNumber": 1,
  "totalThoughts": 4,
  "nextThoughtNeeded": true,
  "hypothesis": "The surface request is [X], which may mask a deeper need",
  "confidence": "exploring"
}
```

**Purpose:** Understand the stated request without accepting it at face value.

---

### T8: Root Problem

```json
{
  "thought": "Step 2/4: Probing for root problem. WHY does the user want this? What problem are they actually trying to solve? The stated solution [X] suggests an underlying problem of [Y].",
  "thoughtNumber": 2,
  "totalThoughts": 4,
  "nextThoughtNeeded": true,
  "hypothesis": "The root problem is [Y], not just the stated request [X]",
  "confidence": "low"
}
```

**Purpose:** Uncover the actual problem behind the request.

**Key Question:** WHY does the user want this?

---

### T9: Stakeholder Motivations

```json
{
  "thought": "Step 3/4: Understanding motivations. What success looks like for different stakeholders? Business wants [A], users want [B], technical team needs [C].",
  "thoughtNumber": 3,
  "totalThoughts": 4,
  "nextThoughtNeeded": true,
  "hypothesis": "Success criteria vary by stakeholder: [list]",
  "confidence": "medium"
}
```

**Purpose:** Map different stakeholder success criteria.

---

### T10: True Need Synthesis

```json
{
  "thought": "Step 4/4: Synthesizing true business need. Combining root problem [Y] with stakeholder motivations, the true need is [refined understanding]. This will guide all subsequent analysis.",
  "thoughtNumber": 4,
  "totalThoughts": 4,
  "nextThoughtNeeded": false,
  "hypothesis": "True business need: [comprehensive statement]",
  "confidence": "high"
}
```

**Purpose:** Articulate the true business need that will guide the specification.

---

## Group 4: Context & Competitive Analysis (T11-T13)

### T11: Landscape Mapping

```json
{
  "thought": "Step 1/3: Mapping competitive landscape. What similar solutions exist? Industry leaders include [list]. Common approaches are [patterns].",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Market is [mature/emerging] with [N] key players",
  "confidence": "exploring"
}
```

**Purpose:** Understand the competitive environment.

---

### T12: Standards Identification

```json
{
  "thought": "Step 2/3: Identifying industry standards and user expectations. Standard practices include [list]. Users expect [behaviors]. Compliance requirements: [if any].",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Must-have standards: [list]. Differentiators: [list]",
  "confidence": "medium"
}
```

**Purpose:** Identify industry standards and baseline expectations.

---

### T13: Strategic Insight

```json
{
  "thought": "Step 3/3: Deriving strategic insight. Gap opportunities exist in [areas]. Our solution should differentiate by [approach]. This aligns with business goals because [reasoning].",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false,
  "hypothesis": "Strategic positioning: [statement]",
  "confidence": "high"
}
```

**Purpose:** Derive actionable strategic insights.

---

## Group 5: Stakeholder Analysis (T14-T16)

### T14: Stakeholder Mapping

```json
{
  "thought": "Step 1/3: Mapping all stakeholders. Primary: [list with roles]. Secondary: [list]. External systems/dependencies: [list]. Each has different success criteria.",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Key stakeholders identified: [count] primary, [count] secondary",
  "confidence": "medium"
}
```

**Purpose:** Identify all affected parties.

**Categories:**
- Primary stakeholders (direct users/owners)
- Secondary stakeholders (indirect impact)
- External dependencies (systems/APIs)

---

### T15: Needs Matrix

```json
{
  "thought": "Step 2/3: Documenting needs matrix. [Stakeholder A] needs [X] with priority [H/M/L]. [Stakeholder B] needs [Y] with priority [H/M/L]. Potential conflicts: [list].",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Conflict areas: [list]. High-priority needs: [list]",
  "confidence": "medium"
}
```

**Purpose:** Document stakeholder needs with priorities.

---

### T16: Conflict Resolution

```json
{
  "thought": "Step 3/3: Resolving conflicts. Conflict between [A] and [B] resolved by [approach] because [reasoning]. All stakeholder needs can be addressed through [strategy].",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false,
  "hypothesis": "All conflicts resolved. Unified stakeholder view: [summary]",
  "confidence": "high"
}
```

**Purpose:** Resolve stakeholder conflicts with documented rationale.

---

## Group 6: Requirements Specification (T17-T21)

### T17: Functional Requirements

```json
{
  "thought": "Step 1/5: Generating functional requirements from business needs. FR-1: [requirement]. FR-2: [requirement]. Each maps to stakeholder need [X].",
  "thoughtNumber": 1,
  "totalThoughts": 5,
  "nextThoughtNeeded": true,
  "hypothesis": "Core functional requirements: [count] identified",
  "confidence": "medium"
}
```

**Purpose:** Generate FRs that trace to business needs.

---

### T18: Acceptance Criteria

```json
{
  "thought": "Step 2/5: Defining acceptance criteria. FR-1 acceptance: Given [context], When [action], Then [outcome]. FR-2 acceptance: [similar format].",
  "thoughtNumber": 2,
  "totalThoughts": 5,
  "nextThoughtNeeded": true,
  "hypothesis": "All FRs have testable acceptance criteria",
  "confidence": "medium"
}
```

**Purpose:** Define testable acceptance criteria in Gherkin format.

---

### T19: Testability Validation

```json
{
  "thought": "Step 3/5: Validating testability. Can QA write test cases from each criterion? FR-1: [PASS/FAIL]. FR-2: [PASS/FAIL]. Failed items need refinement: [list].",
  "thoughtNumber": 3,
  "totalThoughts": 5,
  "nextThoughtNeeded": true,
  "hypothesis": "[X]% of requirements are testable. Refinements needed: [count]",
  "confidence": "high"
}
```

**Purpose:** Verify each requirement is testable.

---

### T20: Non-Functional Requirements

```json
{
  "thought": "Step 4/5: Defining NFRs. Performance: [metrics]. Security: [requirements]. Scalability: [targets]. Usability: [standards]. Each has measurable criteria.",
  "thoughtNumber": 4,
  "totalThoughts": 5,
  "nextThoughtNeeded": true,
  "hypothesis": "NFRs cover: performance, security, scalability, usability",
  "confidence": "high"
}
```

**Purpose:** Define measurable NFRs across all quality attributes.

---

### T21: Completeness Check

```json
{
  "thought": "Step 5/5: Verifying specification completeness against template. Business Context: [✓/✗]. FRs: [✓/✗]. NFRs: [✓/✗]. Constraints: [✓/✗]. Out of Scope: [✓/✗]. Open Questions: [✓/✗].",
  "thoughtNumber": 5,
  "totalThoughts": 5,
  "nextThoughtNeeded": false,
  "hypothesis": "Specification is [complete/incomplete]. Gaps: [list if any]",
  "confidence": "high"
}
```

**Purpose:** Final completeness validation against template.

---

## Group 7: Story Splitting (T22-T23)

### T22: Atomic Story Validation

```json
{
  "thought": "Step 1/2: Checking each user story for atomicity. US-001: When count=[N], Then count=[N] → [PASS/SPLIT]. US-002: When count=[N], Then count=[N] → [PASS/SPLIT]. Stories needing split: [list]. Applying 8 splitting criteria in order: (1) Multiple workflow steps? (2) Business rule variations? (3) Data variations? (4) Complex acceptance criteria? (5) Major effort? (6) External dependencies? (7) DevOps effort? (8) TADs needed?",
  "thoughtNumber": 1,
  "totalThoughts": 2,
  "nextThoughtNeeded": true,
  "hypothesis": "[X] stories need splitting, [Y] are atomic",
  "confidence": "high"
}
```

**Purpose:** Identify stories that need splitting.

**Atomicity Rule:** Exactly ONE `When` and ONE `Then` per story.

**8 Splitting Criteria (apply in order):**
1. Multiple workflow steps
2. Business rule variations
3. Data variations
4. Complex acceptance criteria
5. Major effort required
6. External dependencies
7. DevOps effort
8. Tiny Acts of Discovery (TADs)

---

### T23: Split Execution

```json
{
  "thought": "Step 2/2: Executing splits. US-00X split using criterion [N]: [name]. Split into: US-00X-A: [summary], US-00X-B: [summary]. Each new story has exactly ONE When and ONE Then. Verifying no anti-patterns: layer-based split [✓/✗], person-based split [✓/✗], technical-component split [✓/✗]. All splits deliver independent user value: [✓/✗].",
  "thoughtNumber": 2,
  "totalThoughts": 2,
  "nextThoughtNeeded": false,
  "hypothesis": "All stories now atomic. Total stories: [original] → [after split]",
  "confidence": "high"
}
```

**Purpose:** Execute the splits and verify quality.

**Anti-Patterns to Check:**
- Layer-based split (BAD)
- Person-based split (BAD)
- Technical-component split (BAD)

**Correct:** Value-based splitting (each story delivers independent value)

---

## Group 8: Self-Critique (T24-T25)

### T24: Rubric Evaluation

```json
{
  "thought": "Step 1/2: Evaluating specification against 5-dimension rubric. Business Value: [1-4] because [evidence]. Requirements: [1-4] because [evidence]. Testability: [1-4] because [evidence]. Scope: [1-4] because [evidence]. Stakeholders: [1-4] because [evidence]. TOTAL: [X]/20.",
  "thoughtNumber": 1,
  "totalThoughts": 2,
  "nextThoughtNeeded": true,
  "hypothesis": "Specification scores [X]/20. Weakest dimensions: [list]",
  "confidence": "high"
}
```

**Purpose:** Evaluate spec against quality rubric.

**Scoring Interpretation:**
- **16-20:** Ready for submission (PASS)
- **12-15:** Needs minor revision (CONDITIONAL)
- **<12:** Requires significant rework (FAIL)

---

### T25: Gap Remediation

```json
{
  "thought": "Step 2/2: Addressing gaps. Dimension [X] scored [N] because [specific gap]. Remediation: [specific action]. Updating spec section [Y] with [improvement]. Re-evaluating: new score is [N+improvement].",
  "thoughtNumber": 2,
  "totalThoughts": 2,
  "nextThoughtNeeded": false,
  "hypothesis": "After remediation, total score: [X]/20. All dimensions ≥3.",
  "confidence": "high"
}
```

**Purpose:** Address identified gaps before submission.

**Remediation Actions by Dimension:**

| Dimension | Remediation Action |
|-----------|-------------------|
| Business Value (1-2) | Add explicit problem statement, success metrics, ROI justification |
| Requirements (1-2) | Add missing FRs, include error scenarios, edge cases |
| Testability (1-2) | Rewrite criteria in Given/When/Then format |
| Scope (1-2) | Add "Out of Scope" section with explicit exclusions |
| Stakeholders (1-2) | Add stakeholder matrix, resolve documented conflicts |

---

## Usage Instructions

### Loading Templates

The BA agent should load this file when:
1. Starting a new specification (load all groups)
2. Resuming from a specific phase (load relevant group only)
3. Performing self-critique (load Group 8)

### Customizing Templates

Templates can be customized per invocation by:
1. Replacing `[placeholders]` with actual values
2. Adjusting `totalThoughts` if steps need expansion
3. Setting appropriate `confidence` levels

### Checkpoint Integration

After completing each group, emit a checkpoint marker:

```markdown
<!-- CHECKPOINT: {GROUP_NAME} -->
Phase: {GROUP_NAME}
Status: completed
Timestamp: {ISO_DATE}
Key Outputs:
- {output_1}
- {output_2}
<!-- END_CHECKPOINT -->
```
