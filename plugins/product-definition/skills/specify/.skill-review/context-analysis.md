---
lens: context-engineering
target: feature-specify
target_path: plugins/product-definition/skills/specify
skill_version: 1.2.0
analysis_date: 2026-03-01
fallback_used: true
findings_count:
  critical: 1
  high: 2
  medium: 3
  low: 1
  info: 0
strengths_count: 3
total_reference_files: 17
total_reference_bytes: 153475
skill_md_words: 1998
---

# Context Engineering Efficiency Analysis: feature-specify

## Summary

The feature-specify skill demonstrates strong foundational context engineering. SKILL.md is precisely sized at 1,998 words (within the 1,500-2,000 word target), and the hub-spoke separation between always-loaded orchestrator content and on-demand stage references is well-structured. However, the skill suffers from significant token waste due to cross-file rule duplication (the same rules stated 3-5 times across files), an oversized reference footprint (153 KB across 17 files), and a dispatch template design that front-loads shared references into every coordinator context regardless of whether that coordinator needs them.

---

## Findings

### 1. Systematic Rule Duplication Across SKILL.md, Stage Files, and Orchestrator Loop (CRITICAL)

**Category:** Token management / Redundancy

**Current state:** Core rules are repeated across multiple files with slight wording variations. Specific examples:

- "design-brief.md is MANDATORY / NEVER skip" appears **12 times** across 5 files (SKILL.md lines 31, 32, 126, 255, 258, 299; stage-5-validation-design.md lines 19, 20, 314, 315; error-handling.md line 106, 147; orchestrator-loop.md lines 281-282).
- "User decisions are IMMUTABLE / NEVER re-ask" appears **10 times** across 6 files (SKILL.md lines 20, 224, 234, 297; checkpoint-protocol.md lines 42, 50; stage-4-clarification.md line 24; stage-1-setup.md lines 19, 402; recovery-migration.md lines 164, 184).
- "NEVER interact with users directly" appears **11 times** across 7 files (SKILL.md line 49; stage-2 line 21, 304; stage-3 lines 17, 224; stage-4 lines 28, 524; stage-5 lines 23, 318; stage-6 lines 20, 189).
- "No question/story/iteration limits" appears **6 times** across 3 files.
- Each stage file has both a CRITICAL RULES section at the top and a CRITICAL RULES REMINDER at the bottom, duplicating its own rules within the same file.

**Estimated token waste:** Each stage file carries ~100-200 words of duplicated rules (top + bottom bookends). Across 7 stage files plus SKILL.md end-section and orchestrator-loop.md, this is approximately 1,200-1,800 words (~1,500-2,300 tokens) of pure redundancy. When a coordinator loads its stage file + SKILL.md content from the dispatch template, it receives the same rules 3 times (SKILL.md Critical Rules, stage file top, stage file bottom).

**Recommendation:** Adopt a single-authority rule placement strategy:
1. SKILL.md "Critical Rules" section is the canonical location for cross-cutting rules (the orchestrator always loads this).
2. Stage files should contain ONLY stage-specific rules (e.g., "Edge case severity boost on cross-CLI agreement" belongs in stage-4, not SKILL.md).
3. Remove CRITICAL RULES REMINDER sections from stage files entirely. The LLM-attention concern that motivates bookending is already addressed by SKILL.md's own bookend structure.
4. Reduce each stage file's critical rules to genuinely unique constraints (target: 3-5 per stage, not 5-7 + repeated bookend).

**File:** `SKILL.md`, all `references/stage-*.md` files

---

### 2. Dispatch Template Injects Shared References Into Every Coordinator (HIGH)

**Category:** Progressive loading strategy / Context degradation risk

**Current state:** The coordinator dispatch template in `orchestrator-loop.md` (lines 54-99) loads `checkpoint-protocol.md` and `error-handling.md` into nearly every coordinator dispatch (6 of 7 stages get checkpoint-protocol; 6 of 7 get error-handling). Additionally, the config YAML is loaded for 6 of 7 stages. This means every coordinator context includes:
- Stage reference file: 700-2,550 words
- checkpoint-protocol.md: 180 words
- error-handling.md: 724 words
- specify-config.yaml: ~500-700 words (estimated)
- SKILL.md critical rules (embedded in template): ~500 words
- Prior stage summaries: grows with each stage (~200-1,500 words by Stage 5)

