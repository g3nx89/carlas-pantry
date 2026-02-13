# Synthesis Rules

Rules for merging 7 independent lens analyses (plus any optional lenses) into a consolidated review report. The coordinator applies these rules after reading all analysis files from `.skill-review/`.

## Step 1: Parse All Analyses

Read each `{lens-id}-analysis.md` file from `{target-dir}/.skill-review/`. Extract:
- All findings (title, severity, category, file, current state, recommendation)
- All strengths
- YAML frontmatter metrics (findings_count, critical_count, etc.)
- Whether fallback criteria were used (`fallback_used`)

If an analysis file is missing (sub-agent failed), note the lens as degraded and proceed with available analyses. If fewer than 3 analyses are available, warn in the report that coverage is limited.

### Populate `lenses_degraded`

Collect all lenses where `fallback_used: true` in the analysis frontmatter OR where the analysis file is missing entirely. Pass this list as the `lenses_degraded` field to the report template.

## Step 2: Deduplicate Findings

Compare findings across lenses. Two findings address the **same issue** when:
- They reference the same file AND same section/area, AND
- Their recommendations target the same aspect (even if phrased differently)

When merging duplicates:
- **Severity**: Keep the highest severity from any lens
- **Citations**: List all lenses that flagged the issue (shows cross-lens validation)
- **Recommendation**: Use the most specific and actionable recommendation among the duplicates
- **Category**: Assign to the primary category; note secondary categories if applicable

## Step 3: Priority Assignment

Apply cross-lens escalation after deduplication:

| Condition | Assigned Priority |
|-----------|-------------------|
| Any single CRITICAL finding | CRITICAL |
| Same issue flagged by 3+ lenses at HIGH | CRITICAL |
| Same issue flagged by 2+ lenses at HIGH | HIGH |
| Single lens CRITICAL + others at MEDIUM for same issue | HIGH |
| Single lens HIGH (not cross-validated) | HIGH |
| 2+ lenses at MEDIUM for same issue | MEDIUM |
| Single lens MEDIUM (not cross-validated) | MEDIUM |
| Single lens LOW or below | LOW |
| Positive observations, stylistic preferences | INFO |

Cross-lens validation (same issue from 2+ lenses) always escalates one tier.

## Step 4: Grouping

Organize findings into these categories:

1. **Structure & Organization** — Directory layout, file wiring, progressive disclosure
2. **Content Quality & Clarity** — Writing quality, conciseness, terminology, readability
3. **Prompt & Instruction Effectiveness** — Clarity of instructions, LLM guidance, decision coverage
4. **Context & Token Efficiency** — SKILL.md size, reference loading, attention placement, redundancy
5. **Completeness & Coverage** — Edge cases, error paths, missing content, overall effectiveness
6. **Reasoning & Logic** — Reasoning chains, decomposition, verification, decision frameworks
7. **Architecture & Coordination** — Component patterns, bottlenecks, failure propagation, validation gates

## Step 5: Scoring

### Per-Lens Score (1-5)

Per-lens scoring uses the **original (pre-dedup) finding counts** from each lens's individual analysis file frontmatter (`critical_count`, `high_count`, etc.). Deduplication affects only the consolidated report, not per-lens scores.

Evaluate from top to bottom; apply the **first matching** row:

| Score | Criteria |
|-------|----------|
| 5 | 0 critical, 0 high, ≤2 medium |
| 4 | 0 critical, 0-1 high, 3-4 medium |
| 3 | 0 critical, 2+ high, OR 0 critical + 5+ medium |
| 2 | 1 critical (any high/medium count), OR 0 critical + 3-4 high |
| 1 | 2+ critical, OR 5+ high |

### Overall Score (Weighted Average)

> Default lens weights are sourced from `config/skill-analyzer-config.yaml` (`scoring.weights`). The table below adds rationale context.

| Lens | Rationale |
|------|-----------|
| Structure | Foundation — structural issues affect all other dimensions |
| Prompt Quality | Core purpose — skill must guide Claude effectively |
| Context Efficiency | Scalability — inefficient context wastes tokens at every invocation |
| Writing Quality | Polish — affects readability but less critical than structure/function |
| Effectiveness | Outcome — does the skill achieve its purpose? |
| Reasoning | Rigor — are reasoning chains explicit, decomposed, and verified? |
| Architecture | Coordination — are multi-component patterns appropriate and robust? |

Formula (default 7 lenses): `overall = sum(lens_score × lens_weight)` where weights are defined in config.

#### Optional Lens Weight Integration

When N optional lenses are active (per `config/skill-analyzer-config.yaml` `scoring.optional`):

```
per_lens_weight = 0.05  (from config: scoring.optional.per_lens_weight)
scale_factor = 1.0 - (N × per_lens_weight)
each default lens weight = original_weight × scale_factor
each optional lens weight = per_lens_weight
```

Example with 2 optional lenses: scale_factor = 0.90, structure weight becomes 0.20 × 0.90 = 0.18, each optional lens = 0.05.

#### Category Mapping for Optional Lenses

When optional lenses produce findings, route them to these categories:

| Optional Lens | Primary Category | Secondary Category |
|---------------|-----------------|-------------------|
| `config` | Structure & Organization | — |
| `agent-design` | Architecture & Coordination | — |
| `reasoning-method` | Reasoning & Logic | — |
| `escalation` | Architecture & Coordination | Completeness & Coverage |

If a lens is degraded (analysis missing), redistribute its weight proportionally across remaining lenses.

## Step 6: Construct Modification Plan

**INFO-priority items are excluded from the Modification Plan.** Route them to the Strengths section in Step 7 instead.

Build the modification plan table from CRITICAL, HIGH, MEDIUM, and LOW findings only:

1. **Order**: CRITICAL first, then HIGH, then MEDIUM, then LOW. Within the same priority tier, order by estimated effort (quick wins first).
2. **Cap**: Maximum action items per `config/skill-analyzer-config.yaml` (`thresholds.max_modification_plan_items`, default 15). If more exist, group remaining items under an "Additional Improvements" section.
3. **Each action item includes**:
   - `#`: Sequential number
   - `Priority`: CRITICAL | HIGH | MEDIUM | LOW
   - `Action`: Concise description of what to change
   - `File`: Which file to modify (relative to skill directory)
   - `Section`: Which section or area within the file
   - `Effort`: S | M | L (see heuristics below)
   - `Lenses`: Which lenses flagged this (e.g., "structure, context")

### Effort Estimation Heuristics

Effort thresholds are defined in `config/skill-analyzer-config.yaml` (`effort_estimates`):

- **S (Small)**: Localized text edit within one section — wording change, field addition, threshold fix
- **M (Medium)**: New section, restructured content, or changes spanning 2-3 files
- **L (Large)**: Architectural reorganization, new reference file creation, or multi-file structural overhaul

## Step 7: Consolidate Strengths

Merge strengths from all lenses:
- Group similar strengths (same aspect praised by multiple lenses)
- Cite the lens(es) that identified each strength
- Order from most cross-validated to single-lens observations

## Output

Pass the synthesized data to the report template (`references/report-template.md`) to generate the final report.
