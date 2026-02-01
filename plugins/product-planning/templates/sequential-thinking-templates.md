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
| Fork-Join Architecture | T7a-T8 | 5 | Phase 4 Complete mode (branching exploration) |
| Risk Assessment | T11-T13 | 3 | Identifying and mitigating risks |
| Plan Validation | T14-T16 | 3 | Validating plan quality |
| Test Risk Analysis | T-RISK-1 to T-RISK-3 | 3 | V-Model test planning (Phase 7) |
| Revision | T-RISK-REVISION | 1 | Phase 7 reconciliation (when ThinkDeep contradicts) |
| Red Team | T-RISK-REDTEAM series | 2 | Phase 7 Complete/Advanced (adversarial analysis) |
| TAO Analysis | T-AGENT series | 3 | After MPA in Phases 2, 4, 7 (structured pause) |

---

## Group 1: Problem Decomposition (T1-T3)

### T1: Feature Understanding

```json
{
  "thought": "Step 1/3: Understanding the feature request. What is being asked? EXPLICIT requirements: [list from spec]. IMPLICIT requirements: [list inferred]. SUCCESS looks like: [observable outcomes]. FAILURE looks like: [what to avoid].",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "The core feature is [X] with success criteria [Y]",
  "confidence": "exploring"
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
  "thought": "Step 2/3: Defining scope boundaries. IN SCOPE: [list of included items]. OUT OF SCOPE: [explicit exclusions]. ASSUMPTIONS: [list with rationale]. DEPENDENCIES: [external systems, teams, data].",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Scope is bounded by [constraints], depends on [dependencies]",
  "confidence": "medium"
}
```

**Purpose:** Define clear boundaries to prevent scope creep.

**Pattern:** `IN SCOPE... OUT OF SCOPE... ASSUMES... DEPENDS ON...`

---

### T3: Decomposition Strategy

```json
{
  "thought": "Step 3/3: Decomposing into sub-problems. Using Least-to-Most decomposition: ATOMIC problems (smallest, solvable independently): [list]. COMPOSITE problems (require combining solutions): [list]. EXECUTION ORDER: [sequence based on dependencies].",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false,
  "hypothesis": "Feature decomposes into [N] atomic problems with [M] composition steps",
  "confidence": "high"
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
  "thought": "Step 1/3: Identifying existing patterns in codebase. SIMILAR FEATURES: [list with file paths]. COMMON PATTERNS: [design patterns used]. CONVENTIONS: [naming, structure, style]. ANTI-PATTERNS to avoid: [list observed issues].",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Codebase follows [patterns], similar features at [locations]",
  "confidence": "medium"
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
  "thought": "Step 2/3: Mapping integration points. ENTRY POINTS: [where feature will be triggered]. DATA FLOWS: [input → processing → output]. SHARED COMPONENTS: [reusable modules]. EXTERNAL APIS: [third-party integrations].",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Feature integrates at [N] points, reuses [M] components",
  "confidence": "medium"
}
```

**Purpose:** Identify where new code will connect to existing code.

---

### T6: Technical Constraints

```json
{
  "thought": "Step 3/3: Documenting technical constraints. TECHNOLOGY STACK: [required technologies]. PERFORMANCE REQUIREMENTS: [latency, throughput]. SECURITY REQUIREMENTS: [auth, data protection]. COMPATIBILITY: [browser, OS, API versions].",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false,
  "hypothesis": "Key constraints: [list], most limiting factor is [X]",
  "confidence": "high"
}
```

**Purpose:** Document constraints that will shape architecture decisions.

---

## Group 3: Architecture Design (T7-T10)

### T7: Option Generation

```json
{
  "thought": "Step 1/4: Generating architecture options. OPTION A (Minimal Change): [description] - Pros: [list], Cons: [list]. OPTION B (Clean Architecture): [description] - Pros: [list], Cons: [list]. OPTION C (Pragmatic Balance): [description] - Pros: [list], Cons: [list].",
  "thoughtNumber": 1,
  "totalThoughts": 4,
  "nextThoughtNeeded": true,
  "hypothesis": "Three viable options identified with different trade-offs",
  "confidence": "medium"
}
```

**Purpose:** Generate multiple architecture approaches for comparison.

