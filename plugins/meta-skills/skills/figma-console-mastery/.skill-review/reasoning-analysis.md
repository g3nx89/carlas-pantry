---
lens: "Reasoning & Decomposition Quality"
lens_id: "reasoning"
skill_reference: "customaize-agent:thought-based-reasoning"
target: "figma-console-mastery"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery"
fallback_used: true
findings_count: 11
critical_count: 0
high_count: 2
medium_count: 5
low_count: 2
info_count: 2
---

# Reasoning & Decomposition Quality Analysis: figma-console-mastery

## Summary

The figma-console-mastery skill demonstrates strong reasoning architecture overall. It employs multiple advanced reasoning methodologies (TAO Loop, Fork-Join, Checkpoint, Reflexion-style revision) through its Sequential Thinking integration, and structures complex problems into well-defined phases with explicit gates. The convergence protocol is a standout example of verification-driven reasoning, and the quality model's multi-judge Deep Critique follows a sound multi-perspective decomposition.

The primary gaps are: (1) several critical decision points within the main SKILL.md rely on implicit judgment rather than explicit criteria, (2) the Socratic Protocol phase lacks termination criteria and convergence detection, and (3) the fix cycle loops have bounded iteration counts but lack explicit reasoning about *why* a fix failed before retrying, risking mechanical retry without learning. The skill would also benefit from making the mode selection reasoning chain explicit when user intent is ambiguous.

---

## Findings

### F1: Mode Selection Relies on Pattern Matching Without Ambiguity Resolution

**Severity**: HIGH
**Category**: Decision framework clarity
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md`

**Current state**: The Mode Selection table (lines 62-67) maps user intent strings to modes:

```
| "Create a design" / "Build a screen" | Create | ...
| "Restructure this design"            | Restructure | ...
| "Check/fix this frame"               | Audit | ...
| "Create components" / "Setup tokens" | Targeted | ...
```

This is a direct string-match table with no reasoning chain for ambiguous requests. A user saying "clean up this design and add components" could match Create, Restructure, or Targeted. There is no decision tree, no tie-breaking logic, and no instruction to ask the user when intent is ambiguous.

**Recommendation**: Add an explicit disambiguation protocol below the mode table:
1. If user intent matches exactly one mode, select it.
2. If user intent spans 2+ modes, present the top 2 candidates to the user with `AskUserQuestion`, explaining what each mode would do differently.
3. If no mode matches, default to Audit (lowest risk) and confirm with the user.

This aligns with the skill's own P3 principle ("Explicit User Interaction") but is not operationalized at this decision point.

---

### F2: Socratic Protocol Phase Lacks Convergence Detection and Termination Criteria

**Severity**: HIGH
**Category**: Anti-patterns (missing termination criteria)
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md`

**Current state**: Phase 2 (Analysis & Planning) states:

> "Expanded Socratic Protocol with 11 categories (Cat. 0-10). [...] Do NOT proceed to Phase 3 until user approves checklist." (line 73)

The only termination criterion is user approval. However, there is no guidance on:
- How many questions per category is sufficient
- When to stop asking follow-up questions (convergence detection)
- What constitutes a "complete" checklist for user approval
- How to handle users who want to skip categories
- Maximum number of Socratic rounds before declaring "sufficient"

This creates risk of either: (a) the agent asking too many questions (user fatigue), or (b) skipping categories and producing an incomplete plan.

**Recommendation**: Add explicit convergence criteria to the Socratic phase:
1. Define minimum coverage: at least 1 question answered per applicable category.
2. Define convergence signal: when 2 consecutive questions in a category yield no new design decisions, mark category as "converged."
3. Define skip protocol: user can say "skip" for any category; log the skip in the checklist as "User deferred."
4. Define maximum rounds: cap at 3 rounds per category (initial + 2 follow-ups) before auto-converging.
5. Present the completeness state to the user: "8/11 categories covered, 3 skipped. Ready to proceed?"

---

### F3: Fix Cycle Retries Without Root Cause Analysis

