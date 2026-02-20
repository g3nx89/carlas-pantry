# Sequential Thinking Templates for Architecture Planning

This reference contains all Sequential Thinking MCP templates for the `/product-planning:plan` command.
Templates are organized by planning phase and loaded on-demand during structured analysis.

---

## Template Selection Matrix

| Phase | Templates | Total Steps | When to Use |
|-------|-----------|-------------|-------------|
| Problem Decomposition | T1-T3 | 3 | Understanding the feature request |
| Codebase Analysis | T4-T6 | 3 | Exploring existing patterns |
| Architecture Design | T7-T10 | 4 | Designing implementation approach |
| Diagonal Matrix Architecture | T7a-T8b | 6 | Phase 4 Complete mode (branching exploration) |
| Risk Assessment | T11-T13 | 3 | Identifying and mitigating risks |
| Plan Validation | T14-T16 | 3 | Validating plan quality |
| Test Risk Analysis | T-RISK-1 to T-RISK-3 | 3 | V-Model test planning (Phase 7) |
| Revision | T-RISK-REVISION | 1 | Phase 7 reconciliation (when ThinkDeep contradicts) |
| Red Team | T-RISK-REDTEAM series | 3 | Phase 7 Complete/Advanced (adversarial analysis) |
| TAO Analysis | T-AGENT series | 3 | After MPA in Phases 2, 4, 7 (structured pause) |
| Dynamic Extension | T-EXTENSION | 1 | When complexity exceeds initial estimates |
| Checkpoint | T-CHECKPOINT | 1 | Every 5 thoughts (Rule of 5) |
| Task Decomposition | T-TASK series | 4 | Tech-lead task breakdown (Least-to-Most) |

---

## Group 1: Problem Decomposition (T1-T3)

### T1: Feature Understanding

```json
{
  "thought": "Step 1/3: Understanding the feature request. What is being asked? EXPLICIT requirements: [list from spec]. IMPLICIT requirements: [list inferred]. SUCCESS looks like: [observable outcomes]. FAILURE looks like: [what to avoid]. HYPOTHESIS: The core feature is [X] with success criteria [Y]. CONFIDENCE: exploring.",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true
}
```

**Purpose:** Establish clear understanding of what needs to be built.

**Key Questions:**
- What is the user actually asking for?
- What are the explicit vs implicit requirements?
- How will we know when it's done?

---

### T2: Scope Boundaries

```json
{
  "thought": "Step 2/3: Defining scope boundaries. IN SCOPE: [list of included items]. OUT OF SCOPE: [explicit exclusions]. ASSUMPTIONS: [list with rationale]. DEPENDENCIES: [external systems, teams, data]. HYPOTHESIS: Scope is bounded by [constraints], depends on [dependencies]. CONFIDENCE: medium.",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true
}
```

**Purpose:** Define clear boundaries to prevent scope creep.

**Pattern:** `IN SCOPE... OUT OF SCOPE... ASSUMES... DEPENDS ON...`

---

### T3: Decomposition Strategy

```json
{
  "thought": "Step 3/3: Decomposing into sub-problems. Using Least-to-Most decomposition: ATOMIC problems (smallest, solvable independently): [list]. COMPOSITE problems (require combining solutions): [list]. EXECUTION ORDER: [sequence based on dependencies]. HYPOTHESIS: Feature decomposes into [N] atomic problems with [M] composition steps. CONFIDENCE: high.",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false
}
```

**Purpose:** Break feature into manageable sub-problems.

**Decomposition Criteria:**
- Can it be solved independently?
- Does it have a single responsibility?
- Is it testable in isolation?

---

## Group 2: Codebase Analysis (T4-T6)

### T4: Pattern Recognition

```json
{
  "thought": "Step 1/3: Identifying existing patterns in codebase. SIMILAR FEATURES: [list with file paths]. COMMON PATTERNS: [design patterns used]. CONVENTIONS: [naming, structure, style]. ANTI-PATTERNS to avoid: [list observed issues]. HYPOTHESIS: Codebase follows [patterns], similar features at [locations]. CONFIDENCE: medium.",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true
}
```

**Purpose:** Understand existing code patterns to ensure consistency.

**Key Areas:**
- Design patterns (Repository, Factory, Observer, etc.)
- Naming conventions
- Directory structure
- Error handling patterns

---

### T5: Integration Points

```json
{
  "thought": "Step 2/3: Mapping integration points. ENTRY POINTS: [where feature will be triggered]. DATA FLOWS: [input → processing → output]. SHARED COMPONENTS: [reusable modules]. EXTERNAL APIS: [third-party integrations]. HYPOTHESIS: Feature integrates at [N] points, reuses [M] components. CONFIDENCE: medium.",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true
}
```

**Purpose:** Identify where new code will connect to existing code.

---

### T6: Technical Constraints

```json
{
  "thought": "Step 3/3: Documenting technical constraints. TECHNOLOGY STACK: [required technologies]. PERFORMANCE REQUIREMENTS: [latency, throughput]. SECURITY REQUIREMENTS: [auth, data protection]. COMPATIBILITY: [browser, OS, API versions]. HYPOTHESIS: Key constraints: [list], most limiting factor is [X]. CONFIDENCE: high.",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false
}
```

**Purpose:** Document constraints that will shape architecture decisions.

---

## Group 3: Architecture Design (T7-T10)

### T7: Option Generation

```json
{
  "thought": "Step 1/4: Generating architecture options. OPTION A (Structural Grounding — Inside-Out × Structure): [description] - Pros: [list], Cons: [list]. OPTION B (Contract Ideality — Outside-In × Data): [description] - Pros: [list], Cons: [list]. OPTION C (Resilience Architecture — Failure-First × Behavior): [description] - Pros: [list], Cons: [list]. HYPOTHESIS: Three viable options identified with different trade-offs. CONFIDENCE: medium.",
  "thoughtNumber": 1,
  "totalThoughts": 4,
  "nextThoughtNeeded": true
}
```

