---
stage: "3.5"
description: "Design Extension — create missing screens/states in Figma (conditional)"
agents_dispatched: ["handoff-figma-preparer (extend mode)"]
artifacts_written: ["Figma screens (node IDs in state)"]
config_keys_used: ["design_extension.*", "judge.checkpoints.stage_3_5j.*"]
---

# Stage 3.5 — Design Extension (Conditional)

> Only runs if Stage 3 detected MUST_CREATE or SHOULD_CREATE missing screens.
> Uses `handoff-figma-preparer` agent in extend mode (`{MODE}=extend`).

---

## Trigger Condition

Read `missing_screens` from state file. Filter entries where:

```
classification IN ("MUST_CREATE", "SHOULD_CREATE")
AND designer_decision IS null
```

If the filtered list is **empty**, skip Stage 3.5 entirely and advance to Stage 4 (or 3.5J skip path).

If the filtered list is **non-empty**, proceed to Step 3.5.1.

---

## Step 3.5.1: Present Missing Items to Designer

Build a summary table of all actionable missing items and present via `AskUserQuestion`.

**Presentation format:**

```
Stage 3 found {N} missing screens/states that could improve the handoff.
Each item needs your decision before proceeding.

## Missing Screens/States

| #  | Name                     | Classification | Reason                                           |
|----|--------------------------|----------------|--------------------------------------------------|
| 1  | ForgotPassword           | MUST_CREATE    | Login screen links to "Forgot Password" — no screen exists |
| 2  | SearchEmpty              | SHOULD_CREATE  | Search results screen has no empty state variant  |
| 3  | DeleteConfirmation       | SHOULD_CREATE  | Delete button on ItemDetail — no confirmation dialog |

## Options per item (enter as: 1A, 2C, 3B)

  (A) Create in Figma now — subagent creates placeholder using existing design patterns
  (B) Designer will create manually — pauses workflow, resume on re-invocation
  (C) Document in supplement only — describe without visual reference
  (D) Skip — not needed for this handoff

Your choices (e.g. "1A, 2C, 3B"):
```

**Rules:**
- ALL items must receive a decision. Do not proceed with partial answers.
- If the designer gives a bulk shortcut (e.g., "all A"), expand to per-item decisions before recording.
- MUST_CREATE items: warn if designer selects D (Skip) — "This is classified as MUST_CREATE. Skipping means the coding agent has no visual reference for this screen. Confirm skip? (y/n)"

---

## Step 3.5.2: Process Designer Decisions

Record each decision in the state file under `missing_screens[].designer_decision`:

| Option | `designer_decision` value | Next action |
|--------|---------------------------|-------------|
| A | `create_in_figma` | Queue for dispatch in Step 3.5.3 |
| B | `create_manually` | Queue for pause in Step 3.5.5 |
| C | `document_only` | No Figma work — supplement will describe textually |
| D | `skip` | Remove from supplement scope entirely |

**State write checkpoint:** After recording all decisions, update `last_updated` and append to Progress Log:

```markdown
### Stage 3.5 — Designer Decisions Recorded
- Items total: {N}
- Create in Figma (A): {count}
- Create manually (B): {count}
- Document only (C): {count}
- Skip (D): {count}
```

**Immutability rule:** Once `designer_decision` is written, it is NEVER overwritten. On resume, skip items that already have a non-null `designer_decision`.

---

## Step 3.5.3: Dispatch Creation (Option A Items)

For each item with `designer_decision = "create_in_figma"`, dispatch `handoff-figma-preparer` in **extend mode**.

**Dispatch order:** MUST_CREATE items first, then SHOULD_CREATE.

**One screen per dispatch** — never batch multiple screens in a single agent invocation (per `design_extension.one_screen_per_dispatch: true`).

**Extend mode context variables:**

