# Clarification Protocol — File-Based

> Migrated from interactive AskUserQuestion batching (v1.0) to file-based flow (v2.0).
> Dispatched by the Stage 4 coordinator. All questions written to a single file;
> user edits offline; workflow resumes on re-invocation.

### Expected Context

| Variable | Source | Description |
|----------|--------|-------------|
| `FEATURE_DIR` | Stage 1 (Step 1.7) | Path to feature directory |
| `FEATURE_NAME` | Stage 1 | Human-readable feature name |
| `SPEC_FILE` | Stage 2 output | Path to `spec.md` |
| `CHECKLIST_FILE` | Stage 3 output | Path to `spec-checklist.md` |
| `STATE_FILE` | Stage 1 (Step 1.10) | Path to `.specify-state.local.md` |
| `INPUT_DOCUMENT_PATHS` | Stage 2 checkpoint | Paths to input documents for auto-resolve |

---

## Configuration Reference

**Load from:** `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml`

| Setting | Config Path | Default |
|---------|-------------|---------|
| Clarification mode | `clarification.mode` | `file_based` |
| Auto-resolve enabled | `clarification.auto_resolve.enabled` | `true` |
| Auto-resolve confidence | `clarification.auto_resolve.confidence_required` | `high` |
| Auto-resolve sources | `clarification.auto_resolve.sources` | `[input_documents, prior_decisions, spec_content]` |
| Registry file | `clarification.auto_resolve.registry_file` | `clarification-report.md` |

---

## BA Recommendation Pattern (MANDATORY)

For **EVERY** question, the coordinator MUST generate a BA recommendation:

### Format (in question file)

```markdown
### Q-{NNN}: {clear question title}
**Source**: {checklist_gap | edge_case | triangulation}  |  **Severity**: {CRITICAL | HIGH | MEDIUM}
**Context**: {1-2 sentences on why this matters}
**Recommendation**: {BA recommended answer with rationale}
**Options**:
1. {BA choice} (Recommended)
2. {Alternative 1}: {trade-offs}
3. {Alternative 2}: {when appropriate}

**Your answer** (leave blank to accept recommendation):
```

### Example

```markdown
### Q-015: How should the app handle network errors during form submission?
**Source**: edge_case  |  **Severity**: HIGH
**Context**: Forms collect user data that could be lost on network failure.
**Recommendation**: Exponential backoff with retry. Reduces server load during
  outages while providing user feedback.
**Options**:
1. Exponential backoff with retry (Recommended)
2. Immediate retry with limit: Faster recovery but may overwhelm server
3. Show error and manual retry: Simplest but may frustrate users

**Your answer** (leave blank to accept recommendation):
```

---

## Question File Format

**File path:** `specs/{FEATURE_DIR}/clarification-questions.md`

```markdown
---
feature: "{FEATURE_NAME}"
total_questions: {N}
auto_resolved: {N}
requires_user: {N}
generated: "{ISO_TIMESTAMP}"
status: pending  # pending | answered
---

# Clarification Questions: {FEATURE_NAME}

> Fill in answers below. Leave blank to accept BA recommendation.
> When done, re-run `/feature-specify` to continue.

---

## Auto-Resolved (for your review)

> These questions were answered from your input documents. Override by writing
> a different answer in the override field.

### Q-001: {title} [AUTO-RESOLVED]
**Source**: {source}  |  **Severity**: {severity}
**Answer**: {auto-resolved answer}
**Citation**: {document}: "{exact quote}" (section X.Y)
> Override (leave blank to keep auto-answer): ___

{... more auto-resolved questions ...}

---

## Requires Your Input

### Q-{NNN}: {title}
**Source**: {source}  |  **Severity**: {severity}
**Context**: {why this matters}
**Recommendation**: {BA recommended answer with rationale}
**Options**:
1. {Option 1} (Recommended)
2. {Option 2}: {trade-offs}
3. {Option 3}: {when appropriate}

**Your answer** (leave blank to accept recommendation):

{... more questions requiring user input ...}
```

---

## Answer Parsing Rules

When the workflow resumes after user edits:

### Parsing Logic

```
READ clarification-questions.md

FOR each question Q:

    IF Q is AUTO-RESOLVED:
        IF override field is non-empty and differs from auto-answer:
            answer = override text
            response_type = "user_override"
            user_chose_recommended = false
        ELSE:
            answer = auto-resolved answer
            response_type = "auto_resolved"
            user_chose_recommended = N/A

    IF Q is REQUIRES_USER:
        IF "Your answer" field is non-empty:
            answer = user's text
            response_type = "custom"
            # Check if answer matches recommendation
            IF answer matches option 1 text OR is blank:
                user_chose_recommended = true
            ELSE:
                user_chose_recommended = false
        ELSE (blank):
            answer = recommendation text
            response_type = "accepted_recommendation"
            user_chose_recommended = true
```

### Validation

```
IF any CRITICAL severity question has no answer AND no recommendation:
    FLAG as incomplete — notify user

COUNT answered = auto_resolved + user_answered + accepted_recommendations
IF answered < total_questions:
    WARN: "{N} questions unanswered — using recommendations for blank entries"
```

---

## State Tracking

After parsing answers, save to STATE_FILE:

```yaml
user_decisions:
  clarifications:
    - question: "{question_text}"
      answer: "{resolved_answer}"
      ba_recommended: "{what BA recommended}"
      user_chose_recommended: true|false
      response_type: "auto_resolved"|"user_override"|"custom"|"accepted_recommendation"
      source: "{checklist_gap|edge_case|triangulation}"
      severity: "{CRITICAL|HIGH|MEDIUM}"
      auto_resolve_classification: "AUTO_RESOLVED"|"REQUIRES_USER"|null
      timestamp: "{now}"
      stage: 4
      iteration: {N}

stages:
  clarification:
    status: "completed"
    clarification_file_path: "specs/{FEATURE_DIR}/clarification-questions.md"
    clarification_status: "answered"
    questions_total: {N}
    questions_auto_resolved: {N}
    questions_user_answered: {N}
    questions_accepted_recommendation: {N}
    user_overrides: {N}
```

---

## Workflow Integration

### Entry Point (First Run)

Called by coordinator when checklist validation identifies gaps:
1. Load spec and checklist
2. Identify [NEEDS CLARIFICATION] markers and edge case questions
3. Check already-answered in state file (NEVER re-ask)
4. Run auto-resolve gate (see `auto-resolve-protocol.md`)
5. Generate questions with BA recommendations
6. Write `clarification-questions.md`
7. Return `status: needs-user-input, pause_type: file_based`

### Re-Entry (After User Edits)

Called when user re-invokes after editing the question file:
1. Read `clarification-questions.md`
2. Parse answers using rules above
3. Save to state file
4. Return answers to coordinator for spec update

### Exit Conditions

- All questions answered (explicitly or via recommendation) -> Return with success
- File not modified since generation -> Return with `needs-user-input` (user hasn't answered yet)
- Parse errors -> Return with error status and specific parsing issues

---

## Output Variables

Return to coordinator:

| Variable | Value |
|----------|-------|
| CLARIFICATION_STATUS | completed, needs_user_input, or error |
| QUESTIONS_TOTAL | count |
| QUESTIONS_AUTO_RESOLVED | count |
| QUESTIONS_USER_ANSWERED | count |
| QUESTIONS_ACCEPTED_RECOMMENDATION | count |
| USER_OVERRIDES | count |
| MARKERS_RESOLVED | count |
