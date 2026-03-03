---
target_skill: "feature-refinement"
target_path: "plugins/product-definition/skills/refinement"
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
overall_score: "2.6/5.0"
findings_total: 55
findings_critical: 3
findings_high: 14
findings_medium: 20
findings_low: 11
findings_info: 7
---

# Skill Review Report: feature-refinement

> **How to use this report:** Start with the Modification Plan table — it lists the 15 highest-impact changes ordered by priority then effort. Detailed Findings provide context (File/Current/Recommendation) for each plan item. Finding IDs (F-NNN) cross-reference between sections. LOW-priority items appear in Additional Improvements.

## Executive Summary

The feature-refinement skill (v3.0.0) is a 375-line SKILL.md orchestrating a 6-stage PRD generation workflow with 16 reference files totaling ~170KB. The overall quality score is **2.6/5.0 (Adequate)** — the skill is functional and architecturally mature, but has notable gaps across multiple dimensions. The top concern is an **unbounded iteration loop** between Stages 3-5 with no stagnation detection and implicit gap-significance criteria, creating a risk of circular refinement. The top strength is the **dynamic MPA panel system** (v3.0.0) that composes domain-specialized question generation at runtime without hardcoded agents — a genuinely innovative pattern for multi-perspective analysis.

## Scores by Lens

| Lens | Score | Key Finding |
|------|-------|-------------|
| Structure & Progressive Disclosure | 3/5 | Frontmatter lacks trigger phrases for auto-discovery |
| Prompt Engineering Quality | 2/5 | Contradictory user interaction guidance between Rule 22 and Stage 1 |
| Context Engineering Efficiency | 3/5 | Stage 1 inline + orchestrator-loop.md doubles always-loaded context |
| Writing Quality & Conciseness | 3/5 | Redundant emphasis stacking inflates word count ~15-20% |
| Overall Effectiveness | 2/5 | ThinkDeep cascade failures degrade question quality silently |
| Reasoning & Decomposition | 2/5 | Unbounded iteration loop with no stagnation detection |
| Architecture & Coordination | 3/5 | Stage 3 coordinator accumulates 27 ThinkDeep responses in single context |

**Overall: 2.6/5.0** — Adequate

> **Scoring method:** Per-lens scores use the first-match severity table from `synthesis-rules.md` (e.g., 0 critical + 2+ high → 3/5). Overall score is a weighted average using `config/skill-analyzer-config.yaml` weights: structure 0.20, prompt 0.15, context 0.15, writing 0.10, effectiveness 0.15, reasoning 0.15, architecture 0.10. Four lenses used fallback criteria (generic evaluation questions) because their corresponding skills were not installed; findings from these lenses may be less precisely calibrated than findings from the 3 lenses with installed skills (Structure, Writing, Architecture).

Score interpretation:
- 4.5-5.0: Excellent — production-ready, minimal improvements needed
- 3.5-4.4: Good — solid skill with some improvement opportunities
- 2.5-3.4: Adequate — functional but has notable quality gaps
- 1.5-2.4: Needs Work — significant issues affecting effectiveness
- 1.0-1.4: Poor — fundamental problems requiring major revision

## Modification Plan

