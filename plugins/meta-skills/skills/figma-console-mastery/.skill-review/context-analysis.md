---
lens: "Context Engineering Efficiency"
lens_id: "context"
skill_reference: "customaize-agent:context-engineering"
target: "figma-console-mastery"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery"
fallback_used: true
findings_count: 9
critical_count: 1
high_count: 2
medium_count: 3
low_count: 2
info_count: 1
---

# Context Engineering Efficiency Analysis: figma-console-mastery

## Summary

The figma-console-mastery skill demonstrates strong architectural awareness of context window constraints, with a well-defined three-tier loading strategy and a lean SKILL.md that serves as an effective dispatch table. However, the Tier 1 "always-load" designation carries a significant token cost (~7,257 words / ~9,700 tokens for two files), and the SKILL.md itself exceeds the target word count for always-loaded content. The Selective Reference Loading section, while thorough, occupies substantial space with a flat list of 22 references that could be restructured for better LLM attention. The convergence-protocol.md file, marked as Tier 1, contains extensive procedural detail (batch script templates, delegation architecture diagrams) that is only needed during execution phases, not at skill load time.

## Findings

### F1: Tier 1 Always-Load Budget is Excessive

**Severity**: CRITICAL
**Category**: Token management
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (Loading Tiers definition, line 214)

**Current state**: The Loading Tiers section defines two files as Tier 1 (always-load): `recipes-foundation.md` (2,352 words) and `convergence-protocol.md` (4,905 words). Combined with SKILL.md itself (1,739 words), the always-loaded payload is approximately 9,000 words (~12,000 tokens). This is loaded into context before any task-specific work begins.

The `convergence-protocol.md` file contains substantial content that is only relevant during execution:
- Batch Script Templates (Section 3): ~1,500 words of JavaScript code examples for batch rename, batch move, batch fill
- Subagent Delegation Architecture (Section 4): ~1,800 words including a full ASCII delegation tree, prompt templates with 15 mandatory rules, phase-specific prompt extensions
- Session Snapshot Schema (Section 5): ~700 words of JSON schema and migration notes
- Compact Recovery Protocol (Section 6): ~400 words

Only Sections 1 (Operation Journal, ~800 words) and 2 (Convergence Check, ~600 words) contain rules that genuinely need to be understood before any operation.

**Recommendation**: Split `convergence-protocol.md` into two files:
1. `convergence-core.md` (Tier 1, ~1,400 words): Operation Journal format + rules, Convergence Check rules (C1-C9), Journal Lifecycle. This is the "always know" content.
2. `convergence-execution.md` (Tier 2, ~3,500 words): Batch Scripting Protocol, Subagent Delegation Model, Session Snapshot schema, Compact Recovery. Load when entering Phase 2+ or when delegating subagents.

This reduces Tier 1 from ~7,257 words to ~3,752 words (48% reduction), freeing ~4,700 tokens for task-specific context.

---

### F2: SKILL.md Exceeds Target Word Count

**Severity**: HIGH
**Category**: Token management
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md`

**Current state**: SKILL.md is 1,739 words / 255 lines. The target for always-loaded content is 1,500-2,000 words. While technically within the upper bound, the file includes content that is redundant with references or could be deferred:

- The "Quick Reference -- Core Tools" table (lines 104-118, ~120 words) duplicates information available in `tool-playbook.md`.
- The "Troubleshooting (Top 5)" table (lines 239-248, ~100 words) duplicates the first 5 rows of `anti-patterns.md`'s 37-row troubleshooting index.
- The "Sequential Thinking Integration" section (lines 220-230, ~80 words) documents an optional feature that most sessions will not use.
- The "Compound Learning" section (lines 232-236, ~60 words) documents another optional feature.

These four sections total ~360 words. Removing them would bring SKILL.md to ~1,380 words, well within the ideal 1,500-word target while leaving room for the more critical content to breathe.

**Recommendation**: Remove the Quick Reference table (it adds no information beyond what tool-playbook.md provides, and tool selection happens at Tier 2 loading time). Condense Sequential Thinking and Compound Learning to a single 2-line "Optional Integrations" note pointing to references. Keep the Top 5 Troubleshooting -- it provides genuine quick-recovery value at the always-loaded tier. Net savings: ~200 words.

---

### F3: Selective Reference Loading Section Lacks Attention Optimization

**Severity**: HIGH
**Category**: Attention placement
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (lines 142-218)

**Current state**: The Selective Reference Loading section is a flat list of 22 `Read:` directives spanning 76 lines (lines 142-218). Each entry has a one-line comment and a `Read:` path. This section occupies 30% of SKILL.md's total line count. LLM attention degrades in the middle of long uniform lists -- items 8-16 receive less attention than items 1-4 and 19-22.

The section structure is:
```
# Tool selection -- which of the 60 tools to call and when
Read: .../tool-playbook.md

# Plugin API reference -- writing figma_execute code
Read: .../plugin-api.md
... (20 more entries)
```

After the flat list, the Loading Tiers subsection (lines 212-218) provides the actual tier classification, but by this point an LLM has already processed 70 lines of uniform path listings.

**Recommendation**: Restructure the section to lead with the tier classification (currently at the bottom) and group the `Read:` directives by tier within collapsible or clearly headed subsections:

```markdown
## Selective Reference Loading

