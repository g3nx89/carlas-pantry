# Integrazione NTM nella Pipeline CI per Code Review Automatiche

## Approccio

Per il tuo caso d'uso -- 2 agenti Claude che fanno code review prima di ogni merge con output JSON parsabile -- il percorso ottimale e' **robot mode** (`--robot-*` flags). La reference di ntm lo conferma esplicitamente:

> CI/CD pipelines -> Robot mode (simpler, no server dependency)

Robot mode produce un envelope JSON standard su ogni comando:

```json
{
  "success": true,
  "timestamp": "2026-01-27T07:00:00Z",
  "version": "1.0.0",
  "output_format": "json",
  "error": null,
  "error_code": null,
  "hint": null,
  "_meta": { "duration_ms": 42, "exit_code": 0, "command": "robot-status" }
}
```

Exit codes: `0` = successo, `1` = errore, `2` = non disponibile.

---

## Script Completo per CI

Questo script e' pronto per essere integrato in GitHub Actions, GitLab CI, o qualsiasi runner che supporti bash. Spawn 2 agenti Claude, invia il diff della PR come prompt di review, raccoglie gli output, li sintetizza in un report JSON parsabile, e fallisce la pipeline se ci sono issue critiche.

```bash
#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# ci-code-review.sh
#
# Code review automatica pre-merge con 2 agenti Claude via ntm robot mode.
# Output: JSON parsabile su stdout + file di report.
#
# Requisiti:
#   - ntm v1.x installato sul runner CI
#   - claude CLI configurato (ANTHROPIC_API_KEY nel runner)
#   - jq installato
#
# Variabili d'ambiente attese (da CI):
#   CI_PIPELINE_ID   - ID univoco della pipeline (o GITHUB_RUN_ID, etc.)
#   CI_MERGE_BASE     - Branch target (default: main)
#   CI_SOURCE_BRANCH  - Branch sorgente della PR
#
# Exit codes:
#   0 - Review passata (nessun issue critico)
#   1 - Review trovato issue critici (blocca merge)
#   2 - Errore infrastrutturale (ntm/agenti non disponibili)
###############################################################################

# --- Configurazione ---
PIPELINE_ID="${CI_PIPELINE_ID:-${GITHUB_RUN_ID:-$(date +%s)}}"
SESSION="ci-review-${PIPELINE_ID}"
MERGE_BASE="${CI_MERGE_BASE:-main}"
SOURCE_BRANCH="${CI_SOURCE_BRANCH:-HEAD}"
TIMEOUT_SECONDS=300
REPORT_DIR="${CI_REPORT_DIR:-.ntm/ci-reports}"
REPORT_FILE="${REPORT_DIR}/review-${PIPELINE_ID}.json"

# --- Funzioni di utilita' ---
log() { echo "[ntm-review] $(date -u +%H:%M:%S) $*" >&2; }

cleanup() {
  log "Cleanup: interruzione e kill della sessione ${SESSION}"
  ntm --robot-interrupt="${SESSION}" 2>/dev/null || true
  ntm kill -f "${SESSION}" 2>/dev/null || true
}
trap cleanup EXIT

fail_infra() {
  echo '{"success":false,"review_passed":null,"error":"'"$1"'","agents":[],"findings":[]}' | tee "${REPORT_FILE}"
  exit 2
}

# --- Pre-flight checks ---
log "Verifica dipendenze..."
command -v ntm >/dev/null 2>&1 || fail_infra "ntm non trovato nel PATH"
command -v jq  >/dev/null 2>&1 || fail_infra "jq non trovato nel PATH"

ntm deps -v >/dev/null 2>&1 || fail_infra "ntm deps check fallito"

mkdir -p "${REPORT_DIR}"

# --- Step 1: Genera il diff della PR ---
log "Generazione diff ${MERGE_BASE}..${SOURCE_BRANCH}"
DIFF_CONTENT=$(git diff "${MERGE_BASE}...${SOURCE_BRANCH}" -- '*.go' '*.ts' '*.py' '*.js' '*.rs' '*.java' 2>/dev/null || git diff "${MERGE_BASE}..${SOURCE_BRANCH}" 2>/dev/null)

if [ -z "${DIFF_CONTENT}" ]; then
  log "Nessuna modifica trovata, skip review"
  echo '{"success":true,"review_passed":true,"error":null,"agents":[],"findings":[],"summary":"No changes to review"}' | tee "${REPORT_FILE}"
  exit 0
fi

# Tronca diff se troppo lungo (evita overflow context agente)
DIFF_LINES=$(echo "${DIFF_CONTENT}" | wc -l)
if [ "${DIFF_LINES}" -gt 2000 ]; then
  log "Diff troncato da ${DIFF_LINES} a 2000 righe"
  DIFF_CONTENT=$(echo "${DIFF_CONTENT}" | head -n 2000)
  DIFF_CONTENT="${DIFF_CONTENT}

... [TRONCATO: ${DIFF_LINES} righe totali, mostrando le prime 2000] ..."
fi

CHANGED_FILES=$(git diff --name-only "${MERGE_BASE}...${SOURCE_BRANCH}" 2>/dev/null || git diff --name-only "${MERGE_BASE}..${SOURCE_BRANCH}" 2>/dev/null)

# --- Step 2: Spawn 2 agenti Claude ---
log "Spawn sessione ${SESSION} con 2 agenti Claude..."
SPAWN_RESULT=$(ntm --robot-spawn="${SESSION}" --spawn-cc=2 --json 2>&1)

if ! echo "${SPAWN_RESULT}" | jq -e '.success == true' >/dev/null 2>&1; then
  log "ERRORE: spawn fallito"
  fail_infra "Spawn sessione fallito: $(echo "${SPAWN_RESULT}" | jq -r '.error // "unknown"')"
fi

log "Sessione ${SESSION} attiva con 2 agenti"

# --- Step 3: Invia prompt di review ai 2 agenti (ruoli diversi) ---

# Agente 1: Review di correttezza logica e bug
PROMPT_AGENT_1=$(cat <<'REVIEW_PROMPT'
You are a code reviewer in a CI pipeline. Your role: **Logic & Correctness Reviewer**.

Analyze the following diff for:
- Logic errors, off-by-one bugs, null/nil pointer risks
- Missing error handling, unchecked returns
- Race conditions, concurrency issues
- Security vulnerabilities (injection, auth bypass, data exposure)

Output your findings as a JSON array. Each finding MUST follow this exact schema:
```json
[
  {
    "severity": "critical|high|medium|low",
    "file": "path/to/file.ext",
    "line": 42,
    "category": "bug|security|error-handling|concurrency|logic",
    "title": "Short description",
    "description": "Detailed explanation of the issue",
    "suggestion": "How to fix it"
  }
]
```

If no issues found, output: `[]`

IMPORTANT: Output ONLY the JSON array, no markdown fences, no preamble, no commentary.

--- CHANGED FILES ---
REVIEW_PROMPT
)

PROMPT_AGENT_2=$(cat <<'REVIEW_PROMPT'
You are a code reviewer in a CI pipeline. Your role: **Maintainability & Quality Reviewer**.

Analyze the following diff for:
- Code duplication or missed abstraction opportunities
- Naming clarity (variables, functions, types)
- Missing or inadequate tests for new code paths
- API contract violations, breaking changes
- Performance anti-patterns (N+1 queries, unnecessary allocations)

Output your findings as a JSON array. Each finding MUST follow this exact schema:
```json
[
  {
    "severity": "critical|high|medium|low",
    "file": "path/to/file.ext",
    "line": 42,
    "category": "duplication|naming|testing|api-contract|performance",
    "title": "Short description",
    "description": "Detailed explanation of the issue",
    "suggestion": "How to fix it"
  }
]
```

If no issues found, output: `[]`

IMPORTANT: Output ONLY the JSON array, no markdown fences, no preamble, no commentary.

--- CHANGED FILES ---
REVIEW_PROMPT
)

# Componi prompt finali con il diff
FULL_PROMPT_1="${PROMPT_AGENT_1}
${CHANGED_FILES}

--- DIFF ---
${DIFF_CONTENT}"

FULL_PROMPT_2="${PROMPT_AGENT_2}
${CHANGED_FILES}

--- DIFF ---
${DIFF_CONTENT}"

log "Invio prompt ad agente 1 (Logic & Correctness)..."
ntm --robot-send="${SESSION}" --msg="${FULL_PROMPT_1}" --panes=0 --type=claude >/dev/null 2>&1

log "Invio prompt ad agente 2 (Maintainability & Quality)..."
ntm --robot-send="${SESSION}" --msg="${FULL_PROMPT_2}" --panes=1 --type=claude >/dev/null 2>&1

# --- Step 4: Attendi completamento ---
log "Attesa completamento agenti (timeout: ${TIMEOUT_SECONDS}s)..."
ntm --robot-ack="${SESSION}" --ack-timeout="${TIMEOUT_SECONDS}s" >/dev/null 2>&1 || {
  log "WARNING: ack timeout, tento raccolta parziale..."
}

# Pausa breve per flush output
sleep 5

# --- Step 5: Raccogli output degli agenti ---
log "Raccolta output agenti..."
AGENT1_RAW=$(ntm --robot-tail="${SESSION}" --panes=0 --lines=200 --json 2>&1)
AGENT2_RAW=$(ntm --robot-tail="${SESSION}" --panes=1 --lines=200 --json 2>&1)

# Estrai il testo di output da ciascun pane
AGENT1_TEXT=$(echo "${AGENT1_RAW}" | jq -r '.panes[0].output // .output // ""' 2>/dev/null || echo "")
AGENT2_TEXT=$(echo "${AGENT2_RAW}" | jq -r '.panes[0].output // .output // ""' 2>/dev/null || echo "")

# --- Step 6: Parsing JSON dalle risposte ---
# Gli agenti dovrebbero restituire JSON array puro.
# Estraiamo il JSON array anche se c'e' testo intorno.
extract_json_array() {
  local text="$1"
  # Cerca il primo [ ... ] valido nel testo
  echo "${text}" | sed -n '/^\[/,/^\]/p' | jq '.' 2>/dev/null || \
  echo "${text}" | grep -oP '\[.*\]' | head -1 | jq '.' 2>/dev/null || \
  echo '[]'
}

FINDINGS_1=$(extract_json_array "${AGENT1_TEXT}")
FINDINGS_2=$(extract_json_array "${AGENT2_TEXT}")

# --- Step 7: Merge e deduplica findings ---
MERGED_FINDINGS=$(jq -s '
  (.[0] // []) + (.[1] // [])
  | map(. + {id: (input_line_number | tostring)})
  | group_by(.file + .title)
  | map(
      if length > 1 then
        .[0] + {deduplicated: true, agents_agreed: true}
      else
        .[0] + {deduplicated: false, agents_agreed: false}
      end
    )
  | sort_by(
      if .severity == "critical" then 0
      elif .severity == "high" then 1
      elif .severity == "medium" then 2
      else 3 end
    )
' <<< "${FINDINGS_1}
${FINDINGS_2}" 2>/dev/null || echo '[]')

# --- Step 8: Calcola verdetto ---
CRITICAL_COUNT=$(echo "${MERGED_FINDINGS}" | jq '[.[] | select(.severity == "critical")] | length')
HIGH_COUNT=$(echo "${MERGED_FINDINGS}" | jq '[.[] | select(.severity == "high")] | length')
TOTAL_COUNT=$(echo "${MERGED_FINDINGS}" | jq 'length')

# Policy: blocca se ci sono critical, o piu' di 3 high
if [ "${CRITICAL_COUNT}" -gt 0 ] || [ "${HIGH_COUNT}" -gt 3 ]; then
  REVIEW_PASSED=false
  VERDICT="BLOCKED"
else
  REVIEW_PASSED=true
  VERDICT="PASSED"
fi

# --- Step 9: Genera report JSON finale ---
FINAL_REPORT=$(jq -n \
  --argjson findings "${MERGED_FINDINGS}" \
  --argjson critical "${CRITICAL_COUNT}" \
  --argjson high "${HIGH_COUNT}" \
  --argjson total "${TOTAL_COUNT}" \
  --argjson passed "${REVIEW_PASSED}" \
  --arg verdict "${VERDICT}" \
  --arg session "${SESSION}" \
  --arg pipeline "${PIPELINE_ID}" \
  --arg base "${MERGE_BASE}" \
  --arg source "${SOURCE_BRANCH}" \
  '{
    success: true,
    review_passed: $passed,
    verdict: $verdict,
    error: null,
    pipeline_id: $pipeline,
    session: $session,
    branches: {
      base: $base,
      source: $source
    },
    summary: {
      total_findings: $total,
      critical: $critical,
      high: $high,
      medium: ([$findings[] | select(.severity == "medium")] | length),
      low: ([$findings[] | select(.severity == "low")] | length),
      consensus_findings: ([$findings[] | select(.agents_agreed == true)] | length)
    },
    agents: [
      {
        id: 0,
        role: "Logic & Correctness Reviewer",
        findings_count: ([$findings[] | select(.deduplicated == false or .agents_agreed == true)] | length)
      },
      {
        id: 1,
        role: "Maintainability & Quality Reviewer",
        findings_count: ([$findings[] | select(.deduplicated == false or .agents_agreed == true)] | length)
      }
    ],
    findings: $findings,
    timestamp: (now | todate)
  }')

# Scrivi report su file e stdout
echo "${FINAL_REPORT}" | jq '.' | tee "${REPORT_FILE}"

# --- Step 10: Cleanup e exit ---
log "Review completata: ${VERDICT} (${TOTAL_COUNT} findings: ${CRITICAL_COUNT} critical, ${HIGH_COUNT} high)"

if [ "${REVIEW_PASSED}" = "true" ]; then
  exit 0
else
  exit 1
fi
```

