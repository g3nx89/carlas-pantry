---
stage: "5"
stage_name: "Feature Documentation"
checkpoint: "DOCUMENTATION"
delegation: "coordinator"
prior_summaries:
  - ".stage-summaries/stage-3-summary.md"
  - ".stage-summaries/stage-4-summary.md"
artifacts_read:
  - "tasks.md"
  - "plan.md"
  - "spec.md"
  - "contract.md"
  - "data-model.md"
artifacts_written:
  - "docs/"
  - "README.md files"
  - ".implementation-state.local.md"
agents:
  - "product-implementation:developer"
  - "product-implementation:tech-writer"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/agent-prompts.md"
  - "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml"
  - ".stage-summaries/stage-1-summary.md (for detected_domains)"
---

# Stage 5: Feature Documentation

> **COORDINATOR STAGE:** This stage is dispatched by the orchestrator via `Task()`.
> Read the prior stage summaries to understand validation and review results.

## 5.1 Implementation Verification

Before documenting, verify that the implementation is complete enough to document.

### Verification Steps

1. Read `tasks.md` and check task completion status:
   - Count tasks marked `[X]` vs total tasks
   - Identify any incomplete or partially implemented tasks
   - Review codebase for any missing or incomplete functionality referenced in tasks

2. **If all tasks are complete**: Proceed to Section 5.2 (Documentation Update)

3. **If incomplete tasks exist**: Set `status: needs-user-input` in the stage summary with the incomplete task list as `block_reason`.

   The orchestrator will present options to the user:
   1. **Fix now** — Launch `developer` agent to address incomplete tasks before documenting
   2. **Document as-is** — Proceed with documentation noting incomplete areas
   3. **Stop here** — Halt and return to implementation

### On "Fix Now" (from user-input file)

1. Read `{FEATURE_DIR}/.stage-summaries/stage-5-user-input.md`
2. Launch `developer` agent with the incomplete task fix prompt from `agent-prompts.md` (Section: Incomplete Task Fix Prompt)
3. After fixes, re-verify task completion
4. If still incomplete, rewrite summary with `status: needs-user-input` again (loop until resolved or user proceeds)
5. Set `user_decisions.documentation_verification: "fixed"` in state file

### On "Document As-Is"

1. Set `user_decisions.documentation_verification: "accepted_incomplete"` in state file
2. Note incomplete tasks for the tech-writer agent to document as known limitations
3. Proceed to Section 5.2

## 5.1a Skill Reference Resolution for Documentation

Before dispatching the tech-writer, resolve documentation-oriented skill references.

### Procedure

1. Read `detected_domains` from the Stage 1 summary YAML frontmatter
2. Read `dev_skills` section from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`
3. If `dev_skills.enabled` is `false`, set `skill_references` to fallback text and skip to Section 5.2

4. **Resolve documentation skills:**
   - Start with `dev_skills.documentation_skills.always` (e.g., `mermaid-diagrams`)
   - For each entry in `dev_skills.documentation_skills.conditional`, check if ANY of its `domains` appear in `detected_domains` — if matched, add its skills
   - Deduplicate and cap at `max_skills_per_dispatch`

5. **Format `skill_references`** as:

```markdown
The following dev-skills provide diagram and documentation patterns. Use Mermaid.js syntax
for inline diagrams. Read skill SKILL.md on-demand for syntax reference and best practices.

{for each skill:}
- **{skill_name}**: `$PLUGINS_DIR/{plugin_path}/skills/{skill_name}/SKILL.md` — {purpose}
```

**Fallback:** `"No documentation skills available — produce prose documentation without diagrams."`

## 5.2 Documentation Update

Launch `tech-writer` agent to create and update project documentation based on the implementation.

### Agent Dispatch

```
Task(subagent_type="product-implementation:tech-writer")
```

Use the documentation prompt template from `agent-prompts.md` (Section: Documentation Update Prompt). Prefill `{skill_references}` with the value resolved in Section 5.1a.

### Documentation Scope

The tech-writer agent should:

1. **Load context** from FEATURE_DIR (the tech-writer agent operates in a separate context and must load these files independently):
   - Read spec.md for feature requirements
   - Read plan.md for architecture and file structure
   - Read tasks.md for what was implemented
   - Read contract.md for API specifications
   - Read data-model.md for entity definitions

2. **Review implementation**:
   - Identify all files modified during implementation (from tasks.md file paths)
   - Review what was built and how it works
   - Note any implementation challenges and solutions

3. **Update project documentation**:
   - Document feature in `docs/` folder (API guides, usage examples, architecture updates)
   - Add or update README.md files in folders affected by implementation
   - Include development specifics and module summaries for LLM navigation

4. **Ensure documentation completeness**:
   - Cover all implemented features with usage examples
   - Document API changes or additions
   - Include troubleshooting guidance for common issues
   - Maintain proper Markdown formatting

## 5.3 Documentation Summary

After the tech-writer agent completes, capture the summary:

```text
## Documentation Update Summary

Feature: {FEATURE_NAME}

### Files Updated
- {file1} — {brief description of changes}
- {file2} — {brief description of changes}

### Major Changes
- {change 1}
- {change 2}

### New Documentation Added
- {doc 1}
- {doc 2}

### Status
Documentation complete / Documentation complete with noted gaps
```

## 5.4 State Update and Lock Release

After documentation completes:

1. Update state file:
   - Set `current_stage: 5`
   - Store `user_decisions.documentation_outcome: "completed"`
   - Update `last_checkpoint`
   - Append to Implementation Log: "Stage 5: Documentation — completed"

2. Release lock:
   - Set `lock.acquired: false`

## 5.5 Write Stage 5 Summary

Write summary to `{FEATURE_DIR}/.stage-summaries/stage-5-summary.md`:

```yaml
---
stage: "5"
stage_name: "Feature Documentation"
checkpoint: "DOCUMENTATION"
status: "completed"
artifacts_written:
  - "docs/"
  - "README.md files"
  - ".implementation-state.local.md"
summary: |
  Documentation {completed / completed with gaps}.
  {N} files updated, {M} new documents created.
  Lock released.
flags:
  block_reason: null
  documentation_outcome: "completed"
---
## Context for Next Stage

Implementation complete. No further stages.

## Documentation Files

- {file1} — {description}
- {file2} — {description}

## Final Implementation Summary

Feature: {FEATURE_NAME}
Tasks: {completed}/{total}
Phases: {completed}/{total}
Tests: All passing
Quality Review: {outcome}
Documentation: {status}
Lock: Released
```
