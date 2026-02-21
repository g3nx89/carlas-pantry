---
name: deepsearch-browser-mastery
version: 0.2.0
description: >
  This skill should be used when the user asks to "deep search", "research with browser",
  "search on ChatGPT/Gemini/Perplexity", "browser deep research", "compare AI search results",
  "run a deepsearch", "multi-provider web research", "use Chrome to search",
  "open browser and search", "search using my browser", or needs autonomous browser-based
  research across AI search providers (ChatGPT, Gemini, Perplexity) via Chrome automation.
  This skill uses claude-in-chrome MCP tools to control the browser directly, not API-based
  MCP research servers (Context7, Ref, Tavily).
---

# DeepSearch Browser Mastery

## Overview

Autonomous deep research using Chrome browser automation (`mcp__claude-in-chrome__*` tools) across three AI search providers: **ChatGPT**, **Google Gemini**, and **Perplexity**. The skill orchestrates browser interactions to submit queries, wait for AI-generated responses, extract results, and synthesize findings into a unified markdown report.

**Prerequisite**: The user must be logged in to each provider before invoking the skill. The skill does not handle authentication.

> **Tool name convention**: All tool names below (e.g., `tabs_context_mcp`, `navigate`, `find`) are shorthand for `mcp__claude-in-chrome__{tool_name}`.

## Two Operating Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| **Quick Search** | Simple factual query, single topic | Dispatch to relevant providers (consult Provider Selection Guide), collect results, synthesize |
| **Deep Research** | Complex/exploratory topic, "deep" in request | Multi-round iterative: initial query -> analyze gaps -> follow-up queries -> synthesis |

**Mode selection heuristic**: Default to Quick Search. Escalate to Deep Research when:
- The user explicitly says "deep", "thorough", or "comprehensive"
- The topic is multi-faceted (requires sub-questions)
- Initial results reveal conflicting information that needs resolution

## Core Workflow

### Phase 0: Setup

1. Call `tabs_context_mcp` to get current browser state
2. Create new tabs via `tabs_create_mcp` (one per provider)
3. Navigate each tab to its provider URL:
   - ChatGPT: `https://chatgpt.com`
   - Gemini: `https://gemini.google.com/app`
   - Perplexity: `https://www.perplexity.ai`
4. Wait 3 seconds for pages to load, then verify each page loaded
5. **Handle onboarding/consent dialogs**: Providers (especially Gemini) may show consent, terms, or welcome dialogs on first visit. Dismiss them by clicking "Accept"/"Continue"/"Use Gemini" buttons via `find`. After dismissing dialogs, call `tabs_context_mcp` again — **tab IDs may change** after consent redirects
6. Verify input fields are discoverable on all provider tabs before proceeding

### Phase 1: Query Dispatch

For each provider tab (in parallel where possible):

1. Locate the input field using `find` (search for "message input", "search bar", "ask anything")
2. If `find` does not return a clear match, fall back to `read_page(filter="interactive")` to identify the text input
3. **Enter the query using the Tiered Input Strategy** (see below)
4. Submit: press Enter via `computer(action="key", text="Return")`. If Enter does not submit, find and click the send button via `find(query="send button")`
5. Wait for response generation to complete (see Provider Timing below)

#### Tiered Input Strategy

`computer(action="type")` **fails with non-ASCII characters** (accented letters like à, è, ù, etc.) on contenteditable divs — only the last character survives. Use this fallback chain:

| Tier | Method | Works On | When to Use |
|------|--------|----------|-------------|
| **1** | `form_input(ref, value)` | `<textarea>`, `<input>` elements | Always try first — fastest and most reliable |
| **2** | `javascript_tool` with `execCommand('insertText')` | Contenteditable divs (Gemini, some ChatGPT versions) | When `form_input` returns "not a supported form input" |
| **3** | `javascript_tool` with `el.textContent = query` + `dispatchEvent(new Event('input', {bubbles: true}))` | Any contenteditable | When `execCommand` is deprecated or blocked |
| **4** | `computer(action="type")` | Standard inputs | **Only for ASCII-only queries** as last resort |

**Tier 2 JS pattern** (preferred for contenteditable):
```javascript
const el = document.querySelector('[contenteditable="true"]') || document.querySelector('textarea');
if (el) { el.focus(); document.execCommand('insertText', false, 'YOUR QUERY'); }
```

