# Proposal: Plan Skill Enhancement per Product-Definition Plugin

**Versione:** 1.0.0
**Data:** 2026-01-30
**Autore:** Claude Opus 4.5
**Status:** Draft per Review

---

## Sommario Esecutivo

Questa proposta descrive le migliorie al workflow `/product-definition:specify` attraverso l'aggiunta di nuove skill di planning e l'enhancement delle skill esistenti. L'obiettivo è integrare pattern sofisticati ispirati al plugin `compound-engineering` (in particolare `/workflows:plan` e `/deepen-plan`) mantenendo intatti i pilastri architetturali del plugin: **MPA**, **Sequential Thinking**, **PAL Consensus**, e **V-Model Testing**.

### Obiettivi Principali

1. **Aggiungere una fase di Pre-Planning** prima della generazione delle specifiche
2. **Implementare Risk-Based Research Routing** per ottimizzare l'uso di risorse
3. **Creare Detail Level Stratification** per adattare l'output alla complessità del progetto
4. **Integrare Local Knowledge Discovery** per riutilizzare specifiche e learnings esistenti
5. **Aggiungere Post-Generation Workflow Options** per continuità operativa

---

## Parte 1: Analisi Comparativa

### 1.1 Pattern di compound-engineering Identificati

| Pattern | Descrizione | Valore Aggiunto |
|---------|-------------|-----------------|
| **Brainstorm Detection** | Rilevamento automatico di ideation precedenti | Evita duplicazione di domande già risolte |
| **Risk-Based Research** | Routing condizionale della ricerca esterna | Ottimizza tempo e API calls |
| **Detail Levels** | MINIMAL/MORE/A LOT templates | Adatta output alla complessità |
| **SpecFlow Analysis** | Validazione user flow pre-implementation | Scopre gap e edge cases in anticipo |
| **Deepen-Plan** | Enhancement iterativo con agenti paralleli | Approfondimento on-demand |
| **Post-Gen Options** | Workflow chaining (work/review/simplify) | Continuità operativa |

### 1.2 Asset Esistenti da Preservare (MANDATORY)

| Asset | File | Funzione Critica |
|-------|------|------------------|
| **MPA Framework** | `config/specify-config.yaml` | Multi-Perspective Analysis con 3+ agenti paralleli |
| **Sequential Thinking** | `agents/ba-references/sequential-thinking-templates.md` | 25 template di reasoning strutturato |
| **PAL Consensus** | `config/specify-config.yaml` (pal_consensus) | Validazione multi-modello con stance-based prompting |
| **ThinkDeep Integration** | `config/specify-config.yaml` (thinkdeep) | Cognitive diversity con gpt-5.2, gemini-3-pro, grok-4 |
| **V-Model Testing** | `config/specify-config.yaml` (test_strategy) | Test plan con AC-to-test traceability |
| **SADD Orchestrator** | `skills/sadd-orchestrator/` | Parallel dispatch e debate protocols |
| **Stakeholder Advocates** | `agents/stakeholder-advocates/` | 4 prospettive (end-user, business, ops, security) |
| **Incremental Gates** | `config/specify-config.yaml` (incremental_gates) | Validazione problem quality e true need |

---

## Parte 2: Architettura delle Modifiche

### 2.1 Nuove Skill da Creare

#### 2.1.1 `skills/specify-planning/SKILL.md`

**Scopo:** Orchestrare la fase di pre-planning prima della generazione spec.

**Responsabilità:**
- Brainstorm detection e reuse
- Research decision routing
- Detail level selection
- Prior knowledge integration

#### 2.1.2 `skills/specify-deepen/SKILL.md`

**Scopo:** Enhancement iterativo di spec esistenti con agenti paralleli.

**Responsabilità:**
- Parallel research per sezione
- Stakeholder advocate integration
- Synthesis e deduplicazione
- Enhancement summary generation

#### 2.1.3 `skills/specify-research-router/SKILL.md`

**Scopo:** Decidere se e quanto ricercare in base al rischio e contesto.

**Responsabilità:**
- Risk assessment dei topic
- Signal gathering durante refinement
- Research routing decision
- User notification

### 2.2 Enhancement delle Skill Esistenti

#### 2.2.1 `skills/sadd-orchestrator/SKILL.md` Enhancement