### Tier 1 -- Always Load
Read: .../recipes-foundation.md
Read: .../convergence-protocol.md

### Tier 2 -- Load by Task
(10 entries, grouped by task type)

### Tier 3 -- Load by Need
(10 entries)
```

This places the most critical loading decisions (Tier 1) at the point of highest attention and allows the LLM to skip Tier 3 entries entirely when they are not relevant. The tier headers serve as attention anchors.

---

### F4: Code-Heavy References Inflate Token Cost Disproportionately

**Severity**: MEDIUM
**Category**: Token management
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/convergence-protocol.md` (Batch Script Templates, lines 253-327) and `recipes-foundation.md` (full file)

**Current state**: `convergence-protocol.md` contains three complete batch script templates (batch rename: 25 lines, batch move: 20 lines, batch fill: 18 lines) totaling ~600 words of JavaScript code. `recipes-foundation.md` (Tier 1) contains 534 lines with extensive code blocks including the CSS Grid Card Layout recipe (80 lines of JavaScript) and the Proportional Resize Calculator (75 lines of JavaScript).

Code blocks consume approximately 1.3x more tokens per word than prose due to syntax tokens, indentation, and structural characters. The CSS Grid recipe and Proportional Resize Calculator in `recipes-foundation.md` are task-specific patterns, not foundational patterns needed on every invocation.

**Recommendation**: In `recipes-foundation.md`, move the CSS Grid Card Layout recipe and Proportional Resize Calculator to `recipes-advanced.md` (Tier 3). The foundation file should contain only the patterns needed for ANY `figma_execute` call: the IIFE wrapper, font preloading, node references, structured data return, and basic layout recipes (page container, horizontal row, wrap layout, absolute badge). This would reduce `recipes-foundation.md` from 2,352 words to approximately 1,500 words.

---

### F5: Total Reference Corpus is Very Large

**Severity**: MEDIUM
**Category**: Context degradation risk
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/README.md`

**Current state**: The total reference corpus is 75,598 words across 22 files. The largest files are:
- `anti-patterns.md`: 7,341 words
- `plugin-api.md`: 6,743 words
- `recipes-components.md`: 5,600 words
- `convergence-protocol.md`: 4,905 words
- `quality-procedures.md`: 4,825 words
- `quality-audit-scripts.md`: 4,768 words

In a typical multi-phase design session, a subagent loads SKILL.md + Tier 1 + 2-3 Tier 2 files. For example, a Phase 2 screen subagent loads: SKILL.md (1,739) + recipes-foundation.md (2,352) + convergence-protocol.md (4,905) + recipes-components.md (5,600) + tool-playbook.md (3,772) = 18,368 words (~24,500 tokens). This is approximately 12% of a 200K context window, which is reasonable but leaves limited room for the actual Figma API responses, journal content, and multi-turn conversation.

If the user asks a question that triggers additional reference loading (e.g., quality audit), adding quality-dimensions.md (3,449), quality-audit-scripts.md (4,768), and quality-procedures.md (4,825) pushes the total to ~31,410 words (~42,000 tokens), which is 21% of context consumed by reference material alone.

**Recommendation**: Add a "Maximum concurrent load" guideline to the Loading Tiers section. For example: "Load at most 4 reference files simultaneously beyond Tier 1. If additional references are needed, unload (stop referencing) files no longer actively needed for the current phase." This gives Claude an explicit budget signal rather than relying on implicit judgment about when context is getting full.

---

### F6: Frontmatter Description is a Single Dense Sentence

**Severity**: MEDIUM
**Category**: Attention placement
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (lines 1-5)

**Current state**: The frontmatter `description` field is a single 94-word sentence containing 11 trigger phrases, 6 capability descriptions, and a cross-skill delegation note. This is the first content the LLM processes and is critical for skill matching, but the density makes it difficult to parse:

```yaml
description: This skill should be used when the user asks to "create a Figma design", "use figma_execute", "design in Figma", "create Figma components", "set up design tokens in Figma", "build a UI in Figma", "use figma-console MCP", "automate Figma design", "create variables in Figma", "instantiate Figma component", or when developing skills/commands that use the Figma Console MCP server. Provides 2 flows (Design Session and Handoff QA), subagent-first orchestration, quality model, and selective reference loading. For Draft-to-Handoff and Code Handoff preparation workflows, use the design-handoff skill (product-definition plugin) which delegates Figma operations to this skill's references.
```

LLMs attend strongly to the beginning and end of text blocks but lose attention in the middle of long sequences. The trigger phrases in positions 5-8 ("build a UI in Figma", "use figma-console MCP", "automate Figma design", "create variables in Figma") are in the lowest-attention zone.

**Recommendation**: Split the description into a concise primary description and a separate `triggers` list in the frontmatter (if the plugin format supports it), or restructure the description to lead with the highest-level summary and follow with trigger phrases in a more scannable format. If the format constrains to a single field, at minimum front-load the broadest triggers ("design in Figma", "use figma-console MCP") and move narrow triggers to the end.

---

### F7: Cross-Cutting Principles Repeat Content from Essential Rules

**Severity**: LOW
**Category**: Token management (redundancy)
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (lines 48-55, lines 121-140)

**Current state**: The "Cross-Cutting Principles" section (P1, P2, P3) on lines 48-55 and the "Essential Rules (Top 8)" section on lines 121-140 partially overlap:

- P1 ("figma-console Only") is conceptually covered by MUST rule 7 ("Native-tools-first")
- P2 ("Subagent-First (Sonnet)") is restated nearly verbatim as MUST rule 8 ("Subagents inherit skill context")
- P3 ("Explicit User Interaction") is a standalone principle not duplicated in rules

The two sections together consume ~300 words expressing partially overlapping concerns.

**Recommendation**: Merge Cross-Cutting Principles into the Essential Rules section header as a 2-sentence preamble: "All operations use figma-console MCP exclusively. All Figma modifications are delegated to Sonnet subagents; main context orchestrates only." Then integrate P3 into the MUST rules list. This saves ~100 words and eliminates the cognitive overhead of two separate "rules" sections.

---

### F8: No Explicit Context Pressure Signal for Claude

**Severity**: LOW
**Category**: Context degradation risk
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md`

