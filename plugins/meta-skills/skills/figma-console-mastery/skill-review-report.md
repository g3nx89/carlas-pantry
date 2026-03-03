---
target_skill: "figma-console-mastery"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery"
analysis_date: "2026-02-27"
lenses_applied:
  - "Structure & Progressive Disclosure"
  - "Prompt Engineering Quality"
  - "Context Engineering Efficiency"
  - "Writing Quality & Conciseness"
  - "Overall Effectiveness"
  - "Reasoning & Decomposition"
  - "Architecture & Coordination"
lenses_degraded: ["Prompt Engineering Quality", "Context Engineering Efficiency", "Writing Quality & Conciseness", "Overall Effectiveness", "Reasoning & Decomposition"]
overall_score: "2.9/5.0"
findings_total: 37
findings_critical: 2
findings_high: 11
findings_medium: 17
findings_low: 7
findings_info: 0
---

# Skill Review Report: figma-console-mastery

## Executive Summary

The figma-console-mastery skill (v1.1.0) is a comprehensive Figma API technique library with 256-line SKILL.md and 22 reference files (~75K words). It demonstrates mature architectural patterns — hub-spoke progressive disclosure, file-based coordination, convergence anti-regression, and empirically-derived error catalogs. However, the analysis uncovered 2 CRITICAL and 11 HIGH findings that degrade effectiveness, primarily around **cross-file consistency** (Category 10 missing from flow-procedures.md, flagged by 3 lenses), **context budget** (Tier 1 always-load at ~7,257 words is excessive), and **architectural drift** (convergence-protocol.md retains legacy phase numbering misaligned with current flows). The strongest aspects are the three-tier reference loading architecture, the Decision Matrix routing, and the convergence protocol's anti-regression design.

## Scores by Lens

| Lens | Score | Key Finding |
|------|-------|-------------|
| Structure & Progressive Disclosure | 3/5 | Selective Reference Loading block inflates SKILL.md by ~67 lines of redundant Read paths |
| Prompt Engineering Quality | 3/5 | Category count/mode subset inconsistency between SKILL.md, flow-procedures.md, socratic-protocol.md |
| Context Engineering Efficiency | 2/5 | Tier 1 always-load budget ~7,257 words — convergence-protocol.md has ~3,500 words of execution content |
| Writing Quality & Conciseness | 3/5 | Screenshot tool distinction restated in 5+ locations with slightly different wording |
| Overall Effectiveness | 3/5 | Scope boundary ambiguity between this skill and design-handoff for handoff operations |
| Reasoning & Decomposition | 3/5 | Mode selection relies on pattern matching with no disambiguation for ambiguous intent |
| Architecture & Coordination | 3/5 | Convergence-protocol Phase 0-5 numbering misaligned with SKILL.md Flow 1/Flow 2 phases |

**Overall: 2.9/5.0** — Adequate

Score interpretation:
- 4.5-5.0: Excellent — production-ready, minimal improvements needed
- 3.5-4.4: Good — solid skill with some improvement opportunities
- 2.5-3.4: Adequate — functional but has notable quality gaps
- 1.5-2.4: Needs Work — significant issues affecting effectiveness
- 1.0-1.4: Poor — fundamental problems requiring major revision

## Modification Plan

