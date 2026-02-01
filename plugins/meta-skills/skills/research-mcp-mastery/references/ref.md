# Ref.tools MCP Server Reference

> **Compatibility**: Verified against Ref.tools API v1.x (January 2026)
>
> **Related**: See `comparison.md` for Ref vs Context7 vs Tavily decision matrix

## Overview

Ref delivers 60-95% token reduction over Context7 via search-then-read architecture. Returns prose + code (not just snippets). Includes free private repo and PDF indexing.

**Key differentiator**: Agent-controlled retrieval. Search first, then selectively read only what's needed.

### Architecture: The "Dropout" Mechanism

Ref's session intelligence is powered by the **Dropout mechanism** - a server-side deduplication system that:

1. **Tracks shown content** - Every result returned is fingerprinted
2. **Filters future queries** - Subsequent searches "drop out" already-seen content
3. **Enables progressive refinement** - Refining queries never wastes tokens on duplicates
4. **Accumulates context** - The more searched, the more unique each result becomes

**Why this matters**: Unlike Context7 (stateless), Ref sessions build cumulative understanding. A third query in a session is more valuable than the first.

**Transport matters**: HTTP transport (recommended) provides better session persistence than stdio. Stdio may lose session state on restarts.

### Smart Chunking ("Contextual Chunking")

When `ref_read_url` fetches a documentation page, Ref doesn't return the entire page:

1. **Filters by relevance** - Uses session history and query terms to extract relevant sections
2. **Limits to ~5K tokens** - From a 90K-token API reference, returns only ~5K that matter
3. **Deep links** - Returns URL fragments (e.g., `#merge`) to jump to specific sections

This prevents the common issue where large doc pages flood context with irrelevant tokens.

## Tools

### ref_search_documentation

Primary search interface for documentation.

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `query` | Yes | - | Full sentence works best (not keywords) |
| `keyWords` | No | - | Additional grep-like filtering |
| `source` | No | `'all'` | `'public'`, `'private'`, or `'all'` |

**Returns**: URLs with snippets (~54 tokens typical). Use `ref_read_url` to read full pages.

### ref_read_url

Fetches any URL and converts to markdown.

| Parameter | Required | Description |
|-----------|----------|-------------|
| URL | Yes | Any web URL (from search results or known) |

**Returns**: Markdown content, session-aware truncated to ~5,000 relevant tokens.

### ref_search_web

Fallback web search when documentation search fails.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `query` | Yes | Search query |

**Disable if docs-only needed**: Set `DISABLE_SEARCH_WEB=true` or `?disable_search_web=true` in URL.

## Configuration

### Claude Code (Streamable HTTP - Recommended)

```json
"Ref": {
  "type": "http",
  "url": "https://api.ref.tools/mcp?apiKey=YOUR_API_KEY"
}
```

### Claude Code (stdio)

```json
"Ref": {
  "command": "npx",
  "args": ["ref-tools-mcp@latest"],
  "env": { "REF_API_KEY": "YOUR_API_KEY" }
}
```

### Via mcp-remote (for clients without HTTP support)

```json
"Ref": {
  "command": "npx",
  "args": ["-y", "mcp-remote@0.1.0-0", "https://api.ref.tools/mcp", "--header=x-ref-api-key:YOUR_KEY"]
}
```

### Environment Variables

| Variable | Default | Recommended | Description |
|----------|---------|-------------|-------------|
| `REF_API_KEY` | None | Required | Authentication token (format: `ref_*`) |
| `REF_ALPHA` | None | If provided | Alpha access token (alternative to REF_API_KEY) |
| `REF_URL` | api.ref.tools | Don't change | Custom API endpoint (for testing only) |
| `DISABLE_SEARCH_WEB` | false | As needed | Set `true` to disable web fallback |
| `TRANSPORT` | stdio | http | Transport mode (`stdio` or `http`) |
| `PORT` | 8080 | As needed | Port for HTTP mode |
| `MCP_TIMEOUT` | 10000ms | **300000ms** | Startup timeout. Ref can take longer on complex indexing operations |
| `MCP_TOOL_TIMEOUT` | 30000ms | **120000ms** | Execution timeout. Deep searches on large repos may exceed 30s |

**Timeout Bottleneck**: Private repo indexing and PDF processing can exceed default timeouts. Set `MCP_TIMEOUT=300000` (5 minutes) for reliability.

**Email Verification Required**: API key won't work until email is verified. Unverified keys return 401 "verify your email" error.

## Query Optimization

### Full Sentences Beat Keywords

| Poor (keyword style) | Good (full context) |
|---------------------|---------------------|
| "figma comment api" | "Figma API post comment endpoint documentation" |
| "react hooks" | "React useEffect cleanup with async operations" |

### Iterative Refinement Pattern

Session deduplication prevents duplicate results, enabling progressive refinement:

```
1. Start broad: "React Server Components data fetching"
2. Read promising results
3. Narrow: "React Server Components streaming with Suspense"
4. Session excludes already-seen content automatically
```

## Session Behavior

Ref's MCP session provides:

1. **Deduplication filtering** - Same/similar searches never return duplicates
2. **Session-aware truncation** - Reads drop less relevant sections based on search history
3. **Pre-fetching** - Search results cached for faster reads
4. **Link memory** - Previously shown links excluded from future results

**Implication**: Re-reading content requires `ref_read_url` with the URL directly - searching again returns empty due to deduplication.