**After any JS-based injection**, framework state may not update — always verify by attempting to submit, then fall back to clicking the send button if Enter does not work.

### Phase 2: Response Extraction

Extraction reliability varies significantly by provider. Use provider-specific strategies:

| Provider | Primary Method | Fallback | Reason |
|----------|---------------|----------|--------|
| **Perplexity** | `get_page_text` | `javascript_tool` | Cleanest output — returns answer with inline citations |
| **ChatGPT** | `read_page(ref_id)` two-step | `javascript_tool` (may be blocked) | JS extraction gets blocked by cookie/query-string filters when response contains URLs with `?utm_source=` params |
| **Gemini** | `read_page(depth=5)` then parse | `javascript_tool` | `get_page_text` captures sidebar/chat history noise; `read_page` gives structured access |

**ChatGPT two-step extraction** (primary):
1. `read_page(depth=5)` — find the `article` ref containing heading "ChatGPT ha detto" (or "ChatGPT said")
2. `read_page(ref_id="{article_ref}", depth=10)` — extract the full response tree from that article

**ChatGPT JS extraction** (fallback): Use `conversation-turn` selectors (see references). **Warning**: `javascript_tool` may return `[BLOCKED: Cookie/query string data]` when the response contains inline source URLs — this is why `read_page` is the preferred primary method.

**Parallel extraction**: If one provider is still generating, immediately start extracting from completed providers. Do not wait for all providers to complete before starting Phase 2.

**For all providers**: Store extracted text per provider before moving to synthesis.

### Phase 3: Synthesis (Quick Search)

Produce a single markdown document:

```markdown
## DeepSearch Results: {query}

### Synthesis
[2-4 paragraph summary of findings across all providers]
[Note areas of agreement and disagreement]

### Per-Provider Findings

#### ChatGPT
[Key points extracted]

#### Gemini
[Key points extracted]

#### Perplexity
[Key points extracted, including cited sources]

### Sources
[Aggregate URLs/references cited by providers, especially from Perplexity]
```

### Phase 3-Deep: Iterative Research (Deep Research Mode)

After initial extraction:

1. **Gap analysis**: Identify unanswered sub-questions, contradictions, or shallow coverage
2. **Follow-up queries**: Formulate refined queries targeting gaps
3. **Round 2 dispatch**: Send follow-ups to the most relevant provider(s) — not necessarily all three
4. **Repeat** up to 3 rounds total (configurable), or until coverage is satisfactory
5. **Final synthesis**: Combine all rounds into a comprehensive report with:
   - Executive summary
   - Detailed findings by sub-topic
   - Contradiction analysis (where providers disagree)
   - Source list with confidence indicators

## Provider Timing & Wait Strategy

AI providers stream responses at different speeds. Do NOT use fixed waits.

**Strategy**: After submitting a query, use a polling loop:

1. `computer(action="wait", duration=5)` — initial wait for streaming to start
2. Check for completion signals (see per-provider details in references)
3. Poll every 5-10 seconds, up to the provider's max wait time
4. Completion heuristic: look for a "copy" button, "share" button, or absence of typing indicator

**Provider-specific timeouts** (the active model greatly affects response time):

| Provider | Default Max Wait | Extended Max (reasoning models) |
|----------|-----------------|--------------------------------|
| ChatGPT | 90s | 300s (if "Thinking" / "Ragionamento esteso" active — reasoning alone can take 4+ min with web search) |
| Gemini | 90s | 120s |
| Perplexity | 120s | 120s (includes web search phase) |

**ChatGPT Thinking model detection**: After navigation, check the top bar for "Thinking", "o3", or "Ragionamento esteso". If detected, use 300s timeout. During the wait, a "Rispondi subito" / "Answer now" button appears — clicking it skips the reasoning phase and generates an immediate (shorter) response. Offer this option to the user if the wait exceeds 120s.

If the timeout is exceeded, extract the partial response and note it as incomplete in the synthesis.

> **Detailed per-provider selectors and wait patterns**: See `references/provider-interactions.md`

## Provider Selection Guide

Not all queries need all three providers:

| Query Type | Best Provider(s) | Reason |
|------------|-------------------|--------|
| Current events, news | Perplexity | Real-time web search with citations |
| Code, technical | ChatGPT | Strong code generation and reasoning |
| Comparative analysis | All three | Different reasoning approaches |
| Academic/research | Perplexity + Gemini | Citations + Google Scholar access |
| Creative/brainstorming | ChatGPT + Gemini | Complementary creative styles |
| Fact-checking | Perplexity | Source-backed claims |

## Error Handling

| Error | Recovery |
|-------|----------|
| Provider page unresponsive | Refresh tab via `navigate(url="forward")` then `navigate(url="back")`, retry once |
| Rate limited / CAPTCHA | Skip provider, note in output, continue with remaining |
| Input field not found | Try `read_page(filter="interactive")` → locate textarea/input → use `form_input` |
| Response extraction empty | Try alternative extraction: `javascript_tool` with `document.querySelector` targeting response containers |
| Tab closed by user | Call `tabs_context_mcp` to refresh state, create new tab if needed |
| Tab ID changed after redirect | Call `tabs_context_mcp` — match tabs by URL/title to re-identify the provider tab |
| Consent/onboarding dialog blocking | Use `find` to locate "Accept"/"Continue"/"Use" buttons, click them, then refresh tab context |
| Streaming timeout (>max wait) | Extract partial response, note as incomplete in synthesis |
| JS extraction truncated | Extract in chunks via `substring(start, end)`, or switch to `read_page` with `ref_id` |
| JS extraction blocked (cookie/query filter) | Switch to `read_page(ref_id)` two-step extraction — this bypasses the content filter |
| `form_input` returns "not a supported form input" | The element is a contenteditable div, not a form element — use `javascript_tool` with `execCommand('insertText')` instead |
| `computer(type)` produces garbled text | Non-ASCII characters in query — switch to Tiered Input Strategy (Tier 1-3) |

## Anti-Patterns

- **Never trigger browser alerts/dialogs** — avoid clicking elements that may open confirm/prompt dialogs
- **Never submit multiple queries to the same provider tab** without extracting the previous response first — this loses earlier results
- **Never hard-code DOM selectors** — providers update their UI frequently; always use `find` or `read_page` to discover elements dynamically
- **Never skip the wait phase** — extracting before streaming completes yields truncated results
- **Avoid rabbit holes** — if a provider is consistently failing (2+ attempts), skip it and report the issue rather than retrying endlessly
- **Always prefer `ref` clicks over coordinate clicks** — coordinate-based `left_click` is fragile and misses often; use `find` to get a `ref` and click by ref
- **Never assume tab IDs are stable** — consent flows, redirects, and page reloads can change tab IDs silently; always re-check with `tabs_context_mcp` after navigation anomalies

## Tool Loading Reminder

All `mcp__claude-in-chrome__*` tools are deferred. Load the full tool set at workflow start via `ToolSearch`:

```
# Phase 0 — tab management & navigation
ToolSearch(query="select:mcp__claude-in-chrome__tabs_context_mcp")
ToolSearch(query="select:mcp__claude-in-chrome__tabs_create_mcp")
ToolSearch(query="select:mcp__claude-in-chrome__navigate")

# Phase 1 — element discovery & interaction
ToolSearch(query="select:mcp__claude-in-chrome__find")
ToolSearch(query="select:mcp__claude-in-chrome__computer")
ToolSearch(query="select:mcp__claude-in-chrome__read_page")
ToolSearch(query="select:mcp__claude-in-chrome__form_input")

# Phase 2 — extraction
ToolSearch(query="select:mcp__claude-in-chrome__get_page_text")
ToolSearch(query="select:mcp__claude-in-chrome__javascript_tool")
```

Load all tools in parallel batches at the start rather than one at a time.

## Reference Files

For detailed guidance on specific aspects, consult:

| Reference | Content | Load When |
|-----------|---------|-----------|
| `references/provider-interactions.md` | Per-provider DOM patterns, input selectors, wait signals, extraction strategies | Always — core operational guide |
| `references/synthesis-patterns.md` | Output templates, comparison frameworks, citation formatting, deep research round management | Producing final output or running multi-round Deep Research mode |
| `references/deep-research-flows.md` | Native Deep Research activation, source/app configuration, extended wait strategies, report saving | User requests native Deep Research on one or more providers |
