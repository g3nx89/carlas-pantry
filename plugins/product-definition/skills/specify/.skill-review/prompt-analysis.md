---
lens: "Prompt Engineering Quality"
lens_id: "prompt"
skill_reference: "customaize-agent:prompt-engineering"
target: "feature-specify"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify"
fallback_used: true
findings_count: 14
critical_count: 1
high_count: 3
medium_count: 5
low_count: 3
info_count: 2
---

# Prompt Engineering Quality Analysis: feature-specify

## Summary

The feature-specify skill is a sophisticated 7-stage orchestrator for guided feature specification with CLI multi-stance validation, Figma integration, and V-Model test strategy generation. The skill demonstrates strong architectural discipline with its lean orchestrator pattern, explicit state management, and comprehensive error handling. However, several prompt engineering issues reduce the likelihood that a Claude instance would execute the workflow correctly on first attempt without additional context.

Key areas of concern: conflicting rule numbers create ambiguity in cross-references, the coordinator dispatch template relies on conditional blocks that lack explicit rendering instructions, and several decision points use implicit knowledge rather than explicit criteria. The skill's reference file system is well-organized but some critical behavioral details are split across files in ways that could cause coordinators to miss them.

**Files analyzed:**
- `SKILL.md` (main orchestrator)
- `references/orchestrator-loop.md` (dispatch loop, variable defaults, iteration)
- `references/stage-2-spec-draft.md` (spec draft, MPA-Challenge, gates)
- `references/stage-4-clarification.md` (edge cases, clarification, triangulation)
- `references/clarification-protocol.md` (file-based Q&A, answer parsing)
- `references/error-handling.md` (error recovery, degradation)

---

## Findings

### 1. [CRITICAL] Duplicate Rule Number 17 Creates Ambiguity

**Category:** Instruction clarity and unambiguity

**Current state:** In `SKILL.md` lines 39-40, rule 17 appears twice:
```
17. **No CLI Substitution**: If a CLI dispatch fails, **DO NOT** substitute with another CLI.
17b. **Spec Content Inline**: NEVER pass local file paths to CLI dispatch prompt files.
```
The "CRITICAL RULES" section at the end (line 293) references "Rules 1-28" but the actual numbering goes 1-17, 17b, 18-28. This means the set has 29 entries but claims 28.

**Recommendation:** Renumber rule 17b to 18 and shift all subsequent rules up by one (current 18 becomes 19, etc.). Update the closing reference to "Rules 1-29" or whatever the final count is. Alternatively, merge 17 and 17b into a single rule since they both concern CLI dispatch content handling. Consistent numbering is essential because coordinators may receive instructions referencing specific rule numbers.

**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/SKILL.md`

---

### 2. [HIGH] Coordinator Dispatch Template Uses Pseudo-Conditional Syntax Without Rendering Instructions

**Category:** LLM instruction effectiveness

**Current state:** In `orchestrator-loop.md` lines 75-82, the dispatch template includes conditional blocks using a pseudo-template syntax:
```
{IF stage needs checkpoint-protocol:}
- Checkpoint protocol: @$CLAUDE_PLUGIN_ROOT/...
{IF stage needs error-handling:}
- Error handling: @$CLAUDE_PLUGIN_ROOT/...
{IF stage has extra refs:}
- {extra_ref}: @$CLAUDE_PLUGIN_ROOT/...
```
This syntax is not a standard template language. The orchestrator (Claude) must interpret these conditions and manually construct the prompt string. However, there is no explicit instruction telling the orchestrator to evaluate these conditions and produce the final prompt. An LLM could plausibly pass these conditional markers through literally into the coordinator prompt.

**Recommendation:** Add an explicit instruction block before or after the template, such as:
```
### Template Rendering
When constructing the coordinator prompt from the template above, evaluate all
{IF ...} conditions using the Stage Dispatch Profiles table. Replace each
conditional block with its content if the condition is true, or remove it
entirely if false. The final prompt passed to Task() must contain NO {IF ...}
markers — only resolved content.
```
Alternatively, provide a fully resolved example for one stage (e.g., Stage 2) to demonstrate what the final prompt should look like.

**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/references/orchestrator-loop.md`

---

### 3. [HIGH] Step Ordering Conflict in Stage 2 — Step 2.1b Follows Step 2.2

**Category:** Prompt structure and logical flow

**Current state:** In `stage-2-spec-draft.md`, the step ordering is:
- Step 2.1: Launch BA Agent (line 23)
- Step 2.2: Parse BA Response (line 64)
- Step 2.1b: Generate Initial RTM (line 73)
- Step 2.3: MPA-Challenge CLI Dispatch (line 104)

