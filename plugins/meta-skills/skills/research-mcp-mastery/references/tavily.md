# Tavily MCP Server Reference

> **Compatibility**: Verified against Tavily MCP v0.3.x (January 2026)

## Overview

Tavily is the leading web search API for AI agents. Returns structured, LLM-ready JSON with relevance-scored results. Use for real-time web search, news, and content extraction - **never for library documentation**.

**93.3% accuracy** on SimpleQA benchmarks. Powers JetBrains, Cohere, MongoDB.

## Tools

### tavily_search

Real-time web search with AI-optimized ranking.

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `query` | Yes | - | Search query (under 400 chars) |
| `search_depth` | No | `basic` | `basic` (1 credit), `advanced` (2 credits), `fast`, `ultra-fast` |
| `topic` | No | `general` | `general`, `news`, or `finance` |
| `max_results` | No | 5 | Number of results (1-20) |
| `time_range` | No | - | `day`, `week`, `month`, `year` |
| `include_answer` | No | false | `true` for quick AI summary, `"advanced"` for detailed |
| `include_domains` | No | - | Whitelist domains (up to 300) |
| `exclude_domains` | No | - | Blacklist domains (up to 150) |

**Warning**: `auto_parameters` can silently upgrade to `advanced` depth (2x credits). Always set `search_depth` explicitly.

### tavily_extract

Extract clean content from specific URLs.

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `urls` | Yes | - | Array of URLs (up to 20) |
| `query` | No | - | Ranks chunks by relevance |
| `extract_depth` | No | `basic` | `basic` or `advanced` (includes tables) |
| `format` | No | `markdown` | `markdown` or `text` |

**Pricing**: 1 credit per 5 URLs (basic), 2 credits per 5 URLs (advanced).

### tavily_crawl

Intelligent website traversal with natural language guidance.

| Parameter | Description |
|-----------|-------------|
| `url` | Starting URL |
| Instructions | Natural language guidance for what to extract |

**Cost**: Combined map + extract credits.

### tavily_research

Comprehensive multi-source research reports.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `input` | Yes | Research topic |
| `model` | No | `mini` (4-110 credits) or `pro` (15-250 credits) |
| `citation_format` | No | `numbered`, `mla`, `apa`, `chicago` |
| `stream` | No | Enable for long research |

**Warning**: Costs are dynamic and unpredictable (4-250 credits). For cost-controlled workflows, use multiple `tavily_search` calls instead.

## Configuration

### Claude Code (Remote MCP - Recommended)

```bash
claude mcp add --transport http --scope user tavily \
  https://mcp.tavily.com/mcp/?tavilyApiKey=YOUR_API_KEY
```

### NPX Installation

```bash
npx -y tavily-mcp@latest
```

### Claude Desktop

```json
{
  "mcpServers": {
    "tavily-mcp": {
      "command": "npx",
      "args": ["-y", "tavily-mcp@latest"],
      "env": {
        "TAVILY_API_KEY": "tvly-YOUR_API_KEY"
      }
    }
  }
}
```

## Query Optimization

### Search Query Style (Not Prompts)

| Poor (conversational) | Good (search keywords) |
|----------------------|------------------------|
| "Can you tell me everything about Tesla's Q4 earnings?" | "Tesla Q4 2024 earnings revenue guidance" |
| "What's happening with AI regulation?" | "AI regulation 2025 EU US developments" |

### Break Complex Topics into Sub-Queries

```python
# Instead of one complex query:
"Tesla Q4 financials, competitors, guidance, leadership"

# Use multiple focused queries:
queries = [
    "Tesla Q4 2024 earnings report",
    "Tesla competitors market share 2024",
    "Tesla 2025 production guidance"
]
```

## Search Depth Trade-offs

| Depth | Credits | Use Case |
|-------|---------|----------|
| `basic` | 1 | Default for most queries |
| `advanced` | 2 | Complex queries needing multiple perspectives |
| `fast` | 1 | Real-time apps, lower latency |
| `ultra-fast` | 1 | Speed over depth |

**Start with `basic`** - upgrade only when needed.

## Response Handling

### Relevance Score Filtering

Results include `score` (0-1). Filter before LLM processing:

```python
# Only process results with score > 0.5
good_results = [r for r in results["results"] if r["score"] > 0.5]
```

Community consensus: threshold of **0.5-0.7** before passing to LLMs.

### URL Validation

Tavily's index includes pages that have gone offline. Validate URLs:

```python
import requests

def validate_urls(results):
    valid = []
    for item in results:
        try:
            r = requests.head(item["url"], timeout=3)
            if r.status_code == 200:
                valid.append(item)
        except:
            continue
    return valid
```

## Cost Management

### Pricing Tiers

| Plan | Credits/Month | Price |
|------|---------------|-------|
| Free | 1,000 | $0 |
| Project | 4,000 | $30 |
| Bootstrap | 15,000 | $100 |
| Growth | 100,000 | $500 |

**Credits don't roll over** - unused expire at month-end.

### Cost Optimization

1. **Use `basic` depth by default** (saves 50%)
2. **Batch extractions** - 5 URLs = 1 credit
3. **Filter by score** before extraction
4. **Cache results** - searches are highly repetitive
5. **Avoid `tavily_research`** for predictable costs - use multiple `tavily_search` instead

## Rate Limits

| Environment | Limit |
|-------------|-------|
| Development keys | 100 RPM |
| Production keys | 1,000 RPM |
| Crawl endpoint | 100 RPM (always) |

Implement exponential backoff for 429 errors.

## Anti-Pattern: Documentation Lookup

**Never use Tavily for library documentation.**

| Tavily Returns | Reality |
|----------------|---------|
| Outdated tutorials | 2-3 year old patterns |
| Unofficial sources | May be incorrect |
| Stack Overflow snippets | May reinforce hallucinations |

**Use Context7 or Ref instead** - they pull from official sources.

## When to Use Tavily

- Real-time web search and current events
- News with `topic="news"` and `time_range`
- Company research, market analysis
- RAG systems requiring live web data
- Discovering relevant URLs for later extraction
- Topics outside library documentation

## When NOT to Use Tavily

- Library/framework API documentation (use Context7/Ref)
- Static documentation queries
- Version-specific code examples
- Any query where official docs are preferred
