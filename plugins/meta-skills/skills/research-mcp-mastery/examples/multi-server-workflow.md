# Multi-Server Research Workflow

This example demonstrates combining Context7, Ref, and Tavily for comprehensive research.

## Scenario: Researching Next.js 15 Server Actions

A user asks: "How do I implement server actions in Next.js 15 with proper error handling?"

### Step 1: Official Documentation (Context7)

```
Tool: mcp__context7__get-library-docs
Parameters:
  context7CompatibleLibraryID: "/vercel/next.js"
  topic: "server actions error handling"
  tokens: 5000

Result: ~3,300 tokens of code snippets showing:
- Basic server action syntax
- useFormState patterns
- Error boundary integration
```

### Step 2: Recent Announcements (Tavily)

```
Tool: mcp__tavily__tavily_search
Parameters:
  query: "Next.js 15 server actions best practices 2025"
  topic: "news"
  time_range: "month"
  search_depth: "basic"
  max_results: 5

Result: Recent blog posts and announcements about:
- Breaking changes from v14
- New patterns introduced in v15
- Community-discovered edge cases
```

### Step 3: Deep Dive on Specific Article (Ref)

```
Tool: mcp__Ref__ref_read_url
Parameters:
  url: "https://vercel.com/blog/next-15-server-actions-guide"

Result: Full markdown content (~385 tokens) with:
- Prose explanations
- Migration warnings
- Production considerations
```

### Synthesis

Combine insights:
1. **API reference** from Context7 (official, current)
2. **Recent developments** from Tavily (community patterns, gotchas)
3. **Deep context** from Ref (full article with reasoning)

## Token Budget

| Step | Server | Tokens |
|------|--------|--------|
| 1 | Context7 | ~3,300 |
| 2 | Tavily | ~500 |
| 3 | Ref | ~385 |
| **Total** | | **~4,185** |

## Anti-Pattern: Using Only Tavily

```
# DON'T DO THIS
Tool: mcp__tavily__tavily_search
Parameters:
  query: "Next.js server actions documentation"

Result:
- 2-year-old tutorials with deprecated patterns
- Unofficial sources with incorrect syntax
- Stack Overflow answers for older versions
```

Use Context7 or Ref for documentation. Tavily only for news/current events.
