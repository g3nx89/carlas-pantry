---
skill: feature-refinement
version: 3.0.0
analysis_lens: context-engineering-efficiency
analyst: claude-opus-4-6
date: 2026-03-01
fallback_criteria_used: true
skill_root: plugins/product-definition/skills/refinement
files_read:
  - SKILL.md (1,980 words / 374 lines / 17,117 bytes)
  - references/orchestrator-loop.md (2,282 words / 17,699 bytes)
  - references/stage-3-analysis-questions.md (2,310 words / 19,540 bytes)
  - references/stage-1-setup.md (1,933 words / 16,851 bytes)
total_reference_words: 18,863
total_reference_files: 16
severity_counts:
  critical: 0
  high: 2
  medium: 3
  low: 2
  info: 0
strengths: 3
---

# Context Engineering Efficiency Analysis: feature-refinement

**Evaluation criteria source:** Fallback criteria (Skill tool invocation for `customaize-agent:context-engineering` failed).

## Summary

The feature-refinement skill demonstrates a well-structured lean orchestrator pattern with a 1,980-word SKILL.md that sits precisely within the 1,500-2,000 word target for always-loaded content. The Reference Map with "Load When" guidance enables selective loading, and the hub-spoke architecture correctly separates always-loaded orchestration logic from on-demand stage references.

However, two HIGH-severity issues exist: Stage 1 runs inline and forces its 1,933-word reference file into the orchestrator's context alongside SKILL.md, nearly doubling the always-loaded footprint; and the orchestrator-loop.md reference (2,282 words) is also loaded at orchestration start, creating a combined always-loaded context of approximately 6,195 words before any stage coordinator is dispatched. Additionally, several reference files contain redundant content that duplicates SKILL.md sections, and attention-critical rules are partially diluted by mid-document placement of the Summary Contract example.

---

## Findings

### HIGH Severity

#### H1: Stage 1 Inline Execution Doubles Always-Loaded Context

**Category:** Token management / Progressive loading
**File:** `SKILL.md` (lines 157-161), `references/stage-1-setup.md`

**Current state:**
SKILL.md line 159 states: "Execute Stage 1 directly (no coordinator dispatch). Read and follow: `@$CLAUDE_PLUGIN_ROOT/skills/refinement/references/stage-1-setup.md`"

Because Stage 1 runs inline in the orchestrator, the orchestrator must load `stage-1-setup.md` (1,933 words / 16,851 bytes) into its own context during execution. Combined with SKILL.md (1,980 words) and orchestrator-loop.md (2,282 words, loaded at orchestration start per SKILL.md line 151), the orchestrator's effective always-loaded context at invocation is approximately 6,195 words (~24,800 tokens estimated) before any user data, state files, or stage summaries are injected.

The stage-1-setup.md file contains extensive AskUserQuestion JSON templates (lines 91-105, 136-149, 217-246, 272-286, 340-370, 378-393) that consume significant tokens but are only relevant for their specific conditional branches. An orchestrator executing the "resume from checkpoint" path still loads all the "new workflow" JSON templates.

**Recommendation:**
Consider splitting stage-1-setup.md into two files: a lean `stage-1-routing.md` (~400 words) for the detection/routing logic (Steps 1.1-1.4) that always runs, and `stage-1-initialization.md` (~1,500 words) for the workspace creation, mode selection, and panel composition (Steps 1.5-1.8) that only loads when WORKFLOW_MODE = NEW. This would reduce the always-loaded context by approximately 1,500 words for resume scenarios.

---

#### H2: orchestrator-loop.md Is Effectively Always-Loaded Despite Being a "Reference"

**Category:** Progressive loading strategy
**File:** `SKILL.md` (line 151), `references/orchestrator-loop.md`

**Current state:**
SKILL.md line 151 states: "Read and follow: `@$CLAUDE_PLUGIN_ROOT/skills/refinement/references/orchestrator-loop.md`" under the heading "Orchestrator Loop." The Reference Map (line 347) confirms: "Load When: Start of orchestration."

This 2,282-word file is loaded every invocation. It contains the dispatch template (lines 54-106), variable defaults table (lines 118-131), summary handling (lines 164-189), quality gate protocol (lines 195-244), iteration loop logic (lines 254-320), user pause handling (lines 422-454), and the rounds-digest template (lines 358-406). All of this loads simultaneously even though much of it is conditional:

- The Quality Gate Protocol (lines 195-244, ~300 words) only activates after Stages 3 and 5.
- The Rounds-Digest Template (lines 358-406, ~250 words) only activates after round 3.
- The Crash Recovery quick summary (lines 460-470) and User Pause Handling (lines 422-454) only activate conditionally.

**Recommendation:**
Extract the Quality Gate Protocol and Rounds-Digest Template into a separate `references/quality-gates.md` file (~550 words). Load it only after Stage 3 and Stage 5. This reduces the always-loaded orchestrator-loop.md by approximately 25%. The dispatch loop, variable defaults, and summary handling are genuinely always-needed and should remain.

---

### MEDIUM Severity

#### M1: Summary Contract Example Occupies Prime Attention Real Estate

**Category:** Attention placement
**File:** `SKILL.md` (lines 166-248)

**Current state:**
The Summary Contract section (lines 166-248) includes a full filled example (lines 196-226, 31 lines) and the Interactive Pause Schema (lines 228-248, 21 lines). Together, these 82 lines occupy the document's "middle zone" -- an area where LLM attention naturally diminishes compared to the beginning (Critical Rules) and end (Critical Rules reminder).

The Summary Contract definition itself (lines 171-194) is essential. However, the filled example and the Interactive Pause Schema are reference material that coordinators need, not the orchestrator. The orchestrator validates summaries but does not produce them -- it reads them.