By Stage 5, the coordinator context is approximately 4,500-5,500 words (~6,000-7,500 tokens) before the coordinator does any work. For a 200K context window this is not catastrophic, but coordinators also load agents, templates, and spec content at runtime, which can push total context well beyond 50K tokens.

**Recommendation:**
1. Inline the checkpoint-protocol content (only 180 words / 1,604 bytes) directly into the dispatch template's CRITICAL RULES section. It is small enough that a dedicated file load adds more overhead (file path reference, @-load instruction) than embedding saves.
2. For error-handling.md (724 words), load it conditionally: only include for stages 2-5 (where CLI dispatch can fail), not stages 6-7.
3. For config YAML, consider extracting only the relevant keys per stage into the dispatch template rather than loading the entire config file.

**File:** `references/orchestrator-loop.md` (lines 43-50, dispatch profiles table)

---

### 3. stage-4-clarification.md is Disproportionately Large (HIGH)

**Category:** Token management / Selective reference loading

**Current state:** At 22,431 bytes / 2,550 words, `stage-4-clarification.md` is the largest reference file -- nearly 75% larger than the next largest file (`stage-1-setup.md` at 14,630 bytes). It contains:
- Figma Mock Gap Resolution (Step 4.0, 4.0.1, 4.0.2): ~600 words of Figma-specific logic
- RTM Disposition Resolution (Step 4.0a): ~400 words of RTM-specific logic
- MPA-EdgeCases CLI Dispatch (Step 4.1): ~400 words
- Auto-Resolve Gate (Step 4.1b): ~100 words (delegates to protocol file)
- Clarification File Writing (Step 4.2): ~200 words
- Answer Parsing (Step 4.3): ~350 words, plus RTM-specific parsing ~200 words
- MPA-Triangulation CLI Dispatch (Step 4.4): ~350 words
- Spec Update (Step 4.5): ~350 words, plus RTM recovery ~150 words
- Checkpoint (Step 4.6): ~200 words of YAML template
- Self-Verification: ~100 words

The coordinator loads this entire file even when it is on a re-entry path (only needs Steps 4.3-4.6, skipping 4.0-4.2). The Figma mock gap section (Step 4.0) is conditional and only relevant when `handoff_supplement.available == true AND figma_mock_gaps_count > 0`, yet it consumes ~600 words of context unconditionally.

**Recommendation:** Split `stage-4-clarification.md` into two files:
1. `stage-4-clarification.md` (core): Steps 4.1b through 4.6 (~1,200 words) -- the always-needed clarification flow
2. `references/figma-mock-gaps.md` (conditional): Step 4.0 (~600 words) -- loaded only when Figma gaps detected

Alternatively, add a clear re-entry skip marker so the coordinator can be instructed to "skip to Step 4.3" without needing to parse Steps 4.0-4.2. The existing re-entry handling block (lines 33-39) does this logically but the coordinator still loads all text into context.

**File:** `references/stage-4-clarification.md`

---

### 4. Configuration Table Duplicated Between SKILL.md and config-reference.md (MEDIUM)

**Category:** Redundancy / Token waste

**Current state:** SKILL.md lines 59-82 contain a 20-row configuration reference table with setting names, YAML paths, and defaults. `references/config-reference.md` (7,589 bytes, ~1,113 words) contains a more comprehensive version of the same data. When a coordinator loads both SKILL.md context (via the dispatch template) and config-reference.md (for Stages 2, 4, 5), it receives the configuration data twice.

Additionally, the config YAML file itself (`specify-config.yaml`) is also loaded for most stages, making this a triple redundancy for configuration values.

**Recommendation:** Remove the configuration table from SKILL.md (lines 59-82). Replace with a single-line reference: "Configuration: `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml` (key paths documented in `references/config-reference.md`)". This saves ~200 words from the always-loaded SKILL.md while keeping config accessible on demand.

**File:** `SKILL.md` (lines 59-82), `references/config-reference.md`

---

### 5. Summary Contract Schema Occupies Significant SKILL.md Space (MEDIUM)

**Category:** Attention placement / Always-loaded content optimization

