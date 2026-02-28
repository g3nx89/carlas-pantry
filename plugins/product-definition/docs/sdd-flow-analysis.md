# SDD Flow Analysis — Artifact Map & User Review Points

> **Version:** 1.0.0
> **Date:** 2026-02-28
> **Scope:** design-handoff, refinement, specify, plan, implement
> **Purpose:** Map cross-skill artifact handoffs, identify user review bottlenecks, and guide convergence

---

## Table of Contents

1. [Flow Overview](#1-flow-overview)
2. [Cross-Boundary Passport Files](#2-cross-boundary-passport-files)
3. [Per-Skill File Volume](#3-per-skill-file-volume)
4. [Injection Matrix](#4-injection-matrix)
5. [User Review Classification](#5-user-review-classification)
6. [Top 5 Convergence Checkpoints](#6-top-5-convergence-checkpoints)
7. [Per-Skill Detailed I/O](#7-per-skill-detailed-io)
8. [Observations & Simplification Opportunities](#8-observations--simplification-opportunities)

---

## 1. Flow Overview

The SDD pipeline is a 5-skill cascade where each skill produces artifacts consumed by the next:

```
design-handoff ──→ refinement ──→ specify ──→ plan ──→ implement
    (Figma)          (PRD)         (Spec)     (Arch)    (Code)
```

**Key principle:** Only a small subset of files ("passport files") cross skill boundaries. The vast majority of generated files are internal to each skill (state, summaries, analysis reports, judge verdicts). Identifying the passport files is the lever for simplification.

---

## 2. Cross-Boundary Passport Files

These are the ONLY files that cross from one skill to the next:

```
┌─────────────────┐
│  design-handoff  │
└────────┬────────┘
         │  HANDOFF-SUPPLEMENT.md        ──→ specify (design context)
         │  handoff-manifest.md          ──→ specify (screen inventory)
         │  figma-screen-briefs/FSB-*.md ──→ specify (per-screen briefs)
         │
┌────────▼────────┐
│   refinement     │
└────────┬────────┘
         │  PRD.md                       ──→ specify (product requirements)
         │  decision-log.md              ──→ specify (decision traceability)
         │
┌────────▼────────┐
│    specify       │
└────────┬────────┘
         │  spec.md                      ──→ plan    (REQUIRED)
         │  design-brief.md              ──→ plan    (visual context)
         │  design-supplement.md         ──→ plan    (visual specs)
         │  rtm.md                       ──→ plan    (requirements traceability)
         │  test-strategy.md              ──→ plan    (test strategy)
         │
┌────────▼────────┐
│     plan         │
└────────┬────────┘
         │  tasks.md                     ──→ implement (REQUIRED)
         │  plan.md                      ──→ implement (REQUIRED)
         │  design.md                    ──→ implement (architecture)
         │  test-plan.md                 ──→ implement (V-Model test plan)
         │  test-cases/{unit,int,e2e,uat}/ ──→ implement (test specs)
         │  contract.md                  ──→ implement (API contracts)
         │  data-model.md               ──→ implement (data model)
         │  research.md                  ──→ implement (tech context)
         │
┌────────▼────────┐
│   implement      │
└────────┬────────┘
         │  Source code, tests, docs, retrospective.md
         ▼
```

**Total passport files: ~18** out of ~90+ total files in the pipeline.

---

## 3. Per-Skill File Volume

| Skill | Passport files (output → next) | Internal files (state, analysis, summaries) | Total |
|-------|-------------------------------:|-------------------------------------------:|------:|
| **design-handoff** | 3 | ~15+ (state, lock, inventory, gap-report, screenshots, judge verdicts, FSBs) | ~18+ |
| **refinement** | 2 | ~12+ (state, lock, QUESTIONS-NNN, thinkdeep-insights, stage summaries, rounds-digest, reflection) | ~14+ |
| **specify** | 5 | ~15+ (state, lock, checklist, clarification-questions, clarification-report, MPA reports, figma_context, stage summaries) | ~20+ |
| **plan** | 8 | ~15+ (state, lock, phase summaries, design perspectives, CLI reports, skill-context, requirements-anchor) | ~23+ |
| **implement** | 3 | ~12+ (state, lock, stage summaries, review-findings, report-card, transcript-extract, UAT evidence) | ~15+ |
| **TOTAL** | **~21** | **~69+** | **~90+** |

> ~77% of all generated files are internal to each skill and never cross boundaries.

---

## 4. Injection Matrix

What each skill requires from the user and from previous skills:

```
                     design-    refine-
                     handoff    ment     specify    plan      implement
                     ─────────  ───────  ────────   ────────  ──────────
FROM USER:
  Figma page         ●
  Draft file                    ●
  Feature desc                           ●
  Q&A responses                 ●        ●
  Arch selection                                    ●

FROM PREV SKILL:
  HANDOFF-SUPPLEMENT                     ○
  handoff-manifest                       ○
  FSB files                              ○
  PRD.md                                 ○
  spec.md                                           ●(REQ)   ○
  design-brief.md                                   ○
  design-supplement                                 ○
  rtm.md                                            ○
  test-strategy.md                                   ○        ○
  test-plan.md                                                ○
  plan.md                                                     ●(REQ)
  tasks.md                                                    ●(REQ)
  design.md                                                   ○
  test-cases/                                                 ○
  contract.md                                                 ○
  data-model.md                                               ○
  research.md                                                 ○

● = Required   ○ = Optional/Conditional
```

### Required (halt if missing)

| Transition | Required File | Error Behavior |
|-----------|---------------|----------------|
| specify → plan | `spec.md` | Phase 1 errors with guidance to run `/specify` first |
| plan → implement | `tasks.md` | Stage 1 halts with guidance to run `/plan` first |
| plan → implement | `plan.md` | Stage 1 halts with guidance to run `/plan` first |

### Expected (warn if missing, continue)

| Transition | File | Warning |
|-----------|------|---------|
| plan → implement | `design.md` | "developer agents will rely on plan.md only for architecture context" |
| plan → implement | `test-plan.md` | "TDD will proceed without a V-Model test strategy document" |

---

## 5. User Review Classification

### TIER 1 — Blocking, high-impact on direction (MUST REVIEW)

These files, if not carefully reviewed, cause the entire downstream flow to diverge:

| File | Skill | Stage | Why Critical | Downstream Impact |
|------|-------|-------|-------------|-------------------|
| **`QUESTIONS-{NNN}.md`** | refinement | 3→4 | User answers determine PRD content. Superficial answers → vague PRD → vague spec → vague plan → wrong code | **4 skills downstream** |
| **`spec.md`** | specify | 2+ | Only REQUIRED file for `plan`. Errors here propagate into architecture, tests, tasks, and code. It's the "contract" for the entire downstream flow | **2 skills downstream** |
| **`clarification-questions.md`** | specify | 4 | Answers refine spec.md. Unanswered questions = `[NEEDS CLARIFICATION]` markers that remain in the spec and degrade downstream quality | **2 skills downstream** |
| **`tasks.md`** | plan | 9 | Only REQUIRED file for `implement` (with plan.md). Poorly defined tasks → out-of-scope implementation | **1 skill downstream** |
| **`design.md`** + perspective selection | plan | 4 | User chooses between 3 architecture perspectives (grounding/ideality/resilience). Wrong choice = unsuitable architecture. No automatic recovery | **1 skill downstream** |

### TIER 2 — Important for quality, non-blocking

| File | Skill | Stage | Why Important |
|------|-------|-------|--------------|
| **`PRD.md`** | refinement | 5 | Final deliverable; if not reviewed, product requirements may be incomplete when passed to specify |
| **`REQUIREMENTS-INVENTORY.md`** | specify | 1 | If RTM enabled, user must confirm extracted requirements. Missing requirements = incomplete RTM coverage |
| **`rtm.md`** | specify | 2, 4 | UNMAPPED dispositions block the Stage 4→5 gate. User must resolve every untraced requirement |
| **`design-supplement.md`** | specify | 5 | Visual specs for screens not in Figma. If inaccurate, developers will implement wrong UI |
| **`plan.md`** | plan | 6 | Validated by Phase 6 gate. If YELLOW/RED, user can accept or retry |
| **`test-plan.md`** | plan | 8 | Validated by Phase 8 gate. Test coverage gaps → missing tests in implement |

### TIER 3 — Informational / optional

| File | Skill | Note |
|------|-------|------|
| Screen inventory + TIER approval (Stage 1) | design-handoff | Initial approval — errors are recoverable |
| Gap report answers (Stage 4) | design-handoff | Behavior/transition questions for the supplement |
| Missing screen decisions (Stage 3.5) | design-handoff | Create/manual/doc/skip per missing screen |
| `review-findings.md` | implement | Blocks only if CRITICAL findings exist |
| `test-cases/uat/` | plan | UAT scripts for Product Owner sign-off |
| `retrospective.md` | implement | Purely informational — no flow impact |
| `decision-log.md` | refinement | Traceability audit — informational |
| `completion-report.md` | refinement | Workflow metrics summary |

---

## 6. Top 5 Convergence Checkpoints

Ranked by **multiplier effect** — how many downstream skills are affected by poor review:

### 1. `QUESTIONS-{NNN}.md` (refinement, Stage 3→4)

- **Multiplier:** 4 skills downstream (specify → plan → implement → code)
- **Format:** Markdown with checkboxes — user marks `[x]` for selected option or writes custom text
- **Rule:** 100% completion required — no skipping
- **Risk:** Superficial answers produce a vague PRD, which cascades into vague spec, vague architecture, and wrong code
- **Recommendation:** Spend the most review time here. Each answer shapes the entire product definition

### 2. `spec.md` (specify, Stage 2+)

- **Multiplier:** 2 skills downstream (plan → implement)
- **Format:** Structured markdown with user stories, acceptance criteria, NFRs
- **Rule:** REQUIRED input for plan — halts if missing
- **Risk:** An imprecise spec is irreversible without re-running specify. Every phase of plan and every stage of implement reads this file
- **Recommendation:** Review after Stage 3 checklist validation and again after Stage 4 clarification answers are integrated

### 3. `clarification-questions.md` (specify, Stage 4)

- **Multiplier:** 2 skills downstream (plan → implement, via spec.md updates)
- **Format:** File-based Q&A with BA recommendations
- **Rule:** User MUST answer ALL questions — workflow pauses until complete
- **Risk:** Vague answers leave `[NEEDS CLARIFICATION]` markers in spec.md that degrade downstream quality
- **Recommendation:** Treat like QUESTIONS files in refinement — no shortcuts

### 4. `design.md` + architecture perspective selection (plan, Phase 4)

- **Multiplier:** 1 skill downstream (implement)
- **Format:** User selects between 3 architecture perspectives via AskUserQuestion
- **Rule:** Selection is immutable once recorded in state
- **Risk:** Wrong architectural choice = unsuitable foundation for the entire implementation. No automatic recovery
- **Recommendation:** Read all 3 perspective files (`design.grounding.md`, `design.ideality.md`, `design.resilience.md`) before selecting

### 5. `tasks.md` (plan, Phase 9)

- **Multiplier:** 1 skill downstream (implement)
- **Format:** Dependency-ordered task list with TDD structure
- **Rule:** REQUIRED input for implement — halts if missing
- **Risk:** Missing or poorly defined tasks = incomplete features, wrong implementation order
- **Recommendation:** Verify task completeness against spec.md acceptance criteria and test-plan.md coverage

---

## 7. Per-Skill Detailed I/O

### 7.1 design-handoff

**Invocation:** `/handoff`

**User inputs:**
- Figma page selection (via figma_get_selection)
- Screen inventory approval (Stage 1)
- Missing screen decisions (Stage 3.5, conditional)
- Gap report answers (Stage 4)

**Internal stages:** 1 → 2 → 2J → 3 → 3J → [3.5 → 3.5J] → 4 → 5 → 5J

**Quality gates:** 4 LLM-as-judge checkpoints (2J, 3J, 3.5J, 5J) — self-corrective

**Passport outputs:**

| File | Path | Consumer |
|------|------|----------|
| HANDOFF-SUPPLEMENT.md | `design-handoff/HANDOFF-SUPPLEMENT.md` | specify (optional) |
| handoff-manifest.md | `design-handoff/handoff-manifest.md` | specify (optional) |
| Figma screen briefs | `design-handoff/figma-screen-briefs/FSB-*.md` | specify (optional) |

**Internal files (not passed downstream):**

| File | Purpose |
|------|---------|
| `.handoff-state.local.md` | Workflow state, per-screen progress, judge verdicts |
| `.handoff-lock` | Concurrency lock (60 min stale timeout) |
| `.screen-inventory.md` | Raw scanner output |
| `gap-report.md` | Per-screen gaps, consumed by Stage 4 dialog |
| `screenshots/*-{before,after}.png` | Visual diff evidence |

---

### 7.2 refinement

**Invocation:** `/refine`

**User inputs:**
- Draft file in `requirements/draft/`
- Analysis mode selection (complete/advanced/standard/rapid)
- Research decision (conduct/skip)
- Question responses in `requirements/working/QUESTIONS-{NNN}.md`

**Internal stages:** 1 (Setup) → 2 (Research) → 3 (Analysis & Questions) → 4 (Response & Gaps) → 5 (Validation & PRD) → 6 (Completion)

**Iteration loop:** Stage 3 ↔ Stage 4 ↔ Stage 5 (RED validation loops back to Stage 3)

**Passport outputs:**

| File | Path | Consumer |
|------|------|----------|
| PRD.md | `requirements/PRD.md` | specify (optional) |
| decision-log.md | `requirements/decision-log.md` | specify (optional, traceability) |

**Internal files (not passed downstream):**

| File | Purpose |
|------|---------|
| `.requirements-state.local.md` | Workflow state, round tracking, MCP availability |
| `.requirements-lock` | Concurrency lock |
| `working/QUESTIONS-{NNN}.md` | Per-round question files (user-facing) |
| `analysis/thinkdeep-insights.md` | PAL ThinkDeep synthesis |
| `analysis/questions-{product-strategy,user-experience,business-ops}.md` | Per-agent MPA outputs (merged into QUESTIONS) |
| `analysis/response-validation-round-{N}.md` | PAL Consensus findings |
| `research/RESEARCH-AGENDA.md` | Research topics for user |
| `research/research-synthesis.md` | Synthesized research findings |
| `.stage-summaries/stage-{N}-summary.md` | Coordinator output contracts |
| `.stage-summaries/rounds-digest.md` | Compacted multi-round context |
| `.stage-summaries/reflection-round-{N}.md` | RED loop guidance |
| `completion-report.md` | Final metrics |

---

### 7.3 specify

**Invocation:** `/specify`

**User inputs:**
- Natural language feature description (`$ARGUMENTS`)
- RTM confirmation (if enabled)
- Figma integration decision (if available)
- Platform type selection
- Clarification question answers in `clarification-questions.md`

**Internal stages:** 1 (Setup) → 2 (Spec Draft) → 3 (Checklist Validation) → 4 (Clarification) → 5 (CLI Validation & Design) → 6 (Test Strategy) → 7 (Completion)

**Iteration loop:** Stage 3 ↔ Stage 4 (while coverage < 85%)

**Passport outputs:**

| File | Path | Consumer |
|------|------|----------|
| spec.md | `specs/{FEATURE_DIR}/spec.md` | plan (REQUIRED) |
| design-brief.md | `specs/{FEATURE_DIR}/design-brief.md` | plan (optional) |
| design-supplement.md | `specs/{FEATURE_DIR}/design-supplement.md` | plan (optional) |
| rtm.md | `specs/{FEATURE_DIR}/rtm.md` | plan (optional, if RTM enabled) |
| test-strategy.md | `specs/{FEATURE_DIR}/test-strategy.md` | plan (optional, if test strategy enabled) |

**Internal files (not passed downstream):**

| File | Purpose |
|------|---------|
| `.specify-state.local.md` | Workflow state (v5 schema), RTM tracking, MCP availability |
| `.specify.lock` | Concurrency lock |
| `spec-checklist.md` | Coverage validation (platform-specific) |
| `clarification-questions.md` | Offline Q&A file (user-facing) |
| `clarification-report.md` | Auto-resolve audit trail |
| `REQUIREMENTS-INVENTORY.md` | Extracted requirements (if RTM enabled, user-facing) |
| `figma_context.md` | Figma connection context |
| `analysis/mpa-challenge-*.md` | CLI tri-model challenge reports |
| `analysis/mpa-edgecases-*.md` | CLI edge case reports |
| `analysis/mpa-triangulation.md` | CLI cross-validation |
| `analysis/mpa-evaluation.md` | CLI multi-stance evaluation |
| `.stage-summaries/stage-{N}-summary.md` | Coordinator output contracts |

---

### 7.4 plan

**Invocation:** `/plan`

**User inputs:**
- Analysis mode selection (complete/advanced/standard/rapid)
- Clarification question answers (Phase 3, via AskUserQuestion)
- Architecture perspective selection (Phase 4)
- Validation gate accept/retry decisions (Phases 6, 8)

**Internal phases:** 1 (Setup) → 2 (Research) → 3 (Clarification) → 4 (Architecture) → 5 (Deep Analysis) → 6 (Plan Validation) → 6b (Expert Review) → 7 (Test Strategy) → 8 (Test Coverage Validation) → 8b (Asset Consolidation) → 9 (Task Generation)

**Passport outputs:**

| File | Path | Consumer |
|------|------|----------|
| tasks.md | `{FEATURE_DIR}/tasks.md` | implement (REQUIRED) |
| plan.md | `{FEATURE_DIR}/plan.md` | implement (REQUIRED) |
| design.md | `{FEATURE_DIR}/design.md` | implement (expected) |
| test-plan.md | `{FEATURE_DIR}/test-plan.md` | implement (expected) |
| test-cases/unit/ | `{FEATURE_DIR}/test-cases/unit/` | implement (optional) |
| test-cases/integration/ | `{FEATURE_DIR}/test-cases/integration/` | implement (optional) |
| test-cases/e2e/ | `{FEATURE_DIR}/test-cases/e2e/` | implement (optional) |
| test-cases/uat/ | `{FEATURE_DIR}/test-cases/uat/` | implement (optional) |
| contract.md | `{FEATURE_DIR}/contract.md` | implement (optional) |
| data-model.md | `{FEATURE_DIR}/data-model.md` | implement (optional) |
| research.md | `{FEATURE_DIR}/research.md` | implement (optional) |

**Internal files (not passed downstream):**

| File | Purpose |
|------|---------|
| `.planning-state.local.md` | Workflow state (v2 schema), phase tracking, user decisions |
| `.planning.lock` | Concurrency lock (60 min stale timeout) |
| `.phase-summaries/phase-{N}-summary.md` | Coordinator output contracts |
| `.phase-summaries/phase-{N}-user-input.md` | User answers to questions |
| `.phase-summaries/phase-{4,9}-skill-context.md` | Condensed dev-skills context |
| `design.grounding.md` | Architecture perspective option (temporary) |
| `design.ideality.md` | Architecture perspective option (temporary) |
| `design.resilience.md` | Architecture perspective option (temporary) |
| `requirements-anchor.md` | Consolidated spec + user clarifications |
| `cli-deepthinker-*-report.md` | CLI deep analysis findings |
| `cli-planreview-report.md` | CLI pre-validation review |
| `cli-security-report.md` | CLI security supplement |
| `cli-testreview-report.md` | CLI test strategy review |
| `cli-taskaudit-report.md` | CLI task audit findings |
| `analysis/task-test-traceability.md` | Task-to-test mapping matrix |
| `asset-manifest.md` | Asset preparation checklist (optional) |

---

### 7.5 implement

**Invocation:** `/implement`

**User inputs:**
- Autonomy policy selection (Stage 1)
- Validation failure decisions (Stage 3, if needed)
- Review findings decisions (Stage 4: fix/defer/accept)
- Documentation verification (Stage 5)

**Internal stages:** 1 (Setup) → 2 (Phase-by-Phase Execution) → 3 (Completion Validation) → 4 (Quality Review) → 5 (Documentation) → 6 (Retrospective)

**Final outputs:**

| File | Path | Purpose |
|------|------|---------|
| Source code | Per plan.md structure | Implemented feature code |
| Test files | Per test structure | Unit, integration, e2e, UAT tests |
| tasks.md (updated) | `{FEATURE_DIR}/tasks.md` | All completed tasks marked `[X]` |
| docs/ | `{FEATURE_DIR}/docs/` or per plan | Feature documentation |
| retrospective.md | `{FEATURE_DIR}/retrospective.md` | Implementation narrative and KPIs |

**Internal files:**

| File | Purpose |
|------|---------|
| `.implementation-state.local.md` | Workflow state (v2 schema), phase progress, user decisions |
| `.stage-summaries/stage-{N}-summary.md` | Coordinator output contracts |
| `.stage-summaries/stage-3-user-input.md` | User decision on validation failure |
| `.stage-summaries/transcript-extract.json` | Tool usage analytics (excluded from commit) |
| `review-findings.md` | Consolidated quality findings (conditional) |
| `.implementation-report-card.local.md` | Machine-readable KPI report (excluded from commit) |
| `.uat-evidence/{phase}/` | UAT screenshots (conditional) |

---

## 8. Observations & Simplification Opportunities

### 8.1 Volume vs Value

- **~77% of all files are internal** to each skill and never cross boundaries
- The pipeline generates ~90+ files for a single feature, but only ~18 are "passport" files
- State files, stage summaries, lock files, and analysis reports are invisible to the user in normal operation

### 8.2 Weakest Transition

The **refinement → specify** transition is the weakest link:
- `PRD.md` is optional for specify, not required
- If the user skips refinement, specify starts only from a text description
- This means the entire refinement skill can be bypassed, and the user might not realize the quality loss

### 8.3 Self-Corrective vs User-Dependent

| Skill | Quality Mechanism | User Dependency |
|-------|------------------|-----------------|
| design-handoff | 4 internal judge checkpoints (auto-corrective) | Low — judge auto-fixes most issues |
| refinement | RED validation loop (auto-retry with reflection) | High — user answers drive everything |
| specify | Coverage % gate + iteration loop | Medium — clarification questions + checklist |
| plan | Phase gate judges + MPA perspectives | Medium — architecture selection is critical |
| implement | Validation + review stages | Low — mostly automated with override options |

### 8.4 Review Time Allocation

Based on downstream impact multiplier, recommended user review time allocation:

| Review Point | Recommended Effort | Reason |
|-------------|-------------------|--------|
| QUESTIONS-{NNN}.md (refinement) | **35%** | Shapes PRD → cascades through 4 skills |
| spec.md (specify) | **25%** | Contract for all downstream; read by every plan phase |
| clarification-questions.md (specify) | **15%** | Second refinement pass on spec |
| design.md selection (plan) | **15%** | Irreversible architecture choice |
| tasks.md (plan) | **10%** | Direct input to implementation |

### 8.5 File Pattern Summary

Every skill follows the same internal pattern:

```
{working_dir}/
├── .{skill}-state.local.md      # YAML state file (resumable)
├── .{skill}.lock                 # Concurrency lock
├── .stage-summaries/             # Coordinator output contracts
│   └── stage-{N}-summary.md     # YAML frontmatter + markdown
├── {passport-files}              # Files that cross to next skill
└── {internal-files}              # Analysis, judge verdicts, etc.
```

This uniformity means tooling for state inspection, cleanup, or debugging can be shared across all skills.

---

*Last updated: 2026-02-28*