**Recommendation:**
Move the filled example and Interactive Pause Schema to `references/orchestrator-loop.md` under a "Summary Contract Details" section (these are needed during dispatch template construction). Keep only the YAML schema and the path convention in SKILL.md. This saves approximately 50 lines (~350 words) from the always-loaded file, and positions the State Management section (currently line 251) closer to the document's center, improving attention on immutable user decisions and schema version rules.

---

#### M2: State Management Schema Duplicates What Coordinators Discover from the State File Itself

**Category:** Token management / Redundancy
**File:** `SKILL.md` (lines 250-305)

**Current state:**
The State Management section in SKILL.md includes a detailed nested structure definition (lines 272-305) showing the full `rounds` and `phases` YAML schema with example values. This 34-line block describes coordinator-written data structures. The orchestrator never writes these fields directly -- it reads them from coordinator summaries.

Coordinators receive the state file's YAML frontmatter in their dispatch prompt (orchestrator-loop.md line 94: "State File (frontmatter only)"). They learn the schema by reading the actual state file, not from SKILL.md.

**Recommendation:**
Replace the nested structure detail in SKILL.md with a 3-line summary: "Coordinators maintain `rounds` (per-round tracking) and `phases` (per-phase status) in state file frontmatter. See state file for current schema." This saves approximately 30 lines (~200 words) from SKILL.md without information loss.

---

#### M3: stage-3-analysis-questions.md Contains Full ThinkDeep Prompt Templates Inline

**Category:** Selective reference loading
**File:** `references/stage-3-analysis-questions.md` (lines 134-193)

**Current state:**
The ThinkDeep step content templates (COMPETITIVE, RISK, CONTRARIAN) span lines 134-193 (60 lines, ~350 words). The findings templates add another 5 lines at 190-193. These templates are only used in Complete and Advanced modes. In Standard and Rapid modes, Part A is skipped entirely (line 26: "IF ANALYSIS_MODE in {standard, rapid}: Skip Part A entirely").

When a Stage 3 coordinator is dispatched in Standard mode, it still loads these 65 lines of templates that will never execute. This file is the largest reference at 2,310 words.

**Recommendation:**
Extract the ThinkDeep prompt templates (STEP CONTENT TEMPLATES + FINDINGS TEMPLATES + PROBLEM_CONTEXT_TEMPLATE, lines 120-193) into a dedicated `references/thinkdeep-templates.md` file. The Stage 3 coordinator would load it conditionally: "IF ANALYSIS_MODE in {complete, advanced}: Also load `references/thinkdeep-templates.md`." This saves approximately 400 words from the Standard/Rapid mode context.

---

### LOW Severity

#### L1: Agent References Table Contains Model Assignments That Belong in Config

**Category:** Token management / Redundancy
**File:** `SKILL.md` (lines 309-322)

**Current state:**
The Agent References table (lines 310-321) lists each agent's Model assignment (sonnet/opus). This duplicates `config/requirements-config.yaml` -> `model_assignments`, which is the canonical source. If model assignments change in config, this table becomes stale.

**Recommendation:**
Remove the Model column from the Agent References table. Add a note: "Model assignments governed by `config/requirements-config.yaml` -> `model_assignments`." Saves 8 tokens per row (minor) but eliminates a staleness vector.

---

#### L2: Critical Rules Bookend Repetition Could Be More Targeted

**Category:** Attention placement
**File:** `SKILL.md` (lines 365-374)

**Current state:**
The ending Critical Rules reminder (lines 365-374) re-states 7 key points from the 27 rules defined in the opening section. This is a well-known attention reinforcement technique for LLMs. However, the selection of which 7 to repeat does not prioritize the rules most likely to be violated. For example, "No artificial question limits" (line 372) is repeated, but "Variable defaults -- never pass null or empty for required variables" (Rule 26, a common failure mode in template-based dispatch) is not.

**Recommendation:**
Revise the ending reminder to include the top violation-risk rules based on actual failure modes: (1) coordinators never talk to users, (2) variable defaults -- never pass null, (3) Stage 1 inline / others delegated, (4) REFLECTION_CONTEXT on RED loops, (5) quality gates are non-blocking, (6) user_decisions immutable, (7) MCP availability check before using PAL. Drop "no artificial question limits" since it is reinforced by config (`max_questions_total: null`).

---

## Strengths

### S1: SKILL.md Word Count Is Precisely Within Target

The SKILL.md file is 1,980 words -- essentially at the upper boundary of the 1,500-2,000 word target for always-loaded content. This demonstrates disciplined content curation. The file functions as a true dispatch table: stage list, critical rules, reference map, and summary contract -- with procedural detail correctly deferred to reference files.

---

### S2: Reference Map With "Load When" Guidance Enables Selective Loading

The Reference Map table (lines 345-361) explicitly pairs each reference file with a loading condition (e.g., "Dispatching Stage 3", "Any error condition", "PAL tool usage"). This is a direct implementation of progressive disclosure: metadata (SKILL.md) -> body (orchestrator-loop.md) -> references (on-demand stage files). The pattern enables Claude to load only the references relevant to the current execution path rather than consuming all 18,863 words across 16 reference files.

---

### S3: Coordinator Dispatch Template Minimizes Context Bleed

The coordinator dispatch template in orchestrator-loop.md (lines 54-106) explicitly scopes what each coordinator receives: only its stage reference file plus the shared references listed in the Stage Dispatch Profiles table (lines 44-50). The template also passes "State File (frontmatter only -- omit workflow log for context efficiency)" (line 93), explicitly choosing YAML frontmatter over the full state file body. This prevents context pollution from accumulated workflow logs reaching coordinators.
