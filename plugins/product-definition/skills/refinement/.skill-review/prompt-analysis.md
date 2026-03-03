---
lens: Prompt Engineering Quality
lens_id: prompt-engineering
skill_reference: feature-refinement
target: feature-refinement v3.0.0
target_path: /Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement
fallback_used: true
findings_count: 14
critical_count: 1
high_count: 3
medium_count: 5
low_count: 3
info_count: 2
---

# Prompt Engineering Quality Analysis: feature-refinement

## Summary

The feature-refinement skill is a sophisticated, well-structured 6-stage orchestrator for transforming product drafts into PRDs through iterative Q&A. The skill demonstrates strong prompt engineering in several areas: clear critical rules with bookend reinforcement, detailed variable default tables, and explicit coordinator dispatch templates. However, several findings impact LLM instruction effectiveness, ranging from one critical issue with contradictory guidance to high-severity concerns about instruction density and ambiguous conditional logic. The skill's greatest prompt engineering risk is its sheer volume of instructions across files, which increases the probability of Claude losing track of behavioral constraints during execution.

**Files analyzed:**
- `SKILL.md` (17,117 bytes) -- main orchestrator
- `references/orchestrator-loop.md` (17,699 bytes) -- dispatch loop, iteration, recovery
- `references/stage-3-analysis-questions.md` (19,540 bytes) -- analysis and question generation
- `references/option-generation-reference.md` (14,634 bytes) -- option/scoring algorithms
- `references/stage-1-setup.md` (16,851 bytes) -- inline setup instructions

---

## Findings

### 1. Contradictory Guidance on Coordinator User Interaction

**Severity:** CRITICAL
**Category:** Instruction clarity and unambiguity
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/references/stage-1-setup.md`

**Current state:** SKILL.md Rule 22 states: "Coordinators NEVER interact with users directly -- set `status: needs-user-input` in summary; orchestrator mediates ALL prompts via AskUserQuestion." Rule 23 states: "Stage 1 runs inline -- all other stages are coordinator-delegated." However, `stage-1-setup.md` contains multiple direct `AskUserQuestion` calls (Step 1.3 lock management, Step 1.4 state detection, Step 1.7 analysis mode selection, Step 1.7.5 panel composition). Since Stage 1 runs inline as part of the orchestrator, this is technically correct -- but the file header says "Stage 1: Setup & Initialization (Inline)" without explicitly stating "you ARE the orchestrator in this stage, so direct user interaction is permitted."

**Recommendation:** Add an explicit framing statement at the top of `stage-1-setup.md` immediately after the blockquote: "Because this stage runs inline (not as a coordinator dispatch), you interact with the user directly via `AskUserQuestion`. This is the ONE exception to the 'coordinators never talk to users' rule -- you are the orchestrator here, not a coordinator." This eliminates the cognitive dissonance a Claude instance would experience reading Rule 22 and then seeing direct user interaction instructions.

---

### 2. Instruction Density Exceeds Effective Prompt Window for Coordinators

**Severity:** HIGH
**Category:** LLM instruction effectiveness
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/references/stage-3-analysis-questions.md`

**Current state:** The Stage 3 coordinator receives: the stage reference file (19,540 bytes), checkpoint-protocol.md, error-handling.md, config YAML, option-generation-reference.md (14,634 bytes), plus variable context (draft content, ThinkDeep insights, panel config, reflection context, prior stage summaries, state frontmatter). The option-generation-reference alone is ~14K bytes of scoring algorithms, merging logic, and pipeline diagrams. Much of this detail (e.g., the full "Question Generation Pipeline" ASCII art diagram in Section 6) is design documentation explicitly marked as "not needed during execution."

**Recommendation:** Split `option-generation-reference.md` into two files: (1) `option-scoring-rules.md` containing Sections 1-4 (the runtime-critical scoring, merging, and priority logic), and (2) keep Sections 5-6 (example format + design overview) as a separate `option-generation-design.md` loaded only by the synthesis agent or for debugging. This reduces coordinator context by approximately 5K bytes of non-actionable content. Alternatively, move the Section 6 pipeline diagram to `references/README.md` where it serves as architectural documentation rather than runtime instruction.

---

### 3. Ambiguous Conditional Syntax in Dispatch Template

**Severity:** HIGH
**Category:** Prompt structure and logical flow
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/references/orchestrator-loop.md`

**Current state:** The coordinator dispatch template (lines 54-106) uses a custom conditional syntax:
```
{IF REFLECTION_CONTEXT is non-empty (Stage 3 re-dispatch after RED validation):}
## Reflection from Previous Round
{REFLECTION_CONTEXT}