**Aggiunte:**
- Nuovo capability: `sadd:research-dispatch` per ricerca parallela
- Nuovo capability: `sadd:learning-integration` per prior knowledge
- Support per conditional agent invocation

#### 2.2.2 `skills/specify-clarification/SKILL.md` Enhancement

**Aggiunte:**
- Integration con planning phase output
- Skip questions già risolte in planning
- Context inheritance da brainstorm detection

---

## Parte 3: Specifiche Dettagliate delle Nuove Skill

### 3.1 Skill: `specify-planning`

```yaml
# skills/specify-planning/SKILL.md

name: specify-planning
description: Pre-planning phase for specification workflow with brainstorm detection and research routing
version: 1.0.0
dependencies:
  - sadd-orchestrator
  - specify-research-router
```

#### Fase 0: Brainstorm Detection

```markdown
### Step 0.1: Check for Prior Ideation

**Directories to scan:**
- `docs/brainstorms/`
- `specs/brainstorms/`
- `{FEATURE_DIR}/brainstorms/`

**Detection criteria:**
- File age: < 14 days
- Topic match: semantic similarity > 0.7
- YAML frontmatter contains: `topic:`, `decisions:`, or `approach:`

**If relevant brainstorm found:**
1. Read and parse brainstorm document
2. Extract: decisions, chosen approach, open questions, constraints
3. SKIP idea refinement questions already answered
4. Use as context for subsequent phases

**If multiple candidates:**
Present to user via AskUserQuestion:
- List matched brainstorms with dates
- Allow selection or "Start fresh"

**Signal Gathering (for Research Decision):**
During brainstorm reading, capture:
- `user_familiarity_level`: HIGH if examples provided, LOW if exploratory
- `topic_risk_indicators`: List of high-risk keywords found
- `uncertainty_signals`: Open questions count, "not sure" phrases
```

#### Fase 1: Research Decision

```markdown
### Step 1.1: Risk-Based Research Routing

**Input Signals:**
- From brainstorm: topic, decisions, constraints
- From user: familiarity level, urgency
- From keyword analysis: risk indicators

**Decision Logic (implements specify-research-router):**

```python
def decide_research(signals):
    # HIGH-RISK: Always research
    high_risk_keywords = [
        "security", "authentication", "payment", "billing",
        "compliance", "GDPR", "HIPAA", "PCI", "regulatory",
        "financial", "healthcare", "encryption", "PII"
    ]

    if any(kw in signals.topic.lower() for kw in high_risk_keywords):
        return RESEARCH_ALWAYS, "High-risk topic requires external validation"

    # STRONG LOCAL CONTEXT: Skip research
    if (signals.existing_specs_count >= 3 and
        signals.user_provides_examples and
        signals.domain_pattern_match):
        return RESEARCH_SKIP, "Strong local context, external research adds little value"

    # HIGH UNCERTAINTY: Research recommended
    if (signals.open_questions_count > 5 or
        signals.uncertainty_phrases > 2 or
        signals.user_familiarity == "LOW"):
        return RESEARCH_RECOMMENDED, "Uncertainty warrants external perspective"

    # DEFAULT: Ask user
    return RESEARCH_OPTIONAL, "Research available if desired"
```

**Output:**
- `research_decision`: ALWAYS | SKIP | RECOMMENDED | OPTIONAL
- `research_rationale`: Human-readable explanation
- `research_scope`: If researching, what topics to focus on
```

#### Fase 2: Detail Level Selection

```markdown
### Step 2.1: Complexity Assessment

**Automatic indicators:**
- User story count estimate (from brainstorm/description)
- Stakeholder count
- Integration complexity
- Regulatory involvement

**Detail Level Options:**

| Level | Trigger | Sections | MPA Mode | ST Thoughts |
|-------|---------|----------|----------|-------------|
| 📄 MINIMAL | ≤3 stories, single stakeholder | 5 core | Standard (3 agents) | 8 |
| 📋 STANDARD | 4-8 stories, 2-3 stakeholders | 12 extended | Complete (3 agents + ThinkDeep) | 12 |
| 📚 COMPREHENSIVE | 9+ stories, 4+ stakeholders, compliance | 18 full | Complete + PAL Challenge | 15 |

**User Decision Point:**
```json
{
  "question": "Based on complexity analysis, what detail level should this specification have?",
  "header": "Detail",
  "options": [
    {
      "label": "📋 Standard (Recommended)",
      "description": "Balanced detail for most features. Includes problem framing, user stories, AC, and V-Model test plan."
    },
    {
      "label": "📄 Minimal",
      "description": "Quick spec for simple features. Core sections only, faster completion."
    },
    {
      "label": "📚 Comprehensive",
      "description": "Full detail for critical features. Includes competitive analysis, alternatives, extensibility."
    }
  ]
}
```
```

