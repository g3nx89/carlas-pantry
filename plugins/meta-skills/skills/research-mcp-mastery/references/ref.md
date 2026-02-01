# Ref.tools MCP Server Reference

> **Compatibility**: Verified against Ref.tools API v1.x (January 2026)

## Overview

Ref delivers 60-95% token reduction over Context7 via search-then-read architecture. Returns prose + code (not just snippets). Includes free private repo and PDF indexing.

**Key differentiator**: Agent-controlled retrieval. Search first, then selectively read only what's needed.

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

| Variable | Purpose |
|----------|---------|
| `REF_API_KEY` | Required authentication token |
| `DISABLE_SEARCH_WEB` | Set `true` to disable web fallback |

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

## Pricing

| Plan | Cost | Credits |
|------|------|---------|
| Free | $0 | 200 (never expire) |
| Basic | $9/month | 1,000/month |
| Team | $9/member/month | Pooled credits |

Compare: Context7 ~$10 for 500 queries. Ref: $9 for 1,000.

## Known Limitations

1. **Smaller library coverage** - 1000s vs Context7's 20K+
2. **Not self-hostable** - Requires ref.tools API (beta signup available)
3. **Docker issue #35** - Hardcoded `TRANSPORT=http` conflicts with Docker MCP Gateway

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| Authentication failure | API key format | Verify key, try different transport |
| Smithery hang | Mac + Codex client | Use direct `npx` installation |
| Web search overuse | Query too vague | Add library/framework names |

## When to Choose Ref

> Full comparison: See `comparison.md` for detailed decision matrix.

**Best for**: Prose + code output, private repos (free), PDFs, token-sensitive workflows, session deduplication.
