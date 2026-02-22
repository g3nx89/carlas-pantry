# Judge Protocol — Design Handoff

> **Shared pattern for all judge checkpoints (Stages 2J, 3J, 3.5J, 5J)**
> **Agent:** `handoff-judge` (opus) — dispatched by orchestrator at stage boundaries

---

## Dispatch Pattern

The orchestrator dispatches `handoff-judge` at each checkpoint using a consistent protocol:

```
1. READ stage coordinator's output artifacts
2. READ relevant state from design-handoff/.handoff-state.local.md
3. DISPATCH handoff-judge with checkpoint-specific rubric (below)
4. READ judge verdict:
   - Machine-readable: state file `judge_verdicts.{checkpoint_id}` (verdict, cycle, findings)
   - Detailed evidence: `{WORKING_DIR}/judge-verdicts/{CHECKPOINT}-verdict.md`
   The state file is canonical for orchestrator decisions. The verdict file preserves full evidence.
5. ACT on verdict:
   - PASS → advance to next stage
   - NEEDS_FIX → re-dispatch stage coordinator with fix instructions → re-judge (up to max cycles)
   - BLOCK → halt workflow, mark screen(s) as blocked, notify designer
```

**Judge dispatch prompt template:**

```
You are evaluating the quality of Stage {STAGE_NAME} output.

Checkpoint: {CHECKPOINT_ID}
Working directory: {WORKING_DIR}
State file: {STATE_FILE_PATH}

## Artifacts to Evaluate
{ARTIFACT_PATHS}

## Rubric
{CHECKPOINT_RUBRIC}

## Pass Criteria
{PASS_CRITERIA}

## Instructions
1. Read all listed artifacts
2. Evaluate each rubric dimension
3. Write verdict to state file under judge_verdicts.{CHECKPOINT_ID}
4. If NEEDS_FIX or BLOCK: list specific findings with remediation instructions
```

---

## Checkpoint Rubrics

### Stage 2J — Figma Preparation Quality

**When:** After all screens have been processed by `handoff-figma-preparer`.

**Artifacts to evaluate:**
- `design-handoff/.handoff-state.local.md` — per-screen completion status, operation journal
- `design-handoff/.screen-inventory.md` — original readiness scores (for before/after comparison)
- `design-handoff/handoff-manifest.md` — naming, token mapping, component mapping (if started)
- Figma screenshots: `design-handoff/screenshots/{screen}-before.png` and `{screen}-after.png`

**Rubric dimensions:**

| # | Dimension | How to Evaluate | Pass Condition |
|---|-----------|----------------|----------------|
| 1 | **Visual fidelity** | Take screenshots of BOTH source and prepared screens via `figma_take_screenshot`. Compare layout structure, element placement, colors, fonts, content. | No layout shifts, missing elements, color changes, or font mismatches between source and prepared versions |
| 2 | **Naming compliance** | Via `figma-desktop::get_metadata` on each prepared screen: count layers with generic names ("Group N", "Frame N", "Rectangle N"). Compute % PascalCase for components. | Component naming compliance >= `judge.checkpoints.stage_2j.naming_min_compliance` in config |
| 3 | **Token binding** | Via `figma-console::figma_get_variables`: count fills/strokes bound to variables vs hardcoded hex. | Token coverage >= `judge.checkpoints.stage_2j.token_min_coverage` in config |
| 4 | **Component instantiation** | For TIER 2/3: cross-reference component library against each screen. If component X was created AND should appear on screen Y (per componentization analysis), verify an INSTANCE of X exists on screen Y. | All expected instances present. Missing instances listed as findings. |
| 5 | **GROUP residue** | Via `figma-desktop::get_metadata`: count GROUP-type nodes that are direct children of prepared screen frames. | GROUP count <= `judge.checkpoints.stage_2j.group_max_residue` in config |

**Verdicts:**
- `pass` — All 5 dimensions within thresholds → advance to Stage 3
- `needs_fix` — One or more dimensions below threshold → list specific screens and issues → re-dispatch `handoff-figma-preparer` for affected screens only → re-judge
- `block` — Visual fidelity compromised on a screen after max fix attempts → mark screen as blocked, continue workflow with remaining screens

