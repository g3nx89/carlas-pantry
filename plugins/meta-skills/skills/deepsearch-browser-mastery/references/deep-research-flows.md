# Native Deep Research Flows

Per-provider activation, configuration, and extraction patterns for native Deep Research features. These are separate from the skill's own multi-round "Deep Research mode" — here, each provider's built-in deep research engine does the iterative work autonomously.

> **Last verified**: February 2026

---

## Key Difference from Quick Search

In Quick Search mode, the skill dispatches a single query, extracts the response, and optionally synthesizes across providers. In Native Deep Research mode, each provider runs its own multi-step research process internally (browsing dozens of sources, reasoning, structuring a report). This changes the automation in three ways:

1. **Wait times are 5-20x longer** — reports take minutes, not seconds
2. **Synthesis is optional** — each provider already produces a structured report. The typical use case is to save each report where the user requests (file, clipboard, specific directory), not to cross-synthesize them
3. **Output is richer** — structured reports with sections, citations, and sometimes embedded images/tables

---

## ChatGPT Deep Research

### Activation

ChatGPT has a **dedicated page** for Deep Research:

```
URL: https://chatgpt.com/deep-research
```

Navigating here lands directly in Deep Research mode — no clicks needed. The input placeholder reads "Ottieni un report dettagliato" ("Get a detailed report").

### Interface Elements

| Element | Location | Purpose | `find` query |
|---------|----------|---------|-------------|
| Version selector | Toolbar, after "+" | Switch between "Deep Research" and "Legacy" | `find("Deep Research")` → button |
| App integrations | Toolbar, "App ∨" | Toggle data sources (GitHub, Gmail, Atlassian Rovo, Adobe Acrobat, etc.) | `find("App")` → button |
| Site filter | Toolbar, "Siti ∨" | Restrict to specific websites or search the full web | `find("Sites")` or `find("Siti")` → button |
| File upload | Toolbar, "+" | Attach files for context | `find("Aggiungi file")` or `find("Add files")` |
| Send button | Right side of input | Submit the query | `find("send prompt button")` or `find("invia prompt")` |

### Version Selector

The "Deep Research ∨" dropdown contains:

- **Versione** (header label)
- **Deep Research** ✓ (default, currently selected)
- **Legacy** (older version)

For automation, verify "Deep Research" is checked. If "Legacy" is active, click "Deep Research" to switch.

### App Integrations (Data Sources)

The "App ∨" dropdown shows toggleable integrations:

**Connected (toggle on/off):**
- Atlassian Rovo
- GitHub
- Gmail

**Available to connect:**
- Ace Knowledge Graph, Ace Quiz Maker, Adobe Acrobat, and more
- "Collega altre" (Connect more) link at bottom

Each connected app has an on/off toggle. For automation, leave defaults unless the user explicitly requests enabling specific integrations.

### Site Filter

The "Siti ∨" dropdown provides:

- **Cerca sul web** ✓ (Search the web — default)
- **Siti specifici (N)** (Specific sites — user-configured list)
- **Gestisci siti** (Manage sites — opens configuration)

For focused research, the user can pre-configure specific sites. Automation defaults to "Cerca sul web".

### Query Submission

Same input mechanics as regular ChatGPT (see `provider-interactions.md`). The input is a `textarea` — use `form_input` or `execCommand('insertText')` fallback.

### Wait Strategy

Deep Research reports take **significantly longer** than regular responses:

| Phase | Duration | Indicator |
|-------|----------|-----------|
| Planning | 10-30s | "Pianificazione della ricerca..." or similar planning text |
| Web browsing | 1-5 min | Progress indicators showing sources being visited |
| Report generation | 1-3 min | Streaming text with sections appearing |
| **Total** | **3-10 min** | Completion: full report visible with source list |

**Polling strategy:**
```
1. Initial wait: 30 seconds
2. Check for active research indicators:
   - find("stop") or find("interrompi") → still working → wait 30s → repeat
   - Progress text visible (source count, browsing phase) → still working
3. Completion signals:
   - Report sections fully rendered (headings, bullet lists, source cards)
   - find("copy") or find("share") button appears in report area
   - find("sources") or find("fonti") section visible at end of report
4. Max wait: 600 seconds (10 minutes)
```

