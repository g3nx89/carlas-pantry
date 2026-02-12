# Business Analyst: Update Specification Post-Clarification

## Prompt Context

{RESUME_CONTEXT}

## Task

Update {SPEC_FILE} incorporating clarification answers from the user.
Ensure all answered questions are properly integrated into the specification.

## Variables

| Variable | Value |
|----------|-------|
| FEATURE_NAME | {value} |
| FEATURE_DIR | {value} |
| SPEC_FILE | {value} |
| STATE_FILE | {value} |
| FIGMA_CONTEXT_FILE | {value or null} |

## Clarification Responses to Integrate

{CLARIFICATION_ANSWERS}

## Update Process

### Step 1: Load Answered Clarifications

From `{STATE_FILE}`, extract all entries in `user_decisions.clarifications`:
```yaml
- question: "{question}"
  answer: "{user_answer}"
  ba_recommended: "{original_recommendation}"
  user_chose_recommended: true|false
  response_type: "selected"|"custom"
```

### Step 2: For Each Clarification

1. **Find the marker** in spec that triggered this question
2. **Replace the marker** with the resolved content:
   - `[NEEDS CLARIFICATION: ...]` -> Actual requirement
   - `[ASSUMPTION: ...]` -> Validated (or corrected) requirement
   - `[CONFLICT: ...]` -> Resolved decision with rationale

### Step 3: Handle Custom Responses

If `response_type: "custom"`:
- Include full custom text in the spec
- Mark with `[USER SPECIFIED]` for visibility
- Example:
  ```markdown
  ### Error Handling [USER SPECIFIED]
  User specified: "Retry 3 times with 1 second delay, then show offline mode"
  ```

## Figma Correlation (if FIGMA_CONTEXT exists)

For EACH new or modified requirement:

1. Search FIGMA_CONTEXT for matching screens
2. IF match found with confidence > 0.7:
   - Add `@FigmaRef(nodeId="{nodeId}", screen="{screen_name}")`
3. IF no match:
   - Add `[DESIGN NEEDED]` marker

**Example:**
```markdown
### FR-012: Password Reset Flow
@FigmaRef(nodeId="1:234", screen="Password Reset Screen")

As a user, I want to reset my password via email link...
```

## Update Constraints

1. **Preserve existing @FigmaRef annotations** - NEVER remove them
2. **Only ADD new annotations** for newly clarified requirements
3. **Track changes** in UPDATE_LOG section
4. **Remove resolved markers** - No `[NEEDS CLARIFICATION]` should remain for answered questions
5. **Preserve non-technical language** - After all updates, scan spec for technical terms from `spec_quality.technical_keywords_forbidden` in config. Replace any that leaked during clarification with behavioral/capability descriptions (e.g., "Room database" -> "local persistent storage")

## Output Requirements

### Spec File Updates

1. Remove all answered clarification markers
2. Add resolved content with clear formatting
3. Add @FigmaRef where appropriate
4. Add `[DESIGN NEEDED]` for requirements without design coverage

### Change Log Entry

Add to spec file:
```markdown
## Change Log

| Date | Change | Source |
|------|--------|--------|
| {today} | Integrated {N} clarification answers | Stage 4: Clarification |
```

### State File Updates

```yaml
stages:
  clarification:
    spec_updated: true
    timestamp: "{now}"
    changes_made: {count}
    markers_remaining: {count}
```
