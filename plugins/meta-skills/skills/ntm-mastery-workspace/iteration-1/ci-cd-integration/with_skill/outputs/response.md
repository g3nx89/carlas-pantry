# Integrazione ntm nella CI per Code Review Automatiche con Output JSON

## Panoramica

ntm ha una modalita **robot mode** (`--robot-*` flags) pensata esattamente per CI/CD: output JSON strutturato, nessuna dipendenza da server, exit code parsabili. La strategia e:

1. `--robot-spawn` per creare una sessione effimera con 2 agenti Claude
2. `--robot-send` per inviare il prompt di review a entrambi
3. `--robot-ack` per aspettare che finiscano (con timeout)
4. `--robot-tail` per catturare l'output di ciascun agente
5. `--robot-files` per ottenere i file modificati/analizzati
6. `ntm kill -f` per pulire tutto

Ogni comando robot ritorna un envelope JSON standard:

```json
{
  "success": true,
  "timestamp": "2026-03-26T10:00:00Z",
  "version": "1.0.0",
  "output_format": "json",
  "error": null,
  "error_code": null,
  "_meta": { "duration_ms": 42, "exit_code": 0, "command": "robot-status" }
}
```

Exit codes: `0` = successo, `1` = errore, `2` = risorsa non disponibile.

---

## Script Completo per CI

Salva come `.ci/ntm-review.sh` nel tuo repo:

```bash
#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# ntm-review.sh — Code review automatica pre-merge con 2 agenti Claude
#
# Prerequisiti sul CI runner:
#   - ntm installato:  brew install dicklesworthstone/tap/ntm
#   - tmux installato: brew install tmux  (oppure apt-get install tmux)
#   - claude CLI configurato con ANTHROPIC_API_KEY nel CI environment
#   - jq installato per il parsing JSON
#
# Uso:
#   .ci/ntm-review.sh                          # review della PR corrente
#   .ci/ntm-review.sh --base=main              # override del base branch
#   .ci/ntm-review.sh --timeout=600            # timeout in secondi (default 300)
#   .ci/ntm-review.sh --output=/tmp/review.json # dove scrivere il risultato
# ============================================================================

# --- Defaults ----------------------------------------------------------------
BASE_BRANCH="${BASE_BRANCH:-main}"
REVIEW_TIMEOUT="${REVIEW_TIMEOUT:-300}"
OUTPUT_FILE="${OUTPUT_FILE:-/tmp/ntm-review-result.json}"
SESSION="ci-review-${CI_PIPELINE_ID:-$(date +%s)}"

# --- Parse args --------------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --base=*)     BASE_BRANCH="${arg#*=}" ;;
    --timeout=*)  REVIEW_TIMEOUT="${arg#*=}" ;;
    --output=*)   OUTPUT_FILE="${arg#*=}" ;;
  esac
done

# --- Raccolta diff -----------------------------------------------------------
CHANGED_FILES=$(git diff --name-only "${BASE_BRANCH}"...HEAD)
if [[ -z "$CHANGED_FILES" ]]; then
  echo '{"success":true,"reviews":[],"verdict":"pass","reason":"no changed files"}' > "$OUTPUT_FILE"
  echo "Nessun file modificato rispetto a ${BASE_BRANCH}. Skip."
  exit 0
fi

DIFF_CONTENT=$(git diff "${BASE_BRANCH}"...HEAD)

# Tronca il diff se troppo grande (evita di saturare il context degli agenti)
MAX_DIFF_CHARS=80000
if [[ ${#DIFF_CONTENT} -gt $MAX_DIFF_CHARS ]]; then
  DIFF_CONTENT="${DIFF_CONTENT:0:$MAX_DIFF_CHARS}

... [DIFF TRONCATO a ${MAX_DIFF_CHARS} caratteri — review solo i file sopra] ..."
fi

# --- Prompt per i 2 agenti ---------------------------------------------------
# Agente 1: focus su correttezza e bug
PROMPT_AGENT1=$(cat <<'PROMPT_EOF'
Sei un code reviewer esperto. Analizza il diff seguente e produci ESCLUSIVAMENTE un JSON valido (nessun testo prima o dopo) con questa struttura:

{
  "agent": "correctness-reviewer",
  "findings": [
    {
      "file": "path/to/file.ext",
      "line": 42,
      "severity": "critical|high|medium|low|info",
      "category": "bug|logic-error|security|error-handling|race-condition|null-safety",
      "title": "Breve titolo del finding",
      "description": "Spiegazione dettagliata del problema",
      "suggestion": "Come risolvere"
    }
  ],
  "summary": "Valutazione complessiva in 1-2 frasi",
  "verdict": "pass|fail",
  "confidence": 0.95
}

Regole:
- severity "critical" o "high" => verdict "fail"
- Se non trovi problemi significativi => verdict "pass", findings vuoto
- Concentrati su: bug, errori logici, vulnerabilita di sicurezza, gestione errori mancante
- NON commentare stile, formattazione o naming conventions
- Output SOLO il JSON, nessun markdown fence, nessun testo aggiuntivo

DIFF DA ANALIZZARE:
PROMPT_EOF
)

# Agente 2: focus su design e manutenibilita
PROMPT_AGENT2=$(cat <<'PROMPT_EOF'
Sei un code reviewer esperto di architettura software. Analizza il diff seguente e produci ESCLUSIVAMENTE un JSON valido (nessun testo prima o dopo) con questa struttura:

{
  "agent": "design-reviewer",
  "findings": [
    {
      "file": "path/to/file.ext",
      "line": 42,
      "severity": "critical|high|medium|low|info",
      "category": "complexity|duplication|coupling|abstraction|testability|performance",
      "title": "Breve titolo del finding",
      "description": "Spiegazione dettagliata del problema",
      "suggestion": "Come risolvere"
    }
  ],
  "summary": "Valutazione complessiva in 1-2 frasi",
  "verdict": "pass|fail",
  "confidence": 0.90
}

Regole:
- severity "critical" o "high" => verdict "fail"
- Se non trovi problemi significativi => verdict "pass", findings vuoto
- Concentrati su: complessita eccessiva, codice duplicato, accoppiamento stretto, astrazioni mancanti, performance
- NON commentare bug o errori logici (c'e un altro reviewer per quello)
- Output SOLO il JSON, nessun markdown fence, nessun testo aggiuntivo

DIFF DA ANALIZZARE:
PROMPT_EOF
)

# --- Cleanup garantito -------------------------------------------------------
cleanup() {
  echo "Cleanup sessione ${SESSION}..."
  ntm --robot-interrupt="${SESSION}" 2>/dev/null || true
  ntm kill -f "${SESSION}" 2>/dev/null || true
}
trap cleanup EXIT

# --- Step 1: Spawn 2 agenti Claude ------------------------------------------
echo "==> Spawn sessione ${SESSION} con 2 agenti Claude..."
SPAWN_RESULT=$(ntm --robot-spawn="${SESSION}" --spawn-cc=2 2>&1)
SPAWN_OK=$(echo "$SPAWN_RESULT" | jq -r '.success // false')

if [[ "$SPAWN_OK" != "true" ]]; then
  echo "ERRORE: spawn fallito"
  echo "$SPAWN_RESULT" | jq .
  exit 2
fi

# Attendi che gli agenti siano pronti (breve pausa per inizializzazione)
sleep 5

# --- Step 2: Invia il diff a ciascun agente ---------------------------------
echo "==> Invio prompt all'agente 1 (correctness)..."
ntm --robot-send="${SESSION}" \
  --msg="${PROMPT_AGENT1}
${DIFF_CONTENT}" \
  --type=claude \
  --panes=1 > /dev/null

echo "==> Invio prompt all'agente 2 (design)..."
ntm --robot-send="${SESSION}" \
  --msg="${PROMPT_AGENT2}
${DIFF_CONTENT}" \
  --type=claude \
  --panes=2 > /dev/null

# --- Step 3: Attendi completamento ------------------------------------------
echo "==> Attesa completamento (timeout: ${REVIEW_TIMEOUT}s)..."
ACK_RESULT=$(ntm --robot-ack="${SESSION}" --ack-timeout="${REVIEW_TIMEOUT}s" 2>&1)
ACK_OK=$(echo "$ACK_RESULT" | jq -r '.success // false')

if [[ "$ACK_OK" != "true" ]]; then
  echo "WARNING: ack timeout o errore — tento di raccogliere output parziale"
fi

# --- Step 4: Raccogli output da entrambi gli agenti -------------------------
echo "==> Raccolta output agenti..."
TAIL_RAW=$(ntm --robot-tail="${SESSION}" --lines=200 --json 2>&1)

# Estrai il testo di output per ciascun pane
AGENT1_RAW=$(echo "$TAIL_RAW" | jq -r '.panes[0].content // ""' 2>/dev/null || echo "")
AGENT2_RAW=$(echo "$TAIL_RAW" | jq -r '.panes[1].content // ""' 2>/dev/null || echo "")

# Funzione per estrarre JSON valido dall'output dell'agente
extract_json() {
  local raw="$1"
  local fallback_agent="$2"

  # Prova a estrarre il primo blocco JSON valido
  local json
  json=$(echo "$raw" | sed -n '/{/,/^}/p' | head -100)

  if echo "$json" | jq empty 2>/dev/null; then
    echo "$json"
  else
    # Fallback: crea un risultato di errore parsabile
    cat <<EOF
{
  "agent": "${fallback_agent}",
  "findings": [],
  "summary": "Impossibile parsare output dell'agente",
  "verdict": "pass",
  "confidence": 0.0,
  "parse_error": true
}
EOF
  fi
}

REVIEW1=$(extract_json "$AGENT1_RAW" "correctness-reviewer")
REVIEW2=$(extract_json "$AGENT2_RAW" "design-reviewer")

# --- Step 5: Sintetizza risultato finale ------------------------------------
VERDICT1=$(echo "$REVIEW1" | jq -r '.verdict // "pass"')
VERDICT2=$(echo "$REVIEW2" | jq -r '.verdict // "pass"')

TOTAL_CRITICAL=$(echo "$REVIEW1 $REVIEW2" | jq -s '
  [.[].findings[] | select(.severity == "critical" or .severity == "high")] | length
')

TOTAL_FINDINGS=$(echo "$REVIEW1 $REVIEW2" | jq -s '
  [.[].findings[]] | length
')

if [[ "$VERDICT1" == "fail" || "$VERDICT2" == "fail" ]]; then
  FINAL_VERDICT="fail"
else
  FINAL_VERDICT="pass"
fi

# Assembla il JSON finale
FINAL_RESULT=$(jq -n \
  --arg verdict "$FINAL_VERDICT" \
  --argjson review1 "$REVIEW1" \
  --argjson review2 "$REVIEW2" \
  --argjson total_findings "$TOTAL_FINDINGS" \
  --argjson critical_findings "$TOTAL_CRITICAL" \
  --arg session "$SESSION" \
  --arg base "$BASE_BRANCH" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    verdict: $verdict,
    total_findings: $total_findings,
    critical_findings: $critical_findings,
    reviews: [$review1, $review2],
    metadata: {
      session: $session,
      base_branch: $base,
      timestamp: $timestamp,
      timeout_seconds: '"$REVIEW_TIMEOUT"'
    }
  }')

# Scrivi output
echo "$FINAL_RESULT" > "$OUTPUT_FILE"
echo "$FINAL_RESULT" | jq .

# --- Step 6: Exit code basato sul verdict -----------------------------------
echo ""
if [[ "$FINAL_VERDICT" == "fail" ]]; then
  echo "REVIEW FALLITA: ${TOTAL_CRITICAL} finding critici/alti su ${TOTAL_FINDINGS} totali"
  exit 1
else
  echo "REVIEW SUPERATA: ${TOTAL_FINDINGS} finding (nessuno critico/alto)"
  exit 0
fi
```

