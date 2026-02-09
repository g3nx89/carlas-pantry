---
name: refinement
description: Transform rough product drafts into finalized PRDs through iterative Q&A
version: 1.0.0
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(find:*)", "Bash(grep:*)", "Bash(rm:*)", "Bash(mv:*)", "Bash(mkdir:*)", "Task", "mcp__pal__consensus", "mcp__pal__thinkdeep", "mcp__sequential-thinking__sequentialthinking"]
---

# Requirements Refinement Skill — Lean Orchestrator

Guided PRD generation through iterative clarification with offline file-based Q&A.

**This workflow is resumable and resilient.** Progress is preserved in state files. User decisions are NEVER lost.

---

## CRITICAL RULES (High Attention Zone — Start)

### Core Workflow Rules
1. **State Preservation**: ALWAYS checkpoint after user decisions via state file update
2. **Resume Compliance**: NEVER re-ask questions from `user_decisions` — they are IMMUTABLE
3. **Delegation Pattern**: Complex analysis uses MPA agents + PAL + Sequential Thinking
4. **PRD Unique**: Only ONE PRD.md exists — extend if present, don't recreate
5. **User Choice**: ALWAYS ask user for analysis mode preference (Complete/Advanced/Standard/Rapid)
6. **File-Based Q&A**: Questions are written to files for offline user response
7. **Lock Protocol**: Always acquire lock at start, release at completion
8. **Config Reference**: All limits and thresholds from `@$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml`
9. **No Technical Content**: PRD must NOT contain APIs, architecture, implementation details
10. **Git Guidance**: Suggest commits at each checkpoint for traceability

### Mandatory Requirements
11. **PRD EXTEND Mode**: If PRD.md exists, analyze and extend — NEVER recreate from scratch
12. **Research Discovery Optional**: At 2 moments (pre-first round via Stage 2, pre-subsequent rounds via Stage 4 `loop_research`)
13. **No Question Limits**: Continue iterations until PRD is complete, not until a counter reaches max
14. **grok-4 for Variety**: PAL Consensus and ThinkDeep include `x-ai/grok-4` for additional variety

### PAL/Model Failure Rules
15. **PAL Consensus Minimum**: Consensus requires **minimum 2 model perspectives** before synthesis is meaningful. If < 2 models available after failures, FAIL and notify user
16. **No Model Substitution**: If a ThinkDeep model fails, DO NOT substitute. Continue with remaining models
17. **User Notification MANDATORY**: When ANY PAL model fails, ALWAYS notify user

### Graceful Degradation
18. **MCP Availability Check**: Before using PAL/Sequential Thinking, check if tools are available
19. **Fallback Behavior**: If PAL unavailable, limit modes to Standard/Rapid only
20. **If Sequential Thinking unavailable**: Use internal reasoning instead

### Orchestrator Delegation Rules
21. **Coordinators NEVER interact with users directly** — set `status: needs-user-input` in summary; orchestrator mediates ALL prompts via AskUserQuestion
22. **Stage 1 runs inline** — all other stages are coordinator-delegated
23. **Iteration loop owned by orchestrator** — coordinators report `flags.next_action`, orchestrator decides control flow

---

## Configuration Reference

**Load configuration from:** `@$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml`

| Setting | Path | Default |
|---------|------|---------|
| Max rounds | `limits.max_rounds` | 100 |
| Max questions total | `limits.max_questions_total` | **No limit** |
| Min completion rate | `limits.min_completion_rate` | **100%** |
| PRD readiness GREEN | `scoring.prd_readiness.ready` | See config |
| PRD readiness YELLOW | `scoring.prd_readiness.conditional` | See config |
| Research discovery | `research_discovery.enabled` | true |

---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

---

## Analysis Modes

| Mode | MPA | ThinkDeep | ST | Consensus | MCP Required |
|------|-----|-----------|----|-----------|--------------|
| Complete | 3 agents | 27 calls (3×3×3) | Yes | Yes | Yes |
| Advanced | 3 agents | 18 calls (2×3×3) | No | No | Yes |
| Standard | 3 agents | 0 | No | No | No |
| Rapid | 1 agent | 0 | No | No | No |

---

## Workflow Stages

```
+-------------------------------------------------------------------+
|  Stage 1 (Inline): SETUP                                         |
|  Init, workspace, MCP check, lock, mode selection                |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 2 (Coordinator): RESEARCH [optional]                      |
|  Research agenda, user pause for offline research, synthesis      |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 3 (Coordinator): ANALYSIS & QUESTIONS  <--+               |
|  ThinkDeep (if mode), MPA agents, synthesis      |               |
+-------------------------------+------------------+               |
                                |                  |               |
+-------------------------------v-----------+      |               |
|  Stage 4 (Coordinator): RESPONSE & GAPS  |      |               |
|  Collect answers, gap analysis, decide    |      |               |
+------+----------+----------+-------------+      |               |
       |          |          |                     |               |
 loop_questions   |    loop_research         (from Stage 4)        |
       +----------+-----+                         |               |
                        |                          |               |
                  proceed                          |               |
+-------------------------------v-----------------------------------+
|  Stage 5 (Coordinator): VALIDATION & PRD GEN                     |
|  PAL readiness, PRD generation, decision log                     |
|  If RED: loop back to Stage 3  ---------------->-+               |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 6 (Coordinator): COMPLETION                               |
|  Release lock, completion report, next steps                     |
+-------------------------------------------------------------------+
```