**Current state:** The Summary Contract section (SKILL.md lines 173-214) consumes ~300 words (~15% of SKILL.md) with a detailed YAML schema template including all flag fields, pause type schemas, and option mapping structures. This is reference material needed by coordinators when writing their summary, not by the orchestrator at dispatch time.

The orchestrator only needs to know: (a) summary file path convention, (b) status values to handle, (c) key flags to check. The full YAML schema is coordinator-facing detail.

**Recommendation:** Reduce the Summary Contract in SKILL.md to a compact version (~100 words): path convention, status enum, and required fields list. Move the full YAML template to `orchestrator-loop.md` (which coordinators also receive) or create a `references/summary-schema.md` micro-reference. This reclaims ~200 words for higher-value always-loaded content.

**File:** `SKILL.md` (lines 173-214)

---

### 6. Reference Map Table Provides Limited Value in Always-Loaded Context (MEDIUM)

**Category:** Attention placement / Context efficiency

**Current state:** The Reference Map (SKILL.md lines 268-288) duplicates nearly the same information as the Stage Dispatch Table (lines 144-153) and the `references/README.md` File Usage table (lines 5-23). It lists 16 reference files with purpose and "Load When" columns. This is useful documentation but occupies ~250 words of the always-loaded SKILL.md.

The orchestrator already knows which reference to load because the Stage Dispatch Table maps each stage to its reference file. The Reference Map adds value only for cross-cutting references (checkpoint-protocol, error-handling, config-reference, cli-dispatch-patterns), which could be noted more compactly.

**Recommendation:** Merge the Reference Map into the Stage Dispatch Table by adding an "Extra Refs" column note, then reduce the Reference Map to list only non-stage-specific references (checkpoint-protocol, error-handling, config-reference, cli-dispatch-patterns, figma-capture-protocol, clarification-protocol, auto-resolve-protocol, recovery-migration). This saves ~100 words and reduces cognitive duplication.

**File:** `SKILL.md` (lines 268-288)

---

### 7. Rule Numbering Error Creates Ambiguity at Attention Boundary (LOW)

**Category:** Attention placement

**Current state:** The CRITICAL RULES section uses numbering 1-17, then 17b, then 18-28. The end-section (line 293) references "Rules 1-28" but the actual set has 29 entries (due to 17b). Rule 17b ("Spec Content Inline") is arguably the most important CLI dispatch rule (external CLIs cannot read local files), but its sub-numbered position reduces its attention weight compared to whole-numbered rules.

**Recommendation:** Renumber rules sequentially 1-29. Alternatively, group related rules under titled subsections (as currently done: "Core Workflow Rules", "Mandatory Requirements", "CLI Dispatch Rules", etc.) and remove individual numbering, since the subsection headers provide better scanning than sequential numbers for LLMs.

**File:** `SKILL.md` (lines 16-56, 291-301)

---

## Strengths

### S1. SKILL.md Word Count Hits Target Precisely

At 1,998 words, SKILL.md is at the upper boundary of the recommended 1,500-2,000 word range. This demonstrates disciplined content curation for the always-loaded context. The lean orchestrator pattern (dispatch table + stage pointers, not procedural detail) is well-executed.

### S2. Progressive Loading Architecture is Well-Designed

The three-tier loading strategy is clearly defined:
1. **Always loaded:** SKILL.md (1,998 words) -- dispatch table, critical rules, state schema
2. **Per-dispatch loaded:** Stage reference file + conditional shared references (orchestrator-loop.md governs)
3. **On-demand loaded:** Protocol files (clarification-protocol, auto-resolve-protocol, figma-capture-protocol) loaded by coordinators only when they reach the relevant step

The "Load When" guidance in both the Reference Map and README.md gives clear signals for selective loading. Stage files that delegate to protocol sub-files (e.g., stage-4 delegates to auto-resolve-protocol.md and clarification-protocol.md) demonstrate two-level progressive disclosure.

### S3. Attention-Favored Positioning of Critical Information

Critical rules are placed at both the beginning (lines 16-56) and end (lines 291-301) of SKILL.md, exploiting the primacy and recency effects in LLM attention. Each stage reference file follows the same bookend pattern (CRITICAL RULES at top, CRITICAL RULES REMINDER at bottom). While the content duplication within bookends is a concern (Finding 1), the structural positioning strategy itself is sound.