**Max cycles:** `judge.checkpoints.stage_2j.max_fix_cycles` from config.

**On final failure:** Per `judge.checkpoints.stage_2j.on_final_fail` from config:
- `halt_screen` — Mark failing screens as `blocked` in state, continue with passing screens
- `halt_workflow` — Stop entirely, notify designer of all failures

---

### Stage 3J — Gap Completeness Check

**When:** After `handoff-gap-analyzer` produces the gap report.

**Artifacts to evaluate:**
- `design-handoff/gap-report.md` — per-screen gaps, missing screens, cross-screen patterns
- `design-handoff/.handoff-state.local.md` — screen inventory
- `design-handoff/handoff-manifest.md` — screen inventory with navigation references

**Rubric dimensions:**

| # | Dimension | How to Evaluate | Pass Condition |
|---|-----------|----------------|----------------|
| 1 | **Gap detection thoroughness** | For each screen, verify all 6 gap categories were considered (behaviors, states, animations, data, logic, edge_cases). Check for obvious omissions (e.g., a form screen with no submission behavior gap). | No obvious gaps missed across any screen |
| 2 | **Navigation dead-end detection** | Trace navigation flows from the manifest. Verify every "Navigates to X" reference has a matching screen X in the inventory OR is flagged as a missing screen. | Zero unresolved navigation references |
| 3 | **Missing screen completeness** | Verify all implied screens are cataloged: confirmation dialogs for destructive actions, error states for network calls, empty states for list screens, permission prompts for sensitive features. | All structurally implied screens are either present in inventory or flagged as missing |
| 4 | **Classification accuracy** | Verify MUST_CREATE/SHOULD_CREATE/OPTIONAL classifications are proportional: MUST_CREATE only for genuine implementation blockers, not for nice-to-haves. | No over-classification (MUST_CREATE for optional items) or under-classification (OPTIONAL for blocking items) |

**Verdicts:**
- `pass` — All dimensions satisfied → advance to Stage 3.5 (or Stage 4 if no missing screens)
- `needs_deeper` — Specific areas identified for re-examination → re-dispatch `handoff-gap-analyzer` with targeted instructions → re-judge

**Max cycles:** `judge.checkpoints.stage_3j.max_review_cycles` from config.

---

### Stage 3.5J — Design Extension Quality

**When:** After `handoff-figma-preparer` (in extend mode) creates missing screens/states.

**Artifacts to evaluate:**
- Newly created Figma screens (node IDs from state file)
- `design-handoff/.handoff-state.local.md` — missing_screens entries with `created_node_id`
- Existing prepared screens (for visual consistency comparison)

**Rubric dimensions:**

| # | Dimension | How to Evaluate | Pass Condition |
|---|-----------|----------------|----------------|
| 1 | **Visual consistency** | Take screenshots of new screen AND closest existing screen. Compare fonts, colors, spacing, layout rhythm. | New screen visually belongs to the same design family |
| 2 | **Component usage** | Via `figma-desktop::get_metadata`: verify new screen uses library components (INSTANCES) not raw frames for UI elements that have component equivalents. | Library components used where available |
| 3 | **Layout coherence** | Compare layout structure (header/body/footer pattern, margins, grid) with related existing screens. | Follows same layout patterns as related screens |
| 4 | **Content completeness** | Cross-reference against the missing screen's `reason` and classification. Verify all required elements are present (title, body, actions, navigation). | All elements from the classification description are present |

**Verdicts:**
- `pass` — All 4 dimensions satisfied → advance to Stage 4
- `needs_fix` — Specific issues listed → re-dispatch `handoff-figma-preparer` (extend mode) → re-judge

**Max cycles:** `judge.checkpoints.stage_3_5j.max_fix_cycles` from config.

---

### Stage 5J — Supplement Quality Check

**When:** After Stage 5 output assembly produces `HANDOFF-SUPPLEMENT.md` and updates `handoff-manifest.md`.

