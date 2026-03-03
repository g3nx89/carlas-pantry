---
lens: "Context Engineering Efficiency"
lens_id: "context"
skill_reference: "customaize-agent:context-engineering"
target: "design-handoff"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff"
fallback_used: true
findings_count: 8
critical_count: 0
high_count: 2
medium_count: 4
low_count: 1
info_count: 1
---

# Context Engineering Efficiency Analysis: design-handoff

## Summary

The design-handoff skill demonstrates strong context engineering fundamentals. SKILL.md is 1,979 words (333 lines), landing squarely within the 1,500-2,000 word target for always-loaded content. The hub-spoke architecture is well-implemented: SKILL.md functions as a lean dispatch table with clear `@$CLAUDE_PLUGIN_ROOT` load directives pointing to 9 reference files totaling ~14,420 words. The Reference Map table with "Load When" conditions enables genuinely selective loading.

However, there are notable context efficiency issues: significant rule repetition between SKILL.md and reference files wastes tokens when both are loaded; the gap-analysis.md reference file at 3,433 words contains extensive example tables that could be externalized; and the middle stages of SKILL.md contain procedural detail that belongs in references rather than the always-loaded orchestrator.

**Total always-loaded cost:** ~1,979 words (SKILL.md alone)
**Total potential context cost per stage:** ~1,979 + stage-specific reference (~1,100-3,400 words) = ~3,100-5,400 words
**Total if all references loaded simultaneously:** ~16,400 words -- this should never happen given the stage-gated loading pattern

## Findings

### Finding 1: Excessive Rule Duplication Between SKILL.md and Reference Files

**Severity:** HIGH
**Category:** Token management / Redundancy
**File:** `SKILL.md`, `references/gap-analysis.md`, `references/figma-preparation.md`, `references/output-assembly.md`

**Current state:** Several critical rules appear 4-7 times across SKILL.md and reference files:

- "Figma is source of truth" / "supplement NEVER duplicates Figma content" appears in: SKILL.md frontmatter (line 12), SKILL.md core philosophy (line 25), SKILL.md critical rules (line 34), SKILL.md end rules (line 327), output-assembly.md (lines 21, 186, 208) -- **7 occurrences**
- "ONE screen per dispatch" appears in: SKILL.md critical rules (line 36), SKILL.md workflow diagram (line 69), SKILL.md Stage 2 section (line 161), SKILL.md end rules (line 329), figma-preparation.md (lines 21, 48) -- **6 occurrences**
- Screenshot tool rule (`figma_capture_screenshot` vs `figma_take_screenshot`) appears in: SKILL.md allowed-tools (line 14), SKILL.md critical rules (line 41), gap-analysis.md (line 85), judge-protocol.md (lines 69, 127) -- **5 occurrences**
- "Coordinator never talks to users" appears in: SKILL.md critical rules (line 39), SKILL.md end rules (line 332), figma-preparation.md dispatch prompts (lines 77, 203, 375) -- **5 occurrences**

When Stage 2 executes, SKILL.md and figma-preparation.md are both in context, meaning the "ONE screen per dispatch" rule is present 6 times consuming ~150 tokens on repetition alone. Across all duplicated rules, an estimated 300-500 tokens are wasted on redundancy per stage execution.

**Recommendation:** In reference files, replace full rule restatements with brief cross-references: `> Per SKILL.md Rule 3: one screen per dispatch.` This preserves the cue for attention while eliminating the verbose restatement. Keep the full formulation in exactly two places: SKILL.md Critical Rules (Start) and SKILL.md Critical Rules (End) -- the two highest-attention positions. The dispatch prompt instances ("You MUST NOT interact with users directly") are acceptable since those are agent prompts that may execute without SKILL.md in context.

---

### Finding 2: gap-analysis.md Example Tables Inflate Context Unnecessarily

**Severity:** HIGH
**Category:** Progressive loading / Context pressure
**File:** `references/gap-analysis.md`

**Current state:** gap-analysis.md is 3,433 words (471 lines) -- the largest reference file by a significant margin. Approximately 40% of its content (lines 93-161, roughly 1,200 words) consists of example tables for each of the 6 gap categories. Each table provides 3-5 concrete examples showing "Example Screen | Element | Gap" patterns. For instance, the Behaviors category alone has a 4-row table with multi-sentence gap descriptions.

These examples are useful for grounding the gap analyzer agent's understanding, but they load into the coordinator context even though the coordinator never performs gap analysis itself -- it only dispatches the agent and processes the output.