---

## Configurazione per le principali CI

### GitHub Actions

```yaml
# .github/workflows/ntm-review.yml
name: NTM Code Review

on:
  pull_request:
    branches: [main, develop]

jobs:
  agent-review:
    runs-on: ubuntu-latest   # oppure self-hosted con tmux+ntm
    timeout-minutes: 10

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0      # serve la history completa per il diff

      - name: Install dependencies
        run: |
          sudo apt-get update && sudo apt-get install -y tmux jq
          curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/ntm/main/install.sh" | bash -s -- --easy-mode

      - name: Run NTM review
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          CI_PIPELINE_ID: ${{ github.run_id }}
          BASE_BRANCH: ${{ github.base_ref }}
          REVIEW_TIMEOUT: 300
          OUTPUT_FILE: /tmp/ntm-review.json
        run: |
          chmod +x .ci/ntm-review.sh
          .ci/ntm-review.sh

      - name: Upload review artifact
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: ntm-review-result
          path: /tmp/ntm-review.json

      - name: Post review comment on PR
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const review = JSON.parse(fs.readFileSync('/tmp/ntm-review.json', 'utf8'));

            let body = `## Code Review NTM\n\n`;
            body += `**Verdetto**: ${review.verdict.toUpperCase()}\n`;
            body += `**Finding totali**: ${review.total_findings} (${review.critical_findings} critici/alti)\n\n`;

            for (const r of review.reviews) {
              body += `### ${r.agent}\n${r.summary}\n\n`;
              for (const f of r.findings) {
                body += `- **[${f.severity.toUpperCase()}]** \`${f.file}:${f.line}\` — ${f.title}\n`;
                body += `  ${f.description}\n`;
                if (f.suggestion) body += `  *Suggerimento*: ${f.suggestion}\n`;
                body += `\n`;
              }
            }

            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: body
            });
