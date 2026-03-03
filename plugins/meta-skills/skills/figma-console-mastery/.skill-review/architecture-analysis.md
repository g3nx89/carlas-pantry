---
lens: "Architecture & Coordination Quality"
lens_id: "architecture"
skill_reference: "sadd:multi-agent-patterns"
target: "figma-console-mastery"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery"
fallback_used: false
findings_count: 10
critical_count: 0
high_count: 2
medium_count: 4
low_count: 2
info_count: 2
---

# Architecture & Coordination Quality Analysis: figma-console-mastery

## Summary

The figma-console-mastery skill implements a well-designed supervisor/orchestrator pattern with Sonnet subagent delegation, file-based coordination via operation journals, and a three-tier access model for state resolution. The architecture is appropriate for the complexity of multi-screen Figma design workflows, with strong context isolation, explicit convergence checks, and robust crash recovery. The primary architectural concerns center on information flow gaps between the two flows (Design Session vs Handoff QA), potential supervisor context accumulation in complex sessions, and a coordination model mismatch between the SKILL.md flow definitions and the convergence-protocol.md delegation architecture which references a different (legacy) phase numbering scheme.

---

## Findings

### Finding 1: Convergence Protocol Phase Numbering Misalignment with SKILL.md Flows

**Severity**: HIGH
**Category**: Information flow between components

**Current state**: SKILL.md defines two flows with 4 phases each:
- Flow 1 (Design Session): Phase 1 Preflight, Phase 2 Analysis, Phase 3 Execution, Phase 4 Validation
- Flow 2 (Handoff QA): Phase 1 Inventory, Phase 2 Audit, Phase 3 Mod-Audit-Loop, Phase 4 Readiness

However, `convergence-protocol.md` Section 4 (Subagent Delegation Model) defines a completely different phase structure with Phases 0-5 (Phase 0 Inventory, Phase 1 Component Builder, Phase 2 Per-Screen Pipeline, Phase 3 Prototype Wiring, Phase 4 Annotation, Phase 5 Validation). The delegation architecture diagram does not correspond to either Flow 1 or Flow 2 as defined in SKILL.md.

The journal entry `phase` field uses numeric values that map to the convergence-protocol phases, not the SKILL.md phases. When a subagent logs `"phase": 2`, it is ambiguous whether this refers to Flow 1 Phase 2 (Analysis & Planning) or the convergence-protocol Phase 2 (Per-Screen Pipeline).

**Recommendation**: Reconcile the phase numbering. The convergence-protocol Section 4 appears to document a legacy workflow (possibly the "Draft-to-Handoff" workflow now owned by the `design-handoff` skill). Either:
1. Rewrite Section 4 to document delegation patterns for Flow 1 and Flow 2 as defined in SKILL.md, with phase numbers matching SKILL.md, or
2. Explicitly namespace the phase field in journal entries (e.g., `"phase": "flow1:3"` or `"flow": 1, "phase": 3`) to eliminate ambiguity.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/convergence-protocol.md` (Section 4)

---

### Finding 2: Supervisor Context Accumulation Risk in Flow 2 Phase 3 (Mod-Audit-Loop)

**Severity**: HIGH
**Category**: Bottleneck identification

**Current state**: In Flow 2 Phase 3, for each screen with deviations, the main context (orchestrator):
1. Receives audit results from the Phase 2 subagent
2. Presents findings to user and collects approval
3. Dispatches a Modification subagent
4. Receives modification results
5. Dispatches an Audit subagent (separate dispatch)
6. Receives re-audit results
7. Evaluates pass/fail
8. Loops up to 3 times per screen

For a 10-screen project where most screens need fixes, the orchestrator accumulates results from up to 60 subagent dispatches (10 screens x 3 iterations x 2 subagents per iteration) plus user interaction context for each screen. This is precisely the "supervisor bottleneck" failure mode described in the multi-agent-patterns lens: the supervisor accumulates context from all workers, becoming susceptible to saturation and degradation.

**Recommendation**: Implement a summary-as-context-bus pattern. After each screen's mod-audit-loop completes, the orchestrator should write a per-screen summary to `specs/figma/audits/{screen-name}-loop-summary.md` and then discard the detailed subagent results from working memory. Before dispatching the next screen's loop, load only the summary, not the full history. Additionally, consider delegating the entire per-screen mod-audit-loop to a single subagent that handles the fix-audit cycle internally, reducing orchestrator round trips from 6 per iteration to 1 per screen.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/flow-procedures.md` (Section 2.3)

