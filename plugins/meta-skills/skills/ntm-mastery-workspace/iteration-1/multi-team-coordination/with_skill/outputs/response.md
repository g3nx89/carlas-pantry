# Coordinare 2 team (Backend Go + Frontend React) con ntm -- 5 agenti senza conflitti

## Architettura consigliata

Usa le **session label** di ntm per creare due swarm separati che lavorano sulla stessa directory di progetto. Le label creano sub-sessioni distinte, ciascuna con i propri agenti, ma tutte puntano alla stessa codebase.

Layout proposto:
- **Backend swarm** (label `backend`): 2 Claude + 1 Codex = 3 agenti
- **Frontend swarm** (label `frontend`): 1 Claude + 1 Codex = 2 agenti

Puoi ovviamente redistribuire i 5 agenti come preferisci in base alle esigenze.

---

## Step 1 -- Spawn dei due swarm

```bash
# Swarm backend: 2 Claude (implementazione) + 1 Codex (test)
ntm spawn myapp --label backend --cc=2 --cod=1

# Swarm frontend: 1 Claude (implementazione) + 1 Codex (test)
ntm spawn myapp --label frontend --cc=1 --cod=1
```

Entrambi i gruppi lavorano in `~/Developer/myapp/` (o la tua `projects_base`), ma sono sessioni tmux separate. Puoi listarle con `ntm list` e vedrai due entry.

---

## Step 2 -- Riservare i file per evitare conflitti

Questo e' il passaggio cruciale. Le **file reservation** di ntm garantiscono che gli agenti del backend non tocchino i file del frontend e viceversa.

```bash
# Riserva il codice Go al team backend
ntm mail reserve myapp --agent cc_1 --paths "cmd/**/*.go,internal/**/*.go,pkg/**/*.go,go.mod,go.sum"
ntm mail reserve myapp --agent cc_2 --paths "cmd/**/*.go,internal/**/*.go,pkg/**/*.go"
ntm mail reserve myapp --agent cod_1 --paths "**/*_test.go,testdata/**"

# Riserva il codice React al team frontend
ntm mail reserve myapp --agent cc_3 --paths "web/src/**/*.tsx,web/src/**/*.ts,web/src/**/*.css,web/package.json"
ntm mail reserve myapp --agent cod_2 --paths "web/src/**/__tests__/**,web/cypress/**"
```

> **Nota**: adatta i glob pattern alla struttura effettiva del tuo repo. L'esempio assume `internal/`, `pkg/`, `cmd/` per Go e `web/src/` per React.

Per i file condivisi (es. `api/openapi.yaml`, `proto/*.proto`, file di configurazione), decidete quale team ne e' owner e riservate di conseguenza. Se entrambi i team devono leggerli ma solo uno deve modificarli, riservate la scrittura a quel team.

---

## Step 3 -- Installare il pre-commit guard

Il guard e' la rete di sicurezza: blocca qualsiasi `git commit` che tocchi file riservati ad un altro agente.

```bash
ntm hooks guard install
```

Da questo momento, se un agente del frontend provasse a committare un file `.go`, il commit viene rifiutato.

---

## Step 4 -- Assegnare i task ai team

```bash
# Task al team backend (tutti i Claude del backend)
ntm send myapp --label backend --cc "Implementa l'endpoint REST /api/products con handler, service layer e repository. File in internal/api/, internal/service/, internal/repository/. Non toccare nulla sotto web/."

# Task al Codex del backend (test)
ntm send myapp --label backend --cod "Scrivi test unitari e di integrazione per il package internal/api/. Usa testify. Non toccare file fuori da *_test.go e testdata/."

# Task al team frontend
ntm send myapp --label frontend --cc "Crea il componente React ProductList in web/src/components/ che chiama GET /api/products. Usa React Query per il fetching. Non toccare nulla fuori da web/src/."

ntm send myapp --label frontend --cod "Scrivi test con React Testing Library per ProductList in web/src/components/__tests__/. Non toccare file fuori da web/src/."
```

