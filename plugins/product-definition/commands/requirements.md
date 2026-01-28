---
description: Generate a finalized, non-technical PRD from a user's draft through iterative Q&A with offline file-based responses.
argument-hint: |
  Draft filename (in requirements/draft/)

  Options:
    --mode=complete    Use full analysis (MPA + PAL + ST) - Recommended
    --mode=advanced    Use MPA + PAL ThinkDeep
    --mode=standard    Use MPA only
    --mode=rapid       Use single BA agent
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(find:*)", "Bash(grep:*)", "Bash(rm:*)", "Bash(mv:*)", "Bash(mkdir:*)", "Task", "mcp__pal__consensus", "mcp__pal__thinkdeep", "mcp__sequential-thinking__sequentialthinking"]
---

# Requirements Refinement (Resumable)

Guided PRD generation through iterative clarification with offline file-based Q&A.

**This workflow is resumable and resilient.** Progress is preserved in state files. User decisions are NEVER lost.

---

## CRITICAL RULES (MUST READ FIRST)

### Core Workflow Rules
1. **State Preservation**: ALWAYS checkpoint after user decisions via state file update
2. **Resume Compliance**: NEVER re-ask questions from `user_decisions` - they are IMMUTABLE
3. **Delegation Pattern**: Complex analysis uses MPA agents + PAL + Sequential Thinking
4. **PRD Unique**: Only ONE PRD.md exists - extend if present, don't recreate
5. **User Choice**: ALWAYS ask user for analysis mode preference (Complete/Advanced/Standard/Rapid)
6. **File-Based Q&A**: Questions are written to files for offline user response
7. **Lock Protocol**: Always acquire lock at start, release at completion
8. **Config Reference**: All limits and thresholds from `@$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml`
9. **No Technical Content**: PRD must NOT contain APIs, architecture, implementation details
10. **Git Guidance**: Suggest commits at each checkpoint for traceability

### MANDATORY REQUIREMENTS
11. **PRD EXTEND Mode**: If PRD.md exists, analyze and extend - NEVER recreate from scratch
12. **Research Discovery Optional**: At 3 moments (pre-first round, pre-subsequent rounds, post-completion)
13. **No Question Limits**: Continue iterations until PRD is complete, not until a counter reaches max
14. **grok-4 for Variety**: PAL Consensus and ThinkDeep include `x-ai/grok-4` for additional variety

### PAL/MODEL FAILURE RULES
15. **PAL Consensus Minimum**: Consensus requires **minimum 2 models**. If < 2 available FAIL and notify user
16. **No Model Substitution**: If a ThinkDeep model fails, DO NOT substitute. Continue with remaining models
17. **User Notification MANDATORY**: When ANY PAL model fails, ALWAYS notify user (see [error-handling.md](requirements/error-handling.md))

### GRACEFUL DEGRADATION (Plugin Mode)
18. **MCP Availability Check**: Before using PAL/Sequential Thinking, check if tools are available
19. **Fallback Behavior**: If PAL unavailable, limit modes to Standard/Rapid only
20. **If Sequential Thinking unavailable**: Use internal reasoning instead (less structured but functional)

---

## Configuration Reference

**Load configuration from:** `@$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml`

Key settings used:
| Setting | Path | Default |
|---------|------|---------|
| Max rounds | `limits.max_rounds` | 100 |
| Max questions total | `limits.max_questions_total` | **No limit** |
| Min completion rate | `limits.min_completion_rate` | **100%** (all must be answered) |
| PRD readiness threshold GREEN | `scoring.prd_readiness.ready` | 16/20 |
| PRD readiness threshold YELLOW | `scoring.prd_readiness.conditional` | 12/20 |
| Research discovery enabled | `research_discovery.enabled` | true |

**IMPORTANT**: There is NO artificial limit on the number of questions. Generate ALL questions necessary for a complete and robust PRD. The user MUST answer ALL questions - no skipping allowed.

**For template variables and file naming conventions, see:** [config-reference.md](requirements/config-reference.md)

---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

---

## Workflow Overview

```
+-----------------------------------------------------------------------------+
|                         WORKFLOW PHASES                                      |
+-----------------------------------------------------------------------------+
|                                                                             |
|  SETUP PHASES                                                               |
|  -------------------------------------------------------------------------  |
|  Phase 1: Initialization --> Validate, check locks, detect state            |
|  Phase 2: Workspace -------> Create directories, copy draft, init state     |
|  Phase 3: Configuration ---> Select analysis mode (Complete/Advanced/etc.)  |
|                                                                             |
|  RESEARCH PHASES (Optional)                                                 |
|  -------------------------------------------------------------------------  |
|  Phase 4: Research Agenda --> Generate research questions for user          |
|  Phase 5: Research Synthesis -> Analyze user-provided research reports      |
|                                                                             |
|  ANALYSIS PHASES                                                            |
|  -------------------------------------------------------------------------  |
|  Phase 6: Deep Analysis ---> ThinkDeep multi-model insights (Complete/Adv)  |
|  Phase 7: Question Generation -> MPA agents + synthesis                     |
|                                                                             |
|  COLLECTION & VALIDATION PHASES                                             |
|  -------------------------------------------------------------------------  |
|  Phase 8: User Response ---> Collect answers (EXIT for user input)          |
|  Phase 9: Response Analysis -> Gap detection, consistency check             |
|  Phase 10: PRD Validation --> Readiness assessment (PAL Consensus)          |
|                                                                             |
|  OUTPUT PHASES                                                              |
|  -------------------------------------------------------------------------  |
|  Phase 11: PRD Generation --> Generate/extend PRD.md                        |
|  Phase 12: Completion -----> Release lock, final report                     |
|                                                                             |
+-----------------------------------------------------------------------------+
```

