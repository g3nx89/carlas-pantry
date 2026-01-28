# Phase 2: Workspace

> **Source:** Extracted from `/product-definition:requirements` main orchestration

**Checkpoint:** `WORKSPACE_INIT`

**Goal:** Set up directory structure and state tracking.

## Step 2.1: Create Directory Structure

```bash
mkdir -p requirements/draft
mkdir -p requirements/working
mkdir -p requirements/research/questions
mkdir -p requirements/research/reports
mkdir -p requirements/analysis
```

## Step 2.2: Copy Draft to Working

```bash
cp "requirements/draft/{DRAFT_FILE}" requirements/working/draft-copy.md
```

## Step 2.3: Create Lock File

```bash
echo "locked_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
workflow_mode: {NEW|EXTEND}
prd_mode: {NEW|EXTEND}
pid: $$" > requirements/.requirements-lock
```

## Step 2.4: Initialize State File (CHECKPOINT)

Create `requirements/.requirements-state.local.md` from template at `$CLAUDE_PLUGIN_ROOT/templates/.requirements-state-template.local.md`.

Set:
- `prd_mode`: "{NEW|EXTEND}"
- `current_phase`: "INIT"
- `phase_status`: "completed"
- `mcp_availability`:
  - `pal_available`: {true|false}
  - `st_available`: {true|false}

**Git Suggestion:**
```
git add requirements/
git commit -m "wip(req): initialize requirements structure"
```
