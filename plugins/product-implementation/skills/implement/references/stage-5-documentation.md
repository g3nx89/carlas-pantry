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
  - "product-implementation:doc-judge"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/agent-prompts.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/cli-dispatch-procedure.md"
  - "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml"
  - ".stage-summaries/stage-1-summary.md (for detected_domains)"
---

# Stage 5: Feature Documentation

> **COORDINATOR STAGE:** This stage is dispatched by the orchestrator via `Task()`.
> Read the prior stage summaries to understand validation and review results.
> **CLI dispatch: ONLY use `dispatch-cli-agent.sh`**: For ALL CLI dispatches (doc generation), use `$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh` via Bash(). NEVER use the `ask` command or CCB async dispatch — the async queue returns stale cross-stage results.

## Phase Scope Mode

When the coordinator prompt includes a `## Phase Scope` block, this stage generates **incremental documentation** for a single phase:
- **Documentation scope**: only new/changed interfaces, components, and APIs from this phase
- **Summary path**: write to the path specified in the Phase Scope block (e.g., `phase-{N}-stage-5-summary.md`)
- **Prior summaries**: read `phase-{N}-stage-3-summary.md` and `phase-{N}-stage-4-summary.md`
- **Doc judge verification**: after tech-writer completes, dispatch `doc-judge` agent to verify accuracy (see Section 5.2b)
- **Lock release**: per-phase S5 does NOT release the lock — only the final S5 pass releases it

When NO Phase Scope is present, this is a **final documentation pass** (cross-phase synthesis):
- Generate feature overview, index, architecture diagram updates, cross-cutting concerns
- This is lighter since per-phase docs already exist — just synthesize and cross-reference
- **Lock release**: the final S5 pass releases the lock (Section 5.4)
- Summary path: `final-stage-5-summary.md` or `stage-5-summary.md`

## 5.1 Implementation Verification

Before documenting, verify that the implementation is complete enough to document.

### Verification Steps

1. Read `tasks.md` and check task completion status:
   - Count tasks marked `[X]` vs total tasks
   - Identify any incomplete or partially implemented tasks
   - Review codebase for any missing or incomplete functionality referenced in tasks

2. **If all tasks are complete**: Proceed to Section 5.2 (Documentation Update)

3. **If incomplete tasks exist**:

   **Check autonomy policy** (read `autonomy_policy` from Stage 1 summary, read policy level from config `autonomy_policy.levels.{policy}`). This uses `policy.incomplete_tasks` (not the severity-based iteration from `autonomy-policy-procedure.md`):
   - If action is `"fix"`: Auto-fix — launch `developer` agent to complete tasks, log: `"[AUTO-{policy}] Incomplete tasks — auto-fixing before documentation"`. After fix, re-verify. If still incomplete after one fix attempt, fall back to `"document_as_is"` behavior.
   - If action is `"document_as_is"`: Log: `"[AUTO-{policy}] Incomplete tasks — documenting as-is with noted gaps"`. Note incomplete tasks for tech-writer. Proceed to Section 5.2.
   - If no policy set (edge case): fall through to manual escalation below.

   **Manual escalation** (when no autonomy policy applies):
   Set `status: needs-user-input` in the stage summary with the incomplete task list as `block_reason`.

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

## 5.1b Research Context Resolution for Documentation

Build the `{research_context}` block for the tech-writer agent prompt using accumulated research URLs.

### Procedure

