# CLAUDE.md

This file provides guidance to Claude Code when working with this plugin.

## Plugin Overview

Plugin for feature planning, task decomposition, and **integrated test strategy generation** using SDD (Subagent-Driven Development) patterns with:
- **Multi-Perspective Analysis (MPA)** - Parallel agents with different focuses
- **PAL ThinkDeep** - External model insights (performance, maintainability, security)
- **PAL Consensus** - Multi-model validation with scoring rubric
- **Sequential Thinking** - Structured reasoning templates
- **Research MCP Integration** - Context7/Ref/Tavily for authoritative documentation lookup
- **V-Model Test Planning** - Comprehensive test strategy aligned with development phases (integrated)
- **UAT Script Generation** - User story-based acceptance testing with Given-When-Then format

## Plugin Testing

```bash
# Install locally for testing
claude plugins add /path/to/product-planning
claude plugins enable product-planning

# Run the main workflow (includes test planning)
/product-planning:plan
```

## Architecture

### 9-Phase Integrated Workflow

The skill `skills/plan/SKILL.md` orchestrates a **9-phase workflow** that includes both feature planning AND test strategy. The orchestrator delegates phases to coordinator subagents via `Task(general-purpose)`. Each coordinator reads a self-contained per-phase instruction file and communicates results through standardized summary files. See `skills/plan/references/orchestrator-loop.md` for dispatch logic.

```
┌─────────────────────────────────────────────────────────────────┐
│                    PLANNING WORKFLOW (V-MODEL)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Phase 1: Setup & Initialization                                 │
│       ↓                                                          │
│  Phase 2: Research & Exploration                                 │
│       ↓                                                          │
│  Phase 3: Clarifying Questions ─────────→ UAT Scripts           │
│       ↓                                                          │
│  Phase 4: Architecture Design ──────────→ E2E Tests             │
│       ↓                                                          │
│  Phase 5: PAL ThinkDeep ────────────────→ Integration Tests     │
│       ↓                                                          │
│  Phase 6: Plan Validation                                        │
│       ↓                                                          │
│  Phase 7: Test Strategy (V-Model) ──────→ Unit Tests (TDD)      │
│       ↓                                                          │
│  Phase 8: Test Coverage Validation                               │
│       ↓                                                          │
│  Phase 9: Task Generation & Completion ─→ tasks.md (TDD)        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key Integrations:**
- Test planning (Phases 7-8) is embedded directly in the main workflow
- Task generation (Phase 9) uses test artifacts for TDD integration
- The `/tasks` command is deprecated - use `/plan` for complete workflow

### Phase Summary

| Phase | Name | Purpose |
|-------|------|---------|
| 1 | Setup | Initialize workspace, detect state, select analysis mode |
| 2 | Research | Codebase exploration, technology research |
| 3 | Clarification | User questions, gap resolution |
| 4 | Architecture | MPA design options (minimal/clean/pragmatic) |
| 5 | ThinkDeep | PAL multi-model insights (Complete/Advanced modes) |
| 6 | Validation | PAL Consensus plan validation |
| **7** | **Test Strategy** | **V-Model test planning, UAT generation** |
| **8** | **Test Coverage** | **Coverage validation, PAL Consensus** |
| **9** | **Task Generation** | **TDD-structured tasks with test refs, clarification loop** |

### Analysis Mode Hierarchy

| Mode | Description | MCP Required |
|------|-------------|--------------|
| Complete | MPA + ThinkDeep (9) + ST + Consensus + Full Test Plan | Yes |
| Advanced | MPA + ThinkDeep (6) + Test Plan | Yes |
| Standard | MPA only + Basic Test Plan | No |
| Rapid | Single agent + Minimal Test Plan | No |

See `config/planning-config.yaml` `analysis_modes` for current cost estimates and `blessed_profiles` for full-ST costs.

The plugin gracefully degrades when MCP tools are unavailable.

### PAL ThinkDeep Integration

Phase 5 executes multi-model analysis across perspectives:
- **Performance** - Scalability, latency, resource efficiency
- **Maintainability** - Code quality, extensibility, technical debt
- **Security** - Threat modeling, compliance, vulnerabilities

Models used: gpt-5.2, gemini-3-pro-preview, grok-4

### PAL Consensus Validation

**Phase 6 (Plan):** 20 points across 5 dimensions:
- Problem Understanding (20%)
- Architecture Quality (25%)
- Risk Mitigation (20%)
- Implementation Clarity (20%)
- Feasibility (15%)

Thresholds: GREEN ≥16, YELLOW ≥12, RED <12

**Phase 8 (Test Coverage):** 100% across 5 dimensions:
- AC Coverage (25%)
- Risk Coverage (25%)
- UAT Completeness (20%)
- Test Independence (15%)
- Maintainability (15%)

Thresholds: GREEN ≥80%, YELLOW ≥65%, RED <65%

### State Management

State is persisted in `{FEATURE_DIR}/.planning-state.local.md` (YAML frontmatter + markdown). The workflow is resumable—user decisions are immutable and never re-asked.

Checkpoints: SETUP → RESEARCH → CLARIFICATION → ARCHITECTURE → THINKDEEP → VALIDATION → EXPERT_REVIEW → **TEST_STRATEGY** → **TEST_COVERAGE_VALIDATION** → COMPLETION

State file version 2 adds `phase_summaries` tracking and `orchestrator` metadata. v1 files are auto-migrated on resume.

## V-Model Test Planning (Integrated)

### Test Levels (V-Model Alignment)

| Development Phase | Test Level | Loop | Executor |
|------------------|------------|------|----------|
| Requirements | UAT (Acceptance) | Outer | Product Owner |
| Architecture | E2E (System) | Outer | QA / Automation |
| Design | Integration | Inner | CI Pipeline |
| Implementation | Unit | Inner | CI Pipeline (TDD) |

### Inner vs Outer Loop

**Inner Loop (Automated, CI):**
- Unit Tests - TDD pattern, write before implementation
- Integration Tests - Component boundaries

**Outer Loop (Manual/Agentic, Pre-release):**
- E2E Tests - Complete user flows with evidence
- UAT Scripts - Given-When-Then format for stakeholders
- Exploratory Testing - Charter-based edge case discovery

### UAT Script Format

UAT scripts follow Gherkin-style Given-When-Then:

```gherkin
Given: {preconditions}
When: {user actions}
Then: {expected outcomes}
```

With evidence collection (screenshots) and sign-off checkboxes for Product Owner approval.

### TDD-Structured Tasks

Phase 9 generates tasks structured as TEST → IMPLEMENT → VERIFY cycles:

```markdown
## Task: {component_name}