| # | Priority | Action | File | Section | Effort | Findings |
|---|----------|--------|------|---------|--------|----------|
| 1 | CRITICAL | Add explicit Stage 1 exception to Rule 22: "Stage 1 runs inline as orchestrator — uses AskUserQuestion directly. Rules 22-23 apply to Stages 2-6 only." | SKILL.md, stage-1-setup.md | Critical Rules (line 48), header | S | F-001 |
| 2 | CRITICAL | Add stagnation detector: if validation score hasn't improved by N points over 2 consecutive RED rounds, present user with explicit "stagnation detected" decision. Define quantified gap-significance thresholds in Stage 4 Step 4.7 | orchestrator-loop.md, stage-4-response-analysis.md | Reflexion Step, Step 4.7 | M | F-002 |
| 3 | CRITICAL | Add auto-downgrade threshold: if `thinkdeep_completion_pct < 40%`, downgrade from Complete to Standard with user notification and override option | error-handling.md, orchestrator-loop.md | ThinkDeep failures, Quality Gate | M | F-003 |
| 4 | HIGH | Rewrite frontmatter description with third-person voice and trigger phrases: "This skill should be used when the user asks to 'refine requirements', 'generate a PRD', 'create product requirements'..." | SKILL.md | Frontmatter (line 3) | S | F-004 |
| 5 | HIGH | Replace MCP probing invocations with tool existence checks: "Check if tool appears in available tools list. Do NOT invoke for detection." | stage-1-setup.md | Step 1.1 (lines 22-36) | S | F-013 |
| 6 | HIGH | Rewrite "You **MUST** consider the user input" to imperative form: "Consider the user input before proceeding. MANDATORY when non-empty." | SKILL.md | User Input (line 78) | S | F-005 |
| 7 | HIGH | Add `{END IF}` closures to all conditional blocks in dispatch template. OR restructure into 2-3 named profiles (first-round, subsequent-round, reflection) with no conditionals | orchestrator-loop.md | Coordinator Dispatch (lines 54-106) | M | F-009 |
| 8 | HIGH | Replace 100-point scoring algorithm with behavioral anchors per star level (5=convergent insight+best practice, 4=strong with one trade-off, etc.) | option-generation-reference.md | Section 2: Scoring | M | F-010 |
| 9 | HIGH | Add structured CoT template for internal validation path (non-PAL fallback). Define scoring anchors per dimension (1=missing, 2=stated but unbounded, 3=bounded, 4=bounded+measurable) | stage-5-validation-generation.md | Step 5.2 internal path | M | F-014 |
| 10 | HIGH | Add cross-round reflection diff: read prior reflection, classify each prior recommendation as addressed-and-improved / addressed-but-no-improvement / not-addressed. Escalate persistent gaps to different approaches | orchestrator-loop.md | Reflexion Step (lines 278-320) | M | F-015 |
| 11 | HIGH | Extract Quality Gate Protocol + Rounds-Digest Template (~550 words) from orchestrator-loop.md into `references/quality-gates.md`. Load conditionally after Stages 3/5 | orchestrator-loop.md | Quality Gate Protocol, Rounds-Digest | M | F-012 |
| 12 | HIGH | Add blocking structural validation for critical handoff artifacts (QUESTIONS format regex check after Stage 3, PRD section headings after Stage 5) | orchestrator-loop.md | Summary Handling | M | F-017 |
| 13 | HIGH | Reduce emphasis stacking: one mechanism per instruction. Inside CRITICAL RULES, bold alone suffices. Reserve ALL CAPS for single keyword (verb) per rule | SKILL.md, stage-1-setup.md, stage-3-analysis-questions.md | Critical Rules sections | M | F-006 |
| 14 | HIGH | Delete parenthetical restatements when info exists in a nearby table or heading. Target: orchestrator-loop.md design rationale blocks, stage-1-setup.md inline re-explanations | SKILL.md, orchestrator-loop.md, stage-1-setup.md | Various | M | F-007 |
| 15 | HIGH | Split Stage 3 into two sub-coordinators: ThinkDeep coordinator (Part A → writes insights file) then MPA coordinator (Part B → reads insights, dispatches panel). Prevents 27 responses piling into single context | stage-3-analysis-questions.md | Parts A & B | L | F-016 |

### Additional Improvements

