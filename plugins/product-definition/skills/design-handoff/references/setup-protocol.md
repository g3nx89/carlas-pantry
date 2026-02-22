---
stage: "1"
description: "Discovery & Inventory — Figma MCP check, page scan, readiness audit, TIER decision"
agents_dispatched: ["handoff-screen-scanner"]
artifacts_written: ["design-handoff/.handoff-state.local.md", "design-handoff/.screen-inventory.md", "design-handoff/.handoff-lock"]
config_keys_used: ["figma.connection", "state.*", "tier.*", "readiness.*", "directories.*", "figma_preparation.scenario_detection.*"]
---

# Stage 1 — Discovery & Inventory (Inline)

> Executed directly by orchestrator. No coordinator dispatch.

## Purpose

Gates all subsequent stages by confirming Figma MCP connectivity, scanning the designer's page for top-level frames, scoring each frame's handoff-readiness, recommending a TIER level, and obtaining designer approval before any Figma mutations begin.

## CRITICAL RULES (must follow)

1. **Both MCPs required** — If either `figma-desktop` or `figma-console` is unavailable, STOP. No graceful degradation.
2. **Lock before state** — Acquire lock before any state file read/write.
3. **All thresholds from config** — Never hardcode readiness percentages or nesting limits.
4. **Designer approval gates Stage 2** — Do NOT advance until the designer confirms inventory, TIER, and scenario.

---

## Step 1.1: Config Validation

```
READ @$CLAUDE_PLUGIN_ROOT/config/handoff-config.yaml

VALIDATE required keys: directories.root, state.{file_name, lock_file, lock_stale_timeout_minutes,
schema_version}, figma.connection (must be "desktop+console"), tier.{default (1-3),
smart_componentization.recurrence_threshold (>=2), smart_componentization.require_behavioral_variants,
smart_componentization.require_codebase_match}, readiness.{naming_compliance_threshold (1-100),
token_binding_threshold (1-100), group_warning_threshold (>=1), deep_nesting_warning_depth (>=1)},
modes.default (one of: guided, quick, batch)

IF any key missing or invalid:
    STOP. NOTIFY user: "Config validation failed: {key} is {missing|invalid}. Check handoff-config.yaml."
```

---

## Step 1.2: Figma MCP Check

```
CALL mcp__figma-desktop__get_metadata → SET FIGMA_DESKTOP = true/false
CALL mcp__figma-console__figma_get_status → SET FIGMA_CONSOLE = true/false

IF either is false:
    NOTIFY user: "Required Figma MCP unavailable. figma-desktop: {FIGMA_DESKTOP}, figma-console: {FIGMA_CONSOLE}. Both must be running."
    STOP workflow.
```

---

## Step 1.3: Lock Acquisition

```
ROOT = directories.root from config       # "design-handoff"
LOCK_PATH = {ROOT}/{state.lock_file}      # "design-handoff/.handoff-lock"
STALE = state.lock_stale_timeout_minutes from config

IF lock exists AND age < STALE:
    AskUserQuestion: "Active handoff session detected (lock < {STALE} min). How to proceed?"
        - "Resume existing session"     → SET WORKFLOW_MODE = RESUME
        - "Override lock and start fresh" → DELETE lock, SET WORKFLOW_MODE = NEW
        - "Cancel"                        → STOP

IF lock exists AND age >= STALE:
    NOTIFY: "Stale lock (>{STALE} min). Clearing."
    DELETE lock. SET WORKFLOW_MODE = RESUME if state file exists, else NEW.

IF no lock:
    SET WORKFLOW_MODE = RESUME if state file exists, else NEW.

WRITE lock: { locked_at: {ISO_NOW}, workflow_mode: {WORKFLOW_MODE} }
```

---

## Step 1.4: State Init or Resume

```
STATE_PATH = {ROOT}/{state.file_name}

IF WORKFLOW_MODE = RESUME AND state file exists:
    READ + VALIDATE schema_version. EXTRACT current_stage.
    IF current_stage != "1":
        NOTIFY: "Resuming from Stage {current_stage}. {screens.length} screens inventoried."
        RETURN current_stage to orchestrator → orchestrator dispatches appropriate stage.
    # current_stage == "1": re-run from Step 1.5 onward.

IF WORKFLOW_MODE = NEW OR no state file:
    mkdir -p {ROOT} {ROOT}/working {ROOT}/screenshots
    AskUserQuestion: "Select workflow mode:"
        - "Guided — interactive per-screen dialog (recommended)"
        - "Quick — single screen, no Figma preparation"
        - "Batch — file-based Q&A for offline answers"
    MAP selection → mode ID: "guided" | "quick" | "batch"
    INITIALIZE state per state-schema.md Initialization Template (schema_version from config,
        workflow_mode, current_stage: "1", started_at/last_updated: ISO_NOW)
    CHECKPOINT state
```

---

## Step 1.5: Page Selection

```
AskUserQuestion: "Open your Figma file, navigate to the handoff page, and confirm."
    - "Ready — page is open in Figma"

CALL mcp__figma-console__figma_get_selection → EXTRACT page_name, page_node_id

IF no page detected:
    NOTIFY: "Could not detect active Figma page. Select a page and try again."
    RE-ASK (loop until detected or user cancels)

UPDATE state: figma_page = { name: {page_name}, node_id: {page_node_id} }
CHECKPOINT state
```

---

## Step 1.6: Screen Scanner Dispatch

Dispatch `handoff-screen-scanner` (haiku) for frame discovery and structural metrics.

