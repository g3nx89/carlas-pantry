---
name: specify-clarification
description: Question batching and BA recommendation patterns for specification clarifications
---

# Clarification Skill

## Purpose

Handle the clarification phase of specification workflow.
Manages question batching, BA recommendations, error recovery, and state tracking.

---

## Input Context

| Variable | Description |
|----------|-------------|
| FEATURE_DIR | Path to feature directory |
| SPEC_FILE | Path to spec.md |
| CHECKLIST_FILE | Path to spec-checklist.md |
| STATE_FILE | Path to state file |

---

## Batching Rules

### Configuration Reference (P7)

**Load limits from:** `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml`

| Setting | Config Path | Default |
|---------|-------------|---------|
| Questions per batch | `limits.questions_per_batch` | 4 (API limit) |
| Max clarification iterations | `limits.clarification_iterations_max` | **null** (no limit) |
| Max clarification markers | `limits.clarification_markers_max` | **null** (no limit) |
| Max clarification questions | `limits.max_clarification_questions` | **null** (no limit) |
| Max clarification batches | `limits.max_clarification_batches` | **null** (no limit) |

### Core Constraints

- AskUserQuestion supports **MAX 4 questions** per invocation (API constraint - cannot change)
- If > 4 questions: batch in groups, save after EACH batch
- Track: `current_batch`, `total_batches`, `questions_answered`
- **NO LIMIT on total questions** - ask everything needed for complete spec
- **NO LIMIT on iterations** - continue until all clarifications resolved

### Batching Algorithm

```
total_questions = count(identified_clarifications)
batch_size = 4
total_batches = ceil(total_questions / batch_size)

for batch_num in 1..total_batches:
    start_idx = (batch_num - 1) * batch_size
    end_idx = min(start_idx + batch_size, total_questions)
    batch_questions = questions[start_idx:end_idx]

    present_batch(batch_questions)
    save_responses_to_state()  # IMMEDIATELY after each batch
```

---

## BA Recommendation Pattern (MANDATORY)

For **EVERY** question, the first option MUST be BA-recommended:

### Format

```json
{
  "question": "{clear question ending with ?}",
  "header": "{max 12 chars}",
  "options": [
    {
      "label": "{BA choice} (Recommended)",
      "description": "BA Rationale: {why this is recommended based on industry best practices, project context, or technical constraints}"
    },
    {
      "label": "{alternative 1}",
      "description": "{trade-offs and implications of this choice}"
    },
    {
      "label": "{alternative 2}",
      "description": "{when this might be appropriate}"
    }
  ],
  "multiSelect": false
}
```

### Example

```json
{
  "question": "How should the app handle network errors during form submission?",
  "header": "Error",
  "options": [
    {
      "label": "Exponential backoff with retry (Recommended)",
      "description": "BA Rationale: Industry standard for mobile. Reduces server load during outages while providing user feedback."
    },
    {
      "label": "Immediate retry with limit",
      "description": "Faster recovery but may overwhelm server. Good for low-latency requirements."
    },
    {
      "label": "Show error and manual retry",
      "description": "Simplest implementation. Gives user full control but may frustrate during intermittent issues."
    }
  ],
  "multiSelect": false
}
```

---

## Custom Response Handling ("Other" Option)

AskUserQuestion automatically adds "Other" option to all questions.

### Detection

```
IF user_response.selected_option == "other" OR user_response contains free text:
  RESPONSE_TYPE = "custom"
  CUSTOM_TEXT = user_response.text
```

### Validation

```
IF RESPONSE_TYPE == "custom":
  IF CUSTOM_TEXT is empty OR whitespace only:
    -> Retry question: "Please provide a valid custom response"

  IF CUSTOM_TEXT length > 500:
    -> Truncate and confirm: "Your response was truncated to 500 chars. Confirm?"
```

### State Storage for Custom Responses

```yaml
user_decisions:
  clarifications:
    - question: "{question_text}"
      answer: "{CUSTOM_TEXT}"
      response_type: "custom"  # vs "selected"
      ba_recommended: "{original_recommendation}"
      user_chose_recommended: false
```

### BA Update Integration

When updating spec with custom responses:
- Include full custom text in context
- Mark as `[USER SPECIFIED]` in spec for visibility

---

## State Tracking

After **EACH** batch, save to STATE_FILE:

```yaml
user_decisions:
  clarifications:
    - question: "{question_text}"
      answer: "{user_selected_option}"
      ba_recommended: "{what BA recommended}"
      user_chose_recommended: true|false
      response_type: "selected"|"custom"
      batch: 1
      timestamp: "{now}"
    - question: "{next_question}"
      answer: "{answer}"
      # ... etc

phases:
  clarification:
    current_batch: {N}
    total_batches: {M}
    questions_answered: {count}
    questions_remaining: {count}
    status: "in_progress"|"completed"
```

---

## Error Handling for AskUserQuestion

### Error Detection

After EACH AskUserQuestion call, validate response:

```
IF response is null OR empty:
  ERROR_TYPE = "NO_RESPONSE"

IF response timeout (> 5 minutes no activity):
  ERROR_TYPE = "TIMEOUT"

IF response contains unexpected format:
  ERROR_TYPE = "INVALID_FORMAT"
```

### Recovery Protocol

```
ON ERROR:
  RETRY_COUNT = 0
  MAX_RETRIES = 1

  WHILE RETRY_COUNT < MAX_RETRIES:
    -> Log to state file:
      error_log:
        - timestamp: "{now}"
          error_type: {ERROR_TYPE}
          question_batch: {current_batch}
          retry_attempt: {RETRY_COUNT + 1}

    -> Wait 2 seconds
    -> Retry AskUserQuestion
    -> RETRY_COUNT += 1

    IF success:
      -> Break loop, continue normal flow

  IF still failing after retries:
    -> Mark questions as NEEDS_MANUAL_INPUT
    -> Offer recovery options
```

### Recovery Options Dialog

```json
{
  "questions": [{
    "question": "The interactive question flow encountered an error. How would you like to proceed?",
    "header": "Recovery",
    "options": [
      {
        "label": "Provide text answers (Recommended)",
        "description": "I'll show you the questions and you can type your answers directly."
      },
      {
        "label": "Skip these questions",
        "description": "Continue with BA recommendations for unanswered questions."
      },
      {
        "label": "Retry from beginning",
        "description": "Start the clarification batch over."
      }
    ],
    "multiSelect": false
  }]
}
```

### Handling Recovery Choices

**If "Provide text answers":**
- For each NEEDS_MANUAL_INPUT question:
  - Display: "Question: {question_text}"
  - Display: "BA Recommendation: {ba_recommended}"
  - Prompt: "Your answer (or press Enter to accept recommendation):"
  - Capture text input
  - Update state file with answer

**If "Skip these questions":**
- For each NEEDS_MANUAL_INPUT:
  - Set answer = ba_recommended
  - Set user_chose_recommended = true (auto)
  - Set skipped_due_to_error = true

**If "Retry from beginning":**
- Clear current_batch from state
- Re-invoke clarification skill

---

## Graceful Degradation (Bulk Mode)

```
IF total_errors_in_session > 3:
  -> Switch to "Bulk Mode":

  Display:
  ---
  SWITCHING TO BULK CLARIFICATION MODE

  Multiple interactive errors detected. Switching to bulk input.

  Please review the following questions and provide answers:

  ---
  Q1: {question_1}
  BA Recommendation: {recommendation_1}
  Your answer: _____________

  Q2: {question_2}
  BA Recommendation: {recommendation_2}
  Your answer: _____________

  [... etc ...]
  ---

  Paste your answers below (format: Q1: answer, Q2: answer, ...)
  Or type "ACCEPT ALL" to use all BA recommendations.
  ---

  -> Parse bulk response
  -> Update state file
  -> Continue workflow
```

---

## Workflow Integration

### Entry Point

Called by orchestrator when checklist validation identifies gaps:
1. Load spec and checklist
2. Identify markers and low-coverage items
3. Check already-answered in state file (NEVER re-ask)
4. Generate questions with BA recommendations
5. Present in batches of 4
6. Save immediately after each batch
7. Return to orchestrator for spec update

### Exit Conditions

- All identified questions answered -> Return with success
- User chose "Skip remaining" -> Return with partial
- Unrecoverable error -> Return with error status

---

## Output Variables

Return to orchestrator:

| Variable | Value |
|----------|-------|
| CLARIFICATION_STATUS | completed, partial, or error |
| QUESTIONS_ANSWERED | count |
| QUESTIONS_SKIPPED | count |
| MARKERS_RESOLVED | count |
| ERRORS_ENCOUNTERED | count |
