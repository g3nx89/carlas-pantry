# Coordinare 5 agenti su backend Go + frontend React con ntm

## Architettura: due swarm con label sullo stesso repo

La chiave e' usare le **session label** di ntm. Questo ti permette di avere due swarm separati che lavorano nella stessa directory del progetto, ciascuno con il proprio set di agenti.

```bash
# Swarm backend: 3 agenti (2 Claude + 1 Codex)
ntm spawn myrepo --label backend --cc=2 --cod=1

# Swarm frontend: 2 agenti (2 Claude)
ntm spawn myrepo --label frontend --cc=2
```

Entrambe le sessioni lavorano in `~/Developer/myrepo/`. Senza `--label`, il secondo `spawn` sostituirebbe il primo -- con le label invece coesistono come sub-sessioni distinte.

## Passo 1: Riservare i file per evitare conflitti

Questo e' il passaggio critico. Le **file reservation** di ntm impediscono che un agente backend tocchi file frontend e viceversa.

```bash
# Riserva i path Go al team backend
ntm mail reserve myrepo --agent myrepo__cc_1 --paths "cmd/**/*.go,internal/**/*.go,pkg/**/*.go,go.mod,go.sum"
ntm mail reserve myrepo --agent myrepo__cc_2 --paths "cmd/**/*.go,internal/**/*.go,pkg/**/*.go"
ntm mail reserve myrepo --agent myrepo__cod_1 --paths "internal/**/*_test.go,pkg/**/*_test.go"

# Riserva i path React al team frontend
ntm mail reserve myrepo --agent myrepo__cc_3 --paths "src/**/*.tsx,src/**/*.ts,src/**/*.css,package.json"
ntm mail reserve myrepo --agent myrepo__cc_4 --paths "src/**/*.tsx,src/**/*.ts,public/**"
```

> Nota: i nomi agente (come `myrepo__cc_1`) sono assegnati da ntm. Verifica quelli effettivi con `ntm status myrepo --label backend` e `ntm status myrepo --label frontend`.

## Passo 2: Installare il pre-commit guard

Il guard blocca i commit che violano le reservation attive -- e' la rete di sicurezza definitiva.

```bash
ntm hooks guard install
```

Da questo momento, se un agente frontend prova a committare un file `.go` riservato al backend, il commit viene rifiutato.

## Passo 3: Assegnare i task ai due team

Usa `--cc` / `--cod` per mandare prompt a tutti gli agenti di un tipo nella sessione, oppure `--pane=N` per targettare un agente specifico.

```bash
# Task al team backend
ntm send myrepo --label backend --cc "Implementa l'endpoint REST /api/users con CRUD completo in internal/handler/users.go. Il contratto API e' in api/openapi.yaml."
ntm send myrepo --label backend --cod "Scrivi i test per internal/handler/users.go coprendo tutti i casi edge."

# Task al team frontend
ntm send myrepo --label frontend --pane=1 "Crea il componente UserList in src/components/UserList.tsx che consuma GET /api/users."
ntm send myrepo --label frontend --pane=2 "Crea il componente UserForm in src/components/UserForm.tsx per POST /api/users."
```

## Passo 4: Coordinazione cross-team con Agent Mail

Quando il backend ha completato il contratto API e il frontend deve saperlo, usa il sistema di mail:

```bash
# Il backend notifica il frontend che l'API e' pronta
ntm mail send myrepo --all "Il contratto API per /api/users e' finalizzato. Vedi api/openapi.yaml per i tipi e gli endpoint aggiornati."
```

Per messaggi mirati a un singolo agente:

```bash
ntm mail send myrepo --to myrepo__cc_3 "L'endpoint GET /api/users ora restituisce pagination. Aggiorna UserList per gestire i campi page/total_pages nella risposta."
```

## Passo 5: Monitoraggio

```bash
# Overview di tutte le sessioni attive
ntm list

# Dashboard visuale per ciascun team
ntm dashboard myrepo --label backend
ntm dashboard myrepo --label frontend

# Status rapido
ntm status myrepo --label backend
ntm status myrepo --label frontend

# Controllare i conflitti (file toccati da piu' agenti)
ntm --robot-snapshot --since=1h | jq '.conflicts'

# Verificare le reservation attive
ntm locks list myrepo --all-agents
```

Il dashboard mostra indicatori di conflitto sui pane coinvolti: bordo giallo = warning, bordo rosso = critico.

## Passo 6: Checkpoint prima di merge

Prima di integrare il lavoro dei due team:

```bash
ntm checkpoint save myrepo --label backend -m "backend users endpoint completo"
ntm checkpoint save myrepo --label frontend -m "frontend user components completi"

# Sincronizzazione: chiedi a tutti di committare
ntm send myrepo --label backend --all "Ferma il lavoro corrente, committa tutto e riporta lo stato."
ntm send myrepo --label frontend --all "Ferma il lavoro corrente, committa tutto e riporta lo stato."
```

## Schema riassuntivo

```
myrepo (stesso repo, stessa directory)
|
+-- session: myrepo --label backend
|   +-- pane 1: cc_1  -->  reservation: cmd/, internal/, pkg/, go.*
|   +-- pane 2: cc_2  -->  reservation: cmd/, internal/, pkg/
|   +-- pane 3: cod_1 -->  reservation: *_test.go
|
+-- session: myrepo --label frontend
|   +-- pane 1: cc_3  -->  reservation: src/**/*.tsx, src/**/*.ts, src/**/*.css
|   +-- pane 2: cc_4  -->  reservation: src/**/*.tsx, public/
|
+-- pre-commit guard: blocca commit che violano le reservation
+-- Agent Mail: comunicazione cross-session
```

## Alternativa avanzata: git worktree per isolamento totale

Se vuoi isolamento ancora piu' forte (zero rischio di conflitti a livello filesystem), puoi usare i **git worktree** di ntm. Ogni agente lavora nella propria copia della working directory:

```bash
ntm worktrees create myrepo --agent cc_1 --branch feature/backend-users
ntm worktrees create myrepo --agent cc_3 --branch feature/frontend-users
```

Questo e' piu' pesante da gestire (devi fare merge dei branch alla fine) ma elimina completamente la possibilita' che due agenti tocchino lo stesso file simultaneamente. Per la maggior parte dei casi, le file reservation + pre-commit guard sono sufficienti.

## Cleanup

```bash
ntm kill -f myrepo --label backend
ntm kill -f myrepo --label frontend
ntm hooks guard uninstall
```
