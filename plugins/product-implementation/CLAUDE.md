# product-implementation CLAUDE.md

Plugin-specific guidance for Claude Code when working in this plugin.

## Plugin Purpose

Configures projects so Claude Code can autonomously implement development plans produced by product-planning. Two complementary skills: **harness** sets up the project environment (knowledge, hooks, progress tracking, evaluation criteria), **implement** provides the session protocol for working within that environment.

## Workflow Chain Position

Product Definition (PRD, spec) → Product Planning (design, plan, tasks, test-plan) → **Product Implementation** (harness setup → implement protocol → autonomous coding sessions)

## Architecture

### Dual-Skill Model (v6.0)

```
┌─────────────────────────────────────────────────┐
│  /product-implementation:harness                 │
│  Configures the project environment once:        │
│  CLAUDE.md, hooks, feature-list.json, eval loop  │
└───────────────────┬─────────────────────────────┘
                    │ produces .harness/ artifacts
                    ▼
┌─────────────────────────────────────────────────┐
│  /product-implementation:implement               │
│  Session protocol — guides each coding session:  │
│  startup → task selection → TDD → review →       │
│  verify → complete → handoff                     │
└─────────────────────────────────────────────────┘
```

### Harness Configurator

`skills/harness/SKILL.md` — three-stage workflow:

1. **Analyze & Interview** — Read plan artifacts, analyze project, detect domain, ask user preferences
2. **Configure Harness** — Generate 7 categories of environment components:
   - Knowledge Store (CLAUDE.md, ARCHITECTURE.md)
   - Enforcement Layer (hooks in settings.json, lint scripts)
   - Evaluation Criteria & Loop (gradable dimensions, evaluator prompt, CLI review, interactive UAT)
   - Progress Tracking (feature-list.json, progress.md, session-startup.md)
   - Tooling Setup (MCP servers, skills, CLI agents)
   - Workflow Guide (sprint contracts, iteration pattern)
   - Compound Learning (learnings.md, injection/gate hooks)
3. **Verify & Hand Off** — Test hooks, present summary, suggest first sprint

### Implement Protocol

`skills/implement/SKILL.md` — session protocol for working inside the harness:

1. **Session startup** — read .harness/ artifacts, verify baseline
2. **Task selection** — next `passes: false` with satisfied dependencies
3. **Sprint contract** — concrete acceptance verification table
4. **TDD cycle** — delegates to `product-implementation:tdd`
5. **Review** — delegates to `product-implementation:code-review` (conditional on review_granularity)
6. **Verify & complete** — delegates to `product-implementation:verification`
7. **Phase boundaries** — eval loop, learning promotion
8. **Session handoff** — progress.md update for next session

### Behavioral Skills

| Skill | Purpose | Invoked by |
|-------|---------|------------|
| `tdd` | RED→GREEN→REFACTOR cycle, anti-rationalizations | Implement step 4 |
| `code-review` | Two-stage review: spec compliance + code quality | Implement step 5 |
| `verification` | Evidence-before-claims gate function | Implement step 6 |

### Agent Assignments

Developer-family agents read `agents/shared/developer-core-instructions.md` for shared engineering process.

| Agent | Domain | Role |
|-------|--------|------|
| `developer` | Generic | Implementation fallback |
| `android-developer` | Android/Kotlin/Compose | Mobile specialist |
| `frontend-developer` | React/Vue/Svelte/Web | Frontend specialist |
| `backend-developer` | API/DB/Server | Backend specialist |
| `debugger` | Cross-domain | Systematic bug diagnosis |
| `test-writer` | Cross-domain | Unit test Red phase |
| `integration-test-writer` | Cross-domain | E2E/integration tests |
| `code-simplifier` | Cross-domain | Post-implementation cleanup |
| `uat-tester` | Mobile/Web | Interactive UAT via MCP |
| `tech-writer` | Cross-domain | Documentation |

### Key Files

**Harness skill:**
- `skills/harness/SKILL.md` — Harness configurator entry point
- `skills/harness/references/harness-components.md` — Templates for 7 harness categories
- `skills/harness/references/evaluation-loop.md` — Evaluation loop protocol
- `skills/harness/references/feature-list-schema.md` — JSON contract schema
- `skills/harness/references/hooks-catalog.md` — Hook catalog
- `skills/harness/references/cli-agents.md` — CLI agent dispatch and UAT layers
- `skills/harness/references/development-protocols.md` — Gate templates, SessionStart content

**Implement skill:**
- `skills/implement/SKILL.md` — Session protocol

**Behavioral skills:**
- `skills/tdd/SKILL.md` — TDD enforcement
- `skills/code-review/SKILL.md` — Two-stage code review
- `skills/verification/SKILL.md` — Verification gate

**Shared agent reference:**
- `agents/shared/developer-core-instructions.md` — Core engineering process for developer-family agents

### Required Input Artifacts

The harness expects these files in the feature directory (produced by product-planning):
- `tasks.md` (required) — phased task list with acceptance criteria
- `plan.md` (required) — implementation plan
- `design.md`, `test-plan.md` (optional — richer context)
- `test-cases/` (optional) — test specifications by level

## Dev-Skills Integration

Vertical developer agents use domain-specific skills via progressive disclosure — skills are baked into agent `.md` files, not injected at runtime.

### Key Constraints

- **Progressive disclosure** — agents read skill SKILL.md files in 2 phases: first 50 lines for decision framework, then grep for specific sections on-demand
- **Shared core** — all developer-family agents read `agents/shared/developer-core-instructions.md`
- **Codebase conventions take precedence** — CLAUDE.md and constitution.md override skill guidance
- **Graceful degradation** — if dev-skills not installed, agents proceed without domain skills

## Development Notes

- Cross-plugin naming: product-planning produces `contract.md` (singular), `test-cases/uat/` (not `visual/`), and test IDs like `E2E-*`, `INT-*`, `UT-*`, `UAT-*` — always verify against the source plugin before adding new artifact references
- The harness generates CLI instruction files (AGENTS.md, GEMINI.md), review scripts, and UAT dispatch scripts directly in the target project — no plugin-side config files needed
- `/product-implementation:ralph-implement` validates the harness exists, then loops the implement skill via ralph for autonomous execution
