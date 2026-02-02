# Tavily MCP server: technical manual for AI agent integration

Tavily is the leading search API purpose-built for AI agents, offering real-time web search, content extraction, and deep research capabilities via a unified API optimized for LLM consumption. **The platform serves over 700,000 developers** and powers AI systems for JetBrains, Cohere, MongoDB, and major Fortune 500 companies. This manual provides everything needed to integrate Tavily effectively into AI agent workflows, including when to use it versus documentation-specific servers like Context7 or Ref.

For AI agent builders, Tavily's key advantage is returning **structured, LLM-ready JSON** with relevance-scored results, pre-extracted content, and optional AI-generated summaries—eliminating the glue code typically required between retrieval and prompt construction. The platform achieves **93.3% accuracy on SimpleQA benchmarks** and its Research API ranks #1 on DeepResearch Bench.

---

## Technical architecture and API reference

### Core endpoints and their purposes

Tavily's API provides six main endpoints accessed via `https://api.tavily.com`:

| Endpoint | Purpose | Credit cost |
|----------|---------|-------------|
| `/search` | Web search with AI-optimized ranking | 1-2 credits |
| `/extract` | Content extraction from specific URLs | 1-2 credits per 5 URLs |
| `/crawl` | Intelligent website traversal | Combined map + extract cost |
| `/map` | Site structure discovery | 1-2 credits per 10 pages |
| `/research` | Comprehensive multi-source reports | 4-250 credits (dynamic) |
| `/usage` | API consumption monitoring | Free |

Authentication uses Bearer tokens: `Authorization: Bearer tvly-YOUR_API_KEY`. Keys are obtained at app.tavily.com, with the free tier providing **1,000 credits monthly**.

### The tavily_search endpoint parameters

The search endpoint is the workhorse for most AI agent integrations. Key parameters include:

**Query and depth settings:**
- `query` (required): Search query under 400 characters for best results
- `search_depth`: Controls quality vs latency—`basic` (1 credit), `advanced` (2 credits), `fast` (1 credit), or `ultra-fast` (1 credit)
- `topic`: Search category—`general`, `news`, or `finance`—affecting source prioritization
- `max_results`: Number of results (1-20, default 5)

**Content options:**
- `include_answer`: Set to `true` for quick AI summary, `"advanced"` for detailed analysis
- `include_raw_content`: Returns full page content as `"markdown"` or `"text"`
- `include_images`: Returns query-related images
- `chunks_per_source`: Number of semantic snippets per source (1-3, advanced depth only)

**Filtering capabilities:**
- `time_range`: Recency filter—`day`, `week`, `month`, or `year`
- `start_date` / `end_date`: Custom date range in YYYY-MM-DD format
- `include_domains`: Whitelist up to 300 domains
- `exclude_domains`: Blacklist up to 150 domains
- `country`: Boost results from specific countries (general topic only)

**The `auto_parameters` option** lets Tavily automatically configure search settings based on query intent—useful but may silently upgrade to advanced search depth, doubling credit cost.

### Understanding search depth tradeoffs

The four depth options serve different use cases:

**Basic depth** returns one NLP-generated summary per URL, balancing relevance and latency at **1 credit**. Use this for general queries where comprehensive snippets aren't critical.

**Advanced depth** returns multiple semantic chunks per URL with higher relevance at **2 credits**. The additional cost buys better results for complex queries requiring nuanced information—for example, finding specific statistics buried in long documents.

**Fast and ultra-fast depths** optimize for latency at **1 credit** each. Fast returns multiple snippets while ultra-fast returns single summaries. Choose these for real-time applications where speed matters more than depth.

### The tavily_extract endpoint

Extract retrieves clean content from specific URLs you've already identified—up to **20 URLs per request**:

```python
response = tavily_client.extract(
    urls=["https://example.com/article1", "https://example.com/article2"],
    query="machine learning applications",  # Optional: ranks chunks by relevance
    extract_depth="basic",  # "basic" or "advanced" (includes tables)
    chunks_per_source=3,  # 1-5 chunks per source
    format="markdown"  # "markdown" or "text"
)
```

