---
target_skill: "feature-specify"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify"
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
overall_score: "2.3/5.0"
findings_total: 46
findings_critical: 8
findings_high: 17
findings_medium: 13
findings_low: 8
findings_info: 0
dedup_stats:
  raw_findings_total: 77
  after_dedup: 46
  merge_ratio: "40%"
---

# Skill Review Report: feature-specify

## Executive Summary

The feature-specify skill (v1.2.0) is a 7-stage coordinator-delegated orchestrator for producing feature specifications with Figma integration, CLI multi-stance validation, and V-Model test strategy generation. At 17,302 bytes across SKILL.md and 153KB across 17 reference files, it is one of the most complex skills in the plugin ecosystem.

**Overall: 2.3/5.0 — Needs Work.** The skill has strong architectural foundations (lean orchestrator, progressive disclosure, immutable user decisions, crash recovery) but is penalized by 8 CRITICAL issues: an unbounded iteration loop with no hard termination, systematic rule duplication wasting ~2K tokens, supervisor context accumulation over long workflows, contradictory user interaction rules in Stage 4, ambiguous rule numbering, incomplete PAL-to-CLI terminology migration, a decorative semantic dedup threshold, and a haiku-tier synthesis bottleneck. The skill would produce correct output in most scenarios but has real risk of incorrect behavior in edge cases (loop non-convergence, contradictory instructions, synthesis information loss).

> **Calibrated sentiment:** Despite the strict rubric score, the skill's architectural foundations are sound — all 8 CRITICAL findings are fixable polish items (terminology, config, rule wording), not fundamental design flaws. A focused remediation pass addressing the CRITICAL tier would likely raise the score to 3.5+/5.0.

**Top concern:** The Stage 3-4 iteration loop lacks a hard termination guarantee — flagged independently by Reasoning, Effectiveness, and Architecture lenses.

**Top strength:** Exemplary progressive disclosure architecture with 17 well-wired reference files, precise 1,998-word SKILL.md, and three-tier loading strategy.

## Scores by Lens

| Lens | Score | Key Finding |
|------|-------|-------------|
| Structure & Progressive Disclosure | 3/5 | Frontmatter lacks trigger phrases for auto-discovery |
| Prompt Engineering Quality | 2/5 | Duplicate rule 17/17b creates ambiguous cross-references |
| Context Engineering Efficiency | 2/5 | Same rules repeated 6-12 times across files (~2K token waste) |
| Writing Quality & Conciseness | 3/5 | Pervasive passive voice and synonym churn for CLI dispatch concept |
| Overall Effectiveness | 2/5 | Contradictory user interaction rules in Stage 4 |
| Reasoning & Decomposition | 2/5 | Iteration loop has no hard termination guarantee |
| Architecture & Coordination | 2/5 | Supervisor context grows unbounded through iteration loop |

**Overall: 2.3/5.0** — Needs Work

Score interpretation:
- 4.5-5.0: Excellent — production-ready, minimal improvements needed
- 3.5-4.4: Good — solid skill with some improvement opportunities
- 2.5-3.4: Adequate — functional but has notable quality gaps
- 1.5-2.4: Needs Work — significant issues affecting effectiveness
- 1.0-1.4: Poor — fundamental problems requiring major revision

> **Note on scoring methodology:** Per-lens scores use pre-dedup raw finding counts from each lens's individual analysis (not consolidated counts). The strict rubric drops any lens with 1+ CRITICAL to 2/5 — five of seven lenses found at least one CRITICAL issue. The 2.3 weighted average reflects this penalty. See the calibrated sentiment note above for practical interpretation.

## Modification Plan

