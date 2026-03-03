---
lens: "Prompt Engineering Quality"
lens_id: "prompt"
skill_reference: "customaize-agent:prompt-engineering"
target: "design-handoff"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff"
fallback_used: true
findings_count: 14
critical_count: 1
high_count: 3
medium_count: 5
low_count: 3
info_count: 2
---

# Prompt Engineering Quality Analysis: design-handoff

## Summary

The design-handoff skill is a well-structured, multi-stage orchestrator pattern with strong architectural discipline. It excels at separation of concerns (lean SKILL.md dispatch table + detailed reference files), explicit state management, and clear agent boundaries. The core philosophy ("Figma is source of truth, supplement covers only what Figma cannot express") is articulated consistently across all files, reinforcing the primary constraint at every decision point.

However, several prompt engineering issues reduce the skill's reliability when executed by an LLM. The most significant are: (1) a critical ambiguity in how the orchestrator should resolve `$CLAUDE_PLUGIN_ROOT` when constructing agent dispatch prompts, (2) inconsistent verdict terminology across judge checkpoints that forces the orchestrator to maintain a per-checkpoint vocabulary, (3) several instances where instructions describe *what* to do but not *how to decide* when conditions are ambiguous, and (4) missing explicit fallback behavior for edge cases in the designer dialog flow.

**Files analyzed:**
- `SKILL.md` (main orchestrator)
- `references/gap-analysis.md` (Stage 3)
- `references/judge-protocol.md` (all judge checkpoints)
- `references/output-assembly.md` (Stage 5)
- `references/designer-dialog.md` (Stage 4)

---

## Findings

### 1. Inconsistent Judge Verdict Vocabulary Across Checkpoints

**Severity:** HIGH
**Category:** Instruction clarity and unambiguity
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/judge-protocol.md`

**Current state:** Each judge checkpoint uses a different verdict term for the "needs improvement" outcome:
- Stage 2J: `needs_fix`
- Stage 3J: `needs_deeper`
- Stage 3.5J: `needs_fix`
- Stage 5J: `needs_revision`

The orchestrator must maintain a per-checkpoint mapping to know which verdict string means "re-dispatch the stage coordinator." The `SKILL.md` Stage Dispatch Table (lines 122-129) also uses different "User Pause?" conditions per checkpoint (`On BLOCK`, `On NEEDS_DEEPER`, `On NEEDS_FIX`, `On NEEDS_REVISION`), compounding the vocabulary burden.

**Recommendation:** Standardize on a single re-dispatch verdict across all checkpoints (e.g., `needs_fix`), with an optional `fix_type` sub-field to distinguish semantics when needed:

```yaml
verdict: "needs_fix"
fix_type: "deeper_analysis" | "targeted_fix" | "section_revision"
```

This lets the orchestrator use a single `if verdict == "needs_fix"` branch for all checkpoints while preserving the semantic distinction in the sub-field. Update the SKILL.md dispatch table accordingly.

---

### 2. $CLAUDE_PLUGIN_ROOT Resolution Ambiguity in Dispatch Prompts

**Severity:** CRITICAL
**Category:** LLM instruction effectiveness
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** Reference file loading instructions use `@$CLAUDE_PLUGIN_ROOT/...` syntax (e.g., line 137: `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/setup-protocol.md`). For inline stages executed by the orchestrator itself, this works because the orchestrator has the environment variable in scope. However, for agent dispatches via `Task()`, the dispatch prompt in `gap-analysis.md` (line 57) says:

```
Instructions: Read @$CLAUDE_PLUGIN_ROOT/agents/handoff-gap-analyzer.md
```

There is no instruction telling the orchestrator whether `$CLAUDE_PLUGIN_ROOT` will be automatically resolved in the dispatched agent's context, or whether the orchestrator must expand it to an absolute path before dispatching. If the subagent does not inherit the environment variable, it will fail to locate the agent definition file.

**Recommendation:** Add an explicit rule to the CRITICAL RULES section in SKILL.md:

```markdown
9. **Variable expansion in dispatch prompts**: When constructing Task() prompts for agent dispatch,
   ALWAYS expand `$CLAUDE_PLUGIN_ROOT` to its actual absolute path value before dispatching.
   Subagents do NOT inherit shell environment variables from the orchestrator.