**Current state**: The skill does not include any explicit guidance for behavior when context window pressure increases. There is no instruction for what to prioritize retaining vs. what to let go during context compaction. The convergence-protocol.md discusses compact recovery (re-reading journal and session state), but SKILL.md itself does not tell Claude what the minimum viable context is for continued operation.

In a long design session, Claude's context will fill with Figma API responses, screenshots, journal entries, and conversation history. When compaction occurs, the system prompt (including SKILL.md) is retained, but loaded reference files may be lost from working memory.

**Recommendation**: Add a 3-line "Context Pressure" note to SKILL.md (near the Essential Rules section) stating the minimum viable context: "After context compaction, the minimum recovery set is: (1) session-state.json, (2) per-screen journal for current screen, (3) recipes-foundation.md. Re-load additional references only as needed for the current operation. See convergence-protocol.md Section 6 for full compact recovery."

---

### F9: Loading Tier Comments Provide Good Disambiguation

**Severity**: INFO
**Category**: Selective reference loading patterns
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (lines 142-210)

**Current state**: Each `Read:` directive in the Selective Reference Loading section includes a comment line describing both the content and the loading condition:

```
# Foundation patterns -- ALWAYS load when writing figma_execute code
Read: .../recipes-foundation.md

# Error catalog, anti-patterns, troubleshooting -- debugging, recovery, hard constraints
Read: .../anti-patterns.md
```

These comments serve as effective routing signals for Claude to decide which references to load. The "ALWAYS load when writing figma_execute code" annotation is particularly helpful as a mandatory loading trigger.

**Recommendation**: No action required. This is a well-executed pattern. The inline comments provide both content summary and loading condition in a single line, enabling selective loading without consulting the README.md first.

---

## Strengths

### S1: Well-Architected Three-Tier Progressive Loading

The skill implements a clear three-tier progressive loading strategy (Tier 1: Always, Tier 2: By task, Tier 3: By need) that maps directly to context engineering best practices. The tier assignments are logically sound -- foundation patterns and convergence rules are always-loaded because they apply to every operation, while quality audit scripts and M3 recipes are deferred to Tier 3 because they apply only to specific workflow phases. This architecture enables Claude to operate with minimal context for simple tasks (just SKILL.md + Tier 1 = ~4,100 words) and progressively load more for complex multi-phase workflows.

### S2: SKILL.md Functions as an Effective Lean Dispatch Table

SKILL.md at 1,739 words and 255 lines successfully functions as a lean orchestrator document. It contains:
- Flow summaries with phase tables (not full procedures)
- Decision matrix with tool routing (not full tool reference)
- Top 8 MUST / Top 5 AVOID rules (not full 37 rules)
- Troubleshooting top 5 (not full 37-entry index)

Each section ends with a cross-reference to the detailed file (e.g., "Full rules (23 MUST + 14 AVOID): references/essential-rules.md"). This "summary + pointer" pattern is the ideal hub-spoke model for context engineering -- Claude gets enough information to make routing decisions without loading full detail.

### S3: Reference README.md Enables Informed Selective Loading

The `references/README.md` file provides a comprehensive File Usage Table with line counts, purposes, and "Load When" conditions for all 22 reference files. It also includes a Cross-References table and Content Ownership table that prevent duplication. This metadata layer enables Claude (or a subagent) to make informed decisions about which references to load without needing to read the references themselves -- a form of progressive disclosure that is especially valuable under context pressure.

### S4: Subagent Context Reduction Pattern

The convergence-protocol.md Subagent Delegation Model explicitly addresses context engineering for subagents: "Subagents receive only the journal for their assigned screen (context reduction)" and the prompt template specifies exactly which references each phase's subagent should load. This per-phase reference scoping prevents subagents from loading the full 75K-word corpus and keeps each subagent's context focused on its specific task.