### 1. TEST (RED)
- Write failing unit tests: UT-{ids}

### 2. IMPLEMENT (GREEN)
- Write minimal code to pass tests

### 3. VERIFY
- Run integration tests: INT-{ids}
```

## Key Design Patterns

### Sequential Thinking Templates

25+ templates organized into groups:
- **T1-T3:** Problem Decomposition
- **T4-T6:** Codebase Analysis
- **T7-T10:** Architecture Design (linear)
- **T7a-T8:** Fork-Join Architecture (branching exploration)
- **T11-T13:** Risk Assessment
- **T14-T16:** Plan Validation
- **T-RISK-1 to T-RISK-3:** Test Risk Analysis
- **T-RISK-REVISION:** Reconciliation (revision capability)
- **T-RISK-REDTEAM series:** Adversarial analysis (branching)
- **T-AGENT series:** TAO Loop (structured synthesis pause)
- **T-EXTENSION:** Dynamic chain extension

Templates are in `templates/sequential-thinking-templates.md`.

### Sequential Thinking Advanced Patterns

The following patterns leverage previously unused ST MCP parameters for more sophisticated reasoning:

#### Fork-Join for Architecture (st_fork_join_architecture)
- **When**: Exploring multiple architecture options in Phase 4
- **Pattern**: Frame → Branch × 3 (minimal, clean, pragmatic) → Synthesize
- **ST Parameters**: `branchFromThought`, `branchId`
- **Mode**: Complete only
- **Cost Impact**: +3 ST calls (~40% Phase 4 increase)

```
T7a_FRAME (branchFromThought: null)
    ├── T7b_BRANCH_MINIMAL (branchFromThought: 1, branchId: "minimal")
    ├── T7c_BRANCH_CLEAN (branchFromThought: 1, branchId: "clean")
    └── T7d_BRANCH_PRAGMATIC (branchFromThought: 1, branchId: "pragmatic")
T8_SYNTHESIS (joins all branches)
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
- **ST Parameters**: `needsMoreThoughts`, updated `totalThoughts`
- **Mode**: Complete only
- **Cost Impact**: 0-2 additional ST calls (situational)

