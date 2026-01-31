# planner - Incremental Planning

## Purpose

Break down complex projects into structured, actionable plans with phase validation, branching capabilities, and step-by-step tracking.

## When to Use

- Starting new features
- Architectural migrations
- Multi-sprint initiatives
- Any work requiring decomposition into manageable phases
- Before delegating to clink subagents

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `step` | string | Yes | Planning content for this step |
| `step_number` | integer | Yes | Current step (starts at 1) |
| `total_steps` | integer | Yes | Estimated total steps |
| `next_step_required` | boolean | Yes | Whether planning continues |
| `model` | string | Yes | Planning model |
| `continuation_id` | string | No | Continue from previous context |
| `is_step_revision` | boolean | No | True when replacing a step |
| `revises_step_number` | integer | No | Step being replaced |
| `is_branch_point` | boolean | No | True when creating a branch |
| `branch_from_step` | integer | No | Branching point step number |
| `branch_id` | string | No | Branch identifier |
| `more_steps_needed` | boolean | No | True when adding beyond estimate |

## Example Workflow

```
# Step 1: Describe task and scope
planner(
  step="Plan migration from PostgreSQL to CockroachDB with zero downtime",
  step_number=1,
  total_steps=4,
  next_step_required=True,
  model="pro"
)

# Step 2: Phase breakdown
planner(
  step="Phase 1: Set up CockroachDB cluster, schema migration",
  step_number=2,
  total_steps=4,
  next_step_required=True,
  model="pro",
  continuation_id="<from_step_1>"
)

# Step 3: Detailed tasks
planner(
  step="Phase 2: Dual-write implementation, data sync verification",
  step_number=3,
  total_steps=4,
  next_step_required=True,
  model="pro",
  continuation_id="<from_step_2>"
)

# Step 4: Finalize
planner(
  step="Phase 3: Cutover strategy, rollback plan, monitoring",
  step_number=4,
  total_steps=4,
  next_step_required=False,
  model="pro",
  continuation_id="<from_step_3>"
)
```

## Branching for Alternative Paths

```
# Create branch to explore alternative
planner(
  step="Alternative approach: Use CDC instead of dual-write",
  step_number=3,
  total_steps=5,
  next_step_required=True,
  model="pro",
  is_branch_point=True,
  branch_from_step=2,
  branch_id="cdc-approach",
  continuation_id="<from_step_2>"
)
```

## Revision Pattern

```
# Revise a previous step based on new info
planner(
  step="Revised Phase 1: Include index migration (missed earlier)",
  step_number=2,
  total_steps=4,
  next_step_required=True,
  model="pro",
  is_step_revision=True,
  revises_step_number=2,
  continuation_id="<from_previous>"
)
```

## Output Structure

```markdown
## Phase 1: Foundation (Days 1-3)
- [ ] Set up database schema
- [ ] Implement core data models
- [ ] Write unit tests for models

## Phase 2: API Layer (Days 4-7)
- [ ] Design REST endpoints
- [ ] Implement authentication middleware
...
```

## Best Practices

1. **Use planner before clink** - generate plan, validate, then dispatch to subagents
2. **Step 1: Always describe task and scope** comprehensively
3. **Use branching** to explore alternative approaches
4. **Revise steps** when new information changes the plan
5. **Match steps to complexity** - don't over-plan simple tasks

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Skipping step 1 description | Always start with task/scope overview |
| Not using continuation_id | Pass ID to maintain planning context |
| Over-planning simple tasks | Use chat for simple planning |
| Ignoring revision capability | Update steps when plans change |
