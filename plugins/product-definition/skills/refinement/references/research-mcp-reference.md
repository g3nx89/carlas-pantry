# Research MCP Integration Reference

> **Load When:** Dispatching Stage 2 AND `state.mcp_availability.research_mcp.tavily = true`
>
> This file governs how the auto-research path uses MCP research servers to gather
> real-world market data before question generation.

---

## Tool Selection Decision Tree

```
Auto-research available? (state.mcp_availability.research_mcp)
├── tavily = true
│   ├── Market/competitive research via tavily_search (PRIMARY)
│   │   └── Draft mentions specific tech framework?
│   │       ├── YES + ref = true → Also use ref_search_documentation
│   │       └── NO → Tavily only
│   └── Generate 3-5 focused queries from draft (see Query Decomposition)
├── tavily = false, ref = true
│   └── Limited: doc lookup only (skip market research)
│       └── Only useful if draft is for a developer-facing product
└── both false
    └── Manual research flow (existing Stage 2 behavior)
```

**Core principle:** Tavily for market/business research. Ref for library/API documentation lookup. Never use Tavily to look up library documentation — it returns outdated tutorials from unofficial sources.

### Session Behavior

Both Tavily and Ref are **stateless** — each call is independent with no session memory. There is no need to "close" a session or manage connection state. If a call fails, simply retry or skip; there is no corrupted session to recover.

---

## Query Decomposition from Draft

Extract 3-5 search queries from the user's product draft using Least-to-Most decomposition:

| # | Query Category | Extract From Draft | Query Template |
|---|---------------|--------------------|----------------|
| 1 | Market Size | Product category, target market | `"{product_category} market size revenue {year}"` |
| 2 | Competitors | Product type, alternatives mentioned | `"{product_type} competitors comparison {target_audience} {year}"` |
| 3 | Target Audience | User personas, demographics | `"{target_audience} behavior trends {problem_domain} {year}"` |
| 4 | Industry Trends | Domain, regulations | `"{industry} trends regulations {year}"` |
| 5 | Tech Docs (optional) | Framework/library names | Use `ref_search_documentation` instead of Tavily |

**Year rule:** Always append current year to market/trend queries (prevents stale results).

---

## Query Patterns

### Tavily Query Optimization (Poor → Good → Best)

**Market Size:**
```
Poor:  "market for my app"
Good:  "meal planning app market size 2026"
Best:  "meal planning subscription app B2C food-tech market size revenue forecast 2026"
```

**Competitors:**
```
Poor:  "competitors"
Good:  "meal planning app competitors comparison"
Best:  "meal planning app competitors market share Mealime Yummly Whisk features pricing 2026"
```

**Target Audience:**
```
Poor:  "who wants meal planning"
Good:  "busy professionals meal planning habits"
Best:  "millennial dual-income households meal planning behavior pain points grocery spending 2026"
```

### Ref Query Optimization (for tech products)

```
Poor:  "react hooks"
Good:  "React 19 Server Components data fetching patterns"
Best:  "How to implement streaming with React 19 Server Components and Suspense boundaries"
```

---

## Anti-Patterns

| Anti-Pattern | Impact | Fix |
|---|---|---|
| Using Tavily for library API docs | Returns outdated tutorials, unofficial sources | Use Ref (`ref_search_documentation`) for library docs |
| Single broad query for all research | Shallow results, misses specifics | Decompose into 3-5 focused queries per category |
| Not filtering by relevance score | LLM processes irrelevant content, wastes tokens | Filter results with `score >= 0.5` (from config) |
| Using `advanced` search depth by default | 2x Tavily credits wasted | Use `basic` (1 credit); upgrade to `advanced` only for deep dives |
| Queries without year/date context | Returns outdated market data | Always append current year to market/trend queries |
| Passing raw search results to synthesis | Token budget exceeded, noisy output | Extract key data points, condense to 3,000 tokens max |

---

## Tavily Search Parameters

Reference: `config/requirements-config.yaml` -> `research_mcp.tavily`

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `search_depth` | `"basic"` | 1 credit/search; sufficient for market overview |
| `max_results` | `5` | Top 5 results per query; more adds noise |
| `relevance_threshold` | `0.5` | Filter below this score before processing |
| `max_searches_per_round` | `5` | Budget cap: 5 credits max per research round |
| `topic` | `"general"` | Use `"news"` only for time-sensitive queries |

### Cost Awareness

| Action | Credits | Notes |
|--------|---------|-------|
| `tavily_search` (basic) | 1 | Default for all queries |
| `tavily_search` (advanced) | 2 | Only for deep competitor analysis |
| `tavily_extract` | 1-2 | For reading full articles (use sparingly) |
| **Typical round total** | **3-5** | 3-5 searches at basic depth |

---

## Output Condensation

Auto-research results MUST be condensed into `requirements/research/research-synthesis.md` following the existing template. The output file MUST NOT exceed `config.research_mcp.token_budgets.auto_research_output` tokens (default: 3,000).

### Condensation Structure

```markdown
## Auto-Research Synthesis

**Queries executed:** {N}
**Sources analyzed:** {M}
**Generated:** {ISO_TIMESTAMP}

### Market Overview
{2-3 key findings with data points}

### Competitor Landscape
| Competitor | Key Feature | Pricing | Market Position |
|------------|-------------|---------|-----------------|
{Top 3-5 competitors from search results}

### Target Audience Insights
{2-3 behavioral insights from search results}

### Industry Trends
{2-3 relevant trends with timeline}

### Sources
| # | Title | URL | Relevance |
|---|-------|-----|-----------|
{All sources used, with relevance scores}
```

### Condensation Rules

1. **Data points over prose**: Prefer numbers, percentages, names over generic descriptions
2. **Source attribution**: Every claim must have a source URL
3. **Recency priority**: Prefer 2025-2026 sources over older content
4. **Conflict flagging**: When sources disagree, note both positions (flag for ThinkDeep)
5. **Token counting**: If condensed output exceeds budget, cut Industry Trends first, then Target Audience detail

---

## Ref Integration (Optional)

**Triggered when:** `research_mcp.ref = true` AND draft contains tech framework keywords.

**Tech keyword detection:** Scan draft for mentions of specific libraries, frameworks, or APIs (e.g., React, Next.js, Firebase, Stripe, Supabase). If found, generate 1-2 Ref queries.

```
mcp__Ref__ref_search_documentation(
  query: "{framework} {feature} documentation setup guide"
)
```

**If Ref returns results:** Append a "Technical Context" section to research-synthesis.md:
```markdown
### Technical Context (from documentation)
{1-2 paragraphs of relevant framework capabilities/limitations}
**Source:** {URL}
```

**If Ref fails or returns no results:** Skip silently. Tech context is supplementary.

---

## Error Recovery

All research MCP failures are non-blocking. See `error-handling.md` -> "Research MCP Failure Recovery" for full procedures.

**Quick reference:**
- Tavily failure → Log, notify user, offer manual research fallback
- Ref failure → Log, skip tech context, proceed with Tavily results
- Partial results (rate limit) → Use what we have, note incompleteness in synthesis
- All failures → Fall back to manual research flow (existing Stage 2 behavior)