---

## Integrazione con GitHub Actions

```yaml
# .github/workflows/ntm-review.yml
name: NTM Code Review

on:
  pull_request:
    branches: [main, develop]

jobs:
  agent-review:
    runs-on: ubuntu-latest  # o self-hosted runner con ntm
    timeout-minutes: 10

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # serve per git diff completo

      - name: Setup ntm
        run: |
          # Installa ntm (adatta al tuo metodo di distribuzione)
          curl -sSL https://raw.githubusercontent.com/Dicklesworthstone/ntm/main/install.sh | bash
          ntm deps -v

      - name: Run Agent Code Review
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          CI_PIPELINE_ID: ${{ github.run_id }}
          CI_MERGE_BASE: ${{ github.base_ref }}
          CI_SOURCE_BRANCH: ${{ github.head_ref }}
          CI_REPORT_DIR: ./review-reports
        run: |
          chmod +x ./scripts/ci-code-review.sh
          ./scripts/ci-code-review.sh

      - name: Upload Review Report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: review-report-${{ github.run_id }}
          path: review-reports/

      - name: Comment on PR
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const reportPath = `review-reports/review-${process.env.GITHUB_RUN_ID}.json`;
            if (!fs.existsSync(reportPath)) return;
            const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));

            let body = `## Code Review Report\n\n`;
            body += `**Verdict**: ${report.verdict}\n`;
            body += `**Findings**: ${report.summary.total_findings} `;
            body += `(${report.summary.critical} critical, ${report.summary.high} high)\n\n`;

            if (report.findings.length > 0) {
              body += `| Severity | File | Issue |\n|----------|------|-------|\n`;
              for (const f of report.findings.slice(0, 20)) {
                body += `| ${f.severity} | \`${f.file}:${f.line}\` | ${f.title} |\n`;
              }
            }

            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: body
            });
