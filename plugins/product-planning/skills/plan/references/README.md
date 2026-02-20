# Reference Files Index

Quick guide to when to read each reference file during skill development or debugging.

> **Contributor authoring rules** (phase file authoring, ST patterns, CLI roles, config integrity) are in `$CLAUDE_PLUGIN_ROOT/docs/contributor-guide.md`. Read it when modifying plugin internals.

## Reference File Usage

| File | Read When... |
|------|--------------|
| `research-mcp-patterns.md` | Using Context7/Ref/Tavily MCP servers; optimizing research queries |
| `self-critique-template.md` | Creating or modifying agents; need to add self-verification |
| `cot-prefix-template.md` | Adding reasoning approach to agent prompts |
| `judge-gate-rubrics.md` | Understanding quality gate scoring; debugging PASS/FAIL decisions |
| `adaptive-strategy-logic.md` | Debugging S4 adaptive strategy selection issues |
| `tot-workflow.md` | Working on Complete mode architecture (S5 Tree-of-Thoughts) |
| `debate-protocol.md` | Working on S6 multi-judge debate validation |
| `phase-workflows.md` | Thin index pointing to per-phase files (navigation only) |
| `orchestrator-loop.md` | Understanding dispatch loop, crash recovery, state migration, or delegation ADR |
| `phase-1-setup.md` | Debugging setup, mode selection, or workspace init |
| `phase-2-research.md` | Debugging research, code exploration, or flow analysis |
| `phase-3-clarification.md` | Debugging clarification questions |
| `phase-4-architecture.md` | Debugging architecture design, MPA, or ToT/S5 |
| `phase-5-thinkdeep.md` | Debugging ThinkDeep multi-model analysis |
| `phase-6-validation.md` | Debugging plan validation, PAL Consensus, or S6 debate |
| `phase-6b-expert-review.md` | Debugging expert security/simplicity review |
| `phase-7-test-strategy.md` | Debugging test planning, QA MPA, or V-Model alignment |
| `phase-8-coverage.md` | Debugging test coverage validation |
| `phase-8b-asset-consolidation.md` | Debugging asset discovery, manifest generation, or user validation |
| `phase-9-completion.md` | Debugging task generation or completion |
| `thinkdeep-prompts.md` | Customizing PAL ThinkDeep perspective prompts |
| `validation-rubric.md` | Understanding Phase 6 plan validation scoring |
| `coverage-validation-rubric.md` | Understanding Phase 8 test coverage validation |
| `v-model-methodology.md` | Understanding test level mapping and V-Model alignment |
| `cli-dispatch-pattern.md` | Canonical CLI dual-CLI dispatch pattern (referenced by all CLI phase steps) |
| `skill-loader-pattern.md` | Canonical dev-skills context loading via subagent delegation (referenced by Phases 2, 4, 6b, 7, 9) |
| `deep-reasoning-dispatch-pattern.md` | Offering deep reasoning escalation after gate failures or security findings; understanding the manual user submission workflow |
| `mpa-synthesis-pattern.md` | Adding or modifying MPA Deliberation (S1) or Convergence Detection (S2); understanding Jaccard similarity trade-offs |

## Working with CLI Integration

CLI roles are defined as templates in `$CLAUDE_PLUGIN_ROOT/templates/cli-roles/` and auto-deployed to projects at runtime (Phase 1). Dispatch uses Bash process-group dispatch (`scripts/dispatch-cli-agent.sh`) instead of PAL MCP.

### Dual-CLI MPA Pattern
Each CLI role runs BOTH Gemini and Codex in parallel via `Bash(run_in_background=true)`. The coordinator synthesizes findings as convergent/divergent/unique, then runs self-critique via a Task subagent with ST Chain-of-Verification.

### Key Files
- `$CLAUDE_PLUGIN_ROOT/templates/cli-roles/README.md` — Role index and deployment docs
- `$CLAUDE_PLUGIN_ROOT/templates/cli-roles/*.txt` — 10 role prompt files (5 roles x 2 CLIs)
- `$CLAUDE_PLUGIN_ROOT/templates/cli-roles/*.json` — CLI client configurations
- `$CLAUDE_PLUGIN_ROOT/config/planning-config.yaml` `cli_integration:` section — All config
- `$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh` — Process-group-safe dispatch script

### CLI-Enhanced Phases
| Phase | Role | Step | Report |
|-------|------|------|--------|
| 1 | — | Step 1.5b: Detection + deployment | State only |
| 5 | deepthinker | Step 5.6: Supplement ThinkDeep | `cli-deepthinker-report.md` |
| 6 | planreviewer | Step 6.0a: Pre-validation review | `cli-planreview-report.md` |
| 6b | securityauditor | Step 6b.1b: Security supplement | `cli-security-report.md` |
| 7 | teststrategist | Step 7.3.5: Test review | `cli-testreview-report.md` |
| 9 | taskauditor | Step 9.5b: Task audit | `cli-taskaudit-report.md` |

## By Task

### Understanding the Delegation Architecture
1. Read `orchestrator-loop.md` for dispatch loop and recovery
2. Read any per-phase file for that phase's complete instructions
3. Read `phase-workflows.md` for the navigational index

### Using Research MCP Servers
1. Read `research-mcp-patterns.md` for server selection and query patterns
2. Check per-phase files (phase-2, phase-4, phase-7) for integration points

### Adding a New Agent
1. Read `self-critique-template.md` for verification section
2. Read `cot-prefix-template.md` for reasoning approach
3. Read `research-mcp-patterns.md` if agent uses research MCP servers