**MEDIUM priority (16 items):**
- F-018: Extract Summary Contract example + Interactive Pause Schema to a reference file (~500 words freed from SKILL.md) _(structure, context)_
- F-030: Add coordinator dispatch timeout hints via `token_budgets.stage_dispatch_profiles.{stage}.timeout_minutes` in config _(effectiveness, architecture)_
- F-022: Tighten pseudocode: replace mixed declarative/imperative blocks with state-machine transitions; remove verbose conditionals _(prompt, writing)_
- F-034, F-035: Strengthen consensus anti-sycophancy: add stance-violation detector (against score ≈ for score → flag); document score aggregation logic explicitly _(reasoning, architecture)_
- F-028: Extract ThinkDeep prompt templates from stage-3-analysis-questions.md into conditional `thinkdeep-templates.md` — saves ~400 words in Standard/Rapid mode _(context)_
- F-025: Add variable resolution instruction for panel member dispatch: "Template uses `{VARIABLE_NAME}` placeholders. Replace each with corresponding value." _(prompt)_
- F-026: ThinkDeep call count in Analysis Modes table: use formula "P×M×S calls" with default config example instead of hardcoded 27/18 _(prompt)_
- F-027: Renumber Step 1.7.5 → Step 1.8, cascade renumber through all cross-references _(prompt)_
- F-033: Add self-verification reasoning-quality checks per stage (not just existence checks) _(reasoning)_
- F-036: Mark ThinkDeep `FOR` loops as parallelizable — 9 independent chains could run 3× faster _(architecture)_
- F-037: Create shared `references/artifact-schemas.md` for QUESTIONS and validation file formats _(architecture)_
- F-031: Panel Builder failure fallback: present preset selection to user instead of silently defaulting _(effectiveness)_
- F-019: Add `references/README.md` row to SKILL.md Reference Map table _(structure)_
- F-024: Convert stage-1-setup.md Step 1.4 Cases A-D from if/else chain to decision table _(writing)_
- F-023: Standardize "skip" for conditional omission, "proceed" for forward continuation; eliminate "bypass"/"omit" _(writing)_
- F-029: Replace State Management nested schema in SKILL.md with 3-line summary _(context)_

**LOW priority (11 items):**
- F-038: Add comment to example summary: "Example uses product-focused preset — actual IDs from panel config" _(prompt, effectiveness)_
- F-039: Rapid mode: reference config instead of hardcoding product-strategist values inline _(prompt)_
- F-040: Remove Model column from Agent References table (duplicates config) _(context)_
- F-041: Acknowledge lock race condition as accepted single-session limitation _(prompt)_
- F-042: Document absence of `examples/` directory (deliberate: skill generates all files at runtime) _(structure)_
- F-043: Add token budget for REFLECTION_CONTEXT in config _(architecture)_
- F-044: Document Panel Builder dispatch as exception to "Stage 1 inline" pattern _(architecture)_
- F-045: Git suggestion: use explicit file paths instead of `git add requirements/` _(effectiveness)_
- F-046: Standardize heading capitalization (title case) _(writing)_
- F-047: Drop unnecessary "Note:" / "Key Rule:" labels when content is already visually distinct _(writing)_
- F-048: Inconsistent dash usage: standardize on Unicode em dash for interruptions, hyphens for compounds _(writing)_

## Detailed Findings

### Structure & Organization

**F-004: Frontmatter lacks trigger phrases** `HIGH`
- **File**: SKILL.md (line 3)
- **Current**: `description: Transform rough product drafts into finalized PRDs through iterative Q&A`
- **Recommendation**: Rewrite in third-person with trigger phrases: "This skill should be used when the user asks to 'refine requirements', 'generate a PRD', 'create product requirements'..."

**F-005: Second-person "You" in SKILL.md** `HIGH`
- **File**: SKILL.md (line 78)
- **Current**: `You **MUST** consider the user input before proceeding`
- **Recommendation**: Rewrite in imperative: "Consider the user input before proceeding. MANDATORY when non-empty."

**F-018: Summary Contract section occupies ~80 lines of SKILL.md** `MEDIUM`
- **File**: SKILL.md (lines 166-248)
- **Current**: Full example + Interactive Pause Schema inline
- **Recommendation**: Extract to `references/summary-contract.md`, keep 5-line pointer in SKILL.md
- **Cross-validated by**: context

