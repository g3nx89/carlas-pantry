---
stage: all
artifacts_written:
  - design-narration/working/auto-resolved-questions.md (created or updated)
  - design-narration/.narration-state.local.md (updated — auto_resolved_questions appended)
---

# Auto-Resolve Protocol

> Shared reference for automatically answering clarification questions when the answer
> is already available in input documents, prior Q&A, or accumulated patterns.
> Referenced by `screen-processing.md`, `batch-processing.md`, `coherence-protocol.md`,
> and `validation-protocol.md` as a pre-presentation gate.

## CRITICAL RULES (must follow)

1. **High confidence only**: Only auto-resolve when the source provides a clear, unambiguous answer. When in doubt, present to user.
2. **Always notify**: When questions are auto-resolved, notify the user with a count and pointer to the registry file.
3. **Never auto-resolve subjective questions**: Questions about preferences, trade-offs, or design philosophy always go to the user.

---

## When to Apply This Protocol

This protocol is a **gate** inserted BEFORE presenting questions to the user. It filters out
questions that already have answers available in existing context. The calling stage file
specifies when to invoke this gate — typically:

- **Screen processing (Stage 2):** Before AskUserQuestion in Q&A mediation
- **Batch processing (Stage 2-BATCH):** Before writing BATCH-QUESTIONS document
- **Coherence check (Stage 3):** Before presenting inconsistencies to user
- **Validation (Stage 4):** Before presenting critical findings to user

---

## Auto-Resolve Gate Logic

```
READ config: auto_resolve.enabled
READ config: auto_resolve.confidence_required
READ config: auto_resolve.sources
READ config: auto_resolve.registry_file
READ config: auto_resolve.notify_user

IF NOT auto_resolve.enabled:
    SKIP gate — pass all questions through to user
    RETURN

SET auto_resolved = []
SET user_questions = []

FOR each question Q in pending_questions:

    SET resolved = false

    # Source 1: Prior answers (exact match)
    IF "prior_answers" IN auto_resolve.sources:
        SEARCH decisions_audit_trail for prior answer to same or equivalent question
        MATCH criteria:
            - Same screen element or behavior being asked about
            - Question intent matches (not just keyword overlap)
            - Prior answer is still current (not superseded by a revision)
        IF found:
            auto_resolve(Q, prior_answer, "Prior answer (decision {id})", "high")
            SET resolved = true

    # Source 2: Context document (PRD, brief, screen descriptions)
    IF NOT resolved AND "context_document" IN auto_resolve.sources:
        SEARCH context_document + batch screen descriptions for explicit text answering Q
        MATCH criteria:
            - The document explicitly states the answer (not implied or tangential)
            - The relevant section is about the same screen or feature
            - The answer is specific enough to act on (not "TBD" or "to be defined")
        IF found with clear match:
            auto_resolve(Q, extracted_answer, "Context document: {section}", "high")
            SET resolved = true

    # Source 3: Accumulated patterns
    IF NOT resolved AND "accumulated_patterns" IN auto_resolve.sources:
        CHECK accumulated_patterns for convention that directly answers Q
        MATCH criteria:
            - An established pattern across 2+ completed screens covers this question
            - Applying the pattern to this screen is unambiguous (same element type, same context)
        IF pattern directly answers:
            auto_resolve(Q, pattern_answer, "Pattern: {pattern_name}", "high")
            SET resolved = true

    IF resolved:
        APPEND Q to auto_resolved[]
    ELSE:
        APPEND Q to user_questions[]
```

---

## Post-Gate Actions

```
IF auto_resolved is non-empty:

    # 1. Append to state
    FOR each auto-resolved question:
        APPEND to state.auto_resolved_questions[]:
            id: "auto-{NNN}"  (sequential, zero-padded)
            stage: "{current_stage}"
            screen: "{screen_name}"
            question: "{question_text}"
            answer: "{resolved_answer}"
            rationale: "{why this answer was chosen}"
            source_type: "{prior_answers|context_document|accumulated_patterns}"
            source_ref: "{specific reference — decision ID, document section, or pattern name}"
            timestamp: "{ISO}"

    CHECKPOINT state (per references/checkpoint-protocol.md)

    # 2. Write/update registry file
    WRITE_OR_UPDATE design-narration/{auto_resolve.registry_file}
        (see Registry File Format below)

    # 3. Notify user (if enabled)
    IF auto_resolve.notify_user:
        NOTIFY user (inline, not AskUserQuestion):
            "{N} question(s) auto-resolved from input documents/prior answers.
             See design-narration/{auto_resolve.registry_file} for details."

# 4. Present ONLY user_questions[] to user
RETURN user_questions[] to calling stage for presentation
```

---

## Registry File Format

File: `design-narration/{auto_resolve.registry_file}` (default: `working/auto-resolved-questions.md`)

```markdown
---
total_auto_resolved: {N}
last_updated: "{ISO}"
---

# Auto-Resolved Questions Registry

> Questions answered automatically because the answer was already available
> in input documents or prior Q&A.
> Review this file to verify auto-resolutions. Flag any incorrect answers
> during the next interaction cycle.

| # | Stage | Screen | Question | Auto-Answer | Rationale | Source |
|---|-------|--------|----------|-------------|-----------|--------|
| 1 | 2 | CartScreen | Empty state behavior? | Show illustration with CTA | PRD Section 3.2 specifies empty state pattern | context_document |
| 2 | 2 | HomeScreen | Header naming convention? | Use "Navigation Bar" | Pattern from LoginScreen, SettingsScreen | accumulated_patterns |
```

**Update behavior:** Each gate invocation appends new rows. The `total_auto_resolved` count
and `last_updated` timestamp in frontmatter are updated on each write. Existing rows are
never modified or removed.

---

## Exclusion Rules

The following question types are NEVER auto-resolved, regardless of source matches:

1. **Subjective/preference questions**: "Which color scheme?", "Should we use a modal or inline?"
2. **Decision revision proposals**: Questions flagged as `decision_revisions` by the analyzer
3. **Conflict resolution questions**: Questions tagged `[CONFLICT]` by the batch consolidator
4. **Questions with no clear single answer**: If the source material is ambiguous or provides multiple options

---

## Self-Verification

After running the auto-resolve gate:

1. All auto-resolved questions have `confidence_required` level (from config)
2. Registry file exists and has valid YAML frontmatter
3. State `auto_resolved_questions[]` count matches registry table row count
4. No subjective or conflict questions were auto-resolved
5. User was notified (if `notify_user` enabled and auto-resolutions occurred)

## CRITICAL RULES REMINDER

1. High confidence only — when in doubt, present to user
2. Always notify — user must know questions were auto-resolved
3. Never auto-resolve subjective questions