---

### Finding 3: No Output Validation Contract Between Phase 3 and Phase 4 in Flow 1

**Severity**: MEDIUM
**Category**: Output validation between stages

**Current state**: Flow 1 Phase 3 (Execution) dispatches a Sonnet subagent that logs operations to the per-screen journal. Phase 4 (Validation) then dispatches a separate Sonnet subagent for quality audit. However, there is no explicit contract defining what Phase 3 must produce for Phase 4 to consume. The flow-procedures say Phase 4 subagent loads `quality-dimensions.md` and "captures screenshot," but there is no pre-condition check that Phase 3 actually completed successfully, no required artifact list that Phase 3 must write, and no schema for what the orchestrator validates before dispatching Phase 4.

By contrast, the convergence-protocol Section 4 (legacy delegation model) defines explicit per-screen validation gates: "childCount > 0, instance_count > 0, diff_score within threshold." This rigor is absent from the Flow 1 and Flow 2 phase transitions.

**Recommendation**: Add explicit inter-phase contracts. Define what each phase must write (artifacts, journal entries, session state fields) and what the orchestrator validates before dispatching the next phase. For example:
- Phase 3 must log a `phase_complete` entry with `screens_modified`, `operations_count`, `errors_count`
- Orchestrator checks: `errors_count == 0` (or user-approved errors) before dispatching Phase 4
- Phase 4 subagent prompt includes expected artifact paths from Phase 3

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/flow-procedures.md` (Sections 1.3, 1.4)

---

### Finding 4: Dual-Subagent Pattern in Flow 2 Phase 3 Creates Unnecessary Coordination Overhead

**Severity**: MEDIUM
**Category**: Agent/component specialization justification

**Current state**: Flow 2 Phase 3 dispatches two separate subagents per iteration per screen:
1. A "Modification subagent" that applies fixes
2. An "Audit subagent (separate dispatch)" that re-audits

This separation is described in `flow-procedures.md` Section 2.3 with the note "Sonnet, separate dispatch." The rationale appears to be preventing the modification subagent from self-grading its own work (a sycophancy/bias concern).

However, this creates coordination overhead: the orchestrator must marshal context between two subagents (passing the audit report to the modifier, then passing the modified state to the auditor), multiplied by up to 3 iterations per screen. For a skill that already uses file-based coordination (journals, audit reports), the anti-sycophancy benefit is marginal because both subagents are the same model (Sonnet) with similar system prompts, just different reference files loaded.

**Recommendation**: Evaluate whether a single subagent per iteration (fix then self-audit) with a structured scoring rubric produces equivalent quality. If the dual-subagent pattern is retained for anti-sycophancy reasons, document this rationale explicitly in flow-procedures.md. If quality testing shows no significant difference, consolidate to a single subagent per iteration to halve dispatch overhead.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/flow-procedures.md` (Section 2.3)

---

### Finding 5: Session Index Validation Gap for Cross-Subagent Mutations

**Severity**: MEDIUM
**Category**: Failure propagation and recovery

**Current state**: The session-index-protocol specifies that subagents are read-only consumers of the Session Index (Section "Subagent Responsibilities": "subagents never build or modify the index"). The orchestrator validates freshness at phase boundaries via C9. However, within Flow 1 Phase 3, a subagent creates new Figma nodes (frames, components, instances). These new nodes are not in the Session Index. If Phase 4's validation subagent uses the Session Index for name-to-ID lookups on these newly created nodes, the lookup will miss and fall back to L3.

