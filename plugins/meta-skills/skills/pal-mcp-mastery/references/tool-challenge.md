# challenge - Anti-Sycophancy Critical Thinking

## Purpose

Force critical evaluation of assumptions and approaches, preventing reflexive agreement and surfacing potential flaws.

## When to Use

- Before committing to major decisions
- When Claude seems too agreeable
- Devil's advocate analysis needed
- After consensus reaches agreement (check for groupthink)
- Validating assumptions you're uncertain about

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `prompt` | string | Yes | Statement or approach to challenge |

## Example Usage

```
# Challenge architectural assumption
challenge(
  prompt="Microservices are the right choice for a team of 3 developers with a 6-month runway"
)

# Challenge consensus recommendation
challenge(
  prompt="The consensus recommendation to use PostgreSQL over MongoDB for this project"
)

# Challenge implementation approach
challenge(
  prompt="Using Redis for session storage instead of database-backed sessions"
)
```

## Output Includes

- **Counterarguments** to stated position
- **Hidden assumptions** identified
- **Alternative approaches** worth considering
- **Risk factors** not explicitly acknowledged
- **Edge cases** that could invalidate the approach

## Workflow Pattern

```
# Step 1: Analyze the problem
thinkdeep(
  step="Analyze our authentication approach",
  ...
)

# Step 2: Get multi-model perspective
consensus(
  prompt="Should we use JWT or session-based auth?",
  models=["pro", "o3"]
)
# → Result: Consensus recommends JWT

# Step 3: Challenge the recommendation
challenge(
  prompt="JWT is better than session-based auth for our SPA application"
)
# → Surfaces: token revocation challenges, local storage security, etc.

# Step 4: Make informed decision with full picture
```

## Best Practices

1. **Use AFTER analysis** - not before understanding the problem
2. **Use AFTER consensus** - to check for groupthink
3. **Be specific** - challenge concrete statements, not vague ideas
4. **Don't overuse** - reserve for critical assumptions

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Challenging before investigation | Understand first, challenge after |
| Challenging every decision | Reserve for critical choices |
| Vague challenge statements | Be specific about what to challenge |
| Ignoring challenge output | Incorporate findings into decision |
