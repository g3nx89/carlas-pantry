---
name: harness
description: >-
  Set up a project's Claude Code harness so it can autonomously implement a development plan
  across multiple sessions. Takes tasks.md and plan.md (from product-planning) and configures:
  CLAUDE.md with build commands, hooks in settings.json, feature-list.json for progress
  tracking, evaluation criteria, session startup checklists, and external CLI review scripts
  (Codex/Gemini). Use when the user wants to start implementing a planned feature, configure
  a project for autonomous coding, set up hooks and progress tracking, prepare for long-running
  agent work, or set up the evaluation loop with external reviewers. Also trigger when the user
  has tasks.md/plan.md ready and wants to start coding. Do NOT trigger for actual code
  implementation, creating plans, or reviewing PRs.
---

# Harness Configurator

Set up a project so Claude Code can autonomously implement a development plan across sessions.
Instead of scripting every agent decision, invest complexity in the *environment* — knowledge,
enforcement, progress tracking, evaluation, tooling — so the model reasons freely within
well-designed constraints.

## Core Principles

These come from harness engineering research and are the foundation for every decision:

1. **Map, Not Manual** — CLAUDE.md is a table of contents (~100 lines), not an encyclopedia.
   Point to `docs/` for depth. The agent finds what it needs via progressive disclosure.

2. **Enforce Invariants, Not Implementations** — Hooks and lints constrain *what must be true*
   (tests pass, specs untouched, builds succeed). The model decides *how* to get there.

3. **JSON Contracts Over Markdown** — Feature lists as JSON with immutable descriptions and
   mutable `passes` field. Models are less likely to inappropriately modify JSON than Markdown.

4. **Generator ≠ Evaluator** — The agent building code should not be the sole judge of its
   quality. Set up separate evaluation criteria with concrete, gradable dimensions.

5. **Context Resets Over Compaction** — Default to fresh sessions with structured handoff.
   Progress files and git history bridge the gap. Note: this is model-dependent — newer
   models with large context windows may work well with compaction (summarizing in-place).
   If the model supports long coherent sessions, sprints can span multiple features.

## Prerequisites

Plan artifacts from product-planning (in a feature directory):
- `tasks.md` (required) — phased task list with acceptance criteria
- `plan.md` (required) — architecture decisions and implementation approach
- `design.md`, `test-plan.md`, `test-cases/` (optional) — richer context

## Stage 1: Analyze & Interview

### 1a. Read the Plan

Load `tasks.md` and `plan.md`. Extract: phase count, task breakdown, tech stack, frameworks,
test strategy, architectural constraints, external dependencies.

### 1b. Analyze the Project

Examine the target project directory:

| Check | What to Look For |
|-------|-----------------|
| CLAUDE.md | Existing guidance — augment, don't replace |
| .claude/settings.json | Current hooks, permissions, allowed tools |
| Build system | package.json, build.gradle, Makefile, Cargo.toml, etc. |
| Test setup | Test runner, coverage config, existing test files |
| Git state | Clean working tree? On a feature branch? |
| MCP servers — UAT | Probe for Playwright MCP (web) and mobile-mcp (mobile) — primary interactive UAT tools |
| MCP servers — Figma | Probe for figma-console and figma-desktop — mandatory visual parity checks |
| Maestro CLI | Check for `maestro` CLI (`command -v maestro`) — scripted mobile regression |
| Maestro MCP | Probe for Maestro MCP server if registered — enables hybrid CLI+MCP workflows |
| Missing tool prompting | If mandatory tools are absent, generate install checklist (see `cli-agents.md` Section 3a) |
| CLI agents | Check for `codex`, `gemini` CLIs (`command -v`) |
| Codex plugin | Check if `codex-plugin-cc` is installed (enables `/codex:*` commands) |
| Installed skills | Check what Claude Code skills are already available |
| Architecture boundaries | Layer structure from plan.md, import patterns, naming conventions |

### 1c. Interview the User

Ask only what you can't infer from the plan or project. Skip questions where context gives
a clear answer. Present remaining questions together, not one-by-one.