While the miss-handling procedure (fall back to L3) prevents outright failure, it silently degrades performance. The protocol states "consider whether the index needs rebuilding" on miss, but a subagent cannot rebuild the index (read-only rule), so this creates an unresolvable situation within the subagent.

**Recommendation**: Add an explicit index refresh step between Phase 3 and Phase 4 in the orchestrator flow. After Phase 3 subagent completes, the orchestrator should either (a) rebuild the Session Index, or (b) append new node entries to the index from Phase 3's journal entries (a lightweight incremental update without a full `figma_get_file_data` call). Document the incremental update pattern in session-index-protocol.md.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/session-index-protocol.md` (Subagent Integration section)

---

### Finding 6: No Explicit Failure Propagation Model for Flow 1

**Severity**: MEDIUM
**Category**: Failure propagation and recovery

**Current state**: SKILL.md and flow-procedures.md describe the happy path for Flow 1 phases but do not define what happens when a subagent fails mid-phase. The convergence-protocol Section 6 (Compact Recovery Protocol) handles context compaction recovery, and Section 4 Delegation Rule D5 states "Failed subagent = retry once, then escalate to user." However, D5 is part of the legacy phase structure (Phases 0-5), not the Flow 1/Flow 2 structure.

Flow 1's flow-procedures.md does not address:
- What if the Phase 3 Execution subagent crashes partway through creating a screen?
- What if Phase 4 Validation subagent scores a "fail" but the fix cycle is not defined for Flow 1 (only Flow 2 has the explicit mod-audit-loop)?
- What constitutes a "fail" in Phase 4 vs a "conditional pass" for Flow 1?

For Phase 4, flow-procedures.md Section 1.4 states: "If fail or conditional_pass: targeted fix cycle (max 2 iterations per screen)" and "Main context reviews findings, decides whether to proceed or loop back to Phase 3." But the looping mechanics (who dispatches the fix, where the fix subagent reads its scope, how the loop counter is tracked) are not specified.

**Recommendation**: Add a failure handling subsection to flow-procedures.md Sections 1.3 and 1.4 that specifies:
1. Subagent crash recovery: orchestrator reads journal, determines completed operations, dispatches new subagent for remaining work (mirroring D5 but explicitly for Flow 1 phases)
2. Phase 4 fix cycle mechanics: who dispatches the fix subagent, what references it loads, how the iteration counter is tracked (in session-state.json or in-memory), and the escalation path
3. Pass/fail/conditional_pass thresholds (numeric or rule-based) that the orchestrator uses to make the loop-or-proceed decision

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/flow-procedures.md` (Sections 1.3, 1.4)

---

### Finding 7: Subagent Prompt Template Stale Phase References

**Severity**: LOW
**Category**: Information flow between components

**Current state**: The Subagent Prompt Template in convergence-protocol.md Section 4 includes phase-specific reference loading instructions:

```
{Additional references by phase:}
  Phase 1 (components): + recipes-components.md ...
  Phase 2 (screens):    + recipes-components.md ...
  Phase 3 (wiring):     + (none additional)
  Phase 4 (annotations): + (none additional)
  Phase 5 (validation):  + anti-patterns.md ...
```

These phase numbers and descriptions (components, screens, wiring, annotations) do not match either Flow 1 or Flow 2 phase definitions. An orchestrator following SKILL.md's Flow 1 Phase 3 (Execution) would need to mentally map to the convergence-protocol's guidance, but there is no mapping table.

**Recommendation**: Either update the phase-specific reference loading table to match Flow 1 and Flow 2 phase definitions, or add a mapping table that explicitly connects "Flow 1 Phase 3 Execution" to the relevant reference loading guidance.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/convergence-protocol.md` (Section 4, Subagent Prompt Template)

---

### Finding 8: Journal Schema Lacks Flow Identifier

**Severity**: LOW
**Category**: Information flow between components