### Report Extraction

ChatGPT Deep Research produces a **structured report** — longer and more organized than regular responses. Use the same `read_page(ref_id)` two-step extraction from `provider-interactions.md`, but expect much larger output.

**Chunked extraction** may be necessary — reports can exceed 10,000 characters:
```javascript
const turns = document.querySelectorAll('[data-testid^="conversation-turn"]');
const lastTurn = turns[turns.length - 1];
// Extract in chunks
lastTurn ? lastTurn.innerText.substring(0, 5000) : ''    // chunk 1
lastTurn ? lastTurn.innerText.substring(5000, 10000) : '' // chunk 2
lastTurn ? lastTurn.innerText.substring(10000, 15000) : '' // chunk 3
```

If JS extraction is blocked (cookie/query filter — common with source-heavy reports), fall back to `read_page(ref_id, depth=10)`.

### Previous Reports

The `/deep-research` homepage shows cards for previous reports with title, snippet, and date. These are read-only references — the skill does not interact with them.

---

## Google Gemini Deep Research

### Activation

Gemini Deep Research is a **tool toggle** on the regular chat page — not a separate URL.

```
URL: https://gemini.google.com/app
Activation: Strumenti → Deep Research
```

**Steps:**
1. Navigate to `https://gemini.google.com/app`
2. `find("Strumenti")` → click the "Strumenti" (Tools) button
3. In the dropdown, `find("Deep Research")` → click
4. Verify: a **"Deep Research ✕"** chip appears in the toolbar between "Strumenti" and the model selector
5. The input placeholder changes to "Che cosa vuoi cercare?" ("What do you want to search?")
6. A **"Fonti ∨"** (Sources) row appears below the input

**Deactivation:** Click the ✕ on the "Deep Research" chip.

### Tools Menu (Strumenti)

The full menu contains:

| Tool | Description |
|------|-------------|
| Crea immagine | Image generation |
| Canvas | Collaborative editing canvas |
| **Deep Research** | Multi-step web research |
| Crea video | Video generation |
| Create music | Music generation (Novità) |
| Apprendimento guidato | Guided learning |

### Source Configuration (Fonti)

The "Fonti ∨" dropdown appears **only when Deep Research is active**. It shows:

**"Scegli una o più fonti"** (Choose one or more sources):

| Source | Icon | Default | Notes |
|--------|------|---------|-------|
| Ricerca (Google Search) | Google "G" | ✅ Selected | Primary web search |
| Gmail | Gmail icon | ○ | Searches user's email |
| Drive | Drive icon | ○ | Searches Google Drive files |
| Chat | Chat icon | ○ | Searches Google Chat messages |

Sources are **multi-selectable** — multiple can be active simultaneously. For automation, default to "Ricerca" only unless the user requests workspace sources.

### Model Selector (Independent)

The model selector ("Veloce ∨") operates **independently** from Deep Research:

| Mode | Description | Model |
|------|-------------|-------|
| Veloce | Quick answers | Gemini 3 |
| Ragionamento | Complex problem solving | Gemini 3 |
| Pro (Novità) | Advanced math/programming | Gemini 3.1 Pro |

Deep Research can run with any of these models. The model choice affects quality and speed.

### Query Submission

Same mechanics as regular Gemini — `contenteditable` div requires JavaScript injection:
```javascript
const el = document.querySelector('[contenteditable="true"]') || document.querySelector('rich-textarea [contenteditable]');
if (el) { el.focus(); document.execCommand('insertText', false, 'QUERY'); }
```
Then click the send button: `find("invia messaggio")` or `find("send button")`.

### Wait Strategy

| Phase | Duration | Indicator |
|-------|----------|-----------|
| Research planning | 5-15s | Planning/thinking animation |
| Source browsing | 1-5 min | Progress indicators, source cards appearing |
| Report generation | 1-3 min | Streaming text |
| **Total** | **2-8 min** | |

**Polling strategy:**
```
1. Initial wait: 20 seconds
2. Check for active research:
   - find("stop") or find("cancel") → still working → wait 20s → repeat
   - Sparkle animation visible → still generating
3. Completion signals:
   - find("share") or find("copy") buttons appear
   - find("modify response") or thumbs up/down icons
   - Deep Research chip remains but progress indicators disappear
4. Max wait: 480 seconds (8 minutes)
```

