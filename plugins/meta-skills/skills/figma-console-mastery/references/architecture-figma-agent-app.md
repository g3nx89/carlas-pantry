# Architecture Analysis: Figma Design Agent — Mac App

> **Scope**: Analisi architetturale completa per la costruzione di un'applicazione macOS dedicata alla collaborazione su Figma. L'app wrappa il Claude Agent SDK e agisce come agente specializzato nel design, ricevendo istruzioni in linguaggio naturale e traducendole in operazioni Figma via Desktop Bridge Plugin.
>
> **Contesto di provenienza**: Questa analisi nasce dall'esplorazione di due progetti open-source — `figma-console-mcp` (southleft, server MCP per Figma) e `mcporter` (steipete, toolkit MCP) — e dall'esperienza operativa documentata nella skill `figma-console-mastery` (v1.4.0, 28 reference files, 61 tool verified).
>
> **Data analisi**: Marzo 2026. Basata su figma-console-mcp v1.14.0 e Claude Agent SDK v0.2.76.

---

## 1. L'Obiettivo

Costruire un'applicazione macOS "molto semplice" che:

1. Presenti un'interfaccia chat dove l'utente descrive cosa vuole progettare
2. Un agente Claude processi le istruzioni e operi direttamente su Figma Desktop
3. L'agente mostri screenshot del lavoro in corso per feedback iterativo
4. L'utente possa collaborare con l'agente in modo conversazionale ("sposta quel pulsante", "cambia il colore", "aggiungi una sidebar")

L'esperienza target è un **design pair-programming**: l'utente descrive l'intento, l'agente esegue in Figma, mostra il risultato, l'utente corregge, l'agente itera.

---

## 2. I Componenti in Gioco

### 2.1 figma-console-mcp (southleft)

Server MCP open-source che consente agli assistenti AI di interagire con Figma Desktop. Versione corrente: v1.14.0, MIT license.

**Architettura a 4 layer:**

```
Layer 4: MCP Transport — local.ts (6243 righe)
  ├── McpServer da @modelcontextprotocol/sdk
  ├── StdioServerTransport (comunicazione via stdin/stdout)
  ├── Registrazione tool (server.tool() per ogni operazione)
  └── Lifecycle management (startup, shutdown, signal handlers)

Layer 3: MCP Tool Wrappers — ~10,600 righe totali
  ├── figma-tools.ts      (3590) — tool di lettura/query (file data, components, variables)
  ├── write-tools.ts      (2636) — tool di mutazione (execute, fills, text, resize, move)
  ├── design-code-tools.ts (2952) — design-code parity, documentation generation
  ├── design-system-tools.ts (1072) — estrazione design system (kit, summary)
  └── comment-tools.ts     (344)  — gestione commenti

Layer 2: Connector Abstraction — ~1850 righe
  ├── IFigmaConnector      (75)   — interface con ~30 metodi async
  ├── WebSocketConnector   (301)  — implementazione via WebSocket (attiva)
  └── FigmaDesktopConnector (1553) — implementazione via CDP (deprecata, Figma l'ha bloccato)

Layer 1: Transport verso Figma — ~1630 righe
  ├── FigmaWebSocketServer (786)  — server WebSocket multi-client su porte 9223-9232
  ├── FigmaAPI             (540)  — client REST API per metadati file
  └── port-discovery.ts    (308)  — gestione porte, heartbeat, zombie detection
```

**Osservazione fondamentale**: il 75% del codice (~15K righe, Layer 3+4) è puro wrapper MCP — schemi Zod per i parametri, error handling e formatting delle risposte, compressione adattiva per non esaurire il context window, e logica MCP-specifica (content types, text formatting). La logica Figma vera risiede nel Layer 1+2: circa 2000 righe. `WebSocketConnector` da solo fornisce TUTTE le operazioni Figma come metodi async puliti: `executeCodeViaUI(code)`, `captureScreenshot(nodeId)`, `instantiateComponent(key)`, `setNodeFills(nodeId, fills)`, eccetera.

**Come funziona la comunicazione con Figma:**

```
MCP Server (Node.js) ──WebSocket──> Desktop Bridge Plugin (ui.html in Figma)
                                         │
                                    postMessage
                                         │
                                    Plugin Worker (code.js) ──figma.*──> Figma Canvas
```