**Extension Triggers:**
- Component count > 10
- Unexpected integration points discovered
- Security/compliance requirements more extensive than expected

### MPA (Multi-Perspective Analysis)

Architecture design uses 3 parallel specialist agents:
- Minimal Change approach
- Clean Architecture approach
- Pragmatic Balance approach

### Configuration

All limits, thresholds, and settings are in `config/planning-config.yaml`.

## Agents

### Planning Agents (Phases 2-4)

| Agent | Purpose |
|-------|---------|
| `product-planning:code-explorer` | Codebase patterns and integration points |
| `product-planning:software-architect` | Architecture options and trade-offs |
| `product-planning:tech-lead` | Task breakdown and complexity analysis |
| `product-planning:researcher` | Technology research and unknowns |

### QA Agents (Phase 7 - MPA Pattern)

| Agent | Purpose | Modes |
|-------|---------|-------|
| `product-planning:qa-strategist` | V-Model test strategy, UAT scripts | All |
| `product-planning:qa-security` | Security testing, STRIDE analysis, auth tests | Complete, Advanced |
| `product-planning:qa-performance` | Performance/load testing, latency requirements | Complete, Advanced |

Phase 7 uses MPA (Multi-Perspective Analysis) pattern similar to Phase 4 architecture design.

## Output Artifacts

| Artifact | Content |
|----------|---------|
| `design.md` | Final architecture design |
| `plan.md` | Implementation plan |
| `tasks.md` | Dependency-ordered tasks with TDD structure and test refs |
| `research.md` | Codebase analysis findings |
| `test-plan.md` | V-Model test strategy |
| `test-cases/unit/` | Unit test specifications |
| `test-cases/integration/` | Integration test specs |
| `test-cases/e2e/` | E2E scenario scripts |
| `test-cases/uat/` | UAT scripts (Given-When-Then) |
| `.phase-summaries/*.md` | Inter-phase coordinator summary files |

## File Naming Conventions

- Agents: `agents/{role}.md`
- Skills: `skills/{skill-name}/SKILL.md`
- Reference files: `skills/{skill-name}/references/*.md`
- Templates: `templates/{purpose}.md`
- State: `{FEATURE_DIR}/.planning-state.local.md`

## Plugin Path Variable

Use `$CLAUDE_PLUGIN_ROOT` to reference plugin-relative paths in commands and agents.

## MCP Dependencies

### Core MCP (Optional but recommended)
- `mcp__sequential-thinking__sequentialthinking` - Structured reasoning
- `mcp__pal__thinkdeep` - External model insights
- `mcp__pal__consensus` - Multi-model validation
- `mcp__pal__listmodels` - Model availability check
- `mcp__pal__challenge` - Groupthink detection

### Research MCP (Optional but recommended)
Used in Phases 2, 4, and 7 for authoritative documentation lookup.

| Server | Purpose | Best For |
|--------|---------|----------|
| `mcp__context7__query-docs` | Library documentation | React, Next.js, mainstream libs |
| `mcp__Ref__ref_search_documentation` | Docs with prose | Explanations, niche/private repos |
| `mcp__Ref__ref_read_url` | Read specific URLs | Changelogs, blog posts |
| `mcp__tavily__tavily_search` | Web search | News, CVEs, recent updates |
| `mcp__tavily__tavily_extract` | Extract URL content | Full page extraction |

**Server Selection Decision Tree:**
- Library API (mainstream) → Context7
- Library API (niche/prose needed) → Ref
- Current events/news → Tavily
- Security CVE check → Tavily
- Deep dive specific URL → Ref

**Reference:** `skills/plan/references/research-mcp-patterns.md`

---

## Development Guidelines

### Architecture Decisions

#### Integration over Separation
- **Pattern**: Embed tightly-coupled functionality as phases within a single workflow rather than separate skills
- **Rationale**: Separate skills for coupled workflows create state synchronization issues and user friction
- **Example**: Test planning (Phases 7-8) is embedded in main `/plan` skill, not a separate `/plan-tests`
- **Anti-pattern**: Creating separate skills that share state files and must be run in sequence

#### MPA Pattern Extensibility
- **Pattern**: Apply Multi-Perspective Analysis (MPA) to any phase requiring diverse viewpoints
- **Implementation**: Launch 2-3 specialized agents in parallel, synthesize their outputs
- **Applied to**: Phase 4 (architecture: minimal/clean/pragmatic) and Phase 7 (QA: general/security/performance)
- **Checklist**: When adding MPA, define: agent variants, mode availability, output synthesis rules

