# Context7 MCP Server: Complete technical manual

Context7 is the leading MCP server for injecting up-to-date library documentation into AI coding assistants, solving the persistent problem of LLMs generating deprecated APIs and hallucinated method signatures. Developed by Upstash and boasting **43,000+ GitHub stars**, it serves as a critical bridge between AI models and current documentation for 3,570+ libraries. This manual covers everything developers need to deploy, configure, and optimize Context7 effectively.

## How Context7 works under the hood

Context7 operates through a two-step resolution process that transforms natural language library mentions into structured documentation retrieval. When an LLM receives a coding question, it first calls `resolve-library-id` to convert a library name (like "React") into a Context7-compatible identifier (`/facebook/react`), then calls `get-library-docs` to fetch semantically-relevant documentation snippets.

The server supports three transport mechanisms: **stdio** for local MCP integrations (the default), **HTTP/Streamable HTTP** via the `/mcp` endpoint, and **SSE** (deprecated) for streaming connections. Most users should prefer the remote HTTP transport at `https://mcp.context7.com/mcp` for reliability, though stdio works well for air-gapped environments or strict network policies.

### The two core tools

**`resolve-library-id`** accepts a `libraryName` string and returns up to 10 matching libraries with metadata including trust scores, benchmark scores, available versions, and total indexed snippets. The LLM selects the appropriate match and proceeds to documentation retrieval. Users who know their library ID can skip this step entirely by using the `/org/project` format directly in prompts.

**`get-library-docs`** fetches documentation using three parameters: the required `context7CompatibleLibraryID` (e.g., `/vercel/next.js`), an optional `topic` for focusing results (e.g., "routing"), and an optional `tokens` limit (default: 5000, minimum: 1000). The response contains an array of documentation snippets with titles, content, and source URLs.

### Token consumption and the January 2026 optimization

Token usage was Context7's most criticized limitation—early versions averaged **~9.7k tokens per lookup** with 3.95 tool calls and 24-second latency. After Upstash implemented server-side reranking in January 2026, these metrics improved dramatically:

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Average tokens | 9.7k | 3.3k | 65% reduction |
| Tool calls | 3.95 | 2.96 | 30% reduction |
| Latency | 24s | 15s | 38% reduction |

The new architecture performs vector search with proprietary reranking on the server side, sending only the most relevant snippets rather than everything matching the query. Code examples rank higher than prose, and API signatures rank higher than descriptions.

## Configuration across major AI coding platforms

### Claude Code integration

For Claude Code, the remote server approach requires no local dependencies:

```bash
# With API key (recommended)
claude mcp add --header "CONTEXT7_API_KEY: YOUR_API_KEY" --transport http context7 https://mcp.context7.com/mcp

# Without API key (lower rate limits)
claude mcp add --transport http context7 https://mcp.context7.com/mcp
```

