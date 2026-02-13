# Proposal: KPI Framework per il Processo di Implementazione

**Plugin:** product-implementation (skill: implement)
**Data:** 2026-02-09
**Versione:** Draft v2
**Stato:** Phase 1 implemented in Stage 6 (Implementation Retrospective). Phase 2/3 remain future work.

---

## Obiettivo

Definire un set di KPI misurabili per monitorare il processo di implementazione orchestrato dalla skill `implement`. Le KPI servono a:

1. **Monitorare il processo** — identificare colli di bottiglia e inefficienze nell'esecuzione
2. **Valutare i miglioramenti** — misurare l'impatto di modifiche alla skill, agli agent, o ai prompt
3. **Valutare la qualità dell'input** — capire se i miglioramenti più efficaci partono dal processo a monte (product-planning)

---

## Rollout a Fasi

Il framework è strutturato in 3 fasi per validare incrementalmente l'utilità delle KPI prima di investire in modifiche ai template.

| Fase | Scope | Prerequisiti | KPI incluse |
|------|-------|-------------|-------------|
| **1 — MVP** | 10 KPI estraibili da YAML strutturato esistente + Report Card + session transcript + narrative retrospective | Nessuna modifica ai template. **Implementato in Stage 6.** | 1.2, 1.3, 3.1, 3.2, 3.3, 5.1, 5.2, 5.3, 5.4, 5.5 |
| **2 — Full** | +10 KPI che richiedono nuovi campi YAML nei summary template | Template changes (vedi sezione dedicata) | +1.1, 2.1–2.5, 3.4, 4.1–4.4 |
| **3 — Aggregazione** | Cross-run analytics, correlazioni, trend | Aggregation tool o index file | Dashboard cross-run |

**Criterio di avanzamento:** Fase 1 → 2 dopo 5 run con dati stabili. Fase 2 → 3 dopo 10+ run con Report Card complete.

---

## Contesto Architetturale

La skill `implement` esegue un workflow a 6 stage sequenziali:

| Stage | Nome | Dati di qualità già prodotti |
|-------|------|------------------------------|
| 1 | Setup & Context Loading | Artifact inventory, domain detection, file gap warnings |
| 2 | Phase-by-Phase Execution | Task completion marks `[X]`, test pass/fail |
| 3 | Completion Validation | Validation report (task %, test %, spec coverage, traceability) |
| 4 | Quality Review | Finding count per severity, reviewer consensus |
| 5 | Feature Documentation | Documentation file list, completeness assessment |
| 6 | Implementation Retrospective | KPI Report Card, transcript analysis, narrative retrospective |

Ogni stage produce un summary file con YAML frontmatter strutturato. Lo state file (`implementation-state.local.md`) traccia le decisioni utente e i contatori di recovery. Questi sono i punti di osservazione naturali per le KPI.

---

## KPI Proposte

### Riepilogo