### Report Extraction

Use `read_page(depth=5)` then parse — same as regular Gemini but expect larger output. Locate "Gemini ha detto" / "Gemini said" heading, then extract the full response tree.

---

## Perplexity Deep Research

### Activation

Perplexity Deep Research is a **mode toggle** in the "+" menu — not a separate URL.

```
URL: https://www.perplexity.ai
Activation: "+" button → Deep research
```

**Steps:**
1. Navigate to `https://www.perplexity.ai`
2. `find("Add files or tools")` → click the "+" button inside the input area
3. In the menu, `find("Deep research")` → click (element type: `menuitemradio`)
4. Verify: a **"Deep research"** chip appears in the toolbar next to the "+" button
5. The menu item shows a ✓ checkmark when active

**Deactivation:** Open the "+" menu again and click "Deep research" to uncheck it.

### "+" Menu (Full Contents)

| Option | Type | Description |
|--------|------|-------------|
| Upload files or images | Action | Attach files to query |
| Add files from cloud | Submenu → | Cloud storage integrations |
| Connectors and sources | Submenu → | Toggle search sources |
| **Deep research** | Toggle (menuitemradio) | Native deep research mode |
| Model council | Feature (Max badge) | Multi-model consensus |
| More → Create files and apps | Action | Code/app generation |
| More → Learn step by step | Action | Step-by-step learning mode |

### Source Configuration (Connectors and Sources)

Accessible from "+" → "Connectors and sources":

| Source | Type | Default |
|--------|------|---------|
| Web | Toggle | ✅ Enabled |
| Academic | Toggle | ○ Off |
| Gmail with Calendar | Integration (↗) | Requires setup |
| Google Drive | Integration (↗) | Requires setup |
| Social | Toggle | ○ Off |
| Asana | Integration (↗) | Requires setup |
| Confluence | Integration (↗) | Requires setup |
| Dropbox | Integration (↗) | Requires setup |

Native toggles (Web, Academic, Social) can be switched directly. Integration sources (↗) require external OAuth setup — not automatable inline.

### Model Selector (Independent)

The model dropdown operates independently from Deep Research:

| Model | Notes |
|-------|-------|
| Sonar | Perplexity's native model |
| Gemini 3 Flash | Fast Google model |
| Gemini 3.1 Pro | Advanced Google model |
| GPT-5.2 | OpenAI model |
| Claude Sonnet 4.6 | Anthropic model |
| Claude Opus 4.6 | Anthropic model |
| Grok 4.1 | xAI model |
| Kimi K2.5 | Moonshot model |

A **Thinking toggle** is also available for models that support it. The model affects response quality and speed.

### Query Submission

Standard Perplexity input — `textarea` works with `form_input`:
```
1. find("ask anything") or find("search input") → click
2. form_input(ref, value="QUERY")
3. computer(action="key", text="Return")
```

### Wait Strategy

| Phase | Duration | Indicator |
|-------|----------|-----------|
| Source search | 10-30s | "Searching..." with source cards populating |
| Deep analysis | 1-4 min | "Analyzing sources..." or thinking indicator |
| Report generation | 30s-2 min | Streaming text with inline citations |
| **Total** | **2-5 min** | |

**Polling strategy:**
```
1. Initial wait: 15 seconds
2. Check for active research:
   - find("searching") or find("generating") → still working → wait 15s → repeat
   - Progress phase text visible → still working
3. Completion signals:
   - find("copy") or find("share") button appears
   - find("ask follow-up") input appears
   - Source cards fully rendered with numbered citations
4. Max wait: 300 seconds (5 minutes)
```

### Report Extraction

`get_page_text` remains the best method — Perplexity produces clean output with inline citations. For very long reports, supplement with JavaScript chunked extraction.

---

## Cross-Provider Comparison

