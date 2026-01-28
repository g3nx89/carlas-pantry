# Checkpoint Protocol

> **Source:** Extracted from `/product-definition:requirements` main orchestration

**After EVERY phase, you MUST:**

## 1. Update State File

```yaml
current_phase: "{PHASE_NAME}"
phase_status: "completed"
updated: "{ISO_TIMESTAMP}"
next_step: "{DESCRIPTION}"

phases:
  {phase_name}:
    status: completed
    timestamp: "{ISO_TIMESTAMP}"
```

## 2. Update Lock File

```yaml
last_activity: "{ISO_TIMESTAMP}"
```

## 3. Append to Workflow Log

```markdown
### {ISO_DATE} - Phase: {PHASE_NAME}
- **Action**: {WHAT_WAS_DONE}
- **Outcome**: SUCCESS | PARTIAL | ERROR
- **Key Outputs**: {FILES_OR_DECISIONS}
```

## 4. User Decisions (IMMUTABLE)

```yaml
user_decisions:
  {decision_key}: "{value}"
  {decision_key}_timestamp: "{ISO_TIMESTAMP}"
```

**CRITICAL:** Once a user decision is recorded, it is IMMUTABLE. Never re-ask questions that have been answered.
