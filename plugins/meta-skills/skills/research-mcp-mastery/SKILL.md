---
name: research-mcp-mastery
description: This skill should be used when the user asks to "fetch library documentation", "look up React/Next.js/Rails API", "search the web for news", "research current events", "which MCP server should I use", "Context7 vs Ref vs Tavily", or needs guidance choosing between Context7, Ref, and Tavily MCP servers for documentation lookup or web research tasks. Provides decision trees, query optimization patterns, and selective reference loading.
---

# Research MCP Mastery

## Overview

Three MCP servers handle research and documentation tasks with distinct strengths:

| Server | Best For | Token Profile | Coverage |
|--------|----------|---------------|----------|
| **Context7** | Library code snippets | ~3.3k avg (5k max) | 20K+ libraries |
| **Ref** | Docs with prose + code | 500-5k adaptive | 1000s + private repos |
| **Tavily** | Web search, news, current events | Variable | Entire web |

**Core principle**: Use documentation servers (Context7/Ref) for library APIs. Use Tavily only for web research and current events - never for library documentation lookup.

## Quick Start

**Library API question?** → Context7 or Ref (see decision tree below)
**Current events, news, company research?** → Tavily `tavily_search`
**Need full page from URL?** → Ref `ref_read_url` or Tavily `tavily_extract`

## Tool Selection Decision Tree

```
Need information about a library/framework API?
├── YES ↓
│   Need prose explanations, warnings, context (not just code)?
│   ├── YES → Ref (ref_search_documentation)
│   └── NO ↓
│       Is it a mainstream library (React, Next.js, Rails, etc.)?
│       ├── YES → Context7 (faster for well-indexed libs)
│       └── NO → Ref (better for niche/private repos)
│
└── NO ↓

Need current/real-time information?
├── YES ↓
│   News, events, prices, recent announcements?
│   ├── YES → Tavily (tavily_search with topic="news")
│   └── NO → Tavily (tavily_search, general)
│
└── NO ↓

Need to read a specific URL's content?
├── YES → Ref (ref_read_url) - better markdown, session tracking
└── NO → Reassess whether task is documentation lookup or web research
```

## Anti-Pattern: Using Tavily for Documentation

**Never use Tavily to look up library documentation.**

Tavily searches the general web, which returns:
- Outdated tutorials from 2-3 years ago
- Unofficial sources with incorrect patterns
- Content that reinforces LLM hallucinations

**Always use Context7 or Ref for library APIs** - they pull from official sources.

## Context7 vs Ref: Quick Guide

> Full decision matrix: `$SKILL_PATH/references/comparison.md`

**TL;DR**: Context7 for mainstream library APIs (React, Next.js). Ref for prose/private repos/PDFs/token-sensitive work.

## Quick Reference by Tool

### Context7 Tools

| Tool | Purpose | Key Parameters |
|------|---------|----------------|
| `resolve-library-id` | Convert name to ID | `libraryName` |
| `get-library-docs` | Fetch code snippets | `context7CompatibleLibraryID`, `topic`, `tokens` |

**Tip**: Skip `resolve-library-id` by using IDs directly: `/facebook/react`, `/vercel/next.js`

### Ref Tools

| Tool | Purpose | Key Parameters |
|------|---------|----------------|
| `ref_search_documentation` | Search docs | `query`, `keyWords`, `source` |
| `ref_read_url` | Read any URL as markdown | URL from search results |
| `ref_search_web` | Fallback web search | `query` (disable if docs-only needed) |

**Tip**: Use `source: 'private'` to search only private repos.

### Tavily Tools

| Tool | Purpose | Key Parameters |
|------|---------|----------------|
| `tavily_search` | Web search | `query`, `search_depth`, `topic`, `max_results` |
| `tavily_extract` | Extract from URLs | `urls[]`, `extract_depth` |
| `tavily_crawl` | Crawl entire sites | `url`, guidance instructions |
| `tavily_research` | Deep multi-source report | `input`, `model` (warning: 4-250 credits) |