**F-019: references/README.md missing from Reference Map** `MEDIUM`
- **File**: SKILL.md (Reference Map table)
- **Current**: 15 entries; README.md absent
- **Recommendation**: Add row: `references/README.md | Reference index | On-demand orientation`

**F-020: No examples/ directory** `MEDIUM`
- **File**: Skill directory
- **Current**: Only SKILL.md + references/
- **Recommendation**: Document deliberate absence, or add sample state/QUESTIONS files

### Content Quality & Clarity

**F-006: Redundant emphasis stacking** `HIGH`
- **File**: SKILL.md, stage-1-setup.md, stage-3-analysis-questions.md
- **Current**: Bold + ALL CAPS + intensifiers co-occur: `**Pre-flight validation MUST pass**: If ANY required agent or config file is MISSING, ABORT immediately. Do NOT proceed`
- **Recommendation**: One emphasis mechanism per instruction. Rewrite: `**Pre-flight validation**: Abort if any required agent or config file is missing.`

**F-007: Parenthetical asides restate nearby content** `HIGH`
- **File**: SKILL.md, orchestrator-loop.md, stage-1-setup.md
- **Current**: Design rationale blocks, inline re-explanations of table data
- **Recommendation**: Delete when info exists in nearby table/heading. ~15-20% prose reduction possible.

**F-008: Bookend critical rules repetition varies across files** `HIGH`
- **File**: SKILL.md (lines 365-374), stage-3 (lines 523-528), stage-1 (lines 483-486)
- **Current**: End-of-file reminders restate different subsets; some universal rules omitted per-file
- **Recommendation**: Standardize: (1) universal rules (same in every file), (2) stage-specific rules
- **Cross-validated by**: prompt, context

**F-021: Passive voice in descriptive passages** `MEDIUM`
- **File**: SKILL.md (line 91), orchestrator-loop.md
- **Current**: "Panel composition is set in Stage 1 via the Panel Builder and persisted in..."
- **Recommendation**: "The Panel Builder sets panel composition in Stage 1 and persists it in..."

**F-022: Verbose conditional blocks** `MEDIUM`
- **File**: orchestrator-loop.md, stage-3-analysis-questions.md
- **Current**: 8 lines for 3-line mode check; `(best-effort)` after "PROCEED with available data"
- **Recommendation**: Tighten pseudocode. Remove trailing commentary that restates the action.
- **Cross-validated by**: prompt

**F-023: Synonym churn (skip/bypass/omit/proceed)** `MEDIUM`
- **File**: stage-3, stage-1, orchestrator-loop (various)
- **Current**: Multiple verbs for conditional omission
- **Recommendation**: Standardize: "skip" for omission, "proceed" for continuation. Eliminate "bypass"/"omit" for control flow.

**F-024: If/else chains where tables serve better** `MEDIUM`
- **File**: stage-1-setup.md (lines 113-160)
- **Current**: Step 1.4 Cases A-D use narrative if/else chain with conditions, actions, and sub-UI prompts
- **Recommendation**: Convert to decision table: `| Condition | Action |` with Cases A-D as rows. Follow table with AskUserQuestion JSON for Case C only.

### Prompt & Instruction Effectiveness

**F-001: Contradictory user interaction guidance** `CRITICAL`
- **File**: SKILL.md (Rule 22), stage-1-setup.md
- **Current**: Rule 22: "Coordinators NEVER interact with users directly." Stage 1 runs inline and calls AskUserQuestion directly. Technically correct but cognitively dissonant.
- **Recommendation**: Amend Rule 22: "Coordinators (Stages 2-6) NEVER interact with users directly. Stage 1 runs inline as orchestrator and uses AskUserQuestion directly."
- **Cross-validated by**: effectiveness