**Required Options:**
- **Minimal Change:** Smallest delta to existing code
- **Clean Architecture:** Best practices, may require refactoring
- **Pragmatic Balance:** Middle ground optimizing for delivery + quality

---

### T8: Trade-off Analysis

```json
{
  "thought": "Step 2/4: Analyzing trade-offs across dimensions. DIMENSION: Complexity - A:[score], B:[score], C:[score]. DIMENSION: Maintainability - A:[score], B:[score], C:[score]. DIMENSION: Performance - A:[score], B:[score], C:[score]. DIMENSION: Time-to-Implement - A:[score], B:[score], C:[score].",
  "thoughtNumber": 2,
  "totalThoughts": 4,
  "nextThoughtNeeded": true,
  "hypothesis": "Option [X] wins on [dimensions], Option [Y] wins on [other dimensions]",
  "confidence": "high"
}
```

**Purpose:** Systematically compare options across key dimensions.

**Scoring:** 1-5 scale per dimension, document rationale for each score.

---

### T9: Component Design

```json
{
  "thought": "Step 3/4: Designing component structure for selected option. COMPONENTS: [list with responsibilities]. INTERFACES: [contracts between components]. DATA MODEL: [entities and relationships]. SEQUENCE: [interaction flow diagram description].",
  "thoughtNumber": 3,
  "totalThoughts": 4,
  "nextThoughtNeeded": true,
  "hypothesis": "Design has [N] components with [M] interfaces, follows [pattern]",
  "confidence": "high"
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
  "thought": "Step 4/4: Mapping requirements to acceptance criteria. FR-1 maps to: Component [X], Test: Given [context] When [action] Then [outcome]. FR-2 maps to: Component [Y], Test: [similar]. NFRs addressed by: [architectural decisions].",
  "thoughtNumber": 4,
  "totalThoughts": 4,
  "nextThoughtNeeded": false,
  "hypothesis": "All [N] requirements have acceptance criteria and component ownership",
  "confidence": "high"
}
```

**Purpose:** Ensure every requirement has a clear test and owner.

---

## Group 4: Risk Assessment (T11-T13)

### T11: Risk Identification