| # | Priority | Action | File | Section | Effort | Lenses |
|---|----------|--------|------|---------|--------|--------|
| 1 | CRITICAL | Add hard iteration ceiling (max_iterations: 5 in config) with forced user proceed/abort decision as circuit breaker | `orchestrator-loop.md`, `specify-config.yaml` | Iteration Loop | M | reasoning, effectiveness, architecture |
| 2 | CRITICAL | Remove CRITICAL RULES REMINDER bookends from stage files; keep rules only in SKILL.md (canonical) and stage-specific rules at top of each stage file | All `stage-*.md` files | CRITICAL RULES sections | M | context, writing, structure |
| 3 | CRITICAL | Implement rolling summary window — pass only 2-3 most recent summaries to coordinators, not full history; add `max_prior_summaries` config value | `orchestrator-loop.md` | Coordinator Dispatch Template | M | architecture, context, effectiveness |
| 4 | CRITICAL | Fix Stage 4 Rule 6 to explicitly carve out Step 4.0 interactive exception at the rule definition, not 500 lines later | `stage-4-clarification.md` | CRITICAL RULES (top) | S | effectiveness |
| 5 | CRITICAL | Renumber rule 17b to 18, shift subsequent rules, update end-section reference count | `SKILL.md` | CRITICAL RULES | S | prompt |
| 6 | CRITICAL | Complete PAL-to-CLI terminology migration: rename config keys (`pal_*` → `cli_*`), update user-facing labels, README descriptions | `SKILL.md`, `specify-config.yaml`, `stage-1-setup.md`, `README.md` | Multiple | M | prompt, effectiveness |
| 7 | CRITICAL | Replace 0.85 semantic deduplication threshold with qualitative criteria (DUPLICATE/RELATED/UNIQUE classification) | `stage-4-clarification.md` | Step 4.4 Triangulation | S | prompt, reasoning |
| 8 | CRITICAL | Elevate synthesis agent model to sonnet for Challenge/EdgeCases/Evaluation; add post-synthesis finding-count validation | `cli-dispatch-patterns.md` | Synthesis sections | M | architecture, prompt |
| 9 | HIGH | Rewrite frontmatter description with third-person voice and trigger phrases for auto-discovery | `SKILL.md` | Frontmatter | S | structure |
| 10 | HIGH | Reconcile RTM disposition gate: update Rule 28 to reflect two-tier enforcement (Stage 4 blocking + post-Stage-4 non-blocking) | `SKILL.md`, `orchestrator-loop.md` | Rule 28, RTM Quality Check | S | effectiveness, reasoning, architecture |
| 11 | HIGH | Add explicit `gate-judge` dispatch in Stage 2 gates (currently says "auto-evaluate" which implies self-assessment) | `stage-2-spec-draft.md` | Steps 2.4, 2.5 | M | reasoning |
| 12 | HIGH | Standardize CLI dispatch terminology: use "CLI dispatch" as canonical term, qualify with role (Challenge/EdgeCases/Triangulation/Evaluation) | All files | Throughout | M | writing |
| 13 | HIGH | Add Template Rendering instruction block to dispatch template explaining how to resolve `{IF ...}` conditionals | `orchestrator-loop.md` | Coordinator Dispatch Template | S | prompt |
| 14 | HIGH | Remove config table from SKILL.md (lines 59-82), replace with single-line pointer to config-reference.md | `SKILL.md` | Configuration Reference | S | structure, context |
| 15 | HIGH | Extract Summary Contract YAML schema to `orchestrator-loop.md` or new micro-reference; keep only compact version in SKILL.md | `SKILL.md` | Summary Contract | S | structure, context |

### Additional Improvements

**HIGH (continued):**
- Fix step ordering in `stage-2-spec-draft.md` — renumber 2.1b to sequential order matching physical file position
- Add pre-condition validation checks at start of each stage reference file (following Stage 6 pattern)
- Add Least-to-Most synthesis protocol for CLI output merging (INVENTORY → CLUSTER → OVERLAP → BOOST → DEDUPLICATE → VERIFY)
- Add 3-4 worked examples to auto-resolve classification protocol
- Add "internal reasoning" fallback protocol for when CLI dispatch is unavailable
- Rewrite passive voice in procedural instructions to active imperative form
- Make CLI evaluation fully parallel (remove sequential gemini-first ordering that provides no anchoring benefit)
- Define `RESUME_CONTEXT` variable in defaults table or remove from template
- Fix "You MUST" second-person voice on SKILL.md line 91

