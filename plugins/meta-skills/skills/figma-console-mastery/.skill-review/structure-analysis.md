---
lens: "Structure & Progressive Disclosure"
lens_id: "structure"
skill_reference: "plugin-dev:skill-development"
target: "figma-console-mastery"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery"
fallback_used: false
findings_count: 9
critical_count: 0
high_count: 2
medium_count: 4
low_count: 2
info_count: 1
---

# Structure & Progressive Disclosure Analysis: figma-console-mastery

## Summary

The figma-console-mastery skill demonstrates strong structural maturity with a well-organized progressive disclosure hierarchy across 22 reference files, a lean SKILL.md (~1,739 words), and a comprehensive reference README with file usage, cross-reference, and content ownership tables. The main areas for improvement are the SKILL.md body exceeding its lean orchestrator role in the Selective Reference Loading section (67 lines of verbatim Read paths that could be a compact table), a cross-file inconsistency where `flow-procedures.md` omits Category 10 that both SKILL.md and `socratic-protocol.md` reference, and the absence of `examples/` and `scripts/` directories despite the skill containing numerous executable JavaScript audit scripts and code recipes that would benefit from standalone runnable files.

## Findings

### 1. Selective Reference Loading block inflates SKILL.md body
- **Severity**: HIGH
- **Category**: Progressive disclosure
- **File**: `SKILL.md` (lines 143-210)
- **Current**: The "Selective Reference Loading" section contains 67 lines of verbatim `Read:` directives — one per reference file with full `$CLAUDE_PLUGIN_ROOT` paths and inline comments. This block alone accounts for roughly 400 words (approximately 23% of the skill body). The subsequent "Loading Tiers" subsection (lines 212-218) already provides a compact tier-based summary of the same information.
- **Recommendation**: Replace the 67-line verbatim block with a compact table mapping each file to its tier and one-line purpose. The tier summary already captures the essential loading logic. If the full `Read:` path format is needed for tooling, extract it to a dedicated `references/loading-manifest.md` file and reference it from SKILL.md. This would reduce SKILL.md by ~60 lines while preserving discoverability.

### 2. Category 10 missing from flow-procedures.md mode subsets
- **Severity**: HIGH
- **Category**: Reference file wiring
- **File**: `references/flow-procedures.md` (line 129-130)
- **Current**: SKILL.md line 73 states "11 categories (Cat. 0-10)" and `socratic-protocol.md` defines Category 10 (Content & Interaction Specifications). However, `flow-procedures.md` only defines Categories 0-9. The mode-specific subset on line 129 (`Create mode: Run Cat. 0, 1, 2 (optional), 5, 6, 7, 8. Skip Cat. 3, 4, 9`) and line 130 (`Restructure mode: Run all categories (0-9)`) both omit Category 10. A subagent loading `flow-procedures.md` for phase execution would have no instruction to run Category 10.
- **Recommendation**: Add a `#### Category 10 — Content & Interaction Specifications (optional)` section to `flow-procedures.md` (after Category 9) with a brief procedure summary and cross-reference to `socratic-protocol.md` for the full question templates. Update the mode-specific subsets: Restructure should list "all categories (0-10)" and Create should explicitly note Cat. 10 as optional or skipped.

### 3. No examples/ or scripts/ directories
- **Severity**: MEDIUM
- **Category**: Directory layout
- **File**: Skill root directory
- **Current**: The skill directory contains only `SKILL.md`, `references/`, and `.skill-review/`. There are no `examples/` or `scripts/` directories. The skill contains numerous JavaScript code patterns (audit scripts A-I in `quality-audit-scripts.md`, recipes in multiple files) that are embedded inline within reference Markdown files rather than stored as standalone runnable scripts.
- **Recommendation**: Consider extracting the most frequently used scripts into a `scripts/` directory — particularly the quality audit scripts (A through I) from `quality-audit-scripts.md`. These are deterministic JavaScript code blocks that subagents copy-paste into `figma_execute` calls. Standalone `.js` files would be token-efficient (executable without loading the surrounding prose) and easier to version/test independently. A `scripts/audit/` subdirectory with files like `script-a-parent-context.js` through `script-i-prototype-connections.js` would align with the skill-development lens recommendation that scripts "may be executed without loading into context."

### 4. SKILL.md frontmatter description length
- **Severity**: MEDIUM
- **Category**: Frontmatter quality
- **File**: `SKILL.md` (line 3)
- **Current**: The `description` field is 89 words and contains 10 specific trigger phrases, a capability summary, and a cross-skill delegation note for `design-handoff`. While the trigger phrases are excellent and specific, the trailing sentence about `design-handoff` delegation ("For Draft-to-Handoff and Code Handoff preparation workflows, use the design-handoff skill...") is contextual guidance that belongs in the SKILL.md body (where it already exists on line 11 and lines 253-255), not in the always-loaded metadata description.
- **Recommendation**: Remove the `design-handoff` delegation sentence from the frontmatter description. The description already has this guidance in the body's "Scope" block (line 11) and "When NOT to Use This Skill" section (line 255). The description should focus on trigger phrases that cause this skill to load, not on routing logic for other skills. Target ~60 words for the description.

