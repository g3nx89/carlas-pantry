# Recupero di un agente STALLED senza perdere contesto

Lo stato STALLED significa che ntm non ha rilevato output dal pane dell'agente per un periodo prolungato (default: 300 secondi, configurabile in `detection.stall_threshold_sec`). Le cause piu' comuni sono tre: crash silenzioso, context window esaurita, o rate limiting. La procedura cambia in base alla causa, quindi partiamo dalla diagnosi.

---

## Passo 1 -- Diagnosi (non toccare ancora l'agente)

Esegui questi tre comandi in sequenza rapida:

```bash
# 1. Guarda le ultime 50 righe di output del pane stallato
#    (sostituisci SESSION col nome della tua sessione, PANE col numero del pane)
ntm --robot-tail=SESSION --panes=PANE --lines=50

# 2. Controlla lo stato di salute di tutti gli agenti
ntm health SESSION

# 3. Controlla l'uso del context window per ogni agente
ntm --robot-context=SESSION
```

Interpreta i risultati:

| Cosa vedi nel tail | health dice | context dice | Causa probabile |
|--------------------|-------------|--------------|-----------------|
| Errore API / "rate_limit" | RATE_LIMITED | Qualsiasi | **Rate limiting** -- aspetta e riprova |
| Prompt vuoto, nessun errore visibile | UNHEALTHY | < 80% | **Crash silenzioso** -- interrupt + re-prompt |
| "context_length_exceeded" o output troncato | DEGRADED/UNHEALTHY | > 90% | **Context esaurita** -- serve rotazione |
| Output fermo su un ragionamento lungo | HEALTHY/DEGRADED | < 80% | **Falso positivo** -- l'agente sta pensando, alza la soglia |

---

## Passo 2 -- Salva lo stato PRIMA di intervenire

Prima di toccare qualsiasi cosa, fai un checkpoint. Questo cattura lo scrollback di tutti i pane e lo stato corrente della sessione:

```bash
ntm checkpoint save SESSION -m "pre-recovery: agente PANE stallato"
```

Se l'agente ha file lock attivi, verifica che siano ancora validi:

```bash
ntm locks list SESSION --all-agents
```

---

## Passo 3 -- Recupero in base alla causa

### Caso A: Crash silenzioso (causa piu' comune)

L'agente si e' fermato ma il pane e' ancora aperto. Interrupt e re-prompt:

```bash
# Manda Ctrl+C solo all'agente stallato (interrupt agisce su tutti i pane,
# quindi se vuoi essere chirurgico usa tmux direttamente)
ntm interrupt SESSION

# Aspetta 2-3 secondi, poi re-invia il task con contesto
ntm send SESSION --pane=PANE "L'operazione precedente si e' interrotta. Riprendi da dove eri rimasto. Controlla lo stato dei file su cui stavi lavorando e continua."
```

Verifica che l'agente risponda:

```bash
ntm activity SESSION --watch
```

### Caso B: Context window esaurita

Se `ntm --robot-context=SESSION` mostra > 90% per quel pane, la rotazione automatica dovrebbe scattare. Se non e' scattata:

```bash
# Verifica che la rotazione sia abilitata
grep "context_rotation" ~/.config/ntm/config.toml

# Se era disabilitata, abilitala e poi forza la rotazione manuale:
# 1. Salva l'output corrente
ntm copy SESSION --pane=PANE --output /tmp/agent-output-before-rotation.txt

# 2. Interrupt l'agente
ntm interrupt SESSION

# 3. Re-invia con un prompt di handoff che riassume il contesto
ntm send SESSION --pane=PANE "$(cat <<'EOF'
Il tuo context precedente era quasi esaurito. Ecco il riassunto di dove eravamo:
- [inserisci qui il task corrente dall'output salvato]
- [inserisci i file su cui stava lavorando]
- [inserisci le decisioni gia' prese]
Riprendi da questo punto.
EOF
)"
```

Se la rotazione automatica e' configurata correttamente ma non ha funzionato, controlla questi valori in `config.toml`:

```toml
[context_rotation]
enabled = true
warning_threshold = 0.80
rotate_threshold = 0.95
try_compact_first = true
```

### Caso C: Rate limiting

```bash
# Conferma con health
ntm health SESSION
```

Se vedi RATE_LIMITED, le opzioni sono:
1. **Aspetta** -- il rate limit si risolve da solo (tipicamente 1-5 minuti)
2. **Riduci il parallelismo** -- troppi agenti dello stesso tipo saturano la quota API
3. Dopo che il rate limit si risolve, re-invia:

```bash
ntm send SESSION --pane=PANE "Continua con il task precedente."
```

### Caso D: Falso positivo (l'agente sta solo pensando a lungo)

Se l'agente e' in extended thinking mode e la soglia di stallo e' troppo bassa:

```bash
# Aumenta la soglia in config.toml (default 300s, metti 600s per sessioni lunghe)
# [detection]
# stall_threshold_sec = 600
```

Non serve interrupt -- l'agente sta lavorando. Verifica con `ntm watch SESSION` che l'output stia effettivamente progredendo.

---

## Passo 4 -- Verifica post-recupero

Dopo l'intervento, conferma che tutto funziona:

```bash
# Lo stato dovrebbe tornare GENERATING o WAITING (non piu' STALLED)
ntm activity SESSION

# Controlla che non ci siano conflitti sui file
ntm --robot-snapshot --since=1h | jq '.conflicts'

# Se tutto ok, salva un nuovo checkpoint
ntm checkpoint save SESSION -m "post-recovery: agente recuperato"
```

---

## Riferimento rapido -- sequenza copia-incolla

Per il caso piu' comune (crash silenzioso, contesto ancora disponibile):

```bash
ntm --robot-tail=SESSION --panes=PANE --lines=50   # diagnosi
ntm --robot-context=SESSION                          # verifica context
ntm checkpoint save SESSION -m "pre-recovery"        # salva stato
ntm interrupt SESSION                                # stop
ntm send SESSION --pane=PANE "Riprendi il task precedente da dove eri rimasto."
ntm activity SESSION --watch                         # verifica ripresa
```