---

## Stage Dispatch Table

| Stage | Name | Delegation | Reference File | Checkpoint | User Pause? |
|-------|------|------------|---------------|------------|-------------|
| 1 | Setup | **Inline** | `references/stage-1-setup.md` | SETUP | No |
| 2 | Research | Coordinator | `references/stage-2-research.md` | RESEARCH | Yes (exit_cli) |
| 3 | Analysis & Questions | Coordinator | `references/stage-3-analysis-questions.md` | ANALYSIS_QUESTIONS | No |
| 4 | Response & Gaps | Coordinator | `references/stage-4-response-analysis.md` | RESPONSE_ANALYSIS | Yes (exit_cli) |
| 5 | Validation & PRD | Coordinator | `references/stage-5-validation-generation.md` | VALIDATION_PRD | No |
| 6 | Completion | Coordinator | `references/stage-6-completion.md` | COMPLETE | No |

---

## Orchestrator Loop

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/refinement/references/orchestrator-loop.md`

The orchestrator manages dispatch, iteration, user pauses, crash recovery, and state migration.

---

## Stage 1 — Inline Execution

Execute Stage 1 directly (no coordinator dispatch). Read and follow:
`@$CLAUDE_PLUGIN_ROOT/skills/refinement/references/stage-1-setup.md`

Write summary to: `requirements/.stage-summaries/stage-1-summary.md`

---

## Summary Contract

All coordinator summaries follow this convention:

**Path:** `requirements/.stage-summaries/stage-{N}-summary.md`

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
  round_number: {N}
  analysis_mode: "{mode}"
  block_reason: null | "{reason}"
  pause_type: null | "exit_cli" | "interactive"
  next_action: null | "loop_questions" | "loop_research" | "proceed"
---

## Context for Next Stage
{What the next coordinator needs to know}
```

---

## State Management

**State file:** `requirements/.requirements-state.local.md`
**Schema version:** 2
**Lock file:** `requirements/.requirements-lock`

State uses YAML frontmatter. User decisions under `user_decisions` are IMMUTABLE.

**Key fields:**
- `schema_version`: 2
- `current_stage`: 1-6
- `current_round`: N
- `waiting_for_user`: true/false
- `analysis_mode`: complete/advanced/standard/rapid
- `prd_mode`: NEW/EXTEND
- `user_decisions`: immutable decision log

---

## Agent References

| Agent | Stage | Purpose | Model |
|-------|-------|---------|-------|
| `requirements-product-strategy` | 3 | Product strategy questions | sonnet |
| `requirements-user-experience` | 3 | UX and persona questions | sonnet |
| `requirements-business-ops` | 3 | Business viability questions | sonnet |
| `requirements-question-synthesis` | 3 | Merge and format questions | opus |
| `requirements-prd-generator` | 5 | Generate/extend PRD | opus |
| `research-discovery-business` | 2 | Strategic research questions | sonnet |
| `research-discovery-ux` | 2 | UX research questions | sonnet |
| `research-discovery-technical` | 2 | Viability research | sonnet |
| `research-question-synthesis` | 2 | Synthesize research agenda | opus |

---

## Output Artifacts

| Artifact | Stage | Description |
|----------|-------|-------------|
| `requirements/PRD.md` | 5 | Product Requirements Document |
| `requirements/decision-log.md` | 5 | Decision traceability |
| `requirements/completion-report.md` | 6 | Final summary with metrics |
| `requirements/working/QUESTIONS-{NNN}.md` | 3 | Question files per round |
| `requirements/analysis/thinkdeep-insights.md` | 3 | ThinkDeep synthesis |
| `requirements/analysis/response-validation-round-{N}.md` | 4 | Consensus validation results |
| `requirements/research/RESEARCH-AGENDA.md` | 2 | Research questions |
| `requirements/research/research-synthesis.md` | 2 | Research findings |

---

## Reference Map

| Reference | Purpose | Load When |
|-----------|---------|-----------|
| `references/orchestrator-loop.md` | Dispatch loop, iteration, recovery | Start of orchestration |
| `references/stage-1-setup.md` | Inline setup instructions | Stage 1 execution |
| `references/stage-2-research.md` | Research coordinator instructions | Dispatching Stage 2 |
| `references/stage-3-analysis-questions.md` | Analysis + question generation | Dispatching Stage 3 |
| `references/stage-4-response-analysis.md` | Response parsing + gaps | Dispatching Stage 4 |
| `references/stage-5-validation-generation.md` | Validation + PRD generation | Dispatching Stage 5 |
| `references/stage-6-completion.md` | Completion instructions | Dispatching Stage 6 |
| `references/checkpoint-protocol.md` | State update patterns | Any checkpoint |
| `references/error-handling.md` | Error recovery, degradation | Any error condition |
| `references/config-reference.md` | Template vars, PAL patterns | PAL tool usage |
| `references/option-generation-reference.md` | Question/option format | Stage 3 question gen |

---

## CRITICAL RULES (High Attention Zone — End)

Rules 1-23 above MUST be followed. Key reminders:
- Coordinators NEVER talk to users directly
- Orchestrator owns the iteration loop
- Stage 1 is inline, all others are coordinator-delegated
- State file user_decisions are IMMUTABLE
- No artificial question limits — generate ALL needed for complete PRD