**Artifacts to evaluate:**
- `design-handoff/HANDOFF-SUPPLEMENT.md` — the final supplement document
- `design-handoff/handoff-manifest.md` — the updated manifest
- `design-handoff/gap-report.md` — the gap report (for completeness verification)
- Figma screens (via MCP) — to verify no content duplication

**Rubric dimensions:**

| # | Dimension | How to Evaluate | Pass Condition |
|---|-----------|----------------|----------------|
| 1 | **No Figma duplication** | Scan supplement for layout descriptions, color specs, spacing values, or element positioning. These belong in Figma, not the supplement. | Zero instances of visual/layout information that duplicates what's already in Figma |
| 2 | **Gap coverage completeness** | Cross-reference every CRITICAL and IMPORTANT gap from gap-report.md against supplement content. Every gap must have a corresponding entry. | 100% of CRITICAL gaps addressed, >= 90% of IMPORTANT gaps addressed |
| 3 | **Consistency with Figma** | Verify element names in supplement match current Figma layer names (post-preparation). Verify screen names and node IDs match manifest. | Zero naming mismatches between supplement and Figma/manifest |
| 4 | **Machine parseability** | Verify all tables are well-formed markdown (consistent columns, no broken rows). Verify mermaid diagrams parse without errors. | All tables and diagrams valid |
| 5 | **Conciseness** | Check for prose that could be a table row, redundant information across screens, or verbose descriptions. | No section exceeds 20 lines of prose. Tables preferred over paragraphs. |

**Verdicts:**
- `pass` — All 5 dimensions satisfied → workflow complete
- `needs_revision` — Specific sections to improve → regenerate affected sections → re-judge

**Max cycles:** `judge.checkpoints.stage_5j.max_revision_cycles` from config.

---

## Verdict Format

The judge writes verdicts to **two locations**:
1. **State file** (`judge_verdicts.{checkpoint_id}`) — machine-readable, used by orchestrator for decisions
2. **Verdict file** (`{WORKING_DIR}/judge-verdicts/{CHECKPOINT}-verdict.md`) — detailed evidence, used for auditing

State file structure (canonical for orchestrator):

```yaml
judge_verdicts:
  {checkpoint_id}:
    verdict: "pass" | "needs_fix" | "needs_deeper" | "needs_revision" | "block"
    cycle: {N}  # Current cycle number (1-indexed)
    findings:
      - dimension: "{dimension_name}"
        severity: "blocking" | "warning"
        screen: "{screen_name}" | "cross-screen"  # Which screen, or cross-screen for global issues
        detail: "{specific issue description}"
        remediation: "{what the stage coordinator should do to fix this}"
    summary: "{1-2 sentence overall assessment}"
```

---

## Orchestrator Integration

The orchestrator's responsibility at each judge checkpoint:

1. **Before dispatch:** Ensure all required artifacts exist. If any are missing, log error and skip judge (do not block workflow on missing artifacts — flag to designer instead).

2. **On PASS:** Update `current_stage` in state file, advance to next stage.

3. **On NEEDS_FIX / NEEDS_DEEPER / NEEDS_REVISION:**
   - Increment cycle counter
   - If cycle < max_cycles: re-dispatch the stage coordinator with judge findings as additional context
   - If cycle >= max_cycles: escalate to designer via AskUserQuestion: "Judge found issues after {N} fix attempts: {summary}. Options: (A) Accept current state, (B) Review findings manually, (C) Halt workflow."

4. **On BLOCK:** Mark affected screen(s) as `blocked` in state. If any screens remain non-blocked, continue workflow with those screens. If ALL screens blocked, halt workflow and notify designer.

---

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Correct Approach |
|-------------|----------------|-----------------|
| Skipping judge for "obviously clean" screens | Confirmation bias — issues hide in clean-looking screens | Always run judge; let the rubric decide |
| Running judge inline (not as separate dispatch) | Judge shares context with the stage coordinator, biasing toward passing | Always dispatch as independent agent |
| Ignoring NICE_TO_HAVE gaps in Stage 5J | Supplement should address all designer-confirmed gaps | Check all severity levels, not just CRITICAL |
| Re-running entire stage on NEEDS_FIX | Wastes time and context on screens that passed | Re-dispatch only for affected screens/sections |