#### Lean Orchestrator Delegation
- **Pattern**: Orchestrator dispatches coordinator subagents per phase, reads only summary files between phases
- **Rationale**: Reduces orchestrator context from ~2700 lines to ~590 lines (~78% reduction)
- **Trade-off**: ~5-15s latency overhead per coordinator dispatch
- **Implementation**: Per-phase instruction files in `skills/plan/references/phase-{N}-*.md`, summary files in `{FEATURE_DIR}/.phase-summaries/`
- **Exception**: Phase 1 (inline) and Phase 3 Standard/Rapid (inline) execute in orchestrator context

#### Phase Reconciliation
- **Pattern**: Multi-phase workflows with related analysis need explicit reconciliation steps
- **Example**: Phase 7 reconciles Phase 5 ThinkDeep security insights with test risk analysis
- **Implementation**: Create reconciliation step that maps prior findings to current phase, identifies gaps/conflicts
- **Output**: Reconciliation report showing alignment and flagging unresolved conflicts

### Configuration Management

#### Single Source of Truth
- **Rule**: Configurable values (thresholds, costs, model names) must exist in exactly one place
- **Location**: `config/planning-config.yaml` for this plugin
- **Anti-pattern**: Duplicating values in SKILL.md, CLAUDE.md, and config - causes drift
- **If displaying values**: Reference config file or note "See config for current values"

#### Threshold Semantics
- **Rule**: Always clarify boundary conditions using comparison operators
- **Format**: `GREEN: score >= 16`, `YELLOW: score >= 12 AND score < 16`, `RED: score < 12`
- **Anti-pattern**: Ambiguous statements like "RED <12" with separate `not_ready: 11` field

#### External Model Names
- **Note**: Model identifiers (gpt-5.2, gemini-3-pro-preview) are configurable placeholders
- **Rule**: Document that users should update these to match their PAL/MCP server configurations
- **Location**: Add configuration notes near model definitions

#### Feature Flag Dependencies
- **Rule**: Flags that depend on other flags must declare `requires: [flag_names]`
- **Example**: `s5_tot_architecture.requires: [s4_adaptive_strategy]`
- **Rationale**: Prevents enabling advanced features without prerequisites
- **Validation**: CI should check that required flags are enabled when dependent flag is enabled

### Template Design

#### Glossary Sections
- **Rule**: Templates used by non-technical stakeholders (UAT scripts) must include glossary
- **Content**: Define domain terms (AC, TDD, Given-When-Then, Inner/Outer Loop)
- **Placement**: Appendix section at end of template

#### Template Completeness
- **Checklist for new templates**:
  - [ ] All placeholder sections have example content
  - [ ] Glossary for non-technical users
  - [ ] Evidence/sign-off sections where approval needed
  - [ ] Cross-references to related templates

### Quality Verification

#### Critique-Driven Improvements
When running `/reflexion:critique`, address findings by priority:
1. **Critical**: Duplicate files, missing reconciliation - fix immediately
2. **High**: Inconsistent constants, missing MPA - fix before release
3. **Medium**: Missing glossaries, unclear thresholds - fix in next iteration
4. **Low**: Style inconsistencies - batch fix periodically

#### Common Issues to Check
- [ ] No duplicate reference files across skills
- [ ] All config values sourced from single location
- [ ] MPA agents have mode availability documented
- [ ] Related phases have reconciliation steps
- [ ] Templates have glossaries for non-technical users

#### Post-Refactoring Cross-Reference Validation
After bulk refactoring (e.g., extracting monolithic files into per-phase files):
- [ ] All agent names in SKILL.md dispatch table have corresponding files in `agents/`
- [ ] All template paths referenced in phase files exist in `templates/`
- [ ] All per-phase files referenced in dispatch table exist in `references/`
- [ ] Config feature flags referenced in phase files are defined in `config/planning-config.yaml`
- [ ] No stub markers remain (search for TODO, FIXME, TBD, PLACEHOLDER)
- [ ] `references/README.md` index is updated with new file entries and sizes
- [ ] No cross-plugin file leakage in staged commits (verify with `git diff --cached --stat`)

### Agent Design Standards