| # | Priority | Action | File | Section | Effort | Lenses |
|---|----------|--------|------|---------|--------|--------|
| 1 | CRITICAL | Split convergence-protocol.md into convergence-core.md (Tier 1, ~1,400 words: journal + convergence rules) and convergence-execution.md (Tier 2, ~3,500 words: batch scripts, delegation, snapshot, recovery). Reduces Tier 1 by 48%. | references/convergence-protocol.md | All | L | context |
| 2 | CRITICAL | Add Category 10 summary to flow-procedures.md Section 1.2. Update mode-specific subsets: Restructure "0-10", Create add "10 (optional)". Fix socratic-protocol.md header to say "11 categories". | references/flow-procedures.md, references/socratic-protocol.md | SS1.2, Header | M | structure, prompt, effectiveness |
| 3 | HIGH | Restructure Selective Reference Loading: lead with tier classification (currently at bottom), group Read directives by tier with ### headers. Replace flat 67-line list with tier-organized format. | SKILL.md | Selective Reference Loading | M | structure, context |
| 4 | HIGH | Trim frontmatter description to ~60 words: keep trigger phrases, remove architecture details ("2 flows", "subagent-first", "quality model"), remove design-handoff delegation (already in body). | SKILL.md | Frontmatter | S | structure, context, writing |
| 5 | HIGH | Reconcile convergence-protocol.md Section 4 phase numbering with SKILL.md Flow 1/Flow 2. Update subagent prompt template phase-specific references to match current flows. Add `flow` field to journal schema. | references/convergence-protocol.md | Section 4, Section 1 | L | architecture |
| 6 | HIGH | Canonicalize screenshot tool rule in essential-rules.md MUST #6 only. In all other locations (SKILL.md x3, flow-procedures) use terse reminder without re-explaining. Merge AVOID #11 into MUST #6. | references/essential-rules.md, SKILL.md, references/flow-procedures.md | MUST/AVOID rules | M | prompt, writing |
| 7 | HIGH | Add explicit phase transition guards to flow-procedures.md (IF mode IN {Create,Restructure} THEN Phase 2 ELSE Phase 3; IF approved THEN Phase 3; etc.) | references/flow-procedures.md | Phase transitions | M | prompt |
| 8 | HIGH | Add mode disambiguation protocol below Mode Selection table: if 2+ modes match, present candidates to user; if none match, default to Audit. | SKILL.md | Mode Selection | S | reasoning |
| 9 | HIGH | Add Socratic Protocol convergence criteria: min 1 question/category, convergence after 2 no-new-decisions rounds, max 3 rounds/category, user skip logging. | SKILL.md or references/flow-procedures.md | Phase 2 | M | reasoning |
| 10 | HIGH | Add essential-rules.md to Phase 3 subagent required loading list in flow-procedures.md. Add anti-patterns.md note for debugging scenarios. | references/flow-procedures.md | SS1.3 | S | effectiveness |
| 11 | HIGH | Add Boundary Clarification to SKILL.md: which handoff ops belong here (QA, readiness, technique ref) vs design-handoff (orchestration, manifest, pipeline). | SKILL.md | After "When NOT to Use" | S | effectiveness |
| 12 | HIGH | Remove Quick Reference table (duplicates tool-playbook.md). Condense ST Integration and Compound Learning to 2-line "Optional Integrations" note. Saves ~200 words. | SKILL.md | Quick Reference, ST, Compound Learning | S | context |
| 13 | HIGH | Implement summary-as-context-bus for Flow 2 Phase 3: after each screen's mod-audit-loop, write per-screen summary file, discard detailed results before next screen. | references/flow-procedures.md | SS2.3 | M | architecture |
| 14 | MEDIUM | Add inter-phase validation contracts: Phase 3 must log `phase_complete` entry; orchestrator validates before Phase 4 dispatch. Add failure handling subsection. | references/flow-procedures.md | SS1.3, SS1.4 | M | architecture, reasoning |
| 15 | MEDIUM | Add root cause analysis step to fix cycle: after failed fix, subagent must produce Fix Failure Analysis before retrying with different approach. | references/quality-procedures.md | Section 6 | M | reasoning |

### Additional Improvements

**MEDIUM priority** (grouped by theme):

- **Decision Matrix refinements**: Add G4 fallback row for unsupported operations; refine G2/G3 boundary with count + dependency criteria _(prompt, reasoning)_
- **Writing quality**: Remove passive voice in flow-procedures.md phase steps; trim redundant framing in Socratic Protocol questions; remove trivially-derivable Mode Notes; shorten Output lines _(writing)_
- **Terminology consistency**: Standardize "Sonnet subagent" vs plain "subagent"; consider abstracting model name to config _(prompt, writing)_
- **Context optimization**: Move CSS Grid + Proportional Resize from recipes-foundation.md (Tier 1) to recipes-advanced.md (Tier 3); add max concurrent load guideline; add context pressure note to SKILL.md _(context)_
- **Completeness**: Expand "When NOT to Use" with cross-file operations, IMAGE fill from URLs; update quality-dimensions.md D11 maintenance note to D12; add Spot dimension IDs at point of use in flow-procedures.md; add max fix iteration rationale at both locations _(effectiveness)_
- **Architecture**: Add Session Index refresh step between Phase 3→4; document dual-subagent rationale or consolidate; add structured arbitration template for Deep Critique _(architecture, reasoning)_
- **Structure**: Extract audit scripts to scripts/ directory; add grep navigation hints for files >700 lines; add loading tier trigger conditions _(structure, prompt)_

