---
name: feature-refinement
description: Transform rough product drafts into finalized PRDs through iterative Q&A
version: 2.1.0
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(find:*)", "Bash(grep:*)", "Bash(rm:*)", "Bash(mv:*)", "Bash(mkdir:*)", "Task", "mcp__pal__consensus", "mcp__pal__thinkdeep", "mcp__sequential-thinking__sequentialthinking", "mcp__tavily__tavily_search", "mcp__Ref__ref_search_documentation", "mcp__Ref__ref_read_url"]
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
18. **MCP Availability Check**: Before using PAL/Sequential Thinking/Research MCP, check if tools are available
19. **Fallback Behavior**: If PAL unavailable, limit modes to Standard/Rapid only
20. **If Sequential Thinking unavailable**: Use internal reasoning instead
21. **If Research MCP unavailable**: Fall back to manual research flow in Stage 2

### Orchestrator Delegation Rules
22. **Coordinators NEVER interact with users directly** — set `status: needs-user-input` in summary; orchestrator mediates ALL prompts via AskUserQuestion
23. **Stage 1 runs inline** — all other stages are coordinator-delegated
24. **Iteration loop owned by orchestrator** — coordinators report `flags.next_action`, orchestrator decides control flow
25. **Reflexion on RED loops**: When Stage 5 validation is RED and loops back to Stage 3, orchestrator MUST generate REFLECTION_CONTEXT from Stage 4+5 summaries and pass it to the Stage 3 coordinator
26. **Variable defaults**: Every coordinator dispatch variable has a defined fallback — never pass null or empty for required variables (see `orchestrator-loop.md` -> Variable Defaults)
27. **Quality gates**: Orchestrator performs lightweight quality checks after Stage 3 (question coverage) and Stage 5 (PRD completeness) — non-blocking, notify user of issues

---

## Configuration Reference

**Load configuration from:** `@$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml`

| Setting | Path | Default |
|---------|------|---------|
| Max rounds | `limits.max_rounds` | 100 |
| Max questions total | `limits.max_questions_total` | **No limit** |
| Min completion rate | `scoring.completion.required` | **100%** |
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
  questions_count: {N}           # Stage 3 only
  thinkdeep_calls: {N}           # Stage 3 only (0 if skipped)
  thinkdeep_completion_pct: {N}  # Stage 3 only (actual/expected %)
  block_reason: null | "{reason}"
  pause_type: null | "exit_cli" | "interactive"
  next_action: null | "loop_questions" | "loop_research" | "proceed"
---

## Context for Next Stage
{What the next coordinator needs to know}
```

### Example (filled Stage 3 summary)

```yaml
---
stage: "analysis-questions"
stage_number: 3
status: completed
checkpoint: ANALYSIS_QUESTIONS
artifacts_written:
  - requirements/analysis/thinkdeep-insights.md
  - requirements/analysis/questions-product-strategy.md
  - requirements/analysis/questions-user-experience.md
  - requirements/analysis/questions-business-ops.md
  - requirements/working/QUESTIONS-001.md
summary: "Generated 14 questions across 3 perspectives with ThinkDeep insights from 27 calls"
flags:
  round_number: 1
  questions_count: 14
  analysis_mode: "complete"
  thinkdeep_calls: 27
  thinkdeep_completion_pct: 100
---

## Context for Next Stage
Round 1 generated 14 questions covering all 10 PRD sections. ThinkDeep convergent
insight: all 3 models flagged revenue model uncertainty as CRITICAL priority.
3 CRITICAL questions, 5 HIGH, 6 MEDIUM. User must fill QUESTIONS-001.md.
```

### Interactive Pause Schema

When coordinators need user input, they encode the question in `flags` for the orchestrator to relay via `AskUserQuestion`:

```yaml
flags:
  pause_type: "interactive" | "exit_cli"
  block_reason: "{human-readable reason for pause}"
  question_context:           # Present when pause_type = interactive
    question: "{question text}"
    header: "{short label, max 12 chars}"
    options:
      - label: "{option label}"
        description: "{option description}"
  next_action_map:            # Optional — maps option labels to next_action values
    "{option label}": "loop_questions" | "loop_research" | "proceed"
