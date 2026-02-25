# Reflection Protocol

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Quality self-assessment for Figma design operations. Evaluates structural integrity,
> token binding, component reuse, naming, visual fidelity, and operational efficiency using a
> tiered approach: lightweight per-screen reflection (R1), full-rubric per-phase reflection (R2),
> and multi-agent critique at session end (R3).
>
> **Relationship**: Complements the convergence protocol (`convergence-protocol.md`) which prevents
> regression, and compound learning (`compound-learning.md`) which persists discoveries. The
> reflection protocol evaluates *quality* — whether the right thing was done, not just that
> something was done.

---

## 1. Figma Quality Dimensions

Six dimensions capture the quality surface of Figma design operations. Each scores 0-100.

| # | Dimension | Weight | What It Measures | Data Source |
|---|-----------|--------|------------------|-------------|
| D1 | **Structural Integrity** | 0.25 | Auto-layout correctness, nesting depth, GROUP-to-FRAME conversion, constraint assignments | `figma_get_file_for_plugin` node tree |

> **Weight rationale**: D1 carries 0.25 (vs 0.15 for others) because structural integrity is foundational — incorrect auto-layout, residual GROUPs, and broken constraints cascade into failures across D2 (token binding requires well-structured frames), D3 (component reuse depends on clean hierarchy), and D5 (visual fidelity breaks when structure is wrong). Fixing D1 often improves other dimensions as a side effect.
| D2 | **Token Binding** | 0.15 | Percentage of fills/strokes/effects/spacing bound to variables vs hardcoded | `figma_execute` `boundVariables` inspection |
| D3 | **Component Reuse** | 0.15 | Library components used vs custom elements, Smart Componentization adherence (3-gate criteria) | `figma_search_components` cross-referenced with placed instances |
| D4 | **Naming & Organization** | 0.15 | Semantic slash-convention names, no generic names, logical hierarchy, PascalCase for components | Node tree name analysis |
| D5 | **Visual Fidelity** | 0.15 | Alignment with intent/blueprint, 4px grid compliance, no visual regressions, health score | `figma_capture_screenshot` + `figma_audit_design_system` |
| D6 | **Operational Efficiency** | 0.15 | Batch usage ratio, native-tools-first adherence, redundant API call count, convergence check compliance | Operation journal analysis |

### Scoring Rubric

#### D1 — Structural Integrity

| Score | Criteria |
|-------|----------|
| 90-100 | All frames use auto-layout. Zero residual GROUPs. Nesting depth max 6. All constraints assigned per type |
| 70-89 | 90%+ auto-layout. 1-2 residual GROUPs. Constraints mostly correct |
| 50-69 | 70-89% auto-layout. Some GROUPs remain. Partial constraints |
| 30-49 | 50-69% auto-layout. Multiple GROUPs with silent constraint failures |
| 0-29 | <50% auto-layout. Heavy GROUP usage. Broken constraints |

#### D2 — Token Binding

| Score | Criteria |
|-------|----------|
| 90-100 | 95%+ fills bound to variables. Spacing from tokens. Zero hardcoded semantic colors |
| 70-89 | 80-94% bound. Few hardcoded values in non-critical locations |
| 50-69 | 60-79% bound. Hardcoded in primary surfaces/text |
| 30-49 | 30-59% bound despite token system existing |
| 0-29 | <30% bound, or no token system when one was available |

#### D3 — Component Reuse

| Score | Criteria |
|-------|----------|
| 90-100 | All recurring elements (3+ occurrences) use components. Zero custom where library equivalents exist |
| 70-89 | Most recurring elements componentized. 1-2 missed library matches |
| 50-69 | Components for obvious patterns. Some missed opportunities |
| 30-49 | Sporadic usage. Multiple custom builds duplicating library |
| 0-29 | Minimal usage. Rampant duplication |

#### D4 — Naming & Organization

