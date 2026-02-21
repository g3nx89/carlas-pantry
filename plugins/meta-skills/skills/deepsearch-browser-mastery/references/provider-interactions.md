# Provider Interaction Patterns

Detailed interaction guides for each AI search provider. These patterns are discovered dynamically — use them as starting hints, not hardcoded selectors.

## General Approach

All provider interactions follow the same abstract flow:

```
Navigate → Find Input → Enter Query → Submit → Wait for Completion → Extract
```

The specifics differ per provider. Always prefer `find` for element discovery and fall back to `read_page(filter="interactive")` when `find` returns ambiguous results.

---

## ChatGPT (chatgpt.com)

### Navigation

```
URL: https://chatgpt.com
```

After navigation, verify the page loaded by checking for the presence of the main input area.

### Input Discovery

**Primary method**: `find(query="message input")` or `find(query="prompt textarea")`

**Fallback**: `read_page(filter="interactive")` — look for:
- A `textarea` or `contenteditable` div near the bottom of the page
- Placeholder text like "Message ChatGPT" or "Ask anything"

**Common patterns**:
- The input is typically a `contenteditable` div or `textarea` at the bottom of the viewport
- There may be a "New chat" or model selector above the input — do not click those

### Query Submission

ChatGPT's input is exposed as a `textarea` (via `find`) but may render as a `contenteditable` div internally. Use the **Tiered Input Strategy**:

1. Click the input element: `computer(action="left_click", ref="{input_ref}")`
2. Try `form_input(ref="{input_ref}", value="{query}")` — this works when the element is a true `<textarea>`
3. If `form_input` fails or the text doesn't appear visually, use JavaScript:
   ```javascript
   const el = document.getElementById('prompt-textarea') || document.querySelector('[contenteditable="true"]');
   if (el) { el.focus(); el.textContent = ''; document.execCommand('insertText', false, 'YOUR QUERY'); }
   ```
4. Submit: `computer(action="key", text="Return")`
5. **If Enter does not submit** (common after programmatic text injection): find and click the send button via `find(query="send prompt button")` or `find(query="invia prompt")`

**Important**: After `form_input` or JS injection, always take a screenshot or check the page to verify the text appeared correctly before submitting. The underlying React state may not update from `form_input` alone.

### Wait for Completion

**Streaming indicator**: ChatGPT shows a blinking cursor or "Stop generating" button while streaming.

**Polling strategy**:
```
1. Initial wait: 10 seconds (longer if web search or Thinking model active)
2. Check for streaming indicators:
   - find(query="stop streaming") or find(query="interrompi") → still streaming → wait 10s → repeat
   - find(query="verifica delle fonti") or find(query="searching") → web search phase → wait 10s → repeat
3. Completion signals (any one suffices):
   - find(query="copy button") returns results in the response area
   - find(query="regenerate") button appears
   - The "stop streaming" button disappears
4. Max wait: 90 seconds (standard models), 300 seconds (Thinking/reasoning models)
5. Thinking-specific: find(query="Rispondi subito") or find(query="Answer now") → model is still reasoning (not yet streaming response)
```

**Detecting the active model**: After navigation, the model name is visible in the top bar (e.g., "ChatGPT 5.2 Thinking"). If "Thinking", "o3", or "Ragionamento esteso" appears, use the extended 300s timeout. Reasoning alone can take 4+ minutes when combined with web search.

**"Rispondi subito" / "Answer now" button**: During the reasoning phase, ChatGPT shows this button to skip thinking and generate an immediate (shorter) response. If the wait exceeds 120s and the user needs faster results, clicking this button is a viable fast-path.

**JavaScript fallback for completion detection**:
```javascript
// Check if response is still streaming (look for stop button or streaming indicator)
document.querySelector('[aria-label*="stop"], [aria-label*="Interrompi"]') !== null
```

### Response Extraction

**WARNING**: `get_page_text` is unreliable for ChatGPT — it often returns only the user query, not the assistant response.