Step 2.1b appears after Step 2.2 in the file, but its numbering suggests it should logically follow Step 2.1 (before parsing). Per the project's own CLAUDE.md rule: "Step ordering: Physical order in the file MUST match logical execution order — coordinators read top-to-bottom regardless of step numbers."

A coordinator reading top-to-bottom would execute Step 2.2 (Parse BA Response) before Step 2.1b (Generate Initial RTM), which appears to be the intended order. But the "2.1b" numbering creates cognitive dissonance — it implies the step belongs between 2.1 and 2.2. This ambiguity could cause a coordinator to reorder steps based on numbering rather than file position.

**Recommendation:** Renumber to match physical order: Step 2.1 -> Step 2.2 -> Step 2.3 (RTM) -> Step 2.4 (MPA-Challenge) -> Step 2.5 (Gate 1) -> Step 2.6 (Gate 2) -> Step 2.7 (Checkpoint). This eliminates the "2.1b" suffix and aligns numbering with execution order.

**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/references/stage-2-spec-draft.md`

---

### 4. [HIGH] Semantic Deduplication Threshold Stated Without Actionable Criteria

**Category:** Degrees of freedom (under-specified)

**Current state:** In `stage-4-clarification.md` line 352:
```
**Semantic deduplication** against existing questions (similarity threshold: 0.85)
```
This specifies a numeric similarity threshold of 0.85, but Claude does not have a built-in similarity score function. There is no instruction on how to compute "0.85 similarity" — whether this means cosine similarity of embeddings, word overlap ratio, or semantic judgment. A Claude instance would need to interpret this as a qualitative heuristic, but the numeric precision implies a quantitative measure.

**Recommendation:** Replace the numeric threshold with actionable qualitative criteria:
```
**Semantic deduplication** against existing questions:
- DUPLICATE (discard): Questions that ask about the same scenario, edge case,
  or requirement, even if worded differently
- RELATED (keep both): Questions that share a domain but ask about distinct
  aspects or scenarios
- UNIQUE (keep): No existing question covers this topic

When in doubt, keep the question — false negatives (missing a needed question)
are worse than false positives (asking a redundant one).
```

**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/references/stage-4-clarification.md`

---

### 5. [MEDIUM] Self-Critique Score Threshold Referenced But Evaluation Rubric Not Provided

**Category:** Degrees of freedom (under-specified)

**Current state:** In `orchestrator-loop.md` line 231:
```
1. Self-critique score >= 16/20 (config threshold)
```
And in `stage-2-spec-draft.md` line 69:
```
- `self_critique_score`: N/20
```
The BA agent produces a self-critique score out of 20, and the orchestrator checks it against a threshold. However, no rubric or scoring criteria for this self-critique are defined in any of the analyzed files. The BA agent must invent its own 20-point scale, which could vary significantly between invocations.

**Recommendation:** Either define the self-critique rubric (e.g., 4 criteria at 5 points each with explicit descriptions per level), or reference the specific template file that contains it (e.g., `@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-spec-draft.md`). If the rubric lives in the BA prompt template, add a note in the orchestrator-loop quality gate section: "Rubric defined in `ba-spec-draft.md` — scoring criteria are: [brief list]."

**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/references/orchestrator-loop.md`

---

### 6. [MEDIUM] Inconsistent Gate Terminology — "Gate 1" / "Gate 2" vs. Config Reference Naming

**Category:** Instruction clarity and unambiguity

**Current state:** In `SKILL.md` line 73-74, the config reference uses:
```
| CLI eval GREEN threshold | `thresholds.pal.green` | 16/20 |
| CLI eval YELLOW threshold | `thresholds.pal.yellow` | 12/20 |
```
The config path uses `pal` (the old PAL/MCP terminology), while the rest of the skill uses "CLI" terminology throughout. Rule 25 in SKILL.md line 301 states: "CLI dispatch replaces PAL MCP — `CLI_AVAILABLE` replaces `PAL_AVAILABLE` everywhere." This config path appears to be a leftover from the PAL-to-CLI migration.

**Recommendation:** Rename the config path from `thresholds.pal.green` to `thresholds.cli_eval.green` (and similarly for yellow) in both the config YAML file and the SKILL.md reference table. This prevents confusion when a coordinator reads the config and encounters `pal` terminology that has been deprecated everywhere else.

**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/SKILL.md`

---

### 7. [MEDIUM] Implied But Unstated Coordinator Context Window Assumption

**Category:** LLM instruction effectiveness