{IF stage needs checkpoint-protocol:}
- Checkpoint protocol: @$CLAUDE_PLUGIN_ROOT/...
{IF stage needs error-handling:}
- Error handling: @$CLAUDE_PLUGIN_ROOT/...
```
These `{IF ...}` blocks have no closing delimiters (`{END IF}` or `{/IF}`), making scope ambiguous. A Claude instance must infer where each conditional block ends. The nested conditions for shared references are particularly unclear -- does "IF stage needs config YAML" include or exclude the extra refs line below it?

**Recommendation:** Add explicit `{END IF}` closures to every conditional block. Better yet, adopt the pattern already used in `stage-1-setup.md` lines 307-308 which uses `{IF PRESET_OVERRIDE:}...{END IF}` with clear delimiters. Apply this consistently across all dispatch templates. Example:
```
{IF REFLECTION_CONTEXT is non-empty:}
## Reflection from Previous Round
{REFLECTION_CONTEXT}
{END IF}
```

---

### 4. Scoring Algorithm is Descriptive Rather Than Executable

**Severity:** HIGH
**Category:** Degrees of freedom (specificity vs over-constraint)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/references/option-generation-reference.md`

**Current state:** The recommendation scoring algorithm (Section 2) presents a 100-point scoring system with four dimensions (PRD Completeness, ThinkDeep Alignment, Multi-Perspective, Industry Practice), each worth 0-25 points with specific sub-criteria. However, this is presented to MPA panel member agents who are generating questions and options. The sub-criteria are qualitative descriptions ("Does this option provide clear PRD content? (+5)") not quantitative measures. An LLM cannot meaningfully distinguish between a +5 and +0 on "Does it resolve ambiguity in the draft?" -- it will produce plausible-looking numbers that are not reproducible or calibrated.

**Recommendation:** Replace the point-based scoring with a rubric-based approach that maps to the star ratings directly. Instead of asking agents to compute 100-point scores, provide behavioral anchors for each star level:
- 5 stars: "Option directly addresses a convergent ThinkDeep insight, aligns with industry best practices, and produces unambiguous PRD content"
- 4 stars: "Option is strong but has one notable trade-off or lacks ThinkDeep alignment"
- 3 stars: "Viable option with meaningful trade-offs; user context needed to evaluate"
- 2 stars: "Niche or risky approach; only appropriate in specific circumstances"
- 1 star: "Included for completeness; significant downsides outweigh benefits"

This gives Claude clear behavioral guidance rather than pseudo-quantitative math that will be performed inconsistently.

---

### 5. Missing Explicit Instruction for Panel Member Agent Variable Resolution

**Severity:** MEDIUM
**Category:** Instruction clarity and unambiguity
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/references/stage-3-analysis-questions.md`

**Current state:** Step 3B.3 dispatches panel member agents with a prompt that includes "Template: @$CLAUDE_PLUGIN_ROOT/agents/requirements-panel-member.md" and a "Variable Injection" section listing 15 variables. However, there is no explicit instruction telling the dispatched agent HOW to apply variables to the template. The prompt says "Apply these variables to the template" but does not specify whether variables are `{VARIABLE_NAME}` placeholders in the template, whether to substitute inline, or whether the template itself contains instructions for variable usage.

**Recommendation:** Add a one-line framing instruction: "The template uses `{VARIABLE_NAME}` placeholders. Replace each placeholder with the corresponding value from the Variable Injection list below. If a variable has no value, use the text 'Not specified'." This removes ambiguity about the variable substitution mechanism.

---

### 6. Pseudocode Dispatch Loop Mixes Declarative and Imperative Styles

**Severity:** MEDIUM
**Category:** Prompt structure and logical flow
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/references/orchestrator-loop.md`

**Current state:** The dispatch loop (lines 10-34) uses a pseudocode style that mixes declarative routing logic ("IF waiting_for_user == true: ROUTE to the stage that set the pause") with imperative execution instructions ("READ coordinator summary / HANDLE summary status"). The "FOR each stage in dispatch order" block at line 23 implies sequential iteration, but stages can be skipped, paused, or looped -- the FOR loop model is misleading because control flow is not strictly sequential (Stage 5 can loop back to Stage 3).