**Pricing**: 1 credit per 5 successful URLs (basic) or 2 credits per 5 URLs (advanced). Failed extractions aren't charged.

### The tavily_research endpoint for deep research

The research endpoint automates multi-step research workflows, generating comprehensive reports with citations:

```python
response = tavily_client.research(
    input="Research the latest developments in quantum computing",
    model="pro",  # "mini" (4-110 credits) or "pro" (15-250 credits)
    citation_format="numbered",  # "numbered", "mla", "apa", "chicago"
    stream=True  # Enable streaming for long research
)
```

**Credit costs are dynamic and unpredictable**—ranging from 4-250 credits depending on query complexity. Use `mini` for straightforward fact-finding and `pro` for comprehensive topics requiring depth.

### Response format structure

Search responses return structured JSON optimized for LLM consumption:

```json
{
  "query": "string",
  "answer": "AI-generated summary (if include_answer=true)",
  "results": [
    {
      "title": "Page title",
      "url": "https://example.com",
      "content": "Relevant snippets",
      "score": 0.85,  // Relevance score 0-1
      "raw_content": "Full markdown (if requested)",
      "published_date": "2025-01-15 (news topic only)"
    }
  ],
  "response_time": 1.67,
  "usage": {"credits": 1}
}
```

**The relevance score** (0-1) is critical for filtering—community consensus suggests using thresholds of **0.5-0.7** before passing results to LLMs.

### Pricing tiers and rate limits

| Plan | Monthly credits | Price | Per credit |
|------|-----------------|-------|------------|
| Free (Researcher) | 1,000 | $0 | — |
| Project | 4,000 | $30 | $0.0075 |
| Bootstrap | 15,000 | $100 | $0.0067 |
| Startup | 38,000 | $220 | $0.0058 |
| Growth | 100,000 | $500 | $0.005 |
| Pay-as-you-go | Per usage | — | $0.008 |

**Rate limits**: Development keys allow 100 RPM; production keys (requires paid plan) allow 1,000 RPM. The crawl endpoint has a separate 100 RPM limit regardless of environment.

**Important**: Credits don't roll over monthly—unused credits expire at month-end.

---

## MCP server implementation and configuration

### Official MCP server repository

Tavily maintains an official MCP server at **github.com/tavily-ai/tavily-mcp** (970+ stars) providing production-ready integration with Claude Desktop, Claude Code, Cursor, and VS Code.

**Installation options:**

```bash
# NPX (recommended)
npx -y tavily-mcp@latest

# Smithery auto-install
npx -y @smithery/cli install @tavily-ai/tavily-mcp --client claude

# Docker
docker run -i --rm -e TAVILY_API_KEY mcp/tavily
```

### Claude Desktop configuration

For Claude Desktop, edit the configuration file:
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "tavily-mcp": {
      "command": "npx",
      "args": ["-y", "tavily-mcp@latest"],
      "env": {
        "TAVILY_API_KEY": "tvly-YOUR_API_KEY",
        "DEFAULT_PARAMETERS": "{\"search_depth\": \"basic\", \"max_results\": 10}"
      }
    }
  }
}
```

### Claude Code CLI integration

The simplest approach uses Tavily's remote MCP server:

```bash
# Add globally (available across all projects)
claude mcp add --transport http --scope user tavily \
  https://mcp.tavily.com/mcp/?tavilyApiKey=YOUR_API_KEY