```

- `exit_cli`: orchestrator updates state, displays `block_reason`, and TERMINATES (user works offline)
- `interactive`: orchestrator reads `question_context`, calls `AskUserQuestion`, then re-dispatches the stage or maps the answer via `next_action_map`

---

## State Management

**State file:** `requirements/.requirements-state.local.md`
**Schema version:** 2
**Lock file:** `requirements/.requirements-lock`

State uses YAML frontmatter. User decisions under `user_decisions` are IMMUTABLE.

**Top-level fields:**
- `schema_version`: 2
- `current_stage`: 1-6
- `current_round`: N
- `waiting_for_user`: true/false
- `pause_stage`: N (set when `waiting_for_user: true`)
- `analysis_mode`: complete/advanced/standard/rapid
- `prd_mode`: NEW/EXTEND
- `mcp_availability`: `{pal_available: bool, st_available: bool, research_mcp: {tavily: bool, ref: bool}}`
- `user_decisions`: immutable decision log (keys like `analysis_mode_round_1`, `research_decision_round_1`)
- `model_failures`: array of `{model, stage, operation, error, timestamp, action_taken}`

**Nested structures (written by coordinators):**

```yaml
rounds:
  - round_number: 1
    analysis_mode: "complete"
    questions_file: "working/QUESTIONS-001.md"
    questions_count: 14
    generated_at: "{timestamp}"
    stage_3_completed: true
    stage_4_completed: true

phases:
  research:
    status: completed
    reports_analyzed: 3
    consensus_findings: 5
    research_gaps: 2
    st_used: true
  response_analysis:
    status: completed
    round: 1
    completion_rate: 100
    gaps_found: 3
  validation:
    status: completed
    mode: "pal_consensus"
    score: 17
    decision: "READY"
  prd_generation:
    status: completed
    prd_mode: "NEW"
    sections_generated: 10
    sections_extended: 0
```

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
| `references/orchestrator-loop.md` | Dispatch loop, variable defaults, quality gates, reflexion, iteration | Start of orchestration |
| `references/recovery-migration.md` | Crash recovery procedures, v1→v2 state migration | On crash or v1 state detected |
| `references/stage-1-setup.md` | Inline setup instructions | Stage 1 execution |
| `references/stage-2-research.md` | Research coordinator instructions | Dispatching Stage 2 |
| `references/stage-3-analysis-questions.md` | Analysis + question generation | Dispatching Stage 3 |
| `references/stage-4-response-analysis.md` | Response parsing + gaps | Dispatching Stage 4 |
| `references/stage-5-validation-generation.md` | Validation + PRD generation | Dispatching Stage 5 |
| `references/stage-6-completion.md` | Completion instructions | Dispatching Stage 6 |
| `references/checkpoint-protocol.md` | State update patterns | Any checkpoint |
| `references/error-handling.md` | Error recovery, degradation | Any error condition |
| `references/config-reference.md` | PAL parameter reference, scoring thresholds | PAL tool usage |
| `references/option-generation-reference.md` | Question/option format | Stage 3 question gen |
| `references/consensus-call-pattern.md` | Shared PAL Consensus call workflow | Stages 4 and 5 consensus |
| `references/research-mcp-reference.md` | Research MCP tool selection, query patterns, cost management | Dispatching Stage 2 with research MCP available |

---

## CRITICAL RULES (High Attention Zone — End)

Rules 1-27 above MUST be followed. Key reminders:
- Coordinators NEVER talk to users directly
- Orchestrator owns the iteration loop
- Stage 1 is inline, all others are coordinator-delegated
- State file user_decisions are IMMUTABLE
- No artificial question limits — generate ALL needed for complete PRD
- RED validation loops MUST include REFLECTION_CONTEXT for Stage 3
- Quality gates after Stage 3 and Stage 5 — non-blocking but user-notified
