# Research MCP Servers: Detailed Comparison

> **Compatibility**: Context7 API v2.x, Ref API v1.x, Tavily MCP v0.3.x (January 2026)

## Architectural Differences

| Aspect | Context7 | Ref | Tavily |
|--------|----------|-----|--------|
| **Model** | Select → Batch return | Search → Read selectively | Search → Extract |
| **Token control** | Fixed ~3.3k | Adaptive 500-5k | Variable |
| **Multi-source** | 3.3k × libraries | Single efficient query | Per search |
| **Session state** | None | Deduplication + memory | None |

### Context7: Batch Retrieval

```
resolve-library-id("React") → /facebook/react
get-library-docs("/facebook/react", topic="hooks") → ~3,300 tokens
```

Fixed token cost regardless of actual information needed.

### Ref: Search-Then-Read

```
ref_search_documentation("React hooks cleanup async") → 54 tokens
ref_read_url(best_result_url) → 385 tokens
Total: 439 tokens
```

Agent controls exactly what gets consumed.

### Tavily: Web Search + Extract

```
tavily_search("React 19 features") → Variable tokens, URLs
tavily_extract(urls=[...]) → Full content
```

Searches entire web, not curated documentation.

## Feature Comparison Matrix

| Feature | Context7 | Ref | Tavily |
|---------|----------|-----|--------|
| Library coverage | 20K+ | 1000s | N/A (web) |
| Output type | Code snippets only | Code + prose + warnings | Web content |
| Private repos | Paid add-on | **Free** | N/A |
| PDF support | No | **Yes** | No |
| Token efficiency | Fixed 3.3k | Adaptive 500-5k | Variable |
| Session dedup | No | **Yes** | No |
| Real-time web | No | Via fallback | **Yes** |
| News/events | No | No | **Yes** |

## Pricing Comparison (1000 queries)

| Server | Cost | Notes |
|--------|------|-------|
| Context7 | ~$20 | Based on free tier limits |
| Ref | **$9** | 1000 credits/month |
| Tavily | ~$8 (basic) | 1-2 credits per search |

## Decision Matrix by Scenario

### Documentation Lookup

| Scenario | Best Choice | Why |
|----------|-------------|-----|
| React/Next.js API | Context7 | Excellent mainstream coverage |
| Need prose explanations | Ref | Returns context, not just code |
| Private company docs | Ref | Free private repo indexing |
| PDF documentation | Ref | Only option with PDF support |
| Niche library | Ref | Search-based finds more |
| Quick version-specific | Context7 | Direct ID, no search step |

### Research Tasks

| Scenario | Best Choice | Why |
|----------|-------------|-----|
| Current events | Tavily | Real-time web search |
| Company research | Tavily | News, financials, announcements |
| Market analysis | Tavily | Cross-source synthesis |
| Blog posts/tutorials | Ref or Tavily | Ref `ref_read_url` or Tavily extract |
| Error troubleshooting | Tavily | Stack Overflow, GitHub issues |

### Token-Sensitive Workflows

| Scenario | Best Choice | Why |
|----------|-------------|-----|
| Production AI agents | Ref | Adaptive token budget |
| Multi-library lookup | Ref | Single query vs N × 3.3k |
| Simple single lookup | Context7 | Predictable, fast |
| Long conversation | Ref | Session deduplication |

## Overlapping Scenarios: Resolution Guide

### "I need React documentation"

1. **Quick API lookup, know the method?** → Context7 (direct ID)
2. **Need explanation of how it works?** → Ref (returns prose)
3. **Looking for community patterns?** → Tavily (tutorials, SO)

### "I need to understand this library"

1. **Popular library?** → Context7 first, Ref for gaps
2. **Niche library?** → Ref first, fallback to Tavily
3. **Private/internal?** → Ref only

### "I need current information"

1. **About a library release?** → Tavily `topic="news"` + Context7/Ref for docs
2. **About a company/product?** → Tavily only
3. **About market trends?** → Tavily only

### "I need to read a specific page"

1. **Documentation page?** → Ref `ref_read_url` (better markdown, session tracking)
2. **Blog/tutorial?** → Ref `ref_read_url` or Tavily `tavily_extract`
3. **News article?** → Tavily `tavily_extract`

## Combining Servers

Servers can coexist. Example multi-tool workflow:

```
1. User asks about "Next.js 15 server actions best practices"

2. Context7: get-library-docs("/vercel/next.js", topic="server actions")
   → API reference, code patterns (~3.3k tokens)

3. Tavily: tavily_search("Next.js 15 server actions", topic="news", time_range="month")
   → Recent announcements, blog posts

4. Ref: ref_read_url(interesting_blog_url)
   → Full content of specific article (~385 tokens)
```

## Performance Characteristics

| Metric | Context7 | Ref | Tavily |
|--------|----------|-----|--------|
| Latency (typical) | 15s | Variable | 1-3s |
| Rate limit (free) | 60/hr | 200 total | 100 RPM |
| Cold start | Fast (remote) | Fast | Fast |
| Batch efficiency | Fixed | High | 5 URLs/credit |

## Known Issues and Workarounds

| Issue | Server | Workaround |
|-------|--------|------------|
| Rate limiting | Context7 | Add API key, cache results |
| Stale content | Tavily | Validate URLs before use |
| Session quirks | Ref | Use `ref_read_url` for re-reads |
| No private repos | Context7 | Use Ref instead |
| No PDFs | Context7 | Use Ref instead |
| Outdated tutorials | Tavily | Never use for library docs |

## Parameter Naming Notes

The `topic` parameter exists in both Context7 and Tavily but with different meanings:

| Server | Parameter | Values | Meaning |
|--------|-----------|--------|---------|
| Context7 | `topic` | Free text | Focus area within library (e.g., "routing", "hooks") |
| Tavily | `topic` | `general`, `news`, `finance` | Content category for source prioritization |

**Implication**: When switching between servers, do not assume parameter semantics are equivalent.

## Recommendation Summary

**Default to:**
- **Context7** for quick mainstream library lookups
- **Ref** for comprehensive research, private docs, or token-sensitive work
- **Tavily** for anything real-time, news, or web-wide

**Never:**
- Use Tavily for library documentation lookup
- Call Context7 more than 3 times per question
- Ignore Ref's session deduplication (refine queries freely)
