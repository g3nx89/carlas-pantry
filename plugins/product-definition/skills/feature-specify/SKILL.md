---
name: feature-specify
description: Create or update feature specifications through guided analysis with Figma integration, PAL validation, and V-Model test strategy
version: 1.0.0
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(find:*)", "Bash(grep:*)", "Bash(rm:*)", "Bash(mv:*)", "Bash(mkdir:*)", "Bash(test:*)", "Task", "mcp__pal__consensus", "mcp__pal__thinkdeep", "mcp__sequential-thinking__sequentialthinking", "mcp__figma-desktop__get_screenshot", "mcp__figma-desktop__get_design_context", "mcp__figma-desktop__get_metadata", "mcp__figma__get_screenshot", "mcp__figma__get_design_context", "mcp__figma__get_metadata"]
---

# Feature Specify Skill — Lean Orchestrator

Guided feature specification with codebase understanding, Figma integration, PAL consensus validation, and V-Model test strategy generation.

**This workflow is resumable and resilient.** Progress is preserved in state files. User decisions are NEVER lost.

---

## CRITICAL RULES (High Attention Zone — Start)

### Core Workflow Rules
1. **State Preservation**: ALWAYS checkpoint after user decisions via state file update
2. **Resume Compliance**: NEVER re-ask questions from `user_decisions` — they are IMMUTABLE
3. **Delegation Pattern**: Complex analysis → specialized agents (`business-analyst`, `design-brief-generator`, `gap-analyzer`, `qa-strategist`)
4. **Progressive Disclosure**: Load templates ONLY when stage reached (reference via `@$CLAUDE_PLUGIN_ROOT/templates/prompts/`)
5. **Batching Limit**: AskUserQuestion MAX 4 questions per call — clarification protocol handles batching
6. **BA Recommendation**: First option MUST be "(Recommended)" with rationale
7. **Lock Protocol**: Always acquire lock at start, release at completion
8. **Config Reference**: All limits and thresholds from `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml`
9. **Structured Responses**: Agents return responses per `@$CLAUDE_PLUGIN_ROOT/templates/agent-response-schema.md`
10. **Unified Checkpoints**: State file ONLY — no HTML comment checkpoints

### Mandatory Requirements
11. **Design Brief MANDATORY**: `design-brief.md` MUST be generated for EVERY specification. NEVER skip.
12. **Design Feedback MANDATORY**: `design-feedback.md` MUST be generated for EVERY specification. NEVER skip.
13. **No Question Limits**: There is NO maximum on clarification questions — ask EVERYTHING needed for complete spec.
14. **No Story Limits**: There is NO maximum on user stories, acceptance criteria, or NFRs — capture ALL requirements.
15. **No Iteration Limits**: Continue clarification loops until COMPLETE, not until a counter reaches max.

### PAL/Model Failure Rules
16. **PAL Consensus Minimum**: Consensus requires **minimum 2 models**. If < 2 models available → **FAIL** and notify user.
17. **No Model Substitution**: If a ThinkDeep model fails, **DO NOT** substitute with another model. ThinkDeep is for variety — substituting defeats the purpose.
18. **User Notification MANDATORY**: When ANY PAL model fails or is unavailable, **ALWAYS** notify user.

### Graceful Degradation
19. **MCP Availability Check**: Before using PAL/Sequential Thinking/Figma MCP, check if tools are available
20. **Fallback Behavior**: If PAL unavailable, skip ThinkDeep and Consensus steps — proceed with internal reasoning
21. **grok-4 for Variety**: PAL Consensus and ThinkDeep include `x-ai/grok-4` for additional variety. Continue gracefully if unavailable.

### Orchestrator Delegation Rules
22. **Coordinators NEVER interact with users directly** — set `status: needs-user-input` in summary; orchestrator mediates ALL prompts via AskUserQuestion
23. **Stage 1 runs inline** — all other stages are coordinator-delegated
24. **Iteration loop owned by orchestrator** — Stage 3 <-> Stage 4 until coverage >= 85% or user forces proceed
25. **Variable defaults**: Every coordinator dispatch variable has a defined fallback — never pass null or empty (see `orchestrator-loop.md` → Variable Defaults)
26. **Quality gates**: Orchestrator performs lightweight quality checks after Stages 2, 4, and 5 — non-blocking, notify user of issues

---

## Configuration Reference

**Load configuration from:** `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml`

| Setting | Path | Default |
|---------|------|---------|
| Clarification questions | `limits.max_clarification_questions` | **null** (no limit) |
| User stories | `limits.max_user_stories` | **null** (no limit) |
| NFRs | `limits.max_nfrs` | **null** (no limit) |
| PAL rejection retries max | `limits.pal_rejection_retries_max` | 2 |
| Checklist GREEN threshold | `thresholds.checklist.green` | 85% |
| Checklist YELLOW threshold | `thresholds.checklist.yellow` | 60% |
| PAL GREEN threshold | `thresholds.pal.green` | 16/20 |
| PAL YELLOW threshold | `thresholds.pal.yellow` | 12/20 |
| Incremental gates enabled | `feature_flags.enable_incremental_gates` | true |
| Test strategy enabled | `feature_flags.enable_test_strategy` | true |
| Design brief skip allowed | `design_artifacts.skip_allowed` | **false** |

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
|  Stage 1 (Inline): SETUP & FIGMA                                  |
|  Init, workspace, MCP check, lock, Figma capture (optional)       |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 2 (Coordinator): SPEC DRAFT & GATES                        |
|  BA agent, MPA-Challenge ThinkDeep, incremental gates              |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 3 (Coordinator): CHECKLIST & VALIDATION   <──+             |
|  Platform detect, checklist copy, BA validate        |             |
+-------------------------------+----------------------+             |
                                |                      |             |