**Purpose:** Generate multiple architecture approaches for comparison.

**Required Options (Diagonal Matrix):**
- **Structural Grounding (Inside-Out × Structure):** Starts from existing codebase internals, primary concern is structural integrity
- **Contract Ideality (Outside-In × Data):** Starts from external contracts and APIs, primary concern is data flow correctness
- **Resilience Architecture (Failure-First × Behavior):** Starts from failure scenarios, primary concern is behavioral robustness

---

### T8: Trade-off Analysis

```json
{
  "thought": "Step 2/4: Analyzing trade-offs across dimensions. DIMENSION: Complexity - A:[score], B:[score], C:[score]. DIMENSION: Maintainability - A:[score], B:[score], C:[score]. DIMENSION: Performance - A:[score], B:[score], C:[score]. DIMENSION: Time-to-Implement - A:[score], B:[score], C:[score]. HYPOTHESIS: Option [X] wins on [dimensions], Option [Y] wins on [other dimensions]. CONFIDENCE: high.",
  "thoughtNumber": 2,
  "totalThoughts": 4,
  "nextThoughtNeeded": true
}
```

**Purpose:** Systematically compare options across key dimensions.

**Scoring:** 1-5 scale per dimension, document rationale for each score.

---

### T9: Component Design

```json
{
  "thought": "Step 3/4: Designing component structure for selected option. COMPONENTS: [list with responsibilities]. INTERFACES: [contracts between components]. DATA MODEL: [entities and relationships]. SEQUENCE: [interaction flow diagram description]. HYPOTHESIS: Design has [N] components with [M] interfaces, follows [pattern]. CONFIDENCE: high.",
  "thoughtNumber": 3,
  "totalThoughts": 4,
  "nextThoughtNeeded": true
}
```

**Purpose:** Define the internal structure of the chosen architecture.

**Output Artifacts:**
- Component diagram (described in text)
- Interface contracts
- Data model sketch
- Sequence description

---

### T10: Acceptance Criteria Mapping

```json
{
  "thought": "Step 4/4: Mapping requirements to acceptance criteria. FR-1 maps to: Component [X], Test: Given [context] When [action] Then [outcome]. FR-2 maps to: Component [Y], Test: [similar]. NFRs addressed by: [architectural decisions]. HYPOTHESIS: All [N] requirements have acceptance criteria and component ownership. CONFIDENCE: high.",
  "thoughtNumber": 4,
  "totalThoughts": 4,
  "nextThoughtNeeded": false
}
```

**Purpose:** Ensure every requirement has a clear test and owner.

---

## Group 4: Risk Assessment (T11-T13)

### T11: Risk Identification

```json
{
  "thought": "Step 1/3: Identifying risks using categories. TECHNICAL RISKS: [unknown technologies, complexity]. INTEGRATION RISKS: [API changes, data migration]. SCHEDULE RISKS: [dependencies, unknowns]. SECURITY RISKS: [vulnerabilities, compliance]. HYPOTHESIS: Identified [N] risks across [M] categories. CONFIDENCE: medium.",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true
}
```

**Purpose:** Systematically identify all potential risks.

**Risk Categories:**
- Technical (complexity, unknowns)
- Integration (external systems)
- Schedule (timeline, dependencies)
- Security (vulnerabilities)
- Operational (deployment, monitoring)

---

### T12: Risk Prioritization

```json
{
  "thought": "Step 2/3: Prioritizing risks using probability × impact matrix. HIGH-HIGH: [list] → CRITICAL. HIGH-LOW or LOW-HIGH: [list] → MONITOR. LOW-LOW: [list] → ACCEPT. Risk exposure score: [calculated total]. HYPOTHESIS: [N] critical risks require mitigation before proceeding. CONFIDENCE: high.",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true
}
```

**Purpose:** Prioritize risks to focus mitigation efforts.

**Priority Matrix:**
| Probability | High Impact | Low Impact |
|-------------|-------------|------------|
| High | CRITICAL | MONITOR |
| Low | MONITOR | ACCEPT |

---

### T13: Mitigation Strategies

```json
{
  "thought": "Step 3/3: Defining mitigation strategies. RISK-1: Mitigation: [action], Fallback: [if mitigation fails], Owner: [who]. RISK-2: Mitigation: [action], Fallback: [plan B], Owner: [who]. RESIDUAL RISKS (accepted): [list with justification]. HYPOTHESIS: All critical risks have mitigations, [N] risks accepted with documentation. CONFIDENCE: high.",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false
}
```

**Purpose:** Define concrete actions to address prioritized risks.

**Mitigation Types:**
- **Avoid:** Change design to eliminate risk
- **Transfer:** Shift risk to another party (vendor, insurance)
- **Mitigate:** Reduce probability or impact
- **Accept:** Document and monitor

---

## Group 5: Plan Validation (T14-T16)

### T14: Completeness Check

```json
{
  "thought": "Step 1/3: Verifying plan completeness against checklist. PROBLEM STATEMENT: [PASS/FAIL] - [evidence]. ARCHITECTURE DESIGN: [PASS/FAIL] - [evidence]. TASK BREAKDOWN: [PASS/FAIL] - [evidence]. RISK ASSESSMENT: [PASS/FAIL] - [evidence]. ACCEPTANCE CRITERIA: [PASS/FAIL] - [evidence]. HYPOTHESIS: Plan is [X]% complete, gaps in [areas]. CONFIDENCE: high.",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true
}
```

**Purpose:** Verify all required plan sections are complete.