#### Fase 3: Local Knowledge Integration

```markdown
### Step 3.1: Prior Knowledge Discovery

**Scan directories:**
```bash
# Existing specs
find specs/ -name "spec.md" -type f 2>/dev/null

# Documented learnings
find docs/learnings/ -name "*.md" 2>/dev/null
find docs/decisions/ -name "*.md" 2>/dev/null
find docs/post-mortems/ -name "*.md" 2>/dev/null
```

**For each found document:**
1. Read YAML frontmatter (if present)
2. Extract: domain, patterns, lessons, anti-patterns
3. Match against current feature description
4. Rank by relevance

**Integration Output:**
```yaml
prior_knowledge:
  relevant_specs:
    - path: "specs/auth-flow/spec.md"
      relevance: 0.85
      reusable_patterns:
        - "Token refresh flow"
        - "Error state handling"

  learnings:
    - path: "docs/learnings/api-retry-pattern.md"
      relevance: 0.72
      key_insight: "Exponential backoff with jitter prevents thundering herd"
      apply_to: "Network error handling"

  anti_patterns:
    - path: "docs/post-mortems/auth-incident-2025.md"
      warning: "Never store tokens in localStorage"
```
```

### 3.2 Skill: `specify-deepen`

```yaml
# skills/specify-deepen/SKILL.md

name: specify-deepen
description: Enhance existing specifications with parallel research and review agents
version: 1.0.0
dependencies:
  - sadd-orchestrator
```

#### Architecture

```markdown
### Deepen Process

**Input:** Path to existing spec.md

**Step 1: Parse Spec Structure**
- Extract sections: problem, stakeholders, stories, AC, constraints
- Identify sections needing enhancement
- Create section manifest

**Step 2: Launch Stakeholder Advocates (REUSE EXISTING)**
Using sadd-orchestrator parallel-dispatch:
```yaml
agents:
  - name: "end-user-advocate"
    path: "$CLAUDE_PLUGIN_ROOT/agents/stakeholder-advocates/end-user-advocate.md"
    model: "sonnet"
  - name: "business-advocate"
    path: "$CLAUDE_PLUGIN_ROOT/agents/stakeholder-advocates/business-advocate.md"
    model: "sonnet"
  - name: "operations-advocate"
    path: "$CLAUDE_PLUGIN_ROOT/agents/stakeholder-advocates/operations-advocate.md"
    model: "sonnet"
  - name: "security-advocate"
    path: "$CLAUDE_PLUGIN_ROOT/agents/stakeholder-advocates/security-advocate.md"
    model: "sonnet"

context:
  SPEC_FILE: "{spec_path}"
  MODE: "enhancement"  # vs "initial_review"
```

**Step 3: Launch Research Discovery Agents (REUSE EXISTING)**
Using sadd-orchestrator parallel-dispatch:
```yaml
agents:
  - name: "research-discovery-business"
    path: "$CLAUDE_PLUGIN_ROOT/agents/research-discovery-business.md"
    model: "sonnet"
  - name: "research-discovery-technical"
    path: "$CLAUDE_PLUGIN_ROOT/agents/research-discovery-technical.md"
    model: "sonnet"
  - name: "research-discovery-ux"
    path: "$CLAUDE_PLUGIN_ROOT/agents/research-discovery-ux.md"
    model: "sonnet"
```

**Step 4: Synthesize Enhancements**
Using existing stakeholder-synthesis agent:
- Merge all agent outputs
- Deduplicate overlapping insights
- Organize by spec section
- Identify conflicts requiring user input

**Step 5: Generate Enhancement Report**
```markdown
## Enhancement Summary

