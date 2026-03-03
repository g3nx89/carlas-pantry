---
lens: "Overall Effectiveness"
lens_id: "effectiveness"
skill_reference: "customaize-agent:agent-evaluation"
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

# Overall Effectiveness Analysis: figma-console-mastery

## Summary

The figma-console-mastery skill is a remarkably thorough Figma API technique library with clear purpose, well-structured flows, and extensive error coverage. It achieves its stated purpose of enabling Claude to create, manipulate, and validate Figma designs via the figma-console MCP. The skill demonstrates mature patterns born from empirical production usage -- the anti-patterns catalog alone contains 47+ entries with specific recovery paths.

However, effectiveness is constrained by three factors: (1) the sheer volume of reference material (~560KB across 23 files) creates a high cognitive load even with the tiered loading system, (2) some critical decision-making guidance is distributed across files rather than consolidated at the point of need, and (3) the relationship between this skill and the `design-handoff` skill creates boundary ambiguity in several areas that could confuse Claude during execution.

Overall, this skill would be highly effective for a Claude agent that loads references selectively and follows the prescribed flows. The quality model, convergence protocol, and anti-pattern catalog are standout features that would prevent the majority of real-world failures.

---

## Findings

### F1: Scope Boundary with design-handoff Creates Execution Ambiguity

**Severity**: HIGH
**Category**: Instruction-following quality

**Current state**: SKILL.md states at line 4: "For Draft-to-Handoff and Code Handoff preparation workflows, use the design-handoff skill (product-definition plugin) which delegates Figma operations to this skill's references." However, anti-patterns.md contains 15+ entries under "Handoff-Specific Anti-Patterns" (lines 173-202) that describe problems and solutions for Draft-to-Handoff workflows. The flow-procedures.md "Flow 2 -- Handoff QA" (lines 199-309) includes behavioral specification extraction and handoff readiness reporting, which border on manifest preparation territory.

**Recommendation**: Add a short "Boundary Clarification" subsection to SKILL.md (near the "When NOT to Use" section) that explicitly lists which handoff operations belong to this skill (QA, readiness assessment, technique reference) versus which belong to design-handoff (orchestration, manifest generation, screen processing pipeline). Currently Claude must infer the boundary from scattered hints across multiple files.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md`

---

### F2: Reference Loading Tier Assignments May Cause Under-Loading in Practice

**Severity**: HIGH
**Category**: Completeness / Edge cases

**Current state**: SKILL.md lines 212-218 define three loading tiers. `essential-rules.md` is placed in Tier 2 ("By task"), but it contains the full 23 MUST + 14 AVOID rules that SKILL.md itself summarizes as the "Top 8" (lines 121-140). Similarly, `anti-patterns.md` is placed in Tier 3 ("By need"), meaning it would not be loaded during standard execution flows. However, anti-patterns.md contains the Quick Troubleshooting Index (37 entries) that would prevent the most common failures during Phase 3 execution.

A Sonnet subagent dispatched for Phase 3 execution loads "Required: `recipes-foundation.md`, `convergence-protocol.md`" (flow-procedures.md line 168) but NOT `essential-rules.md` or `anti-patterns.md`. This means the subagent doing the actual Figma mutations may not have access to the full rule set or the troubleshooting index.

**Recommendation**: Either (a) promote `essential-rules.md` to Tier 1 ("Always"), since it is the authoritative rule set, or (b) add explicit subagent loading instructions in flow-procedures.md Section 1.3 that include `essential-rules.md` in the "Required" list for Phase 3 subagents. The anti-patterns file is large enough that Tier 3 placement is defensible, but a note should be added to flow-procedures.md recommending it for debugging scenarios.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (lines 212-218) and `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/flow-procedures.md` (lines 166-170)

---

### F3: Quality Dimensions Maintenance Checklist References Stale Dimension Count

**Severity**: MEDIUM
**Category**: Internal consistency

**Current state**: quality-dimensions.md Section 6 "Maintenance Notes" (lines 423-445) includes a checklist titled "Adding a New Dimension" that begins with "When adding dimension D11 (or modifying existing dimensions)". However, D11 (Accessibility Compliance) already exists in the current model (Section 1 table, line 31, and full rubric at lines 302-324). This maintenance note appears to be a leftover from before D11 was added.

**Recommendation**: Update the maintenance note to reference D12 (or "D{N+1}") as the next hypothetical dimension. This prevents confusion about whether D11 is fully integrated.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/quality-dimensions.md` (line 425)

---

### F4: Spot Audit Dimension List Inconsistency Between SKILL.md and quality-dimensions.md

**Severity**: MEDIUM
**Category**: Internal consistency