**Checklist Items:**
- [ ] Problem clearly stated
- [ ] Scope boundaries defined
- [ ] Architecture documented
- [ ] Tasks broken down
- [ ] Dependencies mapped
- [ ] Risks identified
- [ ] Acceptance criteria defined

---

### T15: Consistency Validation

```json
{
  "thought": "Step 2/3: Checking internal consistency. SPEC ↔ DESIGN alignment: [findings]. DESIGN ↔ TASKS alignment: [findings]. TASKS ↔ ACCEPTANCE alignment: [findings]. CONTRADICTIONS found: [list if any]. HYPOTHESIS: Plan is [consistent/inconsistent], issues: [list]. CONFIDENCE: high.",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true
}
```

**Purpose:** Ensure all plan components align with each other.

**Alignment Checks:**
- Requirements → Architecture (all FRs addressed)
- Architecture → Tasks (all components have tasks)
- Tasks → Tests (all tasks have acceptance criteria)

---

### T16: Feasibility Assessment

```json
{
  "thought": "Step 3/3: Assessing overall feasibility. TECHNICAL FEASIBILITY: [assessment with evidence]. SCHEDULE FEASIBILITY: [can it be done in time?]. RESOURCE FEASIBILITY: [skills, tools available?]. RECOMMENDATION: [PROCEED / REVISE / BLOCK] with reasoning. HYPOTHESIS: Plan is [feasible/needs revision], recommendation: [action]. CONFIDENCE: high.",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false
}
```

**Purpose:** Final go/no-go assessment before implementation.

**Feasibility Dimensions:**
- **Technical:** Can we build it with available technology?
- **Schedule:** Can we deliver in the expected timeline?
- **Resource:** Do we have the skills and tools?
- **Risk:** Are residual risks acceptable?

---

## Group 6: Test Risk Analysis (T-RISK-1 to T-RISK-3)

These templates are used in Phase 7 (Test Strategy) for V-Model test planning.

### T-RISK-1: Failure Mode Identification

```json
{
  "thought": "Step 1/3: Identifying all failure modes for this feature. DATA FAILURES: [missing data, malformed input, stale cache, data too large]. INTEGRATION FAILURES: [dependencies unavailable, timeouts, version mismatch, API changes]. STATE FAILURES: [race conditions, stale reads, lost updates, deadlocks]. USER FAILURES: [invalid input, misuse, unexpected navigation, permission issues]. INFRASTRUCTURE FAILURES: [network, disk, memory, CPU exhaustion]. HYPOTHESIS: Identified [N] potential failure modes across [M] categories. CONFIDENCE: medium.",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true
}
```

**Purpose:** Systematically identify all ways the feature could fail before writing tests.

**Failure Categories:**
- **Data:** Input validation, data integrity, cache coherence
- **Integration:** External service availability, contract compliance
- **State:** Concurrency, persistence, session management
- **User:** Input errors, workflow violations, permission boundaries
- **Infrastructure:** Resource limits, network conditions

**Key Question:** "What could go wrong that would make a user unable to complete their task?"

---

### T-RISK-2: Test Risk Prioritization

```json
{
  "thought": "Step 2/3: Prioritizing failure modes for test coverage. CRITICAL (must have tests): [list failures that cause data loss, security breach, or complete feature breakage]. HIGH (should have tests): [list failures that block users with no workaround]. MEDIUM (good to have tests): [list failures with workarounds or degraded experience]. LOW (exploratory coverage): [list minor UX issues]. RECONCILIATION with Phase 5 security insights: [align or note differences]. HYPOTHESIS: [N] critical risks require dedicated test coverage, [M] can be covered by exploratory testing. CONFIDENCE: high.",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true
}
```

**Purpose:** Prioritize which failure modes need dedicated test coverage vs. exploratory testing.

**Priority Matrix:**
| Severity | User Impact | Test Requirement |
|----------|-------------|------------------|
| Critical | Data loss, security breach, system crash | MUST have unit + integration + E2E |
| High | Feature broken, user blocked | MUST have unit + E2E |
| Medium | Degraded experience, workaround available | SHOULD have unit test |
| Low | Cosmetic issues, minor inconvenience | Exploratory coverage |

**Reconciliation Step:** Cross-reference with Phase 5 ThinkDeep security insights to ensure security-related failure modes are captured and prioritized consistently.

---

### T-RISK-3: Risk to Test Mapping

```json
{
  "thought": "Step 3/3: Mapping risks to specific test levels. CRITICAL RISK [R-01]: Mitigated by UT-[ids] (unit), INT-[ids] (integration), E2E-[ids] (end-to-end). HIGH RISK [R-02]: Mitigated by UT-[ids], E2E-[ids]. COVERAGE MATRIX: [risk_id → test_ids mapping]. GAPS IDENTIFIED: [risks without test coverage]. UAT MAPPING: [which risks map to acceptance criteria for user validation]. HYPOTHESIS: All critical/high risks have test coverage, [N] gaps identified for remediation. CONFIDENCE: high.",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false
}
```

**Purpose:** Create explicit mapping between identified risks and test cases at each V-Model level.

**Mapping Rules:**
- Each **Critical** risk → At least 1 unit test + 1 integration test + 1 E2E test
- Each **High** risk → At least 1 unit test + 1 E2E test
- Each **Medium** risk → At least 1 unit test
- Each **Low** risk → Documented for exploratory testing

**Output Artifact:** Coverage matrix in test-plan.md showing risk-to-test traceability.

**UAT Connection:** Map risks that affect user-visible behavior to acceptance criteria for Product Owner validation.

---

## Group 7: Diagonal Matrix Architecture Design (T7a-T8b)

These templates use **branching** to explore architecture through a **Diagonal Matrix** combining two orthogonal dimensions:

- **Perspectives** (from where you look): Inside-Out, Outside-In, Failure-First
- **Concerns** (what you analyze): Structure, Data, Behavior