```

Also update the dispatch prompt template in `gap-analysis.md` to use `{PLUGIN_ROOT}` as an explicit template variable with sourcing instructions.

---

### 3. Missing Decision Criteria for TIER Recommendation

**Severity:** HIGH
**Category:** Degrees of freedom / specificity
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** Stage 1 step 7 says "Smart Componentization analysis, recommend TIER 1/2/3" (line 147), and Stage 2 references TIER 2/3 for component library creation (line 163). However, SKILL.md never defines what TIER 1, 2, or 3 mean, what criteria distinguish them, or what thresholds drive the recommendation. The decision is deferred to `references/setup-protocol.md` (not read for this analysis), but SKILL.md itself provides no summary criteria.

An LLM executing the orchestrator will reach step 7 and must decide between three tiers with zero decision criteria visible in its current context. It must load the full setup-protocol.md reference file to understand the tiers, adding latency and context cost for what should be a summarized decision framework.

**Recommendation:** Add a 3-row summary table to SKILL.md Stage 1 that defines the tiers at a glance:

```markdown
| TIER | Criteria | Component Library? |
|------|----------|--------------------|
| 1 | < 5 reusable patterns, no design system | No |
| 2 | 5-15 reusable patterns OR partial design system | Yes (local) |
| 3 | Full design system, 15+ components, token-driven | Yes (linked) |
```

This lets the orchestrator make a preliminary assessment before loading the full reference, and serves as a validation check after the reference is loaded.

---

### 4. Ambiguous "Figma Page Order" for Screen Iteration

**Severity:** MEDIUM
**Category:** Instruction clarity and unambiguity
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/output-assembly.md`

**Current state:** Step 5.3 (line 67) says "Iterate `STATE.screens` in Figma page order (matching manifest)." But `STATE.screens` is an array populated during Stage 1 discovery. The instruction assumes the array is already in Figma page order, but does not specify what "Figma page order" means (left-to-right frame position? top-to-bottom? insertion order? alphabetical by frame name?).

**Recommendation:** Define "Figma page order" explicitly in either the state-schema.md or setup-protocol.md, and add a parenthetical to output-assembly.md:

```markdown
Iterate `STATE.screens` in Figma page order (left-to-right X-coordinate of top-level frames,
as recorded during Stage 1 discovery — the array is pre-sorted).
```

---

### 5. Gap Report Markdown Template Contains Unclosed Code Fence

**Severity:** MEDIUM
**Category:** Prompt structure / logical flow
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/gap-analysis.md`

**Current state:** The "Gap Report Format" section (starting line 302) opens a markdown code fence on line 304 to show the template. The code fence contains a mermaid block (line 367) and a "Common Transitions" table (line 383). The code fence appears to close on line 387 with triple backticks, but this closing fence is actually the closing of the inner `Common Transitions` block, not the outer template fence. The outer code fence from line 304 is never explicitly closed with a standalone triple backtick line.

When an LLM reads this, it may become confused about where the template ends and where the instructional prose resumes. The "No Supplement Needed Screens" section (line 391) and subsequent prose may be interpreted as part of the template rather than as separate instructions.

**Recommendation:** Ensure the outer code fence is cleanly closed after the Common Transitions table. Add a clear `---` separator and a comment like `<!-- End of gap report template -->` before the "No Supplement Needed" prose section to eliminate parsing ambiguity.

---

### 6. Designer Dialog "Accept Remaining" Guard Condition Underspecified

**Severity:** MEDIUM
**Category:** Edge cases and decision points
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/designer-dialog.md`

**Current state:** Step 4.3 (line 106) says the "Accept Remaining" option is offered "After completing each screen (not the first)." This means it is offered after screen 2, screen 3, etc. However, it does not specify:
- What if there are only 2 screens total and the designer already completed screen 1? Is "Accept Remaining" offered for the single remaining screen?
- What if the remaining screens have only CRITICAL gaps? Should the accept-remaining option still be offered, or should it be suppressed for screens with CRITICAL gaps to prevent silent quality loss?