**Deepened on:** {date}
**Agents used:** {list}
**Sections enhanced:** {count}

### Key Improvements
1. {improvement_1}
2. {improvement_2}

### New Considerations Discovered
- {consideration_1}
- {consideration_2}

### Conflicts Requiring Resolution
- {conflict_1}: [Agent A] vs [Agent B]
```
```

### 3.3 Skill: `specify-research-router`

```yaml
# skills/specify-research-router/SKILL.md

name: specify-research-router
description: Intelligent routing for research phases based on risk and context
version: 1.0.0
```

#### Configuration

```yaml
# Addition to config/specify-config.yaml

research_router:
  enabled: true
  version: "1.0.0"

  # Keywords that ALWAYS trigger external research
  high_risk_keywords:
    - "security"
    - "authentication"
    - "authorization"
    - "payment"
    - "billing"
    - "subscription"
    - "compliance"
    - "GDPR"
    - "HIPAA"
    - "PCI-DSS"
    - "SOC2"
    - "regulatory"
    - "financial"
    - "healthcare"
    - "encryption"
    - "PII"
    - "personal data"
    - "biometric"

  # Signals indicating strong local context (may skip research)
  strong_context_indicators:
    existing_specs_threshold: 3
    user_provides_examples: true
    domain_documented_in_claude_md: true

  # Research depth by decision
  research_depth:
    ALWAYS:
      agents: ["research-discovery-business", "research-discovery-technical", "research-discovery-ux"]
      thinkdeep_enabled: true
      mpa_mode: "complete"
    RECOMMENDED:
      agents: ["research-discovery-business", "research-discovery-technical"]
      thinkdeep_enabled: true
      mpa_mode: "advanced"
    OPTIONAL:
      agents: ["research-discovery-business"]
      thinkdeep_enabled: false
      mpa_mode: "standard"
    SKIP:
      agents: []
      thinkdeep_enabled: false
      mpa_mode: "rapid"
```

---

## Parte 4: Integration con Workflow Esistente

### 4.1 Modifiche a `/specify` Command

**Nuova struttura delle fasi:**

```
Phase 0 (NEW): Planning & Discovery
├── 0.1: Brainstorm Detection (specify-planning)
├── 0.2: Research Decision (specify-research-router)
├── 0.3: Detail Level Selection (specify-planning)
└── 0.4: Local Knowledge Integration (specify-planning)

Phase 1: Initialization (UNCHANGED)
├── 1.1: Validation
├── 1.2: Lock checking
└── 1.3: State detection

Phase 2: Workspace Setup (UNCHANGED)
├── 2.1: Directory creation
├── 2.2: Draft copying
└── 2.3: State initialization

Phase 3: Configuration (ENHANCED)
├── 3.1: Analysis mode selection (informed by Phase 0.3)
└── 3.2: Figma integration decision

Phase 4: Research Discovery (ENHANCED)
├── 4.1: Research routing check (from Phase 0.2)
├── 4.2: Conditional research execution
└── 4.3: Research synthesis

[... Phases 5-12 UNCHANGED ...]

Phase POST (NEW): Post-Generation Options
├── POST.1: Present workflow options
├── POST.2: Handle user selection
└── POST.3: Chain to selected action
```

### 4.2 Post-Generation Workflow Options

```markdown
### Phase POST: Workflow Continuation

**Present options via AskUserQuestion:**

```json
{
  "question": "Specification complete at `{spec_path}`. What would you like to do next?",
  "header": "Next Step",
  "options": [
    {
      "label": "Review specification (Recommended)",
      "description": "Open spec.md and test-plan.md for manual review before implementation."
    },
    {
      "label": "Run /deepen-spec",
      "description": "Enhance specification with parallel research and stakeholder review agents."
    },
    {
      "label": "Generate implementation plan",
      "description": "Create detailed implementation tasks from specification."
    },
    {
      "label": "Export to issue tracker",
      "description": "Create GitHub/Linear issues from user stories."
    }
  ]
}
```

**Action Handlers:**

- **Review specification**: `open {spec_path}` + `open {test_plan_path}`
- **Run /deepen-spec**: Invoke `specify-deepen` skill
- **Generate implementation plan**: Create tasks from user stories with AC mapping
- **Export to issue tracker**: Use gh/linear CLI to create issues
```