```

---

## Integrazione con GitLab CI

```yaml
# .gitlab-ci.yml (frammento)
agent-code-review:
  stage: review
  image: your-registry/ntm-runner:latest  # immagine con ntm + claude pre-installati
  variables:
    CI_PIPELINE_ID: $CI_PIPELINE_ID
    CI_MERGE_BASE: $CI_MERGE_REQUEST_TARGET_BRANCH_NAME
    CI_SOURCE_BRANCH: $CI_MERGE_REQUEST_SOURCE_BRANCH_NAME
    CI_REPORT_DIR: ./review-reports
  script:
    - chmod +x scripts/ci-code-review.sh
    - ./scripts/ci-code-review.sh
  artifacts:
    paths:
      - review-reports/
    when: always
    expire_in: 30 days
  rules:
    - if: $CI_MERGE_REQUEST_ID
```

---

## Struttura dell'Output JSON

Il report finale che lo script produce ha questo schema:

```json
{
  "success": true,
  "review_passed": false,
  "verdict": "BLOCKED",
  "error": null,
  "pipeline_id": "12345",
  "session": "ci-review-12345",
  "branches": {
    "base": "main",
    "source": "feature/auth-refactor"
  },
  "summary": {
    "total_findings": 7,
    "critical": 1,
    "high": 2,
    "medium": 3,
    "low": 1,
    "consensus_findings": 2
  },
  "agents": [
    { "id": 0, "role": "Logic & Correctness Reviewer", "findings_count": 4 },
    { "id": 1, "role": "Maintainability & Quality Reviewer", "findings_count": 5 }
  ],
  "findings": [
    {
      "severity": "critical",
      "file": "internal/auth/jwt.go",
      "line": 87,
      "category": "security",
      "title": "JWT secret esposto in variabile non protetta",
      "description": "Il secret JWT viene letto da env senza validazione...",
      "suggestion": "Usare una libreria di secrets management...",
      "agents_agreed": true,
      "deduplicated": true
    }
  ],
  "timestamp": "2026-03-26T14:30:00Z"
}
```

Campi chiave per il parsing CI:
- **`review_passed`** (bool) -- unico campo da controllare per gate pass/fail
- **`verdict`** -- `"PASSED"` o `"BLOCKED"`, leggibile da umani nei log
- **`summary.consensus_findings`** -- finding su cui entrambi gli agenti concordano (maggiore confidenza)
- **`findings[].agents_agreed`** -- se `true`, il finding e' stato identificato da entrambi gli agenti indipendentemente

---

## Policy di Blocco

La policy di default nello script e':

| Condizione | Risultato |
|------------|-----------|
| >= 1 finding `critical` | **BLOCKED** (exit 1) |
| > 3 finding `high` | **BLOCKED** (exit 1) |
| Tutto il resto | **PASSED** (exit 0) |

Puoi personalizzarla modificando le soglie nello Step 8 dello script. Per una policy piu' granulare, potresti anche pesare i `consensus_findings` in modo diverso (ad esempio, un `high` confermato da entrambi gli agenti conta come `critical`).

---

## Note Operative

1. **Timeout**: il default e' 300s (5 minuti). Per diff grandi, aumenta `TIMEOUT_SECONDS`. Il `--robot-ack` e' una wait bloccante -- se scade, lo script tenta comunque la raccolta parziale.

2. **Troncamento diff**: diff oltre 2000 righe vengono troncati per evitare overflow del context window degli agenti. Per PR molto grandi, considera di splittare la review per directory o per file.

3. **Costo**: 2 agenti Claude per ogni PR. Per contenere i costi, puoi aggiungere una condizione nel CI che skippa la review per PR con meno di N righe cambiate, o solo per branch protetti.

4. **Profili agente**: lo script usa agenti "vanilla". Per review piu' specifiche, usa `--profiles` nello spawn (es. `--profiles=security-reviewer,performance-reviewer`) se hai definito profili personalizzati in `.ntm/`.

5. **Pipeline ntm come alternativa**: per workflow piu' complessi (es. review + fix automatico + re-review), considera di definire una pipeline YAML ntm in `.ntm/pipelines/review.yaml` e lanciarla con `ntm pipeline run .ntm/pipelines/review.yaml --session $SESSION`. Le pipeline supportano step con dipendenze, resume, e cleanup automatico.