Il Desktop Bridge Plugin è un plugin Figma che gira all'interno dell'app desktop. Ascolta su WebSocket (porte 9223-9232), riceve comandi JSON dal server MCP, li traduce in chiamate alla Figma Plugin API (`figma.createFrame()`, `figma.currentPage.selection`, etc.), e restituisce i risultati via WebSocket.

### 2.2 Claude Agent SDK (TypeScript)

SDK ufficiale Anthropic per costruire agenti. Versione: v0.2.76. Espone una funzione `query()` che ritorna un `AsyncGenerator<SDKMessage>` con streaming.

**Capacità chiave per questo progetto:**

- **MCP server esterni via stdio**: `mcpServers: { "name": { command: "npx", args: [...] } }` — l'SDK spawna il processo e gestisce la comunicazione MCP
- **MCP server in-process**: `createSdkMcpServer({ tools: [...] })` — definisci tool con Zod schemas direttamente in TypeScript, senza processo esterno
- **Entrambi contemporaneamente**: un agent può avere sia server MCP esterni che tool in-process
- **`allowedTools`**: whitelist delle tool che Claude può usare — permette di esporre un sottoinsieme dei tool disponibili
- **Streaming**: `includePartialMessages: true` per UI chat real-time
- **Multi-turn**: `MessageQueue` pattern o V2 preview `unstable_v2_createSession` per conversazioni continue
- **Hook system**: `canUseTool`, `PreToolUse`, `PostToolUse` per intercettare/controllare le chiamate

### 2.3 mcporter (steipete)

TypeScript runtime, CLI, e toolkit per MCP. Versione: v0.7.4.

**Cosa fa**: scopre MCP server configurati in vari editor (Cursor, Claude Code, VS Code, etc.), permette di chiamarli da CLI (`mcporter call figma-console.figma_get_status`), genera client TypeScript tipizzati (`mcporter emit-ts`), e gestisce un daemon per server stateful.

**Ruolo in questo progetto**: mcporter NON è necessario per l'app stessa. L'Agent SDK gestisce la connessione MCP nativamente. mcporter è utile solo come **strumento di sviluppo** — `mcporter list figma-console --schema` per esplorare i tool disponibili, `mcporter call` per testare operazioni senza lanciare l'app intera.

### 2.4 figma-console-mastery (skill v1.4.0)

Skill della piattaforma carlas-pantry che documenta best practices, pattern, regole, e ricette per l'uso di figma-console-mcp. Contiene 28 reference files (~600KB totali) con:

- **Essential Rules**: 23 MUST + 13 AVOID per l'uso corretto della Figma Plugin API
- **Component Recipes**: pattern per creare card, button, input, form, data table, modal, dashboard, sidebar, navbar, etc.
- **Decision Matrix**: albero decisionale G0→G4 per scegliere quale tool usare
- **Quality Dimensions**: 11 dimensioni per audit di qualità con script JS
- **Convergence Protocol**: anti-regression, journaling per-screen, recovery post-compaction

Questa knowledge base è il **differenziatore chiave** dell'agente — un assistente generico con 60 tool Figma è mediocre, ma un agente specializzato con le regole e i pattern giusti nel system prompt produce design di qualità.

---

## 3. Il Problema delle Sessioni Zombie

Questo è il problema operativo più critico riscontrato nell'uso quotidiano di figma-console-mcp con Claude Code, e la sua analisi è determinante per la scelta architetturale.

### 3.1 Meccanismo dei Zombie

Quando Claude Code avvia una sessione MCP, spawna `figma-console-mcp` come child process via stdio:

```
Claude Code (parent) ──stdin/stdout──> figma-console-mcp (child, PID 1234)
                                           └── WebSocket server su porta 9223
                                                └── Desktop Bridge Plugin connesso
```

Se Claude Code termina normalmente, invia SIGTERM al child → `shutdown()` in `local.ts:6160` pulisce tutto → porta rilasciata → file `/tmp/figma-console-mcp-9223.json` rimosso.

Ma se Claude Code **crasha**, viene **killato con SIGKILL**, o semplicemente il **processo parent muore inaspettatamente**:

1. Il child process (figma-console-mcp) **non riceve SIGTERM** — resta vivo come orfano
2. La porta 9223 resta **occupata** dal processo zombie
3. Il file heartbeat in `/tmp/` continua ad apparire "vivo" per 5 minuti (threshold in `port-discovery.ts:51`: `HEARTBEAT_STALE_MS = 5 * 60 * 1000`)
4. La prossima sessione Claude Code spawna un NUOVO figma-console-mcp → porta 9223 occupata → fallback a porta 9224
5. Il Desktop Bridge Plugin è ora connesso a **DUE server** (lo zombie su 9223 e il nuovo su 9224) — il plugin scanna tutte le porte 9223-9232 e si connette a ogni server trovato (`ui.html:689-765`)
6. I comandi vanno al server sbagliato, le risposte si incrociano → **comportamento imprevedibile**

Le difese esistenti nel codice (`port-discovery.ts:251-289`, `cleanupStalePortFiles()`) funzionano solo parzialmente:

- Rilevano PID morti → OK, ma il processo zombie è **tecnicamente vivo** (il PID esiste, Node.js event loop gira)
- Rilevano heartbeat stale dopo 5 minuti → troppo lento per l'utente
- La funzione gira **solo allo startup** di una nuova istanza, non periodicamente
- Non rileva processi che sono vivi ma il cui parent MCP è morto (il child non sa che il parent è andato via)

### 3.2 Impossibilità di Sessioni Parallele

Il codice supporta tecnicamente connessioni multi-client (`FigmaWebSocketServer` traccia i client per `fileKey`). Ma quando due sessioni MCP operano sullo **stesso file Figma**:

- Entrambi i server WebSocket ricevono eventi broadcast dal plugin (SELECTION_CHANGE, FILE_INFO, DOCUMENT_CHANGE)
- I comandi (EXECUTE_CODE, SET_NODE_FILLS) sono correttamente isolati — la risposta va solo al server richiedente
- MA le **mutazioni concorrenti** sullo stesso canvas Figma creano conflitti visivi: un agente crea un frame, l'altro lo sposta, il primo non sa che è stato spostato

Non esiste un meccanismo di locking o serializzazione delle operazioni tra server diversi.

### 3.3 Plugin che Smette di Connettersi

Il Desktop Bridge Plugin ha limiti rigidi nei retry (`ui.html:694-765`):

```javascript
var MAX_INITIAL_SCANS = 3;   // Dopo 3 scan iniziali senza trovare server → si arrende
// ...
if (wsReconnectAttempts <= 5) { ... }  // Dopo 5 retry per porta → stop
```

Non c'è un rescan periodico. Se il server MCP non era attivo quando il plugin è partito, il plugin non lo troverà mai. L'utente deve riavviare il plugin manualmente.

### 3.4 Perché Questo È un Problema Architetturale

Il problema zombie non è un bug nel codice di figma-console-mcp — è una **conseguenza strutturale** del modello MCP stdio. In questo modello:

- Il parent (Claude Code, Cursor, etc.) spawna il child (figma-console-mcp)
- La comunicazione avviene via stdin/stdout
- Il child non ha modo affidabile di sapere se il parent è ancora vivo
- Se il parent muore, il child diventa orfano ma resta funzionante
- Nessuna quantità di heartbeat, cleanup, o zombie detection risolve tutti i casi

La soluzione definitiva è **eliminare il modello parent-child**: l'app custom possiede direttamente il server WebSocket, non lo delega a un processo esterno.

---

## 4. Le Opzioni Architetturali Valutate

### Opzione A: figma-console-mcp come MCP Server Esterno (standard)

```
App → Agent SDK → spawna figma-console-mcp via MCP stdio → 60+ tool disponibili
```

L'Agent SDK gestisce figma-console-mcp come un qualsiasi MCP server:

```typescript
const q = query({
  prompt: userMessage,
  options: {
    mcpServers: {
      "figma-console": {
        command: "npx",
        args: ["-y", "figma-console-mcp@latest"],
        env: { FIGMA_ACCESS_TOKEN: process.env.FIGMA_ACCESS_TOKEN }
      }
    }
  }
});
```

**Pro**: zero codice custom, tutti i 60+ tool pronti, updates gratis da npm.

