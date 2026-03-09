---
version: 4                       # State schema version. v4 replaces quality_preset/autonomy_policy/external_models with profile/autonomy.
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
  # NOTE: autonomy is stored in the Stage 1 summary YAML, not here.
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
  ralph_mode: false                # true when running inside ralph loop
  ralph_stall_count: 0             # consecutive iterations with no progress
  ralph_stall_level: 0             # graduated stall response level (0-4)
  ralph_last_fingerprint: null     # hash of last iteration's state for stall detection
  ralph_same_error_count: 0        # consecutive iterations with same error pattern
  ralph_last_error: null           # normalized error string from last failed coordinator
  ralph_rate_limit_count: 0        # cumulative rate limit/timeout events (monitoring only)
  ralph_last_summary_lengths: {}   # per-stage summary length baselines (e.g., {"stage_2": 5000, "stage_3": 1500})
  ralph_last_test_signature: null  # sorted failing test names from Stage 3 (test result stall detection)
  ralph_test_stall_count: 0        # consecutive iterations with same test failures (independent of ralph_same_error_count)
ralph_blocked_tasks: []            # tasks annotated as blocked by graduated stall Level 3
last_checkpoint: "{ISO_TIMESTAMP}"
---
## Implementation Log
- [{ISO_TIMESTAMP}] Implementation started
- [{ISO_TIMESTAMP}] Context loaded: {N} phases, {M} tasks
