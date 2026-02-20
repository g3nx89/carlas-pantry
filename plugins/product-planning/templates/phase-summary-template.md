# Phase Summary Template

> **Purpose:** Standardized inter-phase communication file. Each coordinator writes a summary
> after completing its phase. The orchestrator reads ONLY these summaries (not full artifacts)
> to maintain context between phases.
>
> **Path Convention:** `{FEATURE_DIR}/.phase-summaries/phase-{N}-summary.md`
> where N is the phase identifier (1, 2, 3, 4, 5, 6, 6b, 7, 8, 9).

## YAML Frontmatter Schema

```yaml
---
summary_version: 1                   # Schema version for future migration
phase: "{N}"                        # Phase identifier (string: "1"-"9", "6b")
phase_name: "{Phase Name}"          # Human-readable phase name
checkpoint: "{CHECKPOINT_NAME}"     # State checkpoint (e.g., SETUP, RESEARCH, ARCHITECTURE)
status: "completed"                 # completed | needs-user-input | failed | skipped
timestamp: "{ISO_8601}"             # When this summary was written
analysis_mode: "{mode}"             # complete | advanced | standard | rapid
decisions:
  - key: "{decision_key}"           # Machine-readable key
    value: "{decision_value}"       # Selected value
    immutable: true                 # true for user decisions, false for derived
gate:                               # Quality gate results (omit if phase has no gate)
  name: "{Gate Name}"
  score: 0.0                        # Numeric score
  verdict: "GREEN"                  # GREEN | YELLOW | RED | SKIP
  retries: 0                        # Number of retry attempts
artifacts_written:
  - path: "{relative_path}"         # Relative to {FEATURE_DIR}
    description: "{what it contains}"
summary: |
  {3-5 sentence executive summary of what this phase accomplished,
  key findings, and critical context for subsequent phases.}
flags:
  requires_user_input: false         # true if orchestrator must ask user something
  block_reason: null                 # What input is needed (if requires_user_input)
  degraded: false                    # true if a sub-agent failed and results are partial
  degradation_reason: null           # What failed and what's missing
  critical_security_count: null      # Count of CRITICAL severity findings (Phase 6b only)
  high_security_count: null          # Count of HIGH severity findings (Phase 6b only)
  algorithm_difficulty: null         # true if coordinator found algorithmic challenge (Phase 4/7)
  deep_reasoning_supplement: null    # true if deep reasoning response was appended (Phase 6b)
  low_specify_score: null            # true if Phase 3 specify gate score < 6 after max iterations
key_decisions:                       # S6: Accumulated decision trail (a6_context_protocol)
  - id: "KD-{N}-{seq}"              # Phase-prefixed unique ID
    decision: "{what was decided}"
    rationale: "{why}"
    confidence: "HIGH|MEDIUM|LOW"    # HIGH = should not be reversed without justification
open_questions:                      # S6: Unresolved questions carried forward
  - id: "OQ-{N}-{seq}"
    question: "{what remains unanswered}"
    priority: "HIGH|MEDIUM|LOW"
    candidates: ["{possible answers}"]
risks_identified:                    # S6: Risks surfaced by this phase
  - id: "RISK-{N}-{seq}"
    risk: "{what could go wrong}"
    severity: "CRITICAL|HIGH|MEDIUM|LOW"
    mitigation: "{proposed mitigation or 'unmitigated'}"
specify_score: null                  # S8: Phase 3 only — specify gate score (0-10)
specify_dimensions: null             # S8: Phase 3 only — per-dimension scores
  # value: 0          # Value clarity (0/1/2)
  # scope: 0          # Scope definition (0/1/2)
  # acceptance: 0     # Acceptance criteria quality (0/1/2)
  # constraints: 0    # Constraints & dependencies (0/1/2)
  # risk: 0           # Risk identification (0/1/2)
---
```

## Markdown Body Sections

### Key Findings
- {3-5 bullet points summarizing the most important discoveries or outputs}
- {Focus on decisions made, risks identified, and integration points}

### Artifacts Produced

| Artifact | Description |
|----------|-------------|
| `{path}` | {What it contains and why it matters} |

### Quality Gate
- **Gate:** {gate name} — {score}/{max} ({verdict: GREEN | YELLOW | RED})
- Write "N/A — this phase has no quality gate" if not applicable.

### Context for Next Phase
{This is the MOST IMPORTANT section. Write 3-8 lines of executive summary that the
next phase coordinator needs to understand. Include:}
- What was decided and why
- Key constraints or risks discovered
- Specific areas the next phase should focus on
- Any unresolved items carried forward

### Key Decisions
{List decisions made during this phase. Each entry maps to `key_decisions` YAML array.}
- **KD-{N}-1:** {decision} — Confidence: {HIGH|MEDIUM|LOW}
- **KD-{N}-2:** {decision} — Confidence: {HIGH|MEDIUM|LOW}