## Query Optimization Patterns

### Context7: Use Specific Queries

```
# Poor - too vague
"auth"

# Good - includes framework, version, use case
"React 19 useFormState validation patterns"
```

**Max 3 tool calls per question** - if not found after 3, work with best result.

### Ref: Full Sentences Work Best

```
# Poor - keyword style
"figma comment api"

# Good - full context sentence
"Figma API post comment endpoint documentation"
```

Session deduplication means refining queries never returns duplicate results.

### Tavily: Search Query Style

```
# Poor - too conversational
"Can you tell me everything about Tesla's Q4 earnings?"

# Good - focused keywords under 400 chars
"Tesla Q4 2024 earnings revenue guidance"
```

**Break complex topics into sub-queries** for better results.

## Cost & Token Management

| Server | Cost Model | Token Efficiency Tip |
|--------|------------|---------------------|
| Context7 | Free (1K/month), paid for more | Use library ID directly, limit to 3 calls |
| Ref | $9/1K queries | Search first, read selectively |
| Tavily | 1-2 credits/search, 4-250 research | Use `basic` depth by default |

**Tavily warning**: `auto_parameters` can silently upgrade to `advanced` (2x credits). Always set `search_depth` explicitly.

## Selective Reference Loading

**Load server-specific reference only when needed:**

```
# Before using Context7:
Read: $SKILL_PATH/references/context7.md

# Before using Ref:
Read: $SKILL_PATH/references/ref.md

# Before using Tavily:
Read: $SKILL_PATH/references/tavily.md

# For comparison and overlapping scenarios:
Read: $SKILL_PATH/references/comparison.md
```

**Available references:**
- `context7.md` - Context7 configuration, parameters, workflow patterns
- `ref.md` - Ref tools, session behavior, private repo setup
- `tavily.md` - Search/extract/crawl parameters, cost management
- `comparison.md` - Detailed comparison matrix, edge cases

**Working examples:**
- `examples/multi-server-workflow.md` - Complete research workflow combining all three servers
- `examples/query-patterns.md` - Good vs bad query patterns for each server

## Common Mistakes

| Mistake | Impact | Fix |
|---------|--------|-----|
| Using Tavily for library docs | Outdated/incorrect patterns | Use Context7/Ref |
| Not specifying version in Context7 | Wrong API returned | Add "Next.js 15" etc. |
| Vague single-word queries | Poor results, wasted tokens | Use descriptive sentences |
| Ignoring Tavily relevance scores | LLM processes junk | Filter `score > 0.5` |
| Multiple Context7 calls (>3) | Token waste | Work with best result |
| Not using Ref session dedup | Duplicate content | Refine queries progressively |

## Combining Servers

These servers complement each other:

```
# Complex task workflow:
1. Context7/Ref for library documentation
2. Tavily for current events/news about that library
3. Ref ref_read_url for deep-diving specific pages
```

**Example**: Researching a new framework release:
1. Context7 `get-library-docs` for API reference
2. Tavily `tavily_search(topic="news", time_range="week")` for announcements
3. Ref `ref_read_url` to read specific blog post in full

## For Skill/Command Development

When building skills or commands that use research MCP servers:

1. **Specify servers in skill description** - mention which server(s) the skill uses
2. **Include query examples** - show optimal query patterns in prompts
3. **Handle rate limits gracefully**:
   - Context7: 60/hr (free), add backoff
   - Ref: 200 credits total (free tier)
   - Tavily: 100 RPM dev, 1000 RPM prod
4. **Budget tokens appropriately**:
   - Context7: ~3.3k avg per call
   - Ref: 500-5k adaptive
   - Tavily: variable, filter by relevance score
5. **Use ToolSearch for deferred tools**: `select:mcp__context7__resolve-library-id`

## When NOT to Use These Servers

- **Simple code questions Claude knows** - native knowledge suffices
- **Project-specific patterns** - use codebase search instead
- **Non-technical research** - Tavily works, but consider if LLM knowledge suffices
- **Large file operations** - use native file tools