**Current state:** The dispatch template in `orchestrator-loop.md` lines 54-99 loads the stage reference file, shared references, prior stage summaries, and state file frontmatter into a single coordinator prompt. For a complex feature with multiple iterations, this could include:
- Stage reference file (7-22K bytes)
- checkpoint-protocol.md (1.6K)
- error-handling.md (5.4K)
- config YAML
- cli-dispatch-patterns.md (13.5K, for Stages 2/4/5)
- All prior stage summaries
- State file frontmatter

There is no guidance on what to do if the total context approaches token limits, nor any instruction to truncate or summarize prior stage summaries beyond the 500/1000 char limits on individual summaries.

**Recommendation:** Add a "Context Budget" section to `orchestrator-loop.md` that specifies:
1. Priority order for context inclusion (stage reference > config > shared refs > summaries > state)
2. A maximum total context guideline (e.g., "coordinator prompt should not exceed 40K tokens")
3. Instructions for summarizing or truncating if the budget is exceeded (e.g., "include only the 2 most recent stage summaries if total exceeds budget")

**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/references/orchestrator-loop.md`

---

### 8. [MEDIUM] Stage 4 Figma Mock Gap Flow Has Ambiguous Exit Path

**Category:** Edge cases and decision points

**Current state:** In `stage-4-clarification.md` Step 4.0.2, when the user selects "Create mocks first":
```
2. Return `status: needs-user-input` — orchestrator exits workflow with instructions:
```
The instructions tell the user to run three separate commands (`/meta-skills:figma-console-mastery`, `/product-definition:design-handoff`, `/product-definition:specify`). However, it is unclear whether the orchestrator should:
(a) Fully terminate the workflow (release lock, set status to incomplete), or
(b) Keep the lock and state in a paused position for re-entry.

The `status: needs-user-input` suggests (b), but the instructions say "exits workflow" which suggests (a). If the lock is held, the user's other commands may fail because the lock prevents concurrent access.

**Recommendation:** Add explicit lock and state instructions:
```
**If "Create mocks first":**
1. Write figma-briefs-index.md (as current)
2. Release lock (this is a multi-session exit, not a pause)
3. Update state: current_stage = 4, stage_status = "awaiting_figma_mocks"
4. Return status: completed (not needs-user-input — workflow exits cleanly)
5. When user re-runs /specify, Stage 1 detects state and resumes at Stage 4
```

**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/references/stage-4-clarification.md`

---

### 9. [MEDIUM] RESUME_CONTEXT Variable in BA Dispatch Prompt Undefined

**Category:** Degrees of freedom (under-specified)

**Current state:** In `stage-2-spec-draft.md` line 30:
```
{RESUME_CONTEXT}
```
This variable appears in the BA agent dispatch prompt but is never defined in the variable list, the variable defaults table in `orchestrator-loop.md`, or the Stage 2 coordinator's expected context. There is no guidance on what to populate it with, when it should be non-empty, or what its default value should be.

**Recommendation:** Either:
(a) Define `RESUME_CONTEXT` in the orchestrator-loop variable defaults table with a clear description (e.g., "Empty string on first run. On re-entry after gate rejection, contains the gate feedback and user's decision."), or
(b) Remove it from the template if it is vestigial, replacing it with an explicit conditional block that includes gate feedback when `ENTRY_TYPE == "re_entry_after_user_input"`.

**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/references/stage-2-spec-draft.md`

---

### 10. [LOW] Redundant Critical Rules Sections in Reference Files

**Category:** Use of examples vs. rules (redundancy)

**Current state:** Each reference file contains both a "CRITICAL RULES" section at the top and a "CRITICAL RULES REMINDER" at the bottom. These are duplicates of rules already stated in `SKILL.md`. For example, `stage-4-clarification.md` has 7 critical rules at the top (lines 22-30) and repeats 8 rules at the bottom (lines 517-524), with slight wording differences and an extra rule ("Figma mock gaps: generate FSBs first") not present in the top section.

**Recommendation:** The High Attention Zone bookending pattern (rules at start and end) is documented as intentional in CLAUDE.md. The issue is content drift between the two instances. Ensure the top and bottom rule lists are identical in both count and wording. In `stage-4-clarification.md`, the bottom section adds "Figma mock gaps" and "NEVER interact with users directly — except Step 4.0" which are not in the top section. Either add these to the top, or remove them from the bottom to maintain parity.

**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/references/stage-4-clarification.md`

---

### 11. [LOW] Haiku Agent Reference Without Model Assignment Validation

**Category:** Instruction clarity and unambiguity