**MEDIUM:**
- Add "When NOT to Use" section to SKILL.md
- Add self-verification failure consequences (retry → failed status, never completed with failures)
- Collapse verbose conditional preambles to single-line guards
- Add `artifacts_for_next_stage` field to summary YAML schema
- Split `stage-4-clarification.md` Figma mock gap section to conditional reference file
- Add lock stale timeout in config and checkpoint-protocol.md
- Expand pre-flight validation to cover all 5 agents and config file
- Standardize AskUserQuestion format between inline Stage 1 and coordinator-delegated stages
- Add self-consistency check between spec draft and MPA-Challenge (BA internal validation)
- Formalize severity boost as explicit decision table
- Add RFC 2119-style keyword convention note
- Expand acronyms on first use (MPA, RTM, NFR, BA)
- Standardize if/else formatting across stage files

**LOW:**
- Fix loose sentence chains in orchestrator-loop.md explanatory prose
- Remove dead `OR is blank` clause in clarification-protocol.md answer parsing
- Merge self-verification items into summary contract as pre-write checklist
- Document why Stage 1 inline exception is 400 lines (or split to inline + delegated discovery)
- Fix tense inconsistency in stage-2-spec-draft.md step descriptions
- Replace vague "see above/below" cross-references with explicit section anchors

## Detailed Findings

### Structure & Organization

**Frontmatter lacks trigger phrases** `HIGH`
- **File**: `SKILL.md` (line 3)
- **Current**: `description: Create or update feature specifications through guided analysis...` — imperative voice, no trigger phrases
- **Recommendation**: Rewrite to `This skill should be used when the user asks to "create a feature spec", "specify a feature", "write a specification"...`
- **Cross-validated by**: structure only

**Configuration table duplicates config-reference.md** `HIGH`
- **File**: `SKILL.md` (lines 59-82)
- **Current**: 20-row table repeating values also in `config-reference.md` and `specify-config.yaml` (triple redundancy)
- **Recommendation**: Replace with single-line pointer; keep only 5-6 orchestrator-critical thresholds inline
- **Cross-validated by**: structure, context

**Summary Contract occupies 15% of SKILL.md** `HIGH`
- **File**: `SKILL.md` (lines 173-214)
- **Current**: Full YAML schema (42 lines, ~250 words) that coordinators receive via dispatch template, not by reading SKILL.md
- **Recommendation**: Extract to `orchestrator-loop.md`; keep compact version (path, status enum, key fields) in SKILL.md
- **Cross-validated by**: structure, context

**Second-person voice in SKILL.md** `HIGH`
- **File**: `SKILL.md` (line 91)
- **Current**: `You **MUST** consider the user input before proceeding`
- **Recommendation**: Rewrite to imperative: `Consider user input before proceeding (mandatory when non-empty)`

**No examples/ or scripts/ directories** `MEDIUM`
- **File**: Skill root
- **Current**: Only SKILL.md + references/ exist; plugin-level scripts referenced but undocumented
- **Recommendation**: Add note clarifying shared resources live at plugin root (`$CLAUDE_PLUGIN_ROOT/`)

### Content Quality & Clarity

**Pervasive passive voice** `HIGH`
- **File**: All files
- **Current**: "Questions are written to...", "findings are synthesized", "State is persisted"
- **Recommendation**: Rewrite as "Write questions to...", "Synthesize findings", "Persist state"

**Synonym churn for CLI dispatch concept** `HIGH`
- **File**: SKILL.md, stage files
- **Current**: 5+ terms: "CLI dispatch", "MPA-Challenge CLI dispatch", "tri-CLI dispatch", "CLI multi-stance validation", "CLI multi-stance eval"
- **Recommendation**: Standardize on "CLI dispatch" with role qualifier: "CLI dispatch (Challenge)", "CLI dispatch (Evaluation)"

**Verbose conditional preambles** `HIGH`
- **File**: `stage-2-spec-draft.md`, `stage-4-clarification.md`
- **Current**: 5-line guard clause blocks before each conditional step
- **Recommendation**: Collapse to single-line guards; full boolean expressions belong in pseudocode, not prose