**Contro**:
- 60+ tool nel context di Claude → overhead, confusione nella selezione
- Il modello MCP stdio genera ESATTAMENTE il problema zombie descritto sopra
- Child process overhead (~2-3s cold start)
- Nessuna possibilità di customizzazione dei tool
- Se l'app crasha, il child process resta zombie

### Opzione B: Embeddare il Transport Layer dal Sorgente

```
App (singolo processo) → WebSocketConnector → FigmaWebSocketServer → Desktop Bridge
                       → Agent SDK + createSdkMcpServer (tool in-process)
```

Estraiamo dal repository figma-console-mcp solo il layer di transport (Layer 1+2, ~2000 righe) e lo integriamo direttamente nell'app. I tool sono definiti in-process con `createSdkMcpServer()`.

**Pro**:
- **Zero zombie per design** — un processo, una porta, shutdown pulito
- **Zero port contention** — il server WebSocket è parte dell'app, non un processo esterno
- **Tool set custom** — esponiamo solo i tool necessari per il design assistant
- **Accesso diretto** — chiamate a `WebSocketConnector` senza serializzazione MCP
- **Operation queue** — possiamo implementare mutex per serializzare operazioni Figma

**Contro**:
- ~2000 righe di codice da mantenere (fork parziale)
- Perdiamo gli updates automatici di figma-console-mcp (ma il transport layer è stabile)
- Dobbiamo scrivere i nostri tool wrapper (ma sono più semplici dei 10K righe di wrapper MCP)

### Opzione C: Ibrido — MCP Server + allowedTools + Tool Custom

```
App → Agent SDK → figma-console-mcp (MCP stdio, ~20 tool filtrati via allowedTools)
               → createSdkMcpServer (tool custom in-process)
```

Usiamo figma-console-mcp come server MCP esterno ma con `allowedTools` per esporre solo ~20 tool curati. Aggiungiamo tool custom in-process per logica di alto livello.

**Pro**: codice collaudato, tool curati, estensibilità con tool custom.

**Contro**:
- **NON risolve il problema zombie** — il modello è sempre MCP stdio con child process
- Child process overhead
- Non possiamo implementare un operation mutex cross-process

### Valutazione Comparativa

| Criterio | Peso | A (MCP full) | B (Embed) | C (Hybrid) |
|----------|------|:---:|:---:|:---:|
| Risolve zombie | 30% | 2/10 | **10/10** | 2/10 |
| Tempo a MVP | 20% | 9/10 | 5/10 | 8/10 |
| Qualità agente | 20% | 5/10 | **9/10** | 8/10 |
| Manutenibilità | 15% | 9/10 | 6/10 | 8/10 |
| Customizzazione | 15% | 3/10 | **10/10** | 7/10 |
| **Score pesato** | | **4.9** | **8.1** | **5.9** |

Il problema zombie pesa 30% perché è un dealbreaker per l'esperienza utente — un'app che richiede kill manuali di processi, restart del plugin, e attese di 5 minuti non è utilizzabile.

---

## 5. La Raccomandazione: Opzione B (Embed Transport Layer)

### 5.1 Cosa Embeddiamo

Dal repository `figma-console-mcp` (path: `/Users/afato/Projects/forks/figma-console-mcp/src/`), estraiamo SOLO questi file:

| File sorgente | Righe | Ruolo | Dipendenze esterne |
|--------------|-------|-------|-------------------|
| `core/websocket-server.ts` | 786 | Server WebSocket multi-client. Gestisce connessioni, comandi request/response, eventi (selection, page change, document change). È il cuore della comunicazione con Figma. | `ws` (WebSocket library) |
| `core/websocket-connector.ts` | 301 | Implementa `IFigmaConnector` via WebSocket. Ogni metodo corrisponde a un'operazione Figma: `executeCodeViaUI()`, `captureScreenshot()`, `instantiateComponent()`, etc. | Nessuna (usa solo websocket-server) |
| `core/figma-api.ts` | 540 | Client REST API per metadati file. Serve per `figma_get_file_data` e operazioni che richiedono dati non accessibili via Plugin API. Richiede `FIGMA_ACCESS_TOKEN`. | `fetch` (nativo Node.js 18+) |
| `core/figma-connector.ts` | 75 | Interfaccia `IFigmaConnector` — contratto stabile con ~30 metodi. | Nessuna |
| `core/port-discovery.ts` | 308 | Gestione file porta in `/tmp/`, heartbeat, cleanup zombie. Adattabile al nostro lifecycle. | `fs`, `os` (built-in) |
| `core/logger.ts` | ~60 | Logger wrapper. | `pino` |
| **Totale** | **~2070** | | |

