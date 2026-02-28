---
name: feature-specify
description: Create or update feature specifications through guided analysis with Figma integration, CLI multi-stance validation, and V-Model test strategy
version: 1.2.0
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(find:*)", "Bash(grep:*)", "Bash(rm:*)", "Bash(mv:*)", "Bash(mkdir:*)", "Bash(test:*)", "Bash(command:*)", "Bash(wait:*)", "Task", "mcp__sequential-thinking__sequentialthinking", "mcp__figma-desktop__get_screenshot", "mcp__figma-desktop__get_design_context", "mcp__figma-desktop__get_metadata", "mcp__figma__get_screenshot", "mcp__figma__get_design_context", "mcp__figma__get_metadata"]
---

# Feature Specify Skill — Lean Orchestrator

Guided feature specification with codebase understanding, Figma integration, CLI multi-stance validation (Codex/Gemini/OpenCode), and V-Model test strategy generation.

**This workflow is resumable and resilient.** Progress is preserved in state files. User decisions are NEVER lost.

---

## CRITICAL RULES (High Attention Zone — Start)

### Core Workflow Rules
1. **State Preservation**: ALWAYS checkpoint after user decisions via state file update
2. **Resume Compliance**: NEVER re-ask questions from `user_decisions` — they are IMMUTABLE
3. **Delegation Pattern**: Complex analysis → specialized agents (`business-analyst`, `design-brief-generator`, `gap-analyzer`, `qa-strategist`)
4. **Progressive Disclosure**: Load templates ONLY when stage reached (reference via `@$CLAUDE_PLUGIN_ROOT/templates/prompts/`)
5. **File-Based Clarification**: All clarification questions written to `clarification-questions.md` for offline editing — NO AskUserQuestion for clarification batches
6. **BA Recommendation**: First option MUST be "(Recommended)" with rationale
7. **Lock Protocol**: Always acquire lock at start, release at completion
8. **Config Reference**: All limits and thresholds from `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml`
9. **Structured Responses**: Agents return responses per `@$CLAUDE_PLUGIN_ROOT/templates/agent-response-schema.md`
10. **Unified Checkpoints**: State file ONLY — no HTML comment checkpoints

### Mandatory Requirements
11. **Design Brief MANDATORY**: `design-brief.md` MUST be generated for EVERY specification. NEVER skip.
12. **Design Supplement MANDATORY**: `design-supplement.md` MUST be generated for EVERY specification. NEVER skip.
13. **No Question Limits**: There is NO maximum on clarification questions — ask EVERYTHING needed for complete spec.
14. **No Story Limits**: There is NO maximum on user stories, acceptance criteria, or NFRs — capture ALL requirements.
15. **No Iteration Limits**: Continue clarification loops until COMPLETE, not until a counter reaches max.

### CLI Dispatch Rules
16. **CLI Evaluation Minimum**: Evaluation requires **minimum 2 substantive responses**. If < 2 → signal `needs-user-input` (NEVER self-assess).
17. **No CLI Substitution**: If a CLI dispatch fails, **DO NOT** substitute with another CLI. Tri-CLI dispatch is for variety — substituting defeats the purpose.
17b. **Spec Content Inline**: NEVER pass local file paths to CLI dispatch prompt files. Embed spec content inline. External CLIs cannot read local files.
18. **User Notification MANDATORY**: When ANY CLI fails or is unavailable, **ALWAYS** notify user.

### Graceful Degradation
19. **CLI Availability Check**: Before dispatching CLI, check if `scripts/dispatch-cli-agent.sh` is executable and at least one CLI binary is in PATH
20. **Fallback Behavior**: If CLI unavailable, skip Challenge, EdgeCases, Triangulation, and Evaluation steps — proceed with internal reasoning
21. **OpenCode for Variety**: CLI dispatch includes OpenCode (Grok) for contrarian perspective. Continue gracefully if unavailable.

