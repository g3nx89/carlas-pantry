# Recupero di un agente STALLED senza perdere il contesto

Quando il dashboard mostra STALLED, significa che ntm non ha rilevato output dal pane dell'agente per un periodo superiore alla soglia configurata (default: 300 secondi). L'agente potrebbe essersi bloccato per diversi motivi: crash silenzioso, rate limiting, o esaurimento del contesto. Ecco la procedura di diagnosi e recupero, dal meno distruttivo al piu' invasivo.

---

## Passo 1: Diagnosi -- capire PERCHE' e' stallato

Prima di toccare qualsiasi cosa, raccogli informazioni:

```bash
# Controlla l'output recente del pane stallato (es. pane 2)
ntm --robot-tail=SESSIONE --panes=2 --lines=50

# Controlla lo stato di salute complessivo
ntm health SESSIONE

# Controlla l'utilizzo del contesto per tutti gli agenti
ntm --robot-context=SESSIONE

# Cerca errori nell'output dell'agente
ntm grep "Error:\|rate_limit\|context_length_exceeded" SESSIONE -C 3
```

Le tre cause principali e come riconoscerle:

| Causa | Segnale nel tail | Cosa fare |
|-------|-----------------|-----------|
| **Crash silenzioso** | Prompt shell visibile (`>`, `$`), nessun output dell'agente | L'agente e' morto, vai al Passo 2a |
| **Rate limiting** | Messaggi `rate_limit`, `429`, `API Error` | Aspetta qualche minuto, poi vai al Passo 2b |
| **Contesto esaurito** | `context_length_exceeded` o barra contesto rossa (>95%) | Vai al Passo 2c |
| **Stallo logico** | L'agente produce output ma gira in tondo | Vai al Passo 2d |

---

## Passo 2a: Crash silenzioso -- ripristino dolce

L'agente e' caduto ma il pane tmux e' ancora attivo. Puoi rilanciare senza perdere lo stato della sessione.

```bash
# Prima, salva un checkpoint di sicurezza
ntm checkpoint save SESSIONE -m "pre-recovery da stall"

# Interrompi eventuali processi residui nel pane
ntm interrupt SESSIONE

# Rimanda il task all'agente -- ntm inietta il prompt nel pane esistente
ntm send SESSIONE --pane=2 "Continua con il task precedente. Rileggi il contesto e riprendi da dove ti eri fermato."
```

Se l'agente non risponde neanche cosi', il pane potrebbe essere corrotto. In quel caso:

```bash
# Aggiungi un nuovo agente dello stesso tipo per sostituire quello stallato
ntm add SESSIONE --cc=1

# Poi invia il task al nuovo agente, recuperando il contesto dal checkpoint
ntm send SESSIONE --pane=NUOVO_PANE "Ecco il contesto del lavoro in corso: [descrivi il task]. Riprendi da dove l'agente precedente si era fermato."
```

---

## Passo 2b: Rate limiting -- aspetta e riprova

```bash
# Verifica lo stato di rate limiting
ntm health SESSIONE

# Aspetta 2-3 minuti, poi riprova con un prompt leggero
ntm send SESSIONE --pane=2 "Sei ancora attivo? Riprendi il task precedente."
```

Se il rate limiting persiste, riduci il parallelismo:

```bash
# Verifica quanti agenti hai attivi
ntm status SESSIONE

# Considera di ridurre il carico -- non servono tutti gli agenti attivi contemporaneamente
```

---

## Passo 2c: Contesto esaurito -- rotazione manuale

Se la rotazione automatica non si e' attivata (verifica con `ntm --robot-context=SESSIONE`):

```bash
# Controlla se la rotazione automatica e' abilitata
grep "context_rotation" ~/.config/ntm/config.toml

# Se il contesto e' al 95%+, forza la compaction dell'agente
ntm send SESSIONE --pane=2 "/compact"

# Dopo la compaction, manda il recovery prompt per ri-ancorare l'agente
ntm send SESSIONE --pane=2 "Rileggi AGENTS.md e il contesto del progetto. Riprendi il task: [breve descrizione del task]."
```

Se la compaction non basta (contesto ancora al limite):

```bash
# Salva checkpoint PRIMA di qualsiasi azione distruttiva
ntm checkpoint save SESSIONE -m "pre-rotation contesto esaurito"

# La rotazione creera' un nuovo agente con un handoff summary automatico
# Verifica che sia configurata:
grep "summary_max_tokens" ~/.config/ntm/config.toml
# Se il valore e' troppo basso (default 2000), aumentalo temporaneamente per preservare piu' contesto:
# summary_max_tokens = 3000
```

---

## Passo 2d: Stallo logico -- l'agente gira in tondo

L'agente produce output ma non fa progressi reali.

```bash
# Interrompi il loop corrente
ntm interrupt SESSIONE

# Rimanda con istruzioni piu' specifiche per rompere il loop
ntm send SESSIONE --pane=2 "STOP. Non ripetere l'approccio precedente. Riassumi cosa hai provato finora e proponi un approccio alternativo per [task]."
```

---

## Passo 3: Verifica il recupero

Dopo qualsiasi intervento:

```bash
# Controlla che lo stato sia tornato GENERATING o WAITING
ntm activity SESSIONE --watch

# Apri il dashboard per monitoraggio visuale
ntm dashboard SESSIONE

# Verifica che il contesto sia sano
ntm --robot-context=SESSIONE
```

---

## Prevenzione per le prossime sessioni lunghe

```bash
# Salva checkpoint periodici durante sessioni lunghe
ntm checkpoint save SESSIONE -m "checkpoint periodico ore 14"
```

E verifica che `config.toml` abbia queste impostazioni ottimali per sessioni lunghe:

```toml
[context_rotation]
enabled = true
warning_threshold = 0.80
rotate_threshold = 0.95
try_compact_first = true
summary_max_tokens = 3000       # Piu' generoso per preservare contesto

[context_rotation.recovery]
enabled = true
cooldown_seconds = 30
max_recoveries_per_pane = 5
include_bead_context = true

[detection]
stall_threshold_sec = 300       # 5 minuti -- aumenta se i task sono naturalmente lenti
```

Se i tuoi agenti fanno task che richiedono pensiero prolungato (architettura, analisi), considera di alzare `stall_threshold_sec` a 600 (10 minuti) per evitare falsi positivi STALLED.

---

## Riepilogo rapido

```
STALLED sul dashboard
    |
    +---> ntm --robot-tail=SESS --panes=N --lines=50   (guarda l'output)
    |
    +---> ntm health SESS                               (diagnosi stato)
    |
    +---> ntm --robot-context=SESS                      (check contesto)
    |
    +---> ntm checkpoint save SESS -m "pre-recovery"    (SEMPRE prima di agire)
    |
    +---> Causa identificata?
          |
          +-- Crash     --> ntm interrupt + ntm send "continua"
          +-- Rate limit --> aspetta 2-3 min + ntm send "riprendi"
          +-- Contesto  --> ntm send "/compact" + recovery prompt
          +-- Loop      --> ntm interrupt + prompt con approccio alternativo
```