| Aspect | ChatGPT | Gemini | Perplexity |
|--------|---------|--------|------------|
| **Activation method** | Dedicated URL `/deep-research` | Strumenti → Deep Research (chip toggle) | "+" → Deep research (menuitemradio toggle) |
| **Clicks to activate** | 0 (navigate directly) | 2 | 2 |
| **Mode indicator** | Version dropdown ✓ | Chip with ✕ in toolbar | Chip in toolbar + ✓ in menu |
| **Source options** | Sites (whitelist) + App integrations | Google Search, Gmail, Drive, Chat | Web, Academic, Social + integrations |
| **Model independence** | No (fixed Deep Research model) | Yes (Veloce / Ragionamento / Pro) | Yes (8+ models + Thinking) |
| **Typical wait** | 3-10 min | 2-8 min | 2-5 min |
| **Max wait** | 600s | 480s | 300s |
| **Output format** | Structured report with sections and sources | Long-form response with Google Search grounding | Long-form with inline citations and source cards |
| **Input type** | `textarea` | `contenteditable` div | `textarea` |
| **Extraction method** | `read_page(ref_id)` two-step or chunked JS | `read_page(depth=5)` structured parse | `get_page_text` |

---

## Output Handling

### Synthesis Is Optional

Unlike Quick Search mode, native Deep Research does **not** require cross-provider synthesis. Each provider already produces a self-contained, structured report with sources. Cross-synthesizing three 5,000+ word reports would produce an unwieldy result.

**Default behavior**: Save each provider's report individually to the location the user specifies.

**When synthesis adds value:**
- Comparing provider conclusions on controversial topics
- Identifying gaps where one provider covered something others missed
- Producing a unified executive summary from multiple reports

### Saving Reports

The typical use case is to save reports to a user-specified location. Ask the user where to save before starting, or default to a timestamped file.

**Save patterns:**
```
# Single provider report
{output_dir}/deepsearch-{provider}-{date}.md

# Multiple provider reports
{output_dir}/deepsearch-chatgpt-{date}.md
{output_dir}/deepsearch-gemini-{date}.md
{output_dir}/deepsearch-perplexity-{date}.md
```

**Report file structure:**
```markdown
# Deep Research Report: {query}

> Provider: {provider name} ({active model if visible})
> Date: {date}
> Mode: Native Deep Research

{full report text as extracted from provider}

## Sources
{source list from provider}
```

---

## Automation Workflow

### Phase 0: Setup & Activation

```
1. tabs_context_mcp → get browser state
2. Create tabs:
   - ChatGPT: navigate to https://chatgpt.com/deep-research
   - Gemini: navigate to https://gemini.google.com/app
   - Perplexity: navigate to https://www.perplexity.ai
3. Wait 3s for page load
4. Activate Deep Research mode:
   - ChatGPT: verify "Deep Research ✓" in version dropdown (already active via URL)
   - Gemini: find("Strumenti") → click → find("Deep Research") → click → verify chip
   - Perplexity: find("Add files or tools") → click → find("Deep research") → click → verify chip
5. Handle onboarding dialogs (Gemini especially)
```

### Phase 1: Configuration (Optional)

Only if the user requests specific source/app/site configuration:

```
ChatGPT:
  - App integrations: find("App") → toggle desired integrations
  - Site filter: find("Siti") → select "Siti specifici" or add sites

Gemini:
  - Sources: find("Fonti") → toggle Gmail/Drive/Chat alongside Ricerca
  - Model: find("Apri selettore modalità") → select Veloce/Ragionamento/Pro

Perplexity:
  - Sources: find("Add files or tools") → "Connectors and sources" → toggle Web/Academic/Social
  - Model: click model dropdown → select desired model
```

### Phase 2: Query Dispatch

Same Tiered Input Strategy as Quick Search (see SKILL.md):
1. `form_input` for `textarea` elements (ChatGPT, Perplexity)
2. `execCommand('insertText')` for `contenteditable` divs (Gemini)
3. Submit via Enter or send button click

### Phase 3: Extended Wait

Poll every 20-30 seconds (less frequent than Quick Search):
- ChatGPT: max 600s
- Gemini: max 480s
- Perplexity: max 300s

Use provider-specific completion signals documented above.

### Phase 4: Extraction & Save

1. Extract full report using provider-specific methods
2. Save to user-specified location (or ask where to save)
3. Optionally synthesize if user requests cross-provider comparison