**Recommendation:** Replace the FOR loop with explicit state-machine transitions. For example:
```
DETERMINE next_stage from state:
  IF waiting_for_user: next_stage = pause_stage
  ELIF current_stage incomplete: next_stage = current_stage
  ELSE: next_stage = first_incomplete_stage(1..6)

EXECUTE next_stage:
  [dispatch or inline logic]

AFTER execution:
  READ summary -> HANDLE status -> UPDATE state -> LOOP (goto DETERMINE)
```
This state-machine framing accurately models the non-linear control flow and prevents Claude from treating stages as a simple sequential pipeline.

---

### 7. ThinkDeep Call Count Discrepancy Between SKILL.md and Stage 3

**Severity:** MEDIUM
**Category:** Instruction clarity and unambiguity
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/SKILL.md`

**Current state:** SKILL.md Analysis Modes table (line 86) states Complete mode uses "27 calls (3x3x3)" and Advanced uses "18 calls (2x3x3)". Rule 14 mentions "grok-4 for Variety" in PAL Consensus and ThinkDeep. Stage 3 reference (line 57) says to use "model IDs from `config/requirements-config.yaml`" for ThinkDeep models. If the config file ever changes the number of models from 3, the hardcoded "27" and "18" in SKILL.md become wrong. This creates a source-of-truth conflict: SKILL.md says 27, but the actual count depends on config.

**Recommendation:** Change the Analysis Modes table to use formulas instead of hardcoded counts: "P x M x S calls" where P = perspectives, M = models from config, S = steps per call. Add a note: "With default config (3 perspectives x 3 models x 3 steps = 27 for Complete, 2 x 3 x 3 = 18 for Advanced)." This keeps the table readable while making the dependency on config explicit.

---

### 8. Step 1.7.5 Numbering Creates Fragile Cross-References

**Severity:** MEDIUM
**Category:** Prompt structure and logical flow
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/references/stage-1-setup.md`

**Current state:** The panel composition step is numbered "Step 1.7.5" (line 249), inserted between Step 1.7 (Analysis Mode Selection) and Step 1.8 (State Initialization). This fractional numbering signals a feature that was added after initial design. While functional, it breaks the clean integer sequence and makes "proceed to Step 1.8" references fragile -- any future insertion between 1.7 and 1.8 would require "Step 1.7.25" or a full renumber.

**Recommendation:** Renumber the steps in stage-1-setup.md to use clean integers: current 1.7 becomes 1.7, current 1.7.5 becomes 1.8, and current 1.8 becomes 1.9. Then grep all reference files for "Step 1.8" and update cross-references. This follows the CLAUDE.md instruction: "When inserting a new numbered section, all subsequent section numbers shift. After any section insert, grep ALL reference files for the old section numbers and update them."

---

### 9. "CRITICAL RULES REMINDER" Sections Vary in Content Across Files

**Severity:** MEDIUM
**Category:** Use of examples vs. rules for conveying behavior
**Files:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/SKILL.md`, `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/references/stage-3-analysis-questions.md`, `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/references/stage-1-setup.md`

**Current state:** Each file ends with a "CRITICAL RULES REMINDER" section that restates a subset of rules. SKILL.md restates 7 rules (lines 367-374). Stage 3 restates 4 rules (lines 525-529). Stage 1 restates 3 rules (lines 484-487). The restated rules are different subsets, selected per-file. While the intent is good (bookend reinforcement), the varying content means a coordinator reading Stage 3 sees "Continuation IDs are PER-CHAIN" as a critical rule but not "Coordinators NEVER talk to users directly" -- even though that rule is equally critical for the coordinator.

**Recommendation:** Standardize the CRITICAL RULES REMINDER pattern: every coordinator-facing file should include two categories: (1) **Universal rules** -- the 2-3 rules that apply to ALL coordinators (no user interaction, must write summary, must update state), restated identically in every file, and (2) **Stage-specific rules** -- rules unique to that stage. This ensures no coordinator misses a universal constraint while keeping stage-specific reinforcement.

---

### 10. Lock Management Race Condition Not Addressed

**Severity:** LOW
**Category:** Edge cases and decision points
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/references/stage-1-setup.md`

**Current state:** Step 1.3 (Lock Management) checks lock age and either removes stale locks or asks the user. However, there is no instruction for what happens if two CLI sessions invoke the skill simultaneously -- between reading the lock file and creating a new one, another session could create its own lock. The instructions treat lock management as single-threaded.

**Recommendation:** Add a brief note: "Lock management assumes single-session execution. If a user runs the skill in two terminals simultaneously, both sessions will acquire locks. This is accepted as a low-probability edge case -- the state file's last-write-wins behavior may cause data loss but will not corrupt the workflow." This acknowledges the limitation explicitly rather than leaving Claude to reason about it.