+-------------------------------v-----------------------------------+
|  Stage 4 (Coordinator): EDGE CASES & CLARIFICATION  |             |
|  MPA-EdgeCases ThinkDeep, clarification protocol,    |             |
|  MPA-Triangulation, spec update                      |             |
+-------------------------------+----------------------+             |
                                |              (loop if coverage     |
                          proceed               < 85%)               |
+-------------------------------v-----------------------------------+
|  Stage 5 (Coordinator): PAL VALIDATION & DESIGN                   |
|  PAL Consensus, design-brief, design-feedback (MANDATORY)          |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 6 (Coordinator): TEST STRATEGY [optional]                   |
|  V-Model test plan, AC->Test traceability                          |
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
| 5 | PAL Validation & Design | Coordinator | `references/stage-5-pal-design.md` | PAL_GATE | Yes (if PAL REJECTED) | PAL optional; design MANDATORY |
| 6 | Test Strategy | Coordinator | `references/stage-6-test-strategy.md` | TEST_STRATEGY | Yes (if coverage gaps) | Yes (feature flag) |
| 7 | Completion | Coordinator | `references/stage-7-completion.md` | COMPLETE | No | No |

---

## Orchestrator Loop

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/feature-specify/references/orchestrator-loop.md`

The orchestrator manages dispatch, iteration (Stage 3 <-> Stage 4), user pauses, crash recovery, and state migration.

---

## Stage 1 — Inline Execution

Execute Stage 1 directly (no coordinator dispatch). Read and follow:
`@$CLAUDE_PLUGIN_ROOT/skills/feature-specify/references/stage-1-setup.md`

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
  pal_score: {N}                 # Stage 5 only
  pal_decision: "{APPROVED|CONDITIONAL|REJECTED}"  # Stage 5 only
  block_reason: null | "{reason}"
  pause_type: null | "interactive"
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

### Interactive Pause Schema

- `interactive`: orchestrator reads `question_context`, calls `AskUserQuestion`, then re-dispatches the stage or maps the answer via `next_action_map`

---

## State Management

**State file:** `specs/{FEATURE_DIR}/.specify-state.local.md`
**Schema version:** 3 (stage-based)
**Lock file:** `specs/{FEATURE_DIR}/.specify.lock`
**Summaries:** `specs/{FEATURE_DIR}/.stage-summaries/`

State uses YAML frontmatter. User decisions under `user_decisions` are IMMUTABLE.

**Top-level fields:**
- `schema_version`: 3
- `current_stage`: 1-7
- `feature_id`: "{NUMBER}-{SHORT_NAME}"
- `feature_name`: "{FEATURE_NAME}"
- `mcp_availability`: `{pal_available: bool, st_available: bool, figma_mcp_available: bool}`
- `user_decisions`: immutable decision log
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
| `specs/{FEATURE_DIR}/design-feedback.md` | 5 | Design analysis (MANDATORY) |
| `specs/{FEATURE_DIR}/test-plan.md` | 6 | V-Model test strategy (optional) |
| `specs/{FEATURE_DIR}/analysis/mpa-challenge*.md` | 2 | MPA Challenge ThinkDeep report |
| `specs/{FEATURE_DIR}/analysis/mpa-edgecases*.md` | 4 | MPA Edge Cases ThinkDeep report |
| `specs/{FEATURE_DIR}/analysis/mpa-triangulation.md` | 4 | MPA Triangulation report |

---

## Reference Map

| Reference | Purpose | Load When |
|-----------|---------|-----------|
| `references/orchestrator-loop.md` | Dispatch loop, variable defaults, iteration, quality gates | Start of orchestration |
| `references/recovery-migration.md` | Crash recovery, v2→v3 state migration | On crash or v2 state detected |
| `references/stage-1-setup.md` | Inline setup: init, MCP check, workspace, Figma | Stage 1 execution |
| `references/stage-2-spec-draft.md` | Spec draft, MPA-Challenge, incremental gates | Dispatching Stage 2 |
| `references/stage-3-checklist.md` | Platform detect, checklist, BA validation | Dispatching Stage 3 |
| `references/stage-4-clarification.md` | Edge cases, clarification, triangulation | Dispatching Stage 4 |
| `references/stage-5-pal-design.md` | PAL Consensus, design-brief, design-feedback | Dispatching Stage 5 |
| `references/stage-6-test-strategy.md` | V-Model test plan, AC traceability | Dispatching Stage 6 |
| `references/stage-7-completion.md` | Lock release, completion report | Dispatching Stage 7 |
| `references/checkpoint-protocol.md` | State update patterns | Any checkpoint |
| `references/error-handling.md` | Error recovery, degradation | Any error condition |
| `references/config-reference.md` | Key config values, ThinkDeep/PAL params | PAL tool usage |
| `references/thinkdeep-patterns.md` | Parameterized ThinkDeep execution patterns | Stages 2, 4 (ThinkDeep calls) |
| `references/figma-capture-protocol.md` | Figma connection, capture, screenshot naming | Stage 1 (Figma enabled) |
| `references/clarification-protocol.md` | Batching, BA recommendations, error recovery | Stage 4 (clarification dispatch) |

---

## CRITICAL RULES (High Attention Zone — End)

Rules 1-26 above MUST be followed. Key reminders:
- Coordinators NEVER talk to users directly
- Orchestrator owns the iteration loop (Stage 3 <-> Stage 4)
- Stage 1 is inline, all others are coordinator-delegated
- State file user_decisions are IMMUTABLE
- No artificial question/story/iteration limits
- design-brief.md and design-feedback.md are MANDATORY — NEVER skip
- Quality gates after Stages 2, 4, and 5 — non-blocking but user-notified