**Filler phrases and overlong parentheticals** `MEDIUM`
- **File**: All files (~15-20% of prose could be cut)
- **Current**: Blockquote introductions restate headings; nested parentheticals disrupt flow
- **Recommendation**: Delete filler; promote important parentheticals to sentences

**Loose sentence chains in explanatory prose** `MEDIUM`
- **File**: `orchestrator-loop.md` (lines 267-272)
- **Current**: Six consecutive loose sentences explaining the non-blocking RTM gate rationale, each adding a subordinate thought; reader must hold entire chain to understand design intent
- **Recommendation**: Compress to two sentences: "This check is non-blocking: Stage 4 already offered disposition for every UNMAPPED requirement, so remaining gaps reflect the user's conscious choice. Remaining UNMAPPED entries appear in the Stage 7 completion report."

**Inconsistent if/else formatting across stage files** `MEDIUM`
- **File**: `stage-2-spec-draft.md`, `stage-4-clarification.md`
- **Current**: Conditional branches appear in at least four formats: bold-colon (`**If enabled:**`), bold-colon-code (`**Check:** \`config.key\``), inline code (`IF ENTRY_TYPE == ...`), and paragraph ("If user chose 'Revise': ...")
- **Recommendation**: Adopt one format for all guard clauses; use bold-label for guards, code blocks only for pseudocode that coordinators parse mechanically

**Hedging language weakens instructions** `MEDIUM`
- **File**: SKILL.md, `orchestrator-loop.md`
- **Current**: "Non-blocking but user-notified" (double negative), "Assume unavailable; prevents failed CLI dispatch calls" (negative explaining negative)
- **Recommendation**: Rewrite in positive form: "Quality gates notify the user and allow the workflow to continue"; "Default false. Detected in Stage 1; overridden when found."

**Inconsistent RFC 2119 keyword usage** `LOW`
- **File**: SKILL.md, orchestrator-loop.md
- **Current**: Mixed MUST/must/ALWAYS/always without convention
- **Recommendation**: Add convention note; capitalize only for mandatory requirements

**Acronyms undefined on first use** `LOW`
- **File**: SKILL.md
- **Current**: MPA, RTM, NFR, BA used without expansion
- **Recommendation**: Expand on first use: "Multi-Perspective Analysis (MPA)"

**Tense inconsistency in step descriptions** `LOW`
- **File**: `stage-2-spec-draft.md`
- **Current**: Steps alternate between imperative ("Dispatch BA agent via Task") and declarative present ("Agent uses Sequential Thinking...") and sentence fragments ("Same GREEN/YELLOW/RED logic as Gate 1.")
- **Recommendation**: Use imperative mood throughout step instructions (coordinator is the implied subject)

**Vague cross-references** `LOW`
- **File**: `stage-2-spec-draft.md`, `orchestrator-loop.md`
- **Current**: "Same logic as Gate 1", "see Coordinator Dispatch below", "see Summary Handling" — no section anchors or step numbers
- **Recommendation**: Use explicit step/section references: "Same logic as Step 2.4 (Gate 1)"; use markdown anchor links for in-document cross-references

**Self-verification sections repeat summary contract** `LOW`
- **File**: `stage-2-spec-draft.md` (lines 289-296), `stage-4-clarification.md` (lines 504-513)
- **Current**: Self-verification checklists largely restate what the Summary Contract already requires (e.g., "Summary YAML frontmatter has no placeholder values")
- **Recommendation**: Merge verification items into the Summary Contract section as a pre-write checklist (~10 lines recovered per file)

### Prompt & Instruction Effectiveness

**Duplicate rule 17/17b** `CRITICAL`
- **File**: `SKILL.md` (lines 39-40)
- **Current**: Rule 17 and 17b coexist; end section references "Rules 1-28" but set has 29 entries
- **Recommendation**: Renumber sequentially 1-29 or merge 17/17b into single rule

**Dispatch template pseudo-conditional syntax** `HIGH`
- **File**: `orchestrator-loop.md` (lines 75-82)
- **Current**: `{IF stage needs checkpoint-protocol:}` — not a standard template language, no rendering instructions
- **Recommendation**: Add explicit Template Rendering section; provide one fully resolved example