# Verify connection
claude
/mcp
```

### Cursor IDE configuration

In your `mcp.json` file:

```json
{
  "mcpServers": {
    "tavily-remote-mcp": {
      "command": "npx -y mcp-remote https://mcp.tavily.com/mcp/?tavilyApiKey=YOUR_API_KEY",
      "env": {}
    }
  }
}
```

### MCP tools exposed

The MCP server exposes four tools:

**tavily-search**: Real-time web search with parameters for query, search_depth, topic, time_range, max_results, include_domains, exclude_domains, and country.

**tavily-extract**: Content extraction from up to 20 URLs with extract_depth and format options.

**tavily-map**: Site structure discovery returning URL lists for planning crawls.

**tavily-crawl**: Systematic website exploration with natural language instructions for guidance.

---

## Use cases and workflow patterns

### Real-time information retrieval for coding agents

Tavily excels at providing current information that LLMs' training data doesn't cover. Trigger web search when:

- Queries contain temporal markers ("today", "latest", "2025")
- Users ask about current events, prices, or time-sensitive data
- Factual verification is needed for LLM-generated claims
- Domain-specific information from authoritative sources is required

```python
def should_search_web(query: str) -> bool:
    temporal_patterns = ["today", "latest", "current", "2025", "recent", "now"]
    factual_patterns = ["price", "stock", "weather", "score", "result", "news"]
    query_lower = query.lower()
    return any(p in query_lower for p in temporal_patterns + factual_patterns)
```

### Deep research mode workflows

The Research API automates multi-step research but requires careful cost management. Use it for:

- Comprehensive topic research requiring synthesis from many sources
- Report generation with proper citations
- Complex queries that would require 10+ individual searches
- When thoroughness matters more than cost

**Warning**: Research costs are unpredictable (4-250 credits). For cost-controlled workflows, implement your own multi-search pattern using standard search:

```python
async def controlled_deep_research(topic: str, max_credits: int = 20):
    queries = generate_sub_queries(topic)  # Break into focused queries
    results = []
    credits_used = 0
    
    for query in queries:
        if credits_used >= max_credits:
            break
        response = await tavily_client.search(query, search_depth="basic")
        results.append(response)
        credits_used += 1
    
    return synthesize_results(results)
```

### News and current events queries

For news-specific searches, use the `news` topic with time filtering:

```python
response = tavily_client.search(
    query="AI regulation developments",
    topic="news",
    time_range="week",
    max_results=10,
    include_answer=True
)
```

The `news` topic returns `published_date` metadata and prioritizes mainstream media sources.

### LangChain integration patterns

LangChain provides the most mature Tavily integration via `langchain-tavily`:

```python
from langchain_tavily import TavilySearch, TavilyExtract
from langchain.agents import create_openai_tools_agent, AgentExecutor

# Initialize tools
search_tool = TavilySearch(max_results=5, topic="general")
extract_tool = TavilyExtract(extract_depth="advanced")

# Create agent
agent = create_openai_tools_agent(llm=llm, tools=[search_tool, extract_tool], prompt=prompt)
executor = AgentExecutor(agent=agent, tools=[search_tool, extract_tool])

# Run
response = executor.invoke({"messages": [HumanMessage(content="Research AI trends")]})
```

### LlamaIndex integration for RAG

LlamaIndex supports Tavily through `llama-index-tools-tavily-research`:

```python
from llama_index.tools.tavily_research import TavilyToolSpec
from llama_index.core.agent.workflow import FunctionAgent

tavily_tool = TavilyToolSpec(api_key="your-key")
agent = FunctionAgent(
    tools=tavily_tool.to_tool_list(),
    llm=OpenAI(model="gpt-4o"),
    system_prompt="Search the web for current information."
)

response = await agent.run("What's the latest on quantum computing?")
```

### Fact-checking workflow pattern

Combine search and extraction for verification:

```python
async def fact_check(claim: str) -> dict:
    # 1. Search for evidence
    search_results = await tavily_client.search(
        query=claim,
        search_depth="advanced",
        max_results=10
    )
    
    # 2. Filter by relevance
    top_urls = [r["url"] for r in search_results["results"] if r["score"] > 0.7]
    
    # 3. Extract full content
    extracted = await tavily_client.extract(urls=top_urls[:5])
    
    # 4. LLM analysis
    return llm.analyze(claim=claim, evidence=extracted)
```

---

## Best practices for effective usage

### Query optimization strategies

**Keep queries under 400 characters**—think search query, not LLM prompt:

```python
# Good: Focused, keyword-rich
{"query": "Tesla Q4 2024 earnings revenue"}

