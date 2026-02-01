# Query Patterns by Server

Effective queries vary by server. This reference shows optimal patterns for each.

## Context7 Queries

Context7 works best with specific, version-aware queries.

| Quality | Query | Why |
|---------|-------|-----|
| Poor | `"auth"` | Too vague, returns generic results |
| Poor | `"hooks"` | No framework context |
| Good | `"React 19 useFormState validation"` | Version + hook + use case |
| Good | `"Next.js 15 middleware cookie validation"` | Framework + version + specific feature |
| Best | `"Express.js 5 async error handling middleware"` | Complete context |

### Skip resolve-library-id

Use library IDs directly to save a tool call:

```
# Instead of:
1. resolve-library-id("React")  → /facebook/react
2. get-library-docs("/facebook/react", topic="hooks")

# Use directly:
get-library-docs("/facebook/react", topic="useEffect cleanup async")
```

Common IDs:
- `/facebook/react`
- `/vercel/next.js`
- `/supabase/supabase`
- `/prisma/prisma`
- `/expressjs/express`

## Ref Queries

Ref performs better with full sentences than keywords.

| Quality | Query | Why |
|---------|-------|-----|
| Poor | `"figma comment api"` | Keyword style, vague |
| Poor | `"react hooks"` | No specific context |
| Good | `"Figma API endpoint for posting comments"` | Full sentence with intent |
| Good | `"React useEffect cleanup with async operations"` | Describes the problem |
| Best | `"How to handle authentication refresh tokens in Next.js middleware"` | Complete question |

### Iterative Refinement

Session deduplication enables progressive narrowing:

```
# First search (broad)
ref_search_documentation("React Server Components data fetching")
→ Read promising results

# Second search (narrow)
ref_search_documentation("React Server Components streaming with Suspense")
→ Session excludes already-seen content automatically

# Third search (specific)
ref_search_documentation("React Server Components error boundaries during streaming")
→ New results only, no duplicates
```

## Tavily Queries

Tavily needs search-engine style keywords, not conversational prompts.

| Quality | Query | Why |
|---------|-------|-----|
| Poor | `"Can you tell me everything about Tesla's Q4 earnings?"` | Conversational, wastes tokens |
| Poor | `"What's happening with AI regulation?"` | Too broad |
| Good | `"Tesla Q4 2024 earnings revenue guidance"` | Focused keywords |
| Good | `"AI regulation 2025 EU US developments"` | Time-bound, specific |
| Best | `"OpenAI GPT-5 release date announcement 2025"` | Specific entity + event + time |

### Break Complex Topics

```python
# Instead of one complex query:
"Tesla Q4 financials, competitors, guidance, leadership"

# Use multiple focused queries:
queries = [
    "Tesla Q4 2024 earnings report revenue",
    "Tesla competitors market share 2024 EV",
    "Tesla 2025 production guidance Cybertruck"
]
```

### Use Topic Parameter Correctly

```
# For news/current events:
tavily_search(query="...", topic="news", time_range="week")

# For financial data:
tavily_search(query="...", topic="finance")

# For general web search:
tavily_search(query="...", topic="general")  # default
```

## Query Length Guidelines

| Server | Optimal Length | Notes |
|--------|----------------|-------|
| Context7 | 5-15 words | Version + feature + use case |
| Ref | 10-20 words | Full sentences with context |
| Tavily | 5-10 words | Search keywords, under 400 chars |

## Common Mistakes

| Mistake | Server | Impact | Fix |
|---------|--------|--------|-----|
| Single-word queries | All | Poor results | Add context and specifics |
| No version number | Context7 | Wrong API returned | Include "React 19", "Next.js 15" |
| Conversational style | Tavily | Wasted tokens | Use search keywords |
| Keyword style | Ref | Misses relevant docs | Use full sentences |
| Repeating same query | Ref | Empty results (dedup) | Refine progressively |
