---
lens: "Structure & Progressive Disclosure"
lens_id: "structure"
skill_reference: "plugin-dev:skill-development"
target: "design-handoff"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff"
fallback_used: false
findings_count: 8
critical_count: 0
high_count: 2
medium_count: 3
low_count: 2
info_count: 1
---

# Structure & Progressive Disclosure Analysis: design-handoff

## Summary

The design-handoff skill demonstrates strong progressive disclosure architecture with a lean SKILL.md (1,979 words) that serves as a dispatch table, deferring all procedural detail to 9 well-organized reference files. Frontmatter quality is good with specific trigger phrases in third-person voice. The primary structural issues are: (1) SKILL.md duplicates stage procedure summaries that belong exclusively in reference files, inflating it beyond the ideal lean orchestrator pattern; and (2) several external dependencies (agents, templates, config) referenced from SKILL.md and reference files cannot be resolved from the skill directory alone, with no existence-verification guidance for the orchestrator.

## Findings

### 1. SKILL.md Stage Sections Duplicate Reference Content
- **Severity**: HIGH
- **Category**: Progressive disclosure
- **File**: `SKILL.md`
- **Current**: Each stage (Stages 1-5J) has a section in SKILL.md that includes numbered procedural steps. For example, Stage 1 (lines 133-151) lists 9 steps with descriptions, and Stage 2 (lines 155-171) includes a 3-step orchestration loop. These summaries overlap with the full procedure in the corresponding reference files (e.g., `references/setup-protocol.md` contains the same 10 steps in full detail).
- **Recommendation**: Reduce each stage section in SKILL.md to 2-3 lines: a one-sentence purpose statement, the "Read and follow" reference pointer, and a mode guard if applicable. Remove the numbered step summaries — the Stage Dispatch Table (lines 118-129) already serves as the index. This would bring SKILL.md closer to the ~300-line lean orchestrator target documented in CLAUDE.md and free approximately 100 lines of duplicated content.

### 2. External Dependencies Not Verifiable From Skill Directory
- **Severity**: HIGH
- **Category**: Reference file wiring
- **File**: `SKILL.md`, `references/README.md`
- **Current**: SKILL.md and reference files reference 4 agents (`handoff-screen-scanner.md`, `handoff-figma-preparer.md`, `handoff-gap-analyzer.md`, `handoff-judge.md`), 3 templates (`handoff-supplement-template.md`, `handoff-screen-template.md`, `handoff-manifest-template.md`), 1 additional template (`figma-screen-brief-template.md` in the Reference Map), and 1 config file (`handoff-config.yaml`) — all located outside the `skills/design-handoff/` directory at `$CLAUDE_PLUGIN_ROOT/agents/`, `$CLAUDE_PLUGIN_ROOT/templates/`, and `$CLAUDE_PLUGIN_ROOT/config/`. These files do exist in the plugin, but the `references/README.md` External Dependencies table (lines 42-52) lists them without any validation instruction. If any were deleted or renamed, the skill would fail silently at runtime.
- **Recommendation**: Add a "Pre-flight Dependency Check" step to `references/setup-protocol.md` Step 1.1 (or as a new Step 1.0) that verifies all external dependencies exist before proceeding. Alternatively, list expected file paths in `config/handoff-config.yaml` so they are auditable from one location.

### 3. Reference Map Inconsistency With README.md File Sizes
- **Severity**: MEDIUM
- **Category**: Reference file wiring
- **File**: `SKILL.md`, `references/README.md`
- **Current**: The SKILL.md Reference Map (lines 309-320) includes 10 entries (9 reference files + 1 template). The `references/README.md` File Usage Table (lines 10-20) lists line counts (e.g., `setup-protocol.md` = 264 lines, `figma-preparation.md` = 504 lines) but these are not cross-validated against actual file sizes. The README also does not list the `figma-screen-brief-template.md` that appears in the SKILL.md Reference Map, creating an inconsistency between the two file indexes.
- **Recommendation**: Add `figma-screen-brief-template.md` to the README.md External Dependencies table (it is currently missing). Consider adding actual byte sizes alongside line counts in the README for easier auditing, matching the format used in the user's task description which showed byte sizes.

### 4. No examples/ or scripts/ Directories
- **Severity**: MEDIUM
- **Category**: Directory layout
- **File**: Skill directory
- **Current**: The skill directory contains only `SKILL.md` and `references/`. There are no `examples/` or `scripts/` directories. For a complex 10-stage workflow with Figma MCP integration, sample outputs (e.g., an example `HANDOFF-SUPPLEMENT.md`, an example `handoff-manifest.md`, or an example `gap-report.md`) would help a consuming agent understand the expected output format without loading the full template files.
- **Recommendation**: Add an `examples/` directory with 1-2 trimmed example outputs showing the expected structure of `HANDOFF-SUPPLEMENT.md` and `handoff-manifest.md`. These serve as concrete format references that are more immediately useful than reading template files with unresolved variables. This is a LOW priority if the templates are sufficiently self-explanatory; classified MEDIUM because the templates live outside the skill directory and require a separate load.