# Bad: Conversational, too long
{"query": "Can you tell me everything about Tesla's financial performance in the fourth quarter of 2024 including revenue, profit margins, and guidance?"}
```

**Break complex research into sub-queries:**

```python
# Instead of one complex query, use multiple focused ones:
queries = [
    "Tesla Q4 2024 earnings report",
    "Tesla competitors market share 2024",
    "Tesla 2025 production guidance"
]
```

### Choosing the right tool

| Scenario | Tool | Why |
|----------|------|-----|
| Finding relevant pages | `search` | Discovery, ranked results |
| Need full content from known URLs | `extract` | Direct extraction, no search overhead |
| Comprehensive research reports | `research` | Automated multi-step synthesis |
| Understanding site structure | `map` | URL discovery before crawling |
| Scraping entire sites | `crawl` | Systematic extraction |

**The optimal two-step pattern** for thorough research:

```python
# 1. Search to discover URLs
results = await tavily_client.search(query, max_results=20)

# 2. Filter by relevance score
good_urls = [r["url"] for r in results["results"] if r["score"] > 0.5]

# 3. Extract full content from best sources
extracted = await tavily_client.extract(urls=good_urls[:10])
```

### Cost management techniques

**Use basic search by default**—advanced costs 2x credits but only matters for complex queries requiring multiple perspectives.

**Implement caching** for repeated queries. A Redis cache can reduce costs by **30-50%** in typical applications.

**Monitor auto_parameters**—it may silently upgrade to advanced depth. Override explicitly:

```python
{"query": "AI news", "auto_parameters": True, "search_depth": "basic"}
```

**Batch extractions**—5 URLs cost the same as 1 URL (1 credit for basic).

### When to use Tavily versus documentation servers

**Use Tavily for:**
- Real-time web search and current events
- Company research, market analysis, news
- General queries across diverse sources
- RAG systems requiring live web data
- Discovering relevant URLs

**Use Context7 or Ref for:**
- Programming library documentation
- API reference lookup
- Version-specific code examples
- Static documentation queries

**The key insight**: LLMs often hallucinate about APIs due to outdated training data. Context7/Ref fetch latest official docs, while Tavily searches the general web—which may return outdated tutorials or unofficial sources for documentation queries.

**Recommended pattern:**

```markdown
1. Use Context7/Ref for library documentation
2. Use Tavily for general web research and current events
3. Fall back to Tavily only when doc servers don't have the library
```

### Domain filtering for quality results

**Whitelist authoritative sources** for specific query types:

```python
# Company research
{"query": "Apple financials", "include_domains": ["sec.gov", "investor.apple.com"]}

# Academic research
{"query": "climate change studies", "include_domains": ["nature.com", "sciencedirect.com"]}

# Professional profiles
{"query": "CEO background", "include_domains": ["linkedin.com/in"]}
```

Keep domain lists **short and focused**—overly broad filtering degrades results.

---

## Antipatterns and common pitfalls

### Queries that waste API credits

**Overly long queries** perform poorly. Tavily optimizes for search-style queries, not prompts:

```python
# Wastes credits with poor results
{"query": "I need you to find comprehensive information about everything related to..."}

# Effective
{"query": "quantum computing breakthroughs 2025"}
```

**Not breaking down complex queries** leads to unfocused results. A single query asking about "competitors, financials, news, and leadership" will return mediocre results for all topics. Run separate focused queries instead.

**Setting max_results too high** (>10) often returns increasingly irrelevant results while using the same credits.

### Over-relying on Tavily for documentation

Using Tavily to look up programming documentation is a common antipattern. Results often include:
- Outdated tutorials from years ago
- Unofficial sources with incorrect information  
- Content that reinforces LLM hallucinations

**Solution**: Use Context7 or Ref for documentation lookup, which pull from official sources.

### Not validating URLs

Tavily's index includes pages that have since gone offline. **Validate URLs before using them**:

```python
import requests

def validate_results(results):
    valid = []
    for item in results:
        try:
            response = requests.head(item["url"], timeout=3, allow_redirects=True)
            if response.status_code == 200:
                valid.append(item)
        except:
            continue
    return valid
