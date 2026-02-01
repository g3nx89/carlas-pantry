# Context7 MCP Server Reference

> **Compatibility**: Verified against Context7 remote MCP API v2.x (January 2026)
>
> **Related**: See `comparison.md` for Context7 vs Ref vs Tavily decision matrix

## Overview

Context7 fetches up-to-date library documentation snippets for 20K+ libraries. Solves the problem of LLMs generating deprecated APIs from stale training data.

### Architecture (2026 Update)

Context7 uses **Server-Side Reranking** to optimize token delivery:

1. **Retrieval**: Vector search fetches broad candidate chunks
2. **Reranking**: Server-side model scores candidates against query
3. **Delivery**: Only top-scoring, highly relevant chunks sent to client

This shift from client-side filtering resulted in:
- **65% reduction** in average tokens (9.7k → 3.3k)
- **38% reduction** in latency

**Infrastructure**: Uses Redis (Upstash) caching and llms.txt standard for efficient documentation parsing.

**llms.txt Integration**: Libraries using the llms.txt standard have IDs like `/llmstxt/developers_cloudflare_com-d1-llms-full.txt`. The `-llms-full.txt` suffix indicates full content (all details); `llms.txt` alone is a concise overview.

## Tools

### resolve-library-id

Converts library name to Context7-compatible ID.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `libraryName` | Yes | Library name (e.g., "React", "Next.js") |

**Returns**: Up to 10 matching libraries with metadata (trust scores, versions, snippet counts).

**Skip this step** by using IDs directly in prompts (slash syntax):
- `/facebook/react`
- `/vercel/next.js`
- `/supabase/supabase`

**Slash Syntax Benefit**: Using library ID directly short-circuits the resolve step, saving 1-2 seconds latency and ~7,000 tokens (resolve can return many candidates with descriptions).

**Pro Tip**: Pre-fetch library IDs from context7.com website, then use them directly in prompts to avoid resolve overhead.

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

| Variable | Default | Recommended | Description |
|----------|---------|-------------|-------------|
| `CONTEXT7_API_KEY` | None | Required | API key (format: `ctx7sk-*`) |
| `MCP_TIMEOUT` | 10000ms | **60000ms** | Startup timeout. Critical for npx - package download often exceeds 10s |
| `MCP_TOOL_TIMEOUT` | 30000ms | **60000ms** | Execution timeout. Deep searches can spike latency |
| `DEFAULT_MINIMUM_TOKENS` | 10000 | - | Min token response |
| `https_proxy` | None | As needed | For corporate firewalls |

**Timeout Bottleneck**: The most common "Connection Timeout" error is caused by npx download exceeding the default 10s timeout. Always set `MCP_TIMEOUT=60000`.

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

### Version Pinning (Critical)

The most common failure mode is **Version Hallucination**. If a library has breaking changes (e.g., Next.js Pages vs App Router), explicitly state the version:

```
# Good - forces reranker to downrank legacy docs
"Using Next.js 14 App Router conventions, how do I implement middleware?"

# Bad - may return v12 documentation
"How do I implement Next.js middleware?"
```

### Multi-Library Workflows

Avoid context overflow with sequential loading:

1. **One-at-a-Time Rule**: Limit tool calls to one major library per turn
2. **Sequential Strategy**: Instead of "Docs for React, Tailwind, and Supabase" in one prompt:
   - First: "Find docs for Supabase Auth hook" (wait for response)
   - Then: "Now find Tailwind forms docs to style a login component"

This allows synthesis before adding complexity.

## Token Profile

Post-January 2026 optimization:
- **Average tokens per query**: ~3.3k (down from 9.7k)
- **Average tool calls**: 2.96 (down from 3.95)
- **Average latency**: 15s (down from 24s)

Code examples rank higher than prose. API signatures rank higher than descriptions.

## Rate Limits

| Tier | Request Limit | Private Repos | Notes |
|------|---------------|---------------|-------|
| Free | 60/hr | No | Aggressive limits during peak loads |
| Pro | ~5,000/seat/month | Yes | Private repo indexing, email support |
| Enterprise | Custom | Yes | SSO, SLA, unlimited indexing |