| ID | Nome | Categoria | Qualità Dati | Fase | Formula |
|----|------|-----------|-------------|------|---------|
| 1.1 | Stage First-Pass Rate | Processo | Richiede parsing | 2 | `stages senza retry / 5` |
| 1.2 | Rework Loop Count | Processo | Strutturato | 1 | `count(user_decisions == "fixed")` |
| 1.3 | Coordinator Stability | Processo | Strutturato | 1 | `coordinator_failures + summaries_reconstructed` |
| 2.1 | Review Finding Density | Output | Richiede YAML | 2 | `{critical: N, high: N, medium: N, low: N}` |
| 2.2 | Reviewer Consensus Rate | Output | Richiede YAML | 2 | `consensus_findings / total_findings` |
| 2.3 | Validation Result | Output | Richiede YAML | 2 | Enum: PASS / PASS WITH NOTES / NEEDS ATTENTION |
| 2.4 | Test Traceability Coverage | Output | Richiede YAML | 2 | `test_ids_implemented / test_ids_total` |
| 2.5 | Spec Coverage | Output | Richiede YAML | 2 | `ac_covered / ac_total` |
| 3.1 | Input Completeness Score | Input | Strutturato | 1 | `artifacts_present / artifacts_total` (da config) |
| 3.2 | Expected File Gap Rate | Input | Strutturato | 1 | `expected_files_missing / expected_files_total` |
| 3.3 | Test Case Availability | Input | Strutturato | 1 | Flag: `flags.test_cases_available` |
| 3.4 | Task Ambiguity Signal | Input | Manuale | 2 | Analisi qualitativa (non automatizzabile) |
| 4.1 | Stage Duration | Risorse | Richiede YAML | 2 | `stage_end - stage_start` (secondi) |
| 4.2 | Lock Conflict Rate | Risorse | Strutturato | 1 | Flag: stale lock overridden |
| 4.3 | Conditional Reviewer Activation | Risorse | Richiede YAML | 2 | `conditional_reviewers_triggered / conditional_reviewers_possible` |
| 4.4 | Context Size Indicator | Risorse | Richiede YAML | 2 | `phases_count * avg_tasks_per_phase` |
| 5.1 | Autonomy Policy Level | Processo | Strutturato | 1 | `autonomy_policy` da Stage 1 summary |
| 5.2 | Auto-Resolution Count | Processo | Strutturato | 1 | `count([AUTO-{policy}])` entries across stage logs |
| 5.3 | Simplification Stats | Output | Strutturato | 1 | `simplification_stats` da Stage 2 summary |
| 5.4 | UAT Results | Output | Strutturato | 1 | `uat_results` da Stage 2 summary |
| 5.5 | Clink Augmentation Bugs | Output | Strutturato | 1 | `augmentation_bugs_found` da Stage 2 summary |

**Legenda Qualità Dati:**
- **Strutturato** — estraibile da campi YAML esistenti senza parsing
- **Richiede YAML** — necessita aggiunta di campi YAML ai summary template (vedi sezione "Template Changes")
- **Richiede parsing** — estraibile da markdown con parsing di testo
- **Manuale** — richiede analisi qualitativa umana

---

### Categoria 1: Efficienza del Processo

Misurano quanto fluido è il passaggio da input a output finito.

#### 1.1 Stage First-Pass Rate (Fase 2)

- **Definizione:** Percentuale di stage che completano senza richiedere intervento utente
- **Formula:** `stages_without_retry / 5`
- **Fonte dati:** Nuovo campo `retry_count` nei summary YAML di ogni stage (vedi Template Changes). Il campo `status` attuale non basta perché il summary viene riscritto dopo un retry, perdendo l'evidenza dell'intervento precedente.
- **Qualità dati:** Richiede YAML
- **Target ideale:** 5/5 (100%)
- **Razionale target:** Ogni intervento utente interrompe il flusso; il target rappresenta un processo completamente autonomo.
- **Segnale:** Se Stage 3 fallisce spesso → problema in Stage 2 (esecuzione). Se Stage 4 fallisce spesso → qualità del codice generato insufficiente.

#### 1.2 Rework Loop Count (Fase 1)

- **Definizione:** Numero di cicli fix-and-retry in Stage 3 (validation), Stage 4 (review), e Stage 5 (documentation)
- **Formula:** `count(user_decisions.* == "fixed")`
  - `validation_outcome == "fixed"` → 1 rework loop in Stage 3
  - `review_outcome == "fixed"` → 1 rework loop in Stage 4
  - `documentation_verification == "fixed"` → 1 rework loop in Stage 5
- **Fonte dati:** `user_decisions.validation_outcome`, `user_decisions.review_outcome`, e `user_decisions.documentation_verification` nello state file
- **Qualità dati:** Strutturato
- **Target ideale:** 0
- **Razionale target:** Rework indica che la prima esecuzione non ha soddisfatto i criteri. Zero rework significa che l'agent ha prodotto output corretto al primo tentativo.
- **Limitazione:** Lo state file traccia solo la decisione finale. Se l'utente fa fix → re-valida → fix di nuovo → accetta, viene registrato solo l'ultimo outcome. Per contare cicli multipli, serve il campo `retry_count` aggiunto in Fase 2.
- **Segnale:** Rework in Stage 3 → task ambigue o AC poco chiari. Rework in Stage 4 → developer agent non segue convenzioni o produce bug.

