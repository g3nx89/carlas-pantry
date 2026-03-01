---
name: feature-refinement
description: "Transform rough product drafts into finalized PRDs through iterative Q&A. Use when user asks to 'refine requirements', 'generate a PRD', 'create product requirements', 'iterate on PRD', or 'requirements Q&A'."
version: 3.1.0
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(find:*)", "Bash(grep:*)", "Bash(rm:*)", "Bash(mv:*)", "Bash(mkdir:*)", "Task", "mcp__pal__consensus", "mcp__pal__thinkdeep", "mcp__sequential-thinking__sequentialthinking", "mcp__tavily__tavily_search", "mcp__Ref__ref_search_documentation", "mcp__Ref__ref_read_url"]
---

# Requirements Refinement Skill -- Lean Orchestrator

Guided PRD generation through iterative clarification with offline file-based Q&A.

**This workflow is resumable and resilient.** Progress is preserved in state files. User decisions are never lost.

---

## Critical Rules (High Attention Zone -- Start)

### Core Workflow Rules
1. **State Preservation**: Checkpoint after user decisions via state file update
2. **Resume Compliance**: Never re-ask questions from `user_decisions` -- they are immutable
3. **Delegation Pattern**: Complex analysis uses MPA agents + PAL + Sequential Thinking
4. **PRD Unique**: Only one PRD.md exists -- extend if present, do not recreate
5. **User Choice**: Ask user for analysis mode preference (Complete/Advanced/Standard/Rapid)
6. **File-Based Q&A**: Questions are written to files for offline user response
7. **Lock Protocol**: Acquire lock at start, release at completion
8. **Config Reference**: All limits and thresholds from `@$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml`
9. **No Technical Content**: PRD must not contain APIs, architecture, implementation details
10. **Git Guidance**: Suggest commits at each checkpoint for traceability

### Mandatory Requirements
11. **PRD EXTEND Mode**: If PRD.md exists, analyze and extend -- never recreate from scratch
12. **Research Discovery Optional**: At 2 moments (pre-first round via Stage 2, pre-subsequent rounds via Stage 4 `loop_research`)
13. **No Question Limits**: Continue iterations until PRD is complete, not until a counter reaches max
14. **grok-4 for Variety**: PAL Consensus and ThinkDeep include `x-ai/grok-4` for additional variety

### PAL/Model Failure Rules
15. **PAL Consensus Minimum**: Consensus requires minimum 2 model perspectives. If < 2 available after failures, FAIL and notify user
16. **No Model Substitution**: If a ThinkDeep model fails, do not substitute. Continue with remaining models
17. **User Notification**: When any PAL model fails, notify user

### Graceful Degradation
18. **MCP Availability Check**: Before using PAL/Sequential Thinking/Research MCP, check if tools are available
19. **Fallback Behavior**: If PAL unavailable, limit modes to Standard/Rapid only
20. **If Sequential Thinking unavailable**: Use internal reasoning instead
21. **If Research MCP unavailable**: Fall back to manual research flow in Stage 2

### Orchestrator Delegation Rules
22. **Coordinator delegation boundary**: Stages 2-6 coordinators never interact with users directly -- set `status: needs-user-input` in summary; orchestrator mediates all prompts via AskUserQuestion. Stage 1 runs inline and uses AskUserQuestion directly.
23. **Stage 1 runs inline** -- all other stages are coordinator-delegated. Panel Builder is dispatched as a subagent from Stage 1 (not a coordinator).
24. **Iteration loop owned by orchestrator** -- coordinators report `flags.next_action`, orchestrator decides control flow
25. **Reflexion on RED loops**: When Stage 5 validation is RED and loops back to Stage 3, orchestrator generates REFLECTION_CONTEXT from Stage 4+5 summaries and passes it to the Stage 3 coordinator
26. **Variable defaults**: Every coordinator dispatch variable has a defined fallback -- never pass null or empty for required variables (see `orchestrator-loop.md` -> Variable Defaults)
27. **Quality gates**: Orchestrator performs quality checks after Stage 3 and Stage 5 -- see `references/quality-gates.md`

---

## Configuration Reference

**Load configuration from:** `@$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml`

| Setting | Path | Default |
|---------|------|---------|
| Max rounds | `limits.max_rounds` | 10 |
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

Consider user input before proceeding. Mandatory when non-empty.

---

## Analysis Modes

| Mode | Panel | ThinkDeep (P x M x S calls) | ST | Consensus | MCP Required |
|------|-------|------------------------------|-----|-----------|--------------|
| Complete | Configured (2-5 members) | 3 x 3 x 3 = 27 | Yes | Yes | Yes |
| Advanced | Configured (2-5 members) | 2 x 3 x 3 = 18 | No | No | Yes |
| Standard | Configured (2-5 members) | 0 | No | No | No |
| Rapid | Single agent (product-strategist) | 0 | No | No | No |