## Token Profile

| Metric | Ref | Context7 |
|--------|-----|----------|
| Search | ~54 tokens | N/A (batch) |
| Read | ~385 tokens | ~3,300 tokens |
| Total typical | 439 tokens | 3,300+ tokens |
| Multi-library | Efficient | 3.3k × libraries |

**Adaptive range**: 500-5,000 tokens based on query complexity.

## Private Resources Setup

At ref.tools/resources:

1. **GitHub repos**: Connect via OAuth for automatic indexing
2. **PDF upload**: Upload documentation files
3. **Markdown files**: Index custom docs
4. **Search**: Use `source: 'private'` to scope queries

### Private Repo Sync Details

Ref uses intelligent indexing based on repository size:

| Repo Size | Indexing Behavior |
|-----------|-------------------|
| **<2,000 files** | All code indexed (full codebase search) |
| **>2,000 files** | Docs only (README, /docs, markdown) |

**Sync mechanism**:
- **Frequency**: 5-minute cron job checks for changes
- **Method**: Incremental indexing (only changed files re-indexed)
- **Trigger**: Push to default branch or manual refresh

**Implication**: For large codebases, ensure documentation is comprehensive since code files won't be indexed.

## Pricing

| Plan | Cost | Credits |
|------|------|---------|
| Free | $0 | 200 (never expire) |
| Basic | $9/month | 1,000/month |
| Team | $9/member/month | Pooled credits |

Compare: Context7 ~$10 for 500 queries. Ref: $9 for 1,000.

**Credit consumption**: Each tool invocation consumes one credit (whether search or read). An iterative workflow (search→read→search→read) uses multiple credits, but token savings often offset LLM costs.

### Session Management

Sessions persist context across queries within a conversation. To reset:
- **HTTP**: Send DELETE to `/mcp` endpoint
- **Stdio**: Close and reopen the connection

Reset when topic completely changes and fresh results are needed.

## Deep Research Mode

Ref includes aliases for extended research workflows:

| Alias | Purpose |
|-------|---------|
| `ref_deep_research` | Extended multi-source synthesis |
| `ref_comprehensive_search` | Broader search scope |

**Note**: These are convenience aliases and may consume additional credits.

## Combining with Other MCP Servers

Ref complements other research tools:

| Combination | Use Case |
|-------------|----------|
| **Ref + Context7** | Ref for prose explanations, Context7 for quick code snippets |
| **Ref + Tavily** | Ref for indexed docs, Tavily for current events/news |
| **Ref + SequentialThinking** | Better reasoning over complex documentation |

**Pattern**: Use Ref's session deduplication for iterative research, then Tavily for current context.

## Known Limitations

1. **Smaller library coverage** - 1000s vs Context7's 20K+
2. **Not self-hostable** - Requires ref.tools API (beta signup available)
3. **Docker issue #35** - Hardcoded `TRANSPORT=http` conflicts with Docker MCP Gateway
4. **Large repo indexing** - Repos >2K files only index documentation

## Supported IDE Integrations

Ref works with any MCP-compatible client:
- **Cursor** - Native HTTP support, Inspector UI for debugging
- **VS Code** - Via extensions
- **Zed** - Native MCP support
- **Vim (Augment)** - Via plugin
- **Windsurf/Antigravity** - AI coding assistants
- **Claude Code** - Via MCP configuration
- **ChatGPT plugins** - Tools aliased to `search`/`fetch` for OpenAI compatibility

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| Authentication failure | API key format | Verify key, try different transport |
| 401 "verify your email" | Email not verified | Check email, click verification link |
| Smithery hang | Mac + Codex client | Use direct `npx` installation |
| Web search overuse | Query too vague | Add library/framework names |
| No results (library exists) | Not indexed yet | Request addition via docs site |
| Session returns empty | Deduplication active | Use `ref_read_url` for re-reads |

## Anti-Patterns to Avoid

| Anti-Pattern | Why It Hurts | Better Approach |
|--------------|--------------|-----------------|
| **New chat per question** | Loses session deduplication, resets Dropout mechanism | Keep conversation in single session |
| **"Read everything" fallacy** | Wasting tokens on exhaustive reads | Search → read selectively |
| **Keyword-only queries** | Poor semantic matching | Use full sentences with context |
| **Ignoring session state** | Re-searching already-seen content | Use `ref_read_url` directly for re-reads |
| **Not scoping to `private`** | Noise from public docs | Add `source: 'private'` when using private repos |

## When NOT to Use Ref

| Scenario | Why Not | Alternative |
|----------|---------|-------------|
| Quick mainstream library lookup | Context7 faster for well-indexed libs | Context7 with library ID |
| Real-time news/events | Not designed for current events | Tavily with `topic="news"` |
| Broad web research | Limited to indexed sources | Tavily for web-wide search |
| Already know exact URL | No search needed | WebFetch or `ref_read_url` directly |

## When to Choose Ref

> Full comparison: See `comparison.md` for detailed decision matrix.

**Best for**: Prose + code output, private repos (free), PDFs, token-sensitive workflows, session deduplication.

**Choose Ref over Context7 when**:
- Need explanations, not just code snippets
- Working with private company documentation
- PDF documentation is involved
- Token budget is tight (adaptive 500-5k vs fixed 3.3k)
- Long conversation benefits from session deduplication