#### 1.3 Coordinator Stability (Fase 1)

- **Definizione:** Numero di crash del coordinator e summary ricostruiti via crash recovery
- **Formula:** `orchestrator.coordinator_failures + orchestrator.summaries_reconstructed`
- **Fonte dati:** `orchestrator.coordinator_failures` e `orchestrator.summaries_reconstructed` nello state file
- **Qualità dati:** Strutturato
- **Target ideale:** 0
- **Razionale target:** Ogni crash è un fallimento infrastrutturale che aggiunge latenza e rischio di perdita dati.
- **Segnale:** Valori > 0 indicano problemi infrastrutturali (context overflow, timeout, prompt troppo lunghi) piuttosto che problemi di qualità del codice.

---

### Categoria 2: Qualità dell'Output

Misurano la bontà del codice e della documentazione prodotti.

#### 2.1 Review Finding Density (Fase 2)

- **Definizione:** Conteggio dei finding per severità rilevati in Stage 4
- **Formula:** `{critical: N, high: N, medium: N, low: N, total: sum}`
- **Fonte dati:** Nuovo campo `finding_counts` nel summary Stage 4 YAML (vedi Template Changes). Attualmente i conteggi sono nel corpo markdown del report consolidato e richiederebbero parsing di heading come "### Critical (3)".
- **Qualità dati:** Richiede YAML
- **Target ideale:** 0 Critical, 0 High. Medium e Low accettabili in quantità limitata.
- **Razionale target:** Critical/High sono definiti nel config come "breaks functionality" e "likely to cause bugs" — non accettabili in codice da rilasciare.
- **Segnale:**
  - Molti finding su "correctness" (Reviewer 2) → developer agent manca di contesto o non rispetta TDD
  - Molti finding su "conventions" (Reviewer 3) → contesto di progetto (CLAUDE.md, constitution.md) non applicato
  - Molti finding su "simplicity" (Reviewer 1) → agent tende a over-engineering

#### 2.2 Reviewer Consensus Rate (Fase 2)

- **Definizione:** Percentuale di finding segnalati indipendentemente da 2+ reviewer
- **Formula:** `consensus_findings / total_findings`
- **Fonte dati:** Nuovo campo `consensus_findings` nel summary Stage 4 YAML (vedi Template Changes). Il dato è attualmente ricavabile dal report consolidato (annotazioni "Reviewers: 1, 2" per finding) ma richiede parsing.
- **Qualità dati:** Richiede YAML
- **Target ideale:** N/A (metrica diagnostica)
- **Segnale:** Alta consensus indica problemi evidenti che il developer agent avrebbe dovuto intercettare. Suggerisce che il self-critique loop è insufficiente.

#### 2.3 Validation Result (Fase 2)

- **Definizione:** Risultato della validazione Stage 3
- **Formula:** Enum: `PASS` | `PASS WITH NOTES` | `NEEDS ATTENTION`
- **Fonte dati:** Nuovo campo `validation_recommendation` nel summary Stage 3 YAML (vedi Template Changes). Nota: è distinto da `user_decisions.validation_outcome` nello state file che usa valori diversi (`passed|fixed|proceed_anyway|stopped`).
- **Qualità dati:** Richiede YAML
- **Target ideale:** PASS costante
- **Razionale target:** PASS indica che l'implementazione soddisfa tutti i criteri senza riserve.
- **Segnale:** NEEDS ATTENTION frequente → problemi sistematici in Stage 2 (agent prompt, task parsing, TDD enforcement).

#### 2.4 Test Traceability Coverage (Fase 2)

