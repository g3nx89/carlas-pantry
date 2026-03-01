---
name: feature-specify
description: This skill should be used when the user asks to "create a feature spec", "specify a feature", "write a specification", or "define feature requirements". Creates or updates feature specifications through guided analysis with Figma integration, CLI multi-stance validation, and V-Model test strategy.
version: 1.3.0
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(find:*)", "Bash(grep:*)", "Bash(rm:*)", "Bash(mv:*)", "Bash(mkdir:*)", "Bash(test:*)", "Bash(command:*)", "Bash(wait:*)", "Task", "mcp__sequential-thinking__sequentialthinking", "mcp__figma-desktop__get_screenshot", "mcp__figma-desktop__get_design_context", "mcp__figma-desktop__get_metadata", "mcp__figma__get_screenshot", "mcp__figma__get_design_context", "mcp__figma__get_metadata"]
---

# Feature Specify Skill — Lean Orchestrator

Guided feature specification with codebase understanding, Figma integration, CLI multi-stance validation (Codex/Gemini/OpenCode), and V-Model test strategy generation.

**This workflow is resumable and resilient.** Progress is preserved in state files. User decisions are NEVER lost.

### When NOT to Use

- **Too simple**: If the feature is a single-line bug fix or trivial tweak, skip this skill. Minimum complexity: 2+ user stories or cross-cutting concerns.
- **Missing draft**: This skill needs a feature description (even rough). If you have nothing, use `/product-definition:refine` first to build a PRD (Product Requirements Document).
- **Partial re-run**: To re-run only clarification or validation, resume the existing workflow — do not invoke a new `/specify`.
- **Prerequisites**: If Figma designs exist, run `/product-definition:design-handoff` first for best results.

---

> **Convention:** Capitalized MUST, NEVER, and ALWAYS indicate mandatory requirements per RFC 2119.

## CRITICAL RULES (High Attention Zone — Start)

### Core Workflow Rules
1. **State Preservation**: ALWAYS checkpoint after user decisions via state file update
2. **Resume Compliance**: NEVER re-ask questions from `user_decisions` — they are IMMUTABLE
3. **Delegation Pattern**: Complex analysis → specialized agents (BA = Business Analyst: `business-analyst`, `design-brief-generator`, `gap-analyzer`, `qa-strategist`)
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
14. **No Story Limits**: There is NO maximum on user stories, acceptance criteria, or NFRs (Non-Functional Requirements) — capture ALL requirements.
15. **No Iteration Limits**: Continue clarification loops until COMPLETE, not until a counter reaches max.

### CLI Dispatch Rules
16. **CLI Evaluation Minimum**: Evaluation requires **minimum 2 substantive responses**. If < 2 → signal `needs-user-input` (NEVER self-assess).
17. **No CLI Substitution**: If a CLI dispatch fails, **DO NOT** substitute with another CLI. Tri-CLI dispatch is for variety — substituting defeats the purpose.
18. **Spec Content Inline**: NEVER pass local file paths to CLI dispatch prompt files. Embed spec content inline. External CLIs cannot read local files.
19. **User Notification MANDATORY**: When ANY CLI fails or is unavailable, **ALWAYS** notify user.

### Graceful Degradation
20. **CLI Availability Check**: Before dispatching CLI, check if `scripts/dispatch-cli-agent.sh` is executable and at least one CLI binary is in PATH
21. **Fallback Behavior**: If CLI unavailable, skip Challenge, EdgeCases, Triangulation, and Evaluation steps — proceed with internal reasoning
22. **OpenCode for Variety**: CLI dispatch includes OpenCode (Grok) for contrarian perspective. Continue gracefully if unavailable.

### Orchestrator Delegation Rules
23. **Coordinators NEVER interact with users directly** — set `status: needs-user-input` in summary; orchestrator mediates ALL prompts via AskUserQuestion
24. **Stage 1 runs inline** — all other stages are coordinator-delegated
25. **Iteration loop owned by orchestrator** — Stage 3 <-> Stage 4 until coverage >= 85% or user forces proceed
26. **Variable defaults**: Every coordinator dispatch variable has a defined fallback — never pass null or empty (see `orchestrator-loop.md` → Variable Defaults)
27. **Quality gates**: Orchestrator performs lightweight quality checks after Stages 2, 4, and 5 — non-blocking, notify user of issues
28. **Summary size limits**: Coordinator summaries max 500 chars (YAML `summary` field), 1000 chars (Context for Next Stage body). Detailed analysis in artifact files, not summaries.
29. **RTM (Requirements Traceability Matrix) Disposition Gate**: Stage 4 Step 4.0a BLOCKS on UNMAPPED/PENDING_STORY requirements. Post-Stage-4 orchestrator check is NON-BLOCKING (notification only, reported in Stage 7).

---

## Configuration Reference

All limits, thresholds, and feature flags: `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml`

---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if non-empty).

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
|  BA agent, MPA (Multi-Perspective Analysis) Challenge CLI dispatch,|
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
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 8 (Coordinator): RETROSPECTIVE                              |
|  KPI report card, transcript analysis, narrative composition       |
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
| 8 | Retrospective | Coordinator | `references/stage-8-retrospective.md` | RETROSPECTIVE | No | No |

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

**Path:** `specs/{FEATURE_DIR}/.stage-summaries/stage-{N}-summary.md`

**Status enum:** `completed` | `needs-user-input` | `failed`

**Key fields:** `stage`, `stage_number`, `status`, `checkpoint`, `artifacts_written`, `summary` (max 500 chars), `flags` (stage-specific metrics + `block_reason`, `pause_type`, `next_action`).

**Full YAML schema and pause type reference:** see `orchestrator-loop.md` → Summary Contract Schema.

---

## State Management

**State file:** `specs/{FEATURE_DIR}/.specify-state.local.md`
**Schema version:** 5 (stage-based, file-based clarification, RTM tracking)
**Lock file:** `specs/{FEATURE_DIR}/.specify.lock`
**Summaries:** `specs/{FEATURE_DIR}/.stage-summaries/`

State uses YAML frontmatter. User decisions under `user_decisions` are IMMUTABLE.

**Top-level fields:**
- `schema_version`: 5
- `current_stage`: 1-8
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
| `definition-retrospective-writer` | 8 | Retrospective narrative composition | sonnet |

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
| `specs/{FEATURE_DIR}/.specify-report-card.local.md` | 8 | KPI report card |
| `specs/{FEATURE_DIR}/retrospective.md` | 8 | Retrospective narrative |

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
| `references/stage-8-retrospective.md` | Retrospective protocol, KPI definitions | Dispatching Stage 8 |

---

## CRITICAL RULES (High Attention Zone — End)

Rules 1-29 above MUST be followed. Key reminders:
- Coordinators NEVER talk to users directly
- Orchestrator owns the iteration loop (Stage 3 <-> Stage 4)
- Stage 1 is inline, all others (2-8) are coordinator-delegated
- State file user_decisions are IMMUTABLE
- No artificial question/story/iteration limits
- design-brief.md and design-supplement.md are MANDATORY — NEVER skip
- Quality gates after Stages 2, 4, and 5 — non-blocking but user-notified
- `CLI_AVAILABLE` gates all multi-model analysis steps