### Orchestrator Delegation Rules
22. **Coordinators NEVER interact with users directly** — set `status: needs-user-input` in summary; orchestrator mediates ALL prompts via AskUserQuestion
23. **Stage 1 runs inline** — all other stages are coordinator-delegated
24. **Iteration loop owned by orchestrator** — Stage 3 <-> Stage 4 until coverage >= 85% or user forces proceed
25. **Variable defaults**: Every coordinator dispatch variable has a defined fallback — never pass null or empty (see `orchestrator-loop.md` → Variable Defaults)
26. **Quality gates**: Orchestrator performs lightweight quality checks after Stages 2, 4, and 5 — non-blocking, notify user of issues
27. **Summary size limits**: Coordinator summaries max 500 chars (YAML `summary` field), 1000 chars (Context for Next Stage body). Detailed analysis in artifact files, not summaries.
28. **RTM Disposition Gate**: Zero UNMAPPED requirements before proceeding past Stage 4. Every source requirement must have a conscious disposition (COVERED, PARTIAL, DEFERRED, or REMOVED).

---

## Configuration Reference

**Load configuration from:** `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml`

| Setting | Path | Default |
|---------|------|---------|
| Clarification questions | `limits.max_clarification_questions` | **null** (no limit) |
| Clarification mode | `clarification.mode` | `file_based` |
| Auto-resolve enabled | `clarification.auto_resolve.enabled` | `true` |
| User stories | `limits.max_user_stories` | **null** (no limit) |
| NFRs | `limits.max_nfrs` | **null** (no limit) |
| CLI rejection retries max | `limits.pal_rejection_retries_max` | 2 |
| Checklist GREEN threshold | `thresholds.checklist.green` | 85% |
| Checklist YELLOW threshold | `thresholds.checklist.yellow` | 60% |
| CLI eval GREEN threshold | `thresholds.pal.green` | 16/20 |
| CLI eval YELLOW threshold | `thresholds.pal.yellow` | 12/20 |
| Incremental gates enabled | `feature_flags.enable_incremental_gates` | true |
| Test strategy enabled | `feature_flags.enable_test_strategy` | true |
| Design brief skip allowed | `design_artifacts.skip_allowed` | **false** |
| RTM tracking enabled | `feature_flags.enable_rtm_tracking` | true |
| RTM inventory template | `rtm.inventory_extraction.template` | `requirements-inventory-template.md` |
| RTM output file | `rtm.output.rtm_file` | `rtm.md` |
| RTM gate-blocking dispositions | `rtm.dispositions.gate_blocking` | `[UNMAPPED, PENDING_STORY]` |

---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

---

## Workflow Stages

```
+-------------------------------------------------------------------+
|  Stage 1 (Inline): SETUP & FIGMA + RTM INVENTORY                  |
|  Init, workspace, MCP check, lock, Figma capture (optional),      |
|  requirements inventory extraction (optional, RTM)                 |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 2 (Coordinator): SPEC DRAFT & GATES + INITIAL RTM          |
|  BA agent, MPA-Challenge CLI dispatch, incremental gates,          |
|  initial rtm.md generation (if RTM enabled)                        |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 3 (Coordinator): CHECKLIST & VALIDATION   <──+             |
|  Platform detect, checklist copy, BA validate,       |             |
|  RTM coverage re-evaluation (if RTM enabled)         |             |
+-------------------------------+----------------------+             |
                                |                      |             |
+-------------------------------v-----------------------------------+
|  Stage 4 (Coordinator): EDGE CASES & CLARIFICATION  |             |
|  RTM disposition gate (zero UNMAPPED), MPA-EdgeCases |             |
|  CLI dispatch, clarification protocol,               |             |
|  MPA-Triangulation CLI dispatch, spec update         |             |
+-------------------------------+----------------------+             |
                                |              (loop if coverage     |
                          proceed               < 85%)               |
+-------------------------------v-----------------------------------+
|  Stage 5 (Coordinator): CLI VALIDATION & DESIGN                   |
|  CLI multi-stance eval, design-brief, design-supplement (MANDATORY)|
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 6 (Coordinator): TESTABILITY & RISK ASSESSMENT [optional]   |
|  Risk analysis, testability verification, test level guidance      |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 7 (Coordinator): COMPLETION                                 |
|  Lock release, completion report, next steps                       |
+-------------------------------------------------------------------+
```

---

## Stage Dispatch Table

