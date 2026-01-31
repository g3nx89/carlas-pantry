# apilookup - Live API Documentation

## Purpose

Force current-year API and SDK documentation lookups, preventing outdated training data responses.

## When to Use

- Working with APIs that change frequently
- New library versions
- When Claude's knowledge might be stale
- Rapidly-evolving APIs (Firebase, AWS, Stripe)
- Need for official, current documentation

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `prompt` | string | Yes | API or SDK query |

## Example Usage

```
# Current Firebase docs
apilookup(
  prompt="Firebase Authentication multi-factor authentication setup for web"
)

# Latest React features
apilookup(
  prompt="React 19 Server Components streaming data patterns"
)

# Current AWS SDK
apilookup(
  prompt="AWS SDK v3 JavaScript S3 multipart upload"
)

# Stripe API changes
apilookup(
  prompt="Stripe Payment Intents API latest changes and deprecations"
)
```

## Workflow Pattern

```
# Step 1: Get current documentation
apilookup(
  prompt="React 19 Server Components"
)

# Step 2: Discuss patterns with current knowledge
chat(
  prompt="Based on the current docs, what's the best approach for streaming?",
  model="pro",
  continuation_id="<from_apilookup>"
)

# Step 3: Deep analysis
thinkdeep(
  step="Explore error handling edge cases for streaming",
  continuation_id="<from_chat>",
  ...
)

# Step 4: Validate implementation
codereview(
  step="Verify implementation follows current best practices",
  focus_on="API usage patterns",
  ...
)
```

## Best Practices

1. **Use proactively** with rapidly-evolving APIs
2. **Don't trust training data** for recent API changes
3. **Chain with chat** to discuss findings
4. **Be specific** about what you need (version, feature, use case)

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Trusting Claude's API knowledge for new versions | Always apilookup for current APIs |
| Vague queries | Be specific: include version, feature, platform |
| Not following up | Use chat/thinkdeep to discuss findings |
| Using for stable, mature APIs | May not be needed for stable APIs |