| Variable | Source | Example |
|----------|--------|---------|
| `{MODE}` | Literal | `extend` |
| `{SCREEN_NAME}` | `missing_screens[i].name` | `ForgotPassword` |
| `{SCREEN_NODE_ID}` | Not applicable — screen does not exist yet. Pass `null`. | `null` |
| `{SCREEN_PURPOSE}` | `missing_screens[i].reason` | `"Login screen links to 'Forgot Password' — no screen exists"` |
| `{REFERENCE_SCREEN_NODE_ID}` | Closest existing screen by navigation relationship. Determined by tracing the `implied_by` field back to the source screen's node ID in the state file. | `"42:1337"` |
| `{REQUIRED_ELEMENTS}` | Derived from gap category and screen type. Include: structural elements (header, body, actions), content elements (title, description, inputs), and navigation elements (back, submit, cancel). | `["header", "emailInput", "submitButton", "backLink"]` |
| `{SCENARIO}` | Literal — extend mode does not use preparation scenarios | `"extend"` |
| `{TIER}` | From state file `tier_decision.tier` | `2` |
| `{STATE_FILE_PATH}` | From state file path | `"design-handoff/.handoff-state.local.md"` |
| `{WORKING_DIR}` | From working directory | `"design-handoff/"` |
| `{COMPONENT_LIBRARY_NODE_ID}` | From state file `component_library` (TIER 2/3 only) | `"0:42"` |
| `{INVENTORY_DATA}` | Not applicable for new screens — pass `null` | `null` |

**Reference screen selection logic:**

```
1. IF missing screen was implied by a navigation element on Screen X:
     → Use Screen X as reference
2. ELSE IF missing screen is a state variant of Screen X (e.g., empty state):
     → Use Screen X as reference
3. ELSE:
     → Use the screen with the highest readiness_score as reference
```

**Per-dispatch post-processing:**

After each successful dispatch:
1. Record `created_node_id` from the agent's summary in state file
2. Set `extension_status = "created"`
3. Append to Progress Log: `"Created {SCREEN_NAME} (node: {ID}) using {REFERENCE_SCREEN_NAME} as reference"`

After each failed dispatch:
1. Set `extension_status = "error"`
2. Log error detail to Progress Log
3. Continue to next item — do not halt the loop

---

## Step 3.5.4: Verify Created Screens

After ALL Option A dispatches complete, verify each created screen:

```
FOR EACH missing_screen WHERE extension_status = "created":
  1. READ state file for created_node_id
  2. CALL mcp__figma-desktop__get_metadata(nodeId={created_node_id})
     → Verify node exists and has children
  3. IF node missing or empty:
       SET extension_status = "error"
       LOG: "Verification failed for {name}: node {id} not found or empty"
  4. ELSE:
       SET extension_status = "verified"
       LOG: "Verified {name}: node {id} has {child_count} children"
```

**Failure threshold:** If more than half of Option A items fail verification, notify designer:

```
{N} of {M} screens failed creation verification.
Options:
  (A) Retry failed screens
  (B) Convert failed screens to Option C (document in supplement only)
  (C) Halt workflow for manual intervention
```

---

## Step 3.5.5: Handle Pause (Option B Items)

If ANY item has `designer_decision = "create_manually"`:

1. Update state file:
   - Set `current_stage = "3.5"`
   - Set those items' `extension_status = "pending_manual"`
2. Append to Progress Log:
   ```markdown
   ### Stage 3.5 — Paused for Manual Design
   Waiting for designer to create:
   - {item_1_name}: {reason}
   - {item_2_name}: {reason}
   Resume by re-invoking the workflow command.
   ```
3. Release lock file (allow designer to work without stale lock)
4. Present exit message via `AskUserQuestion`:
   ```
   Workflow paused. Please create the following screens in Figma:

   | Screen           | Purpose                                    |
   |------------------|--------------------------------------------|
   | ForgotPassword   | Forgot password flow — linked from Login   |
   | DeleteConfirm    | Confirmation dialog for item deletion      |

   When done, re-run /product-definition:design-handoff to resume.
   Tip: Place new screens on the same Figma page as existing handoff screens.
   ```
5. **EXIT workflow immediately.** Do not proceed to Step 3.5.6 or Stage 3.5J.

**Resume protocol (re-invocation):**

On resume, the orchestrator detects `current_stage = "3.5"` and `extension_status = "pending_manual"`:

1. For each pending_manual item, search Figma for a new frame matching the expected name
2. If found: record `created_node_id`, set `extension_status = "verified"`
3. If not found: ask designer — "Could not find screen '{name}' in Figma. Has it been created? (y/n)"
   - If yes: ask for node ID or screen name to search
   - If no: offer Option A (create now) or Option C (document only) as fallback
4. Once all pending_manual items resolved, continue to Step 3.5.6

---

## Step 3.5.6: Update State & Inventory

After all Option A and Option B items are resolved:

1. **Add new screens to inventory:**
   For each item with `extension_status = "verified"`:
   ```yaml
   screens:
     - node_id: "{created_node_id}"
       name: "{SCREEN_NAME}"
       status: "prepared"          # Created via extend mode — already follows prep standards
       dimensions: { width: TBD, height: TBD }  # Read from Figma metadata
       child_count: TBD            # Read from Figma metadata
       image_fills: false          # New screens use components, not image fills
       group_count: 0              # Extend mode creates FRAMEs, not GROUPs
       readiness_score: { naming: 100, tokens: 100, structure: 100 }  # Subagent creates to standard
   ```

2. **Update gap report:**
   - Items with `designer_decision = "create_in_figma"` and `extension_status = "verified"`: remove from Section 2 (Missing Screens) of `gap-report.md`, add note: "Created in Stage 3.5"
   - Items with `designer_decision = "document_only"`: keep in Section 2, add annotation: "Will be described in supplement (no Figma screen)"
   - Items with `designer_decision = "skip"`: remove from Section 2 entirely

3. **Update manifest:**
   Add new screens to `handoff-manifest.md` screen inventory with navigation references pointing back to their source screens.

4. **State checkpoint:**
   ```yaml
   current_stage: "3.5J"  # Ready for judge evaluation
   last_updated: "{ISO_NOW}"
   ```

---

## Transition to Stage 3.5J

The orchestrator checks the following before dispatching `handoff-judge` for checkpoint `stage_3_5j`:

1. All Option A items have `extension_status` in `("verified", "error")`
2. All Option B items have `extension_status` in `("verified")` (resolved on resume)
3. No item has `extension_status = "pending_manual"` (would have triggered pause)
4. State file `current_stage` is `"3.5J"`

**Judge dispatch context:**
- Checkpoint ID: `stage_3_5j`
- Artifacts: newly created Figma screens (node IDs from state), existing prepared screens (for consistency comparison)
- Rubric: visual consistency, component usage, layout coherence, content completeness (see `judge-protocol.md` Stage 3.5J)
- Max fix cycles: `judge.checkpoints.stage_3_5j.max_fix_cycles` (config: 2)

**On NEEDS_FIX:** Re-dispatch `handoff-figma-preparer` in extend mode for affected screens only, passing judge findings as additional context. Decrement remaining fix cycles.

**On PASS:** Advance `current_stage` to `"4"`.

---

## Skip Condition

Stage 3.5 is **entirely skipped** when ALL of the following are true:

1. `missing_screens` array in state file is empty, OR
2. All entries in `missing_screens` have `classification = "OPTIONAL"` (no MUST_CREATE or SHOULD_CREATE items)

When skipped:
- Set `current_stage` directly from `"3J"` to `"4"` (bypass `"3.5"` and `"3.5J"`)
- Append to Progress Log: `"Stage 3.5 skipped — no MUST_CREATE or SHOULD_CREATE items detected"`
- OPTIONAL items remain in the gap report for supplement documentation in Stage 5

---

## Error Recovery

| Failure | Recovery |
|---------|----------|
| Agent dispatch fails mid-loop | Resume from next unprocessed item; failed item gets `extension_status = "error"` |
| State file write fails | Agent retries write once; on second failure, marks item as error and continues |
| Designer gives invalid option format | Re-prompt with example: "Please use format: 1A, 2C, 3B" |
| Created screen node disappears from Figma | Detected in Step 3.5.4; offer retry or fallback to Option C |
| Workflow resumes but Figma file changed | Re-verify all `created_node_id` entries; flag any that no longer exist |