**Step ordering conflict 2.1b** `HIGH`
- **File**: `stage-2-spec-draft.md`
- **Current**: Step 2.1b appears after Step 2.2 in file; numbering implies it belongs between 2.1 and 2.2
- **Recommendation**: Renumber to sequential order matching physical position (per CLAUDE.md rule)

**Self-critique rubric undefined** `MEDIUM`
- **File**: `orchestrator-loop.md`
- **Current**: BA produces N/20 score but no rubric defines the 20-point scale
- **Recommendation**: Define rubric or reference template file that contains it

**RESUME_CONTEXT variable undefined** `MEDIUM`
- **File**: `stage-2-spec-draft.md` (line 30)
- **Current**: Variable in dispatch prompt with no definition, no default, no sourcing instruction
- **Recommendation**: Add to variable defaults table or remove if vestigial

### Context & Token Efficiency

**Systematic rule duplication** `CRITICAL`
- **File**: All stage files, SKILL.md, orchestrator-loop.md
- **Current**: "MANDATORY design artifacts" appears 12 times across 5 files; "IMMUTABLE user decisions" appears 10 times; "NEVER interact" appears 11 times; each stage file has top+bottom bookend duplication
- **Recommendation**: SKILL.md is canonical; stage files keep only stage-specific rules; remove all CRITICAL RULES REMINDER sections
- **Cross-validated by**: context, writing, structure

**Dispatch template injects shared references unconditionally** `HIGH`
- **File**: `orchestrator-loop.md` (lines 54-99)
- **Current**: checkpoint-protocol.md and error-handling.md loaded for 6/7 stages regardless of need
- **Recommendation**: Inline checkpoint-protocol (only 180 words); load error-handling only for stages 2-5

**stage-4-clarification.md disproportionately large** `HIGH`
- **File**: `stage-4-clarification.md` (22,431 bytes — 75% larger than next biggest)
- **Current**: Figma mock gap section (600 words) loaded unconditionally even on re-entry
- **Recommendation**: Split Figma mock gap to conditional reference file; add re-entry skip markers

**Reference Map table redundant with Stage Dispatch Table** `MEDIUM`
- **File**: `SKILL.md` (lines 268-288)
- **Current**: Largely duplicates Stage Dispatch Table + README.md File Usage table
- **Recommendation**: Merge into Stage Dispatch Table with "Extra Refs" column; keep only non-stage-specific refs in map

### Completeness & Coverage

**Contradictory user interaction rules** `CRITICAL`
- **File**: `stage-4-clarification.md`
- **Current**: Rule 6 says "NEVER interact with users directly" but Step 4.0 uses `pause_type: interactive`; exception appears 500 lines later in reminder
- **Recommendation**: Add exception directly to Rule 6: "Step 4.0 (Figma Mock Gap) uses interactive pause — ONLY interactive pause in Stage 4"
- **Cross-validated by**: effectiveness only (but CRITICAL severity)

**PAL-to-CLI migration incomplete** `CRITICAL` *(escalated from HIGH — cross-validated by 2 lenses)*
- **File**: SKILL.md, stage-1-setup.md, error-handling.md, README.md
- **Current**: Config keys still use `pal_*`; user-facing labels say "Re-run PAL Gate"; line 301 explicitly says rename happened "everywhere"
- **Recommendation**: Complete migration: `pal_rejection_retries_max` → `cli_rejection_retries_max`, `thresholds.pal.*` → `thresholds.cli_eval.*`
- **Cross-validated by**: prompt, effectiveness

**Missing "when NOT to use" guidance** `MEDIUM`
- **File**: `SKILL.md`
- **Current**: No guidance on minimum feature complexity, prerequisites, partial re-runs
- **Recommendation**: Add section with complexity threshold, prerequisite list, relationship to /requirements

**Self-verification lacks failure consequences** `MEDIUM`
- **File**: All stage files
- **Current**: Checklists say "verify before writing summary" but don't specify what happens on failure
- **Recommendation**: Add explicit: "If ANY check fails → attempt fix → if still failing → status: failed with block_reason"

