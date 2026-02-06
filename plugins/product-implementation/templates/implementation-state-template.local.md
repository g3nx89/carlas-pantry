---
version: 2                       # State schema version. v2 adds stage_summaries and orchestrator metadata.
feature_name: "{FEATURE_NAME}"   # e.g., "001-user-auth"
feature_dir: "{FEATURE_DIR}"     # e.g., "specs/001-user-auth"
current_stage: 1                 # 1=Setup, 2=Execution, 3=Validation, 4=Review, 5=Documentation
phases_completed: []             # e.g., ["Phase 1: Setup", "Phase 2: Core"]
phases_remaining: []             # e.g., ["Phase 3: Integration", "Phase 4: Polish"]
stage_summaries:                 # Paths to coordinator summary files
  "1": null                      # .stage-summaries/stage-1-summary.md
  "2": null                      # .stage-summaries/stage-2-summary.md
  "3": null                      # .stage-summaries/stage-3-summary.md
  "4": null                      # .stage-summaries/stage-4-summary.md
  "5": null                      # .stage-summaries/stage-5-summary.md
user_decisions:                  # Immutable once set. Valid keys:
  # validation_outcome: "passed" | "fixed" | "proceed_anyway" | "stopped"
  # review_outcome: "fixed" | "deferred" | "accepted"
  # documentation_verification: "fixed" | "accepted_incomplete"
  # documentation_outcome: "completed"
lock:
  acquired: false
  acquired_at: null              # ISO 8601 timestamp, e.g., "2026-02-06T14:30:00Z"
  session_id: null               # Unique session identifier
orchestrator:
  delegation_model: "lean_orchestrator"
  coordinator_failures: 0
  summaries_reconstructed: 0
last_checkpoint: "{ISO_TIMESTAMP}"
---
## Implementation Log
- [{ISO_TIMESTAMP}] Implementation started
- [{ISO_TIMESTAMP}] Context loaded: {N} phases, {M} tasks
