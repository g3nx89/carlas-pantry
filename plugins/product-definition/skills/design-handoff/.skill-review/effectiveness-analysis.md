---
lens: "Overall Effectiveness"
lens_id: "effectiveness"
skill_reference: "customaize-agent:agent-evaluation"
target: "design-handoff"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff"
fallback_used: true
findings_count: 12
critical_count: 1
high_count: 3
medium_count: 4
low_count: 2
info_count: 2
---

# Overall Effectiveness Analysis: design-handoff

## Summary

The design-handoff skill (v1.0.0) is an ambitious and well-architected 10-stage workflow that transforms Figma designs into coding-agent-ready deliverables via two tracks: preparing the Figma file itself (Track A) and generating a compact behavioral supplement (Track B). The core philosophy -- Figma as source of truth, supplement covers only what Figma cannot express -- is clearly stated and consistently reinforced throughout SKILL.md and all examined reference files.

The skill demonstrates strong structural discipline: lean orchestrator pattern, one-screen-per-dispatch for context control, dedicated judge checkpoints at every stage boundary, and explicit crash recovery via step-level state tracking. The reference file suite is comprehensive at ~2430 lines across 9 files, with a well-maintained cross-reference index.

However, the analysis uncovered 1 CRITICAL, 3 HIGH, and 4 MEDIUM findings that impact real-world effectiveness. The most significant issue is a gap between the stated resume protocol and the actual stage transition logic that could cause data loss on workflow interruption. Other high-severity findings include incomplete Quick mode coverage across reference files, a screenshot tool naming inconsistency between the SKILL.md frontmatter and its own critical rules, and an ambiguity in how Stage 5 handles the workflow completion state after Stage 5J.

Overall, this is a high-quality skill that would function correctly in the majority of cases. The findings below target the failure modes and edge cases that distinguish a good skill from a production-hardened one.

## Findings

### Finding 1: Screenshot Tool Name Conflict in allowed-tools vs Critical Rules

**Severity:** CRITICAL
**Category:** Internal consistency
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** The YAML frontmatter `allowed-tools` list on line 14 includes both `mcp__figma-console__figma_take_screenshot` and `mcp__figma-console__figma_capture_screenshot`. Critical Rule 8 (line 41) then specifies: "Use `figma_take_screenshot` (figma-console) for baseline reads. Use `figma_capture_screenshot` (figma-console, Desktop Bridge) for any post-mutation visual diff." The gap-analysis.md reference (line 85) repeats this distinction correctly. However, CLAUDE.md for the plugin states in its learnings: "Critical: `figma_capture_screenshot` not `figma_take_screenshot` for post-Plugin-API validation (REST API is stale/cached)." This is an observation about the same distinction, but the critical point is that `figma_take_screenshot` returns cloud-cached (potentially stale) renders. If a coding agent uses `figma_take_screenshot` for a visual diff AFTER a mutation (which the Stage 2 Figma preparation pipeline requires), the diff will silently pass because it compares the pre-mutation cached render against itself. The `allowed-tools` list includes `figma_take_screenshot` without a usage constraint -- an agent could select it for any screenshot need, including post-mutation diffs.

**Recommendation:** Add an explicit comment or guard in the `allowed-tools` frontmatter (or immediately below it) that annotates the two screenshot tools with their correct use cases. Better yet, add a validation step in `references/figma-preparation.md` that checks whether the visual diff screenshot was taken with `figma_capture_screenshot` specifically (e.g., by verifying the tool name in the operation journal). This prevents the silent stale-screenshot failure mode that would cause Stage 2J to pass screens that were not actually modified correctly.

---

### Finding 2: Resume Protocol Does Not Cover Mid-Stage Interruption in Stage 5