**Current state**: SKILL.md line 178 states Spot audit covers "3 dimensions (D1 Visual Quality, D4 Auto-Layout, D10 Operational Efficiency)". quality-dimensions.md Section 4 (line 353) confirms the same three dimensions for Spot tier. However, quality-dimensions.md Section 4 Triage Decision Matrix (line 369) says "per-screen pipeline completion" triggers Spot with "D1, D4, D10 only", while flow-procedures.md line 178 says Spot runs "after each screen in Create/Targeted, after each fix in Audit" -- but it does not specify which dimensions.

The inconsistency is minor but flow-procedures.md should explicitly name the Spot dimensions (D1, D4, D10) at the point where it instructs the subagent to run Spot, rather than requiring a cross-reference to quality-dimensions.md.

**Recommendation**: Add "(D1, D4, D10)" parenthetically in flow-procedures.md wherever Spot tier is referenced, to reduce cross-file lookups during execution.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/flow-procedures.md` (lines 176-178)

---

### F5: Max Fix Iteration Count Discrepancy

**Severity**: MEDIUM
**Category**: Internal consistency

**Current state**: SKILL.md line 89 states "Fix -> re-audit -> loop (max 3/screen)" for Flow 2 Phase 3. flow-procedures.md line 269 confirms "max 3 iterations per screen". However, flow-procedures.md line 187 states "max 2 iterations per screen" for Flow 1 Phase 4 validation. quality-dimensions.md Contradiction Resolution #3 (line 395) resolves this as "Max 3 per screen (per-screen fix cycles), max 2 per phase boundary (Standard Audit)."

While this is technically consistent (Flow 1 Phase 4 is a phase boundary, Flow 2 Phase 3 is per-screen), the distinction between "per-screen fix cycle" and "phase boundary" is subtle enough that Claude could apply the wrong limit. The 2-vs-3 distinction is not explained at the point of use in flow-procedures.md.

**Recommendation**: Add a brief parenthetical note in flow-procedures.md at both lines 187 and 269 explaining the rationale: "(max 2 -- phase boundary limit per Contradiction Resolution #3)" and "(max 3 -- per-screen limit)" respectively.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/flow-procedures.md` (lines 187, 269)

---

### F6: Socratic Protocol Category 10 Referenced But Not Defined in flow-procedures.md

**Severity**: MEDIUM
**Category**: Completeness

**Current state**: SKILL.md line 73 states "Expanded Socratic Protocol with 11 categories (Cat. 0-10)". However, flow-procedures.md Section 1.2 (lines 52-134) only defines Categories 0 through 9. Category 10 ("Content & Interaction Specifications") is missing from flow-procedures.md but IS defined in `socratic-protocol.md` (line 241). The "Mode-specific category subsets" (lines 128-131) also omit Category 10 -- neither Create nor Restructure mode lists it.

This means a subagent loading flow-procedures.md for Phase 2 execution would not know Category 10 exists unless it also loads socratic-protocol.md. Since flow-procedures.md is designed to be self-contained for phase execution (per its scope note on line 6), this is a gap.

**Recommendation**: Add Category 10 summary to flow-procedures.md Section 1.2, and add it to the appropriate mode-specific subset (likely Create and/or Restructure). Even a brief entry like "Category 10 -- Content & Interaction Specifications (optional): See socratic-protocol.md" would close the gap.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/flow-procedures.md` (lines 52-134)

---

### F7: "When NOT to Use" Section Could Cover More Edge Cases

**Severity**: MEDIUM
**Category**: Edge case coverage

**Current state**: SKILL.md lines 250-255 list four "When NOT to Use" scenarios: FigJam, REST API/OAuth, Remote SSE mode creation, and full Draft-to-Handoff orchestration. However, several additional important exclusion scenarios are documented in anti-patterns.md "Hard Constraints" section but not surfaced in SKILL.md:

- Cross-file operations (anti-patterns.md line 283)
- Code Connect integration (anti-patterns.md line 284)
- Programmatic IMAGE fill creation from external URLs (anti-patterns.md lines 266-274)
- Figma Make resource retrieval (anti-patterns.md line 286)

**Recommendation**: Expand the "When NOT to Use" section with 2-3 additional entries for the most commonly confused exclusions (especially cross-file operations and IMAGE fill creation from URLs, which are non-obvious limitations).

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (lines 250-255)

---

### F8: Decision Matrix Gate Labels Could Be More Self-Explanatory

**Severity**: LOW
**Category**: Instruction-following quality

**Current state**: SKILL.md lines 94-101 define a Decision Matrix with gates G0-G3. The gate questions are concise but the path labels (INSTANTIATE, NATIVE-BATCH, NATIVE-MODIFY, EXECUTE-SIMPLE, EXECUTE-BATCH) are not explained. Claude would need to infer from the "Primary Tool" column what each path means. For example, "EXECUTE-SIMPLE" maps to "figma_execute with idempotency" but the idempotency requirement is not explained at this level.

**Recommendation**: Add a one-line description after the Decision Matrix table explaining: "Each path name maps to a tool strategy. 'EXECUTE-SIMPLE' means a single `figma_execute` call with idempotency guard (check-before-create). 'EXECUTE-BATCH' means a batched script for 3+ same-type operations." This prevents Claude from treating path labels as opaque tokens.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (after line 101)

---

### F9: Anti-Patterns File Size May Exceed Practical Context Budget

**Severity**: LOW
**Category**: Completeness / Practical effectiveness

**Current state**: anti-patterns.md is 51,311 bytes (~375 lines of dense table content). When loaded into a Sonnet subagent context alongside other required references (recipes-foundation.md at 17,923 bytes, convergence-protocol.md at 37,248 bytes), the combined reference payload approaches 100KB+ before any task-specific content. This risks context pressure on Sonnet subagents, especially during fix cycles where multiple references are needed simultaneously.

**Recommendation**: Consider splitting anti-patterns.md into two files: (a) a "quick-reference" file containing the Quick Troubleshooting Index and Top 5 failures (~100 lines), and (b) the full catalog for deep debugging. The quick-reference file would be appropriate for Tier 2 loading during standard execution, while the full catalog remains Tier 3.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/anti-patterns.md`