### Debugging Quality Gates
1. Read `judge-gate-rubrics.md` for scoring criteria
2. Read `adaptive-strategy-logic.md` if strategy selection fails

### Modifying the Workflow
1. Read `phase-workflows.md` for the navigational index
2. Read the specific per-phase file for detailed instructions

### Working on Test Planning
1. Read `v-model-methodology.md` for test level definitions
2. Read `coverage-validation-rubric.md` for validation scoring

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| `phase-workflows.md` | ~44 | Thin navigational index to per-phase files |
| `orchestrator-loop.md` | ~155 | Dispatch loop, crash recovery, migration |
| `phase-*-*.md` | 70-572 | Per-phase coordinator instructions |
| `research-mcp-patterns.md` | ~293 | Research MCP server usage guide |
| `judge-gate-rubrics.md` | ~308 | Gate evaluation criteria |
| `self-critique-template.md` | ~133 | Agent verification template |
| `tot-workflow.md` | ~344 | Tree-of-Thoughts process |
| `debate-protocol.md` | ~425 | Multi-round debate structure |
| Others | <100 | Focused reference content |
| `cli-dispatch-pattern.md` | ~160 | Canonical CLI dual-CLI dispatch pattern |
| `skill-loader-pattern.md` | ~100 | Dev-skills context loading via subagent delegation |
| `phase-8b-asset-consolidation.md` | ~170 | Asset consolidation coordinator instructions |
| `deep-reasoning-dispatch-pattern.md` | ~180 | Deep reasoning escalation dispatch pattern |
| `mpa-synthesis-pattern.md` | ~130 | Shared MPA Deliberation (S1) + Convergence Detection (S2) algorithms |
| `$PLUGIN/templates/asset-manifest-template.md` | ~90 | Asset manifest structure template |
| `$PLUGIN/templates/deep-reasoning-templates.md` | ~200 | CTCO prompt templates for deep reasoning models |
| `$PLUGIN/templates/cli-roles/*.txt` | ~80-120 | CLI role prompts (10 files) |
| `$PLUGIN/templates/cli-roles/README.md` | ~100 | CLI role index and patterns |

### Working with Dev-Skills Integration
1. Read `skill-loader-pattern.md` for the canonical subagent dispatch pattern
2. Check `config/planning-config.yaml` `dev_skills_integration:` section for domain-skill mappings
3. Phase 1 (`phase-1-setup.md`) Step 1.5c handles detection
4. Phases 2, 4, 6b, 7, 9 each have a skill loader step (e.g., Step 4.0a)
5. Agent files (`agents/*.md`) have "Skill Awareness" sections for runtime context

### Dev-Skills Enhanced Phases
| Phase | Step | Skills Loaded (Conditional) | Budget |
|-------|------|-----------------------------|--------|
| 1 | 1.5c | Detection only (inline) | — |
| 2 | 2.2c-a | accessibility, mobile, figma | 2500 |
| 4 | 4.0a | api-patterns, database, c4, mermaid, frontend | 3000 |
| 6b | 6b.0a | clean-code, api-patterns (security) | 2000 |
| 7 | 7.1c | qa-test-planner, accessibility | 2000 |
| 9 | 9.2a | clean-code | 800 |

### Working with Deep Reasoning Escalation

External deep reasoning models (GPT-5 Pro, Google Deep Think) can be escalated to when Claude's gate-retry loop fails. The user manually submits a CTCO prompt to the model's web interface and returns the result.

1. Read `deep-reasoning-dispatch-pattern.md` for the canonical escalation workflow
2. Check `config/planning-config.yaml` `deep_reasoning_escalation:` section for flags and keywords
3. Phase 1 (`phase-1-setup.md`) Step 1.5d handles algorithm detection
4. `orchestrator-loop.md` gate failure handler and post-Phase-6b check trigger escalation
5. Templates in `$PLUGIN/templates/deep-reasoning-templates.md` define CTCO prompts

### Deep Reasoning Escalation Points

| Trigger | Phase | Type | Config Flag |
|---------|-------|------|-------------|
| Gate RED after 2 retries | Any gated | `circular_failure` | `circular_failure_recovery` |
| Phase 6 RED → Phase 4 | 6→4 | `architecture_wall` | `architecture_wall_breaker` |
| 2+ CRITICAL security findings | 6b | `security_deep_dive` | `security_deep_dive` |
| Algorithm keywords in spec | 1 (detect), 4/7 (surface) | `algorithm_escalation` | `abstract_algorithm_detection` |

## Cross-References

- `phase-workflows.md` references most other files
- `skill-loader-pattern.md` used by Phase 2, 4, 6b, 7, 9 skill loader steps
- `cli-dispatch-pattern.md` used by Phase 5, 6, 6b, 7, 9 CLI steps
- `research-mcp-patterns.md` used by `researcher` agent and Phase 2/4/7 workflows
- `judge-gate-rubrics.md` used by `phase-gate-judge` agent
- `self-critique-template.md` used by all agents
- `debate-protocol.md` used by `debate-judge` agent
- `deep-reasoning-dispatch-pattern.md` used by `orchestrator-loop.md` gate failure handler and Phase 6b security check
- `mpa-synthesis-pattern.md` used by Phase 4 (Steps 4.1b, 4.1c) and Phase 7 (Steps 7.3.2b, 7.3.3b) for shared MPA algorithms
- `phase-8b-asset-consolidation.md` feeds `asset-manifest.md` into Phase 9 for Phase 0 task generation