| Stage | Name | Delegation | Reference File | Checkpoint | User Pause? | Optional |
|-------|------|------------|---------------|------------|-------------|----------|
| 1 | Setup & Figma | **Inline** | `references/stage-1-setup.md` | INIT | No (interactive) | No (Figma optional within) |
| 2 | Spec Draft & Gates | Coordinator | `references/stage-2-spec-draft.md` | SPEC_DRAFT | Yes (if gate RED/YELLOW) | No |
| 3 | Checklist & Validation | Coordinator | `references/stage-3-checklist.md` | CHECKLIST_VALIDATION | No | No |
| 4 | Edge Cases & Clarification | Coordinator | `references/stage-4-clarification.md` | CLARIFICATION | Yes (clarification Q&A) | Edge cases optional |
| 5 | CLI Validation & Design | Coordinator | `references/stage-5-validation-design.md` | CLI_GATE | Yes (if eval REJECTED) | CLI optional; design MANDATORY |
| 6 | Testability & Risk Assessment | Coordinator | `references/stage-6-test-strategy.md` | TEST_STRATEGY | Yes (if testability gaps) | Yes (feature flag) |
| 7 | Completion | Coordinator | `references/stage-7-completion.md` | COMPLETE | No | No |

---

## Orchestrator Loop

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/specify/references/orchestrator-loop.md`

The orchestrator manages dispatch, iteration (Stage 3 <-> Stage 4), user pauses, crash recovery, and state migration.

---

## Stage 1 — Inline Execution

Execute Stage 1 directly (no coordinator dispatch). Read and follow:
`@$CLAUDE_PLUGIN_ROOT/skills/specify/references/stage-1-setup.md`

Write summary to: `specs/{FEATURE_DIR}/.stage-summaries/stage-1-summary.md`

---

## Summary Contract

All coordinator summaries follow this convention:

**Path:** `specs/{FEATURE_DIR}/.stage-summaries/stage-{N}-summary.md`

```yaml
---
stage: "{stage_name}"
stage_number: {N}
status: completed | needs-user-input | failed
checkpoint: "{CHECKPOINT_NAME}"
artifacts_written:
  - "{path/to/artifact}"
summary: "{1-2 sentence description of what happened}"
flags:
  coverage_pct: {N}              # Stage 3 only
  gaps_count: {N}                # Stage 3 only
  cli_score: {N}                 # Stage 5 only
  cli_decision: "{APPROVED|CONDITIONAL|REJECTED}"  # Stage 5 only
  block_reason: null | "{reason}"
  pause_type: null | "interactive" | "file_based"
  next_action: null | "loop_checklist" | "proceed"
  question_context:              # Present when pause_type = interactive
    question: "{question text}"
    header: "{short label, max 12 chars}"
    options:
      - label: "{option label}"
        description: "{option description}"
  next_action_map:               # Optional — maps option labels to next_action values
    "{option label}": "loop_checklist" | "proceed"
---