### 5.2 Cosa NON Embeddiamo

| File/Directory | Righe | Motivo esclusione |
|---------------|-------|-------------------|
| `local.ts` | 6243 | Orchestrazione MCP server — sostituito dal lifecycle della nostra app |
| `core/figma-tools.ts` | 3590 | Wrapper MCP per tool di lettura — sostituiti dai nostri tool custom |
| `core/write-tools.ts` | 2636 | Wrapper MCP per tool di mutazione — sostituiti dai nostri tool custom |
| `core/design-code-tools.ts` | 2952 | Wrapper MCP per design-code parity — non necessario per design agent |
| `core/design-system-tools.ts` | 1072 | Wrapper MCP per DS extraction — reimplementato come singolo tool custom |
| `core/comment-tools.ts` | 344 | Commenti Figma — non core per design agent |
| `core/figma-desktop-connector.ts` | 1553 | CDP connector — deprecato, Figma ha bloccato `--remote-debugging-port` |
| `core/console-monitor.ts` | 519 | Monitoraggio console log — non necessario per design agent |
| `browser-manager.ts` | ~500 | Gestione browser per CDP — deprecato |
| `apps/` | ~2000 | Token Browser e DS Dashboard — app web, non necessarie |
| `index.ts` (Cloudflare) | ~5000 | Worker Cloudflare — irrilevante per app locale |
| **Totale escluso** | **~22,400** | |

Il rapporto è drastico: embeddiamo ~2000 righe, ne scartiamo ~22,000.

### 5.3 Perché il Transport Layer È Stabile

Il codice che embeddiamo cambia raramente perché:

1. **Il protocollo WebSocket è un contratto fisso**: i comandi (`EXECUTE_CODE`, `CAPTURE_SCREENSHOT`, `SET_NODE_FILLS`, `INSTANTIATE_COMPONENT`, etc.) sono stringhe JSON scambiate tra server e plugin. Aggiungere un nuovo comando significa aggiungere UN case nel plugin e UN metodo nel connector — non breaking change.

2. **La Figma Plugin API è stabile**: i metodi come `figma.createFrame()`, `figma.currentPage.selection`, `node.exportAsync()` non cambiano tra versioni.

3. **L'interfaccia `IFigmaConnector`** ha ~30 metodi che coprono tutte le operazioni. Nuovi metodi vengono aggiunti, ma quelli esistenti non vengono modificati.

4. **Il CHANGELOG di figma-console-mcp** (v1.11-v1.14) mostra che i cambiamenti sono quasi tutti nel Layer 3 (nuovi MCP tool, miglioramenti alle description) e Layer 4 (nuovi parametri, adaptive compression). Il Layer 1+2 riceve solo bugfix e nuovi comandi aggiuntivi.

Se upstream aggiunge un nuovo comando (es. `figma_lint_design` → `LINT_DESIGN`), il merge è un singolo metodo nel connector:
```typescript
async lintDesign(nodeId?: string, rules?: string[]): Promise<any> {
  return this.wsServer.sendCommand('LINT_DESIGN', { nodeId, rules }, 120000);
}
```

### 5.4 Architettura dell'App