- **Definizione:** Percentuale di test ID nei task che hanno corrispondenza con test implementati
- **Formula:** `traceability.test_ids_implemented / traceability.test_ids_total`
- **Fonte dati:** Nuovo campo `traceability` nel summary Stage 3 YAML (vedi Template Changes). Disponibile solo quando `test_cases_available: true`.
- **Qualità dati:** Richiede YAML
- **Target ideale:** 100%
- **Razionale target:** Ogni test ID pianificato deve avere un test implementato; gap indicano lavoro incompleto.
- **Segnale:** Gap indicano che il developer ha implementato senza seguire i test case pre-generati, o che i test case del planning non mappano ai file di test.

#### 2.5 Spec Coverage (Fase 2)

- **Definizione:** Percentuale di acceptance criteria dalla spec coperti dall'implementazione
- **Formula:** `spec_coverage.ac_covered / spec_coverage.ac_total`
- **Fonte dati:** Nuovo campo `spec_coverage` nel summary Stage 3 YAML (vedi Template Changes).
- **Qualità dati:** Richiede YAML
- **Target ideale:** 100%
- **Razionale target:** Ogni AC è un requisito contrattuale; coverage < 100% significa feature incompleta.
- **Segnale:** Coverage < 100% ricorrente → AC poco chiari nella spec (problema di input) o parsing dei task inadeguato (problema di processo).

---

### Categoria 3: Qualità dell'Input

Misurano la bontà degli artifact prodotti da product-planning.

#### 3.1 Input Completeness Score (Fase 1)

- **Definizione:** Numero di artifact presenti su totale possibile
- **Formula:** `artifacts_present / artifacts_total * 100`
- **Conteggio artifact (derivato da config):**
  - `artifacts_total` = 2 (required: tasks.md, plan.md) + `len(handoff.expected_files)` + conteggio optional (spec.md, contract.md, data-model.md, research.md, test-cases/, task-test-traceability.md)
  - Il conteggio è dinamico: se la config aggiunge un expected file, il denominatore cresce automaticamente
  - `test-cases/` conta come 1 artifact indipendentemente dal numero di subdirectory presenti
  - Attualmente: `artifacts_total = 2 + 2 + 6 = 10`
- **Fonte dati:** Tabella "Planning Artifacts Summary" nel summary Stage 1
- **Qualità dati:** Strutturato
- **Target ideale:**
  - ≥70% (≥7/10) per feature complesse (>15 task, architettura multi-componente)
  - ≥40% (≥4/10) per feature semplici (<10 task, singolo modulo)
- **Razionale target:** Le soglie sono iniziali e vanno calibrate con i dati delle prime 10 run. Il 70% per feature complesse deriva dall'osservazione che design.md + test-plan.md + almeno 3 optional forniscono contesto sufficiente per evitare che il developer agent prenda decisioni architetturali autonome. Il 40% per feature semplici corrisponde ai 2 required + 2 expected: il minimo per un'esecuzione senza warning.
- **Segnale:** Score basso correlato a più finding in Stage 4 indica che il planning incompleto genera costi in implementazione.

**Breakdown degli artifact:**

| Tier | File | Fonte config | Impatto atteso se mancante |
|------|------|-------------|---------------------------|
| Required | `tasks.md` | Implicito (halt) | Halt: impossibile procedere |
| Required | `plan.md` | Implicito (halt) | Halt: impossibile procedere |
| Expected | `design.md` | `handoff.expected_files[0]` | Developer decide architettura da solo → più finding su conventions |
| Expected | `test-plan.md` | `handoff.expected_files[1]` | TDD senza strategia V-Model → test potenzialmente incompleti |
| Optional | `spec.md` | — | Nessun AC di riferimento per validazione Stage 3 |
| Optional | `contract.md` | — | API non vincolate → possibile drift dall'interfaccia attesa |
| Optional | `data-model.md` | — | Entity model inventato dall'agent → possibile disallineamento |
| Optional | `research.md` | — | Decisioni tecniche senza contesto → scelte subottimali |
| Optional | `test-cases/` | `handoff.test_cases` | Nessun test pre-generato → developer deve inventare test da zero |
| Optional | `task-test-traceability.md` | — | Nessuna mappa task → test → impossibile verificare traceability |

#### 3.2 Expected File Gap Rate (Fase 1)

