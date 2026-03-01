# Contributor Guide — product-planning Plugin

Authoring rules, design patterns, and quality standards for contributors modifying this plugin's skills, agents, templates, and configuration. Read this guide when editing plugin internals — it is not loaded automatically.

> **Operational context** (phase workflow, agent inventory, MCP dependencies) lives in `CLAUDE.md`.
> **Repository-wide patterns** (Lean Orchestrator, MPA, State File Design) live in the root `CLAUDE.md`.

---

## Table of Contents

1. [Architecture Decisions](#architecture-decisions)
2. [Sequential Thinking Patterns](#sequential-thinking-patterns)
3. [CLI Integration](#cli-integration)
4. [Phase File Authoring](#phase-file-authoring)
5. [Configuration Integrity](#configuration-integrity)
6. [Agent Design Standards](#agent-design-standards)
7. [Template Design](#template-design)
8. [Dev-Skills Integration](#dev-skills-integration)
9. [Deep Reasoning Integration](#deep-reasoning-integration)
10. [Quality Verification](#quality-verification)
11. [Documentation Standards](#documentation-standards)
12. [Quick Reference: Anti-Patterns](#quick-reference-anti-patterns)

---

## Architecture Decisions

### Integration over Separation
- **Pattern**: Embed tightly-coupled functionality as phases within a single workflow rather than separate skills
- **Rationale**: Separate skills for coupled workflows create state synchronization issues and user friction
- **Example**: Test planning (Phases 7-8) is embedded in main `/plan` skill, not a separate `/plan-tests`
- **Anti-pattern**: Creating separate skills that share state files and must be run in sequence

### MPA Pattern Extensibility
- **Pattern**: Apply Multi-Perspective Analysis (MPA) to any phase requiring diverse viewpoints
- **Implementation**: Launch 2-3 specialized agents in parallel, synthesize their outputs
- **Applied to**: Phase 4 (architecture: grounding/ideality/resilience via Diagonal Matrix) and Phase 7 (QA: general/security/performance)
- **Checklist**: When adding MPA, define: agent variants, mode availability, output synthesis rules

### Phase Reconciliation
- **Pattern**: Multi-phase workflows with related analysis need explicit reconciliation steps
- **Example**: Phase 7 reconciles Phase 5 ThinkDeep security insights with test risk analysis
- **Implementation**: Create reconciliation step that maps prior findings to current phase, identifies gaps/conflicts
- **Output**: Reconciliation report showing alignment and flagging unresolved conflicts

---

## Sequential Thinking Patterns

### Advanced ST Patterns

The following patterns leverage ST MCP parameters for sophisticated reasoning:

#### Diagonal Matrix Fork-Join for Architecture (st_fork_join_architecture)
- **When**: Exploring multiple architecture perspectives in Phase 4
- **Pattern**: Frame → Branch × 3 (grounding, ideality, resilience) → Reconcile → Compose
- **ST Parameters**: `branchFromThought`, `branchId`
- **Mode**: Complete only
- **Cost Impact**: +4 ST calls (~50% Phase 4 increase)

```
T7a_FRAME (branchFromThought: null)
    ├── T7b_BRANCH_GROUNDING (branchFromThought: 1, branchId: "grounding")
    ├── T7c_BRANCH_IDEALITY (branchFromThought: 1, branchId: "ideality")
    └── T7d_BRANCH_RESILIENCE (branchFromThought: 1, branchId: "resilience")
T8a_RECONCILE (tension map across 9 cells)
T8b_COMPOSE (merge primaries with tension resolution)
```

#### Revision for Reconciliation (st_revision_reconciliation)
- **When**: Later analysis contradicts earlier findings (ThinkDeep vs T-RISK)
- **Pattern**: Original thought → External input → Revision thought
- **ST Parameters**: `isRevision: true`, `revisesThought: <thought_number>`
- **Mode**: Complete, Advanced
- **Cost Impact**: +1 ST call (~10% Phase 7 increase)

```
T-RISK-2 (original prioritization)
    ↓ ThinkDeep contradicts
T-RISK-REVISION (isRevision: true, revisesThought: 2)
```

#### Red Team Branch (st_redteam_analysis)
- **When**: Security/risk analysis in Phase 7 for sensitive features
- **Pattern**: Standard analysis → Red team branch → Synthesis
- **ST Parameters**: `branchId: "redteam"`
- **Mode**: Complete, Advanced
- **Cost Impact**: +2 ST calls (~20% Phase 7 increase)

```
T-RISK-1 (failure modes)
    └── T-RISK-REDTEAM (branchFromThought: 1, branchId: "redteam")
T-RISK-REDTEAM-SYNTHESIS (joins red team findings)
```

#### TAO Loop (st_tao_loops)
- **When**: After MPA agents complete in Phases 2, 4, 7
- **Pattern**: Analysis → Synthesis → Validation
- **Purpose**: Structured pause between agent outputs and decisions
- **Mode**: Complete, Advanced, Standard
- **Cost Impact**: +3 ST calls per MPA phase (~30% per phase)

```
MPA Agents Complete
    ↓
T-AGENT-ANALYSIS (categorize: convergent/divergent/gaps)
    ↓
T-AGENT-SYNTHESIS (define handling strategy)
    ↓
T-AGENT-VALIDATION (quality check before proceed)
```

#### Dynamic Extension (st_dynamic_extension)
- **When**: Complexity exceeds initial estimates during ST chain
- **Pattern**: Use `needsMoreThoughts: true` to extend chain
- **Mode**: Complete only
- **Triggers**: Component count > 10, unexpected integration points, extensive security requirements

### MCP Parameter Reference

| Parameter | Purpose | When to Use |
|-----------|---------|-------------|
| `branchFromThought` | Spawn exploration from a specific thought | Fork-Join, Red Team branching |
| `branchId` | Name the branch (descriptive: "grounding", "redteam") | Always pair with `branchFromThought` |
| `isRevision` | Mark thought as updating prior conclusion | Reconciliation when new evidence contradicts |
| `revisesThought` | Reference the thought being revised | Always pair with `isRevision: true` |
| `needsMoreThoughts` | Signal chain should extend | Complexity exceeds estimate mid-chain |

### Template JSON Requirements

ST template JSON must include these fields to avoid silent failures:
- **Required**: `thought`, `thoughtNumber`, `totalThoughts`, `nextThoughtNeeded`
- **Recommended**: `hypothesis`, `confidence`
- **For branching**: `branchFromThought`, `branchId`
- **For revision**: `isRevision`, `revisesThought`

### Branch Traceability
- Use descriptive `branchId` strings ("grounding", "ideality", "resilience", "redteam") not numeric IDs
- Omit `branchId` in synthesis/join thoughts to signal return to main trunk

### Revision vs Extension

| Scenario | Use | Rationale |
|----------|-----|-----------|
| New evidence contradicts prior conclusion | `isRevision: true` | Updates existing analysis |
| Need more analysis depth | `needsMoreThoughts: true` | Extends chain linearly |
| Exploring alternative approach | `branchFromThought` + `branchId` | Parallel exploration |

### Workflow Enhancement Coordination

When implementing enhancements spanning multiple files, update in dependency order:
1. **Templates** (`templates/sequential-thinking-templates.md`)
2. **Workflows** (`skills/plan/references/phase-workflows.md`)
3. **Agents** (`agents/*.md`)
4. **Config** (`config/planning-config.yaml`)
5. **Documentation** (`SKILL.md`, `CLAUDE.md`)

#### Feature Flag Best Practices

```yaml
st_example_feature:
  enabled: true
  description: "Clear description of what it does"
  rollback: "Set false to disable (describe fallback behavior)"
  modes: [complete, advanced]  # Which modes can use this
  requires_mcp: true           # Always true for ST enhancements
  cost_impact: "+N ST calls (~X% phase increase)"  # Document cost
```

#### Template Group Registration

When adding new ST template groups:
1. Add definitions to `templates/sequential-thinking-templates.md`
2. Register in `config/planning-config.yaml` under `sequential_thinking.template_groups`
3. Map to phases in `sequential_thinking.phase_mapping`
4. Link flag to templates in `sequential_thinking.flag_to_templates`
5. Update availability matrix in templates file

---

## CLI Integration

### Multi-CLI MPA Pattern
- **Pattern**: Run Gemini + Codex + OpenCode in parallel via Bash process-group dispatch for each analysis role, then synthesize
- **Rationale**: Gemini (1M context) excels at broad exploration; Codex excels at code-level precision; OpenCode brings UX/Product lens (accessibility, user flows, product alignment)
- **Implementation**: Each CLI step has 4 sub-steps: dispatch (parallel `Bash(run_in_background=true)`) → synthesis → self-critique (Task subagent) → write report
- **Dispatch script**: `$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh` — process-group-safe with 4-tier output extraction
- **Self-critique isolation**: CoVe verification runs in a separate `Task(general-purpose)` subagent to avoid coordinator context pollution
- **Modes**: Complete and Advanced only

### Role Design
- **6 roles**: deepthinker, consensus, planreviewer, teststrategist, securityauditor, taskauditor
- **18 prompt files**: Each role has `gemini_{role}.txt`, `codex_{role}.txt`, and `opencode_{role}.txt` in `templates/cli-roles/`
- **EXPLORE directives**: Every role MUST include filesystem exploration instructions
- **No researcher**: Removed — duplicates Research MCP (Context7/Ref/Tavily)
- **No reconciliator**: Absorbed into teststrategist review protocol

### Template-to-Runtime Deployment
- **Source of truth**: `$CLAUDE_PLUGIN_ROOT/templates/cli-roles/`
- **Runtime location**: `PROJECT_ROOT/conf/cli_clients/`
- **Deployment**: Phase 1 auto-copies if missing or version marker mismatch

### Synthesis Categorization
- **Unanimous** (all 3 CLIs agree): VERY HIGH confidence, merge directly
- **Majority** (2 of 3 CLIs agree): HIGH confidence, note dissenting view
- **Divergent** (all CLIs disagree): FLAG for user decision or use higher severity
- **Unique** (one CLI only): VERIFY against existing findings before accepting

### Shared Dispatch Pattern (DRY)
- **Rule**: When multiple phases use the same multi-step workflow, extract to `skills/plan/references/cli-dispatch-pattern.md`
- **Anti-pattern**: Duplicating 50+ line pseudocode blocks across 5 phase files

### CLI Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Removing CLI fallback | CLI is now primary, not supplement | Ensure internal fallback still works when CLIs unavailable |
| Running CLI dispatch in Standard/Rapid | Latency not justified | Restrict to Complete/Advanced |
| Self-critique inline in coordinator | Context pollution | Use Task subagent |
| Single-CLI without degradation notice | User unaware analysis reduced | Log degradation, set state.cli.mode |
| Role prompts without EXPLORE directives | Agents miss codebase evidence | Every role MUST explore filesystem |
| Deploying to wrong directory | CLI reads from project conf/ | Auto-deploy in Phase 1 |
| CLI dispatch without availability check | Fails silently | Step 1.6 checks availability |

### External Prompt Authoring

- CLI role prompt files (.txt) must include conditional availability notes for MCP tools (Gemini/Codex/OpenCode environments don't have Claude's MCP servers)
- CLI auto-approval flags (`--yolo`, `--dangerously-bypass-approvals-and-sandbox`) must have documented security trade-off notes in README
- OpenCode uses non-interactive mode (`opencode run --format json -f <file>`) which auto-rejects permissions — no auto-approval flag needed

---

## Phase File Authoring

### Step Ordering Discipline
- **Rule**: Physical order of steps MUST match logical execution order
- **Why**: Coordinators read top-to-bottom regardless of step numbers
- **Check**: After inserting a new step, verify neighbors match intended predecessor/successor

### Explicit Mode Guards Per Step
- **Rule**: Every optional step must have its own `IF analysis_mode in {X, Y}:` guard
- **Why**: Phase-level mode restrictions document eligibility; step-level guards provide runtime protection
- **Anti-pattern**: Relying solely on phase frontmatter `modes:` without per-step guards

### Artifacts Written Completeness
- **Rule**: Phase frontmatter `artifacts_written` must list ALL files including conditional ones
- **Format**: `- "analysis/cli-report.md"  # conditional: CLI enabled`
- **Why**: Crash recovery uses this list to reconstruct state

---

## Configuration Integrity

### Config-to-Implementation Alignment
- Every config value promising runtime behavior (retry counts, circuit breaker thresholds, timeouts) MUST have corresponding implementation in a workflow file
- After adding config entries, grep for the key name across phase files to verify it's consumed
- Anti-pattern: "dead config" that misleads users

### YAML Range Values
- Never use `3-5` for numeric ranges (YAML parses as string `"3-5"`)
- Use structured `min/max` instead: `verification_questions: { min: 3, max: 5 }`

### Single Source of Truth
- Configurable values (thresholds, costs, model names) must exist in exactly one place: `config/planning-config.yaml`
- Anti-pattern: Duplicating values in SKILL.md, CLAUDE.md, and config

### Threshold Semantics
- Always clarify boundary conditions: `GREEN: score >= 16`, `YELLOW: score >= 12 AND score < 16`, `RED: score < 12`
- Anti-pattern: Ambiguous "RED <12" with separate `not_ready: 11` field

### External CLI Names
- CLI identifiers (gemini, codex) are configurable placeholders
- Users should update to match their available CLI installations

### Feature Flag Dependencies
- Flags that depend on other flags must declare `requires: [flag_names]`
- Example: `s5_tot_architecture.requires: [s4_adaptive_strategy]`

---

## Agent Design Standards

### Anti-Patterns Sections
- Every agent file must have domain-specific anti-patterns (3-5 per agent)
- Format: Table with Anti-Pattern | Why It's Wrong | Instead Do
- Placement: Near end of file, after Self-Critique section

### Intentional Agent Variance
- **Architect agents**: 6 self-critique questions (high stakes)
- **Standard agents**: 5 questions (balanced)
- **Lightweight/haiku agents**: 4 questions (cost-conscious)
- Documented in `references/self-critique-template.md`

### Agent Awareness Hints
- 6 agents have "Skill Awareness" sections for optional dev-skills content injection
- Format: "Your prompt may include a `## Domain Reference (from dev-skills)` section. When present: [usage bullets]. If absent, proceed normally."
- Never hard-depend on injected content

---

## Template Design

### Glossary Sections
- Templates for non-technical stakeholders (UAT scripts) must include glossary
- Define: AC, TDD, Given-When-Then, Inner/Outer Loop
- Placement: Appendix section at end

### Template Completeness Checklist
- [ ] All placeholder sections have example content
- [ ] Glossary for non-technical users
- [ ] Evidence/sign-off sections where approval needed
- [ ] Cross-references to related templates

---

## Dev-Skills Integration

### Subagent-Delegated Skill Loading
- Coordinators dispatch a throwaway `Task(general-purpose)` subagent to load, extract, and condense dev-skills (~70% token savings vs inline)
- Detection: Phase 1 Step 1.7 scans spec.md for technology keywords and project root for framework markers
- Modes: Complete, Advanced, Standard (NOT Rapid)
- Reference: `skills/plan/references/skill-loader-pattern.md`
- Config: `config/planning-config.yaml` `dev_skills_integration:` section

### Skill Loader Steps by Phase

| Phase | Step | Skills Loaded | Budget | Parallel With |
|-------|------|---------------|--------|---------------|
| 2 | 2.6 | accessibility, mobile, figma | 2500 | code-explorer, researcher |
| 4 | 4.1 | api-patterns, database, c4, mermaid, frontend | 3000 | Research MCP (Step 4.3) |
| 6b | 6b.1 | clean-code, api-security | 2000 | N/A |
| 7 | 7.3 | qa-test-planner, accessibility | 2000 | Research MCP (Step 7.2) |
| 9 | 9.3 | clean-code | 800 | N/A |

### Dev-Skills Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Invoke Skill() directly in coordinator | Context pollution (~5-15K) | Delegate to subagent |
| Load skills in Rapid mode | Unnecessary latency | Skip via mode guard |
| Exceed per-phase token budget | Coordinator context bloat | Enforce limits in loader prompt |
| Skip Phase 1 detection | All phases load max skills | Always run Step 1.7 |
| Hard-depend on skill content | Breaks without dev-skills | Treat as supplementary |

---

## Deep Reasoning Integration

### Orchestrator-Level Execution
- Deep reasoning escalation runs at the **orchestrator level**, not within coordinators
- Workflow: Detect trigger → generate CTCO prompt → present via `AskUserQuestion` → user submits externally → user returns response → re-dispatch coordinator
- State tracking: `state.deep_reasoning` tracks `escalations[]`, `pending_escalation`, `algorithm_detected`
- Resume: Pending escalations are re-presented on workflow resume
- Config: `config/planning-config.yaml` `deep_reasoning_escalation:` (all disabled by default)
- Reference: `skills/plan/references/deep-reasoning-dispatch-pattern.md`
- Templates: `templates/deep-reasoning-templates.md`

### Escalation Types

| Type | Trigger | Phase | Config Flag |
|------|---------|-------|-------------|
| `circular_failure` | Gate RED after 2 retries | Any gated | `circular_failure_recovery` |
| `architecture_wall` | Phase 6 RED → Phase 4 loop | 6 → 4 | `architecture_wall_breaker` |
| `security_deep_dive` | 2+ CRITICAL security findings | 6b | `security_deep_dive` |
| `algorithm_escalation` | Algorithm keywords in spec | 1 (detect), 4/7 (surface) | `abstract_algorithm_detection` |

### Deep Reasoning Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Escalate in Standard/Rapid mode | Latency not justified | Mode guard: Complete/Advanced only |
| Escalate for creative tasks | Models produce flat output | Check anti-pattern list in skill |
| Auto-escalate without user consent | User must submit externally | Always present via `AskUserQuestion` |
| Run inside coordinator | Context pollution | Orchestrator mediates all |
| Skip pending escalation on resume | User loses submitted work | Check `state.deep_reasoning.pending_escalation` |
| Escalate before 2 retries | Premature | Only after retry limit exhausted |

---

## Quality Verification

### Post-Refactoring Checklist
- [ ] All agent names in SKILL.md dispatch table have files in `agents/`
- [ ] All template paths in phase files exist in `templates/`
- [ ] All per-phase files in dispatch table exist in `references/`
- [ ] Config feature flags referenced in phase files are defined in config
- [ ] No stub markers remain (TODO, FIXME, TBD, PLACEHOLDER)
- [ ] `references/README.md` index updated with new entries and sizes
- [ ] No cross-plugin file leakage in staged commits

### Critique-Driven Improvements

Resolve findings in priority order: MUST DO → SHOULD DO → COULD DO.

1. **Critical**: Duplicate files, missing reconciliation — fix immediately
2. **High**: Inconsistent constants, missing MPA — fix before release
3. **Medium**: Missing glossaries, unclear thresholds — fix next iteration
4. **Low**: Style inconsistencies — batch fix periodically

**Batching**: Group related changes (all config changes together, all agent updates together) to minimize context switching. Run verification commands from critique report after each priority tier.

### Reference File Organization

- Reference directories with 5+ files should have a `README.md` index
- Content: Table showing "File | Read When..." for quick navigation
- Location: `skills/{skill}/references/README.md`

---

## Documentation Standards

### Table of Contents Consistency
- TOC section names MUST match body heading names exactly

### Cost Comparison Baselines
- Specify exact baseline mode/version: "ToT ($0.38) vs Standard MPA in Complete mode ($0.22)"
- Anti-pattern: Comparing Complete mode improvement to Standard mode baseline

### Acceptance Criteria
- Each proposed improvement needs measurable acceptance criteria with verification method
- Format:
  ```yaml
  improvement: S1 Self-Critique
  acceptance_criteria:
    - Agent prompts include self-critique section
    - Output includes self_critique YAML block
    - Questions passed >= 4/5 for submission
  verification: Automated test or manual checklist
  ```
- Anti-pattern: Listing improvements without success conditions

### Gap-to-Improvement Traceability
- Each improvement should trace back to identified gaps
- Format: "**Gap Addressed:** G1 - Description"
- Verification: Matrix showing Gap → Improvement mapping

### Threshold Scales
- Always explain what scale values mean: "Score 1-5 where: 1=missing, 2=incomplete, 3=adequate, 4=good, 5=excellent"

### Research Attribution
- Chain-of-Verification: Dhuliawala et al. (2023)
- Constitutional AI Self-Critique: Bai et al. (2022)
- Zero-Shot CoT: Kojima et al. (2022)
- Tree of Thoughts: Yao et al. (2023)
- Multi-Agent Debate: Du et al. (2023)

### Judge Calibration
- Include in judge prompts: scoring rubric, 2-3 calibration examples, common failure modes
- Document retry behavior: max retries, feedback on failure, escalation path, state management during retries
- Reference: `references/judge-gate-rubrics.md`

### Cost Table Updates
- When adding cost-impacting features, update the cost table in SKILL.md with per-mode impact

---

## Quick Reference: Anti-Patterns

Consolidated cross-cutting anti-patterns for fast lookup. Domain-specific anti-patterns are in their respective sections above.

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Separate skills for coupled workflows | State sync issues, user must remember sequence | Embed as phases in single workflow |
| Duplicate reference files | Maintenance burden, drift risk | Single copy, reference via `$CLAUDE_PLUGIN_ROOT` |
| Hardcoded values in multiple files | Inconsistency, hard to update | Single source in `config/planning-config.yaml` |
| Missing phase reconciliation | Conflicting analysis, coverage gaps | Explicit reconciliation step between related phases |
| Templates without glossary | Non-technical users confused | Add glossary appendix |
| Ambiguous thresholds | Off-by-one errors, unclear logic | Use explicit comparison operators (`>=`, `<`) |
| Generic anti-patterns in agents | Not actionable for specific domain | Domain-specific anti-patterns per agent type |
| Uniform agent configurations | Ignores responsibility differences | Calibrate verification to agent impact level |

---

*Last updated: 2026-02-19 — Extracted from CLAUDE.md to reduce per-conversation context consumption (~8K tokens saved)*