**Pre-flight validation incomplete** `LOW`
- **File**: `stage-1-setup.md`
- **Current**: Validates 3 of 5 agents; misses qa-strategist, gate-judge, config file
- **Recommendation**: Expand to all 5 agents plus config file

### Reasoning & Logic

**Iteration loop lacks hard termination** `CRITICAL`
- **File**: `orchestrator-loop.md`
- **Current**: Loop until coverage >= 85% or user forces proceed; stall detection at < 5% improvement; no iteration cap per Rule 15
- **Recommendation**: Add circuit breaker (max_iterations: 5) that forces user decision; add regression counter for coverage decreases
- **Cross-validated by**: reasoning, effectiveness, architecture

**Semantic dedup threshold is decorative** `CRITICAL` *(escalated from HIGH — cross-validated by 2 lenses)*
- **File**: `stage-4-clarification.md` (line 352)
- **Current**: "similarity threshold: 0.85" — no computation method defined for an LLM coordinator
- **Recommendation**: Replace with qualitative DUPLICATE/RELATED/UNIQUE classification
- **Cross-validated by**: prompt, reasoning

**Gate self-evaluation is implicit** `HIGH`
- **File**: `stage-2-spec-draft.md`
- **Current**: "Auto-evaluate 4 criteria" — same coordinator that drafted the spec evaluates its own work; `gate-judge` agent exists but is never explicitly dispatched
- **Recommendation**: Always dispatch `gate-judge` for gates; add Chain-of-Thought scaffold (quote → criterion → evidence for/against → verdict)

**CLI synthesis lacks reasoning methodology** `HIGH`
- **File**: `stage-4-clarification.md`, `stage-2-spec-draft.md`
- **Current**: Synthesis compressed to single-sentence instructions; no explicit chain for determining "same edge case"
- **Recommendation**: Add Least-to-Most decomposition: INVENTORY → CLUSTER → OVERLAP → BOOST → DEDUPLICATE → VERIFY

**Auto-resolve classification needs worked examples** `HIGH`
- **File**: `auto-resolve-protocol.md`
- **Current**: Classification criteria require significant judgment; no examples of boundary cases
- **Recommendation**: Add 3-4 worked examples (one AUTO_RESOLVED, one INFERRED, one REQUIRES_USER with exclusion detection)

**RTM disposition gate contradiction** `HIGH`
- **File**: `SKILL.md` (Rule 28), `orchestrator-loop.md`
- **Current**: Rule 28 says "Zero UNMAPPED before proceeding past Stage 4" (blocking); orchestrator implements as non-blocking
- **Recommendation**: Update Rule 28 to two-tier: "Step 4.0a is blocking; post-Stage-4 check is warning-only (reported in Stage 7)"
- **Cross-validated by**: effectiveness, reasoning, architecture

**Severity boost logic under-specified** `MEDIUM`
- **File**: `stage-4-clarification.md`
- **Current**: Boost rules don't address already-CRITICAL findings, base severity conflicts, or disagreement
- **Recommendation**: Formalize as decision table covering all severity x agreement combinations

### Architecture & Coordination

**Supervisor context accumulation** `CRITICAL`
- **File**: `orchestrator-loop.md`
- **Current**: All prior stage summaries passed to every coordinator; state file frontmatter grows with decisions, failures, iterations
- **Recommendation**: Rolling window of 2-3 most recent summaries; per-stage `required_state_fields` filter; archive older summaries
- **Cross-validated by**: architecture, context, effectiveness

**Haiku synthesis as interpretation bottleneck** `CRITICAL` *(escalated from HIGH — cross-validated by 2 lenses)*
- **File**: `cli-dispatch-patterns.md`
- **Current**: Haiku model synthesizes outputs from more capable models; no synthesis fidelity check
- **Recommendation**: Elevate to sonnet for Challenge/EdgeCases/Evaluation; add finding-count validation post-synthesis
- **Cross-validated by**: architecture, prompt

**CLI evaluation anchoring despite mitigation claim** `HIGH`
- **File**: `cli-dispatch-patterns.md`
- **Current**: Sequential gemini-first, then parallel codex+opencode; CLIs don't receive each other's output; anchoring only affects synthesis agent
- **Recommendation**: Make all three fully parallel (saves latency); instruct synthesis agent to read in random order