> **Buona pratica**: includi sempre nel prompt un reminder esplicito su quali directory l'agente puo' e non puo' toccare. Le reservation bloccano i commit, ma il reminder nel prompt evita che l'agente sprechi contesto tentando modifiche che poi verrebbero rifiutate.

---

## Step 5 -- Monitorare entrambi i team

```bash
# Dashboard del backend
ntm dashboard myapp --label backend

# Dashboard del frontend (in un altro terminale)
ntm dashboard myapp --label frontend

# Status rapido di tutto
ntm status myapp

# Controllare che non ci siano conflitti
ntm changes conflicts myapp

# Health check su tutti gli agenti
ntm health myapp
```

La dashboard mostra indicatori di conflitto sui pane (bordo giallo = warning, rosso = critico). Premi `c` dentro la dashboard per vedere l'uso del contesto per agente.

---

## Step 6 -- Coordinare tra i due team con Agent Mail

Quando il backend ha finito l'API e il frontend puo' iniziare l'integrazione:

```bash
# Il backend notifica il frontend
ntm mail send myapp --to cc_3 "L'endpoint GET /api/products e' pronto. Contratto: { id: int, name: string, price: float64 }. Vedi internal/api/handler.go per i dettagli."

# Verificare le inbox
ntm mail inbox myapp
```

---

## Step 7 -- Checkpoint prima di operazioni rischiose

```bash
# Salva lo stato prima di un merge tra i due filoni
ntm checkpoint save myapp -m "pre-merge: backend API + frontend components"
```

Se qualcosa va storto dopo il merge, puoi ripristinare con `ntm resume myapp`.

---

## Riepilogo dei comandi chiave

| Scopo | Comando |
|-------|---------|
| Creare swarm backend | `ntm spawn myapp --label backend --cc=2 --cod=1` |
| Creare swarm frontend | `ntm spawn myapp --label frontend --cc=1 --cod=1` |
| Riservare file Go | `ntm mail reserve myapp --agent cc_1 --paths "internal/**/*.go"` |
| Riservare file React | `ntm mail reserve myapp --agent cc_3 --paths "web/src/**/*.tsx"` |
| Attivare guardia commit | `ntm hooks guard install` |
| Inviare task al backend | `ntm send myapp --label backend --cc "..."` |
| Inviare task al frontend | `ntm send myapp --label frontend --cc "..."` |
| Messaggio cross-team | `ntm mail send myapp --to <agent> "..."` |
| Verificare conflitti | `ntm changes conflicts myapp` |
| Vedere le reservation | `ntm locks list myapp --all-agents` |
| Rilasciare lock bloccato | `ntm locks force-release myapp <lock-id> --note "motivo"` |
| Checkpoint | `ntm checkpoint save myapp -m "descrizione"` |
| Dashboard | `ntm dashboard myapp --label backend` |

---

## Variante avanzata: git worktree per isolamento totale

Se vuoi isolamento completo a livello filesystem (zero possibilita' di conflitto anche senza reservation), puoi usare i **git worktree** di ntm. Ogni team lavora su un branch separato nel proprio worktree:

```bash
# Crea worktree separati per ogni team
ntm worktrees create myapp --agent cc_1 --branch feature/backend-api
ntm worktrees create myapp --agent cc_3 --branch feature/frontend-products

# Verifica
ntm worktrees list myapp
```

Con i worktree ogni swarm ha la propria copia del repo su un branch dedicato. Non servono file reservation perche' i filesystem sono fisicamente separati. Il merge avviene via git alla fine.

**Trade-off**: piu' sicuro ma richiede un merge esplicito alla fine. Le file reservation sono piu' leggere e funzionano meglio per iterazioni veloci dove i due team devono vedere le modifiche dell'altro in tempo reale.