Three agents cover 9 cells diagonally (1 primary + 2 secondary each). The join changes from **selection** to **reconciliation + composition**, using 100% of all agent output.

```
                  │ Structure  │   Data     │  Behavior  │
─────────────────┼────────────┼────────────┼────────────┤
  Inside-Out     │ ★ PRIMARY  │  secondary │  secondary │  → Structural Grounding
  Outside-In     │  secondary │ ★ PRIMARY  │  secondary │  → Contract Ideality
  Failure-First  │  secondary │  secondary │ ★ PRIMARY  │  → Resilience Architecture
```

Use in Phase 4 Complete mode when multiple viable options exist.

### T7a_FRAME (Decision Fork Point)

```json
{
  "thought": "Step 1/9: FRAME the architecture decision. PROBLEM: {feature_summary}. CONSTRAINTS: {patterns_found}. SUCCESS CRITERIA: {quality_dimensions}. DIAGONAL MATRIX: crossing Perspectives (Inside-Out, Outside-In, Failure-First) × Concerns (Structure, Data, Behavior). BRANCHING into 3 diagonal paths: structural_grounding (Inside-Out × Structure), contract_ideality (Outside-In × Data), resilience_architecture (Failure-First × Behavior). HYPOTHESIS: Three diagonal perspectives will surface complementary insights across all 9 cells. CONFIDENCE: medium.",
  "thoughtNumber": 1,
  "totalThoughts": 9,
  "nextThoughtNeeded": true
}
```

**Purpose:** Establish the decision context and spawn three diagonal exploration branches.

**Key Outputs:**
- Clear problem statement
- Constraints from codebase patterns
- Quality dimensions to optimize
- Diagonal matrix branch definitions (perspective × concern)

---

### T7b_BRANCH_GROUNDING

```json
{
  "thought": "BRANCH: Structural Grounding (Inside-Out × Structure). PRIMARY: Analyze structural integrity from existing codebase internals — module boundaries, dependency graph, abstraction layers. SECONDARY (Data): How data shapes flow through existing structure. SECONDARY (Behavior): How behavioral patterns emerge from structural choices. COMPONENTS: [files to modify/extend]. PROS: Low risk, leverages proven structure. CONS: May miss external contract requirements. PROBABILITY: 0.85. HYPOTHESIS: Inside-Out perspective reveals structural leverage points at {locations}. CONFIDENCE: high.",
  "thoughtNumber": 2,
  "totalThoughts": 9,
  "nextThoughtNeeded": true,
  "branchFromThought": 1,
  "branchId": "grounding"
}
```

**Purpose:** Explore the Inside-Out × Structure diagonal in isolation.

**Branch Parameters:**
- `branchFromThought: 1` - Branches from the FRAME step
- `branchId: "grounding"` - Names this branch for later reference

**Coverage:** Primary = Structure cell, Secondary = Inside-Out × Data, Inside-Out × Behavior

---

### T7c_BRANCH_IDEALITY

```json
{
  "thought": "BRANCH: Contract Ideality (Outside-In × Data). PRIMARY: Design ideal data contracts from external consumer perspective — API shapes, validation schemas, data transformation boundaries. SECONDARY (Structure): What structural components are implied by ideal contracts. SECONDARY (Behavior): What behavioral guarantees contracts must enforce. COMPONENTS: [new contracts/interfaces]. PROS: Clean API boundaries, consumer-driven design. CONS: May require internal restructuring. PROBABILITY: 0.70. HYPOTHESIS: Outside-In perspective defines contract boundaries at {interfaces}. CONFIDENCE: high.",
  "thoughtNumber": 3,
  "totalThoughts": 9,
  "nextThoughtNeeded": true,
  "branchFromThought": 1,
  "branchId": "ideality"
}
```

**Purpose:** Explore the Outside-In × Data diagonal in isolation.

**Coverage:** Primary = Data cell, Secondary = Outside-In × Structure, Outside-In × Behavior

---

### T7d_BRANCH_RESILIENCE

```json
{
  "thought": "BRANCH: Resilience Architecture (Failure-First × Behavior). PRIMARY: Design behavioral robustness starting from failure scenarios — error propagation, recovery paths, degraded operation modes. SECONDARY (Structure): What structural patterns support failure isolation. SECONDARY (Data): What data integrity guarantees survive failures. COMPONENTS: [error handlers, circuit breakers, fallback paths]. PROS: Production-hardened from day one. CONS: Higher upfront complexity. PROBABILITY: 0.75. HYPOTHESIS: Failure-First perspective identifies {N} critical failure modes requiring architectural support. CONFIDENCE: high.",
  "thoughtNumber": 4,
  "totalThoughts": 9,
  "nextThoughtNeeded": true,
  "branchFromThought": 1,
  "branchId": "resilience"
}
```

**Purpose:** Explore the Failure-First × Behavior diagonal in isolation.

**Coverage:** Primary = Behavior cell, Secondary = Failure-First × Structure, Failure-First × Data

---

### T8a_RECONCILE (Join Pass 1: Tension Map)

```json
{
  "thought": "RECONCILE (Pass 1): Building tension map across 9 matrix cells. For each cell (Perspective × Concern), compare what each agent said. STRUCTURE: Grounding says {G}, Ideality implies {I}, Resilience requires {R} — tension: {LOW|MEDIUM|HIGH}. DATA: Grounding assumes {G}, Ideality defines {I}, Resilience protects {R} — tension: {LOW|MEDIUM|HIGH}. BEHAVIOR: Grounding inherits {G}, Ideality enforces {I}, Resilience prioritizes {R} — tension: {LOW|MEDIUM|HIGH}. TOTAL: {N} low-tension cells (direct merge), {M} medium-tension cells (enrichment needed), {P} high-tension cells (resolution required). HYPOTHESIS: Tension map reveals {N+M+P} integration points with {P} requiring explicit resolution. CONFIDENCE: medium.",
  "thoughtNumber": 5,
  "totalThoughts": 9,
  "nextThoughtNeeded": true
}
```