| Question | Determines |
|----------|-----------|
| Quality bar: fast iteration / balanced / thorough? | Hook strictness, review frequency, eval thresholds |
| Autonomy: commit freely / ask before commits / human reviews? | Auto-commit hooks, push permissions, PR workflow |
| Protected paths: files or dirs Claude must never modify? | Spec-protection hooks |
| Definition of done: tests pass / reviewed / deployed? | Evaluation criteria, completion checklist |
| Review strategy: self-review / agent review / human PRs? | Evaluator setup, review hooks |
| Evaluation loop: code review only / interactive UAT / both? | Evaluation loop depth, tool requirements |
| Compound learning: off / on (commit-gated)? | Learnings capture, session injection, promotion hooks |

**Quality bar resolves to 4 dimensions** (user can override individually):

| Dimension | fast | balanced | thorough |
|-----------|------|----------|----------|
| `tdd_enforcement` | off | advisory | strict |
| `review_granularity` | per-sprint | per-phase | per-task |
| `test_delta_gate` | off | warning | blocking |
| `anti_rationalizations` | none | meta-warning | full |

Store resolved dimensions in `analysis.json` under `quality_dimensions`. If the user
specifies overrides (e.g., "thorough but review only per-sprint"), record them under
`quality_dimensions.overrides` and compute the resolved values.

### 1d. Save Analysis

Write `{feature_dir}/.harness/analysis.json` with all findings and preferences.
This file is the context bus — all Stage 2 decisions reference it.

## Stage 2: Configure Harness

Read `$CLAUDE_PLUGIN_ROOT/skills/harness/references/harness-components.md` for templates and
detailed guidance per category. Below is the overview of what each category produces and why.

### 2a. Knowledge Store — "Give a Map, Not a Manual"

Augment the project's CLAUDE.md with a lean section (~100 lines) covering build/test/run
commands, architecture overview pointing to `docs/ARCHITECTURE.md`, key conventions, and
common pitfalls. Also generate `docs/ARCHITECTURE.md` from plan.md if not present.

The agent can only act on what it sees in-repo. If build commands live in a wiki or README
the agent might not read, it will guess wrong.

### 2b. Enforcement Layer — "Enforce Invariants"

Configure hooks in `.claude/settings.json` and generate lint scripts in `.claude/scripts/`.
Read `$CLAUDE_PLUGIN_ROOT/skills/harness/references/hooks-catalog.md` for the full catalog.

Hooks catch mistakes mechanically at the moment they happen, without consuming context or
relying on the model to remember rules.

### 2c. Evaluation Criteria & Loop — "Generator ≠ Evaluator"

Generate `{feature_dir}/.harness/eval-criteria.md` with 3-5 gradable quality dimensions,
scoring rubric (1-5 with examples), per-criterion hard thresholds (any single FAIL blocks),
few-shot calibration examples, and an evaluator session prompt.

Without explicit criteria, the builder agent will "confidently praise its own work — even
when the quality is obviously mediocre."

**Evaluation Loop (opt-in):** If the project has a runnable UI and appropriate MCP tools
(Playwright for web, mobile-mcp for mobile), also configure the evaluation loop — where
a separate evaluator session interacts with the RUNNING application as a user would.
Read `$CLAUDE_PLUGIN_ROOT/skills/harness/references/evaluation-loop.md` for the full
protocol: sprint contract negotiation, evaluator prompt template, feedback report format,
and multi-round build→QA cycles.

**UAT four-layer mandatory architecture:** Read `$CLAUDE_PLUGIN_ROOT/skills/harness/references/cli-agents.md`
Section 3 for the full UAT configuration:
- **Maestro scripted regression** — For mobile projects, generate YAML E2E flows from
  sprint contract. Runs as session-startup smoke gate (zero Claude tokens). Section 3e.
  Also see `evaluation-loop.md` Section 2f.
- **Native MCP UAT (primary)** — Playwright for web, mobile-mcp for mobile. Real-time
  interaction with the running app. If tools are missing, generate install prompts
  (Section 3a).
- **Figma visual parity (mandatory)** — Compare implementation against Figma designs
  using `figma_check_design_parity` or `figma_capture_screenshot` (Section 3c). Failures
  are blocking. Also see `evaluation-loop.md` Section 2e.
- **CLI evidence review** — Codex/Gemini review captured evidence for independent second
  opinion (Section 3d). External agents provide genuinely different model perspective.