```
figma-design-agent/
├── src/
│   ├── main.ts                      # Entry point: avvia server WS, poi UI
│   ├── figma/                       # EMBEDDED da figma-console-mcp (~2000 righe)
│   │   ├── websocket-server.ts      # FigmaWebSocketServer
│   │   ├── websocket-connector.ts   # WebSocketConnector (IFigmaConnector)
│   │   ├── figma-api.ts             # REST API client
│   │   ├── figma-connector.ts       # Interface
│   │   ├── port-discovery.ts        # Gestione porte
│   │   └── types.ts                 # Tipi condivisi
│   ├── agent/
│   │   ├── figma-agent.ts           # Setup Agent SDK + tool registration
│   │   ├── system-prompt.ts         # Knowledge da figma-console-mastery
│   │   ├── operation-queue.ts       # Mutex per serializzare operazioni Figma
│   │   └── tools/
│   │       ├── core-tools.ts        # figma_execute, screenshot, navigate, status
│   │       ├── manipulation-tools.ts # set_fills, set_text, resize, move, etc.
│   │       └── discovery-tools.ts   # design_system_kit, search_components
│   └── ui/                          # Chat interface (Electron renderer o web)
│       ├── App.tsx
│       ├── ChatMessage.tsx
│       ├── FigmaPreview.tsx         # Mostra screenshot inline
│       └── StatusBar.tsx            # Stato connessione Figma
├── package.json
└── electron/                        # (opzionale) Electron wrapper per .app
    ├── main.ts
    └── preload.ts
```

### 5.5 Lifecycle Management

```typescript
class FigmaDesignApp {
  private wsServer: FigmaWebSocketServer;
  private connector: WebSocketConnector;
  private operationQueue: OperationQueue;

  async start() {
    // 1. Pulisci zombie da crash precedenti
    cleanupStalePortFiles();

    // 2. Avvia WebSocket server (porta singola, nessun conflitto)
    this.wsServer = new FigmaWebSocketServer({ port: 9223, host: 'localhost' });
    await this.wsServer.start();
    advertisePort(9223);

    // 3. Registra cleanup handlers per TUTTI i modi di terminazione
    const cleanup = () => { unadvertisePort(9223); this.wsServer?.stop(); };
    process.on('exit', cleanup);
    process.on('SIGINT', () => { cleanup(); process.exit(0); });
    process.on('SIGTERM', () => { cleanup(); process.exit(0); });
    process.on('uncaughtException', (err) => {
      console.error('Uncaught:', err);
      cleanup();
      process.exit(1);
    });

    // 4. Crea connector e operation queue
    this.connector = new WebSocketConnector(this.wsServer);
    this.operationQueue = new OperationQueue();

    // 5. Attendi connessione Desktop Bridge Plugin
    await this.waitForPluginConnection();

    // 6. Avvia agent e UI
    await this.startAgent();
    await this.startUI();
  }

  private waitForPluginConnection(): Promise<void> {
    return new Promise((resolve) => {
      if (this.wsServer.isClientConnected()) { resolve(); return; }
      this.wsServer.on('connected', () => resolve());
      // Mostra istruzioni all'utente: "Apri il Desktop Bridge Plugin in Figma"
    });
  }
}
```

### 5.6 Tool Set dell'Agente

I tool sono definiti in-process con `createSdkMcpServer()`. Ogni tool chiama direttamente il `WebSocketConnector`:

```typescript
import { tool, createSdkMcpServer } from "@anthropic-ai/claude-agent-sdk";
import { z } from "zod";

function createFigmaTools(connector: WebSocketConnector, queue: OperationQueue) {
  return createSdkMcpServer({
    name: "figma-design",
    version: "1.0.0",
    tools: [
      // CORE — Il tool più importante. Accesso completo alla Plugin API.
      tool("figma_execute",
        "Execute JavaScript in Figma Plugin API context. Use async IIFE with outer return. " +
        "Has full access to figma.* global. For complex multi-step operations.",
        { code: z.string(), timeout: z.number().optional().default(5000) },
        async ({ code, timeout }) => {
          return queue.execute(async () => {
            const result = await connector.executeCodeViaUI(code, Math.min(timeout, 30000));
            return { content: [{ type: "text", text: JSON.stringify(result) }] };
          });
        }
      ),

      // SCREENSHOT — Validazione visiva, il pattern fondamentale
      tool("figma_screenshot",
        "Capture screenshot of a node or current page for visual validation. " +
        "ALWAYS call after creating/modifying visual elements.",
        { nodeId: z.string().optional().describe("Node ID. Omit for current page.") },
        async ({ nodeId }) => {
          const result = await connector.captureScreenshot(nodeId || "0:1", { format: "png" });
          if (result.imageData) {
            return { content: [
              { type: "image", data: result.imageData, mimeType: "image/png" },
              { type: "text", text: JSON.stringify({ width: result.width, height: result.height }) }
            ]};
          }
          return { content: [{ type: "text", text: "Screenshot failed: " + JSON.stringify(result) }] };
        }
      ),

      // DISCOVERY
      tool("figma_search_components", "Search for components in current file by name",
        { query: z.string() },
        async ({ query }) => {
          const result = await connector.getLocalComponents();
          // Filtra per query
          const filtered = result.components?.filter((c: any) =>
            c.name.toLowerCase().includes(query.toLowerCase())
          );
          return { content: [{ type: "text", text: JSON.stringify(filtered) }] };
        }
      ),

      // ... altri ~15 tool per manipolazione, instantiation, variables
    ]
  });
}
```

