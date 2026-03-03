---
lens: "Structure & Progressive Disclosure"
lens_id: "structure"
skill_reference: "plugin-dev:skill-development"
target: "feature-planning"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-planning/skills/plan"
fallback_used: false
findings_count: 8
critical_count: 0
high_count: 2
medium_count: 4
low_count: 1
info_count: 1
---

# Structure & Progressive Disclosure Analysis: feature-planning

## Summary

The feature-planning skill demonstrates strong progressive disclosure architecture, with a lean SKILL.md (2,082 words, 292 lines) that delegates detailed procedural content to 29 reference files totaling ~38,871 words. The most significant structural issue is that the `examples/` directory (containing `state-file.md` and `thinkdeep-output.md`) is never referenced from SKILL.md, making those resources invisible to the consuming agent. Additionally, the SKILL.md body slightly exceeds the recommended 2,000-word threshold and includes a detailed CLI Multi-CLI Dispatch paragraph that belongs in a reference file.

## Findings

### 1. Examples Directory Not Referenced in SKILL.md
- **Severity**: HIGH
- **Category**: Reference file wiring
- **File**: `SKILL.md`
- **Current**: SKILL.md contains an "Additional Resources" section (lines 224-265) that lists per-phase instruction files, orchestrator support, existing references, sequential thinking reference, configuration, and templates. The `examples/` directory is never mentioned anywhere in SKILL.md despite containing two files: `examples/state-file.md` and `examples/thinkdeep-output.md`.
- **Recommendation**: Add an "### Example Files" subsection under "Additional Resources" that references both example files with descriptions of what they demonstrate. For example: `- **examples/state-file.md** — Sample `.planning-state.local.md` for resume testing` and `- **examples/thinkdeep-output.md** — Sample CLI deep analysis output for Phase 5 reference`. This ensures the consuming agent knows these resources exist and can load them on demand.

### 2. SKILL.md Exceeds Recommended Word Count with Inline Detail
- **Severity**: HIGH
- **Category**: Progressive disclosure
- **File**: `SKILL.md`
- **Current**: SKILL.md is 2,082 words. The recommended target is 1,500-2,000 words. Line 67 contains a dense 80+ word paragraph explaining CLI Multi-CLI Dispatch details (binary names, synthesis confidence levels, latency estimates) that is operational detail rather than orchestrator-level dispatch information. Similarly, the "Multi-Agent Collaboration Flags" block (lines 151-157) lists six flags with descriptions that duplicate content from `config/planning-config.yaml`.
- **Recommendation**: Extract the CLI Multi-CLI Dispatch paragraph (line 67) into either the existing `references/cli-dispatch-pattern.md` or a brief summary, keeping only a one-line mention in SKILL.md (e.g., "See `references/cli-dispatch-pattern.md` for CLI multi-CLI dispatch details including synthesis confidence levels."). Move the Multi-Agent Collaboration Flags list to `references/orchestrator-loop.md` where the flags are already contextually relevant, and replace with a single line pointing to that file. This would reduce SKILL.md by approximately 150-200 words, bringing it comfortably under the 2,000-word target.

### 3. Examples Directory Located Under Skill but Listed Under References in Task Input
- **Severity**: MEDIUM
- **Category**: Directory layout
- **File**: `examples/`
- **Current**: The `examples/` directory exists at `skills/plan/examples/` containing `state-file.md` and `thinkdeep-output.md`. However, the file listing provided in the review task input lists these as `examples/thinkdeep-output.md` and `examples/state-file.md` alongside reference files, suggesting they may have been originally intended as reference content. Both files appear to be reference material (a sample state file and sample CLI output) rather than runnable examples.
- **Recommendation**: Evaluate whether these files are true "examples" (complete, runnable, demonstrating skill usage) or "reference" material (documentation for understanding formats). If they are format references for coordinators to understand expected file shapes, consider moving them to `references/` with names like `references/example-state-file.md` and `references/example-thinkdeep-output.md`. If they are kept in `examples/`, ensure they are complete enough to serve as standalone examples per the skill-development lens criteria.

### 4. Scripts Directory Not Under Skill Directory
- **Severity**: MEDIUM
- **Category**: Directory layout
- **File**: `SKILL.md` (line 67)
- **Current**: SKILL.md references `scripts/dispatch-cli-agent.sh` on line 67. The actual scripts directory is at the plugin root level (`plugins/product-planning/scripts/`) containing `cleanup-orphans.sh`, `dispatch-cli-agent.sh`, `planning-hint.sh`, and `test-cli-dispatch.sh`. The skill directory itself has no `scripts/` subdirectory.
- **Recommendation**: This is an acceptable deviation from the standard skill layout since the scripts are shared across the plugin (not skill-specific). However, the SKILL.md reference to `scripts/dispatch-cli-agent.sh` is ambiguous -- it could be interpreted as relative to the skill directory or to `$CLAUDE_PLUGIN_ROOT`. Add an explicit `$CLAUDE_PLUGIN_ROOT/` prefix to the scripts reference on line 67 for consistency with how other plugin-root resources are referenced (e.g., `$CLAUDE_PLUGIN_ROOT/config/planning-config.yaml` on line 49).