**Recommendation:** Extract the 6 category example tables into a dedicated reference file: `references/gap-category-examples.md` (~1,200 words). In gap-analysis.md, keep only the category names, severity classification rules, and confidence tagging rules. Add a load directive in gap-analysis.md: `Agent prompt SHOULD include @$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/gap-category-examples.md when dispatching handoff-gap-analyzer.` This reduces the coordinator's context load by ~35% while ensuring the agent still receives the examples.

---

### Finding 3: Stage Sections in SKILL.md Contain Procedural Detail That Belongs in References

**Severity:** MEDIUM
**Category:** Attention placement / Always-loaded content sizing
**File:** `SKILL.md`

**Current state:** Several stage sections in SKILL.md go beyond dispatch-table-level description into procedural detail. Examples:

- Stage 2 (lines 155-172) includes a 5-step numbered algorithm ("IF TIER 2/3: dispatch...", "FOR EACH screen...", "IF state shows screen completed -> SKIP", etc.) that duplicates the screen loop in figma-preparation.md
- Stage 3.5 (lines 210-224) includes a 4-option decision list ("Create / Designer creates / Supplement only / Skip") that is detailed in design-extension.md
- Stage 5 (lines 252-267) includes a 7-step assembly algorithm that duplicates output-assembly.md

These sections push SKILL.md toward the upper bound of its word budget and place mid-priority procedural content in the always-loaded zone, where it competes for attention with the critical rules and dispatch table.

**Recommendation:** Reduce each stage section to 2-3 lines: purpose sentence, delegation model (inline/agent/loop), and the `Read and follow` directive. For example, Stage 2 could be:

```markdown
## Stage 2 -- Figma Preparation (Agent Loop)

Per-screen Figma file preparation via sequential `handoff-figma-preparer` dispatch.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/figma-preparation.md`

**Mode guard:** Skip entirely in Quick mode (`--quick`).
```

This would save approximately 200-300 words from SKILL.md, keeping it well within the 1,500-word lean orchestrator target.

---

### Finding 4: Workflow Diagram Duplicates the Stage Dispatch Table

**Severity:** MEDIUM
**Category:** Token management / Redundancy
**File:** `SKILL.md` (lines 60-112)

**Current state:** SKILL.md contains both an ASCII workflow diagram (53 lines, ~250 words) and a Stage Dispatch Table (lines 118-129, ~150 words). Both convey the same information: the ordered sequence of stages, their delegation models, and their conditional triggers. The diagram adds visual flow arrows but no information that the table lacks.

**Recommendation:** Remove the ASCII workflow diagram. The Stage Dispatch Table is more information-dense (includes Reference File and User Pause columns) and more LLM-parseable. ASCII art consumes tokens without improving LLM comprehension -- LLMs process structured tables more reliably than visual flow diagrams. This saves ~250 words (approximately 350 tokens) from the always-loaded context.

---

### Finding 5: Reference Map Table Partially Duplicates Stage Dispatch Table

**Severity:** MEDIUM
**Category:** Token management / Redundancy
**File:** `SKILL.md` (lines 307-320 vs lines 118-129)

**Current state:** The Reference Map table (lines 307-320) and the Stage Dispatch Table (lines 118-129) both list all reference files with their associated stages and purposes. The Reference Map adds a "Load When" column; the Stage Dispatch Table adds "Delegation" and "User Pause?" columns. These tables share 3 of 4 columns (Stage, Name/Reference, Purpose/Reference File).

**Recommendation:** Merge into a single table combining the unique columns from each:

```markdown
| Stage | Name | Delegation | Reference File | Load When | User Pause? |
```

This eliminates one 13-row table (~130 words) while preserving all information. The merged table serves as both the dispatch reference and the progressive loading guide.

---

### Finding 6: Critical Rules End Section Could Be More Compact

**Severity:** LOW
**Category:** Attention placement
**File:** `SKILL.md` (lines 324-334)

**Current state:** The "CRITICAL RULES (High Attention Zone -- End)" section (lines 324-334) restates 7 rules in abbreviated form. This is a sound attention-engineering pattern (bookend repetition exploits LLM recency bias). However, the abbreviated rules are still 7 full bullet points consuming ~100 words.

**Recommendation:** Compress the end-of-file rules to a numbered list of rule keywords only, referencing back to the start section:

```markdown
## CRITICAL RULES (High Attention Zone -- End)