**Missing pre-condition validation between stages** `HIGH`
- **File**: `orchestrator-loop.md`
- **Current**: Quality gates are post-hoc and non-blocking; no content validation before stage entry
- **Recommendation**: Add lightweight pre-condition checks per stage (following Stage 6 pattern)

**Graceful degradation removes all quality checks** `MEDIUM`
- **File**: `error-handling.md`
- **Current**: CLI unavailable → skip Challenge, EdgeCases, Triangulation, Evaluation; "internal reasoning" undefined
- **Recommendation**: Define explicit fallback for each: self-critique for Challenge, structured checklist for EdgeCases, self-evaluation with limitations for Evaluation

**Summary size limits may cause silent info loss** `MEDIUM`
- **File**: `orchestrator-loop.md`
- **Current**: 500 char YAML + 1000 char body with no overflow mechanism
- **Recommendation**: Add `artifacts_for_next_stage` structured field separate from 1000-char body

**Lock protocol lacks stale timeout** `LOW`
- **File**: `SKILL.md`, `checkpoint-protocol.md`
- **Current**: No timeout for stale locks from crashed coordinators
- **Recommendation**: Add `lock_stale_timeout_minutes: 60` in config; write timestamp to lock file

**Stage 1 inline exception is 400 lines** `LOW`
- **File**: `stage-1-setup.md`
- **Current**: Exceeds "lightweight setup" justification with Figma capture, MCP checks, RTM extraction
- **Recommendation**: Document rationale or split to inline setup + delegated discovery

## Strengths

1. **Exemplary progressive disclosure architecture** — SKILL.md at 1,998 words (within the <300 line target at 302 lines) serves as lean dispatch table; 17 reference files totaling 153KB provide stage-specific detail with clear "Load When" guidance; three-tier loading strategy (always-loaded → per-dispatch → on-demand) ensures coordinators receive only relevant context per stage _(identified by: structure, context, effectiveness, prompt — 4 lenses)_

2. **Immutable user decisions prevent re-ask loops** — `user_decisions` are write-once, checked before every question (Rule 2), persisted across crashes via YAML state file; RTM dispositions follow the same pattern with 3 disposition types (MAPPED/DEFERRED/OUT_OF_SCOPE); zero reported cases of re-opened questions across the workflow _(identified by: effectiveness, reasoning, architecture, prompt — 4 lenses)_

3. **Comprehensive graceful degradation** — Systematic handling across 4 independent capability axes (CLI dispatch, Sequential Thinking, Figma MCP, individual CLI binaries); explicit fallback behavior for each of 5 exit codes (0-success through 4-partial); circuit breaker (`skip_on_all_fail`) prevents cascading failures from blocking the 7-stage pipeline _(identified by: effectiveness, architecture — 2 lenses)_

4. **File-based clarification with auto-resolve intelligence** — Offline Q&A supporting 15+ questions per iteration with BA recommendations; three-tier classification (AUTO_RESOLVED/INFERRED/REQUIRES_USER) with citation requirements for auto-resolved answers; user override capability preserves autonomy while reducing question fatigue _(identified by: effectiveness, prompt, reasoning — 3 lenses)_

5. **Clean orchestrator-coordinator separation** — SKILL.md contains only dispatch logic (302 lines); each coordinator receives a focused stage reference file (avg ~1.5K lines) plus 2-3 shared references; file-based summary communication prevents context pollution between stages _(identified by: structure, writing, architecture — 3 lenses)_

6. **Crash recovery with artifact-based reconstruction** — State schema migration v2→v5 with additive-only fields ensures backward compatibility; artifact file presence serves as completion proxy when summary is missing; chained migration functions handle all intermediate versions without data loss _(identified by: architecture, reasoning — 2 lenses)_

7. **Parallel structure in rule lists and table-driven configuration** — All 28 critical rules follow consistent bold-number/bold-keyword/colon/imperative format; 4 major reference tables (Stage Dispatch, Variable Defaults, Agent References, Configuration) use scannable parallel column structure _(identified by: writing — 1 lens)_