**Recommendation:** Add explicit guard conditions:

```markdown
**Accept-remaining guard:**
- Only offered when >= 2 screens remain (never for a single remaining screen)
- If remaining screens contain CRITICAL gaps, show a warning:
  "Note: {N} remaining screens have CRITICAL gaps. Accepting as-is means the
   coding agent will make its best judgment on critical behaviors."
```

---

### 7. Dispatch Prompt Variable Table Missing in Judge Protocol

**Severity:** HIGH
**Category:** LLM instruction effectiveness
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/judge-protocol.md`

**Current state:** The judge dispatch prompt template (lines 28-49) uses 5 variables (`{STAGE_NAME}`, `{CHECKPOINT_ID}`, `{WORKING_DIR}`, `{STATE_FILE_PATH}`, `{ARTIFACT_PATHS}`, `{CHECKPOINT_RUBRIC}`, `{PASS_CRITERIA}`) but, unlike `gap-analysis.md` which has a clear variable table with Source and Fallback columns, the judge protocol provides no variable sourcing table. The orchestrator must infer where each variable comes from.

`{CHECKPOINT_RUBRIC}` is particularly problematic -- should the orchestrator copy-paste the rubric table from this reference file into the prompt? Or reference the file path? Or provide a summary? The instruction "Read @$CLAUDE_PLUGIN_ROOT/agents/handoff-judge.md" is missing from the template entirely, meaning the judge agent is dispatched without being told to read its own agent definition.

**Recommendation:** Add a variable table matching the pattern established in gap-analysis.md:

```markdown
| Variable | Source | Fallback |
|----------|--------|----------|
| `{STAGE_NAME}` | Stage dispatch table in SKILL.md | Required |
| `{CHECKPOINT_ID}` | `stage_2j`, `stage_3j`, `stage_3_5j`, `stage_5j` | Required |
| `{WORKING_DIR}` | State file `artifacts.working_dir` | `design-handoff/` |
| `{STATE_FILE_PATH}` | Known path | `design-handoff/.handoff-state.local.md` |
| `{ARTIFACT_PATHS}` | Per-checkpoint artifact lists (below) | Required |
| `{CHECKPOINT_RUBRIC}` | Embed the relevant rubric dimension table inline | Required |
| `{PASS_CRITERIA}` | Embed pass condition text from relevant rubric | Required |
```

Also add the agent file read instruction: `Instructions: Read @$CLAUDE_PLUGIN_ROOT/agents/handoff-judge.md`

---

### 8. Competing Screenshot Tool Names Without Consolidated Rule

**Severity:** MEDIUM
**Category:** Instruction clarity and unambiguity
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** The skill references two figma-console screenshot tools with different use cases:
- `figma_take_screenshot` for "baseline reads" (cloud-cached REST API render)
- `figma_capture_screenshot` for "post-mutation visual diff" (Desktop Bridge, live state)

This distinction is stated in SKILL.md Critical Rule 8 (line 41), repeated in gap-analysis.md (line 85), and again in judge-protocol.md Stage 2J (line 69) and Stage 3.5J (line 127). Each repetition uses slightly different phrasing. The `allowed-tools` in frontmatter (line 14) lists BOTH tools, but the skill description on line 8 does not mention which to use when.

An LLM may become confused by seeing both tools permitted with overlapping descriptions across multiple files.

**Recommendation:** Consolidate the screenshot rule into a single, clearly worded table in SKILL.md Critical Rules, and have all reference files point back to it rather than restating the rule in their own words:

```markdown
| Tool | When to Use | Why |
|------|------------|-----|
| `figma_take_screenshot` | Before any mutations; initial screen reads | Returns cloud-cached render (fast, sufficient for unmodified screens) |
| `figma_capture_screenshot` | After ANY Figma Plugin API mutation | Desktop Bridge captures live canvas state; REST API cache is stale post-mutation |
| `figma-desktop::get_screenshot` | NEVER | Wrong MCP server; do not use |
```

Reference files should say: "Screenshot rules: see SKILL.md Critical Rule 8" instead of restating.

---

### 9. Output Assembly Step 5.5 Variable Uses Double-Brace Syntax Inconsistently

**Severity:** LOW
**Category:** Prompt structure / logical flow
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/output-assembly.md`

