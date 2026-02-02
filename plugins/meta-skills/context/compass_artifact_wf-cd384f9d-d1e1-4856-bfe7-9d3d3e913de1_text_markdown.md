# Ref.tools MCP Server: Complete Technical Manual

**Ref.tools delivers 60-95% token reduction over Context7** by replacing batch retrieval with an intelligent search-then-read architecture that lets AI agents control exactly what documentation they consume. This MCP server combines adaptive token management, session-aware deduplication, and smart chunking to solve the "context rot" problem—where models degrade as context windows fill with irrelevant content. At **$9/month for 1,000 queries** (versus Context7's ~$10 for 500), Ref also includes free private GitHub repo and PDF indexing that competitors charge extra for.

---

## 1. Technical Architecture

### Transport and server implementation

Ref.tools offers two transport options for connecting to its MCP server. The **streamable HTTP transport** is now recommended and connects directly to `https://api.ref.tools/mcp?apiKey=YOUR_API_KEY`. This approach supports the latest MCP specification with Server-Sent Events (SSE) for stateful sessions and requires no local installation. The **legacy stdio transport** runs locally via `npx ref-tools-mcp@latest` with your API key passed as the `REF_API_KEY` environment variable. Docker images are also available at `mcp/ref-tools-mcp` on Docker Hub, though a known issue (#35) exists where hardcoded `TRANSPORT=http` conflicts with Docker MCP Gateway.

The server is written in TypeScript (96.1% of codebase) and operates as a thin client that communicates with Ref's backend API. For clients that don't natively support streamable HTTP—some versions of Claude Desktop, for example—you can proxy through `mcp-remote`:

```json
"Ref": {
  "command": "npx",
  "args": ["-y", "mcp-remote@0.1.0-0", "https://api.ref.tools/mcp", "--header=x-ref-api-key:YOUR_KEY"]
}
```

### The three core tools

**`ref_search_documentation`** is the primary search interface. It accepts a required `query` parameter (full sentences perform better than keywords), optional `keyWords` for grep-like filtering, and an optional `source` parameter (`'public'`, `'private'`, or `'all'`). A search for "Figma API post comment endpoint documentation" returns **54 tokens** of results—compared to Context7's typical **3,000-10,000 tokens** per library lookup.

**`ref_read_url`** fetches any URL and converts it to markdown. Combined with search results, this enables agents to selectively read only pages they need. Reading the Figma comments endpoint documentation consumes just **385 tokens**, bringing total context for that query to **439 tokens**.

**`ref_search_web`** is a fallback web search for edge cases when documentation search fails. It can be disabled via the `DISABLE_SEARCH_WEB=true` environment variable or `?disable_search_web=true` URL parameter. For OpenAI Deep Research compatibility, tools are aliased as `search(query)` and `fetch(id)`.

### Session state and trajectory tracking

Ref's MCP session implements four key optimizations that compound over conversation length:

- **Deduplication filtering**: Repeated similar searches within a session never return duplicate results, allowing agents to both paginate and refine queries simultaneously
- **Session-aware truncation**: When reading documentation pages, Ref uses the agent's search history to drop less relevant sections, returning only the **most relevant ~5,000 tokens** even from pages containing 90,000+ tokens
- **Pre-fetching**: Search results are cached for faster subsequent reads
- **Link memory**: The server tracks all links shown in a session and excludes them from future results since they're already in the agent's context

### Token optimization mechanics

The claimed **60% average reduction** (up to 95% in best cases) versus Context7 stems from architectural differences. Context7 returns fixed batches: select a library, receive ~10,000 tokens regardless of what you actually need. Two libraries means 20,000 tokens. Ref uses **adaptive 500-5,000 token** responses based on query complexity.

Real-world comparison from Skywork.ai analysis: a Firebase CORS query via general web search consumed **110,100 tokens at $0.1317**, while Ref completed the same task with **789 tokens at $0.0856**—a 99.28% reduction. The GitHub README calculates that 6,000 extra tokens per step with Claude Opus costs **$0.09 per step**—in an 11-step workflow, that's $1 wasted on noise.

### Private resources and enterprise features

Ref includes capabilities that Context7 charges extra for or doesn't support:

- **Private GitHub repos**: Connect at ref.tools/resources for automatic indexing and syncing; searchable via `source: 'private'`
- **PDF upload and indexing**: Upload documentation files directly
- **Markdown file indexing**: Full support for custom markdown docs
- **Team RBAC**: Role-based access control for enterprise deployments
- **Prompt injection protection**: Integration with Centure.ai provides real-time multi-modal analysis against malicious instructions in scraped external content

### Environment variables reference

| Variable | Purpose |
|----------|---------|
| `REF_API_KEY` | Required authentication token |
| `DISABLE_SEARCH_WEB` | Set `true` to disable web search fallback |
| `REF_ALPHA` | Legacy config for former alpha users (still supported) |

---

## 2. Use Cases and Workflows

### Documentation lookup workflow

The canonical pattern is **search → read → refine**. For a simple fact lookup like "Figma API post comment endpoint":

1. `ref_search_documentation("Figma API post comment endpoint documentation")` → 54 tokens, returns URLs
2. `ref_read_url("https://www.figma.com/developers/api#post-comments-endpoint")` → 385 tokens, returns markdown
3. Total: **439 tokens** with deep link to source for verification

### Complex multi-step research

The n8n merge node example from documentation demonstrates iterative refinement:

```
SEARCH 'n8n merge node vs Code node multiple inputs best practices' (126 tokens)
READ multiple docs (4961, 138 tokens)
Refinement searches (107-372 tokens each)
Total: ~8,500 tokens with session deduplication
```

Session tracking prevents repeated content across these searches—the agent can adjust queries without seeing the same results twice.

### Private codebase workflows

For internal documentation, configure private repos at ref.tools/resources, then query with `source: 'private'`:

```javascript
ref_search_documentation({
  query: "How does our authentication middleware handle token refresh?",
  source: "private"
})
```

PDF documentation (API specs, architecture documents, compliance guides) follows the same pattern after upload.

### Supported integrations

Ref provides installation guides for **18+ platforms**: Claude Code, Cursor, VS Code, Codex CLI, Gemini CLI, Zed, Windsurf, Kiro, Augment, Goose, Droid CLI, Amp, OpenCode, Cline, Roo Code, Devin, ChatGPT, and Claude Desktop/Web. Configuration varies by platform—streamable HTTP is preferred where supported:

**Cursor/VS Code (streamable HTTP)**:
```json
"Ref": {
  "type": "http",
  "url": "https://api.ref.tools/mcp?apiKey=YOUR_API_KEY"
}
```

**Claude Code (stdio)**:
```json
"Ref": {
  "command": "npx",
  "args": ["ref-tools-mcp@latest"],
  "env": { "REF_API_KEY": "YOUR_API_KEY" }
}
```

### When to choose each tool

Use **`ref_search_documentation`** for: API documentation, library usage patterns, framework-specific questions, version-specific behavior, configuration options, code examples from official sources.

Use **`ref_read_url`** for: Following deep links from search results, reading GitHub files directly, consuming any web page as context, processing external tutorials or blog posts.

Use **`ref_search_web`** (if enabled) for: Topics not covered in indexed documentation, recent news or announcements, general programming concepts not tied to specific libraries, troubleshooting obscure error messages.

---

## 3. Best Practices and Patterns

### Query formulation strategies

The official guidance emphasizes **full sentences over keywords**: "This should be a full sentence or question. Include programming language, framework, or library names for best results." Compare:

- ❌ `"figma comment api"` (keyword-style)
- ✅ `"Figma API post comment endpoint documentation"` (full context)

Include version numbers when relevant, specify the programming language, and describe the actual task rather than abstract concepts.

### Iterative refinement pattern

Leverage session-aware deduplication by refining queries progressively:

1. Start broad: "React Server Components data fetching patterns"
2. Read promising results
3. Narrow: "React Server Components streaming with Suspense boundaries"
4. Session automatically excludes already-seen content

This pattern is more effective than traditional pagination because you can simultaneously adjust query terms and view "next" results.

### Token budget management

For cost-sensitive applications, structure workflows to minimize reads:

- **Search first**: Review search snippets before committing to full page reads
- **Target deep links**: Ref returns links to specific page sections; read only what's relevant
- **Batch related queries**: Session context carries forward, so related questions in sequence benefit from cumulative filtering
- **Monitor credit usage**: At $9 per 1,000 credits, a typical developer rarely exceeds monthly allocation

### Private documentation setup

At ref.tools/resources:

1. Connect GitHub via OAuth to automatically index repositories
2. Upload PDFs and markdown files for internal documentation
3. Use `source: 'private'` in searches to scope to your resources
4. Repositories sync automatically on updates

### Deep research pattern

For comprehensive research tasks (matching OpenAI Deep Research integration):

1. Broad `ref_search_documentation` query to identify relevant pages
2. Multiple `ref_read_url` calls to consume key sources
3. Refined searches based on what you learned
4. Session tracking ensures no duplicated content

---

## 4. Antipatterns and Pitfalls

### Known bugs and limitations

**Docker/Gateway incompatibility** (Issue #35): The Docker image hardcodes `TRANSPORT=http`, causing conflicts with Docker MCP Gateway expectations. Use stdio or native streamable HTTP until resolved.

**Claude Code authentication** (Issue #34): Some users report authentication failures with Claude Code. Verify API key format and try switching between stdio and HTTP transports.

**Gemini CLI integration** (Issue #33): Integration issues reported; check docs.ref.tools for updated Gemini-specific configuration.

**Smithery installation hang** (Issue #420): Installation via Smithery CLI can get stuck at "Validating configuration..." on Mac with Codex client. Use direct `npx` installation instead.

### Not self-hostable (yet)

Ref requires the ref.tools API service—there's no self-hosted option currently. A beta signup form exists at tally.so/r/mZKlrA for interested enterprises.

### Query patterns that fail

- **Overly short queries**: "React" or "API" return too many results; add specificity
- **Questions about very recent releases**: Coverage depends on indexing; email hello@ref.tools to request additions
- **Highly localized content**: Internal jargon or custom terminology without context
- **Non-technical queries**: Ref is optimized for technical documentation, not general knowledge

### Web search fallback overreliance

If agents default to `ref_search_web` too frequently, it suggests:
- Query formulation needs improvement (add library/framework names)
- Documentation isn't indexed (request addition via hello@ref.tools)
- Query is genuinely outside documentation scope (acceptable)

Consider disabling `ref_search_web` in environments where you want strict documentation-only results.

### Documentation coverage gaps

Ref indexes "1000s of public repos and sites" versus Context7's 20,000+ libraries. For niche or new libraries:
- Check if indexed via a test search
- Request addition at docs.ref.tools/support/request-docs
- Fall back to `ref_search_web` or alternative sources temporarily

### Session isolation quirks

Session deduplication is powerful but means repeated queries in the same session genuinely won't show the same results. If you need to re-read something, use `ref_read_url` with the URL directly rather than searching again.

---

## 5. Community Insights and Comparisons

### Ref.tools vs Context7 in practice

The fundamental architectural difference: **Context7 selects then returns** (pick a library → receive ~10K tokens), while **Ref searches then reads** (query → review → selectively consume). TheAIStack.dev characterizes Context7 as "The Documentation Expert" and Ref as "The Efficiency Beast."

| Dimension | Context7 | Ref.tools |
|-----------|----------|-----------|
| Token per query | Consistent ~3K-10K | Adaptive 500-5K |
| Multi-library | 10K × libraries | Single efficient query |
| Private repos | $15/1M parse tokens | **Free** |
| PDF support | ❌ | **✅** |
| Coverage breadth | 20,000+ libraries | 1000s+ plus private |
| Price/1000 queries | ~$20 | **$9** |
| Invocation style | "use context7" phrase | Tool calls |

**Hacker News feedback**: One user mentioned trying both; the Ref developer responded noting "a bunch of search quality improvements dropped this week" indicating active development. The project has grown from 648 to 949 GitHub stars over the observation period.

**Thoughtworks Technology Radar** placed Context7 favorably for reducing "code hallucinations and reliance on stale training data"—the same core problem Ref solves with a different approach.

### When each tool wins

**Choose Ref.tools for**:
- Token-sensitive production environments
- Complex iterative research workflows  
- Private repo/PDF documentation needs
- Enterprise deployments requiring RBAC
- Cost optimization ($9 vs ~$20 per 1K queries)
- Security-critical applications (Centure.ai protection)

**Choose Context7 for**:
- Maximum library coverage (20K+ vs 1K+)
- Simple "use context7" invocation pattern
- Quick single-library lookups
- Free tier without signup (basic usage)
- Local LLM deployments (praised as "underrated" by XDA Developers)

### Community presence

Ref.tools maintains presence across major MCP directories: Smithery.ai, PulseMCP, mcpservers.org, Glama.ai, and the awesome-mcp-servers GitHub list. Docker Hub shows 158+ pulls for the official image. There's no dedicated Discord—community communication flows through GitHub issues and hello@ref.tools.

User testimonials highlight token efficiency: "Imagine using Claude Opus as a background agent... that 6K extra tokens cost about $0.09 PER STEP. If one prompt ends up taking 11 steps, you've spent $1 for no reason." Another developer reported saving three days of debugging time by having reliable documentation context.

### Feature requests and roadmap

From GitHub issues and community feedback:
- Self-hosting capability (beta signup available)
- OAuth support for remote MCP connections (Context7 has this)
- Extended library pre-indexing
- Better Docker MCP Gateway compatibility

Enterprise features already available include built-in GitHub/PDF/Markdown indexing, team RBAC, SSO ($200/month add-on), and no custom pipeline requirements.

---

## Pricing and Getting Started

| Plan | Cost | Credits | Notes |
|------|------|---------|-------|
| **Free** | $0 | 200 (never expire) | Good for evaluation |
| **Basic** | $9/month | 1,000/month | Typical developers rarely exceed this |
| **Team** | $9/member/month | 1,000 per member pooled | Shared team credits |
| **SSO Add-on** | +$200/month | — | Enterprise authentication |

**Quick start**:
1. Sign up at ref.tools/signup
2. Get API key at ref.tools/keys
3. Configure your MCP client with streamable HTTP or stdio transport
4. Optional: Connect private repos and upload PDFs at ref.tools/resources

For bug reports: docs.ref.tools/support/report-bug  
Request documentation additions: docs.ref.tools/support/request-docs  
General support: hello@ref.tools

---

## Conclusion

Ref.tools represents a deliberate architectural choice: **agent-controlled retrieval over batch delivery**. By letting AI agents search, evaluate, and selectively read documentation, it achieves significant token reduction while maintaining access to complete source material—not just pre-extracted snippets. The free private repo indexing and PDF support address enterprise use cases that competitors monetize separately.

The trade-off is coverage breadth: Context7's 20,000+ indexed libraries versus Ref's thousands. For teams working primarily with mainstream frameworks and needing cost efficiency at scale, Ref's token economics compound favorably. For those prioritizing maximum library coverage with simple invocation, Context7 remains compelling.

The key insight for practitioners: these tools aren't mutually exclusive. Both can coexist in an MCP configuration, with agents choosing the appropriate tool based on query characteristics—Ref for token-sensitive iterative research, Context7 for quick broad lookups.