- **Definizione:** Percentuale di file "expected" mancanti per singola run
- **Formula:** `expected_files_missing / len(handoff.expected_files) * 100`
  - Se design.md manca e test-plan.md è presente: `1/2 * 100 = 50%`
  - Se entrambi presenti: `0%`
  - Per analisi cross-run: `media(expected_file_gap_rate per run)`
- **Fonte dati:** Warning log nel summary Stage 1
- **Qualità dati:** Strutturato
- **Target ideale:** 0% (tutti gli expected presenti)
- **Razionale target:** I file expected sono classificati così perché la loro assenza degrada sensibilmente la qualità dell'output. Zero gap è il requisito minimo per un'esecuzione a contesto completo.
- **Segnale:** Se test-plan.md manca nel >50% delle run, considerare di renderlo output obbligatorio nel workflow di product-planning.

#### 3.3 Test Case Availability (Fase 1)

- **Definizione:** Flag binario: test-cases/ directory presente e popolata?
- **Formula:** `flags.test_cases_available` (boolean)
- **Fonte dati:** `flags.test_cases_available` nel summary Stage 1
- **Qualità dati:** Strutturato
- **Target ideale:** `true` per feature con >10 task
- **Razionale target:** Feature con >10 task hanno complessità sufficiente da richiedere test case strutturati; sotto questa soglia il developer agent può ragionevolmente derivare test dalla spec.
- **Segnale:** La correlazione tra `test_cases_available: false` e alto Review Finding Density fornirebbe evidenza per rendere i test case un output obbligatorio del planning.

#### 3.4 Task Ambiguity Signal — Proxy (Fase 2, Manuale)

- **Definizione:** Proxy indiretto per l'ambiguità dei task: frequenza di fix in Stage 3 riconducibili a task mal definite (vs bug nel codice)
- **Formula:** Analisi qualitativa del validation report — non automatizzabile
- **Fonte dati:** Corpo markdown del validation report Stage 3 + `user_decisions.validation_outcome`
- **Qualità dati:** Manuale
- **Target ideale:** Da stabilire dopo analisi delle prime 5-10 run
- **Nota:** Questa è l'unica KPI che richiede valutazione umana. Va trattata come metrica di retrospettiva, non come dato della Report Card automatica. Considerare la rimozione se non produce insight nelle prime 10 run.
- **Segnale:** Se i fix in Stage 3 sono prevalentemente su "task non completata perché ambigua" piuttosto che su "bug nel codice", il miglioramento va fatto sulla granularità e chiarezza dei task in product-planning.

---

### Categoria 4: Efficienza delle Risorse

Misurano il costo e l'utilizzo delle risorse del processo.

#### 4.1 Stage Duration (Fase 2)

- **Definizione:** Tempo di esecuzione per stage (in secondi)
- **Formula:** `stage_end_timestamp - stage_start_timestamp`
- **Fonte dati:** Nuovo campo `duration_seconds` nel summary YAML di ogni stage (vedi Template Changes). Derivato dai timestamp nello Stage Log.
- **Qualità dati:** Richiede YAML
- **Target ideale:** N/A (metrica diagnostica per trend analysis)
- **Razionale:** Permette di validare l'assunzione "5-15s latency per coordinator dispatch" documentata in SKILL.md e di identificare stage che crescono in durata con la complessità.
- **Segnale:** Stage 2 con durata crescente al crescere delle fasi/task → possibile context overflow nei developer agent.

#### 4.2 Lock Conflict Rate (Fase 1)

- **Definizione:** Flag binario: un lock stale è stato sovrascritto all'avvio?
- **Formula:** `stale_lock_overridden` (boolean)
- **Fonte dati:** Stage Log di Stage 1 (warning "overriding stale lock")
- **Qualità dati:** Strutturato (derivabile dal log esistente)
- **Target ideale:** `false`
- **Razionale target:** Lock stale indica una sessione precedente che è crashata senza rilasciare il lock — un problema infrastrutturale.
- **Segnale:** Lock conflict frequente → sessioni che crashano prima di Stage 5 (che rilascia il lock). Investigare le cause di crash.

