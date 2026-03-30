# Feature List JSON Schema

The feature list is the single source of truth for implementation progress. It uses JSON
(not Markdown) because models are less likely to inappropriately modify structured JSON
than Markdown prose — a finding from Anthropic's harness research.

## Schema

```json
{
  "feature_name": "string — name of the feature being implemented",
  "plan_source": "string — relative path to tasks.md",
  "created": "string — ISO 8601 timestamp",
  "features": [
    {
      "id": "string — task ID from tasks.md (e.g., '1.1', '2.3')",
      "phase": "string — phase name (e.g., 'Foundation', 'Core Features')",
      "description": "string — what this task implements (IMMUTABLE)",
      "acceptance_criteria": [
        "string — each criterion from tasks.md (IMMUTABLE)"
      ],
      "dependencies": ["string — IDs of tasks that must complete first"],
      "passes": "boolean — true only when ALL criteria verified (MUTABLE)"
    }
  ]
}
```

## Immutability Rules

Only the `passes` field may be modified by the implementing agent. All other fields are
locked at generation time. This prevents premature victory — the agent can't redefine
success by editing the criteria.

If a criterion genuinely needs to change (e.g., the user decides to skip something),
the user must make the edit themselves or explicitly approve the change.

## Conversion Algorithm: tasks.md → feature-list.json

### Input Format (typical tasks.md from product-planning)

```markdown
## Phase 1: Foundation

### Task 1.1: Set up project structure
**Acceptance Criteria:**
- [ ] Project directory follows standard layout
- [ ] Build configuration produces working artifact
- [ ] CI pipeline runs on push

### Task 1.2: Create data models
**Acceptance Criteria:**
- [ ] Entity classes match design.md schema
- [ ] Database migrations generated and tested
```

### Conversion Steps

1. Parse each `## Phase N: {name}` as a phase
2. Parse each `### Task {id}: {description}` as a feature
3. Extract acceptance criteria from `- [ ] {criterion}` lines under each task
4. Extract dependencies from any "Depends on:" or "After:" annotations
5. Set all `passes` to `false`
6. Set `created` to current ISO 8601 timestamp
7. Set `plan_source` to the relative path of tasks.md

### Output Example

```json
{
  "feature_name": "User Authentication",
  "plan_source": "features/user-auth/tasks.md",
  "created": "2026-03-31T10:00:00Z",
  "features": [
    {
      "id": "1.1",
      "phase": "Foundation",
      "description": "Set up project structure",
      "acceptance_criteria": [
        "Project directory follows standard layout",
        "Build configuration produces working artifact",
        "CI pipeline runs on push"
      ],
      "dependencies": [],
      "passes": false
    },
    {
      "id": "1.2",
      "phase": "Foundation",
      "description": "Create data models",
      "acceptance_criteria": [
        "Entity classes match design.md schema",
        "Database migrations generated and tested"
      ],
      "dependencies": ["1.1"],
      "passes": false
    }
  ]
}
```

## Usage in Sessions

At session startup, the agent reads feature-list.json and:
1. Finds the first feature with `passes: false` whose dependencies all have `passes: true`
2. Works on that one feature
3. After verifying all acceptance criteria, sets `passes: true`
4. Commits the change to feature-list.json along with the implementation