**WARNING**: `javascript_tool` with `conversation-turn` selectors can be **blocked** by the `[BLOCKED: Cookie/query string data]` content filter when the response contains inline source URLs (e.g., `?utm_source=chatgpt.com`). This happens frequently with web-search-enabled responses.

**Primary — `read_page` two-step extraction** (most reliable):
1. Call `read_page(tabId, depth=5)` to get the page structure
2. Find the `article` element whose first child heading contains "ChatGPT ha detto" (or "ChatGPT said")
3. Call `read_page(tabId, ref_id="{article_ref}", depth=10)` to extract the full response tree
4. Parse the accessibility tree: headings become section titles, `generic` elements become text, `list/listitem` become bullet points, `link` elements provide source URLs

**Fallback — JavaScript extraction via conversation turns** (may be blocked):
```javascript
// Get the last conversation turn (works across ChatGPT versions)
const turns = document.querySelectorAll('[data-testid^="conversation-turn"]');
const lastTurn = turns[turns.length - 1];
lastTurn ? lastTurn.innerText.substring(0, 5000) : 'No turn found'
```

If JS returns `[BLOCKED: Cookie/query string data]`, switch to the `read_page` primary method above.

**If the JS response is longer than 5000 chars**, extract in chunks:
```javascript
const turns = document.querySelectorAll('[data-testid^="conversation-turn"]');
const lastTurn = turns[turns.length - 1];
lastTurn ? lastTurn.innerText.substring(5000, 10000) : ''
```

**Note**: The `[data-message-author-role="assistant"]` selector may not work on all ChatGPT versions (failed during testing). The `[data-testid^="conversation-turn"]` approach is more reliable when JS extraction is available.

### ChatGPT-Specific Notes

- **Model selection**: The skill does not change the selected model. Whatever model the user has active will be used. **Warning**: If the user has a "Thinking" model active (e.g., 5.2 Thinking, o3) with "Ragionamento esteso" (Extended reasoning) enabled, reasoning alone can take **4+ minutes** when combined with web search. The polling loop uses a 300s max timeout for these models. During reasoning, a "Rispondi subito" (Answer now) button is visible — it can be clicked to skip reasoning and get an immediate shorter response.
- **New chat**: Always start a new chat to avoid context contamination. If landing on an existing conversation, click "New chat" before proceeding.
- **File/image uploads**: Not supported — text queries only.
- **Web search**: ChatGPT may automatically perform web searches before generating. The "Verifica delle fonti" (Verifying sources) phase adds 10-30s before streaming starts.

---

## Google Gemini (gemini.google.com)

### Navigation

```
URL: https://gemini.google.com/app
```

Using `/app` path targets the chat interface, but **Gemini may still redirect to the marketing landing page** on first visit or with certain account types. If the landing page appears ("Aumenta la tua creativita'..."):

1. Look for "Prova Gemini" or "Try Gemini" button via `find(query="Prova Gemini")` or `find(query="Try Gemini")`
2. Click it — this may trigger a **consent dialog** ("Termini e privacy") requiring acceptance
3. After accepting, a **welcome dialog** ("Ti diamo il benvenuto in Gemini") may appear — click "Continua" / "Continue"
4. **Critical**: After these dialogs, call `tabs_context_mcp` — the tab ID may change due to cross-origin redirects. Match the new tab by URL containing `gemini.google.com`

This onboarding flow only happens once per account. Subsequent visits land directly on the chat interface.

### Input Discovery

**Primary method**: `find(query="message input")` or `find(query="enter a prompt")`

**Fallback**: `read_page(filter="interactive")` — look for:
- A `textarea` or `contenteditable` element
- Placeholder like "Enter a prompt here" or "Ask Gemini"

**Common patterns**:
- Input is at the bottom of the page
- A microphone icon and submit (arrow) button sit adjacent to the input

### Query Submission

**Important**: Gemini uses a `contenteditable` DIV, not a `<textarea>`. `form_input` will return `Element type "DIV" is not a supported form input`. Use JavaScript injection:

1. Click the input: `computer(action="left_click", ref="{input_ref}")`
2. Inject text via JavaScript:
   ```javascript
   const input = document.querySelector('[contenteditable="true"]') || document.querySelector('rich-textarea [contenteditable]');
   if (input) { input.focus(); input.textContent = ''; document.execCommand('insertText', false, 'YOUR QUERY'); }
   ```
   If `execCommand` does not work, use the fallback:
   ```javascript
   input.focus(); input.textContent = 'YOUR QUERY'; input.dispatchEvent(new Event('input', { bubbles: true }));
   ```
3. Submit: find and click the send button via `find(query="send button")` or `find(query="invia messaggio")`. Prefer the button click over Enter after JS injection, as Enter may not trigger submission when framework state is out of sync.

### Wait for Completion

**Streaming indicator**: Gemini shows a sparkle/loading animation while generating.

**Polling strategy**:
```
1. Initial wait: 5 seconds
2. Check for streaming indicators:
   - find(query="stop") or find(query="cancel") button → still generating
3. Completion signals:
   - find(query="share") or find(query="copy") button in the response area
   - find(query="modify response") or find(query="show drafts") appears
   - Thumbs up/down icons appear below the response
4. Max wait: 90 seconds
```

### Response Extraction

**WARNING**: `get_page_text` is unreliable for Gemini — it captures sidebar chat history, navigation, and location data alongside the response. Use `read_page` as the primary method.

**Primary — `read_page(depth=5)` with structured parsing**:
1. Call `read_page(tabId, filter="all", depth=5, max_chars=30000)`
2. Locate the heading "Gemini ha detto" (or "Gemini said") in the accessibility tree
3. Extract all `generic` elements that follow this heading until the next heading or input area
4. These elements contain the response text in sequential fragments — concatenate them

**Fallback — JavaScript**:
```javascript
// Gemini response containers (pattern may vary)
const responses = document.querySelectorAll('.response-container, .model-response-text, [class*="response"]');
responses.length > 0 ? responses[responses.length - 1].innerText : 'No response found'
```

**Last resort**: Use `get_page_text` and manually filter out sidebar noise (chat history, location, navigation) by looking for content after the query text.

### Gemini-Specific Notes

- **Multiple drafts**: Gemini sometimes shows multiple drafts. Extract the currently visible draft only.
- **Google Search grounding**: Some responses include "Search related topics" cards — include these references in the extracted sources.
- **Canvas/Artifacts**: If Gemini opens a side panel (canvas), use `read_page` on the main content area to avoid capturing the canvas.

---

## Perplexity (perplexity.ai)

### Navigation

```
URL: https://www.perplexity.ai
```

### Input Discovery

**Primary method**: `find(query="ask anything")` or `find(query="search input")`

**Fallback**: `read_page(filter="interactive")` — look for:
- A `textarea` or `input` with placeholder like "Ask anything..."
- The input is typically centered/prominent on the homepage

**Common patterns**:
- On the homepage, the search bar is prominent and centered
- On a thread page, the input may be at the bottom (follow-up input)

### Query Submission

Perplexity's input is typically a standard `<textarea>` or `<input>`, so `form_input` works reliably:

1. Click the input: `computer(action="left_click", ref="{input_ref}")`
2. Try `form_input(ref="{input_ref}", value="{query}")` — this is the preferred method
3. If `form_input` fails, use `computer(action="type", text="{query}")` — Perplexity handles keystroke simulation better than other providers
4. Submit: `computer(action="key", text="Return")`

### Wait for Completion

**Streaming indicator**: Perplexity shows "Searching...", "Reading sources...", then "Generating..." phases.

**Polling strategy**:
```
1. Initial wait: 8 seconds (Perplexity searches the web first, takes longer)
2. Check for streaming phases:
   - find(query="searching") → still in search phase
   - find(query="generating") → generating response
3. Completion signals:
   - find(query="copy") or find(query="share") button appears
   - find(query="ask follow-up") input appears
   - Source cards are fully rendered (numbered citations visible)
4. Max wait: 120 seconds (Perplexity is typically slower due to web search)
```

