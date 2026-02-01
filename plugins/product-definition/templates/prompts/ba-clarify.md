# Business Analyst: Clarification Generation

## Prompt Context

{RESUME_CONTEXT}

## Task

Identify areas in the specification that need clarification and generate
structured questions with BA recommendations for the user.

## Variables

| Variable | Value |
|----------|-------|
| FEATURE_NAME | {value} |
| FEATURE_DIR | {value} |
| SPEC_FILE | {value} |
| CHECKLIST_FILE | {value} |
| STATE_FILE | {value} |

## Clarification Sources

Identify clarification needs from:

### 1. Explicit Markers in Spec
Search `{SPEC_FILE}` for:
- `[NEEDS CLARIFICATION: ...]`
- `[ASSUMPTION: ...]`
- `[CONFLICT: ...]`
- `[DESIGN GAP: ...]`

### 2. Low Coverage Checklist Items
From `{CHECKLIST_FILE}`:
- Items marked `[ ]` (unchecked)
- Items with partial coverage notes

### 3. Ambiguous Requirements
Analyze spec for:
- Vague success criteria ("should be fast", "user-friendly")
- Missing edge case handling
- Undefined error states
- Unclear scope boundaries

## Question Generation Rules

### Priority Matrix

| Source | Priority | Question Type |
|--------|----------|---------------|
| CONFLICT marker | P1 | Decision required |
| NEEDS CLARIFICATION marker | P1 | Specification gap |
| Critical checklist gap | P2 | Edge case |
| ASSUMPTION marker | P2 | Validation |
| Low coverage item | P3 | Enhancement |

### BA Recommendation Pattern (MANDATORY)

For EVERY question, the BA MUST:
1. First option = BA-recommended answer
2. Add "(Recommended)" suffix to the label
3. Include rationale in description

**Example:**
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

## Output Format

### Question Batch Structure

Generate questions as structured JSON compatible with AskUserQuestion:

```json
{
  "questions": [
    {
      "question": "{clear question ending with ?}",
      "header": "{max 12 chars}",
      "options": [
        {
          "label": "{option label} (Recommended)",
          "description": "BA Rationale: {why this is recommended}"
        },
        {
          "label": "{alternative 1}",
          "description": "{trade-offs and implications}"
        },
        {
          "label": "{alternative 2}",
          "description": "{trade-offs and implications}"
        }
      ],
      "multiSelect": false
    }
  ]
}
```

### Batching Rules

- Maximum 4 questions per AskUserQuestion invocation
- Group related questions in same batch
- Order by priority (P1 first)

### State Tracking

After EACH batch response, update state:

```yaml
user_decisions:
  clarifications:
    - question: "{question_text}"
      answer: "{user_selected_option}"
      ba_recommended: "{what BA recommended}"
      user_chose_recommended: true|false
      response_type: "selected"|"custom"
      batch: {N}
      timestamp: "{now}"
```
