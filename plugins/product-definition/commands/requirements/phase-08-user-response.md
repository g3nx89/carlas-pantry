# Phase 8: User Response Collection

> **Source:** Extracted from `/product-definition:requirements` main orchestration

**Checkpoint:** `USER_RESPONSE`

**Goal:** Present questions to user and pause workflow for offline file-based response.

## Step 8.1: Notify User

```markdown
## Questions Ready for Your Response

**Round:** {N}
**Questions:** {COUNT}
**File:** `requirements/working/QUESTIONS-{NNN}.md`

### Instructions:

1. Open `requirements/working/QUESTIONS-{NNN}.md`
2. For each question, mark your choice with `[x]`
3. If selecting "Other (custom answer)", fill in the text field
4. Add any notes in the Notes section
5. Save the file

**When ready to continue:**
```
/product-definition:requirements
```

**Git Suggestion (after filling):**
```
git add requirements/working/QUESTIONS-{NNN}.md
git commit -m "answer(req): round {N} responses completed"
```
```

## Step 8.2: Update State

```yaml
current_phase: "USER_RESPONSE"
phase_status: "waiting_for_user"
waiting_for_user: true
next_step: "Fill QUESTIONS-{NNN}.md and run /product-definition:requirements"

phases:
  user_response:
    status: waiting_for_user
    round: {N}
    questions_file: "{PATH}"
```

EXIT (user pause)