**Severity**: MEDIUM
**Category**: Verification and self-correction mechanisms
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/quality-procedures.md`

**Current state**: The Mod-Audit-Loop (Section 6, lines 366-382) specifies:

```
LOOP (max N iterations):
  1. Dispatch Modification Subagent with issue list
  2. Subagent applies fixes
  3. Re-run audit
  4. Compare scores
  5. If unchanged or worse -> escalate
  6. If iteration >= N -> escalate
```

The loop mechanically retries the same fix pattern without requiring the subagent to reason about *why* the previous fix attempt failed or was insufficient. This is a classic "retry without learning" anti-pattern. If a D4 auto-layout fix fails twice, the third attempt with the same approach will also fail.

**Recommendation**: Insert a mandatory root cause analysis step between retry iterations:

```
4b. If fixed dimensions unchanged or regressed:
    - Subagent must produce a "Fix Failure Analysis": what was attempted, what the actual result was, and a hypothesis for why it failed
    - Next iteration MUST use a different approach based on the hypothesis
    - Log the failure analysis in the journal as op: "fix_failure_analysis"
```

This transforms the loop from mechanical retry into a Reflexion-style pattern where each iteration learns from the previous failure.

---

### F4: Decision Matrix G0-G3 Has No Explicit Reasoning for Borderline Cases

**Severity**: MEDIUM
**Category**: Decomposition of complex problems
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md`

**Current state**: The Decision Matrix (lines 94-102) defines five gates:

```
G0: Exists? -> INSTANTIATE
G1a: Native batch? -> NATIVE-BATCH
G1b: Native modify? -> NATIVE-MODIFY
G2: Simple? -> EXECUTE-SIMPLE
G3: Complex? -> EXECUTE-BATCH
```

The gates are evaluated in order (G0->G1a->G1b->G2->G3), which is a correct Least-to-Most decomposition. However, the boundary between G2 ("Single-node create, complex fill, layout") and G3 ("Multi-step, batch 3+ same-type") is quantitative (3+ nodes) but does not address cases like: 2 nodes that require complex interdependent operations, or 4 nodes with trivially independent operations. The "complexity" dimension conflates node count with operational dependency.

**Recommendation**: Refine the G2/G3 boundary with two orthogonal criteria:
1. **Node count**: 1-2 nodes = G2, 3+ nodes = G3 (current)
2. **Dependency**: If operations on multiple nodes depend on each other's results (e.g., parent must exist before child), treat as sequential G2 calls regardless of count. If independent, batch via G3.

Add a brief decision note: "When in doubt between G2 and G3, prefer G3 (batch) — the idempotency checks in batch scripts make them safe for small counts."

---

### F5: Deep Critique Contradiction Resolution Delegates to a 5th Subagent Without Structured Reasoning

**Severity**: MEDIUM
**Category**: Reasoning methodology selection
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/quality-procedures.md`

**Current state**: In the Deep Critique coordinator synthesis (Section 3, lines 111-114):

```
5. If contradictions exist:
   - Determine which judge has stronger evidence
   - Run mini-debate: present both judge findings to a 5th Sonnet subagent, ask for arbitration
   - Accept arbitrator's ruling
```

The arbitration step dispatches a 5th subagent but provides no structured framework for how the arbitrator should reason. "Ask for arbitration" is underspecified. The arbitrator could rubber-stamp either judge without genuine reasoning. There is no requirement for the arbitrator to explain its reasoning chain, cite specific evidence, or address both sides of the contradiction.

**Recommendation**: Add a structured arbitration prompt template requiring:
1. The arbitrator must restate both positions with their evidence.
2. The arbitrator must identify which evidence is more authoritative (e.g., node ID inspection > screenshot interpretation > journal inference).
3. The arbitrator must produce a chain-of-thought explanation before the ruling.
4. The ruling must include a confidence level (high/medium/low) — if low, escalate to user rather than accepting.

---

### F6: ST Integration Templates Mix Concrete and Positional Placeholders

**Severity**: MEDIUM
**Category**: Explicit step-by-step logic
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/st-integration.md`