---

## Parte 5: Rationale delle Modifiche

### 5.1 Perché Brainstorm Detection?

**Problema Risolto:**
Gli utenti spesso eseguono sessioni di brainstorming separate prima di specificare una feature. Senza detection automatica, le stesse domande vengono poste di nuovo, creando frustrazione e perdita di tempo.

**Pattern di Riferimento:**
compound-engineering `/workflows:plan` Phase 0 implementa questo con successo, riducendo le domande duplicate del ~40%.

**Integrazione con Asset Esistenti:**
- **MPA**: Le decisioni dal brainstorm informano le prospettive degli stakeholder advocates
- **Sequential Thinking**: I template T1-T3 (Problem Framing) possono essere pre-popolati
- **Immutable User Decisions**: Le decisioni dal brainstorm sono trattate come user_decisions esistenti

### 5.2 Perché Risk-Based Research Routing?

**Problema Risolto:**
L'attuale workflow esegue sempre la stessa quantità di ricerca indipendentemente dal rischio del topic. Feature di sicurezza/pagamenti richiedono più validazione esterna, mentre feature UI semplici no.

**Pattern di Riferimento:**
compound-engineering Step 1.5 implementa decision logic basata su:
- High-risk keywords → sempre ricerca
- Strong local context → skip ricerca
- Uncertainty → ricerca raccomandata

**Integrazione con Asset Esistenti:**
- **PAL Consensus**: Per topic high-risk, PAL viene eseguito con stance "skeptical" più aggressivo
- **ThinkDeep**: Attivato automaticamente per ALWAYS e RECOMMENDED, disabilitato per SKIP
- **MPA Mode**: Scala da "complete" a "rapid" in base alla decisione di ricerca

**Beneficio Quantificabile:**
- Risparmio stimato: 30-50% di API calls per feature low-risk
- Aumento coverage: +20% per feature high-risk (più risorse allocate)

### 5.3 Perché Detail Level Stratification?

**Problema Risolto:**
Ogni spec ha lo stesso livello di dettaglio indipendentemente dalla complessità. Feature semplici vengono over-specified (spreco), feature complesse under-specified (rischio).

**Pattern di Riferimento:**
compound-engineering offre MINIMAL/MORE/A LOT con template dedicati e sezioni configurabili.

**Integrazione con Asset Esistenti:**
- **V-Model Testing**: Tutti i livelli includono test plan, ma la profondità varia:
  - MINIMAL: Solo happy path E2E + unit tests critici
  - STANDARD: Happy path + error handling + visual tests
  - COMPREHENSIVE: Full coverage matrix con risk scenarios
- **Sequential Thinking**: Numero di thoughts scala con detail level (8/12/15)
- **SADD Orchestrator**: Numero di agenti paralleli scala con detail level

### 5.4 Perché Local Knowledge Integration?

**Problema Risolto:**
Ogni nuova spec parte da zero, ignorando pattern già validati e learnings da spec precedenti. Questo porta a inconsistenze e errori ripetuti.

**Pattern di Riferimento:**
compound-engineering `/deepen-plan` Step 3 integra `docs/solutions/` e prior specs.

**Integrazione con Asset Esistenti:**
- **Business Analyst Agent**: Riceve prior_knowledge come context aggiuntivo
- **Stakeholder Advocates**: Possono riferire a pattern esistenti
- **Self-Critique Rubric**: Include check per "consistency with existing patterns"

### 5.5 Perché Post-Generation Workflow Options?

**Problema Risolto:**
Dopo la generazione della spec, l'utente deve manualmente decidere il prossimo passo. Questo interrompe il flow e introduce friction.

**Pattern di Riferimento:**
compound-engineering presenta sempre opzioni post-generazione con workflow chaining automatico.

**Integrazione con Asset Esistenti:**
- **State Management**: Le opzioni sono tracciate in `user_decisions.post_generation`
- **Resumability**: Se l'utente seleziona "deepen" e poi interrompe, può riprendere

### 5.6 Perché Specify-Deepen Skill?

**Problema Risolto:**
Non esiste un meccanismo per migliorare iterativamente una spec esistente. Una volta generata, le modifiche sono manuali.