---

### F10: Comprehensive Error Recovery Paths

**Severity**: INFO
**Category**: Positive observation

**Current state**: The anti-patterns.md file contains 47+ entries organized into 8 categories (Plugin API errors, connection/transport, session-level, handoff-specific, regression, performance, context/buffer, prototype, grid layout). Each entry includes Cause, Detection method, and Recovery path. The "Full Errors and Recovery Table" (lines 301-319) adds a detection column that other tables lack, providing a practical diagnostic sequence.

This level of error catalog completeness is exceptional. The entries are clearly derived from empirical production failures (references to specific screens like "WK-01, WK-02, WK-03" at line 175), which makes them actionable rather than theoretical.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/anti-patterns.md`

---

### F11: Quality Model Contradiction Resolution is Exemplary

**Severity**: INFO
**Category**: Positive observation

**Current state**: quality-dimensions.md Section 5 "Contradiction Resolutions" (lines 387-402) explicitly enumerates 10 contradictions between predecessor protocols and documents which resolution was chosen and why. For example, Resolution #1 clarifies that "screen root on fixed viewport is a stage, exempt from auto-layout" -- a nuanced decision that would otherwise cause inconsistent scoring.

This pattern of documenting resolved contradictions with explicit winners is a best practice that prevents Claude from encountering conflicting instructions during audit execution. It also serves as institutional memory for future skill maintainers.

**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/quality-dimensions.md` (lines 387-402)

---

## Strengths

### S1: Hub-Spoke Architecture with Selective Loading

The skill follows the lean orchestrator pattern effectively. SKILL.md is 255 lines -- well under the recommended 300-line limit -- and serves as a dispatch table with Quick Start, Decision Matrix, Essential Rules (Top 8), and Selective Reference Loading instructions. The 23 reference files are organized into three loading tiers with clear guidance on when to load each. This architecture enables Claude to operate with minimal context for simple tasks while having access to deep reference material for complex scenarios.

### S2: Empirically-Derived Anti-Pattern Catalog

The anti-patterns and error recovery documentation is clearly sourced from real production failures rather than theoretical enumeration. Entries like "Data lost between figma_execute calls" (line 46 of anti-patterns.md) include specific workarounds (`globalThis.__key = value`) that would only emerge from debugging actual sessions. The "Root cause" annotations (e.g., line 121: "After context compaction, previously learned workarounds are lost and the same errors re-emerge") explain WHY patterns recur, enabling Claude to understand the deeper failure mode rather than just memorizing fixes.

### S3: Multi-Tier Quality Validation Model

The 11-dimension quality model with three depth tiers (Spot/Standard/Deep) is well-calibrated. Spot audits (3 dimensions, ~1K tokens) run inline for quick checks; Standard audits (11 dimensions, ~5K tokens) run as subagents at phase boundaries; Deep audits (11 dimensions + 3-4 parallel judges, ~18K tokens) run at session end. The Triage Decision Matrix (quality-dimensions.md lines 361-376) provides an unambiguous flowchart for determining which tier to use, and the Suppress Conditions (lines 380-383) prevent audits from consuming remaining context when token budgets are tight.

### S4: Convergence and Anti-Regression Protocol

The skill addresses context compaction -- one of the most destructive failure modes in long agentic sessions -- with a structured approach: per-screen journals, session snapshots, idempotent batch scripts, and explicit "trust only the journal" rules (anti-patterns.md lines 205-217). The Regression Anti-Patterns section catalogs 7 specific ways the system can undo its own work, each with a concrete prevention mechanism. This demonstrates deep understanding of the Claude agent runtime's practical limitations.
