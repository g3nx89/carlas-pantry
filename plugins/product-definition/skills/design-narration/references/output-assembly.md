---
stage: output-assembly
artifacts_written:
  - design-narration/UX-NARRATIVE.md
  - design-narration/decision-log.md (multi-file mode only)
  - design-narration/screens/*.md (enhanced in-place, multi-file mode only)
  - design-narration/.narration-state.local.md (updated)
---

# Output Assembly (Stage 5)

> Orchestrator reads this file to assemble the final UX-NARRATIVE.md from all prior stage outputs.
> Supports two output modes: **single-file** (monolithic) and **multi-file** (progressive disclosure).

## CRITICAL RULES (must follow)

1. **Never overwrite user decisions**: Assemble from existing artifacts — do not regenerate or alter narrative content.
2. **Order screens by navigation flow**: Use the coherence report navigation map to determine document order, not file system order.
3. **Include all appendices**: Validation summary, coherence notes, decision revision log, and state machine diagrams are all required sections.
4. **Mode-aware assembly**: Read `output.progressive_disclosure` from config to determine single-file vs multi-file output. Both pathways produce a valid `UX-NARRATIVE.md` — the difference is what it contains.

---

## Step 5.0: Validate Required Inputs (MANDATORY CHECK)

Before beginning assembly, verify all required inputs exist:

```
REQUIRED (halt if missing):
  - design-narration/screens/ contains at least 1 signed-off narrative file
  - design-narration/.narration-state.local.md exists with screens_completed >= 1

EXPECTED (warn if missing, continue):
  - design-narration/coherence-report.md (Stage 3 output)
  - design-narration/validation/synthesis.md (Stage 4 output)

OPTIONAL (silent if missing):
  - design-narration/context-input.md

IF any REQUIRED input missing:
    STOP. NOTIFY user: "Cannot assemble UX-NARRATIVE.md: {missing_file}. Re-run earlier stages."

IF any EXPECTED input missing:
    NOTIFY user: "Assembling without {missing_file}. The corresponding section will note the gap."
```

---

## Step 5.0b: Completeness Assessment

Determine the document status before assembly:

```
SET DOCUMENT_STATUS = "FINAL"  # default optimistic

IF any screen in state has flagged_for_review == true:
    SET DOCUMENT_STATUS = "DRAFT — {N} screen(s) flagged for review"

IF coherence-report.md is missing AND screens_completed >= 2:
    SET DOCUMENT_STATUS = "DRAFT — coherence check not completed"

IF validation/synthesis.md is missing:
    SET DOCUMENT_STATUS = "DRAFT — validation not completed"

# FINAL only when all quality gates passed
IF all screens signed_off AND coherence.status == "completed" AND validation.status == "completed":
    SET DOCUMENT_STATUS = "FINAL"
```

Insert `{{DOCUMENT_STATUS}}` into the template header. Downstream consumers can check this field to distinguish complete narratives from partial ones.

---

## Step 5.0c: Determine Output Mode

Read progressive disclosure settings from config and determine which assembly pathway to follow:

```
READ config: output.progressive_disclosure.enabled
READ config: output.progressive_disclosure.screen_threshold
READ config: output.progressive_disclosure.mode_override

COUNT signed_off_screens from state file screens[] WHERE status == "signed_off"

IF mode_override == "single-file":
    SET output_mode = "single-file"
ELSE IF mode_override == "multi-file":
    SET output_mode = "multi-file"
ELSE IF enabled == false:
    SET output_mode = "single-file"
ELSE:
    # Auto-detect based on threshold
    IF signed_off_screens >= screen_threshold:
        SET output_mode = "multi-file"
    ELSE:
        SET output_mode = "single-file"

UPDATE state: output.mode = output_mode
NOTIFY user: "Output mode: {output_mode} ({signed_off_screens} screens)"
```

**Proceed to the matching pathway below.**

---
---

# PATHWAY A: Single-File Assembly (output_mode == "single-file")

> Existing monolithic behavior. UX-NARRATIVE.md contains all screen narratives inline.
> Template: `$CLAUDE_PLUGIN_ROOT/templates/ux-narrative-template.md`

---

## Step 5.1: Compile Global Patterns

From state file `patterns` section + coherence report:
- Shared Components table
- Navigation Model (mermaid diagram from coherence report)
- User Journey Flows (mermaid diagrams from coherence report)
- Interaction Conventions table
- Terminology Glossary

## Step 5.2: Assemble Per-Screen Narratives

Read each screen narrative file from `design-narration/screens/`. Include in document order matching the navigation flow (from coherence report navigation map).

**Inference marker cleanup:** During assembly, strip all `[Inferred]` markers from narrative text.
These markers are used during self-critique to distinguish observations from assumptions but
are not needed in the final output. The self-critique process ensures all inferences have been
validated through user Q&A before reaching Stage 5.

## Step 5.3: Append Validation Summary

From `design-narration/validation/synthesis.md`:
- MPA agent scores table
- PAL Consensus result (or "skipped" notation)
- Overall quality score and recommendation status

## Step 5.4: Append Coherence Notes

From `design-narration/coherence-report.md`:
- Resolved inconsistencies summary
- Open items (if any were skipped)

## Step 5.5: Append Decision Revision Log

From state file `decisions_audit_trail`:
- Table of all revisions: | Screen | Original Decision | Revised To | Reason |

## Step 5.5b: Append Auto-Resolved Questions

If `auto_resolve.include_in_report` is `true` in config AND `state.auto_resolved_questions` is non-empty:

```
READ config: auto_resolve.include_in_report
READ state: auto_resolved_questions[]

IF include_in_report AND len(auto_resolved_questions) > 0:
    APPEND section to UX-NARRATIVE.md:

    ## Appendix: Auto-Resolved Questions

    > {N} questions were automatically resolved from input documents, prior answers,
    > or accumulated patterns. See `design-narration/working/auto-resolved-questions.md`
    > for the full registry with rationale.

    | # | Stage | Screen | Question | Auto-Answer | Source |
    |---|-------|--------|----------|-------------|--------|
    (populated from state.auto_resolved_questions[])
```

## Step 5.6: Append State Machine Diagrams

From coherence report: state machine diagrams for screens with 4+ states, placed at end of document.

## Step 5.7: Write Output & Cleanup

Write assembled document to `design-narration/UX-NARRATIVE.md`.

```
NOTIFY user: "UX-NARRATIVE.md generated with {N} screens, overall quality score: {score}/100."
SUGGEST: "Consider committing: git add design-narration/ && git commit -m 'feat: add UX narrative for {product_name}'"
REMOVE design-narration/.narration-lock
```

**→ Skip to Self-Verification section.**

---
---

# PATHWAY B: Multi-File Assembly (output_mode == "multi-file")

> Progressive disclosure mode. UX-NARRATIVE.md is a compact index (~100-150 lines).
> Screen narratives remain as individual files in `screens/` with navigation headers added.
> Template: `$CLAUDE_PLUGIN_ROOT/templates/ux-narrative-index-template.md`

---

## Step 5.1m: Compile Global Patterns

Same source data as single-file Step 5.1 — but compiled into template variables for the index, not a full document:

From state file `patterns` section + coherence report:
- `{{SHARED_COMPONENTS_TABLE}}` — Shared Components table rows
- `{{NAVIGATION_MERMAID}}` — Navigation map mermaid code from coherence report
- `{{USER_JOURNEY_DIAGRAMS}}` — User Journey Flow mermaid diagrams from coherence report
- `{{INTERACTION_CONVENTIONS_TABLE}}` — Interaction Conventions table rows
- `{{GLOSSARY_TABLE}}` — Terminology Glossary table rows
- `{{STATE_MACHINE_DIAGRAMS}}` — State machine diagrams for screens with 4+ states

If coherence report is missing, populate each variable with `*Not available — coherence check was not completed.*`

---

## Step 5.2m: Enhance Screen Files In-Place

Determine screen order from the coherence report navigation map. If no coherence report, use state file screen order.

```
READ config: output.progressive_disclosure.screen_nav_header
READ coherence-report.md navigation map (if exists) → ordered_screens[]
FALLBACK to state file screens[] order if coherence report missing

FOR index, screen IN enumerate(ordered_screens):
    SET screen_file = "design-narration/screens/{screen.nodeId}-{screen.name}.md"
    READ screen_file content

    # 1. Strip [Inferred] markers
    REPLACE all "[Inferred]" with "" in content
    REPLACE all "[Inferred: ...]" patterns with "" in content

    # 2. Prepend navigation header (if screen_nav_header enabled)
    IF screen_nav_header:
        SET prev_link = ""
        SET next_link = ""

        IF index > 0:
            SET prev = ordered_screens[index - 1]
            SET prev_link = "[← {prev.name}]({prev.nodeId}-{prev.name}.md)"

        IF index < len(ordered_screens) - 1:
            SET next = ordered_screens[index + 1]
            SET next_link = "[{next.name} →]({next.nodeId}-{next.name}.md)"

        SET nav_header = "<!-- nav -->"
        SET nav_header += "\n> {prev_link} | [Index](../UX-NARRATIVE.md) | {next_link}"
        SET nav_header += "\n"

        # Check if nav header already exists (idempotent)
        IF content starts with "<!-- nav -->":
            REPLACE existing nav header block (up to first blank line after "<!-- nav -->")
        ELSE:
            PREPEND nav_header + "\n" to content

    # 3. Write back
    WRITE content to screen_file
```

**Idempotency:** The `<!-- nav -->` comment marker ensures re-running Step 5.2m replaces existing nav headers rather than duplicating them.

---

## Step 5.3m: Build Screen Inventory Table

Construct a table linking each screen to its file for the index:

```
SET inventory_rows = []

FOR index, screen IN enumerate(ordered_screens):
    READ state: screens[screen.node_id].critique_scores.total → score
    READ state: screens[screen.node_id] metadata for purpose (from narrative frontmatter or first line)

    SET file_link = "[{screen.nodeId}-{screen.name}.md](screens/{screen.nodeId}-{screen.name}.md)"
    APPEND row: "| {index+1} | {screen.name} | {screen.nodeId} | {score}/20 | {purpose} | {file_link} |"

SET {{SCREEN_INVENTORY_TABLE}} = joined inventory_rows
```

---

## Step 5.4m: Extract Decision Log

Write a standalone decision log from the state file audit trail:

```
READ state: decisions_audit_trail[]
SET decision_log_filename from config: output.progressive_disclosure.decision_log_file

WRITE to design-narration/{decision_log_filename}:

    # Decision Log: {{PRODUCT_NAME}}

    **Generated:** {{DATE}}

    ## All Decisions

    | # | Screen | Question | Answer | Timestamp |
    |---|--------|----------|--------|-----------|
    (populated from decisions_audit_trail[] — all entries)

    ## Revisions

    | # | Original Decision | Original Screen | Revised To | Trigger Screen | Rationale |
    |---|-------------------|----------------|------------|----------------|-----------|
    (populated from decisions_audit_trail[] WHERE revises IS NOT NULL)
```

For the index template, set `{{DECISION_REVISION_SUMMARY}}` to a count summary:
- `{total_decisions} decisions recorded, {revision_count} revisions. See [decision-log.md](decision-log.md) for full trail.`
- If no revisions: `{total_decisions} decisions recorded, no revisions.`

---

## Step 5.5m: Render Index

Populate the index template with all compiled variables and write:

```
READ template: $CLAUDE_PLUGIN_ROOT/templates/ux-narrative-index-template.md

REPLACE template variables:
    {{PRODUCT_NAME}}                  ← from state or context-input.md
    {{DOCUMENT_STATUS}}               ← from Step 5.0b
    {{VERSION}}                       ← "1.0" (or incremented if prior version exists)
    {{DATE}}                          ← current date
    {{SCREEN_COUNT}}                  ← count of signed-off screens
    {{SHARED_COMPONENTS_TABLE}}       ← from Step 5.1m
    {{NAVIGATION_MERMAID}}            ← from Step 5.1m
    {{USER_JOURNEY_DIAGRAMS}}         ← from Step 5.1m
    {{INTERACTION_CONVENTIONS_TABLE}} ← from Step 5.1m
    {{GLOSSARY_TABLE}}                ← from Step 5.1m
    {{STATE_MACHINE_DIAGRAMS}}        ← from Step 5.1m
    {{SCREEN_INVENTORY_TABLE}}        ← from Step 5.3m
    {{DECISION_REVISION_SUMMARY}}     ← from Step 5.4m
    {{MPA_RESULTS_TABLE}}             ← from validation/synthesis.md (or "Not available")
    {{PAL_CONSENSUS_TABLE}}           ← from validation/synthesis.md (or "Skipped")
    {{QUALITY_SCORE}}                 ← from validation/synthesis.md (or "N/A")
    {{RECOMMENDATION}}                ← from validation/synthesis.md (or "N/A")

WRITE rendered index to design-narration/UX-NARRATIVE.md
```

---

## Step 5.6m: Verify Relative Links

Check that all relative links in the index and screen files resolve to existing files:

```
SET broken_links = []

# Check index links
FOR each markdown link in UX-NARRATIVE.md:
    RESOLVE relative path from design-narration/
    IF target file does not exist:
        APPEND to broken_links: "{link} in UX-NARRATIVE.md"

# Check screen nav headers
FOR each screen file in design-narration/screens/:
    FOR each markdown link in nav header:
        RESOLVE relative path from design-narration/screens/
        IF target file does not exist:
            APPEND to broken_links: "{link} in {screen_file}"

IF broken_links is non-empty:
    NOTIFY user: "Warning: {len(broken_links)} broken link(s) found: {broken_links}"
    # Do NOT halt — broken links are non-fatal (usually from missing optional files)
```

---

## Step 5.7: Write Output & Cleanup (Shared)

```
IF output_mode == "multi-file":
    NOTIFY user: "UX-NARRATIVE.md index generated with {N} screens (multi-file mode). Screen files enhanced with navigation headers."
    NOTIFY user: "Per-screen files: design-narration/screens/*.md"
ELSE:
    NOTIFY user: "UX-NARRATIVE.md generated with {N} screens, overall quality score: {score}/100."

SUGGEST: "Consider committing: git add design-narration/ && git commit -m 'feat: add UX narrative for {product_name}'"
REMOVE design-narration/.narration-lock
```

---

## Self-Verification (MANDATORY before completing)

### Common (both modes)

1. `design-narration/UX-NARRATIVE.md` exists and is non-empty
2. Lock file removed
3. State file updated: `current_stage: 5`, `output.mode: {output_mode}`, workflow complete

### Single-file mode additional checks

4. All completed screen narratives included in document
5. Validation summary section populated (not null scores)
6. Coherence notes section present (even if no inconsistencies)
7. Decision revision log included (even if empty)

### Multi-file mode additional checks

4. All screen files in `screens/` have `<!-- nav -->` header (if `screen_nav_header` enabled)
5. Screen inventory table in index has one row per signed-off screen
6. `decision-log.md` exists and is non-empty
7. All relative links in index resolve to existing files (Step 5.6m)
8. Global patterns section in index is populated (not just placeholder text)

**Error handling:** For error classification and logging format, see `references/error-handling.md`.

## CRITICAL RULES REMINDER

1. Never overwrite user decisions — assemble from existing artifacts
2. Order screens by navigation flow
3. Include all appendices
4. Mode-aware assembly — both pathways produce a valid UX-NARRATIVE.md