---

## Phase Modules

Execute phases in order. Each phase is documented in its own file:

### Setup Phases
- **Phase 1:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/phase-01-initialization.md
- **Phase 2:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/phase-02-workspace.md
- **Phase 3:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/phase-03-configuration.md

### Research Phases (Optional)
- **Phase 4:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/phase-04-research-agenda.md
- **Phase 5:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/phase-05-research-synthesis.md

### Analysis Phases
- **Phase 6:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/phase-06-deep-analysis.md
- **Phase 7:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/phase-07-question-generation.md

### Collection & Validation Phases
- **Phase 8:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/phase-08-user-response.md
- **Phase 9:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/phase-09-response-analysis.md
- **Phase 10:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/phase-10-validation.md

### Output Phases
- **Phase 11:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/phase-11-prd-generation.md
- **Phase 12:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/phase-12-completion.md

---

## Supporting Documentation

- **Checkpoint Protocol:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/checkpoint-protocol.md
- **Error Handling:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/error-handling.md
- **Option Generation (Appendix A):** @$CLAUDE_PLUGIN_ROOT/commands/requirements/appendix-option-generation.md
- **Config & Variables Reference:** @$CLAUDE_PLUGIN_ROOT/commands/requirements/config-reference.md

---

## Agent References

| Agent | Phase | Purpose |
|-------|-------|---------|
| `requirements-product-strategy` | 7 | Product strategy questions |
| `requirements-user-experience` | 7 | UX and persona questions |
| `requirements-business-ops` | 7 | Business viability questions |
| `requirements-question-synthesis` | 7 | Merge and format questions |
| `requirements-prd-generator` | 11 | Generate/extend PRD |
| `research-discovery-business` | 4 | Strategic research questions |
| `research-discovery-ux` | 4 | UX research questions |
| `research-discovery-technical` | 4 | Technical/viability research |
| `research-question-synthesis` | 4 | Synthesize research agenda |

---

## PAL/ThinkDeep Configuration

### ThinkDeep Execution (Phase 6)

**CRITICAL:** ThinkDeep must complete before Phase 7 (MPA agents). Insights inform option generation.

| Perspective | Models (all 3) | Focus | How Phase 7 Uses It |
|-------------|----------------|-------|---------------------|
| Competitive | gpt-5.2, gemini-3-pro-preview, grok-4 | Market positioning, competitor gaps | Options address identified gaps |
| Risk | gpt-5.2, gemini-3-pro-preview, grok-4 | Business risks, assumption validation | Options mitigate flagged risks |
| Contrarian | gpt-5.2, gemini-3-pro-preview, grok-4 | Challenge assumptions, find blind spots | Options survive devil's advocate |

**Execution Sequence:**
```
Phase 6: ThinkDeep (9 calls) -> thinkdeep-insights.md -> CHECKPOINT
    |
    v
Phase 7: MPA Agents (3 parallel, WITH insights) -> questions-*.md
    |
    v
Phase 7: Synthesis Agent -> QUESTIONS-{NNN}.md -> CHECKPOINT
```

### PAL Consensus (Phases 9 & 10)

Used for:
- **Phase 9:** Response consistency validation
- **Phase 10:** PRD readiness assessment

Models configured in `$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml`

---

## Agent File Locations

| Asset | Path |
|-------|------|
| MPA agents | `$CLAUDE_PLUGIN_ROOT/agents/requirements-*.md` |
| Research agents | `$CLAUDE_PLUGIN_ROOT/agents/research-discovery-*.md` |
| Research synthesis | `$CLAUDE_PLUGIN_ROOT/agents/research-question-synthesis.md` |
| Templates | `$CLAUDE_PLUGIN_ROOT/templates/` |
| Configuration | `$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml` |
| State template | `$CLAUDE_PLUGIN_ROOT/templates/.requirements-state-template.local.md` |

---

## Graceful Degradation

This plugin supports graceful degradation when MCP servers are unavailable:

### MCP Availability Check (Phase 1)

```
IF PAL tools unavailable:
  - Limit analysis modes to: Standard, Rapid
  - Skip Phase 6 (ThinkDeep)
  - Skip PAL Consensus in Phases 9 & 10

IF Sequential Thinking unavailable:
  - Use internal multi-step reasoning
  - Mark analysis as "DEGRADED" in state
```

### Mode Availability Matrix

| Mode | PAL Required | Sequential Required | Fallback |
|------|--------------|---------------------|----------|
| Complete | Yes | Yes | → Standard |
| Advanced | Yes | No | → Standard |
| Standard | No | No | Full support |
| Rapid | No | No | Full support |