**F-009: Dispatch template conditional branches** `HIGH`
- **File**: orchestrator-loop.md (lines 54-106)
- **Current**: 10 variables, 5 `{IF ...}` blocks without `{END IF}`, nested conditions
- **Recommendation**: Add explicit `{END IF}` closures. Or restructure into named dispatch profiles (first-round, subsequent-round, reflection).
- **Cross-validated by**: effectiveness

**F-010: Scoring algorithm descriptive not executable** `HIGH`
- **File**: option-generation-reference.md (Section 2)
- **Current**: 100-point system with qualitative sub-criteria LLMs cannot reproduce
- **Recommendation**: Replace with behavioral anchors per star level

**F-025: Variable resolution for panel members missing** `MEDIUM`
- **File**: stage-3-analysis-questions.md (Step 3B.3)
- **Current**: "Apply these variables to the template" without specifying mechanism
- **Recommendation**: Add: "Template uses `{VARIABLE_NAME}` placeholders. Replace each with corresponding value."

**F-026: ThinkDeep call counts hardcoded** `MEDIUM`
- **File**: SKILL.md (line 86)
- **Current**: "27 calls (3x3x3)" — breaks if config changes model count
- **Recommendation**: Use formula "P×M×S calls" with default config example

**F-027: Step 1.7.5 fractional numbering** `MEDIUM`
- **File**: stage-1-setup.md (line 249)
- **Current**: Panel composition inserted as "Step 1.7.5" between 1.7 and 1.8
- **Recommendation**: Renumber to clean integers (1.7→1.7, 1.7.5→1.8, 1.8→1.9), update cross-references

### Context & Token Efficiency

**F-011: Stage 1 inline doubles always-loaded context** `HIGH`
- **File**: SKILL.md (line 159), stage-1-setup.md
- **Current**: Orchestrator loads SKILL.md (1,980w) + orchestrator-loop.md (2,282w) + stage-1-setup.md (1,933w) = ~6,195 words before any user data
- **Recommendation**: Split stage-1-setup.md into routing (~400w, always) + initialization (~1,500w, NEW workflow only)

**F-012: orchestrator-loop.md always-loaded** `HIGH`
- **File**: orchestrator-loop.md
- **Current**: 2,282 words loaded every invocation; ~550 words are conditional (quality gates, digest template)
- **Recommendation**: Extract Quality Gate Protocol + Rounds-Digest to `references/quality-gates.md`

**F-028: ThinkDeep templates loaded in Standard/Rapid** `MEDIUM`
- **File**: stage-3-analysis-questions.md (lines 134-193)
- **Current**: 65 lines of templates skipped in Standard/Rapid but still loaded
- **Recommendation**: Extract to `references/thinkdeep-templates.md`, load conditionally

**F-029: State Management schema inline** `MEDIUM`
- **File**: SKILL.md (lines 272-305)
- **Current**: 34 lines of coordinator-written nested YAML the orchestrator never writes
- **Recommendation**: Replace with 3-line summary + "see state file for schema"

### Completeness & Coverage

**F-003: ThinkDeep cascade failures degrade silently** `CRITICAL`
- **File**: SKILL.md (lines 84-89), error-handling.md
- **Current**: Quality gate warns on low `thinkdeep_completion_pct` but never triggers mode downgrade
- **Recommendation**: Auto-downgrade when `thinkdeep_completion_pct < 40%` with user notification

**F-013: MCP detection via probing calls** `HIGH`
- **File**: stage-1-setup.md (lines 22-36)
- **Current**: "Try invoking Sequential Thinking with a simple thought" creates a session as side effect. The `mcp__pal__listmodels` call is read-only and safe.
- **Recommendation**: For Sequential Thinking: check tool availability metadata. Do NOT invoke for detection. PAL `listmodels` probe can remain.

**F-030: No coordinator timeout** `MEDIUM`
- **File**: orchestrator-loop.md, error-handling.md
- **Current**: Hung coordinator detected only when summary is missing (crash recovery)
- **Recommendation**: Add `timeout_minutes` per stage in config; coordinators self-enforce
- **Cross-validated by**: architecture