### Open Questions
{List unresolved questions carried forward. Each entry maps to `open_questions` YAML array.}
- **OQ-{N}-1:** {question} — Priority: {HIGH|MEDIUM|LOW}

### Risks Identified
{List risks surfaced by this phase. Each entry maps to `risks_identified` YAML array.}
- **RISK-{N}-1:** {risk} — Severity: {CRITICAL|HIGH|MEDIUM|LOW} — Mitigation: {action or "unmitigated"}

### User Input Required
{Only include this section if status: needs-user-input}
- **Question:** {What the orchestrator should ask the user}
- **Options:** {Available choices, if applicable}
- **Default:** {Recommended option, if any}
- **Context:** {Why this input is needed}

---

## Calibration Examples

### GOOD Example (Phase 4 Architecture)

```yaml
---
phase: "4"
phase_name: "Architecture Design"
checkpoint: "ARCHITECTURE"
status: "completed"
timestamp: "2026-02-06T14:30:00Z"
analysis_mode: "complete"
decisions:
  - key: "selected_architecture"
    value: "ideality_perspective"
    immutable: true
gate:
  name: "Architecture Quality"
  score: 4.2
  verdict: "GREEN"
  retries: 0
artifacts_written:
  - path: "design.grounding.md"
    description: "Structural Grounding perspective (Inside-Out × Structure)"
  - path: "design.ideality.md"
    description: "Contract Ideality perspective (Outside-In × Data)"
  - path: "design.resilience.md"
    description: "Resilience Architecture perspective (Failure-First × Behavior)"
  - path: "design.md"
    description: "Final composed architecture design"
summary: |
  Generated 3 Diagonal Matrix architecture perspectives. Contract Ideality composed as anchor.
  Key integration point: shared auth service (existing).
  Risk: payment provider SDK lacks TypeScript types - needs adapter.
  Diagonal Matrix ST explored 3 perspectives; low tension across matrix cells.
flags:
  requires_user_input: false
  block_reason: null
  degraded: false
  degradation_reason: null
---

## Key Findings
- Contract Ideality perspective composed as anchor - scored highest on extensibility
- Shared authentication service exists at src/services/auth.ts
- Payment SDK integration needs TypeScript adapter layer

## Quality Gate
- **Gate:** Architecture Quality — 4.2/5.0 (GREEN, threshold >=3.5)

## Context for Next Phase
Phase 5 (ThinkDeep) should focus analysis on:
1. Performance: Payment SDK latency under concurrent load
2. Security: Auth token propagation across new service boundary
3. Maintainability: Adapter pattern for payment SDK version migrations
```

### BAD Example (Anti-Pattern)

> **DO NOT write summaries like this:**
>
> ```yaml
> summary: "Phase complete. See design.md for details."
> ```
>
> This forces the orchestrator to read the full artifact, defeating the purpose
> of summary-based context management. Always include actionable context.

---

## Notes

- This template is for **inter-phase machine communication**. No glossary needed.
- Summaries should be **30-80 lines** total (YAML + markdown).
- The `Context for Next Phase` section is read by the next coordinator to understand priorities.
- Phase identifiers are **strings** to accommodate `6b`.
- **Gate verdict translation:** Judge agents produce `PASS/FAIL` verdicts internally. When writing the summary, translate to the orchestrator vocabulary: `PASS` → `GREEN`, `FAIL` with score ≥ threshold → `YELLOW`, `FAIL` below threshold → `RED`. The orchestrator checks `verdict == "RED"` for retry logic.
- **Deep reasoning escalation flags:** The `critical_security_count`, `high_security_count`, `algorithm_difficulty`, and `deep_reasoning_supplement` flags support the orchestrator's deep reasoning escalation workflow. Coordinators set `critical_security_count` (Phase 6b), `high_security_count` (Phase 6b), and `algorithm_difficulty` (Phase 4/7) but never offer escalation directly. The orchestrator sets `deep_reasoning_supplement` after appending external model analysis. See `deep-reasoning-dispatch-pattern.md`.
- **Context Protocol fields (S6):** When `a6_context_protocol` is enabled, every phase MUST populate `key_decisions`, `open_questions`, and `risks_identified` in the YAML frontmatter. The orchestrator accumulates these across phases and includes them in the Context Pack sent to subsequent coordinators. HIGH-confidence decisions should not be contradicted without explicit justification.
- **Specify Gate fields (S8):** `specify_score` and `specify_dimensions` are populated by Phase 3 only, when `s12_specify_gate` is enabled. The orchestrator uses `specify_score` to assess specification completeness. If `low_specify_score` flag is set, downstream phases are aware the spec may have gaps.