#### 4.3 Conditional Reviewer Activation Rate (Fase 2)

- **Definizione:** Quanti reviewer condizionali vengono attivati rispetto al massimo possibile
- **Formula:** `conditional_reviewers_triggered / max_conditional_reviewers` (da config, attualmente 2)
- **Fonte dati:** Nuovo campo `conditional_reviewers_triggered` nel summary Stage 4 YAML (vedi Template Changes)
- **Qualità dati:** Richiede YAML
- **Target ideale:** N/A (metrica diagnostica)
- **Segnale:** Validazione che la configurazione `conditional_review` nel config sia efficace. Se l'attivazione è sempre 0 nonostante detected_domains rilevanti, la config dei domini potrebbe essere troppo restrittiva.

#### 4.4 Context Size Indicator (Fase 2)

- **Definizione:** Proxy della complessità del contesto che il developer agent deve gestire
- **Formula:** `phases_count * avg_tasks_per_phase`
- **Fonte dati:** Derivabile dal summary Stage 1 (phase count e task count già tracciati)
- **Qualità dati:** Richiede YAML (serve strutturare i conteggi)
- **Target ideale:** N/A (metrica diagnostica)
- **Segnale:** Valori alti correlati a più crash (KPI 1.3) o più finding (KPI 2.1) indicano che il sistema scala male con la complessità. Può guidare decisioni su phase splitting o context windowing.

---

## Correlazioni Chiave da Monitorare (Fase 3)

Le KPI singole hanno valore limitato. Il vero insight viene dalle correlazioni:

### Correlazione 1: Input Completeness ↔ Review Finding Density

**Ipotesi:** Feature con più artifact completi producono meno finding in Stage 4.

**KPI coinvolte:** 3.1 (Input Completeness Score) vs 2.1 (Review Finding Density — total)

**Come validare:** Dopo 10+ run, scatter plot di Input Completeness Score (asse X) vs Total Findings (asse Y). Se la correlazione è negativa, investire nel planning produce ROI misurabile.

### Correlazione 2: Expected File Gap ↔ Rework Loops

**Ipotesi:** L'assenza di design.md o test-plan.md causa più rework in Stage 3.

**KPI coinvolte:** 3.2 (Expected File Gap Rate) vs 1.2 (Rework Loop Count)

**Come validare:** Confrontare il rework rate medio delle run con `expected_file_gap = 0%` vs `expected_file_gap > 0%`.

### Correlazione 3: Test Case Availability ↔ Spec Coverage

**Ipotesi:** La disponibilità di test case pre-generati migliora la copertura degli AC.

**KPI coinvolte:** 3.3 (Test Case Availability) vs 2.5 (Spec Coverage)

**Come validare:** Confrontare Spec Coverage medio tra run con `test_cases_available: true` vs `false`.

### Correlazione 4: Context Size ↔ Coordinator Stability

**Ipotesi:** Feature con molte fasi/task causano più crash del coordinator (context overflow).

**KPI coinvolte:** 4.4 (Context Size Indicator) vs 1.3 (Coordinator Stability)

**Come validare:** Scatter plot di Context Size Indicator (asse X) vs coordinator_failures + summaries_reconstructed (asse Y). Correlazione positiva indicherebbe la necessità di phase splitting o context windowing per feature complesse.

---

## Required Template Changes (Prerequisito per Fase 2)

Prima di implementare le KPI di Fase 2, i seguenti campi YAML devono essere aggiunti ai summary template.

### Stage 3 Summary — Nuovi campi YAML

```yaml
# Aggiungere al frontmatter di stage-3-summary.md
validation_recommendation: "PASS"  # PASS | PASS WITH NOTES | NEEDS ATTENTION
retry_count: 0                     # Incrementato ad ogni ciclo fix-and-retry
duration_seconds: 0                # stage_end - stage_start
spec_coverage:
  ac_total: 0
  ac_covered: 0
traceability:                      # Presente solo se test_cases_available: true
  test_ids_total: 0
  test_ids_implemented: 0
  test_ids_gap: 0
```