#### Anti-Patterns Sections
- **Rule**: Every agent file must have an Anti-Patterns section with domain-specific entries
- **Format**: Table with columns: Anti-Pattern | Why It's Wrong | Instead Do
- **Count**: 3-5 anti-patterns per agent, specific to that agent's domain
- **Example**: Code-explorer anti-patterns differ from judge anti-patterns
- **Placement**: Near end of file, after Self-Critique section

#### Intentional Agent Variance
- **Principle**: Different agent types have different verification requirements
- **Question counts by responsibility**:
  - Architect agents: 6 questions (high stakes, long-term impact)
  - Standard agents: 5 questions (balanced thoroughness)
  - Lightweight/haiku agents: 4 questions (cost-conscious)
- **Documentation**: Variance must be documented in `references/self-critique-template.md`
- **Anti-pattern**: Assuming all agents should have identical self-critique sections

### Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Separate skills for coupled workflows | State sync issues, user must remember sequence | Embed as phases in single workflow |
| Duplicate reference files | Maintenance burden, drift risk | Single copy, reference via `$CLAUDE_PLUGIN_ROOT` |
| Hardcoded values in multiple files | Inconsistency, hard to update | Single source in config file |
| Missing phase reconciliation | Conflicting analysis, coverage gaps | Explicit reconciliation step between related phases |
| Templates without glossary | Non-technical users confused | Add glossary appendix |
| Ambiguous thresholds | Off-by-one errors, unclear logic | Use explicit comparison operators |
| Generic anti-patterns in agents | Not actionable for specific domain | Domain-specific anti-patterns per agent type |
| Uniform agent configurations | Ignores responsibility differences | Calibrate verification to agent impact level |

### Proposal and Documentation Standards

#### Table of Contents Consistency
- **Rule**: TOC section names MUST match body heading names exactly
- **Check**: After writing, compare TOC entries against corresponding body headings
- **Anti-pattern**: TOC says "M1-M5" but body uses "A1-A5"
- **Tool**: Use grep to verify: `grep -E "^##|^\d+\." proposal.md`

#### Cost Comparison Baselines
- **Rule**: When comparing costs, specify exact baseline mode/version
- **Format**: "ToT ($0.38) vs Standard MPA in Complete mode ($0.22)" not "vs ~$0.15"
- **Anti-pattern**: Comparing Complete mode improvement to Standard mode baseline
- **Reason**: Misleading ROI calculations if baselines don't match

#### Acceptance Criteria for Improvements
- **Rule**: Each proposed improvement needs measurable acceptance criteria
- **Format**:
  ```yaml
  improvement: S1 Self-Critique
  acceptance_criteria:
    - Agent prompts include self-critique section
    - Output includes self_critique YAML block
    - Questions passed >= 4/5 for submission
  verification: Automated test or manual checklist
  ```
- **Anti-pattern**: Listing improvements without success conditions

#### Threshold Scales
- **Rule**: Always explain what scale values mean
- **Good**: "Score 1-5 where: 1=missing, 2=incomplete, 3=adequate, 4=good, 5=excellent"
- **Bad**: "Score ≥3.5/5.0" without explaining what 3 or 5 represents
- **Application**: Judge gates, consensus scoring, coverage validation

#### Gap-to-Improvement Traceability
- **Rule**: Each improvement should trace back to identified gaps
- **Format**: "**Gap Addressed:** G1 - Description"
- **Verification**: Matrix showing Gap → Improvement mapping
- **Reason**: Ensures improvements solve real problems, not hypothetical ones

### Research Attribution

#### Academic Citation Standards
- **Rule**: Attribute techniques to correct original papers
- **Chain-of-Verification**: Dhuliawala et al. (2023), NOT Constitutional AI
- **Constitutional AI Self-Critique**: Bai et al. (2022)
- **Zero-Shot CoT**: Kojima et al. (2022)
- **Tree of Thoughts**: Yao et al. (2023)
- **Multi-Agent Debate**: Du et al. (2023)
- **Note**: Constitutional AI and CoVe are related but distinct techniques

### Judge Calibration Methodology

#### Building Effective Judge Prompts
- **Principle**: Judges need calibration examples to score consistently
- **Include in judge prompts**:
  1. Scoring rubric with explicit criteria per level (1-5)
  2. 2-3 calibration examples showing "this is a 3" vs "this is a 5"
  3. Common failure modes to watch for
- **Anti-pattern**: Judge prompts with only criteria, no examples
- **Reference**: Add calibration methodology to `references/judge-gate-rubrics.md`

