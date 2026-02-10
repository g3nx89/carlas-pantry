---
stage: output-assembly
artifacts_written:
  - design-narration/UX-NARRATIVE.md
  - design-narration/.narration-state.local.md (updated)
---

# Output Assembly (Stage 5)

> Orchestrator reads this file to assemble the final UX-NARRATIVE.md from all prior stage outputs.

## CRITICAL RULES (must follow)

1. **Never overwrite user decisions**: Assemble from existing artifacts — do not regenerate or alter narrative content.
2. **Order screens by navigation flow**: Use the coherence report navigation map to determine document order, not file system order.
3. **Include all appendices**: Validation summary, coherence notes, decision revision log, and state machine diagrams are all required sections.

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

## Step 5.6: Append State Machine Diagrams

From coherence report: state machine diagrams for screens with 4+ states, placed at end of document.

## Step 5.7: Write Output

Write assembled document to `design-narration/UX-NARRATIVE.md`.

```
NOTIFY user: "UX-NARRATIVE.md generated with {N} screens, overall quality score: {score}/100."
SUGGEST: "Consider committing: git add design-narration/ && git commit -m 'feat: add UX narrative for {product_name}'"
REMOVE design-narration/.narration-lock
```

---

## Self-Verification (MANDATORY before completing)

1. `design-narration/UX-NARRATIVE.md` exists and is non-empty
2. All completed screen narratives included in document
3. Validation summary section populated (not null scores)
4. Coherence notes section present (even if no inconsistencies)
5. Decision revision log included (even if empty)
6. Lock file removed
7. State file updated: `current_stage: 5`, workflow complete

**Error handling:** For error classification and logging format, see `references/error-handling.md`.

## CRITICAL RULES REMINDER

1. Never overwrite user decisions — assemble from existing artifacts
2. Order screens by navigation flow
3. Include all appendices
