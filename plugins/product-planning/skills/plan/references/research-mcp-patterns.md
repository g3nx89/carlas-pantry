# Research MCP Patterns Reference

This reference provides guidance for using research MCP servers (Context7, Ref, Tavily) effectively within the planning workflow.

## Server Selection Decision Tree

```
Need information about a library/framework API?
├── YES →
│   Need prose explanations, warnings, context (not just code)?
│   ├── YES → Ref (ref_search_documentation)
│   └── NO →
│       Is it a mainstream library (React, Next.js, Rails, etc.)?
│       ├── YES → Context7 (faster for well-indexed libs)
│       └── NO → Ref (better for niche/private repos)
│
└── NO →

Need current/real-time information?
├── YES →
│   News, events, prices, recent announcements?
│   ├── YES → Tavily (tavily_search with topic="news")
│   └── NO → Tavily (tavily_search, general)
│
└── NO →

Need to read a specific URL's content?
├── YES → Ref (ref_read_url) - better markdown, session tracking
└── NO → Reassess whether task is documentation lookup or web research
```

## Anti-Pattern: Using Tavily for Documentation

**NEVER use Tavily to look up library documentation.**

Tavily searches the general web, which returns:
- Outdated tutorials from 2-3 years ago
- Unofficial sources with incorrect patterns
- Content that reinforces LLM hallucinations

**ALWAYS use Context7 or Ref for library APIs** - they pull from official sources.

## Query Patterns by Server

### Context7 Queries

| Aspect | Guideline |
|--------|-----------|
| **Length** | 5-15 words |
| **Style** | Specific, version-aware |
| **Key Rule** | Include version + feature + use case |
| **Max Calls** | 3 per topic (work with best result after that) |

**Good Examples:**
```
"React 18 useEffect cleanup function patterns"
"Next.js 15 app router server components data fetching"
"TypeScript 5.4 satisfies operator use cases"
```

**Bad Examples:**
```
"react hooks"           # Too vague
"how to use useEffect"  # Missing version, too generic
"authentication"        # No framework context
```

**Efficiency Tips:**
- Skip `resolve-library-id` for known libraries - use direct IDs:
  - React: `/facebook/react`
  - Next.js: `/vercel/next.js`
  - TypeScript: `/microsoft/typescript`
  - Vue: `/vuejs/core`
  - Angular: `/angular/angular`
  - Express: `/expressjs/express`
  - Prisma: `/prisma/prisma`

### Ref Queries

| Aspect | Guideline |
|--------|-----------|
| **Length** | 10-20 words |
| **Style** | Full sentences, descriptive |
| **Key Rule** | Include context and specific question |
| **Session** | Leverages deduplication - refine queries progressively |

**Good Examples:**
```
"How to implement JWT authentication with NextAuth.js in Next.js 15 app router"
"PostgreSQL connection pooling configuration for high-traffic Node.js applications"
"GDPR compliance requirements for user data collection in European markets"
```

**Bad Examples:**
```
"auth"                  # Too short
"JWT"                   # Missing context
"database connection"   # Vague
```

**Efficiency Tips:**
- Use `source: 'private'` to search only private repos
- Search first, then use `ref_read_url` selectively on best results
- Session deduplication means refining queries never returns duplicates

### Tavily Queries

| Aspect | Guideline |
|--------|-----------|
| **Length** | 5-10 words |
| **Style** | Search keywords |
| **Key Rule** | Under 400 chars, not conversational |
| **Cost Control** | Always set `search_depth: "basic"` unless explicitly needed |

**Good Examples:** (use current year in queries)
```
"Next.js 15 release notes changes {current_year}"
"React Server Components security vulnerabilities CVE"
"Vercel pricing changes announcement {current_year}"
```

**Bad Examples:**
```
"Can you tell me about the latest changes in Next.js?"  # Conversational
"I need to know about React security issues"            # Too long, conversational
"next"                                                  # Too vague
```

**Efficiency Tips:**
- Always set `search_depth: "basic"` (default) to avoid 2x credit usage
- Filter results by `score > 0.5` to avoid processing junk
- Use `time_range: "week"` or `"month"` for recent information
- Use `topic: "news"` for announcements and releases

## Multi-Server Workflow Pattern

For comprehensive technology research, combine servers:

```yaml
research_workflow:
  step_1_documentation:
    description: "Get official API reference"
    if: is_mainstream_library
      use: mcp__context7__query-docs
      params:
        libraryId: "{direct_id_or_resolved}"
        query: "{specific_feature_question}"
    else:
      use: mcp__Ref__ref_search_documentation
      params:
        query: "{descriptive_question}"

  step_2_recent_updates:
    description: "Check for recent changes, breaking updates"
    condition: risk_level >= medium OR technology_is_new
    use: mcp__tavily__tavily_search
    params:
      query: "{library} release notes changes {current_year}"
      topic: "news"
      time_range: "month"
      search_depth: "basic"

  step_3_deep_dive:
    description: "Read full content of important URLs"
    condition: step_2 found critical updates
    use: mcp__Ref__ref_read_url
    params:
      url: "{changelog_or_blog_url_from_step_2}"

  step_4_security_check:
    description: "Check for known vulnerabilities"
    condition: technology handles auth/payments/PII
    use: mcp__tavily__tavily_search
    params:
      query: "{library} CVE security vulnerability {current_year} {last_year}"
      search_depth: "basic"
      max_results: 5
```

## Example: Researching a New Framework

**Scenario:** Feature spec mentions "implement authentication with NextAuth.js v5"

```
1. Context7 for API reference:
   mcp__context7__query-docs(
     libraryId: "/nextauthjs/next-auth",
     query: "NextAuth.js v5 app router authentication setup credentials provider"
   )

2. Tavily for recent announcements:
   mcp__tavily__tavily_search(
     query: "NextAuth.js v5 release notes breaking changes {current_year}",
     topic: "news",
     time_range: "month",
     search_depth: "basic"
   )

3. Ref for specific blog post:
   mcp__Ref__ref_read_url(
     url: "{migration_guide_url_from_step_2}"
   )

4. Tavily for security check:
   mcp__tavily__tavily_search(
     query: "NextAuth.js security vulnerability CVE {last_year} {current_year}",
     search_depth: "basic",
     max_results: 5
   )
```

## Cost and Token Management

| Server | Cost Model | Token Profile | Efficiency Tip |
|--------|------------|---------------|----------------|
| **Context7** | Free (1K/month), paid for more | ~3.3k avg (5k max) | Max 3 calls per topic |
| **Ref** | $9/1K queries | 500-5k adaptive | Search first, read selectively |
| **Tavily** | 1-2 credits/search, 4-250 research | Variable | Use `basic` depth by default |

**Tavily Warning:** `auto_parameters` can silently upgrade to `advanced` (2x credits). Always set `search_depth` explicitly.

## Integration with Planning Phases

### Phase 2: Research & Exploration

Use research MCP BEFORE launching code-explorer agents:

1. **Parse spec.md** for technology mentions
2. **Query Context7/Ref** for each mentioned library
3. **Query Tavily** for recent updates (if high-risk)
4. **Include findings** in agent context
5. **Launch code-explorer agents** with enriched context

### Phase 4: Architecture Design

Before MPA architect agents:

1. **Query Context7** for framework-specific architecture patterns
2. **Include patterns** in architect agent prompts
3. **Launch architect agents** with official best practices

### Phase 7: Test Strategy

Before QA agents:

1. **Query Context7** for testing library best practices
2. **Check Tavily** for test framework updates
3. **Include patterns** in QA agent prompts

## Common Library IDs (Context7)

Use direct IDs to skip `resolve-library-id` for faster queries.

**Single Source of Truth:** See `$CLAUDE_PLUGIN_ROOT/config/planning-config.yaml` section `research_mcp.context7.common_library_ids` for the complete and current list.

**Quick reference (commonly used):**
- React: `/facebook/react`
- Next.js: `/vercel/next.js`
- TypeScript: `/microsoft/typescript`
- Prisma: `/prisma/prisma`

For the full list of 25+ library IDs, consult the config file.

## Graceful Degradation

When research MCP servers are unavailable:

1. **Context7 unavailable:** Fall back to Ref for library documentation
2. **Ref unavailable:** Use Tavily with `include_domains: ["docs.*.com", "github.com"]`
3. **All unavailable:** Proceed with internal knowledge, mark as DEGRADED in research.md

---

## Glossary

Terms for non-technical users and quick reference:

| Term | Definition |
|------|------------|
| **MCP** | Model Context Protocol - Standard interface for Claude to interact with external tools and services |
| **Context7** | MCP server providing code-focused library documentation from official sources (20K+ libraries) |
| **Ref** | MCP server for prose documentation, private repos, and URL reading with session tracking |
| **Tavily** | MCP server for web search, news, and current events (not for library documentation) |
| **CVE** | Common Vulnerabilities and Exposures - Database of known security vulnerabilities |
| **Token Profile** | Expected token count per MCP call (e.g., Context7 ~3.3k avg, Ref 500-5k adaptive) |
| **Search Depth** | Tavily parameter controlling search thoroughness ("basic" = 1 credit, "advanced" = 2 credits) |
| **Library ID** | Context7 identifier format: `/org/repo` (e.g., `/facebook/react`) |
| **Relevance Score** | Tavily result quality metric (0-1); filter at > 0.5 to avoid low-quality results |
| **Graceful Degradation** | Automatic fallback when preferred MCP server is unavailable |

---

*Last updated: 2026-02-02 - Added glossary for non-technical users*
