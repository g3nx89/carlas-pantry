# Tavily MCP Server Reference

> **Compatibility**: Verified against Tavily MCP v0.3.x (January 2026)
>
> **Related**: See `comparison.md` for Tavily vs Context7 vs Ref decision matrix

## Overview

Tavily is the leading web search API for AI agents. Returns structured, LLM-ready JSON with relevance-scored results. Use for real-time web search, news, and content extraction - **never for library documentation**.

**93.3% accuracy** on SimpleQA benchmarks. Powers JetBrains, Cohere, MongoDB. **#1 on DeepResearchBench** (52.44), outperforming Gemini, OpenAI, and Claude on deep research tasks.

**Security**: SOC 2 certified with zero data retention. Includes prompt injection safeguards to prevent malicious webpage content from tricking agents.

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
| `chunks_per_source` | No | 1 | Chunks per source in `advanced` mode (higher = more detail per source) |
| `start_date` / `end_date` | No | - | Exact date bounds (YYYY-MM-DD format) |
| `country` | No | - | Locale boost (e.g., `"us"`) - only works with `topic=general` |
| `include_images` | No | false | Include image search results |
| `include_usage` | No | false | Return credit consumption in response |
| `include_favicon` | No | false | Return site favicons for each result |

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

**Extract depth technical details**:

| Depth | Mechanism | Latency | Capabilities |
|-------|-----------|---------|--------------|
| `basic` | HTTP GET + HTML parsing | Fast | Cannot see Client-Side Rendered (CSR) content |
| `advanced` | Headless browser (Puppeteer) | 5-15s | Scrapes SPAs, dynamic tables, bypasses basic anti-bot |

### tavily_map

Generates a sitemap of a website (page discovery without content extraction).

| Parameter | Required | Description |
|-----------|----------|-------------|
| `url` | Yes | Website URL to map |

**Use case**: Discover URLs before selective extraction. Costs map + extract credits.

### tavily_crawl

Intelligent website traversal with natural language guidance.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `url` | Yes | Starting URL |
| `max_depth` | No | Graph traversal depth (follows internal links) |
| `limit` | No | Maximum pages to crawl |
| `instructions` | No | Natural language pruning (e.g., "Ignore legal pages, focus on pricing") |

**Instructions parameter**: Tavily uses internal classification during crawl to prune paths not matching instructions, optimizing credit budget.

**Cost warning**: A `max_depth: 3` crawl on large sites can trigger hundreds of extractions. Budget carefully.

### tavily_research

Comprehensive multi-source research reports.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `input` | Yes | Research topic |
| `model` | No | `mini` (4-110 credits) or `pro` (15-250 credits) |
| `citation_format` | No | `numbered`, `mla`, `apa`, `chicago` |
| `stream` | No | Enable for long research |

**Warning**: Costs are dynamic and unpredictable (4-250 credits). For cost-controlled workflows, use multiple `tavily_search` calls instead.

**SSE Streaming**: Research takes 30-60 seconds. Use `stream: true` to receive:
- `search_query` events - shows what agent is searching
- `tool_call` events - shows internal steps
- `content` events - streams final report

**Structured Output**: Use `output_schema` parameter to enforce JSON schema on the final report for programmatic consumption. Define fields like `company_name`, `key_findings` and Tavily returns structured JSON directly usable in applications.

**Async Workflow**: Research is asynchronous - initial POST returns `request_id` and `status`. Either poll for completion or use SSE streaming. Streaming is preferred for UI-driven flows; polling with reasonable intervals for backend flows.

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

### mcp-remote Bridge (for clients without HTTP support)

```bash
npx mcp-remote https://mcp.tavily.com/mcp/?tavilyApiKey=YOUR_KEY
```

Acts as a local MCP proxy to the Tavily cloud for clients that only support local subprocess connections.

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

| Depth | Credits | Latency | Technical Execution | Best For |
|-------|---------|---------|---------------------|----------|
| `basic` | 1 | ~400-800ms | Standard keyword index lookup | Fact-checking, navigational queries |
| `advanced` | 2 | ~2-5s | Performs secondary crawl, extracts deeper content | Complex reasoning, deep research |
| `fast` (Beta) | 1 | <400ms | Optimized index, prioritizes speed over reranking | Real-time autocomplete |
| `ultra-fast` (Beta) | 1 | <200ms | Minimal processing, raw index hits | Time-critical applications |

**Start with `basic`** - upgrade only when needed.

**Insight**: `advanced` depth performs "RAG-in-a-box" - fetches page content and summarizes. For custom extraction logic, use `basic` search + targeted `tavily_extract` for more control.