**Purpose:** Build a 9-cell tension map comparing what each agent said about each concern. Classifies tensions as low/medium/high.

**Key Outputs:**
- Per-cell tension classification across all 9 matrix cells
- Identification of convergent areas (low tension) vs. conflict areas (high tension)
- Input for Pass 2 composition strategy

---

### T8b_COMPOSE (Join Pass 2: Merge with Resolution)

```json
{
  "thought": "COMPOSE (Pass 2): Merging primaries with tension resolution. STRUCTURE (from Grounding primary): {deep analysis}. Enriched by Ideality structural implications + Resilience structural requirements. DATA (from Ideality primary): {deep analysis}. Enriched by Grounding data flow insights + Resilience data integrity guarantees. BEHAVIOR (from Resilience primary): {deep analysis}. Enriched by Grounding behavioral patterns + Ideality behavioral contracts. HIGH-TENSION RESOLUTIONS: {cell}: chose {approach} because {rationale}. COMPOSITION STRATEGY: {DIRECT_COMPOSITION|NEGOTIATED_COMPOSITION|REFRAME}. HYPOTHESIS: Composed architecture integrates all 3 primaries with {P} tension resolutions applied. CONFIDENCE: high.",
  "thoughtNumber": 6,
  "totalThoughts": 9,
  "nextThoughtNeeded": true
}
```

**Purpose:** Take deep analysis from each primary concern (Structure from Grounding, Data from Ideality, Behavior from Resilience), enrich with secondary insights, and apply tension resolutions.

**Key Outputs:**
- Merged architecture combining all three primary analyses
- Tension resolutions with rationale for each high-tension cell
- Composition strategy determination

**Note:** After T8b_COMPOSE, continue with standard T9_COMPONENT_DESIGN and T10_AC_MAPPING using the composed architecture.

**Checkpoint Rule:** The Diagonal Matrix chain spans 9 thoughts (T7a through T10 continuation). Per the Rule of 5, insert a T-CHECKPOINT between T8a_RECONCILE (thought 5) and T8b_COMPOSE (thought 6) to consolidate diagonal findings before proceeding to composition.

---

## Group 8: Revision Templates

Revision templates allow updating earlier conclusions when new evidence emerges. Use when Phase 5 ThinkDeep insights contradict Phase 7 risk analysis.

### T-RISK-REVISION

```json
{
  "thought": "REVISION of Risk Prioritization: ThinkDeep identified NEW/DIFFERENT insights. THINKDEEP: {findings}. ORIGINAL: {T-RISK-2_output}. CONFLICTS: [list]. RESOLUTION: Using higher severity. NEW RISKS: {additions}. HYPOTHESIS: Phase 5 insights update risk; {N} conflicts resolved. CONFIDENCE: high.",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "isRevision": true,
  "revisesThought": 2
}
```

**Purpose:** Reconcile Phase 5 ThinkDeep security/performance findings with Phase 7 T-RISK-2 output.

**Revision Parameters:**
- `isRevision: true` - Marks this as updating a previous thought
- `revisesThought: 2` - References the original T-RISK-2 thought

**When to Use:**
- ThinkDeep identified risks not captured in standard T-RISK analysis
- ThinkDeep assigned different severity than T-RISK-2
- Phase 5 security analysis found new attack vectors

**Resolution Strategy:**
- For conflicting severities: Use the higher severity
- For new risks: Add to risk list with ThinkDeep reference
- For missing ThinkDeep coverage: Flag for human decision

---

## Group 9: Red Team Analysis

Red Team templates add an adversarial perspective to risk analysis. Use in Phase 7 Complete/Advanced modes for security-sensitive features.

### T-RISK-REDTEAM

```json
{
  "thought": "BRANCH: Red Team. ATTACKER PERSPECTIVE: Entry points: {inputs}. Attack vectors: {injections, auth bypass, data exfiltration}. Impact: {breach, disruption, data loss}. OVERLOOKED: {what standard analysis missed}. HYPOTHESIS: Adversarial analysis reveals {N} additional vectors. CONFIDENCE: medium.",
  "thoughtNumber": 2,
  "totalThoughts": 4,
  "nextThoughtNeeded": true,
  "branchFromThought": 1,
  "branchId": "redteam"
}
```

**Purpose:** Think like an attacker to identify risks standard analysis misses.

**Key Questions:**
- What entry points exist for malicious input?
- How could authentication/authorization be bypassed?
- What data could be exfiltrated or corrupted?
- What service disruption is possible?

---

### T-RISK-REDTEAM-SYNTHESIS

```json
{
  "thought": "SYNTHESIS: Merging red team findings. NEW ATTACKS: [list]. ADDITIONS TO TEST PLAN: {new security cases}. COVERAGE GAPS CLOSED: [what red team revealed]. HYPOTHESIS: Red team adds {N} new test cases. CONFIDENCE: high.",
  "thoughtNumber": 3,
  "totalThoughts": 4,
  "nextThoughtNeeded": true
}
```

**Purpose:** Merge red team findings back into the main test plan.

**Outputs:**
- New attack vectors identified
- Additional security test cases
- Coverage gaps that were previously invisible

---

### T-RISK-REDTEAM-FINALIZE

```json
{
  "thought": "RED TEAM COMPLETE. TOTAL NEW VECTORS: {N}. TEST CASES ADDED: SEC-RT-{IDs}. RESIDUAL RISK: {assessment}. All red team findings integrated into main test plan. HYPOTHESIS: Red team analysis is complete with {N} vectors addressed. CONFIDENCE: high.",
  "thoughtNumber": 4,
  "totalThoughts": 4,
  "nextThoughtNeeded": false
}
```

