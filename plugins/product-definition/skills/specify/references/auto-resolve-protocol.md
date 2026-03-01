---
stage: stage-4-clarification
artifacts_written:
  - specs/{FEATURE_DIR}/clarification-report.md (created or updated)
---

# Auto-Resolve Protocol

> Pre-presentation gate that filters clarification questions answerable from existing input
> documents before presenting the remaining questions to the user in `clarification-questions.md`.
> Adapted from `skills/design-narration/references/auto-resolve-protocol.md` for the
> specify workflow.

## CRITICAL RULES (must follow)

1. **High confidence only**: Only auto-resolve when the source provides a clear, unambiguous answer. When in doubt, classify as REQUIRES_USER.
2. **Never auto-resolve subjective questions**: Questions about preferences, trade-offs, priority ordering, or design philosophy always require the user.
3. **Citation required**: Every auto-resolved question must cite the exact source text and location.
4. **User can override**: Auto-resolved answers appear in the question file for user review and optional override.

---

## Classification Levels

| Classification | Meaning | Appears In File |
|----------------|---------|-----------------|
| `AUTO_RESOLVED` | Answer found with high confidence in input documents | Auto-Resolved section (user can override) |
| `INFERRED` | Answer partially supported but needs user confirmation | Requires Your Input section (with inference note) |
| `REQUIRES_USER` | No source material answers this; user must decide | Requires Your Input section |

---

## Auto-Resolve Gate Logic

```
READ config: clarification.auto_resolve.enabled
READ config: clarification.auto_resolve.confidence_required
READ config: clarification.auto_resolve.sources

IF NOT auto_resolve.enabled:
    SKIP gate — classify all questions as REQUIRES_USER
    RETURN

SET auto_resolved = []
SET inferred = []
SET requires_user = []

FOR each question Q in pending_questions:

    SET classification = "REQUIRES_USER"

    # Exclusion check first
    IF Q matches any exclusion rule (see Exclusion Rules below):
        APPEND Q to requires_user[]
        CONTINUE

    # Source 1: Input documents (spec draft, user input, research reports)
    IF "input_documents" IN auto_resolve.sources:
        SEARCH spec.md, original user input, research reports for explicit answer to Q
        MATCH criteria:
            - Document explicitly states the answer (not implied)
            - Relevant section is about the same feature area
            - Answer is specific enough to act on
        IF found with exact quote:
            classification = "AUTO_RESOLVED"
            citation = "{document}: \"{exact_quote}\" (section X.Y)"
        ELIF found with reasonable inference:
            classification = "INFERRED"
            citation = "{document}: \"{supporting_text}\" — inferred, not explicit"

    # Source 2: Prior user decisions (from state file)
    IF classification == "REQUIRES_USER" AND "prior_decisions" IN auto_resolve.sources:
        SEARCH user_decisions.clarifications for prior answer to same or equivalent question
        MATCH criteria:
            - Same feature area or behavior being asked about
            - Question intent matches (not just keyword overlap)
            - Prior answer is still current (not superseded)
        IF found:
            classification = "AUTO_RESOLVED"
            citation = "Prior decision: \"{question}\" → \"{answer}\" (iteration {N})"

    # Source 3: Spec content (answers embedded in drafted sections)
    IF classification == "REQUIRES_USER" AND "spec_content" IN auto_resolve.sources:
        SEARCH spec.md for content that directly answers Q
        MATCH criteria:
            - Spec section explicitly addresses the question
            - Not a [NEEDS CLARIFICATION] marker (those are the questions)
            - Answer is concrete, not a placeholder
        IF found:
            classification = "AUTO_RESOLVED"
            citation = "spec.md: section {section_name} already specifies this"

    # Classify
    IF classification == "AUTO_RESOLVED":
        APPEND Q to auto_resolved[]
    ELIF classification == "INFERRED":
        APPEND Q to requires_user[]  # Inferred = present to user with note
    ELSE:
        APPEND Q to requires_user[]
```

---

## Exclusion Rules

The following question types are NEVER auto-resolved, regardless of source matches:

1. **Subjective/preference questions**: "Which approach should we use?", "What priority level?"
2. **Trade-off questions**: Questions where multiple valid approaches exist with different costs
3. **Severity CRITICAL questions**: Critical gaps always require explicit user confirmation
4. **Scope decisions**: Questions about what to include/exclude from feature scope
5. **Questions with conflicting source answers**: If two sources disagree, present to user

---

## Output: clarification-report.md

Generated after answer processing. Contains audit trail for all questions.

```markdown
---
total_questions: {N}
auto_resolved: {N}
inferred: {N}
user_answered: {N}
user_overrides: {N}
generated: "{ISO_TIMESTAMP}"
---

# Clarification Report: {FEATURE_NAME}

## Summary

| Metric | Count |
|--------|-------|
| Total questions generated | {N} |
| Auto-resolved from input documents | {N} |
| Inferred (presented with note) | {N} |
| Answered by user | {N} |
| User overrides of auto-answers | {N} |
| Blank (accepted recommendation) | {N} |

## Question Audit Trail

### Q-001: {title}
- **Classification**: AUTO_RESOLVED | REQUIRES_USER
- **Source**: {checklist_gap | edge_case | triangulation}
- **Severity**: {CRITICAL | HIGH | MEDIUM}
- **Auto-answer**: {answer} | N/A
- **Citation**: {citation} | N/A
- **User answer**: {answer} | (accepted auto) | (accepted recommendation)
- **Final answer**: {resolved answer}

{... repeat for all questions ...}
```

---

## Self-Verification

After running the auto-resolve gate:

1. All AUTO_RESOLVED questions have exact citations
2. No subjective or scope questions were auto-resolved
3. No CRITICAL severity questions were auto-resolved
4. Inferred questions are presented to user (not silently resolved)
5. Report file has valid YAML frontmatter with accurate counts

## Worked Examples

### Example 1: AUTO_RESOLVED — Explicit Answer in Input

**Question:** "What authentication method should the app use?"
**Source search:** User input contains: "Use OAuth2 with Google and Apple sign-in."
**Classification:** AUTO_RESOLVED
**Citation:** user_input: "Use OAuth2 with Google and Apple sign-in." (paragraph 3)
**Rationale:** Explicit, unambiguous statement directly answering the question.

### Example 2: INFERRED — Partial Support

**Question:** "Should the app support offline mode?"
**Source search:** User input says: "Users may be in areas with poor connectivity."
**Classification:** INFERRED
**Citation:** user_input: "Users may be in areas with poor connectivity." — inferred, not explicit
**Rationale:** Implies offline support is needed, but doesn't explicitly require it. Present to user with the inference note.

### Example 3: REQUIRES_USER — Exclusion Rule Triggered

**Question:** "Which data retention policy should apply: 30 days or 90 days?"
**Source search:** No mention in any source document.
**Classification:** REQUIRES_USER
**Rationale:** This is a trade-off question (two valid options with different costs) — excluded from auto-resolve regardless of source matches.

### Example 4: REQUIRES_USER — Conflicting Sources

**Question:** "Should error messages show technical details?"
**Source search:** User input says "Show helpful error messages." Research report says "Never expose internal errors to users."
**Classification:** REQUIRES_USER
**Rationale:** Two sources disagree on the level of detail. Conflicting sources trigger exclusion rule #5.