**Current state**: Journal entries include a `phase` field (numeric) but no `flow` field. If a user runs Flow 1 (Design Session) and later Flow 2 (Handoff QA) on the same file without archiving journals, the journal entries from both flows intermingle. Phase 1 entries from Flow 1 (Preflight) and Phase 1 entries from Flow 2 (Screen Inventory) would be indistinguishable.

The journal lifecycle section (convergence-protocol.md Section 1) describes archiving between workflows, but this relies on the user or orchestrator remembering to archive. If they do not, convergence checks could match operations from a different flow.

**Recommendation**: Add an optional `flow` field to the journal entry schema (e.g., `"flow": "design-session"` or `"flow": "handoff-qa"`). This provides flow-level discrimination without breaking backward compatibility (existing entries without the field are treated as pre-flow-era). Update convergence check patterns to include flow filtering when both flows have been used on the same file.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/convergence-protocol.md` (Section 1, Entry Format)

---

### Finding 9: Appropriate Use of File-Based Coordination Bus

**Severity**: INFO
**Category**: Coordination pattern appropriateness

**Current state**: The skill uses the file system as the primary coordination mechanism between the orchestrator and subagents. The operation journal (JSONL), session state (JSON), session index (JSONL), and audit reports (Markdown) form a comprehensive file-based shared memory layer. This aligns directly with the multi-agent-patterns recommendation: "Use file-based communication as the default for Claude Code multi-agent patterns."

The three-tier access model (L1 native tools, L2 session index, L3 deep queries) provides a well-structured hierarchy for state resolution that minimizes unnecessary MCP round trips.

This is a textbook implementation of the "Files as Shared Memory" pattern from the lens criteria.

---

### Finding 10: Strong Context Isolation Through Per-Screen Journal Partitioning

**Severity**: INFO
**Category**: Bottleneck identification (positive)

**Current state**: The skill partitions operation journals per screen (`specs/figma/journal/{screen-name}.jsonl`) rather than using a monolithic journal. This means each subagent loads only the journal relevant to its assigned screen, achieving context isolation at the data level in addition to the process level.

The convergence-protocol explicitly states: "Subagents receive only the journal for their assigned screen (context reduction)." Combined with the journal compaction mechanism (triggered at 100 entries per screen), this prevents the journal itself from becoming a context bottleneck even in large workflows.

The cross-screen journal (`_cross-screen.jsonl`) with per-screen back-references is an elegant solution for operations that span multiple screens without polluting individual screen journals.

---

## Strengths

### Strength 1: Comprehensive Anti-Regression System

The convergence protocol with its 9 rules (C1-C9), mandatory pre-operation checks, and append-only journal design creates a robust anti-regression system that survives context compaction. This directly addresses the most critical failure mode in long-running Figma sessions. The batch scripting protocol adds a second layer of idempotency within scripts themselves (`already_done` checks), creating defense in depth against regression.

### Strength 2: Appropriate Supervisor Pattern with Lightweight Inline Exceptions

The skill correctly identifies that Phase 1 (Preflight) is lightweight enough to run inline in the main context, avoiding dispatch overhead for simple read-only operations. This follows the multi-agent-patterns guidance: "Start simple -- add multi-agent complexity only when single-agent approaches fail." The escalation from inline (1-4 screens) to per-screen delegation (5+ screens) based on workflow size is a pragmatic adaptation of the supervisor pattern.

### Strength 3: Selective Reference Loading Tiered System

The three-tier reference loading system (Always / By task / By need) prevents context pollution by ensuring subagents load only the references relevant to their specific phase and mode. This is a practical implementation of context isolation at the knowledge level, complementing the process-level isolation of subagent dispatch and the data-level isolation of per-screen journals.

### Strength 4: User Interaction Protocol with Explicit Discussion Option

The mandatory "Let's discuss this" option in every `AskUserQuestion` and the D7 rule ("Subagents NEVER interact with users") creates a clean human-in-the-loop boundary. The orchestrator serves as the sole user interaction point, which is a key advantage of the supervisor pattern -- it centralizes human oversight without distributing user-facing responsibilities across subagents.