**Purpose:** Close the red team branch chain with a definitive termination. Summarizes all findings and confirms integration into the main test plan.

**Termination Rule:** This MUST be the final thought in the red team chain. `nextThoughtNeeded: false` closes the branch properly.

---

## Group 10: Agent Output Analysis (TAO Loop)

TAO (Think-Analyze-Output) Loop templates provide structured pause points between MPA agent outputs and decisions. Prevents rushed synthesis and ensures all perspectives are properly considered.

### T-AGENT-ANALYSIS

```json
{
  "thought": "ANALYSIS of MPA outputs. AGENTS: [{list}]. CONVERGENT (all agree): [{list}] - HIGH priority. DIVERGENT (disagree): [{list}] - FLAG for decision. GAPS: [{list}]. HYPOTHESIS: MPA has {N} convergent, {M} divergent findings. CONFIDENCE: medium.",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true
}
```

**Purpose:** Categorize agent outputs before synthesis.

**Categories:**
- **Convergent:** All agents agree → High confidence, incorporate directly
- **Divergent:** Agents disagree → Requires decision or further analysis
- **Gaps:** Topics no agent covered → Accept risk or research further

---

### T-AGENT-SYNTHESIS

```json
{
  "thought": "SYNTHESIS strategy. CONVERGENT: Incorporate directly. DIVERGENT: Present options OR apply adaptive strategy. GAPS: Accept or research. DECISION: Proceeding with {strategy}. HYPOTHESIS: Synthesis strategy is {strategy}. CONFIDENCE: high.",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true
}
```

**Purpose:** Define how to handle each category of findings.

**Strategies by Category:**
- **Convergent:** Direct incorporation (no user decision needed)
- **Divergent:** Present options to user OR apply adaptive strategy (DIRECT_COMPOSITION, NEGOTIATED_COMPOSITION)
- **Gaps:** Accept as known unknowns OR trigger research agent

---

### T-AGENT-VALIDATION

```json
{
  "thought": "VALIDATION: [ ] All requirements addressed? [ ] Trade-offs documented? [ ] Risks identified? [ ] No unresolved conflicts? RESULT: {PASS/FAIL}. HYPOTHESIS: Synthesis ready for next phase. CONFIDENCE: high.",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false
}
```

**Purpose:** Final quality check before proceeding to next phase.

**Validation Checklist:**
- All requirements from spec addressed
- Trade-offs explicitly documented
- Risks captured with mitigations
- No unresolved agent conflicts

---

## Group 11: Dynamic Extension

When complexity exceeds initial estimates, use `needsMoreThoughts` to extend the chain.

### T-EXTENSION

```json
{
  "thought": "EXTENSION: Complexity exceeds initial estimate. REASON: {unexpected_complexity}. ADDING {N} more thoughts for: {additional_analysis_needed}. HYPOTHESIS: Additional analysis needed for {reason}. CONFIDENCE: medium.",
  "thoughtNumber": 8,
  "totalThoughts": 10,
  "nextThoughtNeeded": true,
  "needsMoreThoughts": true
}
```

**Purpose:** Dynamically extend the thought chain when more analysis is required.

**When to Use:**
- Feature complexity is higher than initially estimated
- New integration points discovered during analysis
- Security/compliance requirements more extensive than expected
- Component count exceeds 10

**Extension Guidelines:**
- Add 2-4 thoughts maximum per extension
- Document why extension is needed
- Update `totalThoughts` to reflect new estimate

---

## Usage Instructions

### Loading Templates

The planning command loads templates when:
1. Starting a new planning session (load all groups)
2. Resuming from a specific phase (load relevant group only)
3. Running validation (load Group 5)

### Customizing Templates

Templates can be customized per invocation by:
1. Replacing `[placeholders]` with actual values
2. Adjusting `totalThoughts` if steps need expansion
3. Embedding appropriate `HYPOTHESIS` and `CONFIDENCE` values at the end of the `thought` string

### MCP Invocation Pattern

For each template step, invoke Sequential Thinking:

```javascript
mcp__sequential-thinking__sequentialthinking({
  thought: "Step X/Y: {filled template content}. HYPOTHESIS: {current hypothesis}. CONFIDENCE: {exploring|low|medium|high}.",
  thoughtNumber: X,
  totalThoughts: Y,
  nextThoughtNeeded: X < Y
})
```

**Note:** `hypothesis` and `confidence` are NOT separate ST parameters. Embed them at the end of the `thought` string (e.g., `"...analysis complete. HYPOTHESIS: {text}. CONFIDENCE: {level}."`). The ST server only accepts: `thought`, `thoughtNumber`, `totalThoughts`, `nextThoughtNeeded`, `isRevision`, `revisesThought`, `branchFromThought`, `branchId`, `needsMoreThoughts`.

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

---

## Template-Agent Mapping

| Agent | Uses Templates | Purpose |
|-------|---------------|---------|
| code-explorer | T4-T6, T-AGENT series, T-CHECKPOINT | Codebase analysis with TAO synthesis |
| software-architect | T7-T10, T7a-T8b (Diagonal Matrix), T11-T13, T-CHECKPOINT | Architecture design with risk assessment |
| tech-lead | T1-T3, T-TASK series, T-CHECKPOINT | Problem decomposition and task breakdown |
| orchestrator | T14-T16, T-AGENT series, T-CHECKPOINT | Validation and synthesis |
| qa-strategist | T-RISK-1 to T-RISK-3, T-RISK-REVISION, T-RISK-REDTEAM series (3 templates), T-CHECKPOINT | Test risk analysis (Phase 7) |
| qa-security | T-RISK-1, T-RISK-2, T-RISK-REDTEAM, T-CHECKPOINT | Security-focused test planning |
| qa-performance | T-RISK-1, T-RISK-2, T-CHECKPOINT | Performance-focused test planning |

