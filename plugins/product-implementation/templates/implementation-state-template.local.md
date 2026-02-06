---
version: 1                       # State schema version. Increment on breaking changes.
feature_name: "{FEATURE_NAME}"   # e.g., "001-user-auth"
feature_dir: "{FEATURE_DIR}"     # e.g., "specs/001-user-auth"
current_stage: 1                 # 1=Setup, 2=Execution, 3=Validation, 4=Review, 5=Documentation
phases_completed: []             # e.g., ["Phase 1: Setup", "Phase 2: Core"]
phases_remaining: []             # e.g., ["Phase 3: Integration", "Phase 4: Polish"]
user_decisions:                  # Immutable once set. Valid keys:
  # validation_outcome: "passed" | "fixed" | "proceed_anyway" | "stopped"
  # review_outcome: "fixed" | "deferred" | "accepted"
  # documentation_verification: "fixed" | "accepted_incomplete"
  # documentation_outcome: "completed"
lock:
  acquired: false
  acquired_at: null              # ISO 8601 timestamp, e.g., "2026-02-06T14:30:00Z"
  session_id: null               # Unique session identifier
last_checkpoint: "{ISO_TIMESTAMP}"
---
## Implementation Log
- [{ISO_TIMESTAMP}] Implementation started
- [{ISO_TIMESTAMP}] Context loaded: {N} phases, {M} tasks
