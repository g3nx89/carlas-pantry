# Phase 11: PRD Generation

> **Source:** Extracted from `/product-definition:requirements` main orchestration

**Checkpoint:** `PRD_GENERATION`

**Goal:** Generate or extend PRD.md based on gathered requirements and user decisions.

## Step 11.1: Launch PRD Generator

**Launch:** `requirements-prd-generator` agent

Pass:
- All completed QUESTIONS files
- research-synthesis.md (if exists)
- PRD.md (if EXTEND mode)
- User decisions from state

## Step 11.2: Generate PRD

**If PRD_MODE = "NEW":**
Generate complete PRD.md from template at `$CLAUDE_PLUGIN_ROOT/templates/prd-template.md`

**If PRD_MODE = "EXTEND":**
Merge new answers into existing PRD.md sections
Preserve existing complete sections
Add/update incomplete sections

## Step 11.3: Technical Content Filter

Scan PRD.md for forbidden keywords:
- API, endpoint, backend, frontend, database, server
- architecture, implementation, deploy
- sprint, story point, velocity
- Kotlin, Swift, React, AWS, Firebase

**If found:** Remove or replace with non-technical alternatives

## Step 11.4: Generate Decision Log

Create/Update `requirements/decision-log.md` using template at `$CLAUDE_PLUGIN_ROOT/templates/decision-log-template.md`:
- All questions with selected answers
- Rationale for each decision
- Cross-references to PRD sections

## Step 11.5: Update State (CHECKPOINT)

```yaml
phases:
  prd_generation:
    status: completed
    prd_mode: "{NEW|EXTEND}"
    sections_generated: {N}
    sections_extended: {N}
```

**Git Suggestion:**
```
git add requirements/PRD.md requirements/decision-log.md
git commit -m "prd(req): generate PRD v{VERSION}"
git tag prd-v{VERSION}.0.0
```
