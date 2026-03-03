---
lens: "Structure & Progressive Disclosure"
lens_id: "structure"
skill_reference: "plugin-dev:skill-development"
target: "feature-specify"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/specify"
fallback_used: false
findings_count: 8
critical_count: 0
high_count: 2
medium_count: 3
low_count: 2
info_count: 1
---

# Structure & Progressive Disclosure Analysis: feature-specify

## Summary

The feature-specify skill demonstrates strong structural discipline with a well-organized `references/` directory containing 17 files that successfully offload procedural detail from the main SKILL.md. The SKILL.md body is exactly ~1,998 words -- landing precisely within the recommended 1,500-2,000 word target. The Reference Map table, Stage Dispatch Table, and references/README.md provide thorough cross-referencing and discoverability. However, the frontmatter description lacks trigger phrases entirely, there is one instance of second-person voice in the SKILL.md body, and the dispatch template in `orchestrator-loop.md` necessarily uses "You" to address coordinators. The skill has no `examples/` or `scripts/` directories, though these are not strictly required for an orchestrator-pattern skill.

---

## Findings

### 1. Frontmatter description lacks third-person voice and trigger phrases

**Severity:** HIGH
**Category:** Frontmatter quality
**File:** `SKILL.md`

**Current state:**
```yaml
description: Create or update feature specifications through guided analysis with Figma integration, CLI multi-stance validation, and V-Model test strategy
```

This description uses imperative voice ("Create or update"), has no third-person framing ("This skill should be used when..."), and includes zero trigger phrases that a user would actually say.

**Recommendation:** Rewrite the description to follow the lens specification:

```yaml
description: This skill should be used when the user asks to "create a feature spec", "specify a feature", "write a specification", "generate a PRD", "run feature-specify", or mentions needing acceptance criteria, design briefs, or test strategy for a feature. Transforms rough feature descriptions into comprehensive specifications through guided multi-stage analysis with optional Figma integration, CLI multi-stance validation, and V-Model test strategy generation.
```

This change directly controls whether Claude Code's auto-discovery matches user intent to this skill.

---

### 2. Second-person voice in SKILL.md body

**Severity:** HIGH
**Category:** Writing style
**File:** `SKILL.md`, line 91

**Current state:**
```markdown
You **MUST** consider the user input before proceeding (if not empty).
```

The lens criteria require imperative/infinitive form throughout. This is the only second-person occurrence in SKILL.md.

**Recommendation:** Rewrite to imperative form:

```markdown
**MUST** consider user input before proceeding (if not empty).
```

Or:

```markdown
Consider the user input before proceeding (if not empty). This is mandatory when input is non-empty.
```

---

### 3. Second-person voice in coordinator dispatch template

**Severity:** LOW
**Category:** Writing style
**File:** `references/orchestrator-loop.md`, lines 56, 91-97

**Current state:**
```
You are a coordinator for the Feature Specify workflow.
...
- You MUST NOT interact with users directly.
- You MUST write a summary file at ...
- You MUST update the state file after completing your work.
- You MUST run self-verification checks ...
```

These lines use "You" to address the coordinator subagent at runtime.

**Recommendation:** This is classified as LOW because dispatch templates inherently address the receiving agent and second-person is conventional in prompts sent to subagents. However, the surrounding prose in `orchestrator-loop.md` (outside the dispatch template code block) correctly uses imperative form, which is the important part. If strict consistency is desired, the template could use "The coordinator MUST..." but this is a minor stylistic choice with no functional impact.

---

### 4. No `examples/` or `scripts/` directories

**Severity:** MEDIUM
**Category:** Directory layout
**File:** Skill root directory

**Current state:**
The skill directory contains only `SKILL.md` and `references/`. There are no `examples/` or `scripts/` subdirectories.

However, scripts referenced by this skill (e.g., `scripts/dispatch-cli-agent.sh` mentioned in Rule 19) appear to live at the plugin level, not within the skill directory. The `templates/prompts/` directory also lives at the plugin level.

**Recommendation:** This is acceptable for an orchestrator-pattern skill where execution scripts and templates are shared across multiple skills at the plugin level. No structural change is needed, but SKILL.md should clarify this in the Reference Map or a brief note -- currently it references `@$CLAUDE_PLUGIN_ROOT/templates/prompts/` and `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml` without explaining that these live at plugin root, not within the skill directory. Adding a one-line note such as:

```markdown
> **Note:** Agents, templates, and config are shared at plugin root (`$CLAUDE_PLUGIN_ROOT/`), not within this skill directory.
```

This would prevent confusion for anyone inspecting the skill in isolation.

---

### 5. Configuration Reference table partially duplicates config-reference.md

**Severity:** MEDIUM
**Category:** Progressive disclosure / DRY
**File:** `SKILL.md`, lines 59-82; `references/config-reference.md`

**Current state:**
SKILL.md lines 59-82 contain a 20-row Configuration Reference table listing settings, config paths, and defaults. The `references/config-reference.md` file (7,589 bytes) contains the full configuration reference including these same values plus CLI dispatch parameters, template variables, and additional detail.

**Recommendation:** The SKILL.md table serves a valid quick-reference purpose (orchestrator needs thresholds for quality gate decisions without loading a reference file). However, this creates two sources of truth for the same values. Two options:

**(A) Keep inline table but narrow it.** Reduce to only the 5-6 values the orchestrator actively checks (coverage threshold, CLI threshold, design skip flag, RTM gate dispositions). Move the remaining rows (limits, feature flags) to config-reference.md only, with a pointer.

