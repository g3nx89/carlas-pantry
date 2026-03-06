<!-- Variable sources:
  - stall_count, current_stage, current_phase, fingerprint: from state file (orchestrator section)
  - phases_completed_count, total_phases: computed from state.phases_completed and state.phases_remaining
  - last_checkpoint: from state.last_checkpoint
  - recent_summaries: last N coordinator summaries from .stage-summaries/ directory
  Note: ralph_iteration is NOT tracked in the implement skill's state file.
  The ralph-loop plugin tracks iterations externally. Use stall_count as the
  diagnostic counter instead.
-->
---
generated_at: "{ISO_TIMESTAMP}"
stall_count: {stall_count}
current_stage: {current_stage}
current_phase: "{current_phase}"
fingerprint: "{fingerprint}"
last_error: "{ralph_last_error}"
same_error_count: {ralph_same_error_count}
auto_resolutions_count: {count_of_AUTO-ralph_log_entries}
coordinator_failures: {state.orchestrator.coordinator_failures}
---

# Implementation Blockers (Ralph Loop Stall Detection)

The ralph loop has detected no progress for {stall_count} consecutive iterations.

## Current State
- **Stage**: {current_stage}
- **Phase**: {current_phase}
- **Phases completed**: {phases_completed_count}/{total_phases}
- **Last checkpoint**: {last_checkpoint}

## Recent Coordinator Summaries

{recent_summaries}

## Error History

{last_3_normalized_errors}

## Suggested Manual Intervention

1. Check the most recent stage summary for error details
2. Review the implementation log in `.implementation-state.local.md`
3. If a coordinator is repeatedly failing, check the reference file for the current stage
4. Consider running `/ralph-loop:cancel-ralph` and resuming manually with `/product-implementation:implement`