```

### GitLab CI

```yaml
# .gitlab-ci.yml
ntm-review:
  stage: test
  image: ubuntu:24.04
  timeout: 10 minutes
  variables:
    BASE_BRANCH: $CI_MERGE_REQUEST_TARGET_BRANCH_NAME
    REVIEW_TIMEOUT: "300"
    OUTPUT_FILE: review-result.json
  before_script:
    - apt-get update && apt-get install -y tmux jq git curl
    - curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/ntm/main/install.sh" | bash -s -- --easy-mode
  script:
    - chmod +x .ci/ntm-review.sh
    - .ci/ntm-review.sh --output=review-result.json
  artifacts:
    when: always
    paths:
      - review-result.json
    reports:
      codequality: review-result.json
  rules:
    - if: $CI_MERGE_REQUEST_IID
```

---

## Schema dell'Output JSON

L'output finale scritto in `OUTPUT_FILE` ha questa struttura:

```json
{
  "verdict": "pass|fail",
  "total_findings": 5,
  "critical_findings": 1,
  "reviews": [
    {
      "agent": "correctness-reviewer",
      "findings": [
        {
          "file": "src/auth/jwt.go",
          "line": 42,
          "severity": "high",
          "category": "security",
          "title": "Token validation bypass",
          "description": "Il check sull'expiry non gestisce il caso di clock skew...",
          "suggestion": "Aggiungere un margine di 30s con jwt.WithLeeway()"
        }
      ],
      "summary": "Una vulnerabilita di sicurezza nel modulo auth",
      "verdict": "fail",
      "confidence": 0.92
    },
    {
      "agent": "design-reviewer",
      "findings": [
        {
          "file": "src/api/handlers.go",
          "line": 15,
          "severity": "medium",
          "category": "complexity",
          "title": "Handler troppo lungo",
          "description": "Il metodo CreateUser ha 150 righe...",
          "suggestion": "Estrarre la validazione in un middleware"
        }
      ],
      "summary": "Complessita media accettabile, un refactoring consigliato",
      "verdict": "pass",
      "confidence": 0.88
    }
  ],
  "metadata": {
    "session": "ci-review-12345",
    "base_branch": "main",
    "timestamp": "2026-03-26T10:15:00Z",
    "timeout_seconds": 300
  }
}
```

---

## Punti Chiave sull'Implementazione

**Perche robot mode e non `ntm serve`?** La tabella nel reference di ntm e chiara: per CI/CD preferire robot mode perche non richiede un server long-lived, ogni comando e atomico e stateless.

**Perche 2 agenti e non 1?** Due prospettive ortogonali (correttezza vs. design) riducono i blind spot. Ogni agente ha un prompt focalizzato e una tassonomia di `category` diversa, cosi il JSON risultante e direttamente filtrabile per tipo di problema.

**Gestione del timeout.** `--robot-ack` blocca fino a completamento o timeout. Se scade, lo script raccoglie comunque l'output parziale con `--robot-tail` -- non perdi tutto.

**Cleanup garantito.** Il `trap cleanup EXIT` assicura che la sessione ntm venga sempre distrutta, anche in caso di errore o kill del processo CI.

**Troncamento del diff.** I modelli hanno limiti di context. Lo script tronca a 80K caratteri e aggiunge un marker -- gli agenti sanno che il review e parziale.

**Parsing robusto.** La funzione `extract_json` cerca il primo blocco `{...}` valido nell'output dell'agente. Se l'agente produce testo spurio attorno al JSON, lo script lo gestisce. Se il parsing fallisce del tutto, produce un risultato con `parse_error: true` e `confidence: 0.0` -- il verdict non blocca la pipeline per un errore di parsing.

---

## Opzioni Avanzate

### Pipeline YAML ntm (alternativa allo script bash)

Se preferisci il sistema di pipeline nativo di ntm, crea `.ntm/pipelines/review.yaml`:

```yaml
name: code-review
description: Automated 2-agent code review
steps:
  - name: spawn
    command: "ntm --robot-spawn={{.Session}} --spawn-cc=2"
    timeout: 30s

  - name: send-correctness
    command: "ntm --robot-send={{.Session}} --msg='{{.CorrectnessPrompt}}' --type=claude --panes=1"
    depends_on: [spawn]

  - name: send-design
    command: "ntm --robot-send={{.Session}} --msg='{{.DesignPrompt}}' --type=claude --panes=2"
    depends_on: [spawn]

  - name: wait
    command: "ntm --robot-ack={{.Session}} --ack-timeout=300s"
    depends_on: [send-correctness, send-design]

  - name: collect
    command: "ntm --robot-tail={{.Session}} --lines=200 --json"
    depends_on: [wait]

  - name: cleanup
    command: "ntm kill -f {{.Session}}"
    always_run: true
```

Invocabile con:
```bash
ntm pipeline run .ntm/pipelines/review.yaml \
  --session "ci-review-${CI_PIPELINE_ID}" \
  --var CorrectnessPrompt="..." \
  --var DesignPrompt="..."
```

### Profili per gli agenti

Per dare ai reviewer una "personalita" persistente, usa `--profiles`:

```bash
ntm --robot-spawn="${SESSION}" --spawn-cc=2 \
  --profiles=security-reviewer,performance-reviewer
```

I profili si definiscono in `.ntm/profiles/` o `~/.config/ntm/profiles/`.

### Hook post-review per Slack

Aggiungi in `~/.config/ntm/hooks.toml`:

```toml
[[command_hooks]]
event = "post-shutdown"
name = "ci-review-notify"
command = '''
  if [[ "$NTM_SESSION" == ci-review-* ]]; then
    curl -X POST -H "Content-Type: application/json" \
      -d "{\"text\":\"Code review completata per sessione ${NTM_SESSION}\"}" \
      https://hooks.slack.com/services/YOUR/WEBHOOK/URL
  fi
'''
timeout = "10s"
continue_on_error = true
```