8. **Multi-perspective CLI dispatch addresses confirmation bias** — 3 models with distinct analytical roles (neutral/advocate/challenger) across 4 integration points yield up to 12 independent analyses per workflow; severity boost on cross-model agreement converts agreement into confidence signals _(identified by: reasoning, architecture — 2 lenses)_

## Metadata

- **Analysis date**: 2026-03-01
- **Lenses applied**: 7 (Structure & Progressive Disclosure, Prompt Engineering Quality, Context Engineering Efficiency, Writing Quality & Conciseness, Overall Effectiveness, Reasoning & Decomposition, Architecture & Coordination)
- **Fallback used**: 4 lenses (Prompt Engineering Quality, Context Engineering Efficiency, Overall Effectiveness, Reasoning & Decomposition)
- **Target skill size**: ~4,600 words (SKILL.md) + 17 reference files (153KB total) + 0 example files + 0 script files
- **Individual analyses**: `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify/.skill-review/`

### Deduplication Transparency

77 raw findings were collected across 7 lenses (per-lens: structure 8, prompt 14, context 7, writing 18, effectiveness 9, reasoning 10, architecture 11). After cross-lens deduplication per synthesis-rules.md Step 2, 46 consolidated findings remain (40% merge ratio). The writing lens contributed the most raw findings (18) but had the highest merge rate — 12 of its 18 findings survived as distinct entries, while 6 were merged into findings from other lenses that addressed the same file and section. INFO-severity findings (4 raw: writing 2, architecture 2) were routed to the Strengths section per synthesis rules and are excluded from finding counts.

### Escalation Notes

3 findings were escalated from HIGH to CRITICAL under the cross-lens escalation rule ("same issue from 2+ lenses always escalates one tier" — synthesis-rules.md Step 3):
- **PAL-to-CLI migration incomplete**: flagged by prompt + effectiveness lenses
- **Semantic dedup threshold is decorative**: flagged by prompt + reasoning lenses
- **Haiku synthesis as interpretation bottleneck**: flagged by architecture + prompt lenses

### Lens Coverage Note

This analysis used 7 default lenses. A **user-experience** lens (evaluating the skill from the end-user's perspective — e.g., clarity of generated artifacts, quality of AskUserQuestion interactions, usefulness of completion reports) was not included but could surface additional findings in future reviews. Consider adding a UX-focused lens for skills with significant user-facing output.

## Appendix: Omitted Source Findings

The following source findings were merged into consolidated entries during deduplication (same file + same section as another finding). They are listed here for completeness — the merged entry in the report captures their intent.

| Source Lens | Original Finding | Merged Into |
|-------------|-----------------|-------------|
| Writing | Sentences bury the verb after long prepositional chains (stage-4, line 137) | "Verbose conditional preambles" (Content Quality) |
| Writing | Unnecessary "Note" and "Tip" callouts (stage-4, orchestrator-loop) | "Filler phrases and overlong parentheticals" (Content Quality) |
| Writing | Overlong parenthetical asides (stage-4, multiple lines) | "Filler phrases and overlong parentheticals" (Content Quality) |
| Writing | Redundant CRITICAL RULES REMINDER sections (all stage files) | "Systematic rule duplication" (Context & Token Efficiency) |
| Prompt | Incomplete PAL terminology in config keys (SKILL.md line 70) | "PAL-to-CLI migration incomplete" (Completeness) |
| Effectiveness | PAL references in user-facing labels (stage-1-setup line 135) | "PAL-to-CLI migration incomplete" (Completeness) |
| Reasoning | RTM gate blocking semantics ambiguity (orchestrator-loop line 260) | "RTM disposition gate contradiction" (Reasoning) |
| Architecture | RTM gate contradiction (SKILL.md Rule 28) | "RTM disposition gate contradiction" (Reasoning) |
| Context | All prior summaries in dispatch template (orchestrator-loop line 85) | "Supervisor context accumulation" (Architecture) |
| Effectiveness | Dispatch template context bloat for late stages (orchestrator-loop line 54) | "Supervisor context accumulation" (Architecture) |