## Context for Next Stage
{What the next coordinator needs to know}
```

### Pause Type Schema

- `interactive`: orchestrator reads `question_context`, calls `AskUserQuestion`, then re-dispatches the stage or maps the answer via `next_action_map`
- `file_based`: orchestrator notifies user that a clarification file has been written, waits for user to re-invoke after editing, then re-dispatches stage with `re_entry_after_user_input`

---

## State Management

**State file:** `specs/{FEATURE_DIR}/.specify-state.local.md`
**Schema version:** 5 (stage-based, file-based clarification, RTM tracking)
**Lock file:** `specs/{FEATURE_DIR}/.specify.lock`
**Summaries:** `specs/{FEATURE_DIR}/.stage-summaries/`

State uses YAML frontmatter. User decisions under `user_decisions` are IMMUTABLE.

**Top-level fields:**
- `schema_version`: 5
- `current_stage`: 1-7
- `feature_id`: "{NUMBER}-{SHORT_NAME}"
- `feature_name`: "{FEATURE_NAME}"
- `rtm_enabled`: `true | false | null` (null = not yet decided)
- `requirements_inventory`: `{file_path, count, confirmed}`
- `mcp_availability`: `{cli_available: bool, codex_available: bool, gemini_available: bool, opencode_available: bool, st_available: bool, figma_mcp_available: bool}`
- `user_decisions`: immutable decision log (includes `rtm_enabled`, `rtm_dispositions[]`)
- `model_failures`: array of `{model, stage, operation, error, timestamp, action_taken}`

---

## Agent References

| Agent | Stage | Purpose | Model |
|-------|-------|---------|-------|
| `business-analyst` | 2, 3, 4 | Spec draft, validation, clarification updates | sonnet |
| `design-brief-generator` | 5 | Screen and state inventory | sonnet |
| `gap-analyzer` | 5 | Design analysis and recommendations | sonnet |
| `qa-strategist` | 6 | V-Model test strategy generation | sonnet |
| `gate-judge` | 2 | Incremental quality gate evaluation | sonnet |

## Output Artifacts

| Artifact | Stage | Description |
|----------|-------|-------------|
| `specs/{FEATURE_DIR}/spec.md` | 2 | Feature specification |
| `specs/{FEATURE_DIR}/spec-checklist.md` | 3 | Annotated checklist |
| `specs/{FEATURE_DIR}/design-brief.md` | 5 | Screen and state inventory (MANDATORY) |
| `specs/{FEATURE_DIR}/clarification-questions.md` | 4 | Clarification questions for offline editing |
| `specs/{FEATURE_DIR}/clarification-report.md` | 4 | Auto-resolve audit trail and answer summary |
| `specs/{FEATURE_DIR}/design-supplement.md` | 5 | Design analysis (MANDATORY) |
| `specs/{FEATURE_DIR}/test-strategy.md` | 6 | V-Model test strategy (optional) |
| `specs/{FEATURE_DIR}/REQUIREMENTS-INVENTORY.md` | 1 | Source requirements with REQ-NNN IDs (conditional, RTM enabled) |
| `specs/{FEATURE_DIR}/rtm.md` | 2 | Forward traceability matrix REQ→US/AC (conditional, RTM enabled) |
| `specs/{FEATURE_DIR}/analysis/mpa-challenge*.md` | 2 | MPA Challenge CLI dispatch report |
| `specs/{FEATURE_DIR}/analysis/mpa-edgecases*.md` | 4 | MPA Edge Cases CLI dispatch report |
| `specs/{FEATURE_DIR}/analysis/mpa-triangulation.md` | 4 | MPA Triangulation report |

---

## Reference Map

| Reference | Purpose | Load When |
|-----------|---------|-----------|
| `references/orchestrator-loop.md` | Dispatch loop, variable defaults, iteration, quality gates | Start of orchestration |
| `references/recovery-migration.md` | Crash recovery, v2→v3→v4→v5 state migration | On crash or older state detected |
| `references/stage-1-setup.md` | Inline setup: init, MCP check, workspace, Figma | Stage 1 execution |
| `references/stage-2-spec-draft.md` | Spec draft, MPA-Challenge, incremental gates | Dispatching Stage 2 |
| `references/stage-3-checklist.md` | Platform detect, checklist, BA validation | Dispatching Stage 3 |
| `references/stage-4-clarification.md` | Edge cases, clarification, triangulation | Dispatching Stage 4 |
| `references/stage-5-validation-design.md` | CLI multi-stance eval, design-brief, design-supplement | Dispatching Stage 5 |
| `references/stage-6-test-strategy.md` | Risk analysis, testability verification, test level guidance | Dispatching Stage 6 |
| `references/stage-7-completion.md` | Lock release, completion report | Dispatching Stage 7 |
| `references/checkpoint-protocol.md` | State update patterns | Any checkpoint |
| `references/error-handling.md` | Error recovery, degradation | Any error condition |
| `references/config-reference.md` | Key config values, CLI dispatch params | CLI tool usage |
| `references/cli-dispatch-patterns.md` | Parameterized CLI dispatch execution patterns | Stages 2, 4, 5 (CLI dispatch calls) |
| `references/figma-capture-protocol.md` | Figma connection, capture, screenshot naming | Stage 1 (Figma enabled) |
| `references/clarification-protocol.md` | File-based Q&A, BA recommendations, answer parsing | Stage 4 (clarification dispatch) |
| `references/auto-resolve-protocol.md` | Auto-resolve gate, classification, citation rules | Stage 4 (pre-question-file generation) |

---

## CRITICAL RULES (High Attention Zone — End)

Rules 1-28 above MUST be followed. Key reminders:
- Coordinators NEVER talk to users directly
- Orchestrator owns the iteration loop (Stage 3 <-> Stage 4)
- Stage 1 is inline, all others are coordinator-delegated
- State file user_decisions are IMMUTABLE
- No artificial question/story/iteration limits
- design-brief.md and design-supplement.md are MANDATORY — NEVER skip
- Quality gates after Stages 2, 4, and 5 — non-blocking but user-notified
- CLI dispatch replaces PAL MCP — `CLI_AVAILABLE` replaces `PAL_AVAILABLE` everywhere