### 5. Additional Resources Section Lacks Organizational Hierarchy
- **Severity**: MEDIUM
- **Category**: Progressive disclosure
- **File**: `SKILL.md` (lines 224-265)
- **Current**: The "Additional Resources" section lists 22 reference files across 5 subsections (Per-Phase Instruction Files, Orchestrator Support, Existing References, Sequential Thinking Reference, Configuration, Templates). The "Existing References" subsection alone contains 16 bullet points, making it difficult for the consuming agent to quickly identify which reference is relevant for a given task.
- **Recommendation**: Add a brief categorization within the "Existing References" subsection, grouping references by function: (1) Agent Patterns: self-critique, cot-prefix, judge-gate-rubrics; (2) Architecture Strategies: adaptive-strategy-logic, tot-workflow, debate-protocol, mpa-synthesis-pattern; (3) Integration Patterns: research-mcp-patterns, cli-dispatch-pattern, skill-loader-pattern, deep-reasoning-dispatch-pattern; (4) Validation: validation-rubric, coverage-validation-rubric; (5) Methodology: v-model-methodology. Alternatively, since `references/README.md` already provides an excellent task-oriented index, add a single pointer: "For task-oriented reference selection, consult `references/README.md`."

### 6. README.md File Sizes Table Has Inconsistent Entries
- **Severity**: MEDIUM
- **Category**: Reference file wiring
- **File**: `references/README.md` (lines 94-113)
- **Current**: The File Sizes table in `references/README.md` lists most files by name but groups per-phase files as `phase-*-*.md` with a range of "70-572" lines. It also includes files outside the references directory (e.g., `$PLUGIN/templates/asset-manifest-template.md`, `$PLUGIN/templates/cli-roles/*.txt`) which, while useful, blurs the scope of the references index. The `examples/` files (`state-file.md`, `thinkdeep-output.md`) appear in the file listing but are not mentioned in the README.md reference usage table or cross-references section.
- **Recommendation**: (1) Add individual line counts for each `phase-*-*.md` file instead of using a range, since their sizes vary significantly (70 to 572 lines); this helps the consuming agent estimate context cost before loading. (2) Add a note or separate section for files outside `references/` to clarify scope. (3) Add `examples/state-file.md` and `examples/thinkdeep-output.md` to the usage table if they are intended to be discoverable resources.

### 7. Frontmatter Description Could Include More Colloquial Trigger Phrases
- **Severity**: LOW
- **Category**: Frontmatter quality
- **File**: `SKILL.md` (line 3)
- **Current**: The description includes: "plan a feature", "create an implementation plan", "design the architecture", "break down a feature into tasks", "decompose a specification", "plan development", "plan tests". These are reasonable trigger phrases but skew formal. Informal phrasings users might actually say are missing -- for example: "how should I build this", "what's the best approach for this feature", "help me think through the implementation".
- **Recommendation**: Add 2-3 colloquial trigger phrases that capture how users naturally describe planning needs. Consider: "figure out how to build this", "think through the implementation approach", or "break this spec into steps". This broadens skill triggering without bloating the description.

### 8. Frontmatter Includes Version Field
- **Severity**: INFO
- **Category**: Frontmatter quality
- **File**: `SKILL.md` (line 4)
- **Current**: The frontmatter includes `version: 3.0.0`. The skill-development lens specifies `name` and `description` as required fields but does not list `version` as required or recommended. This is a plugin-convention extension.
- **Recommendation**: No action needed. The version field is a reasonable extension for a skill of this complexity, enabling changelog tracking. It aligns with the plugin manifest pattern (`plugin.json` also has version).

## Strengths

1. **Excellent progressive disclosure architecture** -- The SKILL.md functions as a true lean orchestrator dispatch table at 292 lines, with 29 reference files containing the detailed procedural content (~38,871 words total). This achieves the recommended hub-spoke model where the SKILL.md provides metadata, critical rules, phase dispatch table, and resource pointers, while coordinators load only the specific phase file they need. The ratio of approximately 1:19 (SKILL.md words to reference words) demonstrates disciplined content offloading.

2. **Strong reference file indexing via README.md** -- The `references/README.md` provides an exemplary task-oriented index with three discovery paths: (1) a "Read When..." table mapping each file to its use case, (2) a "By Task" section with multi-step workflows for common operations (debugging gates, adding agents, working on test planning), and (3) a cross-references section showing inter-file dependencies. This three-path discovery pattern goes beyond what the skill-development lens requires and significantly improves navigation for both the consuming agent and human contributors.

3. **Consistent imperative/infinitive writing style** -- A scan of SKILL.md found zero instances of second-person pronouns ("you", "your", "you're", "you'll"). Instructions consistently use imperative form: "Read and follow", "Execute Phase 1 inline", "Ensure `{FEATURE_DIR}/spec.md` exists". This aligns perfectly with the skill-development lens requirement for objective, instructional language.

4. **Third-person frontmatter description with concrete trigger phrases** -- The description correctly uses the "This skill should be used when the user asks to..." pattern and lists 7 specific trigger phrases that map to natural user requests. The description also includes a brief capability summary ("Provides 9-phase workflow with MPA agents, CLI deep analysis, V-Model test planning, and consensus scoring") that helps differentiate this skill from adjacent ones.

5. **Explicit file path references throughout** -- SKILL.md consistently uses `$CLAUDE_PLUGIN_ROOT/` prefixed paths and `{FEATURE_DIR}` variables when pointing to resources, making file locations unambiguous. The Phase Dispatch Table (lines 129-141) provides a single-glance mapping from phase number to instruction file, prior summaries, and checkpoint name -- an effective pattern for orchestrator skills.
