# Context7 MCP Server Reference

> **Compatibility**: Verified against Context7 remote MCP API v2.x (January 2026)

## Overview

Context7 fetches up-to-date library documentation snippets for 20K+ libraries. Solves the problem of LLMs generating deprecated APIs from stale training data.

## Tools

### resolve-library-id

Converts library name to Context7-compatible ID.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `libraryName` | Yes | Library name (e.g., "React", "Next.js") |

**Returns**: Up to 10 matching libraries with metadata (trust scores, versions, snippet counts).

**Skip this step** by using IDs directly in prompts:
- `/facebook/react`
- `/vercel/next.js`
- `/supabase/supabase`

### get-library-docs

Fetches documentation snippets.

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `context7CompatibleLibraryID` | Yes | - | Library ID (e.g., `/vercel/next.js`) |
| `topic` | No | - | Focus area (e.g., "routing", "authentication") |
| `tokens` | No | 5000 | Token limit (min: 1000) |

**Returns**: Array of code snippets with titles and source URLs.

## Configuration

### Claude Code (Remote - Recommended)

```bash
# With API key (higher limits)
claude mcp add --header "CONTEXT7_API_KEY: YOUR_KEY" --transport http context7 https://mcp.context7.com/mcp

# Without API key (60 req/hour limit)
claude mcp add --transport http context7 https://mcp.context7.com/mcp
```

### Claude Code (Local)

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp --api-key YOUR_KEY
```

### CLAUDE.md Auto-Invoke Rule

```markdown
When generating code for external libraries:
- Before suggesting code for any external library, use resolve-library-id and get-library-docs
- Never rely on training data for framework APIs (Next.js, React, Vue, Rails)
- Pull docs first, then code
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `CONTEXT7_API_KEY` | API key (format: `ctx7sk-*`) |
| `DEFAULT_MINIMUM_TOKENS` | Min token response (default: 10000) |

## Query Optimization

### Good vs Poor Queries

| Poor | Good |
|------|------|
| "auth" | "How to set up authentication with JWT in Express.js" |
| "hooks" | "React useEffect cleanup function with async operations" |
| "middleware" | "Next.js 15 middleware setup with cookie validation" |

### Best Practices

1. **Use library IDs directly** to skip resolve step and reduce latency
2. **Include version numbers** for frameworks with breaking changes
3. **Limit to 3 tool calls** per question - work with best result after that
4. **Be specific** - include language, framework, exact use case

## Token Profile

Post-January 2026 optimization:
- **Average tokens per query**: ~3.3k (down from 9.7k)
- **Average tool calls**: 2.96 (down from 3.95)
- **Average latency**: 15s (down from 24s)

Code examples rank higher than prose. API signatures rank higher than descriptions.

## Rate Limits

| Plan | Requests |
|------|----------|
| Free (no key) | 60/hour, 500-1000/month |
| With API key | Higher limits (check dashboard) |

HTTP 429 = rate limited. Implement exponential backoff.

## Known Limitations

1. **Code snippets only** - no prose explanations or warnings
2. **No PDF support** - cannot index PDF documentation
3. **No file upload** - cannot add custom docs
4. **Paid private repos** - Context7 charges extra for private repo indexing
5. **Indexing lag** - rapidly-changing libraries may lag behind releases
6. **Node.js 18+ required** for local installation

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| "Documentation not found" | Library not indexed | Try Ref or request addition |
| Rate limit (429) | Too many requests | Add API key or implement backoff |
| Timeout | Network or Node issue | Use full paths on Windows/macOS |
| ESM resolution error | Node version | Use `--experimental-vm-modules` |

## When to Choose Context7

> Full comparison: See `comparison.md` for detailed decision matrix.

**Best for**: Quick mainstream library lookups, maximum coverage (20K+), direct library ID usage.