**Current state:** Step 5.5 (lines 121-138) uses `{{DOUBLE_BRACE}}` syntax for template variables (`{{PRODUCT_NAME}}`, `{{SCREEN_COUNT}}`, etc.), while all other dispatch prompts in the skill use `{SINGLE_BRACE}` syntax. This inconsistency may cause an LLM to treat them as different resolution mechanisms -- one being a literal template placeholder to write into a file, the other being a variable to resolve before dispatch.

The distinction is actually intentional (double-brace = file template variables, single-brace = dispatch prompt variables), but this is never explicitly stated anywhere.

**Recommendation:** Add a one-line clarification at the top of output-assembly.md or in SKILL.md conventions:

```markdown
**Variable syntax:** `{SINGLE_BRACE}` = resolved by orchestrator before dispatch.
`{{DOUBLE_BRACE}}` = template placeholders written to output files, resolved during file generation.
```

---

### 10. Cross-Screen Pattern Confirmation Step Lacks Fallback for Zero Patterns

**Severity:** LOW
**Category:** Edge cases and decision points
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/designer-dialog.md`

**Current state:** Step 4.5 (line 153) says to review `state.patterns` and confirm each pattern. But it does not specify what happens if `patterns.shared_behaviors`, `patterns.common_transitions`, and `patterns.global_edge_cases` are ALL empty (i.e., no cross-screen patterns were detected in Stage 3). The LLM may still attempt to present an empty confirmation step to the designer, or may skip the step silently without updating state.

**Recommendation:** Add an explicit guard:

```markdown
**Guard:** Skip this step entirely if ALL pattern arrays are empty. Log in progress:
"No cross-screen patterns detected — skipping confirmation."
```

---

### 11. Gap Analysis Dispatch Prerequisite Check Uses Pseudocode Without Error Handling

**Severity:** MEDIUM
**Category:** LLM instruction effectiveness
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/gap-analysis.md`

**Current state:** The dispatch prerequisites (lines 31-39) include a check: "IF zero prepared screens: HALT -- log error, set current_stage back to '2'." This is the only prerequisite that sets the stage backward. The others (stage check, existing report check, manifest check) do not specify what to do on failure -- only check #4 has a recovery action.