---

### 11. Example Summary in SKILL.md Uses Hardcoded Panel Member IDs

**Severity:** LOW
**Category:** Use of examples vs. rules for conveying behavior
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/SKILL.md`

**Current state:** The example filled Stage 3 summary (lines 196-226) hardcodes `panel_member_ids: ["product-strategist", "ux-researcher", "functional-analyst"]`. Since the skill's core innovation is a DYNAMIC panel system where member IDs come from config presets (product-focused, consumer, marketplace, enterprise, custom), this example could anchor Claude toward always using these three IDs rather than the panel config.

**Recommendation:** Add a comment to the example: `# Example uses product-focused preset -- actual IDs come from requirements/.panel-config.local.md`. Alternatively, use abstract IDs like `["member-1", "member-2", "member-3"]` with a note that real IDs are sourced from panel config. The former approach is preferred as it preserves concreteness while flagging the dynamic nature.

---

### 12. Rapid Mode Agent Dispatch Duplicates Default Configuration Inline

**Severity:** LOW
**Category:** Degrees of freedom (specificity vs over-constraint)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/references/stage-3-analysis-questions.md`

**Current state:** The rapid mode dispatch (lines 384-411) hardcodes the product-strategist's role, perspective, focus areas, PRD section targets, domain guidance, and all 5 analysis steps directly in the dispatch prompt. This duplicates whatever is defined for the product-strategist perspective in `config/requirements-config.yaml -> panel.available_perspectives`. If the config changes, this hardcoded block becomes stale.

**Recommendation:** Replace the hardcoded values with a reference: "Load the `product-strategist` perspective from `config/requirements-config.yaml -> panel.available_perspectives.product-strategist` and inject its fields as variables." This keeps rapid mode consistent with config and eliminates a maintenance burden. If the concern is context efficiency (avoiding a config read), add a comment: "These values mirror the product-strategist perspective in config. If config changes, update here too."

---

### 13. Well-Designed Variable Defaults Table

**Severity:** INFO
**Category:** Prompt structure and logical flow
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/references/orchestrator-loop.md`

**Current state:** The Variable Defaults table (lines 118-134) lists every dispatch variable with its default value and a rationale column explaining WHY that default was chosen. The precedence rule ("State file values always override defaults") is stated once, clearly.

**Observation:** This is an exemplary prompt engineering pattern. The rationale column is particularly effective because it gives Claude the reasoning behind defaults, enabling it to make correct decisions in edge cases not explicitly covered. The explicit "never pass null or empty for required variables" rule prevents a common failure mode in multi-stage dispatch systems.

---

### 14. Effective Use of Bookend Critical Rules Pattern

**Severity:** INFO
**Category:** LLM instruction effectiveness
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement/SKILL.md`

**Current state:** SKILL.md places 27 critical rules at the top (lines 16-54) and restates key reminders at the bottom (lines 366-374). This "High Attention Zone -- Start/End" bookend pattern leverages both primacy and recency effects in LLM attention.

**Observation:** The bookend pattern is well-executed here. The start section has numbered rules (making them referenceable from other files), while the end section uses a shorter bullet-point format for quick reinforcement. This asymmetry is intentional and effective -- the detailed version comes first for comprehension, the abbreviated version comes last for recall.

---

## Strengths

### 1. Comprehensive Graceful Degradation Design

The skill handles MCP tool unavailability with a well-structured degradation hierarchy. Rules 18-21 in SKILL.md define fallback behavior for PAL, Sequential Thinking, and Research MCP. Stage 1 probes tool availability and records results in state. The Analysis Modes table clearly maps which modes require which MCP tools. The Variable Defaults table defaults PAL and ST availability to `false` (safe fallback). This multi-layered approach means Claude will never attempt to call unavailable tools -- every degradation path is explicitly defined with concrete alternative behavior.

### 2. Summary Contract as a Structured Communication Protocol

The summary contract (SKILL.md lines 166-248) is an outstanding prompt engineering pattern for multi-agent workflows. By defining a strict YAML schema that all coordinators must write, it creates a machine-readable interface between the orchestrator and its subagents. The `flags` object is particularly well-designed -- it carries stage-specific metadata (e.g., `thinkdeep_completion_pct`, `panel_member_ids`) without requiring the orchestrator to parse free-text output. The Interactive Pause Schema with `pause_type` and `next_action_map` gives coordinators a structured vocabulary for requesting user input without breaking the "no direct user interaction" rule. This pattern could be extracted and reused across other skills in the plugin ecosystem.