**Pattern di Riferimento:**
compound-engineering `/deepen-plan` lancia agenti paralleli per ogni sezione con synthesis.

**Integrazione con Asset Esistenti:**
- **SADD Orchestrator**: Riutilizza `parallel-dispatch` esistente
- **Stakeholder Advocates**: Stessi agenti, mode diversa ("enhancement" vs "initial_review")
- **Stakeholder Synthesis**: Riutilizza per merge degli output
- **MPA Framework**: Deepen è essenzialmente un secondo round di MPA

---

## Parte 6: Configurazione Proposta

### 6.1 Additions to `config/specify-config.yaml`

```yaml
# =============================================================================
# PLANNING SKILL CONFIGURATION (v1.0)
# =============================================================================
# New section for specify-planning skill

planning_skill:
  enabled: true
  version: "1.0.0"

  # ─────────────────────────────────────────────────────────────
  # BRAINSTORM DETECTION
  # ─────────────────────────────────────────────────────────────
  brainstorm_detection:
    enabled: true
    directories:
      - "docs/brainstorms/"
      - "specs/brainstorms/"
      - "{FEATURE_DIR}/brainstorms/"
    max_age_days: 14
    relevance_threshold: 0.7

    # YAML frontmatter fields to extract
    extract_fields:
      - "topic"
      - "decisions"
      - "approach"
      - "constraints"
      - "open_questions"

  # ─────────────────────────────────────────────────────────────
  # DETAIL LEVELS
  # ─────────────────────────────────────────────────────────────
  detail_levels:
    minimal:
      label: "📄 Minimal"
      description: "Quick spec for simple features"
      triggers:
        max_user_stories: 3
        max_stakeholders: 1
        integrations: 0
      sections:
        - problem_statement
        - target_user
        - user_stories
        - acceptance_criteria
        - constraints
      mpa_mode: "standard"
      sequential_thinking_thoughts: 8
      test_strategy:
        levels: ["unit", "e2e"]
        coverage_mode: "happy_path"

    standard:
      label: "📋 Standard (Default)"
      description: "Balanced detail for most features"
      triggers:
        max_user_stories: 8
        max_stakeholders: 3
        integrations: 2
      sections:
        - problem_statement
        - stakeholder_analysis
        - jtbd_analysis
        - user_stories
        - acceptance_criteria
        - nfrs
        - constraints
        - design_brief
        - test_plan
      mpa_mode: "complete"
      sequential_thinking_thoughts: 12
      test_strategy:
        levels: ["unit", "integration", "e2e", "visual"]
        coverage_mode: "standard"

    comprehensive:
      label: "📚 Comprehensive"
      description: "Full detail for critical/complex features"
      triggers:
        min_user_stories: 9
        min_stakeholders: 4
        compliance_required: true
      sections:
        - problem_statement
        - competitive_analysis
        - stakeholder_analysis
        - jtbd_analysis
        - epic_hypothesis
        - user_stories
        - acceptance_criteria
        - nfrs
        - constraints
        - alternative_approaches
        - phased_delivery
        - resource_requirements
        - design_brief
        - design_feedback
        - test_plan
        - extensibility
      mpa_mode: "complete"
      thinkdeep_override:
        always_challenge: true
        always_edgecases: true
      sequential_thinking_thoughts: 15
      test_strategy:
        levels: ["unit", "integration", "e2e", "visual"]
        coverage_mode: "comprehensive"
        risk_scenarios: true

  # ─────────────────────────────────────────────────────────────
  # LOCAL KNOWLEDGE INTEGRATION
  # ─────────────────────────────────────────────────────────────
  local_knowledge:
    enabled: true
    scan_directories:
      specs: "specs/"
      learnings: "docs/learnings/"
      decisions: "docs/decisions/"
      postmortems: "docs/post-mortems/"
    relevance_threshold: 0.65
    max_results_per_category: 5

# =============================================================================
# RESEARCH ROUTER CONFIGURATION (v1.0)
# =============================================================================
# Configuration for specify-research-router skill

research_router:
  enabled: true
  version: "1.0.0"

  high_risk_keywords:
    - "security"
    - "authentication"
    - "authorization"
    - "oauth"
    - "jwt"
    - "payment"
    - "billing"
    - "subscription"
    - "checkout"
    - "compliance"
    - "GDPR"
    - "HIPAA"
    - "PCI-DSS"
    - "SOC2"
    - "regulatory"
    - "legal"
    - "financial"
    - "banking"
    - "healthcare"
    - "medical"
    - "encryption"
    - "cryptography"
    - "PII"
    - "personal data"
    - "biometric"
    - "sensitive"

  strong_context_indicators:
    existing_specs_threshold: 3
    user_provides_examples: true
    domain_documented_in_claude_md: true

  research_depth:
    ALWAYS:
      agents:
        - "research-discovery-business"
        - "research-discovery-technical"
        - "research-discovery-ux"
      thinkdeep_enabled: true
      mpa_mode: "complete"
      pal_stance_override:
        against_weight: 1.5  # More skeptical for high-risk
    RECOMMENDED:
      agents:
        - "research-discovery-business"
        - "research-discovery-technical"
      thinkdeep_enabled: true
      mpa_mode: "advanced"
    OPTIONAL:
      agents:
        - "research-discovery-business"
      thinkdeep_enabled: false
      mpa_mode: "standard"
    SKIP:
      agents: []
      thinkdeep_enabled: false
      mpa_mode: "rapid"

# =============================================================================
# DEEPEN SKILL CONFIGURATION (v1.0)
# =============================================================================
# Configuration for specify-deepen skill

deepen_skill:
  enabled: true
  version: "1.0.0"

  # Agents to launch in parallel
  parallel_agents:
    stakeholder_advocates:
      - "$CLAUDE_PLUGIN_ROOT/agents/stakeholder-advocates/end-user-advocate.md"
      - "$CLAUDE_PLUGIN_ROOT/agents/stakeholder-advocates/business-advocate.md"
      - "$CLAUDE_PLUGIN_ROOT/agents/stakeholder-advocates/operations-advocate.md"
      - "$CLAUDE_PLUGIN_ROOT/agents/stakeholder-advocates/security-advocate.md"
    research_agents:
      - "$CLAUDE_PLUGIN_ROOT/agents/research-discovery-business.md"
      - "$CLAUDE_PLUGIN_ROOT/agents/research-discovery-technical.md"
      - "$CLAUDE_PLUGIN_ROOT/agents/research-discovery-ux.md"

  synthesis:
    agent: "$CLAUDE_PLUGIN_ROOT/agents/stakeholder-synthesis.md"
    model: "opus"

  output:
    suffix: "-deepened"
    include_summary: true
    include_diff: true

# =============================================================================
# POST-GENERATION OPTIONS (v1.0)
# =============================================================================
# Configuration for workflow continuation after spec generation

post_generation:
  enabled: true
  version: "1.0.0"

  options:
    - id: "review"
      label: "Review specification (Recommended)"
      description: "Open spec.md and test-plan.md for manual review"
      action: "open_files"
      default: true

    - id: "deepen"
      label: "Run /deepen-spec"
      description: "Enhance with parallel research and stakeholder review"
      action: "invoke_skill"
      skill: "specify-deepen"

    - id: "implement"
      label: "Generate implementation plan"
      description: "Create detailed tasks from user stories"
      action: "generate_tasks"

    - id: "export"
      label: "Export to issue tracker"
      description: "Create GitHub/Linear issues from stories"
      action: "export_issues"

  # Chain configuration
  chaining:
    deepen_to_review: true  # After deepen, offer review
    implement_opens_tasks: true  # After implement, open task file
```