**Project-specific adaptations:** The reference templates are starting points. Research
the project's tech stack, existing tests, and quality standards to produce evaluation
criteria, testing procedures, and sprint contract criteria that feel custom-built for the
project — not a generic template with swapped names. See `evaluation-loop.md` Section 8.

### 2d. Progress Tracking — "Bridge Context Gaps"

Convert `tasks.md` → `feature-list.json` using the schema in
`$CLAUDE_PLUGIN_ROOT/skills/harness/references/feature-list-schema.md`. Also generate
`progress.md` template, `session-startup.md` checklist, and `quality-score.json` for
cross-session health tracking.

Each new session starts with zero memory. Progress files and JSON contracts let the agent
pick up exactly where the last session left off. The quality score tracks project health
trends across sessions — declining dimensions get addressed before new features.

### 2e. Tooling Setup — "Environment Design"

Recommend MCP servers and Claude Code skills based on project domain, verify build/test
commands work, configure `.claude/settings.json` tool permissions. If CLI agents are
available, generate `AGENTS.md` (Codex) and/or `GEMINI.md` with project-specific context.

**agnix linter:** If `agnix` is available (`command -v agnix`), generate a `.agnix.toml`
config at the project root. This enables agnix as a permanent quality gate for all agent
config files the harness produces. Example:

```toml
severity = "Warning"
tools = ["claude-code"]

[rules]
disabled_rules = ["XP-003"]
```

The right tools reduce friction dramatically — a Playwright MCP turns browser testing from
impossible to trivial. External CLI agents turn code review from self-assessment to
independent evaluation. agnix catches broken hook events, malformed frontmatter, and prompt
anti-patterns before they silently degrade agent behavior.

### 2f. Workflow Guide — "Humans Steer, Agents Execute"

Create sprint contract template, recommend iteration pattern (one feature at a time, verify,
commit, next), and document entropy management cadence.

The agent needs to know HOW to work, not just WHAT to build.

### 2g. Compound Learning — "What We Learned Stays Learned"

If enabled, configure the compound learning layer: a SessionStart hook that injects all
accumulated learnings, a commit-gate hook that enforces capture, and a phase-boundary
promotion protocol. Also generate the initial `learnings.md` template and augment
CLAUDE.md with the compound learning protocol section.

Implementation knowledge compounds across sessions instead of being rediscovered.

## Stage 3: Verify & Hand Off

1. **Verify files**: Check all generated artifacts exist and are syntactically valid
2. **Lint with agnix**: If `agnix` is available (`command -v agnix`), run
   `agnix --target claude-code --format json {project}` and fix any errors in the generated
   artifacts (CLAUDE.md, settings.json hooks, SKILL.md files, agent files). Warnings for
   `.claude/` path references (XP-003) are expected and can be ignored — the harness
   intentionally configures these paths. Fix all errors before proceeding.
3. **Test hooks**: Run each configured hook once to confirm it works
4. **Present summary**: List everything configured with file paths and brief explanations
5. **Suggest first sprint**: Recommend which task to start with, based on dependency order
6. **Demo session startup**: Walk through how a new coding session should begin

## Output Artifacts

