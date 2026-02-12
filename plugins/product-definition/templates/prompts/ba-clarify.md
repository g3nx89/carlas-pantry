# Business Analyst: Clarification Generation

## Prompt Context

{RESUME_CONTEXT}

## Task

Identify areas in the specification that need clarification and generate
structured questions with BA recommendations. Output as markdown for the
`clarification-questions.md` file (file-based flow).

## Variables

| Variable | Value |
|----------|-------|
| FEATURE_NAME | {value} |
| FEATURE_DIR | {value} |
| SPEC_FILE | {value} |
| CHECKLIST_FILE | {value} |
| STATE_FILE | {value} |
| AUTO_RESOLVE_REPORT | {value or "Not available"} |

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

### Auto-Resolve Awareness

If `{AUTO_RESOLVE_REPORT}` is available, exclude any questions already resolved
in the auto-resolve report. Only generate questions classified as `REQUIRES_USER`.

## Output Format

Generate questions as markdown sections for `clarification-questions.md`:

```markdown
### Q-{NNN}: {question title} [REQUIRES_USER]
**Source**: {checklist_gap | edge_case | spec_marker}  |  **Severity**: {CRITICAL | HIGH | MEDIUM}
**Context**: {why this matters for the specification}
**Recommendation**: {BA recommended answer with rationale}
**Options**:
1. {Option 1} (Recommended)
2. {Option 2}: {trade-offs}
3. {Option 3}: {when appropriate}

**Your answer** (leave blank to accept recommendation):
```

### Ordering Rules

- Order by priority (P1 first, then P2, then P3)
- Within same priority, order by severity (CRITICAL > HIGH > MEDIUM)

### State Tracking

After user answers are parsed (on re-invocation), update state:

```yaml
user_decisions:
  clarifications:
    - question_id: "Q-{NNN}"
      question: "{question_text}"
      answer: "{user_answer_or_recommendation}"
      ba_recommended: "{what BA recommended}"
      user_chose_recommended: true|false
      response_type: "recommendation_accepted"|"user_provided"|"overridden"
      timestamp: "{now}"
```
