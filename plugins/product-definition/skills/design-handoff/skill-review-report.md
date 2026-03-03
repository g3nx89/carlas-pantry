---
target_skill: "design-handoff"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff"
analysis_date: "2026-03-01"
lenses_applied:
  - "Structure & Progressive Disclosure"
  - "Prompt Engineering Quality"
  - "Context Engineering Efficiency"
  - "Writing Quality & Conciseness"
  - "Overall Effectiveness"
  - "Reasoning & Decomposition"
  - "Architecture & Coordination"
lenses_degraded: ["Prompt Engineering Quality", "Context Engineering Efficiency", "Overall Effectiveness", "Reasoning & Decomposition"]
overall_score: "2.9/5.0"
findings_total: 55
findings_critical: 1
findings_high: 19
findings_medium: 24
findings_low: 11
findings_info: 0
---

# Skill Review Report: design-handoff

## Executive Summary

The design-handoff skill (v1.0.0) is an ambitious 10-stage workflow that prepares Figma designs for coding agent consumption via two tracks: Figma file preparation and compact behavioral supplement generation. At 1,979 words across SKILL.md plus 9 reference files (~14,400 words), it implements the lean orchestrator pattern with strong progressive disclosure, file-based coordination, and LLM-as-judge quality gates.

**Overall: 2.9/5.0 (Adequate)** -- The skill is structurally sound and architecturally mature but has 1 CRITICAL finding (state file corruption risk) and 19 HIGH findings that impact real-world reliability. The strongest aspect is the one-screen-per-dispatch context isolation pattern with step-level crash recovery. The most pervasive concern is incomplete Quick mode coverage that would cause runtime failures across multiple stages.

**Note:** 4 of 7 lenses used fallback criteria (lens plugins not installed), which may reduce finding depth for Prompt Engineering, Context Engineering, Overall Effectiveness, and Reasoning & Decomposition evaluations.

**INFO findings routing:** 12 INFO-severity findings from individual analyses were positive observations routed to the Strengths section per synthesis rules. They are excluded from the findings total and modification plan.

## Scores by Lens

| Lens | Score | Key Finding |
|------|-------|-------------|
| Structure & Progressive Disclosure | 3/5 | Stage sections in SKILL.md duplicate procedural content from reference files |
| Prompt Engineering Quality | 3/5 | `$CLAUDE_PLUGIN_ROOT` resolution ambiguity in agent dispatch prompts |
| Context Engineering Efficiency | 3/5 | 300-500 tokens wasted on rule repetition across SKILL.md and reference files |
| Writing Quality & Conciseness | 3/5 | Passive voice in key instructions weakens responsibility assignment |
| Overall Effectiveness | 3/5 | Screenshot tool name conflict could cause stale visual diffs if agent ignores Rule 8 |
| Reasoning & Decomposition | 3/5 | Judge verdict re-dispatch loops lack convergence criteria (infinite loop risk) |
| Architecture & Coordination | 2/5 | State file as single point of failure with no corruption detection (CRITICAL) |

**Overall: 2.9/5.0** -- Adequate

Score interpretation:
- 4.5-5.0: Excellent -- production-ready, minimal improvements needed
- 3.5-4.4: Good -- solid skill with some improvement opportunities
- 2.5-3.4: Adequate -- functional but has notable quality gaps
- 1.5-2.4: Needs Work -- significant issues affecting effectiveness
- 1.0-1.4: Poor -- fundamental problems requiring major revision

## Modification Plan

