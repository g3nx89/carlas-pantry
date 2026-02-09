# Checkpoint Protocol

> Shared reference for all stages in the Requirements Refinement workflow.

**After EVERY stage completes, you MUST:**

## 1. Update State File

```yaml
current_stage: {STAGE_NUMBER}
stage_status: "completed"
updated: "{ISO_TIMESTAMP}"
next_step: "{DESCRIPTION}"

stages:
  {stage_name}:
    status: completed
    timestamp: "{ISO_TIMESTAMP}"
```

## 2. Update Lock File

```yaml
last_activity: "{ISO_TIMESTAMP}"
```

## 3. Append to Workflow Log

Append to the markdown body (below YAML frontmatter) of `requirements/.requirements-state.local.md`:

```markdown
### {ISO_DATE} - Stage {STAGE_NUMBER}: {STAGE_NAME}
- **Action**: {WHAT_WAS_DONE}
- **Outcome**: SUCCESS | PARTIAL | ERROR
- **Key Outputs**: {FILES_OR_DECISIONS}
```

## 4. Write Stage Summary

Write to `requirements/.stage-summaries/stage-{N}-summary.md` with YAML frontmatter following the summary contract in SKILL.md.

## 5. User Decisions (IMMUTABLE)

```yaml
user_decisions:
  {decision_key}: "{value}"
  {decision_key}_timestamp: "{ISO_TIMESTAMP}"
```

**CRITICAL:** Once a user decision is recorded, it is IMMUTABLE. Never re-ask questions that have been answered.