Panel composition is set in Stage 1 via the Panel Builder and persisted in `requirements/.panel-config.local.md`.

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

## Stage 1 -- Inline Execution

Execute Stage 1 directly (no coordinator dispatch). Read and follow:
`@$CLAUDE_PLUGIN_ROOT/skills/refinement/references/stage-1-setup.md`

Write summary to: `requirements/.stage-summaries/stage-1-summary.md`

---

## Summary Contract

All coordinator summaries use YAML frontmatter at `requirements/.stage-summaries/stage-{N}-summary.md`.

Full schema, examples, and Interactive Pause Schema: `references/summary-contract.md`

---

## State Management

**State file:** `requirements/.requirements-state.local.md` (schema version 2, YAML frontmatter)
**Lock file:** `requirements/.requirements-lock`

Key fields: `current_stage` (1-6), `current_round`, `analysis_mode`, `prd_mode`, `mcp_availability`, `waiting_for_user`. User decisions under `user_decisions` are immutable. Full schema initialized from template at `$CLAUDE_PLUGIN_ROOT/templates/.requirements-state-template.local.md`.

---

## Agent References

| Agent | Stage | Purpose |
|-------|-------|---------|
| `requirements-panel-builder` | 1 | Analyze draft and compose MPA panel |
| `requirements-panel-member` (template) | 3 | Parametric template -- dispatched once per panel member |
| `requirements-question-synthesis` | 3 | Merge N panel outputs into QUESTIONS file |
| `requirements-prd-generator` | 5 | Generate/extend PRD |
| `research-discovery-business` | 2 | Strategic research questions |
| `research-discovery-ux` | 2 | UX research questions |
| `research-discovery-technical` | 2 | Viability research |
| `research-question-synthesis` | 2 | Synthesize research agenda |

> **Model assignments** are configured in `config/requirements-config.yaml` under `panel.builder.model`, `panel.member_model`, `panel.synthesis.model`, and `prd.model`. Agent frontmatter also specifies the model.

> **Dynamic Panel:** Panel members are not hardcoded agents. The `requirements-panel-member.md` template is dispatched via `Task(general-purpose)` with variables injected from the panel config (`requirements/.panel-config.local.md`). Available perspectives are defined in `config/requirements-config.yaml` -> `panel.available_perspectives`.

---

## Output Artifacts

| Artifact | Stage | Description |
|----------|-------|-------------|
| `requirements/.panel-config.local.md` | 1 | Panel composition (persisted across rounds) |
| `requirements/PRD.md` | 5 | Product Requirements Document |
| `requirements/decision-log.md` | 5 | Decision traceability |
| `requirements/completion-report.md` | 6 | Final summary with metrics |
| `requirements/working/QUESTIONS-{NNN}.md` | 3 | Question files per round |
| `requirements/analysis/questions-{member-id}.md` | 3 | Per-panel-member question output |
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
| `references/panel-builder-protocol.md` | Domain detection, presets, panel validation | Stage 1 panel composition |
| `references/consensus-call-pattern.md` | Shared PAL Consensus call workflow | Stages 4 and 5 consensus |
| `references/research-mcp-reference.md` | Research MCP tool selection, query patterns, cost management | Dispatching Stage 2 with research MCP available |
| `references/summary-contract.md` | Summary YAML schema, interactive pause protocol | Coordinator dispatch and summary writing |
| `references/quality-gates.md` | Structural validation, quality checks, rounds-digest | After Stage 3 and Stage 5 |
| `references/thinkdeep-templates.md` | PROBLEM_CONTEXT, step content, findings templates | Stage 3 Part A ThinkDeep execution |
| `references/artifact-schemas.md` | Canonical formats for runtime artifacts | Structural validation, artifact writing |
| `references/README.md` | Reference file index, sizes, cross-references | Skill maintenance and onboarding |

> **Note:** No `examples/` directory exists. All working files (`QUESTIONS-*.md`, `PRD.md`, summaries) are generated at runtime in the user's `requirements/` directory.

---

## Critical Rules (High Attention Zone -- End)

Rules 1-27 above apply. Key reminders:
- Stages 2-6 coordinators never interact with users directly; Stage 1 runs inline and uses AskUserQuestion directly
- Orchestrator owns the iteration loop
- State file user_decisions are immutable
- No artificial question limits -- generate all needed for complete PRD
- RED validation loops must include REFLECTION_CONTEXT for Stage 3
- Quality gates after Stage 3 and Stage 5 -- non-blocking but user-notified
