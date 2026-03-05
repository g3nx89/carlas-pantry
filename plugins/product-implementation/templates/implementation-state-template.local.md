---
version: 3                       # State schema version. v3 adds per-phase stage tracking.
feature_name: "{FEATURE_NAME}"   # e.g., "001-user-auth"
feature_dir: "{FEATURE_DIR}"     # e.g., "specs/001-user-auth"
current_stage: 1                 # 1=Setup, 2-5=Per-phase loop, 6=Retrospective
current_phase: null              # Phase currently being processed (e.g., "Phase 5: Onboarding")
phases_completed: []             # e.g., ["Phase 1: Setup", "Phase 2: Core"]
phases_remaining: []             # e.g., ["Phase 3: Integration", "Phase 4: Polish"]
phase_stages: {}                 # Per-phase stage tracking. Example:
  # "Phase 5: Onboarding":
  #   s2: "completed"
  #   s3: "completed"
  #   s4: "completed"
  #   s5: "in_progress"
stage_summaries:                 # Paths to coordinator summary files (Stage 1 and 6 only)
  "1": null                      # .stage-summaries/stage-1-summary.md
  "6": null                      # .stage-summaries/stage-6-summary.md
user_decisions:                  # Immutable once set. Valid keys:
  # NOTE: autonomy_policy is stored in the Stage 1 summary YAML, not here.
  # It flows through stage summaries to all downstream coordinators.
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