**Note:** T-CHECKPOINT is used by ALL agents for chains of 5+ thoughts following the Rule of 5.

### ST Feature Availability by Mode

| Template Group | Rapid | Standard | Advanced | Complete |
|----------------|-------|----------|----------|----------|
| Problem Decomposition (T1-T3) | ❌ | ❌ | ✅ | ✅ |
| Codebase Analysis (T4-T6) | ❌ | ❌ | ❌ | ✅ |
| Architecture Design (T7-T10) | ❌ | ❌ | ❌ | ✅ |
| Diagonal Matrix (T7a-T8b) | ❌ | ❌ | ❌ | ✅ |
| Risk Assessment (T11-T13) | ❌ | ❌ | ✅ | ✅ |
| Plan Validation (T14-T16) | ❌ | ❌ | ❌ | ✅ |
| Test Risk Analysis (T-RISK-1 to T-RISK-3) | ❌ | ❌ | ✅ | ✅ |
| Revision (T-RISK-REVISION) | ❌ | ❌ | ✅ | ✅ |
| Red Team (T-RISK-REDTEAM) | ❌ | ❌ | ✅ | ✅ |
| TAO Loop (T-AGENT series) | ❌ | ✅ | ✅ | ✅ |
| Dynamic Extension (T-EXTENSION) | ❌ | ❌ | ❌ | ✅ |
| Checkpoint (T-CHECKPOINT) | ❌ | ✅ | ✅ | ✅ |
| Task Decomposition (T-TASK series) | ❌ | ❌ | ✅ | ✅ |

---

## Group 12: Checkpoint Management (T-CHECKPOINT)

Checkpoint templates consolidate progress every 5 thoughts to prevent cognitive drift and ensure chain coherence. Following the "Rule of 5" from ST best practices.

### T-CHECKPOINT

```json
{
  "thought": "CHECKPOINT at thought {N}. PROGRESS SUMMARY: [key findings so far]. HYPOTHESES STATUS: Confirmed: [list], Rejected: [list], Open: [list]. REMAINING INVESTIGATION: [open questions]. NEXT PLANNED STEP: [specific next action]. CONFIDENCE TREND: {increasing|stable|decreasing}. ESTIMATE CHECK: Current {totalThoughts} {adequate|needs extension}. HYPOTHESIS: On track with {X}% progress, {Y} open items remain. CONFIDENCE: medium.",
  "thoughtNumber": 5,
  "totalThoughts": 10,
  "nextThoughtNeeded": true,
  "needsMoreThoughts": false
}
```

**Purpose:** Create mental buffer clear, consolidating findings and freeing cognitive space for next analysis phase.

**When to Invoke:**
- Every 5 thoughts in any chain
- When switching between analysis phases
- Before major branching decisions
- When confidence drops significantly

**Checkpoint Content Requirements:**
1. **Progress Summary:** What has been definitively established
2. **Hypothesis Status:** Track which hypotheses are confirmed/rejected/open
3. **Remaining Work:** Clear list of what still needs investigation
4. **Next Step:** Explicit plan for continuing
5. **Estimate Adjustment:** Whether `totalThoughts` needs updating

**Integration Rule:** Any agent using ST chains of 5+ thoughts MUST include T-CHECKPOINT.

---

## Group 13: Task Decomposition (T-TASK Series)

Task decomposition templates support Least-to-Most problem breakdown for tech-lead agent. Structures the process of breaking features into ordered, dependency-respecting tasks.

### T-TASK-DECOMPOSE

```json
{
  "thought": "DECOMPOSITION of {FEATURE_NAME}. LEVEL 0 (zero dependencies): [config, types, schemas, interfaces - list specific items]. LEVEL 1 (depends only on L0): [utilities, base models, test fixtures - list specific items]. LEVEL 2+ (per user story): [story-specific subproblems in dependency order]. DEPENDENCY CHAIN: L0 → L1 → L2 → ... → Complete feature. PARALLEL OPPORTUNITIES at each level: [tasks that can run concurrently]. HYPOTHESIS: Feature decomposes into {N} levels with {M} tasks, {P} parallel opportunities. CONFIDENCE: medium.",
  "thoughtNumber": 1,
  "totalThoughts": 4,
  "nextThoughtNeeded": true
}
```

**Purpose:** Establish the Least-to-Most decomposition chain before creating individual tasks.

**Key Outputs:**
- Level assignments for all subproblems
- Dependency relationships between levels
- Parallel execution opportunities within each level

---

### T-TASK-SEQUENCE

```json
{
  "thought": "SEQUENCING tasks within levels. IMPLEMENTATION STRATEGY: {top-down|bottom-up|mixed} because {rationale}. LEVEL 0 ORDER: [ordered list]. LEVEL 1 ORDER: [ordered list]. LEVEL 2+ ORDER (per story): [ordered list]. CRITICAL PATH: [tasks that determine minimum completion time]. RISK-FIRST items moved early: [high-risk tasks placed in early positions]. HYPOTHESIS: Optimal sequence minimizes blocking, critical path is {N} tasks. CONFIDENCE: high.",
  "thoughtNumber": 2,
  "totalThoughts": 4,
  "nextThoughtNeeded": true
}
```

**Purpose:** Order tasks within each level following TDD and risk-first principles.

**Sequencing Rules:**
1. Test infrastructure before features needing tests
2. High-risk/uncertainty tasks early for fast feedback
3. Blocking dependencies before dependent tasks
4. Parallel opportunities grouped for team distribution

---

### T-TASK-VALIDATE