### 5. SKILL.md Word Count Near Upper Bound of Recommended Range
- **Severity**: MEDIUM
- **Category**: Progressive disclosure
- **File**: `SKILL.md`
- **Current**: At 1,979 words, SKILL.md is within the recommended 1,500-2,000 word range but at its upper boundary. The lens criteria recommend targeting 1,500-2,000 words with an absolute maximum of 5,000. However, the project's own CLAUDE.md prescribes a lean orchestrator pattern of "<300 lines" for SKILL.md. The current file is 334 lines.
- **Recommendation**: Applying Finding #1 (removing duplicated stage step summaries) would reduce the file by approximately 80-100 lines, bringing it to ~240 lines and comfortably within the <300 line project convention. No further reduction needed after that change.

### 6. Second-Person Voice in Reference File Agent Prompt Templates
- **Severity**: LOW
- **Category**: Writing style
- **File**: `references/figma-preparation.md`, `references/judge-protocol.md`
- **Current**: Several reference files contain second-person "You" in agent prompt templates (e.g., `figma-preparation.md` line 76: "You are a coordinator for Design Handoff, Stage 2" and `judge-protocol.md` line 29: "You are evaluating the quality of Stage {STAGE_NAME} output"). These appear inside agent dispatch prompt blocks, not in the instructional prose.
- **Recommendation**: This is an ambiguous case. The lens criteria say to use imperative/infinitive form and avoid second person. However, agent prompt templates are a special case — they are prompts sent TO an agent, where second-person is the conventional addressing form. Classify as deliberate choice. No change recommended unless the project adopts a strict "no second person even in prompts" policy.

### 7. Reference Map Missing "Load When" Specificity for Shared Files
- **Severity**: LOW
- **Category**: Progressive disclosure
- **File**: `SKILL.md`
- **Current**: The Reference Map entry for `references/judge-protocol.md` says `Load When: "Every judge checkpoint"` (line 317). This is correct but less specific than other entries. Since the judge is dispatched at 4 distinct checkpoints (2J, 3J, 3.5J, 5J), each with different rubric subsections, the "Load When" guidance does not indicate whether the entire file should be loaded or only the relevant rubric section.
- **Recommendation**: Update the "Load When" column for `judge-protocol.md` to: "Every judge checkpoint (2J/3J/3.5J/5J) — load full file, agent selects checkpoint-specific rubric by `checkpoint_id`". This clarifies that the file is a shared resource with internal routing, not a monolithic read.

### 8. `figma-screen-brief-template.md` Listed in Reference Map But Not in references/
- **Severity**: INFO
- **Category**: Reference file wiring
- **File**: `SKILL.md`
- **Current**: The Reference Map (line 320) includes `templates/figma-screen-brief-template.md` with purpose "Template for FSB files generated in Stage 3 for missing screens." This file lives at `$CLAUDE_PLUGIN_ROOT/templates/figma-screen-brief-template.md`, outside the skill's `references/` directory. Including it in the Reference Map is a positive practice — it makes the dependency visible to the orchestrator.
- **Recommendation**: No change needed. This is a correct documentation practice. Noted for completeness because the file is the only non-`references/` entry in the Reference Map, and the distinction is worth preserving.

## Strengths

1. **Exemplary lean orchestrator pattern** — SKILL.md functions as a dispatch table with the Stage Dispatch Table (lines 118-129) providing a single-glance view of all 10 stages, their delegation type, reference file, and user-pause requirements. The ASCII workflow diagram (lines 60-112) adds a visual overview without requiring any reference file load. This is a textbook implementation of the hub-spoke model prescribed in CLAUDE.md.

2. **Well-structured references/README.md** — The README.md provides three cross-referencing tables (File Usage, Cross-References, External Dependencies) plus a compact stage flow diagram. This makes it possible to understand the full dependency graph without loading any individual reference file. The cross-references table (lines 28-37) is particularly valuable for understanding which reference files depend on each other.

3. **Consistent frontmatter across reference files** — Each reference file includes YAML frontmatter with `stage`, `description`, `agents_dispatched`, `artifacts_written`, and `config_keys_used`. This structured metadata enables crash recovery (the orchestrator can reconstruct state from frontmatter alone) and makes each file self-documenting. The pattern is applied uniformly across all 8 stage reference files.

4. **Strong frontmatter description with specific trigger phrases** — The SKILL.md description (lines 3-12) uses correct third-person voice ("This skill should be used when the user asks to...") and includes 6 specific trigger phrases ("prepare Figma for handoff", "handoff designs to developers", "prepare designs for coding agents", "run design handoff", "create handoff supplement", "handoff"). It also describes the output artifacts, which helps Claude determine relevance at the metadata-loading stage.

5. **CRITICAL RULES bookend pattern** — Rules appear at both the top (lines 31-42) and bottom (lines 324-334) of SKILL.md, ensuring they remain in the model's attention window regardless of context position. This is a proven pattern from the plugin's other skills and is correctly applied here with 8 numbered rules at the start and a summary reprise at the end.