```
DISPATCH via Task(subagent_type="general-purpose"):
    - Agent: @$CLAUDE_PLUGIN_ROOT/agents/handoff-screen-scanner.md
    - Variables: PAGE_NODE_ID, PAGE_NAME, WORKING_DIR={ROOT}, OUTPUT_FILE={ROOT}/.screen-inventory.md
    - Config pass-through: NAMING_THRESHOLD, TOKEN_THRESHOLD, GROUP_WARNING, NESTING_WARNING
      (from readiness.* config keys)

WAIT → READ {ROOT}/.screen-inventory.md
```

Scanner writes YAML frontmatter with per-screen: `node_id`, `name`, `dimensions`, `child_count`, `image_fills`, `group_count`, `max_nesting_depth`, readiness breakdown (`naming`, `token_binding`, `structural_quality`, `component_usage` — each 0-100), and `component_candidates[]`.

**If scanner fails or returns zero frames:**
NOTIFY: "No top-level frames found on '{page_name}'. Verify frame-type layers at root level." STOP.

---

## Step 1.7: Readiness Analysis

```
FOR each screen in scanner output:
    APPEND to state.screens[]:
        node_id, name, dimensions, child_count, image_fills, group_count
        readiness_score: { naming: {naming_score}, tokens: {token_score}, structure: {structure_score}, component_usage: {component_usage_score} }
        max_nesting_depth: {max_nesting_depth}
        status: "pending", current_step: null, completed_steps: [], operation_journal: []
        scenario_escalated: false, visual_diff_score: null, fix_attempts: 0
        gap_count: { critical: 0, important: 0, nice_to_have: 0 }
        has_supplement: false, questions_answered: 0, questions_total: 0

CHECKPOINT state
```

---

## Step 1.8: TIER Decision

Apply the 3-gate Smart Componentization test to scanner's `component_candidates`.

```
READ from config: RECURRENCE = tier.smart_componentization.recurrence_threshold
                   REQUIRE_VARIANTS = tier.smart_componentization.require_behavioral_variants
                   REQUIRE_CODEBASE = tier.smart_componentization.require_codebase_match

FOR each candidate:
    gate_1 = occurrences >= RECURRENCE
    gate_2 = (NOT REQUIRE_VARIANTS) OR has_behavioral_variants
    gate_3 = (NOT REQUIRE_CODEBASE) OR has_codebase_match
    IF all gates pass: passing_candidates += 1

TIER decision:
    passing == 0                          → TIER 1
    passing >= 1                          → TIER 2
    TIER 2 AND inter-frame transitions    → TIER 3
    total_candidates == 0 (fallback)      → tier.default from config

UPDATE state: tier_decision = { tier, rationale: "{passing}/{total} passed 3-gate test",
    passing_candidates, total_candidates }
CHECKPOINT state
```

---

## Step 1.9: Scenario Detection

```
COMPUTE aggregates:
    avg_naming = mean(screens[].readiness_score.naming)
    avg_tokens = mean(screens[].readiness_score.tokens)
    total_groups = sum(screens[].group_count)
    any_deep = any screen.max_nesting_depth > readiness.deep_nesting_warning_depth (config)

CLASSIFY:
    avg_naming >= readiness.naming_compliance_threshold (config)
    AND avg_tokens >= readiness.token_binding_threshold (config)
    AND total_groups <= readiness.group_warning_threshold (config)
    AND NOT any_deep                                  → "already_clean"

    avg_naming < figma_preparation.scenario_detection.draft_naming_threshold (config)
    OR avg_tokens < figma_preparation.scenario_detection.draft_token_threshold (config)
    OR total_groups > screen_count * readiness.group_warning_threshold → "draft_to_handoff"

    ELSE                                              → "in_place_cleanup"

UPDATE state: scenario = {SCENARIO}
CHECKPOINT state
```

---

## Step 1.10: Designer Approval

```
BUILD inventory table:
| # | Screen | Size | Naming | Tokens | Structure | Groups | Flags |
(one row per screen from state)

BUILD summary:
    Total screens: {count}
    Scenario: {SCENARIO} — {description from figma_preparation.scenario_detection in config}
    TIER: {TIER} — {description from tier.levels.{TIER} in config}
    Componentization: {passing}/{total} candidates qualify

AskUserQuestion: "{table}\n\n{summary}\n\nConfirm to proceed with Stage 2, or adjust."
    - "Confirmed — proceed"
    - "Change TIER to 1 (naming cleanup only)"
    - "Change TIER to 2 (standard components)"
    - "Change TIER to 3 (full with prototypes)"
    - "Cancel workflow"

IF "Cancel": DELETE lock, STOP.
IF TIER override: UPDATE tier_decision.tier, rationale = "Designer override"

UPDATE state: current_stage = "2", last_updated = {ISO_NOW}
APPEND Progress Log: "## Stage 1 Complete\n- {count} screens\n- Scenario: {SCENARIO}\n- TIER: {TIER}\n- Approved: {ISO_NOW}"
CHECKPOINT state
```

---

## Output

After Stage 1 the state file contains: `figma_page` (name + node ID), `screens[]` (full inventory, all `"pending"`), `tier_decision` (TIER 1/2/3 + rationale), `scenario`, and `current_stage = "2"`.

Artifacts on disk:
- `design-handoff/.handoff-state.local.md` — initialized and checkpointed
- `design-handoff/.screen-inventory.md` — raw scanner output (retained for Stage 2J comparison)
- `design-handoff/.handoff-lock` — lock with timestamp

## CRITICAL RULES REMINDER

1. Both MCPs required — STOP if either unavailable
2. Lock before state — acquire lock before any state read/write
3. All thresholds from config — never hardcode
4. Designer approval gates Stage 2 — no advancement without confirmation