An LLM encountering a missing manifest (check #3) has no instruction on whether to halt, set stage back to "2", notify the designer, or attempt to proceed without it.

**Recommendation:** Add explicit failure actions for each prerequisite check:

```
1. CHECK current_stage == "3"
   - ON FAIL: HALT — state corruption, notify designer
2. CHECK gap-report.md does NOT exist (unless re-run)
   - ON FAIL (exists, not re-run): HALT — duplicate run, ask designer to confirm
3. CHECK handoff-manifest.md EXISTS
   - ON FAIL: HALT — Stage 2 incomplete, set current_stage = "2", notify designer
4. CHECK at least one prepared screen
   - ON FAIL: HALT — set current_stage = "2", notify designer
```

---

### 12. FSB Generation Logic in gap-analysis.md is Orchestrator Work Placed in a Coordinator Reference

**Severity:** LOW
**Category:** Logical flow / separation of concerns
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/gap-analysis.md`

**Current state:** The "Transition to Stage 3J" section (lines 413-471) contains detailed FSB (Figma Screen Brief) generation logic that the *orchestrator* must execute after the gap analyzer agent completes. This logic is embedded in the gap-analysis.md reference file, which is conceptually the coordinator reference for Stage 3's agent dispatch. The orchestrator must read this entire reference file to find the FSB generation steps, even though the agent dispatch portion is the primary content.

**Recommendation:** Consider extracting the post-agent orchestrator steps (FSB generation, state update, judge dispatch) into either SKILL.md itself (as a sub-section of Stage 3) or a separate `references/stage-3-post-analysis.md` file. This separates "what the agent does" from "what the orchestrator does after the agent finishes."

---

### 13. No Explicit Instruction for Handling Concurrent Workflow Invocations

**Severity:** INFO
**Category:** Edge cases and decision points
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** Stage 1 step 3 mentions "Lock Acquisition -- Acquire `design-handoff/.handoff-lock`; handle stale locks" (line 143). The lock mechanism is deferred to `setup-protocol.md`. SKILL.md does not summarize what "stale" means (timeout threshold) or what happens when a lock is held by a previous session that crashed. This is an edge case that could leave the workflow permanently locked.

**Recommendation:** This is an observation rather than a bug. The lock protocol is appropriately delegated to the setup reference file. For completeness, SKILL.md could add a one-liner: "Stale lock timeout: `lock.stale_timeout_minutes` from config (default 60). On stale: auto-acquire with warning."

---

### 14. CRITICAL RULES Bookend Pattern Drifts Between Start and End

**Severity:** INFO
**Category:** Prompt structure
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** The "CRITICAL RULES (High Attention Zone -- Start)" block (lines 31-42) contains 8 numbered rules. The "CRITICAL RULES (High Attention Zone -- End)" block (lines 324-333) restates only 7 of those rules and rephrases several. For example, Rule 8 about screenshot tools is absent from the End block. Rule 3 is reworded from "ONE screen per figma-preparer dispatch" to "ONE screen per figma-preparer dispatch -- sequential with step-level state" (adding detail in the restatement).

The bookend pattern is effective for attention reinforcement, but drift between start and end versions can cause an LLM to treat the end block as authoritative (recency bias), potentially dropping Rule 8 from its working memory.

**Recommendation:** Ensure the End block is an exact copy of the Start block rules (same count, same wording). If additional detail is needed, add it to the Start block so both match. This is a minor polish item since the core rules are still present.

---

## Strengths

### 1. Exceptional Separation of Concerns via Lean Orchestrator Pattern

The SKILL.md file is a clean dispatch table at 334 lines. It defines WHAT happens at each stage, WHO does it (inline vs agent), and WHERE the details live (reference files), without embedding procedural logic. This is ideal for LLM consumption: the orchestrator can load SKILL.md into context at ~2K tokens and selectively load reference files only when reaching their stage. Progressive disclosure reduces context pollution and keeps the LLM focused on the current stage.

### 2. Consistent "Anti-Patterns" Sections Across Reference Files

Both `judge-protocol.md` (lines 209-217) and `designer-dialog.md` (lines 275-283) end with explicit anti-pattern tables that name common mistakes and their corrections. This is a highly effective prompt engineering technique: LLMs learn constraints better from negative examples ("do NOT do X") than from positive-only rules. The anti-pattern tables are concise (4-6 rows each), specific, and non-overlapping.

### 3. Rich Worked Examples in Gap Analysis

The gap-analysis.md reference file provides extensive example tables for each of the 6 gap categories (lines 93-161), with concrete screen names, elements, and gap descriptions. These examples serve as few-shot demonstrations for the gap analyzer agent, grounding abstract categories ("behaviors," "states") in tangible scenarios. The examples are domain-neutral (Login, Product List, Checkout) rather than project-specific, making them reusable across different design projects.

### 4. Explicit Confidence Tagging with Non-Override Rule

The confidence tagging pattern in gap-analysis.md (lines 172-183) is well-designed: it defines three levels, explains what each means with concrete examples, and explicitly states that "confidence never overrides severity." This prevents a common LLM failure mode where uncertainty about a finding causes the agent to downgrade its severity, masking genuinely critical gaps behind a "low confidence" label.

### 5. File-Based Q&A Batch Mode as First-Class Alternative

The designer-dialog.md reference file (lines 239-269) defines batch mode as a complete alternative to interactive dialog, with its own file format, resume protocol, and answer parsing rules. This is not an afterthought -- it has the same level of specification as the interactive path. This dual-mode design is excellent prompt engineering because it acknowledges that the skill will be invoked in different user contexts (interactive session vs. asynchronous workflow) and provides clear instructions for both.