**F-031: Panel Builder fallback skips user validation** `MEDIUM`
- **File**: stage-1-setup.md (lines 321-329)
- **Current**: Failure writes default preset without letting user choose
- **Recommendation**: Present preset selection question after fallback notification

### Reasoning & Logic

**F-002: Unbounded iteration loop / implicit gap significance** `CRITICAL`
- **File**: orchestrator-loop.md (lines 278-320), stage-4-response-analysis.md (lines 168-191)
- **Current**: RED validation always re-dispatches Stage 3 with no stagnation detection. Gap significance ("significant" vs "minimal") is subjective. Circuit breaker at 100 rounds is practically unreachable.
- **Recommendation**: (1) Stagnation detector: if score hasn't improved over 2 RED rounds, present decision to user. (2) Define thresholds: "significant = 2+ MISSING sections OR 1+ CRITICAL gap." (3) Lower circuit breaker to 10-15 rounds.
- **Cross-validated by**: effectiveness

**F-014: Validation scoring lacks CoT enforcement** `HIGH`
- **File**: stage-5-validation-generation.md (lines 86-109)
- **Current**: Consensus path has evidence requirement. Internal (non-PAL) path has none — single sentence instruction. Scoring anchors undefined for both paths.
- **Recommendation**: Add CoT template for internal path. Define scoring anchors per dimension (1=missing, 2=stated but unbounded, 3=bounded, 4=bounded+measurable).

**F-015: Reflexion has no cross-round diff** `HIGH`
- **File**: orchestrator-loop.md (lines 278-320)
- **Current**: Round 3 reflection may repeat round 2 guidance without checking if it was already tried
- **Recommendation**: Add explicit diff: read prior reflection, classify each recommendation as addressed/not-addressed. Escalate persistent gaps.

**F-032: ThinkDeep inter-step verification missing** `MEDIUM`
- **File**: stage-3-analysis-questions.md (lines 62-116)
- **Current**: Step 2 feeds Step 1 findings without evaluating quality
- **Recommendation**: Lightweight check after Step 1: at least 2 specific findings? If not, skip remaining steps for that chain.

**F-033: Self-verification checklists existence-only** `MEDIUM`
- **File**: All stage references
- **Current**: Check file existence, non-empty, placeholder removal — not reasoning quality
- **Recommendation**: Add one reasoning-quality check per stage (e.g., "no two questions target exact same sub-problem")

**F-034: Consensus score aggregation undocumented** `MEDIUM`
- **File**: stage-5-validation-generation.md (lines 56-106)
- **Current**: Three stances report scores; aggregation logic not specified
- **Recommendation**: Document: median, weighted average, or synthesis-based. Add divergence flag (scores differ by 6+).
- **Cross-validated by**: architecture

### Architecture & Coordination

**F-016: Stage 3 coordinator context overload** `HIGH`
- **File**: stage-3-analysis-questions.md
- **Current**: Single coordinator holds 27 ThinkDeep responses + draft + references before MPA dispatch
- **Recommendation**: Split into ThinkDeep sub-coordinator (Part A) and MPA sub-coordinator (Part B)
- **Cross-validated by**: prompt

**F-017: No inter-stage artifact validation** `HIGH`
- **File**: orchestrator-loop.md (Quality Gate Protocol)
- **Current**: Quality gates are non-blocking; no structural validation of QUESTIONS format before Stage 4
- **Recommendation**: Add blocking structural checks (regex-based) for critical handoff artifacts

**F-035: Consensus sycophancy mitigation insufficient** `MEDIUM`
- **File**: consensus-call-pattern.md (lines 73-82)
- **Current**: Only complete unanimity triggers a log note
- **Recommendation**: Add stance-violation detector (against ≈ for → flag). Add challenge round option.