| Score | Criteria |
|-------|----------|
| 90-100 | All layers use semantic slash-convention names. Zero generic. Logical hierarchy. PascalCase components |
| 70-89 | 90%+ named. 1-3 generic in deep children |
| 50-69 | 70-89% named. Some generic in visible sections |
| 30-49 | 50-69% named. Partially logical hierarchy |
| 0-29 | <50% named. "Frame 42", "Group 1" throughout |

#### D5 — Visual Fidelity

| Score | Criteria |
|-------|----------|
| 90-100 | Screenshot matches intent within 2px. All spacing on 4px grid. Zero regressions. Health score >= 80 |
| 70-89 | Minor spacing deviations (<8px). Alignment correct. Health 60-79 |
| 50-69 | Noticeable spacing issues. Some misalignment. Health 40-59 |
| 30-49 | Significant visual deviations. Health 20-39 |
| 0-29 | Major regression. Elements mispositioned or missing |

#### D6 — Operational Efficiency

| Score | Criteria |
|-------|----------|
| 90-100 | All 3+ same-type ops batched. Native tools used where supported. Zero redundant calls. Convergence checks before every mutation. Journal current |
| 70-89 | Most batching taken. 1-2 missed native-tool-first opportunities |
| 50-69 | Partial batching. Some individual calls where batching available |
| 30-49 | Minimal batching. Multiple individual same-type calls |
| 0-29 | No batching. Redundant calls. Missing convergence checks |

### Composite Score

```
composite = (D1 * 0.25) + (D2 * 0.15) + (D3 * 0.15) + (D4 * 0.15) + (D5 * 0.15) + (D6 * 0.15)
```

| Composite | Verdict | Action |
|-----------|---------|--------|
| >= 80 | **Pass** | Quality gate cleared, proceed to next phase |
| 60-79 | **Conditional Pass** | Flag dimensions below 70 for targeted improvement; proceed with caveats |
| < 60 | **Fail** | Mandatory fix cycle on lowest-scoring dimensions before continuing (max 2 iterations) |

---

## 2. Reflection Tiers

Four tiers match reflection depth to operation significance. Tiers use R-prefix to avoid collision with compound learning triggers (T1-T6).

| Tier | Name | Triggers At | Dimensions | Token Budget | Mechanism |
|------|------|-------------|------------|-------------|-----------|
| **R0** | Skip | Single-node ops, zero mutations | None | 0 | No reflection |
| **R1** | Quick Reflect | Per-screen completion | D1, D5, D6 | ~1.5K | Single-agent spot-check |
| **R2** | Standard Reflect | Phase boundary | All 6 + CoV | ~4K | Single-agent full rubric |
| **R3** | Deep Critique | Session completion | All 6 + 3 judges + debate | ~12K | 3 Figma-domain judges |

### Triage Decision Matrix

```
Has the session involved >0 mutating operations?
  No  -> R0 (Skip)
  Yes ->
    Was this a single-node operation (rename, fill, move)?
      Yes -> R0 (Skip)
    Was this a per-screen pipeline completion?
      Yes -> R1 (Quick Reflect)
    Was this a phase boundary?
      Yes -> R2 (Standard Reflect)
    Was this session completion (all phases)?
      Yes -> R3 (Deep Critique)
    Was this user-triggered?
      "reflect" keyword -> R2
      "critique" keyword -> R3
```

### Suppress Conditions

Skip reflection even when tier triggers are met if:
- Session total token usage already exceeds 150K (context conservation)
- User explicitly requests fast-track execution
- Workflow is Quick Audit with fewer than 3 deviations fixed
- Phase produced zero mutations (analysis-only)

---

## 3. R1 — Quick Reflect Procedure

**When**: After each screen pipeline completion (after screen validation — the final screenshot-fix cycle for that screen). Runs inline within per-screen subagents or the main agent for small workflows.

**Dimensions**: D1 (Structural Integrity), D5 (Visual Fidelity), D6 (Operational Efficiency) — the 3 dimensions with the most immediate data available.

**Procedure**:

```
1. Gather data (most already available from the screen pipeline):
   - D1: Count GROUPs remaining, auto-layout % (from node tree already inspected)
   - D5: Screenshot comparison result (from validation step), health score if available
   - D6: Journal entries for this screen — batch ratio, any redundant calls

2. Score each dimension (0-100) per rubric

3. Quick verdict:
   - All 3 >= 70 → pass (log and proceed)
   - Any dimension < 70 → flag with specific issue
   - Any dimension < 50 → targeted fix before declaring screen_complete

4. Log to journal (op: "reflection", tier: "R1")
```

**Token budget**: ~1.5K — no additional Figma tool calls needed beyond what the screen pipeline already executed. R1 is an assessment of existing data, not a new investigation.

---

## 4. R2 — Standard Reflect Procedure

**When**: At phase boundaries (after Phase 3 completion, or after other major phases).

**Dimensions**: All 6 (D1-D6) with Chain of Verification (CoV).

**Procedure**:

```
1. Gather data:
   - D1: figma_get_file_for_plugin (selectionOnly or page) — node tree analysis
         Count: GROUPs, auto-layout frames, nesting depth, constraint assignments
   - D2: figma_execute — sample check of boundVariables on key nodes
         Compute: bound_count / total_fill_count
   - D3: figma_search_components — cross-reference placed instances vs library
         Check: Smart Componentization 3-gate criteria compliance
   - D4: Node names from D1 tree — count generic vs semantic
   - D5: figma_audit_design_system — health score
         Compare: current health vs pre-phase baseline (if captured)
   - D6: Read operation-journal.jsonl — compute stats:
         batch_ratio = batch_ops / (batch_ops + individual_same_type_ops)
         convergence_compliance = convergence_checks / mutating_ops
         redundant_calls = ops targeting same node for same property

2. Score all 6 dimensions per rubric

3. Self-verification (CoV — Chain of Verification):
   - Generate 3-5 verification questions:
     "Did I check all screens or only a sample for D1?"
     "Is the token binding % skewed by screens with no design-system intent?"
     "Am I penalizing D6 for individual calls that were debugging fallbacks?"
   - Answer each question, adjust scores if warranted

4. Compute composite score, determine verdict

5. If fail or conditional_pass:
   - Identify lowest-scoring dimensions
   - Plan targeted fixes (max 2 iterations)
   - Execute fixes, re-score affected dimensions

6. Log to journal (op: "reflection", tier: "R2", all 6 scores + composite)
```

**Token budget**: ~4K — involves 2-3 Figma tool calls plus journal analysis. CoV adds ~500 tokens for verification questions.

**ST activation**: When R2 requires cross-referencing 3+ data sources (node tree + journal + audit), activate Sequential Thinking with the "Reflection Quality Assessment" template from `st-integration.md`.

---

## 5. R3 — Deep Critique Procedure

**When**: Session completion (all phases done) or user-triggered with "critique" keyword. Runs exactly once per session.

**Pattern**: Multi-Agent Debate with 3 Figma-domain judges dispatched in parallel, followed by coordinator synthesis.

### Judge Prompt Variables

All judge templates use `{braces}` placeholders. The orchestrator fills these from session state. If a variable is unavailable, use the fallback default.

| Variable | Type | Source | Fallback Default |
|----------|------|--------|------------------|
| `{file_name}` | string | `figma_list_open_files` result | `"Current active file"` |
| `{screen_list}` | string | Session state / operation journal | `"All screens on target page"` |
| `{target_page_id}` | string | `figma_get_status` or `figma_navigate` result | `"Current page"` |
| `{journal_path}` | string | Working directory | `"operation-journal.jsonl in working directory"` |
| `{collection_summary}` | string | `figma_get_variables(format="summary")` | `"Not pre-gathered — run figma_get_variables(format='summary') to discover"` |
| `{component_summary}` | string | `figma_search_components` result | `"Not pre-gathered — run figma_search_components to discover"` |
| `{start_ts}` | ISO 8601 | First journal entry timestamp | `"First entry in operation-journal.jsonl"` |
| `{end_ts}` | ISO 8601 | Current time | `"Current timestamp"` |