Local installation requires Node.js 18+:

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp --api-key YOUR_API_KEY
```

Claude Code users should add rules to `CLAUDE.md` for automatic invocation:

```markdown
When you need documentation, use `context7` tools.
- Before suggesting code for any external library, use resolve-library-id and get-library-docs
- Never rely on training data for framework APIs (Next.js, React, Vue, Rails)
- Pull docs first, then code
```

### Cursor configuration

For Cursor 1.0+, add to `~/.cursor/mcp.json` or `.cursor/mcp.json` in your project:

```json
{
  "mcpServers": {
    "context7": {
      "url": "https://mcp.context7.com/mcp",
      "headers": {
        "CONTEXT7_API_KEY": "YOUR_API_KEY"
      }
    }
  }
}
```

### Windsurf and VS Code

Windsurf uses the SSE endpoint:
```json
{
  "mcpServers": {
    "context7": {
      "serverUrl": "https://mcp.context7.com/sse"
    }
  }
}
```

VS Code with GitHub Copilot:
```json
{
  "mcp": {
    "servers": {
      "context7": {
        "type": "http",
        "url": "https://mcp.context7.com/mcp"
      }
    }
  }
}
```

### Environment variables and configuration options

| Variable | Description | Default |
|----------|-------------|---------|
| `CONTEXT7_API_KEY` | Authentication key (format: `ctx7sk-*`) | None |
| `DEFAULT_MINIMUM_TOKENS` | Minimum token count for responses | 10000 |
| `https_proxy` / `HTTPS_PROXY` | HTTP proxy for corporate networks | None |

The server accepts API keys through multiple header formats: `Authorization`, `Context7-API-Key`, `X-API-Key`, and their lowercase/underscore variants.

## When to use Context7 versus alternatives

Context7 excels at **library and framework documentation** for rapidly-evolving projects like Next.js, React, Supabase, and TailwindCSS. It's particularly valuable when working with version-specific APIs (Next.js 14 vs 15 have significant differences) or niche libraries that LLMs weren't well-trained on.

**Choose Context7 when:**
- Generating code that depends on specific library APIs
- Working with frameworks that iterate rapidly (Next.js, Astro, SvelteKit)
- Needing version-specific documentation
- Avoiding hallucinated method signatures

**Choose web search instead when:**
- Researching blog posts, tutorials, or Stack Overflow discussions
- Comparing alternative libraries
- Debugging error messages with community solutions
- Accessing content beyond code documentation

**Consider alternatives like Ref.tools when:**
- You need PDF documentation support (Context7 doesn't support PDFs)
- Private repository documentation is essential (paid add-on for Context7, included in Ref)
- Token efficiency is critical (Ref adapts between 500-5k tokens vs Context7's consistent ~3k)
- You need explanatory prose and warnings, not just code snippets

## Query optimization strategies for better results

The single most impactful optimization is **query specificity**. Context7's vector search and reranking work best with descriptive queries:

| Poor query | Optimized query |
|------------|-----------------|
| "auth" | "How to set up authentication with JWT in Express.js" |
| "hooks" | "React useEffect cleanup function with async operations" |
| "middleware" | "Next.js 15 middleware setup with cookie validation" |

**Use library IDs directly** to skip the resolution step and reduce latency:
```
Implement basic authentication with Supabase. use library /supabase/supabase for API and docs
```

**Limit tool calls to 3 per question**—this is explicitly stated in Context7's documentation. If you haven't found what you need after 3 calls, work with the best available result.

**Set up auto-invoke rules** to eliminate typing "use context7" in every prompt. Add this to your client's rules configuration:
```
Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.
```

## Combining Context7 with other MCP servers

Context7 pairs well with complementary MCP servers for comprehensive workflows:

| MCP Server | Combined Use Case |
|------------|-------------------|
| Filesystem | Read project files while getting docs for dependencies |
| GitHub | Access repository code with API documentation |
| Playwright | Browser automation with current API docs |
| Sequential Thinking | Complex multi-step implementations |
| Perplexity | Difficult technical questions beyond documentation |

A power user on Hacker News described their workflow: "I only use 2 MCP servers—context7 and perplexity. For things like updated docs, I have it ask context7... For the more difficult technical tasks where I think it's going to stumble, I'll instruct Claude Code to ask perplexity."

List frequently-used servers first in your configuration—this affects tool resolution priority when conflicts exist.

## Common mistakes and antipatterns to avoid

**Configuration errors** cause most Context7 failures. The most frequent mistakes:

1. **Missing "Bearer" prefix** in HTTP transport authentication headers
2. **Using outdated packages**—always specify `@upstash/context7-mcp@latest`
3. **Transport mode confusion**—don't mix HTTP and stdio configurations
4. **Relative npx paths on Windows/macOS**—use full paths like `C:\\Program Files\\nodejs\\node.exe`

**Query mistakes** that waste tokens:

1. Making vague, single-word queries
2. Calling tools more than 3 times per question
3. Forgetting to call `resolve-library-id` before `get-library-docs`
4. Including sensitive data (API keys, passwords) in queries
5. Not specifying version numbers for frameworks with breaking changes

**Workflow mistakes**:

1. Using Context7 for tasks requiring explanatory prose (it returns code snippets only)
2. Expecting real-time documentation updates (there's indexing lag)
3. Relying on Context7 for private repositories without a paid plan
4. Not caching responses (documentation updates infrequently—cache for hours)

## Rate limits and how to handle them

Context7 dramatically reduced its free tier in January 2026—from ~6,000 requests/month to 500 (later increased to 1,000). The free plan allows **60 requests per hour**.

Users without API keys frequently report rate limiting disrupting their workflows. GitHub Issue #808 documents users "being rate limited on every request since last 24 hours" even with 12-hour gaps between requests.

**Workarounds:**
1. Get a free API key at context7.com/dashboard for higher limits
2. Cache responses locally—documentation changes infrequently
3. Batch requests with larger token limits instead of multiple small calls
4. Monitor usage in the dashboard to stay within limits

HTTP 429 responses indicate rate limiting. Implement exponential backoff:
```python
def fetch_with_retry(url, headers, max_retries=3):
    for attempt in range(max_retries):
        response = requests.get(url, headers=headers)
        if response.status_code == 429:
            time.sleep(2 ** attempt)
            continue
        return response