**(B) Replace table with a pointer.** Replace the full table with: "Load configuration reference from `references/config-reference.md`. Key orchestrator thresholds: coverage GREEN >= 85%, CLI GREEN >= 16/20."

Option A is recommended as it preserves quick access to decision-critical values while reducing duplication.

---

### 6. Summary Contract section is substantial inline content

**Severity:** MEDIUM
**Category:** Progressive disclosure
**File:** `SKILL.md`, lines 173-214

**Current state:**
The Summary Contract section (lines 173-214, approximately 42 lines / ~250 words) defines the full YAML schema for coordinator summaries including field descriptions, the `question_context` sub-schema, and the Pause Type Schema. This is detailed structural specification that coordinators reference, not orchestrator decision logic.

**Recommendation:** The Summary Contract is referenced by every coordinator dispatch and is a critical shared contract. However, coordinators receive it via the dispatch template context, not by reading SKILL.md directly. The orchestrator only needs to know the `status` field values for routing. Consider extracting the full schema to `references/checkpoint-protocol.md` (which already exists and covers state update patterns) or a dedicated `references/summary-contract.md`, leaving only a compact summary in SKILL.md:

```markdown
## Summary Contract

Path: `specs/{FEATURE_DIR}/.stage-summaries/stage-{N}-summary.md`

Key fields: `status` (completed | needs-user-input | failed), `checkpoint`, `artifacts_written`, `flags` (stage-specific metrics). Full schema in `references/checkpoint-protocol.md`.
```

This would reclaim ~200 words from the SKILL.md body.

---

### 7. State Management section could be leaner

**Severity:** LOW
**Category:** Progressive disclosure
**File:** `SKILL.md`, lines 217-236

**Current state:**
The State Management section (lines 217-236) lists all top-level state fields including `mcp_availability` sub-fields, `requirements_inventory` sub-fields, and `model_failures` array structure. This is implementation-level schema detail.

**Recommendation:** The orchestrator needs to know the state file path, schema version, and key fields it reads/writes (`current_stage`, `user_decisions`, `rtm_enabled`). The full field inventory could move to `references/recovery-migration.md` (which already handles state schema) or `references/checkpoint-protocol.md`. Keep in SKILL.md:

```markdown
## State Management

**State file:** `specs/{FEATURE_DIR}/.specify-state.local.md` (YAML frontmatter, schema v5)
**Lock file:** `specs/{FEATURE_DIR}/.specify.lock`
**Summaries:** `specs/{FEATURE_DIR}/.stage-summaries/`

Key fields: `schema_version`, `current_stage`, `feature_id`, `rtm_enabled`, `user_decisions` (IMMUTABLE). Full schema in `references/recovery-migration.md`.
```

---

### 8. Frontmatter includes `allowed-tools` -- non-standard field

**Severity:** INFO
**Category:** Frontmatter quality
**File:** `SKILL.md`, line 5

**Current state:**
```yaml
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(find:*)", "Bash(grep:*)", "Bash(rm:*)", "Bash(mv:*)", "Bash(mkdir:*)", "Bash(test:*)", "Bash(command:*)", "Bash(wait:*)", "Task", "mcp__sequential-thinking__sequentialthinking", "mcp__figma-desktop__get_screenshot", ...]
```

The `allowed-tools` field is not part of the standard skill frontmatter schema (`name`, `description`, `version`). This appears to be a Claude Code runtime feature for tool sandboxing.

**Recommendation:** No action required. This is a functional runtime field that Claude Code uses for permission scoping. It does not interfere with structure or progressive disclosure. Noting it here for completeness as it is not documented in the lens criteria's frontmatter specification.

---

## Strengths

### 1. Exemplary progressive disclosure architecture

The skill achieves a near-perfect hub-and-spoke model. SKILL.md at ~1,998 words serves as a lean dispatch table, while 17 reference files (totaling ~150KB) contain all procedural detail. The Reference Map table (lines 270-288) provides clear "Load When" guidance for each reference file, enabling on-demand context loading. The `references/README.md` adds a second layer of discoverability with file sizes, cross-references, and structural patterns. This is one of the best implementations of the progressive disclosure principle across the codebase.

### 2. Comprehensive and consistent reference file wiring

Every reference file listed in the Reference Map table exists on disk (verified: all 16 reference files present in `references/`). The `references/README.md` cross-reference section maps stage files to shared references, orchestrator to stage files, and internal protocol references with precise step numbers (e.g., "stage-1-setup.md loads figma-capture-protocol.md for Figma capture (Step 1.9)"). The Stage Dispatch Table (lines 144-152) provides a third cross-reference axis mapping stages to reference files, checkpoints, and user pause behavior. No orphaned or missing references were found.

### 3. Clean separation between orchestrator and coordinator concerns

SKILL.md contains only what the orchestrator needs: stage sequencing, dispatch table, critical rules, summary contract, state overview, and reference pointers. All coordinator-executed procedures (spec drafting, checklist validation, clarification protocols, design artifact generation) are fully delegated to stage reference files. This clean separation supports both progressive disclosure (coordinators load only their stage file) and crash resilience (orchestrator reconstructs state from summaries without needing stage internals).

### 4. Well-structured README.md as a reference index

The `references/README.md` file serves as a comprehensive index with four distinct sections: file usage table (when to load each file), file sizes table (with line counts and purpose), cross-references (four categories of inter-file dependencies), and structural patterns (shared conventions across stage files). This is an excellent practice that makes the 17-file reference directory navigable without reading every file.