| # | Priority | Action | File | Section | Effort | Lenses |
|---|----------|--------|------|---------|--------|--------|
| 1 | CRITICAL | Add state file integrity: checksum field, atomic writes (write to .tmp then rename), single-writer constraint documented | state-schema.md, SKILL.md | Resume protocol, Critical Rules | M | architecture |
| 2 | HIGH | Add explicit rule: expand `$CLAUDE_PLUGIN_ROOT` to absolute path before Task dispatch; clarify whether Claude Code resolves plugin root in Task context | SKILL.md | Critical Rules | S | prompt |
| 3 | HIGH | Add screenshot tool usage guard: validation step in visual diff verifying `figma_capture_screenshot` used for post-mutation diffs (Rule 8 disambiguates, but a programmatic guard prevents agent oversight) | SKILL.md, figma-preparation.md | Frontmatter, Visual diff | M | effectiveness |
| 4 | HIGH | Add Quick mode guards to every stage reference file (gap-analysis, output-assembly skip manifest requirement; pass `mode: quick` in dispatch) | gap-analysis.md, output-assembly.md, SKILL.md | Prerequisites, Mode guards | M | effectiveness, architecture |
| 5 | HIGH | Reduce SKILL.md stage sections to 2-3 lines each (purpose + delegation + "Read and follow"); remove duplicated procedural steps | SKILL.md | Stages 1-5J | M | structure, context |
| 6 | HIGH | Replace rule restatements in reference files with cross-references ("> Per SKILL.md Rule N"); keep full rules only in SKILL.md bookends | gap-analysis.md, figma-preparation.md, output-assembly.md | Rule repetitions | M | context, prompt |
| 7 | HIGH | Add TIER decision summary table to SKILL.md Stage 1 (3-row: TIER 1/2/3 criteria and component library flag) | SKILL.md | Stage 1 | S | prompt, reasoning |
| 8 | HIGH | Standardize judge verdict vocabulary: single `needs_fix` across all checkpoints with `fix_type` sub-field for semantic distinction | judge-protocol.md, SKILL.md | Verdict format, Dispatch table | M | prompt |
| 9 | HIGH | Add variable sourcing table to judge-protocol.md dispatch template (matching gap-analysis.md pattern) | judge-protocol.md | Dispatch template | S | prompt |
| 10 | HIGH | Add Stage 6 (Completion) or completion subsection: lock release, `current_stage: "complete"`, final state update, resume-from-complete handling | output-assembly.md, state-schema.md | Post-5J, Terminal state | M | effectiveness |
| 11 | HIGH | Add mid-Stage-5 checkpoint: `current_stage: "5:supplement_written"` after HANDOFF-SUPPLEMENT.md write; update resume protocol | output-assembly.md, state-schema.md | Step 5.5, Resume | S | effectiveness |
| 12 | HIGH | Add convergence gate to judge re-dispatch loop: compare finding counts between cycles; escalate if no progress or regression | judge-protocol.md | Orchestrator Integration | S | reasoning |
| 13 | HIGH | Add gap analysis self-verification step (Reflexion pattern): coverage check, navigation completeness, severity plausibility, cross-reference integrity | gap-analysis.md | Pre-output | M | reasoning |
| 14 | HIGH | Extract gap-analysis example tables (~1,200 words) to `references/gap-category-examples.md`; load only in agent dispatch prompt | gap-analysis.md | Category examples | M | context |
| 15 | HIGH | Add `effective_tier` field to state schema; persist TIER downgrades; downstream stages read `effective_tier` not `tier_decision.tier` | state-schema.md, figma-preparation.md | State fields, Downgrade | S | architecture |

### Additional Improvements