**Parsing note**: `advanced` returns multiple chunks concatenated in `content` with `[...]` separators. Agents should be aware of these separators when extracting specific answers.

## Context Control Parameters

### include_answer

When `true`, Tavily uses an internal LLM to synthesize a direct answer.

**When to enable**: Simple factual queries ("What is the capital of Mongolia?")

**When to disable**: Complex queries - let main agent LLM synthesize to avoid "double-summarization" degradation.

### include_raw_content

Returns cleaned HTML/text of entire page, not just snippets.

**Risk**: Can massively inflate token count. Only use for structural queries ("Extract all headers from this page").

## Response Handling

### Response Structure

Search API returns structured JSON with:
- `query` - original search query
- `answer` - AI-generated answer (if `include_answer` was true)
- `results[]` - array of result objects
- `response_time` - latency metric
- `images[]` - image results (if `include_images` was true)

Each result object contains:
- `title`, `url`, `content` (snippet/summary)
- `raw_content` (if requested)
- `source` (domain), `favicon` (if requested)
- `score` (0-1 relevance)

Extract API returns `results[]` with `url`, `raw_content`, `images[]`, plus `failed_results[]` for URLs that couldn't be fetched.

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
4. **Cache results** - searches are highly repetitive; use semantic similarity on query embeddings to detect near-duplicate queries
5. **Avoid `tavily_research`** for predictable costs - use multiple `tavily_search` instead
6. **Progressive enhancement** - start with `basic`, escalate to `advanced` only if results are sparse
7. **Tune `max_results`** - default 5 is often sufficient; don't request 20 if 5 will do
8. **Two basics vs one advanced** - sometimes two targeted `basic` searches (2 credits) yield more unique info than one `advanced` (2 credits)

## Rate Limits

| Environment | Limit |
|-------------|-------|
| Development keys | 100 RPM |
| Production keys | 1,000 RPM |
| Crawl endpoint | 100 RPM (always) |

Implement **Exponential Backoff with Jitter**: Wait `base * 2^retries + random_jitter` ms. Jitter prevents "thundering herd" when parallel agents retry simultaneously.

## Error Codes

| Code | Error | Likely Cause | Remediation |
|------|-------|--------------|-------------|
| 400 | Bad Request | Invalid parameter combo, malformed JSON | Validate JSON; `days` only works with `topic="news"` |
| 401 | Unauthorized | Invalid API key | Rotate key, check .env file loading |
| 429 | Rate Limited | Exceeded RPM limit | Implement backoff, check for runaway loops |
| 500 | Internal Error | Tavily backend instability | Fallback to `basic` depth or different provider |

## Debugging MCP Connections

If Claude Desktop shows "Disconnected" for Tavily:

1. **Check Node version**: `node -v` (requires Node 18+)
2. **Check path**: `which npx` - ensure Claude's environment can see it
3. **Check logs**: `~/Library/Logs/Claude/mcp.log` (macOS) - shows auth failures and errors

## Enterprise Features

**X-Project-ID Header**: For multi-agent environments, send `X-Project-ID: <project_id>` to:
- Segment usage logs by agent
- Enable per-agent billing reporting
- Internal cost allocation ("Marketing Bot" vs "Legal Bot")

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

## Tavily vs Alternatives

| Feature | Tavily | Exa.ai | Perplexity |
|---------|--------|--------|------------|
| **Mechanism** | Keyword-heavy, factual | Neural/embeddings (meaning-based) | Synthesized answers |
| **Best Query Style** | "Apple stock price today" | "Blog post explaining transformers like I'm five" | Quick Q&A |
| **Agent Control** | High (raw data) | High (semantic URLs) | Low (pre-cooked answers) |
| **Use Case** | RAG/Fact agents | Discovery/Recommendation | Simple answers |

**Strategic Recommendation**: Coding agents should have both Tavily (StackOverflow, GitHub Issues) and Ref (official docs) connected simultaneously.

## Framework Integrations

| Framework | Integration |
|-----------|-------------|
| **LangChain** | Use `langchain-tavily` package (older `tavily_search.tool` deprecated) |
| **LlamaIndex** | Native Tavily retriever support |
| **Vercel AI SDK** | Direct integration |
| **Google ADK** | Agent SDK connector |
| **n8n/Zapier** | HTTP node with API key header |

**Pattern**: Combine Tavily with other MCP servers (e.g., Neo4j for graph queries + Tavily for web) to let agents reason about when to use each source.
