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
# protocol_evidence: (Required for Stages 2-5, omit for Stages 1 and 6)
#   agents_dispatched:             # List of {type, template_used, phase} for each agent dispatch
#     - {type: "developer", template_used: "Phase Implementation Prompt", phase: "Phase 1: Setup"}
#   prompt_templates_used: []      # Template names from agent-prompts.md actually used
#   phases_executed_sequentially: true  # true if phases ran one-at-a-time, false if parallel
#   per_phase_steps_completed: {}  # Map of phase_name → list of step IDs completed
#     # Example: {"Phase 1: Setup": ["1.9", "2", "2.5", "3", "3.5"]}
---
## Context for Next Stage

Key information the next coordinator needs to know.

## Stage Log

- [{timestamp}] Action taken
- [{timestamp}] Result