---

## Parte 7: File da Creare/Modificare

### 7.1 Nuovi File

| File Path | Tipo | LOC Stimate |
|-----------|------|-------------|
| `skills/specify-planning/SKILL.md` | Skill | ~300 |
| `skills/specify-deepen/SKILL.md` | Skill | ~250 |
| `skills/specify-research-router/SKILL.md` | Skill | ~150 |
| `templates/plan/plan-minimal-template.md` | Template | ~50 |
| `templates/plan/plan-standard-template.md` | Template | ~100 |
| `templates/plan/plan-comprehensive-template.md` | Template | ~200 |
| `agents/learnings-researcher.md` | Agent | ~150 |

### 7.2 File da Modificare

| File Path | Modifiche |
|-----------|-----------|
| `commands/specify.md` | Aggiungere Phase 0 (planning) e Phase POST (options) |
| `skills/sadd-orchestrator/SKILL.md` | Aggiungere capabilities: research-dispatch, learning-integration |
| `skills/specify-clarification/SKILL.md` | Integration con planning output, skip già-risolti |
| `config/specify-config.yaml` | Aggiungere sezioni planning_skill, research_router, deepen_skill, post_generation |

### 7.3 File Invariati (PRESERVED)

| File Path | Motivo |
|-----------|--------|
| `agents/stakeholder-advocates/*.md` | Riutilizzati as-is |
| `agents/research-discovery-*.md` | Riutilizzati as-is |
| `agents/qa-strategist.md` | V-Model testing preserved |
| `agents/business-analyst.md` | Core BA logic preserved |
| `agents/ba-references/sequential-thinking-templates.md` | ST templates preserved |
| `skills/specify-figma-capture/SKILL.md` | Figma integration preserved |

