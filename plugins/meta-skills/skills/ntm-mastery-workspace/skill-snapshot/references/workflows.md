# Workflow Templates Reference

> **Compatibility**: ntm v1.x (March 2026)

## Workflow 1: Solo Development

Single developer using agents to accelerate personal workflow.

```bash
# 1. Setup
ntm deps -v
ntm spawn myfeature --cc=2 --cod=1

# 2. Divide work
ntm send myfeature --cc "implement the /users REST endpoint with CRUD operations"
ntm send myfeature --cod "write comprehensive tests for the auth module"

# 3. Monitor progress
ntm dashboard myfeature

# 4. Checkpoint before risky changes
ntm checkpoint save myfeature -m "feature complete, pre-refactor"

# 5. Export results
ntm copy myfeature --all --output /tmp/feature-output.txt

# 6. Cleanup
ntm kill -f myfeature
```

**When to use:** Feature development, bug fixes, refactoring tasks where one person coordinates 2-4 agents.

---

## Workflow 2: Team Coordination

Multiple agent swarms working on different aspects of the same project.

```bash
# 1. Spawn separate sessions for different workstreams
ntm spawn myapi-backend --cc=3 --cod=1
ntm spawn myapi-frontend --cc=2 --gmi=1

# 2. Reserve files to prevent conflicts
ntm mail reserve myapi --agent BackendLead --paths "internal/**/*.go"
ntm mail reserve myapi --agent FrontendLead --paths "web/src/**/*.tsx"

# 3. Install pre-commit guard
ntm hooks guard install

# 4. Assign tasks
ntm send myapi-backend --cc "implement the REST API for user management"
ntm send myapi-frontend --cc "build the user dashboard with React"

# 5. Cross-session coordination via mail
ntm mail send myapi --all "API contract finalized — see openapi.yaml for latest"

# 6. Monitor both sessions
ntm --robot-status  # Overview of all sessions
ntm dashboard myapi-backend   # Deep dive into backend

# 7. Check for conflicts
ntm --robot-snapshot --since=1h | jq '.conflicts'
```

**When to use:** Large features requiring frontend+backend coordination, or multiple independent workstreams on the same codebase.

---

## Workflow 3: Code Review Ensemble

Multi-agent code review from different perspectives.

```bash
# 1. Spawn review session with diverse agents
ntm spawn review-sprint42 --cc=2 --gmi=1 --profiles=security-reviewer,performance-reviewer,maintainability-reviewer

# 2. Send the same review request to all
ntm send review-sprint42 --all "Review the changes in the PR at https://github.com/org/repo/pull/42. Focus on your area of expertise."

# 3. Monitor completion
ntm activity review-sprint42 --watch

# 4. Collect results
ntm save review-sprint42 -o /tmp/reviews/

# 5. Optional: use CASS for historical context
ntm --robot-cass-search="similar bug patterns" --cass-since=30d

# 6. Cleanup
ntm kill -f review-sprint42
```

**When to use:** Pre-merge reviews, security audits, performance evaluations where multiple perspectives add value.

---

## Workflow 4: Migration / Large Refactor

Multi-phase migration with checkpoints and conflict prevention.

```bash
# 1. Create beads for each migration phase
ntm --robot-bead-create --bead-title="Migrate auth to OAuth2" --bead-type=task --bead-priority=1
ntm --robot-bead-create --bead-title="Update API contracts" --bead-type=task --bead-priority=2
ntm --robot-bead-create --bead-title="Migrate database schema" --bead-type=task --bead-priority=1

# 2. Spawn with enough agents
ntm spawn migration --cc=3 --cod=2

# 3. Assign beads with dependency strategy
ntm --robot-assign=migration --beads=bd-1,bd-2,bd-3 --strategy=dependency

# 4. Reserve critical paths
ntm mail reserve migration --agent AuthAgent --paths "internal/auth/**"
ntm mail reserve migration --agent DbAgent --paths "migrations/**,internal/db/**"

# 5. Checkpoint at each phase completion
ntm checkpoint save migration -m "phase 1 complete: auth migrated"

# 6. Monitor health throughout
ntm health migration

# 7. Close beads as completed
ntm --robot-bead-close=bd-1 --bead-close-reason="OAuth2 migration complete"
```

**When to use:** Framework migrations, major refactors, database schema changes — work that spans multiple files and requires careful sequencing.

---

## Workflow 5: CI/CD Integration

Automated pipeline using robot mode for machine-readable output.

```bash
#!/bin/bash
# ci-agent-review.sh — Run agent-powered review in CI

SESSION="ci-review-${CI_PIPELINE_ID}"

# 1. Spawn agents
ntm --robot-spawn=$SESSION --spawn-cc=2

# 2. Send review task
ntm --robot-send=$SESSION \
  --msg="Review all changed files in this PR. Report issues as JSON." \
  --type=claude

# 3. Wait for completion
ntm --robot-ack=$SESSION --ack-timeout=300s

# 4. Collect results
RESULT=$(ntm --robot-files=$SESSION --json)
HEALTH=$(ntm --robot-health --json)

# 5. Extract findings
echo "$RESULT" | jq '.files[] | select(.status == "modified")'

# 6. Cleanup
ntm --robot-interrupt=$SESSION
ntm kill -f $SESSION

# 7. Parse exit code
if echo "$HEALTH" | jq -e '.success' > /dev/null; then
  echo "Review passed"
  exit 0
else
  echo "Review found issues"
  exit 1
fi
```

**When to use:** Automated code review in CI, scheduled codebase health checks, automated test generation pipelines.

---

## Workflow 6: Context Handoff (Long Sessions)

Managing long-running sessions where context rotation is expected.

```bash
# 1. Spawn with context rotation enabled (default)
ntm spawn longproject --cc=3

# 2. Configure rotation thresholds (if needed)
# Edit ~/.config/ntm/config.toml:
# [context_rotation]
# warning_threshold = 0.75
# try_compact_first = true

# 3. Monitor context consumption
ntm --robot-context=longproject

# 4. Watch dashboard for orange/red context bars
ntm dashboard longproject  # Press 'c' for context detail

# 5. Save checkpoints before expected rotations
ntm checkpoint save longproject -m "before context rotation"

# 6. After rotation, verify new agent has context
ntm --robot-tail=longproject --lines=30  # Check handoff summary
```

**When to use:** Multi-hour sessions, complex features requiring deep context, sessions where agent continuity matters.

---

## Workflow 7: Quick Debugging Session

Fast setup for targeted debugging.

```bash
# 1. Quick spawn focused on the bug
ntm spawn debug-auth --cc=1

# 2. Search past solutions
ntm --robot-cass-search="auth token validation error" --cass-since=30d

# 3. Send debug task with context
ntm send debug-auth --cc "There's a bug where JWT tokens fail validation after rotation. The error is in internal/auth/jwt.go:142. Investigate and fix."

# 4. Stream output in real time
ntm watch debug-auth

# 5. Quick cleanup
ntm kill -f debug-auth
```

**When to use:** Targeted bug investigation, quick prototyping, one-off analysis tasks.