```

### Trusting auto_parameters without override

The `auto_parameters` feature can upgrade `search_depth` to advanced based on query intent, **doubling your credit cost**. Always set `search_depth` explicitly when cost control matters.

### Ignoring relevance scores

Processing all results regardless of score wastes LLM tokens on irrelevant content. Filter by score threshold:

```python
good_results = [r for r in results["results"] if r["score"] > 0.5]
```

### Known limitations to account for

**Stale content**: Tavily pulls from indexed sources that may be outdated. Critical applications should validate freshness.

**JavaScript-rendered pages**: Content from heavily JS-dependent pages may be incomplete or missing.

**Dynamic research costs**: The Research API costs 4-250 credits per request with no way to predict cost upfront.

**English optimization**: Tavily is primarily optimized for English content—test thoroughly for other languages.

---

## Community insights and comparisons

### How Tavily compares to alternatives

| Aspect | Tavily | Perplexity API | Exa | Serper |
|--------|--------|----------------|-----|--------|
| **Best for** | RAG systems | Speed + citations | Semantic search | High volume |
| **Output** | Structured JSON | Synthesized answers | Meaning-based | Raw SERP |
| **Latency** | Medium | Fastest (~358ms) | Variable | Fast |
| **Price (100K)** | ~$500-800 | ~$500 | Enterprise | ~$50-75 |
| **Dev effort** | Low | Lowest | Medium | Highest |

**Community consensus**: "Tavily is the safe choice—reliable, well-integrated, largest developer community. Worth the cost if quality matters."

**For ultra-high-volume, budget-constrained applications**: Consider Serper + custom extraction, accepting higher development cost for lower API cost.

**For speed-critical applications**: Perplexity Sonar offers the lowest latency.

**For semantic/conceptual research**: Exa's embedding-based search may outperform keyword-based approaches.

### Real user experiences

**Positive feedback** centers on ease of integration, LLM-ready output format, and strong framework support. Users report getting Tavily working with LangChain "in under 15 minutes."

**Common complaints** include:
- Dead links from cached indexes (solution: validate URLs)
- Occasional content quality issues with cookie banners and navigation in raw content
- Unpredictable Research API costs
- Rate limiting surprises with development keys

### Cost optimization tips from production users

1. **Cache aggressively**—search queries are highly repetitive
2. **Use basic depth unless advanced is truly needed** (saves 50% credits)
3. **Filter by score before extraction** (0.5-0.7 threshold)
4. **Batch URL extractions** (5 URLs = 1 credit)
5. **Monitor credit consumption**—unused credits expire monthly

### Rate limit handling in agentic workflows

Implement exponential backoff with jitter:

```python
async def search_with_retry(client, query, max_retries=3):
    for attempt in range(max_retries):
        try:
            return await client.search(query)
        except RateLimitError:
            wait = (2 ** attempt) + random.uniform(0, 1)
            await asyncio.sleep(wait)
    raise Exception("Max retries exceeded")
```

Development keys have strict limits (100 RPM)—production keys require paid plan or PAYGO enabled for 1,000 RPM.

---

## Conclusion

Tavily provides the most mature, well-integrated search API for AI agent workflows, with native support for LangChain, LlamaIndex, and Claude via MCP. Its strength lies in **returning LLM-ready structured data** that eliminates retrieval-to-prompt glue code.

**Key recommendations for effective integration:**

Use **basic search depth by default** and reserve advanced for complex queries requiring multiple perspectives. **Validate URLs** from search results before using them, as cached indexes include stale pages. **Filter results by relevance score** (>0.5) before LLM processing. **Don't use Tavily for documentation lookup**—Context7 or Ref provide more accurate, up-to-date library documentation.

For production deployments, implement **caching and rate limit handling** from the start. The Research API's dynamic pricing (4-250 credits) makes cost prediction challenging—consider building controlled multi-search workflows instead for predictable costs.

The platform's SOC 2 compliance, zero data retention, and enterprise features make it suitable for production AI applications, while the generous free tier (1,000 credits monthly) enables experimentation. For budget-constrained high-volume applications, consider hybrid approaches—Tavily for quality-critical queries, cheaper alternatives like Serper for volume.