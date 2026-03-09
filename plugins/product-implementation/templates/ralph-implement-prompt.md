# Autonomous Implementation Loop

You are executing an autonomous implementation loop via Ralph.

## Your Task
Resume the feature implementation from its current checkpoint by running:
`/product-implementation:implement`

The skill will automatically:
1. Read the state file and resume from the last checkpoint
2. Process stages and phases in order
3. Save progress after each milestone
4. Handle failures via the configured autonomy policy

## Pre-configured Settings
- Profile: {profile}
- Autonomy: auto (always auto in ralph mode)

## Feature Context
- Feature: {feature_name}
- Feature directory: {feature_dir}
- Tasks file: {feature_dir}/tasks.md

## Completion
When the implementation is fully complete (all 6 stages finished, including retrospective), output:
<promise>{completion_promise}</promise>

## Important Rules

### Anti-Escape
- NEVER output the `<promise>` tag unless ALL 6 stages are completed AND ALL tests pass
- Not even if you are stuck, confused, or want to signal completion early

### Codebase Study
- Study the existing codebase before assuming anything is missing
- Read existing code, tests, and configuration before writing new code

### Protected Files
- Do NOT manually edit: `.implementation-state.local.md`, `.stage-summaries/`, `.implementation-learnings.local.md`
- These are managed by the orchestrator — manual edits cause state corruption

### Testing Throttle
- If the same test fails 3 consecutive times within one iteration, stop retrying
- Document the failure and move on to the next task — the next iteration will retry

### Verbosity
- Keep output brief — verbosity degrades determinism across iterations
- Trust the state file for resumption — do not re-execute completed stages
- If truly stuck, document the issue — the loop will continue next iteration