HTTP 429 = rate limited. Implement exponential backoff (wait 1s, then 2s, then 4s).

## Known Limitations

1. **Code snippets only** - no prose explanations or warnings
2. **No PDF support** - cannot index PDF documentation
3. **No file upload** - cannot add custom docs
4. **Paid private repos** - Context7 charges extra for private repo indexing
5. **Indexing lag** - rapidly-changing libraries may lag behind releases
6. **Node.js 18+ required** for local installation

## Session Behavior

Context7 is **stateless per query** - it does not:
- Maintain multi-turn memory between calls
- Avoid duplicates across queries
- Remember what was already fetched

**Implication**: Client-side caching is recommended since documentation doesn't change frequently. If the same docs are needed later, reuse previous results rather than calling again.

## Anti-Patterns to Avoid

| Anti-Pattern | Why It Hurts | Better Approach |
|--------------|--------------|-----------------|
| **>3 tool calls per question** | Token waste, diminishing returns | Work with best result after 3 calls |
| **Vague single-word queries** | Poor reranking, generic snippets | Include version + feature + use case |
| **No version specification** | Wrong API returned (v12 vs v14) | Always include "Next.js 15" etc. |
| **Using for prose explanations** | Only returns code snippets | Use Ref instead |
| **Multi-library in one prompt** | Context overflow | One library per turn, sequential |
| **Ignoring stateless nature** | Re-fetching same docs | Cache results client-side |

## When NOT to Use Context7

| Scenario | Why Not | Alternative |
|----------|---------|-------------|
| Conceptual questions ("What is OOP?") | No library doc to fetch | LLM native knowledge |
| Debugging specific errors | Forums/SO have fixes, not official docs | Tavily web search |
| Community opinions/comparisons | Official docs don't cover | Tavily or Ref |
| Libraries with no code examples | Returns prose, not ready-to-use code | Read source directly |
| Bleeding-edge unreleased versions | Indexing lag | GitHub repo directly |

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| "Documentation not found" | Library not indexed | Try Ref or request addition |
| Rate limit (429) | Too many requests | Add API key, implement exponential backoff |
| "Connection timeout" | npx download exceeds 10s | Set `MCP_TIMEOUT=60000` |
| "Error spawn node ENOENT" | IDE cannot find Node.js | Use absolute path `/usr/local/bin/npx` in mcp.json |
| "Fetch is not defined" | Node.js < v18 | Upgrade to Node.js v20 or v22 LTS |
| HTTP 422 "library too large" | Library content exceeds limits | Narrow scope or use sub-library |
| ESM resolution error | Node version | Use `--experimental-vm-modules` |

**Pre-install Workaround**: Run `npm install -g @upstash/context7-mcp` globally, then change mcp.json command to `node` with the global script path. This bypasses npx download entirely.

## Combining with Other MCP Servers

Context7 is most powerful combined with complementary tools:

| Combination | Use Case |
|-------------|----------|
| **Context7 + SequentialThinking** | Better reasoning over fetched docs (community favorite) |
| **Context7 + Serena/codebase search** | Combine repo code with library docs |
| **Context7 + Ref** | Context7 for known libraries, Ref for broader web search |

**Pattern**: Use Context7 for official API docs, use Ref/Tavily when docs aren't enough or for debugging/troubleshooting.

## For Library Authors: context7.json

Library maintainers can control indexing via a `context7.json` file in the repository root:

```json
{
  "projectTitle": "Acme SDK",
  "excludeFolders": ["internal", "deprecated", "tests"],
  "branches": ["main", "v2-stable"],
  "rules": ["Always use async/await", "Prefer interface over type"]
}
```

- **excludeFolders**: Prevents indexing of irrelevant directories
- **rules**: Injects "system prompt" style instructions with retrieved docs

## When to Choose Context7

> Full comparison: See `comparison.md` for detailed decision matrix.

**Best for**: Quick mainstream library lookups, maximum coverage (20K+), direct library ID usage.
