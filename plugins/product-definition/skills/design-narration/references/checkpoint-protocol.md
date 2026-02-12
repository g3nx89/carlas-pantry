---
stage: all
artifacts_written:
  - design-narration/.narration-state.local.md (updated)
---

# Checkpoint Protocol

> Shared reference for state checkpointing across all Design Narration stages.
> "Checkpoint after every screen" (SKILL.md Rule 3) — this file defines the exact procedure.

## CRITICAL RULES (must follow)

1. **Checkpoint BEFORE user interaction**: Update state file before any AskUserQuestion call.
2. **Lock refresh on every checkpoint**: Update lock file timestamp to prevent stale-lock detection.
3. **Decisions are append-only**: Never overwrite a decision record — append revision with `revises` pointer.

---

## Checkpoint Sequence

Execute these steps in order after each screen sign-off, stage transition, or decision recording:

### Step 1: Refresh Lock

```
UPDATE design-narration/.narration-lock timestamp to current ISO time
```

### Step 2: Update State YAML Frontmatter

```yaml
# Always update:
current_stage: {STAGE_NUMBER}
screens_completed: {COUNT}

# Per-screen (after sign-off):
screens:
  - node_id: "{NODE_ID}"
    name: "{SCREEN_NAME}"
    status: signed_off      # or: pending | in_progress | described | critiqued | questions_asked | refined
    narrative_file: "screens/{nodeId}-{name}.md"
    screenshot_file: "figma/{nodeId}-{name}.png"
    critique_scores:
      completeness: {1-4}
      interaction_clarity: {1-4}
      state_coverage: {1-4}
      navigation_context: {1-4}
      ambiguity: {1-4}
      total: {X}
    flagged_for_review: {true|false}
```

### Step 3: Append Decision Records (if any)

For each new user decision or revision:

```yaml
decisions_audit_trail:
  - id: "{screen}-q{N}"
    screen: "{SCREEN_NAME}"
    question: "{QUESTION_TEXT}"
    answer: "{ANSWER_TEXT}"
    timestamp: "{ISO}"

  # If revising a prior decision:
  - id: "{screen}-q{N}-rev{M}"
    screen: "{SCREEN_NAME}"
    revises: "{original_id}"
    question: "{QUESTION_TEXT}"
    answer: "{NEW_ANSWER}"
    revision_reason: "{REASON}"
    timestamp: "{ISO}"
```

### Step 4: Update Patterns (ONLY on screen sign-off)

```
IF checkpoint trigger is screen sign-off:
    UPDATE patterns in state file:
        patterns:
          shared_components: [merged list]
          navigation_patterns: [merged list]
          naming_conventions: [merged list]
          interaction_patterns: [merged list]

IF checkpoint trigger is stage transition or decision recording:
    SKIP this step — patterns accumulate only during screen sign-off.
```

### Step 5: Append Workflow Log Entry

Append to the markdown body (below YAML frontmatter) of the state file:

```markdown
### {ISO_TIMESTAMP} - {EVENT_TYPE}
- **Screen**: {SCREEN_NAME} (or "N/A" for stage transitions)
- **Action**: {WHAT_HAPPENED}
- **Status**: {screen_status or stage advancement}
```

---

## Integrity Verification

After every checkpoint, verify:

1. State file is valid YAML (frontmatter parses without error)
2. `screens_completed` count matches number of screens with `status: signed_off`
3. Lock file timestamp is within last `state.lock_freshness_check_minutes` (from config)
4. No decision records reference nonexistent screen names

---

## When to Checkpoint

| Event | Checkpoint Required? |
|-------|---------------------|
| After screen analysis (2A) completes | Yes — update screen status to `described` |
| After each Q&A batch answer recorded | Yes — save answers immediately |
| After refinement (2B) completes | Yes — update critique scores |
| After parallel refinement batch completes (2B.6 parallel) | Yes — single checkpoint after ALL file-based results collected |
| After auto-resolve gate runs (any stage) | Yes — append auto_resolved_questions, update registry file |
| After screen sign-off | Yes — full checkpoint (all 5 steps) |
| Before presenting AskUserQuestion | Yes — ensures state survives if user abandons session |
| After stage transition (2→3, 3→4, 4→5) | Yes — update `current_stage` |
| After error recovery | Yes — update stage and log error |

## CRITICAL RULES REMINDER

1. Checkpoint BEFORE user interaction
2. Lock refresh on every checkpoint
3. Decisions are append-only