### Stage 4 Summary — Nuovi campi YAML

```yaml
# Aggiungere al frontmatter di stage-4-summary.md
retry_count: 0                     # Incrementato ad ogni ciclo fix-and-retry
duration_seconds: 0                # stage_end - stage_start
finding_counts:
  critical: 0
  high: 0
  medium: 0
  low: 0
  total: 0
consensus_findings: 0              # Finding segnalati da 2+ reviewer
conditional_reviewers_triggered: 0  # Reviewer condizionali attivati (su max da config)
```

### Stage 1, 2, 5 Summary — Nuovi campi YAML

```yaml
# Aggiungere al frontmatter di tutti i summary
duration_seconds: 0                # stage_end - stage_start

# Solo Stage 1 — aggiungere ai flags:
flags:
  stale_lock_overridden: false     # true se un lock stale è stato sovrascritto
  phases_count: 0                  # Numero di fasi nel tasks.md
  tasks_count: 0                   # Numero totale di task
```

### Impatto sulle reference file

Le istruzioni per popolare questi campi devono essere aggiunte alle reference file corrispondenti:

| Reference file | Campi da popolare |
|---------------|-------------------|
| `stage-1-setup.md` | `duration_seconds`, `stale_lock_overridden`, `phases_count`, `tasks_count` |
| `stage-2-execution.md` | `duration_seconds` |
| `stage-3-validation.md` | `validation_recommendation`, `retry_count`, `duration_seconds`, `spec_coverage`, `traceability` |
| `stage-4-quality-review.md` | `retry_count`, `duration_seconds`, `finding_counts`, `consensus_findings`, `conditional_reviewers_triggered` |
| `stage-5-documentation.md` | `duration_seconds` |

---

## Implementazione: Report Card Automatica

Per rendere le KPI azionabili, si propone di generare automaticamente una **Implementation Report Card** alla fine di ogni run (post Stage 5).

### Formato proposto

```yaml
---
version: 1                              # Schema versioning per compatibilità
feature: "{FEATURE_NAME}"
timestamp: "{ISO_8601}"

input_quality:
  completeness_score: 0                  # artifacts_present / artifacts_total * 100
  artifacts_total: 10                    # Derivato da config (2 required + expected + optional)
  artifacts_present: 0
  required_present: []                   # ["tasks.md", "plan.md"]
  expected_missing: []                   # Subset di handoff.expected_files
  optional_present: []
  optional_missing: []
  expected_file_gap_rate: 0              # expected_missing / expected_total * 100
  test_cases_available: false
  detected_domains: []

process_efficiency:
  stages_first_pass: 0                   # Stages senza retry (Fase 2; null in Fase 1)
  rework_loop_count: 0                   # count(user_decisions == "fixed")
  rework_stages: []                      # [3, 4] se validation e review hanno avuto fix
  user_decisions:
    validation_outcome: null             # "passed" | "fixed" | "proceed_anyway" | "stopped"
    review_outcome: null                 # "fixed" | "deferred" | "accepted"
    documentation_verification: null     # "fixed" | "accepted_incomplete"
    documentation_outcome: null          # "completed"
  coordinator_failures: 0
  summaries_reconstructed: 0
  stale_lock_overridden: false

output_quality:
  tasks_completed: "{completed}/{total}"
  validation_result: null                # "PASS" | "PASS WITH NOTES" | "NEEDS ATTENTION" (Fase 2)
  review_findings: null                  # Fase 2: {critical: N, high: N, medium: N, low: N, total: N}
  reviewer_consensus_findings: null      # Fase 2
  test_traceability: null                # Fase 2: {total: N, implemented: N, gaps: N} | "N/A"
  spec_coverage: null                    # Fase 2: {total: N, covered: N}

resource_efficiency:
  stage_durations: null                  # Fase 2: {1: N, 2: N, 3: N, 4: N, 5: N} (secondi)
  context_size_indicator: null           # Fase 2: phases * avg_tasks_per_phase
  conditional_reviewers_triggered: null  # Fase 2
---

## Report Card Notes

- Campi con valore `null` non sono ancora raccolti (abilitati in Fase 2)
- Questo report è generato automaticamente al termine di Stage 5
```