**Current state:** In `stage-2-spec-draft.md` line 143:
```
**Synthesize** findings using haiku agent (union_with_dedup strategy).
```
This references a "haiku agent" for synthesis but does not specify which agent definition file to use, what prompt to provide, or how to dispatch it. The Agent References table in `SKILL.md` lists 5 agents (business-analyst, design-brief-generator, gap-analyzer, qa-strategist, gate-judge) — none named "haiku agent." The model tier table in `config/specify-config.yaml` is referenced but not loaded.

**Recommendation:** Either:
(a) Name the specific agent file and provide dispatch instructions (e.g., "Dispatch `gate-judge` agent in haiku mode with union_with_dedup synthesis strategy"), or
(b) If no dedicated agent exists for synthesis, specify that the coordinator should perform synthesis inline using a defined procedure rather than referencing an undefined agent.

**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/references/stage-2-spec-draft.md`

---

### 12. [LOW] Answer Parsing Logic Has Contradictory Blank Handling

**Category:** Edge cases and decision points

**Current state:** In `clarification-protocol.md` lines 150-153:
```
IF "Your answer" field is non-empty:
    answer = user's text
    # Check if answer matches recommendation
    IF answer matches option 1 text OR is blank:
        user_chose_recommended = true
```
The outer condition checks `non-empty`, but the inner condition checks `is blank`. If the answer is non-empty, it cannot also be blank. This dead code path will not cause a runtime error, but it signals unclear thinking in the parsing logic that could confuse a Claude coordinator.

**Recommendation:** Remove the `OR is blank` clause from the inner condition, since it is unreachable:
```
IF answer matches option 1 text:
    user_chose_recommended = true
```

**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/references/clarification-protocol.md`

---

### 13. [INFO] Effective Use of Progressive Disclosure Through Reference Files

**Category:** Prompt structure and logical flow

**Current state:** The skill uses a lean orchestrator pattern where `SKILL.md` serves as a dispatch table under 300 lines of core logic, with detailed procedural content pushed to 16 reference files. Each reference file has a `Load When` condition in the Reference Map table, ensuring coordinators load only what they need.

This is an exemplary application of progressive disclosure for LLM context management — coordinators receive focused, stage-relevant instructions rather than the full 150K+ bytes of reference material.

**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/SKILL.md`

---

### 14. [INFO] Well-Designed File-Based Q&A Pattern With BA Recommendations

**Category:** LLM instruction effectiveness

**Current state:** The clarification protocol in `clarification-protocol.md` implements a sophisticated offline Q&A pattern where:
- Every question includes a BA recommendation with rationale (Rule 6)
- Blank answers default to the recommendation (reducing user friction)
- Auto-resolved questions include citations with exact quotes
- Override fields allow users to reject auto-resolutions
- The parsing logic handles four distinct response types

This pattern is well-suited for LLM-mediated workflows because it provides strong defaults while preserving user agency. The structured format with explicit sections (`Auto-Resolved`, `Requires Your Input`) and consistent question templates makes parsing reliable.

**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/references/clarification-protocol.md`

---

## Strengths

### 1. Comprehensive Variable Defaults With Rationale

The `orchestrator-loop.md` Variable Defaults table (lines 110-126) assigns every dispatch variable a fallback value with a rationale column explaining why that default was chosen. The precedence rule ("State file values override defaults") is explicit. The two required variables (`FEATURE_DIR`, `FEATURE_NAME`) are marked with "MUST be set — abort if missing" rather than given silent defaults. This pattern prevents null/empty variable injection and makes the orchestrator's decision logic transparent and auditable.

### 2. Layered Error Handling With Severity-Appropriate Responses

The `error-handling.md` file defines error recovery procedures that scale appropriately with severity:
- CLI failures: graceful degradation with user notification, no substitution (preserving multi-model variety)
- Gate failures: conservative default (YELLOW, not GREEN), user consulted
- Mandatory output failures (design-brief, design-supplement): retry once, then hard fail
- Optional output failures (test-strategy): retry once, then offer user choice

Each procedure specifies the exact state file update, user notification format, and recovery path. The "never substitute CLIs" rule (preventing the common LLM tendency to work around failures creatively) demonstrates awareness of LLM behavior patterns.

### 3. Immutable User Decisions as Anti-Hallucination Safeguard

The repeated emphasis on `user_decisions` immutability (SKILL.md Rules 1-2, orchestrator-loop, clarification-protocol) serves as an effective anti-hallucination guard. By requiring coordinators to check `user_decisions.clarifications` before generating questions and marking all decisions as immutable once recorded, the skill prevents the common LLM failure mode of re-asking resolved questions or overwriting user choices with its own preferences. The RTM disposition tracking extends this pattern to requirements traceability decisions.