**Current state**: The Visual Fidelity Loop template (lines 263-264) uses positional placeholders:

> `"thoughtNumber": "N"` and `"totalThoughts": "T"` below are positional markers -- replace with actual integers at runtime

Meanwhile, other templates (Phase 1 Analysis, Path A/B Fork-Join) use concrete integers. This inconsistency creates an implicit reasoning requirement: the implementer must determine the correct integer values for N and T based on context, but no formula or heuristic is provided for calculating them.

**Recommendation**: Provide a calculation heuristic alongside the positional markers:
- `N` = (parent chain's current thought number at the point where fidelity check is inserted)
- `T` = (parent chain's current totalThoughts + 2 per fidelity check cycle expected)
- Add a note: "If uncertain, use `needsMoreThoughts: true` on the first fidelity thought to let the ST server extend the chain dynamically."

---

### F7: Convergence Protocol Compact Recovery Lacks Conflict Resolution Reasoning

**Severity**: MEDIUM
**Category**: Verification and self-correction mechanisms
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/convergence-protocol.md`

**Current state**: Compact Recovery Step 3 (line 625-626) says:

```
Step 3 -- Verify Figma state
- figma_get_status -> confirm connection
- figma_execute: figma.currentPage.children.map(...) -> confirm nodes match journal
```

"Confirm nodes match journal" is an implicit verification step. There is no explicit procedure for what to do when nodes do NOT match the journal (e.g., external user edited the Figma file during compact, a subagent's mutation was partially applied). The only related guidance is C7 ("When in doubt, verify via Figma"), but C7 describes a general principle, not the specific conflict resolution chain needed during compact recovery.

**Recommendation**: Add an explicit mismatch resolution procedure to Step 3:

```
Step 3b -- If mismatch detected:
  a. Classify mismatch: MISSING (journal says created, node absent), EXTRA (node exists, no journal entry), MODIFIED (node properties differ from journal's last entry)
  b. For MISSING: log as "external_deletion" in journal, remove from pending ops
  c. For EXTRA: log as "external_addition" in journal with current properties
  d. For MODIFIED: compare journal's intended state vs current state; if journal state is superseded (user intentionally changed), log "external_override"; if journal state should be restored, add to pending ops
  e. After classification, present summary to user if >3 mismatches
```

---

### F8: Subagent Prompt Template Has No Reasoning Preamble

**Severity**: LOW
**Category**: Reasoning methodology selection
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/convergence-protocol.md`

**Current state**: The Subagent Prompt Template (lines 421-476) provides context, mandatory rules, and scope. It does not include any guidance on *how* the subagent should reason about its task. Subagents receive a list of 15 mandatory rules and are expected to follow them, but there is no instruction to plan before acting, verify after acting, or decompose complex steps.

**Recommendation**: Add a brief reasoning preamble to the subagent prompt template:

```
## Approach
Before starting work:
1. Read journal and identify completed operations (convergence check)
2. Plan the sequence of remaining operations for this scope
3. For each operation: verify preconditions, execute, verify postconditions, log
```

This is lightweight (3 lines) but makes the ReAct pattern explicit for subagents rather than relying on their implicit reasoning ability.

---

### F9: Flow 2 Handoff QA Phase 3 Loop Bound Not Contextualized

**Severity**: LOW
**Category**: Anti-patterns (circular logic potential)
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md`

**Current state**: Flow 2, Phase 3 (line 89):

> "Mod-Audit-Loop | Fix -> re-audit -> loop (max 3/screen)"

The max 3 iteration bound is stated but not contextualized with what happens after exhaustion. The quality-procedures.md (line 384) clarifies: "Spot = 3, Standard = 2, Deep = 0 (advisory only)" and the escalation path. However, in SKILL.md itself, the reader has no indication of the escalation path, creating an implicit reasoning gap for anyone reading only the main skill file.

**Recommendation**: Add a parenthetical to the Flow 2 Phase 3 description: "Fix -> re-audit -> loop (max 3/screen; escalate to user if still failing after max iterations)."

---

### F10: ST Activation Conditions Create a Clear Decision Tree

**Severity**: INFO
**Category**: Decision framework clarity (positive observation)
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/st-integration.md`

**Current state**: The Session Protocol Mapping (lines 618-633) and Suppress Conditions (lines 21-26) together form a well-structured decision tree for when to activate Sequential Thinking. Notably, the suppress conditions prevent over-application of ST in simple cases, which is a mature anti-pattern avoidance technique.

The activation triggers are quantitative (e.g., "3+ categories," "3+ decision points," ">5 ambiguous flags") rather than qualitative, making them unambiguous and reproducible.

---

### F11: CoV Self-Verification in Quality Audit Is a Strong Reflexion Pattern

**Severity**: INFO
**Category**: Verification and self-correction mechanisms (positive observation)
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/st-integration.md`

**Current state**: The Reflection Quality Assessment template (Thought 6, lines 580-588) implements Chain of Verification (CoV):

```json
"thought": "CoV SELF-VERIFICATION: Q1: Did I check all screens or only a sample for D1? A: {answer}. Q2: Is low D2 justified by absence of token system? A: {answer}. Q3: Are D6 individual calls justified debugging fallbacks? A: {answer}. Adjustments: {adjustments_or_none}."
```

This is a textbook Reflexion implementation: the model generates verification questions about its own prior reasoning, answers them, and adjusts scores if warranted. The questions are domain-specific and target common scoring biases (sampling bias in Q1, context-dependent grading in Q2, exception handling in Q3).

Similarly, each judge template includes a "Self-verification" section with 3-5 bias-checking questions, ensuring multi-perspective self-correction across the Deep Critique pipeline.

---

## Strengths

### S1: Sophisticated Multi-Methodology Reasoning Integration

The skill integrates five distinct reasoning methodologies in contextually appropriate ways:
- **TAO Loop** (Think-Act-Observe) for interleaved reasoning and tool calls — used in Phase 1 analysis, quality audits, and naming audits
- **Fork-Join** for parallel evaluation of competing alternatives — used in Path A/B decisions
- **Checkpoint** for phase boundary verification — used in Design System Bootstrap
- **Revision** (Reflexion-style) for self-correction when observations contradict predictions — used in Visual Fidelity Loop and quality assessment
- **Circuit Breaker** for termination of unbounded loops — applied consistently at 3 fix cycles and 15 ST steps

These are not merely listed as options but are mapped to specific workflow triggers with quantitative activation criteria, demonstrating a Least-to-Most decomposition of the reasoning methodology selection problem itself.

### S2: Convergence Protocol as Durable Verification Infrastructure

The convergence protocol (`convergence-protocol.md`) is an exceptional example of verification-driven reasoning design. Nine convergence rules (C1-C9) form a complete verification framework that survives context compaction, the primary failure mode for long-running LLM workflows. The protocol addresses the fundamental problem of LLM reasoning: that in-context "memory" is unreliable and ephemeral. By externalizing the verification state to an append-only journal, the skill converts an unreliable reasoning substrate into a reliable one.

The idempotency checks embedded in batch scripts (e.g., `if (node.name === r.name) { status: "already_done" }`) provide defense-in-depth: even if the convergence check is somehow bypassed, the operation itself will not regress.

### S3: Quality Model Decomposes a Complex Problem Into Independent Expert Assessments

The 11-dimension quality model with 3+1 judges (Deep Critique) is a well-executed application of decomposition principles. Each judge evaluates independent dimensions with independent data sources, avoiding cross-contamination of reasoning. The coordinator synthesis step then combines results with explicit contradiction detection (>2pt spread threshold) and evidence-based arbitration. The separation of Judge 4 (UX Critic) as advisory-only prevents qualitative judgments from distorting quantitative scores while still surfacing important non-measurable insights.