### 5. Reference file size imbalance — no grep guidance for large files
- **Severity**: MEDIUM
- **Category**: Progressive disclosure
- **File**: `SKILL.md`
- **Current**: The skill-development lens recommends: "If files are large (>10k words), include grep search patterns in SKILL.md." Several reference files are very large: `plugin-api.md` (1,308 lines), `recipes-components.md` (1,401 lines), `recipes-restructuring.md` (1,022 lines), `recipes-advanced.md` (974 lines), `quality-audit-scripts.md` (966 lines), `quality-procedures.md` (791 lines). SKILL.md provides no grep/search patterns for navigating these large files when loaded into context.
- **Recommendation**: Add a "Navigation Hints" subsection (or inline notes per tier) with grep patterns for the largest reference files. For example: "In `plugin-api.md`, search for `## Node Creation`, `## Auto-Layout`, `## Variables` to jump to relevant sections. In `recipes-components.md`, search for the component name (e.g., `## Card`, `## Modal`)." This helps subagents efficiently navigate large files without reading them end-to-end.

### 6. Compatibility marker inconsistency across reference files
- **Severity**: MEDIUM
- **Category**: Writing style
- **File**: Multiple reference files
- **Current**: SKILL.md includes a compatibility note: `> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)`. The reference files `essential-rules.md` and `flow-procedures.md` include the same compatibility marker. However, this was not verified across all 22 reference files — some files may lack the compatibility marker entirely. The CLAUDE.md quality checklist requires "Workflow templates include version/compatibility markers."
- **Recommendation**: Audit all 22 reference files for the presence of the compatibility marker. For files that lack it, add the standard `> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)` header. Alternatively, centralize the version marker in SKILL.md only and add a note that all references are verified against the same version, to avoid maintaining 23 duplicate version strings.

### 7. README.md line counts vs actual line counts discrepancy
- **Severity**: LOW
- **Category**: Reference file wiring
- **File**: `references/README.md`
- **Current**: The README.md File Usage Table shows line counts (e.g., `convergence-protocol.md` listed as "~650") but actual `wc -l` shows 645 lines. The `essential-rules.md` is listed as 63 lines (matches). Some entries use approximate markers (`~650`) while others use exact numbers. Minor discrepancies are expected after edits, but the approximate notation is inconsistent.
- **Recommendation**: Either use exact counts updated on each release (and note them as "as of vX.Y.Z") or consistently use approximate counts with `~` prefix for all entries. A script that auto-generates the line count column from `wc -l` would prevent drift.

### 8. Loading Tiers list files but not the README itself
- **Severity**: LOW
- **Category**: Reference file wiring
- **File**: `SKILL.md` (lines 212-218)
- **Current**: The Loading Tiers section categorizes all 22 reference files into Tier 1 (always), Tier 2 (by task), and Tier 3 (by need). However, `references/README.md` itself is not mentioned in any tier. The README contains the File Usage Table, Cross-References, and Content Ownership tables — all useful for understanding which reference to load.
- **Recommendation**: Add `README.md` to Tier 2 or note it as a meta-file: "For reference file discovery and cross-reference lookup, consult `references/README.md`." This helps subagents that need to understand the reference ecosystem before selecting which files to load.

### 9. Imperative writing style compliance
- **Severity**: INFO
- **Category**: Writing style
- **File**: `SKILL.md`
- **Current**: The SKILL.md body consistently uses imperative/infinitive form throughout. No instances of second-person "you/your" were found. Instructions use verb-first construction (e.g., "Call `figma_get_status` before any operation", "Evaluate G0->G1a->G1b->G2->G3 in order"). The frontmatter description correctly uses third-person ("This skill should be used when the user asks to...").
- **Recommendation**: None required. This is a positive observation.

## Strengths

1. **Exemplary progressive disclosure architecture** -- The skill demonstrates a textbook three-tier loading system. SKILL.md is 256 lines (~1,739 words) containing only essential procedures, decision matrices, and quick-reference tables. All detailed content (12,469 lines across 22 reference files) lives in `references/` with explicit loading tiers (Always/By-task/By-need). The Loading Tiers subsection provides a clear, scannable summary of when to load each file. This is among the most disciplined progressive disclosure implementations across the plugin ecosystem.

2. **Comprehensive reference wiring with ownership tracking** -- The `references/README.md` goes beyond a simple file listing. It includes three distinct tables: (a) File Usage Table with line counts, purposes, and load-when conditions; (b) Cross-References mapping inter-file dependencies; (c) Content Ownership table preventing duplication by declaring exactly one canonical file per topic. This three-table approach ensures subagents can discover relevant references without loading SKILL.md and prevents the content duplication that typically plagues large reference collections. The 145-line Content Ownership section alone documents 60+ content items mapped to their canonical files.

3. **Strong frontmatter trigger phrases** -- The description includes 10 specific, concrete trigger phrases that users would actually say ("create a Figma design", "use figma_execute", "create variables in Figma", etc.). These cover the full spectrum of skill capabilities — from beginner queries ("design in Figma") to advanced operations ("use figma-console MCP"). The description also correctly uses third-person voice throughout.

4. **Consistent cross-referencing from SKILL.md body** -- Every section in SKILL.md that summarizes content from a reference file includes an explicit pointer to the full reference (e.g., "**Full procedures**: `references/flow-procedures.md`", "**Full rules (23 MUST + 14 AVOID)**: `references/essential-rules.md`", "**Full tool reference**: `references/tool-playbook.md` (60 tools)"). This makes the progressive disclosure boundary transparent — the reader always knows where to find the complete content.