**Tool set completo consigliato** (~20 tool):

| Categoria | Tool | Operazione sottostante |
|-----------|------|----------------------|
| **Core** | `figma_execute` | `connector.executeCodeViaUI()` |
| **Core** | `figma_screenshot` | `connector.captureScreenshot()` |
| **Core** | `figma_status` | `wsServer.isClientConnected()` + `getConnectedFileInfo()` |
| **Core** | `figma_navigate` | Non embedded — richiede browser URL (implementare con executeCodeViaUI) |
| **Core** | `figma_selection` | `wsServer.getCurrentSelection()` |
| **Discovery** | `figma_search_components` | `connector.getLocalComponents()` + filtro |
| **Discovery** | `figma_component_details` | `connector.getComponentFromPluginUI()` |
| **Discovery** | `figma_design_system` | `connector.getVariables()` + `getLocalComponents()` |
| **Manipolazione** | `figma_set_fills` | `connector.setNodeFills()` |
| **Manipolazione** | `figma_set_text` | `connector.setTextContent()` |
| **Manipolazione** | `figma_rename` | `connector.renameNode()` |
| **Manipolazione** | `figma_resize` | `connector.resizeNode()` |
| **Manipolazione** | `figma_move` | `connector.moveNode()` |
| **Manipolazione** | `figma_create_child` | `connector.createChildNode()` |
| **Manipolazione** | `figma_clone` | `connector.cloneNode()` |
| **Manipolazione** | `figma_delete` | `connector.deleteNode()` |
| **Manipolazione** | `figma_set_strokes` | `connector.setNodeStrokes()` |
| **Components** | `figma_instantiate` | `connector.instantiateComponent()` |
| **Components** | `figma_set_instance_props` | `connector.setInstanceProperties()` |
| **Tokens** | `figma_setup_tokens` | `connector.createVariableCollection()` + batch |

Nota: `figma_execute` è il "jolly" — permette QUALSIASI operazione Plugin API in un singolo roundtrip. I tool individuali esistono per operazioni frequenti dove uno schema Zod validato è più sicuro di codice libero.

### 5.7 Il System Prompt — La Parte Critica

Il system prompt è il **vero differenziatore** tra un agente Figma mediocre e uno che produce design di qualità. Deve condensare la conoscenza della skill `figma-console-mastery` in ~3000-5000 token:

**Contenuti essenziali da includere:**

1. **Identità e flusso di lavoro**: "Sei un design assistant. Ricevi istruzioni in linguaggio naturale e le traduci in operazioni Figma. Dopo ogni modifica visiva, fai screenshot per validare."

2. **Pattern figma_execute** (da `recipes-foundation.md`):
   - Async IIFE con outer return: `return (async () => { ... })()`
   - Load font prima di settare testo: `await figma.loadFontAsync()`
   - Settare `layoutMode` PRIMA di padding/spacing
   - Non mutare array Figma direttamente — clone, modify, reassign
   - Non ritornare nodi Figma raw — ritorna `{ id, name, ... }`

3. **Ordine operazioni** (da `essential-rules.md`):
   - Creare frame/container PRIMA dei figli
   - Settare auto-layout PRIMA di padding
   - Caricare font PRIMA di settare testo
   - Usare `figma_screenshot` DOPO ogni mutazione visiva

4. **Decision matrix** (da `tool-playbook.md`):
   - Componente locale? → `figma_search_components` → `figma_instantiate`
   - Singola proprietà? → tool dedicato (`figma_set_fills`, `figma_set_text`)
   - Operazione complessa? → `figma_execute` con script multi-step
   - Validazione? → `figma_screenshot` sempre