| Artifact | Location | Purpose |
|----------|----------|---------|
| Analysis | `{feature_dir}/.harness/analysis.json` | Context bus for configuration decisions |
| CLAUDE.md | `{project}/CLAUDE.md` | Knowledge map — commands, architecture, conventions |
| Architecture | `{project}/docs/ARCHITECTURE.md` | System of record for design decisions |
| Hooks | `{project}/.claude/settings.json` | Mechanical enforcement layer |
| Lint scripts | `{project}/.claude/scripts/` | Custom checks with remediation instructions |
| Eval criteria | `{feature_dir}/.harness/eval-criteria.md` | Gradable dimensions, weights, 3-tier thresholds |
| Feature list | `{feature_dir}/.harness/feature-list.json` | JSON contract — immutable descriptions, mutable passes |
| Progress | `{feature_dir}/.harness/progress.md` | Cross-session handoff state |
| Quality score | `{feature_dir}/.harness/quality-score.json` | Project health dimensions with trend tracking |
| Last cleanup | `{feature_dir}/.harness/last-cleanup.json` | Entropy management checkpoint tracker |
| Session startup | `{feature_dir}/.harness/session-startup.md` | Unified new-session checklist (all conditional steps) |
| Sprint contract | `{feature_dir}/.harness/sprint-contract.md` | What "done" means — verification table + DoD |
| Review script | `{project}/.claude/scripts/external-review.sh` | Dispatch review to Codex/Gemini (if available) |
| Evaluator prompt | `{feature_dir}/.harness/evaluator-prompt.md` | Calibrated QA session prompt (if eval loop enabled) |
| Report template | `{feature_dir}/.harness/evaluation-report-template.md` | Structured feedback format (if eval loop enabled) |
| Eval reports dir | `{feature_dir}/.harness/eval-reports/` | Timestamped evaluation reports (if eval loop enabled) |
| Tuning log | `{feature_dir}/.harness/evaluator-tuning-log.md` | Evaluator calibration observations (if eval loop) |
| App launch | `{project}/.claude/scripts/launch-app.sh` | Start dev server + readiness check (if eval loop enabled) |
| UAT dispatch | `{project}/.claude/scripts/uat-dispatch.sh` | CLI evidence review dispatch to Codex/Gemini (complement to native MCP UAT) |
| Visual parity | `analysis.json → visual_parity` | Screen-to-frame map, parity method, threshold (mandatory for UI projects) |
| Maestro workspace | `{project}/.maestro/config.yaml` + `flows/` | YAML E2E flows, workspace config (if Maestro available + mobile) |
| Maestro config | `analysis.json → maestro` | Flow dirs, smoke tags, app ID, session-startup gate config |
| AGENTS.md | `{project}/AGENTS.md` | Codex instruction file (if available) |
| GEMINI.md | `{project}/GEMINI.md` | Gemini instruction file (if available) |
| Learnings | `{feature_dir}/.harness/learnings.md` | Append-only implementation knowledge (if compound enabled) |
| Promotion tracker | `{feature_dir}/.harness/last-promotion.txt` | Phase-boundary promotion state (if compound enabled) |
| Compound inject | `{project}/.claude/scripts/compound-inject.sh` | SessionStart hook — inject learnings + detect phases (if compound enabled) |
| Compound gate | `{project}/.claude/scripts/compound-gate.sh` | Commit gate — enforce learnings capture (if compound enabled) |
| Task state | `{feature_dir}/.harness/task-state.json` | Review state machine (if review_granularity == per-task) |
| Review artifacts | `{feature_dir}/.harness/reviews/` | Spec + quality review JSON per task/phase |
| Protocol injection | `{project}/.claude/scripts/inject-protocols.sh` | SessionStart behavioral summary |
| Test delta gate | `{project}/.claude/scripts/verify-test-delta.sh` | Commit gate for test completeness (if test_delta_gate != off) |
| State-aware commit | `{project}/.claude/scripts/gate-commit-on-state.sh` | Enhanced commit gate with state check (if review_granularity == per-task) |
| Evidence gate | `{project}/.claude/scripts/gate-feature-list-on-state.sh` | Feature-list edit gate (if review_granularity != per-sprint) |

## Reference Map

| File | ~Lines | Purpose | Read When |
|------|--------|---------|-----------|
| `harness-components.md` | ~878 | Templates for all 7 categories + quality score + entropy + compound learning | Stage 2 — section for the category being configured |
| `evaluation-loop.md` | ~615 | Eval loop: UAT, Maestro regression, Figma visual parity, feedback, stop gate | Stage 2c — when configuring interactive evaluation |
| `feature-list-schema.md` | ~116 | JSON schema, tasks.md conversion, examples, phase boundary detection | Stage 2d/2g — converting the plan to JSON contract, phase boundary |
| `hooks-catalog.md` | ~595 | Hook catalog: essential, architecture guards, entropy, compound learning, custom | Stage 2b/2g — choosing which hooks to install |
| `cli-agents.md` | ~1122 | 4-layer UAT: Maestro, native MCP, Figma parity, CLI review + Codex Plugin, stop gate | Stage 2c/2e — all UAT tools, Figma parity, CLI agents |
| `README.md` | ~66 | Reference index with deduplication notes | As needed |
| `development-protocols.md` | ~590 | Gate script templates, SessionStart content, task-state schema, quality dimensions | Stage 2b/2d/2f — when generating protocol gates and SessionStart hook |
