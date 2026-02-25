---
stage: "5"
description: "Output Assembly — generate HANDOFF-SUPPLEMENT.md and update manifest"
agents_dispatched: []
artifacts_written: ["design-handoff/HANDOFF-SUPPLEMENT.md", "design-handoff/handoff-manifest.md (updated)"]
config_keys_used: ["output.*", "templates.*"]
---

# Stage 5 — Output Assembly (Inline)

> Executed directly by orchestrator. No coordinator dispatch.

## Purpose

Assemble Stages 1-4 output into two deliverables:
1. **HANDOFF-SUPPLEMENT.md** — compact tables-first document covering ONLY what Figma cannot express
2. **handoff-manifest.md** (updated) — structural inventory enriched with routes, annotations, new screens

## CRITICAL RULES

1. **Figma is source of truth** — Zero layout descriptions, color specs, spacing values in supplement.
2. **Tables over prose** — Prose only for cross-screen patterns that genuinely cannot fit table format.
3. **Always single file** — No progressive disclosure mode (compact by design).
4. **Never regenerate content** — Assemble from existing artifacts only.
5. **Omit empty sections** — If a template section would have zero rows, omit it entirely.

---

## Step 5.1: Load Templates and Validate Inputs

```
REQUIRED (halt if missing):  gap-report.md, .handoff-state.local.md, handoff-manifest.md
IF any missing: STOP. NOTIFY: "Cannot assemble: {missing}. Re-run earlier stages."

READ supplement_template  ← config templates.supplement
READ screen_template      ← config templates.screen
READ STATE, GAP_REPORT, INCLUDE_MERMAID (config), INCLUDE_CROSS (config)
```

---

## Step 5.2: Assemble Cross-Screen Patterns

Skip entirely if `INCLUDE_CROSS` is `false`.

**Shared Behaviors** — one row per `STATE.patterns.shared_behaviors[]`:
`| {pattern} | {screens comma-joined} | {description} |`. Fallback: `| — | — | No shared behaviors detected |`.

**Navigation Mermaid** (if `INCLUDE_MERMAID`) — Build `graph LR` with one node per non-blocked screen, one edge per cross-screen transition extracted from GAP_REPORT. Sanitize node labels (no spaces, max 20 chars). Missing screens appear as dashed-border nodes labeled `{Name}["⚠ {Name}"]`.

After the Mermaid block, emit a **Screen Reference Table** for human navigation:
```markdown
| Screen | Node ID | Brief |
|--------|---------|-------|
| Login | `42:1337` | — |
| ForgotPassword | — (not in Figma) | [FSB-001](figma-screen-briefs/FSB-001-ForgotPassword.md) |
```
This lets the reviewer jump directly to the right Figma frame or brief document.

**Common Transitions** — one row per `STATE.patterns.common_transitions[]`:
`| {name} | {screens} | {type} | {duration} |`. Fallback row if empty.

---

## Step 5.3: Assemble Per-Screen Sections

Iterate `STATE.screens` in Figma page order (matching manifest). Track `supplement_count`.

**No-gap screens** — one-liner: `### {N}. {name}` / `**Node ID:** ... | **No supplement needed**`

**Screens with gaps** — extract `screen_gaps` from GAP_REPORT by `node_id`. Category-to-section mapping:

| Gap Category | Template Section | Columns |
|-------------|-----------------|---------|
| behaviors, logic | Behaviors (Not in Figma) | Element / Action / Result |
| states | State Transitions | From / Trigger / To / Visual Change |
| animations | Animations | Animation / Trigger / Spec (`{ms} {easing}`) |
| data | Data Requirements | Endpoint / Method / Payload / Response |
| edge_cases | Edge Cases | Bullet list: `- {description}` |

**Element column rule:** When the gap's `element` field is a named Figma layer (e.g., `SubmitButton`, `PasswordInput`), include it verbatim — the coding agent can locate it via `figma_execute` using the exact layer name. This replaces the need for inline node-ID references in the supplement body.

**Omit any subsection whose table/list would be empty.** `GAP_COUNT` = sum of all rows + bullets.

---

## Step 5.4: Assemble Missing Screens Section

Include only if `STATE.missing_screens` has entries with `designer_decision == "document_only"` (option C). For each: emit `### {name} (not in Figma)`, reason, classification, and `| Element | Behavior | Notes |` table from GAP_REPORT. Omit entire section if no option-C screens.

---

## Step 5.4b: Assemble Figma Screen Briefs Index

Include only if `STATE.artifacts.figma_screen_briefs_dir` exists and contains at least one FSB file.

Read all `FSB-*.md` files from `figma_screen_briefs/`. For each, extract YAML frontmatter fields.

**Output format:**