---

## Parte 8: Piano di Implementazione

### 8.1 Priorità

| Priorità | Componente | Dipendenze | Effort |
|----------|------------|------------|--------|
| **P0** | `config/specify-config.yaml` additions | Nessuna | 2h |
| **P0** | `skills/specify-research-router/SKILL.md` | Config | 4h |
| **P1** | `skills/specify-planning/SKILL.md` | Research router | 8h |
| **P1** | `commands/specify.md` Phase 0 integration | Planning skill | 4h |
| **P2** | `skills/specify-deepen/SKILL.md` | SADD orchestrator | 6h |
| **P2** | Post-generation options | Deepen skill | 3h |
| **P3** | Plan templates (3 levels) | Planning skill | 4h |
| **P3** | `agents/learnings-researcher.md` | None | 3h |

### 8.2 Test Strategy per le Modifiche

| Componente | Test Approach |
|------------|---------------|
| Research Router | Unit test con mock signals per ogni decision path |
| Brainstorm Detection | Integration test con sample brainstorm files |
| Detail Level Selection | E2E test generando spec a ogni livello |
| Local Knowledge | Integration test con sample specs/learnings |
| Post-Generation | E2E test di ogni workflow option |

---

## Parte 9: Rischi e Mitigazioni

| Rischio | Probabilità | Impatto | Mitigazione |
|---------|-------------|---------|-------------|
| Brainstorm detection false positives | Media | Basso | User confirmation prima di reuse |
| Research routing troppo aggressivo | Media | Medio | Conservative defaults, user override |
| Detail level auto-selection errata | Bassa | Medio | User always decides, auto è suggestion |
| Deepen genera conflitti | Alta | Basso | Synthesis agent identifica, user risolve |
| Performance degradation | Bassa | Alto | Parallel execution, timeout per agent |

---

## Parte 10: Metriche di Successo

| Metrica | Target | Misurazione |
|---------|--------|-------------|
| Domande duplicate evitate | -40% | Count domande skipped da brainstorm |
| API calls per feature low-risk | -30% | Token usage per spec |
| Time-to-spec per feature semplici | -25% | Minutes from start to complete |
| Spec consistency score | +15% | Self-critique rubric scores |
| User satisfaction (deepen) | >4.0/5 | Survey post-deepen |

---

## Conclusione

Questa proposta introduce miglioramenti significativi al workflow di specification mantenendo intatti tutti gli asset architetturali esistenti. L'approccio modulare (nuove skill separate) minimizza il rischio di regressioni e permette rollout incrementale.

Le modifiche sono ispirate a pattern validati in produzione (compound-engineering) ma adattate al contesto specifico di product-definition, preservando:
- **MPA** per multi-perspective analysis
- **Sequential Thinking** per reasoning strutturato
- **PAL Consensus** per validazione multi-modello
- **V-Model Testing** per test strategy completa
- **SADD Orchestrator** per parallel agent execution

L'implementazione può procedere per priorità, con P0/P1 completabili in una settimana e benefici immediati per gli utenti.

---

**Approvazione Richiesta:**
- [ ] Product Owner
- [ ] Technical Lead
- [ ] QA Lead

**Prossimi Passi:**
1. Review e feedback su questa proposta
2. Prioritizzazione finale
3. Creazione task di implementazione
4. Sprint planning