### Judge Definitions

#### Judge 1: Structure Judge

**Evaluates**: D1 (Structural Integrity) + D4 (Naming & Organization)

**Prompt template**:

```
## Role
Figma Structure Judge — evaluate the structural quality and naming organization
of Figma design elements created or modified in this session.

## Skill References (MANDATORY)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/design-rules.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-foundation.md

## Context
- Figma file: {file_name}
- Screens processed: {screen_list}
- Target page ID: {target_page_id}
- Session journal: {journal_path}

## Evaluation Process

1. Run node tree analysis:
   figma_get_file_for_plugin({ selectionOnly: false }) on the target page

2. Compute D1 metrics:
   - Total frames vs frames with auto-layout (%)
   - Residual GROUP count (should be 0)
   - Max nesting depth (should be <= 6)
   - Constraint assignments per type (per recipes-foundation.md reference table)

3. Compute D4 metrics:
   - Generic name count ("Frame N", "Group N", "Rectangle N")
   - Slash-convention compliance (e.g., "Header/TopBar", "Content/Card")
   - PascalCase for component names
   - Semantic descriptiveness (names reflect content, not geometry)

4. Self-verification (answer before scoring):
   - "Are residual GROUPs intentional (e.g., boolean operations)?"
   - "Does the project use a non-standard naming convention?"
   - "Is nesting depth reasonable for the design complexity?"

5. Score D1 and D4 per rubric, provide specific node IDs for issues.

## Output Format
Return JSON:
{
  "d1_score": <0-100>,
  "d4_score": <0-100>,
  "d1_issues": [{"node_id": "...", "issue": "...", "severity": "high|medium|low"}],
  "d4_issues": [{"node_id": "...", "issue": "...", "severity": "high|medium|low"}],
  "verification_answers": ["...", "...", "..."],
  "summary": "1-2 sentence assessment"
}
```

#### Judge 2: Design System Judge

**Evaluates**: D2 (Token Binding) + D3 (Component Reuse)

**Prompt template**:

```
## Role
Figma Design System Judge — evaluate token binding coverage and component reuse
efficiency of Figma design elements in this session.

## Skill References (MANDATORY)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-code-handoff.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-advanced.md

## Context
- Figma file: {file_name}
- Screens processed: {screen_list}
- Target page ID: {target_page_id}
- Available variable collections: {collection_summary}
- Available library components: {component_summary}

## Evaluation Process

1. Inspect token binding:
   figma_execute — scan nodes on target page, count:
   - Nodes with fills that have `boundVariables.fills` set
   - Nodes with hardcoded fills (no binding)
   - Spacing values from auto-layout (bound vs hardcoded)

2. Inspect component reuse:
   figma_search_components — list available library components
   figma_execute — scan target page for:
   - Component instances placed
   - Custom elements that match library component patterns (potential missed reuse)
   - Recurring visual patterns (3+ similar) that are not componentized

3. Apply Smart Componentization 3-gate check (from workflow-code-handoff.md):
   Gate 1: Recurrence (3+ occurrences)
   Gate 2: Behavioral variants exist
   Gate 3: Codebase match

4. Self-verification:
   - "Is low token binding justified? (e.g., one-off illustration, no token system available)"
   - "Are custom elements warranted? (no library equivalent, unique design)"
   - "Are recurring patterns truly identical or just visually similar?"

5. Score D2 and D3 per rubric, list specifics.

## Output Format
Return JSON:
{
  "d2_score": <0-100>,
  "d3_score": <0-100>,
  "d2_issues": [{"node_id": "...", "issue": "...", "current_value": "...", "suggested_variable": "..."}],
  "d3_issues": [{"pattern": "...", "occurrences": <N>, "library_match": "...|none", "action": "componentize|use-library|skip"}],
  "verification_answers": ["...", "...", "..."],
  "summary": "1-2 sentence assessment"
}
```

#### Judge 3: Efficiency Judge