```markdown
## Figma Screen Briefs

Screens that were missing from Figma have been documented as briefs.
Give these files to a figma-console agent to create the missing screens.

| Brief | Screen | Classification | Status | Figma Node |
|-------|--------|----------------|--------|------------|
| [FSB-001](figma-screen-briefs/FSB-001-ForgotPassword.md) | ForgotPassword | MUST_CREATE | pending | — |
| [FSB-002](figma-screen-briefs/FSB-002-SearchEmpty.md) | SearchEmpty | SHOULD_CREATE | created | `42:1899` |

**To create pending screens:** run `/meta-skills:figma-console-mastery` and pass each brief file as input.
```

Omit entire section if no FSB files exist in the directory.

---

## Step 5.5: Generate HANDOFF-SUPPLEMENT.md

Populate `handoff-supplement-template.md`:

| Variable | Source |
|----------|--------|
| `{{PRODUCT_NAME}}` | STATE (ask designer if absent) |
| `{{SCREEN_COUNT}}` | Non-blocked screens count |
| `{{SUPPLEMENT_COUNT}}` | From Step 5.3 |
| `{{DATE}}` | ISO-8601 today |
| `{{PAGE_NAME}}` | `STATE.figma_page.name` |
| `{{TIER_LEVEL}}` | `STATE.tier_decision.tier` |
| `{{SHARED_BEHAVIORS_TABLE}}` | Step 5.2 (omit section if `INCLUDE_CROSS` false) |
| `{{NAVIGATION_MERMAID}}` | Step 5.2 (omit block if `INCLUDE_MERMAID` false) |
| `{{COMMON_TRANSITIONS_TABLE}}` | Step 5.2 (omit section if `INCLUDE_CROSS` false) |
| Per-Screen placeholder | Joined output from Step 5.3 |
| `{{MISSING_SCREENS_SECTION}}` | Step 5.4 (omit if empty) |
| `{{FIGMA_BRIEFS_INDEX}}` | Step 5.4b (omit section if no FSB files) |

Write to `design-handoff/HANDOFF-SUPPLEMENT.md`. Update `STATE.artifacts.handoff_supplement`. Checkpoint.

---

## Step 5.6: Update Handoff Manifest

Enrich the existing `handoff-manifest.md` with Stages 3-4 data:

1. **Routes** — Update Route column from designer answers in GAP_REPORT (`"—"` if none).
2. **Supplement flag** — Set `Yes` for screens with `critical > 0 OR important > 0`.
3. **Missing Screens Added** — Populate Stage 3.5 section with `create_in_figma` screens that have `created_node_id`. Omit section if none.
4. **Health Score** — Update instance count if Stage 3.5 added screens.

Write updated manifest. Checkpoint.

---

## Step 5.7: Summary Report

Present to designer (direct output, not AskUserQuestion):

```markdown
## Handoff Complete

| Metric | Value |
|--------|-------|
| Screens processed | {total_screens} |
| Screens with supplement | {supplement_count} |
| Screens skipped (blocked) | {blocked_count} |
| Missing screens documented | {option_c_count} |
| Missing screens created | {option_a_count} |
| Figma screen briefs generated | {figma_briefs_count} |
| Total gaps addressed | {total_gaps} |
| CRITICAL gaps | {critical_count} |
| TIER | {tier} |

### Artifacts
| File | Description |
|------|-------------|
| `HANDOFF-SUPPLEMENT.md` | Developer supplement — what Figma cannot express |
| `handoff-manifest.md` | Structural inventory with routes and components |
| `gap-report.md` | Working artifact — per-screen gap analysis |
| `figma-screen-briefs/FSB-*.md` | Screen briefs for missing screens (if any) |

### Next Steps
1. Review `HANDOFF-SUPPLEMENT.md` for accuracy
2. If briefs exist: give each `FSB-*.md` file to a figma-console agent to create missing screens
3. Run `/product-definition:specify` to generate the feature specification
4. Figma file remains the visual source of truth
```

Update `STATE.current_stage: "5"`. Append to Progress Log. Checkpoint.

---

## Transition to Stage 5J

Artifacts for judge (see `references/judge-protocol.md` Stage 5J rubric): `HANDOFF-SUPPLEMENT.md`, `handoff-manifest.md`, `gap-report.md`, Figma screens via MCP.

```
UPDATE STATE: current_stage = "5J"
DISPATCH handoff-judge with checkpoint_id: "stage_5j"
```

On `needs_revision`: re-run only affected Step 5.x, re-judge (max `judge.checkpoints.stage_5j.max_revision_cycles`). On `pass`: advance to workflow completion (lock release, final state update).

---

## CRITICAL RULES REMINDER

1. Figma is source of truth — zero layout/color/spacing in supplement
2. Tables over prose — every piece of information in a table
3. Always single file — no multi-file mode
4. Never regenerate — assemble from existing artifacts only
5. Omit empty sections — no empty tables or placeholder rows
