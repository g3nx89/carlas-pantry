---
stage: "{N}"
stage_name: "{Stage Name}"
checkpoint: "{CHECKPOINT_NAME}"
status: "completed"  # completed | needs-user-input | failed
artifacts_written:
  - "{artifact 1}"
summary: |
  3-5 sentence executive summary for the next stage.
flags:
  block_reason: null  # Set when status is needs-user-input
---
## Context for Next Stage

Key information the next coordinator needs to know.

## Stage Log

- [{timestamp}] Action taken
- [{timestamp}] Result