**Evaluates**: D5 (Visual Fidelity) + D6 (Operational Efficiency)

**Prompt template**:

```
## Role
Figma Efficiency Judge — evaluate visual fidelity and operational efficiency
of the design session.

## Skill References (MANDATORY)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/convergence-protocol.md

## Context
- Figma file: {file_name}
- Screens processed: {screen_list}
- Session journal: {journal_path}
- Session duration: {start_ts} to {end_ts}

## Evaluation Process

1. Assess visual fidelity:
   figma_audit_design_system — get health score (0-100)
   figma_capture_screenshot — spot-check 1-2 representative screens
   Check: 4px grid compliance, alignment, spacing consistency

2. Analyze operational efficiency from journal:
   Read operation-journal.jsonl, compute:
   - batch_ratio = batch_op_count / (batch_op_count + individual_same_type_ops)
     (3+ same-type ops that were NOT batched count as missed opportunities)
   - native_tools_first = native_tool_uses / (native_tool_uses + figma_execute_for_native_ops)
     (e.g., using figma_execute for component search instead of figma_search_components)
   - convergence_compliance = convergence_check_ops / total_mutating_ops
   - redundant_ops = count of ops targeting same node+property with same value
   - fix_cycles_used = count per screen (should average < 2)

3. Self-verification:
   - "Is the health score low because of pre-existing issues, not session work?"
   - "Were individual calls justified (debugging fallback after batch failure)?"
   - "Is convergence compliance penalized unfairly for small inline workflows?"

4. Score D5 and D6 per rubric.

## Output Format
Return JSON:
{
  "d5_score": <0-100>,
  "d6_score": <0-100>,
  "health_score": <0-100>,
  "d5_issues": [{"screen": "...", "issue": "...", "severity": "high|medium|low"}],
  "d6_stats": {"batch_ratio": <0-1>, "native_tools_first": <0-1>, "convergence_compliance": <0-1>, "redundant_ops": <N>, "avg_fix_cycles": <N>},
  "d6_issues": [{"issue": "...", "journal_evidence": "...", "severity": "high|medium|low"}],
  "verification_answers": ["...", "...", "..."],
  "summary": "1-2 sentence assessment"
}
```

### R3 Coordinator Synthesis

After all 3 judges return:

```
1. Collect all 6 dimension scores from the 3 judges
2. Compute composite score using weights
3. Identify areas of agreement (all judges flag same concern)
4. Identify contradictions (e.g., Structure Judge says naming is fine, but
   Design System Judge notes component names don't match library conventions)
5. If contradictions exist:
   - Determine which judge has stronger evidence (node IDs, journal entries)
   - Note the disagreement with reasoning
6. Produce consensus verdict (pass / conditional_pass / fail)
7. Generate prioritized action items:
   - Must Do: dimensions < 50
   - Should Do: dimensions 50-69
   - Could Do: dimensions 70-79
8. Log to journal (op: "reflection", tier: "R3", all scores, judges, consensus)
```

---

## 6. Fix Cycle Protocol

When reflection produces a **fail** or **conditional_pass** verdict:

### R1 Fix Cycle (per-screen)

```
1. Identify the dimension(s) < 70
2. For D1 (Structural): Run targeted GROUP→FRAME conversion or auto-layout fix
   For D5 (Visual Fidelity): Enter screenshot-fix cycle (max 3, per existing protocol)
   For D6 (Efficiency): Note for improvement in subsequent screens (no retroactive fix)
3. Re-score affected dimension(s)
4. If still < 50 after fix: flag in screen_complete journal entry, proceed
5. Max 1 fix iteration for R1 (lightweight)
```

### R2 Fix Cycle (per-phase)