5. **Anti-pattern critici** (da `anti-patterns.md`):
   - Non settare constraints su GROUP (convertire a FRAME prima)
   - Non usare `getNodeById()` sync — usare `getNodeByIdAsync()`
   - Non splittare page-switch e data-read in chiamate separate

### 5.8 Operation Queue — Serializzazione delle Mutazioni

Per prevenire conflitti tra operazioni concorrenti (es. due tool_use nella stessa risposta dell'agente):

```typescript
class OperationQueue {
  private queue: Promise<any> = Promise.resolve();

  async execute<T>(operation: () => Promise<T>): Promise<T> {
    const result = new Promise<T>((resolve, reject) => {
      this.queue = this.queue
        .then(() => operation())
        .then(resolve)
        .catch(reject);
    });
    return result;
  }
}
```

Ogni tool che muta Figma passa attraverso la queue. Le letture (screenshot, search) possono bypassarla.

---

## 6. Come Mitigare il Problema Zombie Nell'Uso Corrente (Pre-App)

Mentre l'app custom è in sviluppo, ecco mitigazioni pratiche per l'uso corrente di figma-console-mcp con Claude Code:

### 6.1 Script di Cleanup Manuale

```bash
#!/bin/bash
# kill-figma-zombies.sh
# Trova e termina tutti i processi figma-console-mcp orfani

pgrep -f "figma-console-mcp" | while read pid; do
  # Controlla se il parent è ancora vivo
  ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  if [ "$ppid" = "1" ]; then
    echo "Killing zombie figma-console-mcp (PID: $pid, orphan)"
    kill "$pid"
  fi
done

# Pulisci port file stale
rm -f /tmp/figma-console-mcp-*.json
```

### 6.2 Hook Claude Code per Cleanup Pre-Sessione

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "bash /path/to/kill-figma-zombies.sh 2>/dev/null || true"
      }]
    }]
  }
}
```

### 6.3 Ridurre la Finestra Zombie

Nel fork locale di figma-console-mcp, ridurre `HEARTBEAT_STALE_MS` da 5 minuti a 30 secondi e aggiungere detection dello stdin EOF:

```typescript
// In local.ts, dopo la creazione del transport
process.stdin.on('end', async () => {
  logger.info('Stdin closed — parent process likely terminated. Shutting down.');
  await server.shutdown();
  process.exit(0);
});

process.stdin.on('error', async () => {
  logger.info('Stdin error — shutting down.');
  await server.shutdown();
  process.exit(0);
});
```

---

## 7. Riepilogo delle Decisioni

| Decisione | Scelta | Motivazione |
|-----------|--------|-------------|
| Architettura app | **Embed transport layer** (Option B) | Elimina zombie per design, singolo processo, lifecycle pulito |
| Codice da embeddare | ~2000 righe (Layer 1+2) | Il 90% del codice figma-console-mcp è wrapper MCP non necessario |
| Tool framework | `createSdkMcpServer()` in-process | Tool custom, zero overhead MCP stdio, schema Zod nativi |
| Tool set | ~20 tool curati | Meno tool = migliore decision-making di Claude |
| System prompt | Condensato da figma-console-mastery | Regole essenziali, pattern, anti-pattern, decision matrix |
| Zombie prevention | Architetturale (singolo processo) + cleanup al boot | Nessun child process = nessun orfano possibile |
| Operation serialization | Queue/mutex in-process | Previene mutazioni concorrenti sullo stesso canvas |
| mcporter | Solo per dev-time testing | `mcporter call/list` utile durante sviluppo, non nell'app |
| UI framework | Electron (v1) o web localhost (prototipo) | Trade-off semplicità vs native feel |

---

## 8. Prossimi Passi

1. **Estrarre il transport layer** — fork dei ~2000 righe, adattare import, aggiungere types
2. **Prototipo CLI** — Agent SDK + transport embedded + chat in terminale (~100-200 righe)
3. **Validare il flusso** — testare create/screenshot/iterate loop end-to-end
4. **System prompt** — condensare figma-console-mastery knowledge
5. **UI** — chat interface con screenshot inline
6. **Packaging** — Electron wrapper per distribuzione .app