### Dove salvare

`{FEATURE_DIR}/.implementation-report-card.local.md` accanto allo state file e ai summary. Il suffisso `.local.md` indica che è un artifact di analisi locale escluso dall'auto-commit.

### Come generare

**Fase 1:** Il coordinator Stage 5 compila la report card come ultimo step, leggendo:
- State file (per user_decisions, coordinator_failures, summaries_reconstructed)
- Summary Stage 1 (per artifact inventory, test_cases_available, detected_domains)
- I campi di Fase 2 restano `null`

**Fase 2:** Il coordinator Stage 5 legge anche i summary Stage 3 e 4 per popolare i campi strutturati aggiunti con i Template Changes.

**Nota:** La Report Card è stata promossa a Stage 6 dedicato (Implementation Retrospective) per separazione di responsabilità. Il coordinator Stage 6 compila la Report Card, estrae dati dalla session transcript, e dispatch il tech-writer per la composizione del retrospective narrativo.

---

## Cross-Run Aggregation (Fase 3)

### Problema

Ogni run produce una Report Card isolata in `{FEATURE_DIR}/.implementation-report-card.md`. Per validare le correlazioni e tracciare trend servono dati aggregati cross-run.

### Soluzione proposta

**Opzione A — Index file (consigliata per MVP):**

Mantenere un file `.kpi-index.md` nella root del progetto (o in una directory dedicata) che registra ogni run completata:

```yaml
# .kpi-index.md
runs:
  - feature: "001-user-auth"
    timestamp: "2026-02-07T14:30:00Z"
    report_card: "specs/001-user-auth/.implementation-report-card.md"
    completeness_score: 70
    rework_count: 1
    coordinator_failures: 0
    # ... subset dei KPI chiave per query rapide
  - feature: "002-notifications"
    timestamp: "2026-02-10T09:15:00Z"
    report_card: "specs/002-notifications/.implementation-report-card.md"
    completeness_score: 40
    rework_count: 0
    coordinator_failures: 0
```

**Opzione B — Aggregation command:**

Creare una skill `/kpi-dashboard` che:
1. Trova tutte le `.implementation-report-card.md` nel progetto
2. Estrae i KPI strutturati
3. Genera tabella comparativa + trend + correlazioni
4. Output come markdown report

L'opzione B è più potente ma richiede una skill dedicata. L'opzione A è sufficiente per le prime 10-20 run.

---

## Prossimi Passi

### Fase 1 (MVP) — IMPLEMENTED

Phase 1 is implemented as Stage 6 (Implementation Retrospective) with:
- 10 KPIs (original 5 + 5 new from autonomy policy, code simplification, UAT, and clink features)
- Session transcript analysis (streaming extraction of tool usage, errors, timing from JSONL)
- Narrative retrospective document composed by tech-writer agent
- Machine-readable KPI Report Card (`.implementation-report-card.local.md`)

**Remaining validation steps:**
1. Eseguire 5 run della skill implement raccogliendo le Report Card
2. Verificare che i dati siano stabili e coerenti
3. Valutare se le 10 KPI producono insight utili (criterio: almeno 1 KPI porta a un'azione di miglioramento)

### Fase 2 (Full)

5. Implementare i Template Changes (nuovi campi YAML nei summary)
6. Aggiornare le reference file per popolare i nuovi campi
7. Aggiornare le istruzioni del coordinator Stage 5 per leggere i nuovi campi
8. Eseguire 5+ run con il framework completo
9. Verificare le 16 KPI e rimuovere quelle che non producono insight

### Fase 3 (Aggregazione)

10. Implementare l'index file o l'aggregation command
11. Raccogliere 10+ run con Report Card complete
12. Validare le 4 correlazioni chiave
13. Calibrare i target delle KPI sulla base dei dati reali
14. Documentare le azioni di miglioramento derivate dalle KPI e il loro impatto misurato