**Severity:** HIGH
**Category:** Edge case coverage
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/output-assembly.md`

**Current state:** Step 5.7 (line 189) sets `STATE.current_stage: "5"` after generating the summary report. The transition to Stage 5J (line 199) then sets `current_stage = "5J"` before dispatching the judge. If the workflow is interrupted between Step 5.5 (writing HANDOFF-SUPPLEMENT.md) and Step 5.7 (updating state to stage "5"), the state file still shows `current_stage: "4"` (or whatever the previous value was). On resume, the orchestrator would re-run Stage 5 from scratch, potentially overwriting a partially-written supplement. More critically, if interruption occurs between Step 5.7 and the 5J dispatch, state says "5" but the judge has not been invoked -- and there is no explicit resume logic to detect "stage 5 complete but 5J not dispatched."

**Recommendation:** Add a checkpoint immediately after writing HANDOFF-SUPPLEMENT.md in Step 5.5 (the most expensive operation) that sets `current_stage: "5:supplement_written"`. The resume protocol in `state-schema.md` should recognize this intermediate checkpoint and skip to Step 5.6 on resume. Additionally, the orchestrator dispatch table in SKILL.md should document what happens when `current_stage` is "5" on resume -- does it re-run the entire stage or skip to 5J?

---

### Finding 3: Quick Mode Has Incomplete Stage Coverage

**Severity:** HIGH
**Category:** Completeness
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** Quick mode (`--quick`) is defined on line 52 as "single screen, no Figma preparation, gap analysis + dialog only." SKILL.md Stage 1 (line 151) says Quick mode skips steps 7-8 (TIER decision and Scenario Detection) and does single screen selection. Stage 2 (line 171) says "Skip entirely in Quick mode." However, no other stage dispatch section (Stages 2J, 3, 3J, 3.5, 3.5J, 4, 5, 5J) explicitly states its Quick mode behavior. The gap-analysis.md reference file has no mention of `--quick` at all. The output-assembly.md reference has no mention of `--quick` at all.

This means: (a) the gap analyzer will attempt to read `handoff-manifest.md` as a prerequisite (gap-analysis.md line 37), but in Quick mode Stage 2 was skipped and no manifest exists; (b) Stage 5 requires `handoff-manifest.md` as a REQUIRED input (output-assembly.md line 32) that will also not exist.

**Recommendation:** Add explicit Quick mode guards to every stage reference file. At minimum: (1) gap-analysis.md prerequisites should skip the manifest check in Quick mode, (2) output-assembly.md should define a minimal single-screen supplement format that does not depend on a manifest, (3) Stages 2J, 3.5, 3.5J, and 5J should be explicitly skipped or adapted. A "Quick Mode Behavior" subsection at the top of each reference file would make this unambiguous.

---

### Finding 4: Stage 5 current_stage Never Advances Past "5" for Final Completion

**Severity:** HIGH
**Category:** Edge case coverage
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/output-assembly.md`

**Current state:** After Stage 5J passes, the skill needs to complete the workflow (release lock, finalize state). SKILL.md (line 326-333) lists the Critical Rules reminder section but there is no Stage 6 or "Completion" stage defined. The output-assembly.md Transition to Stage 5J section (lines 196-202) describes what happens on `needs_revision` and `pass` verdicts, but the `pass` path says only "advance to workflow completion (lock release, final state update)" without a reference file, stage number, or detailed procedure.

This creates ambiguity: Who releases the lock? What is the final `current_stage` value? How does the state file indicate "workflow complete" vs "stuck at stage 5J"? A crashed session that resumes from `current_stage: "5J"` with a `pass` verdict has no documented next step.

**Recommendation:** Either add a lightweight Stage 6 (Completion) with explicit lock release, final state update (`current_stage: "complete"`), and state file finalization, or add a "Completion Protocol" subsection to output-assembly.md that covers these steps. The state-schema.md should define the terminal `current_stage` value and the resume protocol should handle it (i.e., detect already-complete and skip).

---

### Finding 5: Gap Analysis Prerequisites May Fail Silently on Partial Stage 2