**HIGH (overflow):**
- Add Scenario C graduated escalation (micro-fix threshold before full 9-step pipeline) -- reasoning
- Add orchestrator context management rule for screen loop (progress summary every 5 screens) -- architecture
- Consider downgrading Stage 3J/5J judge to sonnet (structural checks don't need opus) -- architecture
- Evaluate Stage 2/3 parallelism opportunity (prepared screens start gap analysis while remaining screens process) -- architecture
- Fix passive voice in SKILL.md core philosophy and setup-protocol Purpose paragraph -- writing
- Add pre-flight dependency check for external agents/templates/config in setup-protocol -- structure

**MEDIUM (grouped):**
- *Prompt clarity*: Define "Figma page order" explicitly; add accept-remaining guard conditions; add prerequisite error actions per check
- *Context efficiency*: Remove ASCII workflow diagram (dispatch table sufficient); merge Reference Map into dispatch table; add context budget declaration with degradation protocol
- *Structure*: Add `figma-screen-brief-template.md` to README external dependencies; add examples/ directory with sample outputs
- *Writing*: Standardize "dispatch" for agents / "execute" for inline; remove redundant qualifiers; fix synonym churn; replace weak negatives with positive phrasing
- *Effectiveness*: Add `screens_skipped` to gap report; add designer dialog timeout/cancellation handling; expand config validation to cover all stages; specify batch mode answer file path
- *Reasoning*: Restructure Scenario detection as explicit decision tree; decompose FSB generation into named sub-procedures; add priority column to judge rubric dimensions
- *Architecture*: Add consecutive error circuit breaker for screen loop; resolve visual diff threshold contradiction (numeric vs advisory); add judge verdict file reconciliation check

## Detailed Findings

### Structure & Organization

**SKILL.md Stage Sections Duplicate Reference Content** `HIGH`
- **File**: SKILL.md (Stages 1-5J)
- **Current**: Each stage section includes numbered procedural steps (e.g., Stage 2 has a 5-step algorithm, Stage 5 has 7 assembly steps) that duplicate content in the corresponding reference files. SKILL.md is 334 lines vs the <300 line lean orchestrator target.
- **Recommendation**: Reduce each stage to: purpose sentence, delegation model, `Read and follow` directive, mode guard. Saves ~100 lines.
- **Cross-validated by**: context

**External Dependencies Not Verifiable from Skill Directory** `HIGH`
- **File**: SKILL.md, references/README.md
- **Current**: 4 agents, 3 templates, and 1 config file referenced at `$CLAUDE_PLUGIN_ROOT/agents/`, `templates/`, `config/` -- no existence verification step.
- **Recommendation**: Add pre-flight dependency check to setup-protocol Step 1.1 or list expected paths in config.

**Reference Map/README Inconsistency** `MEDIUM`
- **File**: SKILL.md, references/README.md
- **Current**: `figma-screen-brief-template.md` in SKILL.md Reference Map but missing from README External Dependencies table.
- **Recommendation**: Add to README.md External Dependencies.

**No examples/ Directory** `MEDIUM`
- **File**: Skill directory
- **Current**: No examples/ for a complex 10-stage workflow.
- **Recommendation**: Add 1-2 trimmed sample outputs (HANDOFF-SUPPLEMENT.md, handoff-manifest.md).

### Content Quality & Clarity

**Passive Voice in Critical Instructions** `HIGH`
- **File**: SKILL.md (line 27), setup-protocol.md (Purpose paragraph)
- **Current**: "Progress persisted in state file. Designer decisions tracked per-screen." -- agent omitted.
- **Recommendation**: "The state file persists progress. The workflow tracks designer decisions per-screen."

**Synonym Churn: dispatch/run/execute** `MEDIUM`
- **File**: SKILL.md
- **Current**: "dispatch" (agents), "runs" (Stage 4), "execute" (inline) used interchangeably.
- **Recommendation**: Standardize: "dispatch" for agent delegation, "execute" for inline stages.

**Redundant Qualifiers** `MEDIUM`
- **File**: SKILL.md (line 69)
- **Current**: "Mandatory 9-step checklist" -- inherently mandatory within a workflow stage.
- **Recommendation**: "9-step checklist."

**"ONLY" Overuse Dilutes Emphasis** `MEDIUM`
- **File**: SKILL.md (3 occurrences: lines 9, 21, 100)
- **Current**: ONLY-caps in 3 locations (frontmatter description, Track B definition, workflow diagram) dilutes the emphasis capitalization is meant to convey.
- **Recommendation**: Reserve ONLY-caps for one authoritative statement; use lowercase elsewhere or restructure (e.g., "covering what Figma cannot express" -- "cannot" already implies exclusivity).

### Prompt & Instruction Effectiveness

**$CLAUDE_PLUGIN_ROOT Resolution Ambiguity** `HIGH`
- **File**: SKILL.md, gap-analysis.md
- **Current**: `@$CLAUDE_PLUGIN_ROOT/...` in dispatch prompts with no instruction on whether the orchestrator must expand to absolute path before dispatch. The `@$CLAUDE_PLUGIN_ROOT` syntax is a Claude Code plugin-framework convention -- whether Task-dispatched subagents can resolve it depends on Claude Code internals (not shell env inheritance). The risk is real but the failure mode is uncertain without empirical testing.
- **Recommendation**: Add Critical Rule 9: "ALWAYS expand `$CLAUDE_PLUGIN_ROOT` to absolute path before Task dispatch." This is defensive best practice even if the framework handles resolution.

**Judge Verdict Vocabulary Inconsistency** `HIGH`
- **File**: judge-protocol.md, SKILL.md
- **Current**: 2J uses `needs_fix`, 3J uses `needs_deeper`, 5J uses `needs_revision` -- orchestrator must maintain per-checkpoint vocabulary mapping.
- **Recommendation**: Standardize on `needs_fix` with a `fix_type` sub-field.

**Judge Dispatch Variable Table Missing** `HIGH`
- **File**: judge-protocol.md
- **Current**: 7 variables in dispatch template with no sourcing table (unlike gap-analysis.md which has one). `{CHECKPOINT_RUBRIC}` sourcing is completely ambiguous.
- **Recommendation**: Add variable sourcing table matching gap-analysis.md pattern.

**TIER Decision Criteria Missing from SKILL.md** `HIGH`
- **File**: SKILL.md
- **Current**: "Smart Componentization analysis, recommend TIER 1/2/3" with zero inline criteria -- requires loading full setup-protocol.md.
- **Recommendation**: Add 3-row summary table: TIER 1 (< 3 patterns, no DS), TIER 2 (3-15 patterns), TIER 3 (full DS, 15+ components).
- **Cross-validated by**: reasoning

**Ambiguous "Figma Page Order"** `MEDIUM`
- **File**: output-assembly.md
- **Current**: "Iterate `STATE.screens` in Figma page order" without defining what page order means.
- **Recommendation**: Define explicitly: "left-to-right X-coordinate of top-level frames, pre-sorted during Stage 1."

**Accept-Remaining Guard Underspecified** `MEDIUM`
- **File**: designer-dialog.md
- **Current**: Offered "after completing each screen (not the first)" but no rule for single remaining screen or CRITICAL gap suppression.
- **Recommendation**: Only offer when >= 2 screens remain; show warning for screens with CRITICAL gaps.

### Context & Token Efficiency

**Excessive Rule Repetition (300-500 Tokens Wasted)** `HIGH`
- **File**: SKILL.md, gap-analysis.md, figma-preparation.md, output-assembly.md
- **Current**: "Figma is source of truth" appears 7 times; "ONE screen per dispatch" 6 times; screenshot rule 5 times across files. ~300-500 redundant tokens per stage execution.
- **Recommendation**: Replace restatements with cross-references ("> Per SKILL.md Rule N"). Keep full formulation only in SKILL.md bookends.
- **Cross-validated by**: prompt

**Gap Analysis Example Tables Inflate Context** `HIGH`
- **File**: gap-analysis.md (~1,200 words of examples)
- **Current**: 6 category example tables load into coordinator context, but only the agent needs them.
- **Recommendation**: Extract to `references/gap-category-examples.md`; load only in agent dispatch prompt. Reduces coordinator context by ~35%.

**Workflow Diagram Duplicates Dispatch Table** `MEDIUM`
- **File**: SKILL.md (lines 60-112)
- **Current**: 53-line ASCII diagram conveys same information as the Stage Dispatch Table. LLMs process tables more reliably than ASCII art.
- **Recommendation**: Remove the ASCII diagram. Saves ~250 words (350 tokens).

**No Context Budget Declaration** `MEDIUM`
- **File**: SKILL.md
- **Current**: No guidance for context-constrained scenarios. Long workflows with many screens risk evicting Critical Rules.
- **Recommendation**: Add "Context Management" section with per-stage token estimates and degradation protocol.

### Completeness & Coverage

**Screenshot Tool Name Conflict** `HIGH`
- **File**: SKILL.md
- **Current**: `allowed-tools` lists both `figma_take_screenshot` and `figma_capture_screenshot`. Critical Rule 8 (line 41) clearly disambiguates usage: `figma_take_screenshot` for baseline reads, `figma_capture_screenshot` for post-mutation diffs. Both tools are correctly listed because both have legitimate use cases. The risk is an agent ignoring the prominently placed Rule 8, not a design defect.
- **Recommendation**: Add a programmatic validation step in figma-preparation.md visual diff step verifying `figma_capture_screenshot` was used. This provides defense-in-depth beyond the Rule 8 instruction.

**Quick Mode Incomplete Stage Coverage** `HIGH`
- **File**: SKILL.md, gap-analysis.md, output-assembly.md
- **Current**: Quick mode skips Stage 2 (no manifest), but Stage 3 prerequisites require manifest; Stage 5 requires manifest as REQUIRED input. Quick mode would fail at runtime.
- **Recommendation**: Add Quick mode guards to every stage reference file; define minimal single-screen supplement format.
- **Cross-validated by**: architecture

**Resume Protocol Does Not Cover Mid-Stage-5** `HIGH`
- **File**: output-assembly.md, state-schema.md
- **Current**: Interruption between writing HANDOFF-SUPPLEMENT.md and updating state leaves `current_stage` at prior value. Resume re-runs Stage 5, potentially overwriting partial supplement.
- **Recommendation**: Add checkpoint `current_stage: "5:supplement_written"` after supplement write.

**No Stage 6 / Completion Protocol** `HIGH`
- **File**: SKILL.md, output-assembly.md
- **Current**: After Stage 5J passes, no documented procedure for lock release, final state update, or transition to terminal state. The state schema *does* define `"complete"` as a valid `current_stage` value (state-schema.md line 15) and the transition diagram (line 132) shows `5J → complete`. However, no reference file documents the actual steps to execute this transition (lock release, state finalization, resume-from-complete handling). Resume from `current_stage: "5J"` with a pass verdict has no documented next step.
- **Recommendation**: Add a lightweight completion subsection to output-assembly.md (or a Stage 6 in SKILL.md) that documents: (1) set `current_stage: "complete"`, (2) release lock, (3) write final summary, (4) resume protocol recognizes `"complete"` and skips all stages.

**Gap Analysis Skips Blocked Screens Silently** `MEDIUM`
- **File**: gap-analysis.md
- **Current**: No `screens_skipped` field in gap report frontmatter; blocked screens simply absent from report.
- **Recommendation**: Add `screens_skipped` count and "Skipped Screens" section with reasons.

**Designer Dialog Lacks Timeout/Cancellation** `MEDIUM`
- **File**: SKILL.md, designer-dialog.md
- **Current**: No handling for partial answers + abandonment, mid-loop cancellation, or malformed batch answers.
- **Recommendation**: Checkpoint after each screen; "designer skipped" marking for unanswered; batch validation.

**FSB Generation Split Across Stage Boundaries** `MEDIUM`
- **File**: gap-analysis.md, SKILL.md
- **Current**: FSB generation hidden in gap-analysis.md "Transition to Stage 3J" section; not mentioned in SKILL.md Stage 3; missing from `artifacts_written` frontmatter.
- **Recommendation**: Add FSBs to frontmatter; mention in SKILL.md Stage 3; consider sub-step "3b."
- **Cross-validated by**: prompt

### Reasoning & Logic

**Judge Re-dispatch Loop Lacks Convergence Criteria** `HIGH`
- **File**: judge-protocol.md (Orchestrator Integration)
- **Current**: On NEEDS_FIX, orchestrator increments cycle counter and re-dispatches. No check whether findings decreased between cycles. Agent could fix one issue, introduce another, cycling at same severity until max_cycles.
- **Recommendation**: Add convergence gate: if `findings_count >= prior_cycle_count` OR new dimensions appear, escalate immediately.

**Scenario C Binary Escalation** `HIGH`
- **File**: figma-preparation.md
- **Current**: A single unbound token in a "clean" screen triggers the full 9-step Scenario B pipeline. No graduated response.
- **Recommendation**: Add micro-fix threshold (< N issues: fix in-place), partial escalation (single-category: relevant steps only), full escalation (multi-category or high count).

**Gap Analysis Missing Self-Verification (Reflexion)** `HIGH`
- **File**: gap-analysis.md
- **Current**: Gap report produced and immediately handed to judge. No self-check for coverage, navigation completeness, severity plausibility, or cross-reference integrity.
- **Recommendation**: Add "Step 0: Self-Verification" before writing final report.

**Scenario Detection Implicit AND/OR** `MEDIUM`
- **File**: figma-preparation.md
- **Current**: Three scenarios defined with prose AND/OR conditions. Evaluation order (C first, then B, then A as default) never stated explicitly.
- **Recommendation**: Restructure as explicit decision tree with numbered evaluation order.

**Judge Rubric Dimensions Lack Weighting** `MEDIUM`
- **File**: judge-protocol.md
- **Current**: 4-5 dimensions per checkpoint treated as equal peers. No guidance on which failures are more severe.
- **Recommendation**: Add priority column (P0 block-eligible, P1, P2) with fix-ordering rule.

**Visual Diff Assessment Quality** `MEDIUM`
- **File**: figma-preparation.md, handoff-config.yaml
- **Current**: Binary pass/fail with no failure categorization; config `visual_diff_threshold: 0.95` labeled "advisory" with no scoring methodology.
- **Recommendation**: Either define scoring methodology or replace with qualitative PASS/FAIL. Classify failure tiers for targeted re-dispatch.
- **Cross-validated by**: architecture

### Architecture & Coordination

**State File Single Point of Failure** `CRITICAL`
- **File**: state-schema.md
- **Current**: `.handoff-state.local.md` is sole coordination bus. YAML frontmatter is not append-safe -- mid-write crash corrupts entire state. No checksumming or journaling. No single-writer constraint documented.
- **Recommendation**: Add checksum field, atomic writes (write .tmp then rename), explicit single-writer architectural constraint.

**Orchestrator Context Accumulation Across Screen Loop** `HIGH`
- **File**: figma-preparation.md
- **Current**: Orchestrator accumulates N dispatch prompts + N state reads + N manifest entries. For 15-screen files, context degrades reasoning for late-loop screens.
- **Recommendation**: Extract screen loop to dedicated coordinator, or add context management rule (summary every 5 screens, discard per-screen details).

**Judge (Opus) at All 4 Checkpoints** `HIGH`
- **File**: judge-protocol.md
- **Current**: Opus dispatched for 3J (structural checks) and 5J (pattern matching for Figma duplication) -- these don't require opus-level reasoning.
- **Recommendation**: Downgrade 3J and 5J to sonnet. Reserve opus for 2J (visual fidelity) and 3.5J (design language evaluation). Or make model configurable per checkpoint.

**Serial Pipeline Misses Parallelism Opportunity** `HIGH`
- **File**: SKILL.md
- **Current**: Fully serial pipeline. Gap analysis could start on already-prepared screens while remaining screens are still processing.
- **Recommendation**: Enable "streaming" pattern via secondary coordination file, or overlap judge evaluation with gap analysis start.

**No Timeout/Circuit Breaker on Agent Dispatch** `MEDIUM`
- **File**: figma-preparation.md
- **Current**: Hung MCP stalls indefinitely. No circuit breaker after consecutive failures.
- **Recommendation**: Add `consecutive_error_threshold` (3). Halt loop on systematic MCP unavailability.

**TIER Downgrade Not Persisted to State** `MEDIUM`
- **File**: figma-preparation.md, state-schema.md
- **Current**: Runtime TIER downgrade on component library failure not persisted as `effective_tier`. Resume reads original `tier_decision.tier`.
- **Recommendation**: Add `effective_tier` field; downstream stages read it instead.

**Gap Report Unclosed Code Fence** `MEDIUM`
- **File**: gap-analysis.md
- **Current**: Nested triple-backtick fences (outer markdown + inner mermaid) -- outer fence prematurely closed by inner fence's closing backticks.
- **Recommendation**: Use `~~~markdown` for outer fence or indentation for inner mermaid block.
- **Cross-validated by**: prompt, effectiveness

## Strengths

1. **One-screen-per-dispatch context isolation** -- Exemplary implementation of context isolation for MCP-heavy workloads. Each dispatch passes minimal, focused context with explicit variable sourcing. Cross-screen state passed as compact summary. Step-level crash recovery within each screen. _(identified by: architecture, reasoning, structure, effectiveness)_

2. **LLM-as-Judge replacing MPA+PAL** -- Well-motivated architectural simplification documented as explicit evolution from design-narration. Eliminates synthesis bias, reduces agent dispatches from ~8 to 4, provides clearer pass/fail verdicts. Judge modeled as dedicated PHASE with own stage numbers. _(identified by: architecture, reasoning, effectiveness)_

3. **Lean orchestrator dispatch table** -- SKILL.md functions as a pure dispatch table at 1,979 words. Stage Dispatch Table provides single-glance view of all 10 stages with delegation type, reference file, and user-pause requirements. Progressive disclosure works well. _(identified by: structure, context, writing)_

4. **Consistent "Figma is source of truth" philosophy** -- Core constraint reinforced across all files without exception. Every gap category framed as "something a coding agent cannot derive from Figma alone." Output rules include zero-duplication mandate. _(identified by: effectiveness, prompt, writing)_

5. **Comprehensive crash recovery** -- State schema tracks step-level progress within each screen. Resume protocol detects "preparing" (interrupted) vs "pending" (never started). Post-resume integrity check verifies screenshot artifacts match state. _(identified by: architecture, reasoning)_

6. **Anti-patterns tables in reference files** -- Both judge-protocol.md and designer-dialog.md end with explicit anti-pattern tables naming common mistakes. Highly effective for LLM instruction (negative examples complement positive rules). _(identified by: prompt)_

7. **CRITICAL RULES bookend pattern** -- Rules at both start and end of SKILL.md exploit primacy and recency bias for LLM attention. "High Attention Zone" label signals elevated processing priority. _(identified by: context, writing, structure)_

8. **Confidence tagging with non-override semantics** -- Three-level confidence (high/medium/low) with explicit rule that "confidence never overrides severity." Prevents common LLM failure mode of downgrading severity due to uncertainty. _(identified by: reasoning, prompt)_

9. **Tables-over-prose philosophy** -- Structured data consistently in tables across all files. Anti-patterns, variable mappings, gap categories, template variables all use table format. Reduces ambiguity and token usage. _(identified by: writing, prompt)_

10. **File-based batch mode as first-class alternative** -- Designer-dialog.md defines batch mode with complete specification (file format, resume protocol, answer parsing). Not an afterthought -- same specification depth as interactive path. _(identified by: prompt)_

## Metadata

- **Analysis date**: 2026-03-01
- **Lenses applied**: 7 (Structure & Progressive Disclosure, Prompt Engineering Quality, Context Engineering Efficiency, Writing Quality & Conciseness, Overall Effectiveness, Reasoning & Decomposition, Architecture & Coordination)
- **Fallback used**: 4 lenses (Prompt Engineering Quality, Context Engineering Efficiency, Overall Effectiveness, Reasoning & Decomposition)
- **Target skill size**: 1,979 words (SKILL.md) + 9 reference files + 0 example files + 0 script files
- **Individual analyses**: `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/.skill-review/`