**LOW priority**: Renumber step 3.5 to sequential integers; standardize dash style in tables; normalize cross-reference format; add `flow` field to journal schema; add README.md to Loading Tiers; add reasoning preamble to subagent prompt template; standardize compatibility markers across reference files.

## Detailed Findings

### Structure & Organization

**Category 10 missing from flow-procedures.md mode subsets** `CRITICAL`
- **File**: references/flow-procedures.md (lines 128-131)
- **Current**: SKILL.md states "11 categories (Cat. 0-10)", socratic-protocol.md defines Cat. 10 with Create subset including "10 (optional)". flow-procedures.md defines only Cat. 0-9 and omits Cat. 10 from all mode subsets. socratic-protocol.md header says "10 categories" while defining 11.
- **Recommendation**: Add Cat. 10 summary to flow-procedures.md, update mode subsets, fix socratic-protocol.md header to "11 categories".
- **Cross-validated by**: structure, prompt, effectiveness

**Selective Reference Loading inflates SKILL.md** `HIGH`
- **File**: SKILL.md (lines 143-218)
- **Current**: 67 lines of verbatim `Read:` directives (23% of skill body). The Loading Tiers summary at the bottom already captures the essential logic. LLM attention degrades in the middle of long uniform lists.
- **Recommendation**: Lead with tier classification, group Read directives by tier with headers. Place Tier 1 (highest priority) first.
- **Cross-validated by**: structure, context

**Frontmatter description overloaded** `HIGH`
- **File**: SKILL.md (line 4)
- **Current**: 94-word single sentence with 11 trigger phrases, capability summary, and cross-skill delegation note. Architectural details ("2 flows", "subagent-first orchestration") don't aid intent matching.
- **Recommendation**: Trim to ~60 words focused on trigger phrases. Move capability list to Overview. Remove design-handoff delegation (already in body at lines 11 and 253-255).
- **Cross-validated by**: structure, context, writing

**No examples/ or scripts/ directories** `MEDIUM`
- **File**: Skill root directory
- **Current**: JS audit scripts (A-I) and code recipes are embedded inline in reference Markdown files rather than stored as standalone runnable scripts.
- **Recommendation**: Extract frequently-used scripts to `scripts/audit/` directory for token-efficient loading.
- **Cross-validated by**: structure

### Content Quality & Clarity

**Screenshot tool distinction restated 5+ times** `HIGH`
- **File**: SKILL.md (lines 46, 128-129, 245), essential-rules.md (lines 19, 52), flow-procedures.md (line 185)
- **Current**: Each instance uses slightly different wording. AVOID #11 restates MUST #6 in negated form.
- **Recommendation**: Canonical statement in essential-rules.md MUST #6 only. Terse reminders elsewhere. Merge AVOID #11 into MUST #6 as "Not:" suffix.
- **Cross-validated by**: prompt, writing