Rules 1-8 above are MANDATORY. Key mnemonics:
1. Figma source of truth  2. figma-console required  3. One screen per dispatch
4. Visual diff non-negotiable  5. Judge = dedicated phase  6. No user contact
7. Config-only thresholds  8. Screenshots via figma-console
```

This preserves the recency-bias benefit while saving ~50 words. The terse format also increases visual distinctiveness, which aids attention.

---

### Finding 7: No Explicit Context Budget Declaration for Reference File Loading

**Severity:** MEDIUM
**Category:** Context degradation risk
**File:** `SKILL.md`

**Current state:** The Reference Map table specifies "Load When" conditions per reference file, which is excellent for selective loading. However, there is no explicit guidance on what to do when context is running low. In a long workflow with many screens, the orchestrator may have loaded multiple reference files, accumulated per-screen state data, judge verdicts, and agent summaries. At that point, context pressure could cause earlier instructions (particularly the Stage Dispatch Table and Critical Rules) to degrade.

The skill also does not declare maximum expected context consumption per stage or provide guidance for context-constrained scenarios (e.g., "If context exceeds X tokens, drop example tables and rely on category names only").

**Recommendation:** Add a "Context Management" section to SKILL.md (5-7 lines) with:
1. Estimated tokens per stage (e.g., "Stage 3 loads ~4,500 tokens of reference content")
2. A degradation protocol: "When context > 80% capacity: (a) drop prior stage reference content, (b) retain only state file and current stage reference, (c) Critical Rules must never be evicted"
3. Per-reference priority tiers: Tier 1 (never drop: state-schema, current stage ref), Tier 2 (drop after stage completes: prior stage refs), Tier 3 (drop first: README)

---

### Finding 8: gap-analysis.md Gap Report Format Section Is a Template, Not Instructions

**Severity:** INFO
**Category:** Progressive loading
**File:** `references/gap-analysis.md` (lines 300-410)

**Current state:** Lines 300-410 of gap-analysis.md contain a full output format specification with example markdown including YAML frontmatter, per-screen gap tables, missing screen tables, mermaid navigation diagrams, and a "No Supplement Needed" pattern explanation. This is effectively a template (111 lines, ~800 words) embedded within an instruction file.

This is actually well-placed for context efficiency: the gap analyzer agent needs this format when writing its output, and having it in the same file as the dispatch instructions means only one file load is needed. However, if the coordinator context is the bottleneck rather than the agent context, this template content inflates the coordinator's load unnecessarily since the coordinator only verifies the output exists, not its internal format.

**Recommendation:** No action required -- this is an observation. The current placement is a reasonable trade-off. If coordinator context becomes a concern in practice, the format specification could be extracted to `references/gap-report-format.md` and loaded only by the agent prompt. But this optimization is premature given the current architecture where the agent reads gap-analysis.md directly.

---

## Strengths

### Strength 1: Exemplary Hub-Spoke Architecture

SKILL.md achieves the lean orchestrator pattern at 1,979 words -- within the 1,500-2,000 word target. It functions as a pure dispatch table with no procedural implementation embedded (the Stage section overflows noted in Finding 3 are minor). The `@$CLAUDE_PLUGIN_ROOT` load directives ensure reference files are loaded on-demand rather than eagerly. The Reference Map table with "Load When" conditions gives the orchestrator explicit guidance on which reference to load at each stage, enabling genuinely progressive context loading. This is the gold standard for skill architecture.

### Strength 2: High-Attention Bookend Pattern for Critical Rules

The "CRITICAL RULES (High Attention Zone -- Start)" at line 31 and "CRITICAL RULES (High Attention Zone -- End)" at line 324 exploit two well-documented LLM attention patterns: primacy bias (instructions near the top of context receive higher attention) and recency bias (instructions near the end receive a secondary attention boost). Placing the 8 most important rules at both positions ensures they survive context pressure even when the middle sections degrade. The explicit "High Attention Zone" label is also effective -- it signals to the LLM that these sections warrant elevated processing priority.

### Strength 3: Stage-Gated Reference Loading Prevents Context Bloat

Each stage section contains exactly one `Read and follow` directive pointing to its specific reference file. Stages that share a reference (all judge checkpoints use `judge-protocol.md`) specify the sub-section (e.g., "Stage 2J rubric"). This means at any point in execution, the orchestrator needs only SKILL.md (~1,979 words) plus one reference file (~1,100-3,400 words), keeping total context well under 6,000 words for the skill's own content. The README.md file is explicitly marked for "Orientation" only, preventing it from being loaded during execution stages.

### Strength 4: YAML Frontmatter in Reference Files Enables Metadata-First Discovery

Each reference file includes YAML frontmatter with `stage`, `description`, `agents_dispatched`, `artifacts_written`, and `config_keys_used`. This enables a metadata-first loading strategy: the orchestrator can read only the frontmatter to verify it has the right file before loading the full content. This is a context-efficient pattern that prevents wasted tokens from loading the wrong reference file.