```
1. Rank dimensions by score (lowest first)
2. Fix bottom 2 dimensions:
   - D1: Batch GROUP→FRAME + auto-layout conversion
   - D2: Batch token binding via figma_execute setBoundVariable
   - D3: Identify and replace with library instances
   - D4: Batch rename using convergence-protocol batch rename template
   - D5: Screenshot comparison + targeted adjustments
   - D6: No retroactive fix (journal is immutable); note for remaining phases
3. Re-run R2 evaluation on ALL dimensions (not just fixed ones — fixes can cause collateral regression)
4. If any previously-passing dimension regressed below its pre-fix score: revert the fix that caused regression, log as `fix_regression` in journal
5. Max 2 fix iterations for R2
6. If still fail after 2 iterations: escalate to user with findings
```

### R3 Fix Cycle (session end)

```
1. R3 findings are advisory — no automatic fix cycle at session end
2. Present consensus report to user with prioritized action items
3. User decides whether to address findings or accept current state
4. If user requests fixes: re-enter relevant phase, apply fixes, re-run R2
```

---

## 7. Journal Integration

### New Operation Type

Add to the Operation Types table in `convergence-protocol.md`:

| `op` value | When to log | Key `detail` fields |
|-----------|-------------|-------------------|
| `reflection` | After every R1/R2/R3 reflection completes | `tier`, `scores` (per-dimension object), `verdict`, `issues`, `improvements_applied`. **R2/R3 only**: `composite_score`. **R3 only**: `judges`, `consensus` |

> **Note**: R0 (Skip) produces no journal entry — reflection is skipped entirely.

### Example Entries

**R1 (per-screen)**:
```jsonl
{"v":1,"ts":"2026-02-24T10:30:00Z","op":"reflection","target":"screen:ONB-03","detail":{"tier":"R1","scores":{"structural_integrity":92,"visual_fidelity":85,"operational_efficiency":88},"verdict":"pass","issues":[],"improvements_applied":0},"phase":3}
```

**R2 (per-phase)**:
```jsonl
{"v":1,"ts":"2026-02-24T11:00:00Z","op":"reflection","target":"phase_3","detail":{"tier":"R2","composite_score":82,"scores":{"structural_integrity":88,"token_binding":75,"component_reuse":90,"naming_organization":85,"visual_fidelity":78,"operational_efficiency":80},"verdict":"pass","issues":["D2: 5 hardcoded fills in secondary surfaces","D5: 2 spacing deviations >4px"],"improvements_applied":0},"phase":3}
```

**R3 (session)**:
```jsonl
{"v":1,"ts":"2026-02-24T12:00:00Z","op":"reflection","target":"session","detail":{"tier":"R3","composite_score":79,"scores":{"structural_integrity":85,"token_binding":72,"component_reuse":88,"naming_organization":80,"visual_fidelity":75,"operational_efficiency":78},"verdict":"conditional_pass","issues":["D2: 12 hardcoded fills remain","D5: Health score 68"],"improvements_applied":2,"judges":{"structure":{"d1":85,"d4":80},"design_system":{"d2":72,"d3":88},"efficiency":{"d5":75,"d6":78}},"consensus":"Structural quality strong. Token binding is the primary gap."},"phase":4}
```

---

## 8. Compound Learning Integration

### New Trigger T6

Add to the Auto-Detect Triggers table in `compound-learning.md`:

| # | Trigger | Category | Example |
|---|---------|----------|---------|
| T6 | **Reflection reveals systematic gap** — same dimension scored <70 across 2+ screens or 2+ sessions | Effective Strategies or Performance Patterns | "Token binding consistently low — batch binding at phase boundary is more effective than per-screen" |

### Reflection-to-Learning Pipeline

During Phase 4 compound learning save (after checking T1-T6 triggers), additionally:

```
1. Read all op: "reflection" entries from the session journal
2. Identify any dimension scoring <70 in 2+ reflection entries
   (cross-screen pattern within session, or cross-session if learnings file has prior reflection notes)
3. If found: compose a compound learning entry:
   - H3 key: dimension-name-systematic-gap (e.g., "token-binding-batch-at-phase-boundary")
   - Category: Effective Strategies or Performance Patterns
   - Problem: description of the systematic gap
   - Solution: corrective approach that improved scores when applied
   - Tags: dimension name + workflow type
4. Deduplicate per standard protocol (H3 key match + keyword spot-check)
```