**Severity:** MEDIUM
**Category:** Error path coverage
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/gap-analysis.md`

**Current state:** The dispatch prerequisites (lines 33-40) check that "at least one screen has status == 'prepared'" and that `handoff-manifest.md` exists. If Stage 2 partially completed (some screens prepared, some blocked), the prerequisite passes and gap analysis runs on prepared screens only. However, there is no explicit instruction for the gap analyzer to report which screens were SKIPPED due to blocked status. The gap report format (lines 305-387) includes `total_screens_analyzed` but no `screens_skipped_blocked` count.

**Recommendation:** Add a `screens_skipped` field to the gap report frontmatter and require the gap analyzer to list blocked screens in a "Skipped Screens" section with reasons. This prevents downstream stages from silently dropping screens without audit trail.

---

### Finding 6: Designer Dialog Stage Lacks Timeout or Abandonment Handling

**Severity:** MEDIUM
**Category:** Edge case coverage
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** Stage 4 (lines 235-249) describes a per-screen Q&A loop where the orchestrator asks the designer about gaps. The exit condition is "all screens done, or designer accepts remaining as-is." Batch mode writes to a file and exits. However, there is no handling for: (a) a designer who partially answers and then abandons the session for days, (b) a guided mode session where the designer cancels mid-loop (what happens to already-answered screens?), or (c) a batch mode file that the designer modifies incorrectly (malformed answers).

**Recommendation:** Add to SKILL.md Stage 4 or `references/designer-dialog.md`: (1) checkpoint after each screen's answers so partial progress is preserved, (2) a "Cancel mid-dialog" path that preserves answered screens and marks unanswered as "designer skipped," (3) batch mode answer validation with specific error messages for common format mistakes.

---

### Finding 7: Figma Screen Brief Generation Responsibility is Split Across Stage Boundaries

**Severity:** MEDIUM
**Category:** Instruction clarity
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/gap-analysis.md`

**Current state:** Lines 428-461 of gap-analysis.md describe FSB (Figma Screen Brief) generation as a post-gap-analysis step performed by "the orchestrator" after the gap analyzer finishes. This is a substantial procedure (template reading, reference screen selection, field population) embedded in what is labeled as the Stage 3 reference file. However, SKILL.md Stage 3 section (lines 185-196) describes only the gap analyzer dispatch and its output. The FSB generation is not mentioned in SKILL.md at all -- it appears only in the reference file's "Transition to Stage 3J" section.

This creates a cognitive gap: someone reading SKILL.md would not know FSBs are generated in Stage 3. The dispatch table lists `gap-report.md` as the only Stage 3 artifact, but the frontmatter of gap-analysis.md also only lists `gap-report.md` in `artifacts_written` (line 6), missing the FSB files.

**Recommendation:** (1) Add FSBs to gap-analysis.md frontmatter `artifacts_written`, (2) Add a brief mention in SKILL.md Stage 3 section that FSBs are generated post-analysis for MUST_CREATE/SHOULD_CREATE items, (3) Consider whether FSB generation should be a separate sub-step (3b) in SKILL.md for clarity.

---

### Finding 8: Config Key References Not Validated for Existence

**Severity:** MEDIUM
**Category:** Instruction-following quality
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/setup-protocol.md`

**Current state:** Step 1.1 (lines 28-40) validates a specific list of config keys. This is good practice. However, subsequent reference files introduce additional config keys that are NOT in the Step 1.1 validation list. For example, gap-analysis.md references `gap_analysis.*` config keys (frontmatter line 6) and `figma.query_depth` (line 78). Output-assembly.md references `output.*` and `templates.*` config keys. These keys are assumed to exist but never validated upfront.

If a config key is missing (e.g., after a config file version change), the failure would occur mid-workflow at the stage that needs it, rather than at startup.

**Recommendation:** Expand Step 1.1 validation to include ALL config keys used by ALL stages, or add per-stage config validation at the beginning of each reference file's execution. The former is preferred as it surfaces all config issues before any Figma mutations begin.

---

### Finding 9: Gap Report Format Example Has Unclosed Code Fence

**Severity:** LOW
**Category:** Instruction-following quality
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/gap-analysis.md`

**Current state:** The gap report format section starts a markdown code fence at line 304 (`\`\`\`markdown`) and the Common Transitions table ends at line 387 with `\`\`\``. However, the mermaid block inside this code fence (lines 367-377) uses its own triple-backtick fence, which would prematurely close the outer code fence in most markdown renderers. An agent parsing this example literally could produce a malformed gap report.

**Recommendation:** Use indentation (4 spaces) instead of a code fence for the inner mermaid block within the example, or use a different delimiter (e.g., `~~~markdown` for the outer fence) to avoid nesting conflicts. Alternatively, add a note that the mermaid block in the actual output should use triple backticks, but the example here uses a different convention.