```

## Known limitations and edge cases

**Technical constraints:**
- **Code snippets only**—Context7 limits results to pre-extracted code, missing context, explanations, and warnings
- **No PDF support**—cannot index or retrieve PDF documentation
- **No file upload**—unlike competitors like Ref.tools
- **Paid repo indexing**—Context7 charges to index private repositories
- **Batch retrieval model**—agents pick a library but don't control which specific pages to read

**Platform-specific issues:**
- Windows/macOS timeout errors require full Node.js paths
- Node.js < v18 is incompatible
- ESM resolution errors need `--experimental-vm-modules` flag
- Corporate proxies require special configuration

**Documentation coverage gaps:**
- Active cleanup of duplicate libraries (Issue #339 with 54+ comments)
- "Documentation not found or not finalized" errors even after successful library loading
- Niche libraries may have incomplete coverage
- Rapidly-changing libraries may lag behind releases

## Community perspective and real-world feedback

Community sentiment is **largely positive with important caveats**. Developers consistently praise Context7 for solving the outdated-documentation problem—one Hacker News user noted it's "significantly better than relying solely on training data" for new frameworks like Rails 8.

The XDA Developers article highlighted success with niche technologies like ESPHome and CounterStrikeSharp modding, where vanilla LLMs "consistently failed with invalid syntax" but Context7-enhanced models produced near-working configurations.

The primary criticism centers on **token consumption**. One Hacker News commenter warned: "Context7 injects a *huge* amount of tokens into your context, which leads to a very low signal/noise ratio." This concern drove the January 2026 optimization.

Privacy-conscious users note that Context7's "closed-source ingestion and querying pose security/privacy risks"—alternatives like Openground offer full user control over indexed content.

## Conclusion

Context7 represents the current state-of-the-art for providing AI coding assistants with accurate, up-to-date library documentation. The January 2026 architecture improvements addressed the most significant criticism (token bloat), making it substantially more practical for daily use. For developers working with rapidly-evolving frameworks, the value proposition is clear: accurate documentation on first try versus debugging hallucinated APIs.

The optimal deployment strategy uses the remote HTTP transport with an API key, auto-invoke rules to eliminate manual triggering, and direct library IDs when known. Pair Context7 with Perplexity or web search for questions beyond documentation scope, and consider Ref.tools if you need PDF support or private repository documentation without additional fees.

Key numbers to remember: **3,570+ indexed libraries**, **~3.3k average tokens per query** (post-optimization), **60 requests/hour** on the free tier, and **3 maximum tool calls per question**.