```json
{
  "thought": "Step 1/3: Identifying risks using categories. TECHNICAL RISKS: [unknown technologies, complexity]. INTEGRATION RISKS: [API changes, data migration]. SCHEDULE RISKS: [dependencies, unknowns]. SECURITY RISKS: [vulnerabilities, compliance].",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Identified [N] risks across [M] categories",
  "confidence": "medium"
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
  "thought": "Step 2/3: Prioritizing risks using probability × impact matrix. HIGH-HIGH: [list] → CRITICAL. HIGH-LOW or LOW-HIGH: [list] → MONITOR. LOW-LOW: [list] → ACCEPT. Risk exposure score: [calculated total].",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "[N] critical risks require mitigation before proceeding",
  "confidence": "high"
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
  "thought": "Step 3/3: Defining mitigation strategies. RISK-1: Mitigation: [action], Fallback: [if mitigation fails], Owner: [who]. RISK-2: Mitigation: [action], Fallback: [plan B], Owner: [who]. RESIDUAL RISKS (accepted): [list with justification].",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false,
  "hypothesis": "All critical risks have mitigations, [N] risks accepted with documentation",
  "confidence": "high"
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
  "thought": "Step 1/3: Verifying plan completeness against checklist. PROBLEM STATEMENT: [PASS/FAIL] - [evidence]. ARCHITECTURE DESIGN: [PASS/FAIL] - [evidence]. TASK BREAKDOWN: [PASS/FAIL] - [evidence]. RISK ASSESSMENT: [PASS/FAIL] - [evidence]. ACCEPTANCE CRITERIA: [PASS/FAIL] - [evidence].",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Plan is [X]% complete, gaps in [areas]",
  "confidence": "high"
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
  "thought": "Step 2/3: Checking internal consistency. SPEC ↔ DESIGN alignment: [findings]. DESIGN ↔ TASKS alignment: [findings]. TASKS ↔ ACCEPTANCE alignment: [findings]. CONTRADICTIONS found: [list if any].",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Plan is [consistent/inconsistent], issues: [list]",
  "confidence": "high"
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
  "thought": "Step 3/3: Assessing overall feasibility. TECHNICAL FEASIBILITY: [assessment with evidence]. SCHEDULE FEASIBILITY: [can it be done in time?]. RESOURCE FEASIBILITY: [skills, tools available?]. RECOMMENDATION: [PROCEED / REVISE / BLOCK] with reasoning.",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false,
  "hypothesis": "Plan is [feasible/needs revision], recommendation: [action]",
  "confidence": "high"
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
  "thought": "Step 1/3: Identifying all failure modes for this feature. DATA FAILURES: [missing data, malformed input, stale cache, data too large]. INTEGRATION FAILURES: [dependencies unavailable, timeouts, version mismatch, API changes]. STATE FAILURES: [race conditions, stale reads, lost updates, deadlocks]. USER FAILURES: [invalid input, misuse, unexpected navigation, permission issues]. INFRASTRUCTURE FAILURES: [network, disk, memory, CPU exhaustion].",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Identified [N] potential failure modes across [M] categories",
  "confidence": "medium"
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
  "thought": "Step 2/3: Prioritizing failure modes for test coverage. CRITICAL (must have tests): [list failures that cause data loss, security breach, or complete feature breakage]. HIGH (should have tests): [list failures that block users with no workaround]. MEDIUM (good to have tests): [list failures with workarounds or degraded experience]. LOW (exploratory coverage): [list minor UX issues]. RECONCILIATION with Phase 5 security insights: [align or note differences].",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "[N] critical risks require dedicated test coverage, [M] can be covered by exploratory testing",
  "confidence": "high"
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
  "thought": "Step 3/3: Mapping risks to specific test levels. CRITICAL RISK [R-01]: Mitigated by UT-[ids] (unit), INT-[ids] (integration), E2E-[ids] (end-to-end). HIGH RISK [R-02]: Mitigated by UT-[ids], E2E-[ids]. COVERAGE MATRIX: [risk_id → test_ids mapping]. GAPS IDENTIFIED: [risks without test coverage]. UAT MAPPING: [which risks map to acceptance criteria for user validation].",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false,
  "hypothesis": "All critical/high risks have test coverage, [N] gaps identified for remediation",
  "confidence": "high"
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

## Group 7: Fork-Join Architecture Design (T7a-T8)

These templates use **branching** to explore multiple architecture approaches in parallel, then synthesize the best elements. Use in Phase 4 Complete mode when multiple viable options exist.

### T7a_FRAME (Decision Fork Point)

```json
{
  "thought": "Step 1/8: FRAME the architecture decision. PROBLEM: {feature_summary}. CONSTRAINTS: {patterns_found}. SUCCESS CRITERIA: {quality_dimensions}. BRANCHING into 3 exploration paths: minimal, clean, pragmatic.",
  "thoughtNumber": 1,
  "totalThoughts": 8,
  "nextThoughtNeeded": true,
  "hypothesis": "Three distinct approaches exist; exploration will reveal trade-offs",
  "confidence": "medium"
}
```

**Purpose:** Establish the decision context and spawn three parallel exploration branches.

**Key Outputs:**
- Clear problem statement
- Constraints from codebase patterns
- Quality dimensions to optimize
- Branch definitions

---

### T7b_BRANCH_MINIMAL

```json
{
  "thought": "BRANCH: Minimal Change. APPROACH: Smallest footprint modification. COMPONENTS: [files to modify]. PROS: Low risk, fast. CONS: May accumulate tech debt. PROBABILITY: 0.85.",
  "thoughtNumber": 2,
  "totalThoughts": 8,
  "nextThoughtNeeded": true,
  "branchFromThought": 1,
  "branchId": "minimal",
  "hypothesis": "Minimal approach viable if {conditions}",
  "confidence": "high"
}
```

**Purpose:** Explore the minimal-change path in isolation.

**Branch Parameters:**
- `branchFromThought: 1` - Branches from the FRAME step
- `branchId: "minimal"` - Names this branch for later reference

---

### T7c_BRANCH_CLEAN

```json
{
  "thought": "BRANCH: Clean Architecture. APPROACH: Separation of concerns, dependency injection. COMPONENTS: [new abstractions]. PROS: Maintainability, testability. CONS: Higher upfront cost. PROBABILITY: 0.70.",
  "thoughtNumber": 3,
  "totalThoughts": 8,
  "nextThoughtNeeded": true,
  "branchFromThought": 1,
  "branchId": "clean",
  "hypothesis": "Clean approach requires {scope} refactoring",
  "confidence": "high"
}
```

**Purpose:** Explore the clean architecture path in isolation.

---

### T7d_BRANCH_PRAGMATIC

```json
{
  "thought": "BRANCH: Pragmatic Balance. APPROACH: Trade-off between clean and speed. COMPONENTS: [selective improvements]. PROBABILITY: 0.80.",
  "thoughtNumber": 4,
  "totalThoughts": 8,
  "nextThoughtNeeded": true,
  "branchFromThought": 1,
  "branchId": "pragmatic",
  "hypothesis": "Pragmatic approach balances at {trade-off points}",
  "confidence": "high"
}
```

**Purpose:** Explore a middle-ground approach.

---

### T8_SYNTHESIS (Join)

```json
{
  "thought": "SYNTHESIS: Comparing branches. SCORES: Minimal={M}/5, Clean={C}/5, Pragmatic={P}/5. WINNER: {selected}. RATIONALE: {why}. MERGED ELEMENTS: {best from each}.",
  "thoughtNumber": 5,
  "totalThoughts": 8,
  "nextThoughtNeeded": true,
  "hypothesis": "{selected} is optimal because {rationale}",
  "confidence": "high"
}
```

**Purpose:** Join the branches back together and select the winning approach.

**Key Outputs:**
- Comparative scores per dimension
- Selected approach with rationale
- Merged elements from other branches (optional)

**Note:** After T8_SYNTHESIS, continue with standard T9_COMPONENT_DESIGN and T10_AC_MAPPING using the selected approach.

---

## Group 8: Revision Templates

Revision templates allow updating earlier conclusions when new evidence emerges. Use when Phase 5 ThinkDeep insights contradict Phase 7 risk analysis.

### T-RISK-REVISION

```json
{
  "thought": "REVISION of Risk Prioritization: ThinkDeep identified NEW/DIFFERENT insights. THINKDEEP: {findings}. ORIGINAL: {T-RISK-2_output}. CONFLICTS: [list]. RESOLUTION: Using higher severity. NEW RISKS: {additions}.",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "isRevision": true,
  "revisesThought": 2,
  "hypothesis": "Phase 5 insights update risk; {N} conflicts resolved",
  "confidence": "high"
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
  "thought": "BRANCH: Red Team. ATTACKER PERSPECTIVE: Entry points: {inputs}. Attack vectors: {injections, auth bypass, data exfiltration}. Impact: {breach, disruption, data loss}. OVERLOOKED: {what standard analysis missed}.",
  "thoughtNumber": 2,
  "totalThoughts": 4,
  "nextThoughtNeeded": true,
  "branchFromThought": 1,
  "branchId": "redteam",
  "hypothesis": "Adversarial analysis reveals {N} additional vectors",
  "confidence": "medium"
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
  "thought": "SYNTHESIS: Merging red team findings. NEW ATTACKS: [list]. ADDITIONS TO TEST PLAN: {new security cases}. COVERAGE GAPS CLOSED: [what red team revealed].",
  "thoughtNumber": 3,
  "totalThoughts": 4,
  "nextThoughtNeeded": true,
  "hypothesis": "Red team adds {N} new test cases",
  "confidence": "high"
}
```

**Purpose:** Merge red team findings back into the main test plan.

**Outputs:**
- New attack vectors identified
- Additional security test cases
- Coverage gaps that were previously invisible

---

## Group 10: Agent Output Analysis (TAO Loop)

TAO (Think-Analyze-Output) Loop templates provide structured pause points between MPA agent outputs and decisions. Prevents rushed synthesis and ensures all perspectives are properly considered.

### T-AGENT-ANALYSIS

```json
{
  "thought": "ANALYSIS of MPA outputs. AGENTS: [{list}]. CONVERGENT (all agree): [{list}] - HIGH priority. DIVERGENT (disagree): [{list}] - FLAG for decision. GAPS: [{list}].",
  "thoughtNumber": 1,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "MPA has {N} convergent, {M} divergent findings",
  "confidence": "medium"
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
  "thought": "SYNTHESIS strategy. CONVERGENT: Incorporate directly. DIVERGENT: Present options OR apply adaptive strategy. GAPS: Accept or research. DECISION: Proceeding with {strategy}.",
  "thoughtNumber": 2,
  "totalThoughts": 3,
  "nextThoughtNeeded": true,
  "hypothesis": "Synthesis strategy is {strategy}",
  "confidence": "high"
}
```

**Purpose:** Define how to handle each category of findings.

**Strategies by Category:**
- **Convergent:** Direct incorporation (no user decision needed)
- **Divergent:** Present options to user OR apply adaptive strategy (SELECT_AND_POLISH, FULL_SYNTHESIS)
- **Gaps:** Accept as known unknowns OR trigger research agent

---

### T-AGENT-VALIDATION

```json
{
  "thought": "VALIDATION: [ ] All requirements addressed? [ ] Trade-offs documented? [ ] Risks identified? [ ] No unresolved conflicts? RESULT: {PASS/FAIL}.",
  "thoughtNumber": 3,
  "totalThoughts": 3,
  "nextThoughtNeeded": false,
  "hypothesis": "Synthesis ready for next phase",
  "confidence": "high"
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
  "thought": "EXTENSION: Complexity exceeds initial estimate. REASON: {unexpected_complexity}. ADDING {N} more thoughts for: {additional_analysis_needed}.",
  "thoughtNumber": 8,
  "totalThoughts": 10,
  "nextThoughtNeeded": true,
  "needsMoreThoughts": true,
  "hypothesis": "Additional analysis needed for {reason}",
  "confidence": "medium"
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
3. Setting appropriate `confidence` levels

### MCP Invocation Pattern

For each template step, invoke Sequential Thinking:

```javascript
mcp__sequential-thinking__sequentialthinking({
  thought: "Step X/Y: {filled template content}",
  thoughtNumber: X,
  totalThoughts: Y,
  nextThoughtNeeded: X < Y,
  hypothesis: "{current hypothesis}",
  confidence: "{exploring|low|medium|high}"
})
```

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
| code-explorer | T4-T6 | Codebase analysis |
| software-architect | T7-T10, T7a-T8 (Fork-Join) | Architecture design |
| tech-lead | T1-T3, T11-T13 | Decomposition and risk |
| orchestrator | T14-T16, T-AGENT series | Validation and synthesis |
| qa-strategist | T-RISK-1 to T-RISK-3, T-RISK-REVISION, T-RISK-REDTEAM series | Test risk analysis (Phase 7) |
| qa-security | T-RISK-1, T-RISK-2, T-RISK-REDTEAM | Security-focused test planning |
| qa-performance | T-RISK-1, T-RISK-2 | Performance-focused test planning |

### ST Feature Availability by Mode

| Template Group | Rapid | Standard | Advanced | Complete |
|----------------|-------|----------|----------|----------|
| Problem Decomposition (T1-T3) | ❌ | ❌ | ❌ | ✅ |
| Codebase Analysis (T4-T6) | ❌ | ❌ | ❌ | ✅ |
| Architecture Design (T7-T10) | ❌ | ❌ | ❌ | ✅ |
| Fork-Join (T7a-T8) | ❌ | ❌ | ❌ | ✅ |
| Risk Assessment (T11-T13) | ❌ | ❌ | ❌ | ✅ |
| Plan Validation (T14-T16) | ❌ | ❌ | ❌ | ✅ |
| Test Risk Analysis (T-RISK-1 to T-RISK-3) | ❌ | ❌ | ✅ | ✅ |
| Revision (T-RISK-REVISION) | ❌ | ❌ | ✅ | ✅ |
| Red Team (T-RISK-REDTEAM) | ❌ | ❌ | ✅ | ✅ |
| TAO Loop (T-AGENT series) | ❌ | ✅ | ✅ | ✅ |
| Dynamic Extension (T-EXTENSION) | ❌ | ❌ | ❌ | ✅ |

---

## Quality Criteria

Each Sequential Thinking step should:
1. **Be grounded** - Reference actual code/docs, not hallucinations
2. **Be actionable** - Lead to concrete outputs
3. **Build on previous** - Reference findings from earlier steps
4. **Include confidence** - Honest assessment of certainty level
5. **Document unknowns** - Explicitly mark areas needing clarification