---

## 9. Subagent Integration

### Per-Screen Subagents (R1)

Per-screen subagents run R1 as their final step (after screen validation — the screenshot-fix cycle — before declaring `screen_complete`). R1 is inline within the subagent, not a separate dispatch.

### Phase-Boundary Reflection (R2)

The orchestrator runs R2 inline at phase boundaries. No subagent dispatch needed — R2 is 2-3 Figma tool calls plus journal analysis.

### Session-End Critique (R3)

The orchestrator dispatches 3 judge subagents in parallel using `Task(subagent_type="general-purpose")`. Each judge receives its prompt template (Section 5) with context variables filled by the orchestrator. After all 3 complete, the orchestrator runs the coordinator synthesis inline.

**Judge context budget**: Each judge loads ~5K tokens of references + ~2K prompt = ~7K per judge. Total: ~21K for 3 judges + ~3K for synthesis = ~24K. With reference caching (typical when skill is already loaded), expect ~10-12K actual cost. Without caching (cold start), full ~24K applies.

### Subagent Prompt Extension

When constructing per-screen subagent prompts using the Subagent Prompt Template from `convergence-protocol.md`, add this to the Mandatory Rules:

```
16. Run R1 Quick Reflect after screen validation completes: evaluate D1, D5, D6 per
    reflection-protocol.md rubric. Log op: "reflection" to journal. If any dimension < 50,
    attempt one fix cycle before declaring screen_complete
```

---

## 10. Session Protocol Integration

### Updated Phase 4 Flow

```
Phase 4 — Validation
  1. figma_capture_screenshot → visual check (max 3 fix cycles)     [unchanged]
  2. Verify: alignment, spacing, proportions, visual hierarchy       [unchanged]
  3. figma_generate_component_doc → document components              [unchanged]
  4. Reflection (per triage — see Section 2):                        [NEW]
     - R2 at phase boundary (full 6-dimension rubric)
     - R3 at session completion (3 Figma-domain judges)
     - Fix cycle if verdict is fail/conditional_pass (max 2 iter)
  5. Save compound learnings (now includes T6 from reflection)       [updated]
```

**Note**: R1 runs per-screen within Phase 3 (after screen validation), not in Phase 4. R2/R3 run in Phase 4.

---

## Cross-References

- **Convergence Protocol** (journal schema, subagent prompt template): `convergence-protocol.md`
- **Compound Learning** (save triggers T1-T6, cross-session persistence): `compound-learning.md`
- **ST Integration** (Reflection Quality Assessment thought chain): `st-integration.md`
- **Anti-patterns** (known errors to distinguish from quality gaps): `anti-patterns.md`
- **Design Rules** (MUST/SHOULD/AVOID — referenced by Structure Judge): `design-rules.md`
- **Code Handoff** (Smart Componentization 3-gate criteria — referenced by Design System Judge): `workflow-code-handoff.md`
- **SKILL.md** (Phase 4 protocol, MUST/AVOID rules): `SKILL.md`

---

## Maintenance: Adding a New Dimension

When adding a dimension D7 (or modifying existing dimensions), update all of these locations:

- [ ] **Section 1 table** — add dimension row with weight, description, data source
- [ ] **Section 1 rubric** — add 5-tier scoring rubric (0-29, 30-49, 50-69, 70-89, 90-100)
- [ ] **Composite score formula** — update weights (must still sum to 1.0)
- [ ] **R2 procedure (Section 4)** — add data gathering step for the new dimension
- [ ] **R3 judge assignment (Section 5)** — assign to existing judge or create new judge
- [ ] **R3 judge prompt variable table** — add any new variables the dimension needs
- [ ] **Journal schema (Section 7)** — new dimension appears in `scores` object
- [ ] **Compound learning T6 (Section 8)** — new dimension eligible for systematic gap detection
- [ ] **README.md** — update file description line count and content summary