1. Read `mcp_availability` from the Stage 1 summary
2. Read `research_mcp` section from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`
3. If `research_mcp.enabled` is `false` OR all MCP tools are unavailable → set `research_context` to the fallback text and skip to Section 5.2

4. **Re-read accumulated URLs** (Ref — maximum Dropout benefit):
   - Read `research_urls_discovered` from the Stage 2 summary flags
   - For each URL (up to `ref.max_reads_per_stage`): call `ref_read_url(url)` — by Stage 5, Ref returns only the most documentation-relevant content from session cache
   - Cap each source at `ref.token_budgets.per_source` tokens

5. **Enrichment protocol**: Assemble `{research_context}` with documentation-specific focus:
   - **Link generation**: Official documentation URLs for inclusion in feature docs
   - **Example verification**: Code examples from official docs for cross-checking against implemented examples
   - **Migration notes**: Version migration or deprecation warnings from documentation

6. Cap at `ref.token_budgets.research_context_total` tokens.

### Context Budget

Same cap as earlier stages. Maximum Dropout benefit: Ref serves from session cache, returning only documentation-focused content relevant to the feature's libraries.

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

## 5.2b Documentation Judge Verification (Optional — Per-Phase Mode)

> **Conditional**: Only runs when ALL of:
>   1. Phase Scope is present (per-phase mode)
>   2. `doc_judge.enabled` is `true` in config
> If any condition fails, skip to Section 5.2a or 5.3.

After the tech-writer produces per-phase documentation (Section 5.2), dispatch the doc-judge agent to verify documentation accuracy against actual code.

### Procedure

1. **Collect documentation and source files**: List all doc files produced by tech-writer in Section 5.2, and the source files they describe (from the phase's modified file list).

2. **Dispatch doc-judge agent**:
   ```
   Task(subagent_type="product-implementation:doc-judge")
   ```
   Using the Documentation Verification Prompt from `agent-prompts.md`. Prefill variables:
   - `{FEATURE_DIR}`, `{FEATURE_NAME}` — from Stage 1 summary
   - `{doc_files_list}` — doc files produced in Section 5.2
   - `{source_files_list}` — source files the docs describe
   - `{phase_name}` — current phase name

3. **Process results**: Parse the structured YAML output from the doc-judge:
   - If `doc_quality: PASS` → proceed to Section 5.2a or 5.3
   - If `doc_quality: FAIL` AND `accuracy_score < doc_judge.accuracy_threshold` (default: 70):
     - Re-dispatch tech-writer with the findings (one revision cycle per `doc_judge.max_revision_cycles`)
     - Log: `"Doc judge found {N} issues (score: {accuracy_score}) — requesting revision"`
     - After revision, optionally re-run doc-judge (if revision cycles remain)
   - If revision cycles exhausted and still FAIL → log findings and proceed

### Latency

~5-15s dispatch overhead + 15-60s verification execution per phase. Revision cycle adds another tech-writer dispatch.

## 5.2a CLI Documentation Review (Optional)

> **Conditional**: Only runs when ALL of: `cli_dispatch.stage5.doc_reviewer.enabled` is `true` and `cli_availability.opencode` is `true` (from Stage 1 summary). If any condition is false, skip to Section 5.3.

After the tech-writer produces documentation (Section 5.2), dispatch OpenCode to review the output from the user's perspective: completeness, accuracy, usability, and accessibility documentation.

### Procedure

1. **Collect documentation files**: List all documentation files created or modified in Section 5.2 (from tech-writer agent output).

2. **Dispatch**: Follow the Shared CLI Dispatch Procedure (`cli-dispatch-procedure.md`) with:
   - `cli_name="opencode"`, `role="doc_reviewer"`
   - `fallback_behavior` from `cli_dispatch.stage5.doc_reviewer.fallback_behavior` (default: `"skip"`)
   - `expected_fields=["files_reviewed", "features_documented", "findings", "top_gap", "recommendation"]`

3. **Coordinator-Injected Context** (appended per `cli-dispatch-procedure.md` variable injection convention):
   - `{FEATURE_DIR}` — feature directory
   - `{PROJECT_ROOT}` — project root
   - `{doc_files}` — list of documentation files produced in Section 5.2
   - `{tasks_content}` — tasks.md content (for completeness cross-reference)
   - `{spec_content}` — spec.md content (for accuracy cross-reference, or `"Not available"`)

4. **Result processing**: Parse `<SUMMARY>` block. If documentation gaps are found:
   - `[Critical]`/`[High]` findings (wrong API signatures, missing critical feature docs): feed back to tech-writer for revision — dispatch a second tech-writer run with the findings as additional input. Log: `"OpenCode doc review found {count} critical/high gaps — requesting revision"`
   - `[Medium]`/`[Low]` findings (minor completeness gaps, formatting): log as advisory, include in summary for user awareness
   - **One revision cycle maximum** — if the second tech-writer pass still has Critical/High findings from a re-review, log them and proceed (do not loop)

5. **If CLI fails, CLI unavailable, or times out**: follow `fallback_behavior` — default `"skip"` means continue without doc review, log warning

### Latency Impact

Adds ~5-15s dispatch overhead + 30-90s agent execution. Revision cycle (if triggered) adds another tech-writer dispatch. Skipped automatically when disabled or when OpenCode is unavailable.

## 5.3 Documentation Summary

After the tech-writer agent completes (and optional OpenCode doc review in Section 5.2a), capture the summary:

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

## 5.3a Protocol Compliance Checklist

Before writing the Stage 5 summary, complete the **Stage 5** checklist in `$CLAUDE_PLUGIN_ROOT/skills/implement/references/protocol-compliance-checklist.md` (Universal Checks + Stage 5 section). Record results in `protocol_evidence`.

## 5.3b Auto-Commit Documentation

After capturing the documentation summary, optionally commit the documentation changes. Follow the Auto-Commit Dispatch Procedure in `$CLAUDE_PLUGIN_ROOT/skills/implement/references/auto-commit-dispatch.md` with:

| Parameter | Value |
|-----------|-------|
| `template_key` | `documentation` |
| `substitution_vars` | `{feature_name}` = FEATURE_NAME |
| `skip_target` | Section 5.4 |
| `summary_field` | `commit_sha` |

## 5.4 State Update and Lock Release

After documentation completes:

1. Update state file:
   - Set `current_stage: 5`
   - Store `user_decisions.documentation_outcome: "completed"`
   - Update `last_checkpoint`
   - Append to Implementation Log: "Stage 5: Documentation — completed"

2. Release lock (**final pass only** — when NO Phase Scope is present):
   - Set `lock.acquired: false`
   - Per-phase S5 dispatches do NOT release the lock — the lock is held until all phases complete and the final documentation pass runs

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
  {Lock released. | Lock held (per-phase — released in final pass).}
flags:
  block_reason: null
  documentation_outcome: "completed"
  doc_judge_result: null  # Per-phase mode: {quality: "PASS"|"FAIL", accuracy_score: N, hallucinations: N, revision_cycles: N}
  commit_sha: null  # Auto-commit SHA after documentation (null if disabled, skipped, or failed)
  context_contributions: null
---
## Context for Next Stage

Stage 6 (Implementation Retrospective) will analyze the full lifecycle — KPI compilation, session transcript analysis, and narrative retrospective.

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