```json
{
  "thought": "VALIDATION of task breakdown. CHECKING: [ ] All user stories have complete task coverage? [ ] No circular dependencies exist? [ ] Each task depends only on earlier levels? [ ] Every task completable in 1-2 days? [ ] TDD pattern respected (tests in DoD)? [ ] Critical path correctly identified? ISSUES FOUND: [list]. FIXES APPLIED: [list]. HYPOTHESIS: Task breakdown valid after {N} fixes applied. CONFIDENCE: high.",
  "thoughtNumber": 3,
  "totalThoughts": 4,
  "nextThoughtNeeded": true,
  "isRevision": true,
  "revisesThought": 1
}
```

**Purpose:** Verify task breakdown before delivery, applying fixes for any issues found.

**Validation Checklist:**
- [ ] All user stories from spec have tasks
- [ ] No forward dependencies (task referencing later task)
- [ ] No circular dependencies
- [ ] Tasks sized appropriately (1-2 days)
- [ ] Test infrastructure in Level 0-1
- [ ] Every task has DoD including tests
- [ ] Critical path documented

---

### T-TASK-FINALIZE

```json
{
  "thought": "FINALIZATION of task breakdown. SUMMARY: {total_tasks} tasks across {levels} levels. HIGH-RISK TASKS requiring attention: [list with context]. PARALLEL EXECUTION PLAN: [which tasks can run concurrently per level]. MVP SCOPE: [minimum tasks for first deliverable]. INCREMENTAL MILESTONES: [demonstrable progress points]. HYPOTHESIS: Task breakdown complete and ready for sprint planning. CONFIDENCE: high.",
  "thoughtNumber": 4,
  "totalThoughts": 4,
  "nextThoughtNeeded": false
}
```

**Purpose:** Produce final task breakdown with clear next steps and risk callouts.

**Required Outputs:**
- Total task count and level distribution
- Flagged high-risk tasks with context
- Parallel execution recommendations
- MVP scope identification
- Incremental milestones

---

## Termination Criteria by Template Group

Each template group has explicit criteria for when to set `nextThoughtNeeded: false`.

### Problem Decomposition (T1-T3) Termination

Set `nextThoughtNeeded: false` after T3 when ALL are true:
- ✅ Feature understood with explicit/implicit requirements listed
- ✅ Scope boundaries defined (IN/OUT/ASSUMES/DEPENDS)
- ✅ Atomic and composite subproblems identified
- ✅ Execution order determined based on dependencies

### Codebase Analysis (T4-T6) Termination

Set `nextThoughtNeeded: false` after T6 when ALL are true:
- ✅ Existing patterns identified with file:line references
- ✅ Integration points mapped with data flows
- ✅ Technical constraints documented
- ✅ Similar features found and analyzed

### Architecture Design (T7-T10) Termination

Set `nextThoughtNeeded: false` after T10 when ALL are true:
- ✅ One approach selected with documented rationale
- ✅ All components have defined file paths and interfaces
- ✅ Integration points mapped to existing code
- ✅ Acceptance criteria mapped to components
- ✅ Self-critique passed (5/5 questions verified)

### Diagonal Matrix Architecture (T7a-T8b) Termination

Set `nextThoughtNeeded: false` after T8b_COMPOSE when ALL are true:
- ✅ All three diagonal branches explored (grounding, ideality, resilience)
- ✅ Tension map built across all 9 matrix cells (T8a_RECONCILE)
- ✅ Primaries composed with tension resolutions documented (T8b_COMPOSE)
- ✅ Composition strategy determined (DIRECT_COMPOSITION / NEGOTIATED_COMPOSITION / REFRAME)
- ✅ T-CHECKPOINT inserted between T8a_RECONCILE (thought 5) and T8b_COMPOSE (thought 6)

### Risk Assessment (T11-T13) Termination

Set `nextThoughtNeeded: false` after T13 when ALL are true:
- ✅ Risks identified across all categories (technical, integration, schedule, security)
- ✅ Priority matrix applied (probability × impact)
- ✅ Critical risks have mitigation strategies
- ✅ Residual risks documented with justification

### Plan Validation (T14-T16) Termination

Set `nextThoughtNeeded: false` after T16 when ALL are true:
- ✅ Completeness check passed
- ✅ Internal consistency verified (spec↔design↔tasks)
- ✅ Feasibility assessed (technical, schedule, resource)
- ✅ Clear recommendation (PROCEED/REVISE/BLOCK)

### Test Risk Analysis (T-RISK-1 to T-RISK-3) Termination

Set `nextThoughtNeeded: false` after T-RISK-3 when ALL are true:
- ✅ Failure modes identified across all categories
- ✅ Risks prioritized by severity
- ✅ Each Critical/High risk mapped to test IDs
- ✅ Coverage matrix complete with no gaps
- ✅ Phase 5 reconciliation addressed (if applicable)

### TAO Loop (T-AGENT series) Termination

Set `nextThoughtNeeded: false` after T-AGENT-VALIDATION when ALL are true:
- ✅ Agent outputs categorized (convergent/divergent/gaps)
- ✅ Handling strategy defined for each category
- ✅ Validation checklist passed
- ✅ No unresolved conflicts flagged

### Task Decomposition (T-TASK series) Termination

Set `nextThoughtNeeded: false` after T-TASK-FINALIZE when ALL are true:
- ✅ All levels defined with dependency chains
- ✅ Sequencing optimized for parallel execution
- ✅ Validation checklist passed (no circular deps, proper sizing)
- ✅ High-risk tasks flagged with context
- ✅ MVP scope identified

---

## Quality Criteria

Each Sequential Thinking step should:
1. **Be grounded** - Reference actual code/docs, not hallucinations
2. **Be actionable** - Lead to concrete outputs
3. **Build on previous** - Reference findings from earlier steps
4. **Include confidence** - Honest assessment of certainty level (embedded in `thought` string)
5. **Document unknowns** - Explicitly mark areas needing clarification