### Response Extraction

**Primary**: `get_page_text(tabId)` — returns the answer with inline citations.

**Fallback — JavaScript for structured extraction**:
```javascript
// Extract the answer and sources separately
const answer = document.querySelector('[class*="answer"], [class*="prose"]');
const sources = document.querySelectorAll('[class*="source"], [class*="citation"] a');
const sourceList = Array.from(sources).map(s => s.href).filter(Boolean);
JSON.stringify({
  answer: answer ? answer.innerText : 'No answer found',
  sources: [...new Set(sourceList)]
})
```

### Perplexity-Specific Notes

- **Source citations**: Perplexity is the strongest for cited sources. Always extract the source URLs — they are the most valuable output from this provider.
- **Follow-up questions**: Perplexity suggests follow-up questions. In Deep Research mode, these are excellent candidates for the next round of queries.
- **Focus modes**: Perplexity has different focus modes (All, Academic, Writing, etc.). The skill uses whatever mode is currently active. To use a specific focus, instruct the user to set it before invoking the skill.
- **Pro Search**: If the user has Perplexity Pro, responses may be more detailed. The skill works with both free and Pro accounts.
- **Model diversity**: Perplexity uses various AI models as backends (Grok, Claude, GPT, Sonar, etc.) depending on user settings and subscription tier. The active model name appears at the bottom of each response (e.g., "Preparato utilizzando Grok 4.1"). Different models may produce varying response quality and speed — the skill does not change the model selection.

---

## Cross-Provider Comparison

| Aspect | ChatGPT | Gemini | Perplexity |
|--------|---------|--------|------------|
| **Input type** | `textarea` (but may behave as contenteditable) | `contenteditable` DIV | `textarea` / `input` |
| **Best input method** | `form_input` or `execCommand` | `execCommand` (form_input fails) | `form_input` |
| **Submit method** | Enter or send button (prefer button after JS injection) | Send button (prefer over Enter after JS injection) | Enter |
| **Avg response time** | 10-30s (standard), 60-300s (Thinking models) | 10-25s | 15-45s (includes web search) |
| **Streaming indicator** | "Interrompi lo streaming" button | Sparkle animation / stop button | Searching → Reading → Generating |
| **Completion signal** | Copy/regenerate buttons | Share/copy/drafts/thumbs buttons | Copy/share + follow-up input |
| **Source citations** | Sometimes (web search mode) | Sometimes (Google grounding) | Always (primary feature) |
| **Best extraction** | `read_page(ref_id)` two-step | `read_page(depth=5)` | `get_page_text` |
| **`get_page_text` quality** | Poor (returns user query only) | Poor (sidebar noise) | Excellent |
| **JS extraction risk** | May be blocked by cookie/query filter | Works but noisy | Works well |
| **Onboarding required** | No (lands on chat) | Yes (consent + welcome on first visit) | No (lands on search) |
| **Tab ID stability** | Stable | Unstable (changes after consent flow) | Stable |

## Troubleshooting Common Issues

### Input Field Not Found

1. The page may not have fully loaded — add `computer(action="wait", duration=3)` and retry
2. A modal/popup may be covering the input — look for "close", "dismiss", "got it" buttons via `find`
3. The provider may have updated its UI — use `read_page(filter="interactive")` to discover all interactive elements and identify the input manually

### Response Not Appearing

1. The query may not have been submitted — check if the input still contains the text
2. A CAPTCHA or rate limit may have triggered — use `computer(action="screenshot")` to visually inspect
3. The provider may require selecting a model first (ChatGPT) — check for model selector prompts

### Extraction Returns Old Content

1. The response is still streaming — increase wait time
2. Multiple conversations in tab — always start a new chat per query
3. `get_page_text` captured the entire page — use JavaScript extraction to target only the latest response

### Provider Requires Login

This skill assumes pre-authentication. If a login page appears:
1. Report to the user: "Provider X requires login. Log in and retry."
2. Skip the provider and continue with the remaining ones
3. Note the skipped provider in the final synthesis