**F-036: ThinkDeep execution sequential** `MEDIUM`
- **File**: stage-3-analysis-questions.md (lines 62-116)
- **Current**: Nested FOR loops imply sequential execution of 9 independent chains
- **Recommendation**: Explicitly mark outer loops as parallelizable (9 chains → 3× faster)

**F-037: Artifact format coupling between stages** `MEDIUM`
- **File**: stage-3, stage-4, stage-5 references
- **Current**: No shared schema — each stage independently defines format expectations
- **Recommendation**: Create `references/artifact-schemas.md` as single source of truth

## Strengths

1. **Dynamic MPA Panel System** — Domain-specialized question generation composed at runtime via parametric template. Presets for common cases + full customization, persisted across rounds. Avoids hardcoded agent proliferation. _(identified by: architecture, effectiveness, prompt)_

2. **File-based communication with explicit summary contracts** — YAML frontmatter summary schema creates machine-readable interface between orchestrator and coordinators. `flags` object carries stage-specific metadata. Interactive Pause Schema gives coordinators structured vocabulary for user input without breaking delegation rules. _(identified by: architecture, prompt)_

3. **Reflexion loop with persisted context** — Stage 3-5 iteration generates structured reflection (What We Tried → Why Insufficient → What To Do Differently) persisted to disk for crash recovery. External reflection (orchestrator generates, not the failed coordinator). _(identified by: reasoning, effectiveness)_

4. **Exemplary progressive disclosure architecture** — 1,980-word SKILL.md governs 16 reference files (~170KB). Reference Map with "Load When" guidance. Three-level loading (metadata → body → references). _(identified by: structure, context)_

5. **Comprehensive graceful degradation** — Four-tier mode hierarchy (Complete→Advanced→Standard→Rapid) with explicit mode guards at every optional tool usage. Each degradation removes exactly one capability tier. Safe fallback defaults. _(identified by: effectiveness, reasoning, architecture)_

6. **Variable defaults table with rationale** — Every dispatch variable has a defined fallback with a rationale column explaining why. Explicit "never pass null" rule prevents silent null propagation in coordinator prompts. _(identified by: prompt)_

7. **Strong imperative instructional voice** — Core instructions consistently use active, imperative constructions. Pseudocode reads top-to-bottom. Tables for structured data. Consistent section structure across stage files. _(identified by: writing)_

8. **Least-to-Most decomposition in question generation** — PRD sections decomposed into sub-problems before MPA dispatch. Ensures questions target specific, answerable aspects. Serves as coverage checklist. _(identified by: reasoning)_

9. **Resumable state machine** — `waiting_for_user` + `pause_stage` tracking, `ENTRY_TYPE` disambiguation, immutable `user_decisions`, schema versioning with migration, lock protocol with staleness threshold. _(identified by: effectiveness)_

## Metadata

- **Analysis date**: 2026-03-01
- **Lenses applied**: 7 (Structure & Progressive Disclosure, Prompt Engineering Quality, Context Engineering Efficiency, Writing Quality & Conciseness, Overall Effectiveness, Reasoning & Decomposition, Architecture & Coordination)
- **Fallback used**: 4 lenses — Prompt Engineering, Context Engineering, Effectiveness, and Reasoning used generic fallback evaluation criteria because their corresponding skills (`customaize-agent:prompt-engineering`, `customaize-agent:context-engineering`, `customaize-agent:agent-evaluation`, `customaize-agent:thought-based-reasoning`) were not installed. Fallback criteria are broad quality questions (e.g., "Are instructions clear and unambiguous?") rather than framework-specific rubrics. Findings from these lenses are directionally accurate but may lack the precision of installed-skill evaluations.
- **Lenses from installed skills**: 3 (Structure via `plugin-dev:skill-development`, Writing via `docs:write-concisely`, Architecture via `sadd:multi-agent-patterns`)
- **Target skill size**: ~1,980 words (SKILL.md) + 16 reference files (~170KB total) + 0 example files + 0 script files
- **Individual analyses**: `plugins/product-definition/skills/refinement/.skill-review/`
