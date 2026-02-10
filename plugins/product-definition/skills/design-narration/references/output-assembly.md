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

## Step 5.1: Compile Global Patterns

From state file `patterns` section + coherence report:
- Shared Components table
- Navigation Model (mermaid diagram from coherence report)
- User Journey Flows (mermaid diagrams from coherence report)
- Interaction Conventions table
- Terminology Glossary

## Step 5.2: Assemble Per-Screen Narratives

Read each screen narrative file from `design-narration/screens/`. Include in document order matching the navigation flow (from coherence report navigation map).

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

## CRITICAL RULES REMINDER

1. Never overwrite user decisions — assemble from existing artifacts
2. Order screens by navigation flow
3. Include all appendices
