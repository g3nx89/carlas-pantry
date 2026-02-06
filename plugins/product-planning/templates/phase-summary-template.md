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
    value: "clean_architecture_option_2"
    immutable: true
gate:
  name: "Architecture Quality"
  score: 4.2
  verdict: "GREEN"
  retries: 0
artifacts_written:
  - path: "design.minimal.md"
    description: "Minimal change architecture design"
  - path: "design.clean.md"
    description: "Clean architecture design"
  - path: "design.pragmatic.md"
    description: "Pragmatic balance design"
  - path: "design.md"
    description: "Final selected architecture (clean)"
summary: |
  Generated 3 MPA architecture options. Clean Architecture selected by user.
  Key integration point: shared auth service (existing).
  Risk: payment provider SDK lacks TypeScript types - needs adapter.
  Fork-Join ST explored 3 branches; pragmatic branch nearly tied.
flags:
  requires_user_input: false
  block_reason: null
  degraded: false
  degradation_reason: null
---

## Key Findings
- Clean Architecture option selected (Option 2) - scored highest on extensibility
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