#### Retry Logic Documentation
- **Rule**: Document retry behavior explicitly
- **Include**:
  - Max retries (e.g., 2)
  - What feedback is provided on failure
  - Escalation path (what happens after max retries)
  - State management during retries

### Reference File Organization

#### Index README Pattern
- **Rule**: Reference directories with 5+ files should have a README.md index
- **Content**: Table showing "File | Read When..." for quick navigation
- **Location**: `skills/{skill}/references/README.md`
- **Benefit**: Reduces time spent finding the right reference file

### Critique Resolution Workflow

#### Priority-Based Implementation
- **Process**: Resolve critique findings in priority order: MUST DO → SHOULD DO → COULD DO
- **Batching**: Group related changes (all config changes together, all agent updates together)
- **Rationale**: Minimizes context switching, ensures critical issues fixed first
- **Verification**: Run verification commands from critique report after each priority tier

### Sequential Thinking Implementation Guidelines

#### MCP Parameter Usage

The ST MCP tool has underutilized parameters that enable advanced reasoning:

| Parameter | Purpose | When to Use |
|-----------|---------|-------------|
| `branchFromThought` | Spawn exploration path from a specific thought | Fork-Join, Red Team branching |
| `branchId` | Name the branch (use descriptive strings: "minimal", "redteam") | Always pair with `branchFromThought` |
| `isRevision` | Mark thought as updating prior conclusion | Reconciliation when new evidence contradicts |
| `revisesThought` | Reference the thought being revised | Always pair with `isRevision: true` |
| `needsMoreThoughts` | Signal chain should extend beyond initial estimate | Complexity exceeds estimate mid-chain |

#### Template JSON Requirements

ST template JSON must include these fields to avoid silent failures:
- **Required**: `thought`, `thoughtNumber`, `totalThoughts`, `nextThoughtNeeded`
- **Recommended**: `hypothesis`, `confidence`
- **For branching**: `branchFromThought`, `branchId`
- **For revision**: `isRevision`, `revisesThought`

#### Branch Traceability Rules

- Use descriptive `branchId` strings ("minimal", "clean", "pragmatic", "redteam") not numeric IDs
- Omit `branchId` in synthesis/join thoughts to signal return to main trunk
- Document branch → thought mapping in template comments

#### Revision vs Extension

| Scenario | Use | Rationale |
|----------|-----|-----------|
| New evidence contradicts prior conclusion | `isRevision: true` | Updates existing analysis |
| Need more analysis depth | `needsMoreThoughts: true` | Extends chain linearly |
| Exploring alternative approach | `branchFromThought` + `branchId` | Parallel exploration |

### Workflow Enhancement Coordination

#### Multi-File Update Order

When implementing workflow enhancements spanning multiple files, update in dependency order:

1. **Templates** (`templates/sequential-thinking-templates.md`) - Define the ST structures
2. **Workflows** (`skills/plan/references/phase-workflows.md`) - Integrate templates into phases
3. **Agents** (`agents/*.md`) - Add ST invocation instructions
4. **Config** (`config/planning-config.yaml`) - Add feature flags and template groups
5. **Documentation** (`SKILL.md`, `CLAUDE.md`) - Update user-facing docs

**Rationale**: Later files reference earlier ones; updating in this order prevents broken references.

#### Feature Flag Best Practices for MCP Enhancements

When adding feature flags for ST/MCP enhancements:

```yaml
st_example_feature:
  enabled: true
  description: "Clear description of what it does"
  rollback: "Set false to disable (describe fallback behavior)"
  modes: [complete, advanced]  # Which modes can use this
  requires_mcp: true           # Always true for ST enhancements
  cost_impact: "+N ST calls (~X% phase increase)"  # Document cost
```

- **Always include `cost_impact`**: Users need this to make informed mode selections
- **Always include `modes`**: Prevents confusion about availability
- **Always include `rollback`**: Documents graceful degradation path

#### Template Group Registration

When adding new ST template groups:

1. Add template definitions to `templates/sequential-thinking-templates.md`
2. Register group in `config/planning-config.yaml` under `sequential_thinking.template_groups`
3. Map to phases in `sequential_thinking.phase_mapping`
4. Link flag to templates in `sequential_thinking.flag_to_templates`
5. Update availability matrix in templates file

---

*Last updated: 2026-02-06 - Added post-refactoring cross-reference validation checklist*