---

### Finding 10: Batch Mode Resume Lacks Answer File Location Specification

**Severity:** LOW
**Category:** Completeness
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** SKILL.md line 248 says Batch mode writes gaps to a file and exits, with the designer answering offline. On re-invocation, the workflow resumes. However, SKILL.md does not specify the file name or location for the batch mode answer file. The designer-dialog.md reference is not among the files I read, but SKILL.md itself should at minimum name the file so the designer knows where to write answers.

**Recommendation:** Add the batch mode answer file path to SKILL.md Stage 4 description (e.g., `design-handoff/working/DIALOG-ANSWERS.md`) and mention it in the supported flags description on line 53.

---

### Finding 11: Consistent and Thorough Application of Core Philosophy

**Severity:** INFO
**Category:** Positive observation

Every file examined reinforces the "Figma is source of truth" philosophy without exception. SKILL.md states it in the core philosophy section (line 25), Critical Rules (line 34), and the end-of-file rules reminder (line 327). Setup-protocol.md has its own Critical Rules section. Gap-analysis.md frames every gap category explicitly as "something a coding agent CANNOT derive from Figma alone." Output-assembly.md Critical Rules repeat the zero-duplication mandate. This level of consistency across ~2400 lines of reference material is notable and would give Claude a very clear mental model of its constraints.

---

### Finding 12: Excellent Gap Category Exemplification in gap-analysis.md

**Severity:** INFO
**Category:** Positive observation

The gap-analysis.md reference file (lines 95-160) provides concrete example tables for each of the 6 gap categories with specific screen names, element names, and gap descriptions. This is far more effective than abstract definitions -- it gives the gap analyzer agent a calibrated understanding of what constitutes a "behavior gap" vs a "state gap" vs an "edge case gap." The severity classification decision tests (lines 163-170) are similarly concrete: "If the coding agent guesses, will the feature be fundamentally broken?" This question-form rubric is more actionable than threshold-based definitions.

## Strengths

### Strength 1: LLM-as-Judge Architecture Replaces MPA Complexity

The skill's decision to use a single `handoff-judge` agent (opus) at 4 stage boundaries rather than multi-perspective analysis with synthesis is a mature architectural choice. Each checkpoint has its own rubric (documented in judge-protocol.md), clear verdict format (PASS/NEEDS_FIX/BLOCK), and bounded retry cycles. This avoids the first-read anchoring bias documented in the design-narration skill's learnings and reduces total agent dispatches from ~8 (MPA+PAL+synthesis) to 4 (one judge per checkpoint). The judge is a dedicated PHASE, not an afterthought -- it has its own stage numbers (2J, 3J, 3.5J, 5J) in the dispatch table, making it impossible to skip inadvertently.

### Strength 2: One-Screen-Per-Dispatch with Step-Level State Tracking

The decision to process one screen at a time through the figma-preparer agent, with step-level progress persisted in the state file, addresses the context compaction problem head-on. The SKILL.md Stage 2 description (lines 155-171) and the sequential loop pattern ensure that a crash at step 6 of screen 3 can resume at exactly that point rather than restarting the entire pipeline. The state schema tracks `current_step`, `completed_steps[]`, and `operation_journal[]` per screen, providing both resume capability and audit trail. This is the right trade-off for context-heavy MCP operations.

### Strength 3: Explicit "No Supplement Needed" Marking

Gap-analysis.md (lines 392-409) explicitly defines the "No supplement needed" marker for screens where Figma fully expresses the design intent. The file explains WHY this is important: omitting a screen from the gap report is ambiguous (analyzed and clean vs accidentally skipped), while the explicit marker eliminates that ambiguity. This is a small detail that prevents a significant class of downstream errors in the supplement.

### Strength 4: Cross-Reference Index with External Dependencies

The references/README.md maintains a three-part index: file usage table with line counts, cross-reference matrix showing which files reference which others, and an external dependencies table listing config files, templates, and agents. This makes the skill navigable for both human reviewers and Claude agents that need to understand the dependency graph before loading files.