**Passive voice in flow procedures** `MEDIUM`
- **File**: references/flow-procedures.md
- **Current**: "Each category prompts the user..." (categories don't prompt), "Does NOT generate manifest..." (dangling subject)
- **Recommendation**: Rewrite as imperative instructions.

**Socratic Protocol questions contain redundant framing** `MEDIUM`
- **File**: references/socratic-protocol.md
- **Current**: "Two approaches are available:" implied by listing them. "to improve hierarchy clarity" restates what flattening does.
- **Recommendation**: Trim to "[observation]. [proposed action]." with options below.

### Prompt & Instruction Effectiveness

**Implicit mode guards for phase transitions** `HIGH`
- **File**: references/flow-procedures.md (lines 53-54)
- **Current**: Phase 2 skip logic is prose: "Skip for: Audit and Targeted modes". No conditional check template, no state variable, no failure transition.
- **Recommendation**: Add structured transition rules: `Phase 1→2: IF mode IN {Create,Restructure} THEN Phase 2, ELSE Phase 3` etc.
- **Cross-validated by**: prompt

**Mode selection lacks disambiguation for ambiguous intent** `HIGH`
- **File**: SKILL.md (lines 62-67)
- **Current**: Mode Selection table is direct string-match with no tie-breaking. "Clean up this design and add components" could match 3 modes.
- **Recommendation**: Add disambiguation protocol: if 2+ modes match, present to user via AskUserQuestion; if none, default Audit.
- **Cross-validated by**: reasoning

**Decision Matrix lacks G4 fallback** `MEDIUM`
- **File**: SKILL.md (lines 94-101)
- **Current**: G0-G3 with no default for unmatched operations (e.g., "export all frames as PNG").
- **Recommendation**: Add G4 fallback: "Operation not covered → ESCALATE → ask user."

### Context & Token Efficiency

**Tier 1 always-load budget excessive (~7,257 words)** `CRITICAL`
- **File**: references/convergence-protocol.md
- **Current**: Tier 1 loads recipes-foundation.md (2,352 words) + convergence-protocol.md (4,905 words). Only Sections 1-2 of convergence-protocol (~1,400 words) are genuinely needed before any operation. Sections 3-6 (batch scripts, delegation model, snapshot schema, recovery) are execution-phase content.
- **Recommendation**: Split into convergence-core.md (Tier 1, ~1,400 words) and convergence-execution.md (Tier 2, ~3,500 words). Reduces Tier 1 by 48%.
- **Cross-validated by**: context

**SKILL.md exceeds lean target with deferrable content** `HIGH`
- **File**: SKILL.md
- **Current**: Quick Reference table (~120 words, duplicates tool-playbook.md), Troubleshooting Top 5 (~100 words), ST Integration (~80 words), Compound Learning (~60 words). ~360 words of deferrable content.
- **Recommendation**: Remove Quick Reference table. Condense ST + Compound Learning to 2-line "Optional Integrations" note.

**Code-heavy content in Tier 1 recipes-foundation.md** `MEDIUM`
- **File**: references/recipes-foundation.md
- **Current**: CSS Grid Card Layout (80 lines) and Proportional Resize Calculator (75 lines) are task-specific, not foundational.
- **Recommendation**: Move to recipes-advanced.md (Tier 3). Reduces recipes-foundation.md from ~2,352 to ~1,500 words.

### Completeness & Coverage

**Scope boundary with design-handoff ambiguous** `HIGH`
- **File**: SKILL.md
- **Current**: SKILL.md says "use design-handoff for Draft-to-Handoff" but anti-patterns.md has 15+ handoff-specific entries, and Flow 2 includes behavioral spec extraction bordering on manifest preparation.
- **Recommendation**: Add "Boundary Clarification" subsection listing which handoff ops belong here vs design-handoff.

**essential-rules.md Tier 2 placement causes subagent under-loading** `HIGH`
- **File**: SKILL.md (lines 212-218), references/flow-procedures.md (lines 166-170)
- **Current**: Phase 3 subagent required list is `recipes-foundation.md` + `convergence-protocol.md`. essential-rules.md (23 MUST + 14 AVOID) is Tier 2 and not in the required list.
- **Recommendation**: Add essential-rules.md to Phase 3 subagent required loading, or promote to Tier 1.

**"When NOT to Use" section incomplete** `MEDIUM`
- **File**: SKILL.md (lines 250-255)
- **Current**: Lists 4 exclusions. anti-patterns.md Hard Constraints documents additional non-obvious exclusions: cross-file operations, Code Connect, IMAGE fill from external URLs, Figma Make resources.
- **Recommendation**: Add 2-3 most commonly confused exclusions.

### Reasoning & Logic

**Socratic Protocol lacks termination criteria** `HIGH`
- **File**: SKILL.md (line 73)
- **Current**: Only termination criterion is "user approves checklist." No guidance on questions per category, convergence detection, skip protocol, or max rounds.
- **Recommendation**: Add: min 1 question/category, converge after 2 no-new-decisions rounds, max 3 rounds/category, user skip as "deferred", completeness state display.

**Fix cycle retries without root cause analysis** `MEDIUM`
- **File**: references/quality-procedures.md (Section 6)
- **Current**: Mod-Audit-Loop retries mechanically. No requirement to analyze why previous fix failed.
- **Recommendation**: Insert mandatory Fix Failure Analysis between iterations. Next attempt must use different approach based on hypothesis.

**Deep Critique arbitration lacks structured reasoning** `MEDIUM`
- **File**: references/quality-procedures.md (Section 3)
- **Current**: 5th Sonnet subagent "asked for arbitration" with no framework for how to reason.
- **Recommendation**: Add structured arbitration template requiring both positions restated, evidence hierarchy, chain-of-thought explanation, confidence level.

### Architecture & Coordination

**Convergence-protocol phase numbering misaligned with SKILL.md** `HIGH`
- **File**: references/convergence-protocol.md (Section 4)
- **Current**: Section 4 uses legacy Phases 0-5 (Inventory, Component Builder, Per-Screen Pipeline, Prototype Wiring, Annotation, Validation). SKILL.md uses Flow 1 Phases 1-4 and Flow 2 Phases 1-4. Journal `phase` field is ambiguous.
- **Recommendation**: Rewrite Section 4 for current Flow 1/Flow 2 structure, or namespace journal phase field as `"flow": 1, "phase": 3`.
- **Cross-validated by**: architecture

**Supervisor context accumulation in Flow 2 Phase 3** `HIGH`
- **File**: references/flow-procedures.md (Section 2.3)
- **Current**: 10-screen project → up to 60 subagent dispatches, all results accumulating in orchestrator context.
- **Recommendation**: Summary-as-context-bus: write per-screen loop summary, discard details before next screen. Consider delegating entire per-screen loop to single subagent.

**No output validation contract Phase 3→4 in Flow 1** `MEDIUM`
- **File**: references/flow-procedures.md (Sections 1.3, 1.4)
- **Current**: No required artifact list from Phase 3, no orchestrator validation before Phase 4 dispatch. Legacy convergence-protocol had explicit gates but current flows don't.
- **Recommendation**: Add inter-phase contracts: Phase 3 logs `phase_complete` with screens_modified, operations_count, errors_count. Orchestrator validates before Phase 4.

**No failure propagation model for Flow 1** `MEDIUM`
- **File**: references/flow-procedures.md (Sections 1.3, 1.4)
- **Current**: Happy path only. No spec for: subagent crash mid-Phase 3, Phase 4 fail threshold definition, fix cycle mechanics (who dispatches, where scope, counter tracking).
- **Recommendation**: Add failure handling subsection with crash recovery, pass/fail thresholds, fix cycle mechanics, escalation path.

## Strengths

1. **Three-tier progressive loading architecture** — SKILL.md at 1,739 words functions as a lean dispatch table with 22 reference files organized into Always/By-task/By-need tiers. The tier structure maps directly to context engineering best practices. _(identified by: structure, context, effectiveness, architecture)_

2. **Decision Matrix as structured routing logic** — The G0-G3 matrix provides an ordered evaluation sequence with specific tools mapped to each gate, eliminating ambiguity about tool selection. _(identified by: structure, prompt, writing)_

3. **Convergence protocol as durable verification infrastructure** — Nine convergence rules (C1-C9) survive context compaction. Per-screen journals, idempotent batch scripts, and "trust only the journal" rules address the fundamental unreliability of in-context memory. _(identified by: reasoning, architecture, effectiveness)_

4. **Empirically-derived anti-pattern catalog** — 47+ entries from production failures with specific recovery paths. References to real screen names (WK-01, WK-02) indicate genuine field experience rather than theoretical enumeration. _(identified by: effectiveness)_

5. **Multi-methodology reasoning integration** — TAO Loop, Fork-Join, Checkpoint, Reflexion-style revision, and Circuit Breaker mapped to specific triggers with quantitative activation criteria. _(identified by: reasoning)_

6. **11-dimension quality model with tiered depth** — Spot (3 dimensions, inline), Standard (11 dimensions, subagent), Deep (11 dimensions + 3-4 judges). Contradiction Resolution section explicitly documents 10 resolved conflicts. _(identified by: effectiveness, reasoning)_

7. **Consistent user interaction boundary** — "Let's discuss this" escape hatch in every AskUserQuestion, orchestrator-only user interaction (D7), clean human-in-the-loop design. _(identified by: structure, prompt, architecture)_

8. **Comprehensive reference README with ownership tracking** — Three-table README (usage, cross-references, content ownership) prevents duplication and enables informed selective loading. _(identified by: structure, context)_

9. **Per-screen journal partitioning** — Context isolation at the data level prevents journal growth from becoming a bottleneck. Cross-screen journal with back-references handles multi-screen operations. _(identified by: architecture)_

10. **CoV self-verification in quality audit** — Chain of Verification implementation where the model generates bias-checking questions about its own scoring, a textbook Reflexion pattern. _(identified by: reasoning)_

## Metadata

- **Analysis date**: 2026-02-27
- **Lenses applied**: 7 (Structure & Progressive Disclosure, Prompt Engineering Quality, Context Engineering Efficiency, Writing Quality & Conciseness, Overall Effectiveness, Reasoning & Decomposition, Architecture & Coordination)
- **Fallback used**: 5 lenses (Prompt, Context, Writing, Effectiveness, Reasoning)
- **Target skill size**: 1,739 words (SKILL.md) + 22 reference files + 0 example files + 0 script files
- **Individual analyses**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/.skill-review/`
