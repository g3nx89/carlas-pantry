# Sequential Thinking Integration Templates for Figma Console Mastery

> **Compatibility**: Verified against ST server v0.2.0 (npm 2025.12.18), figma-console-mcp v1.10.0 (February 2026)
>
> **Prerequisites**: `mcp__sequential-thinking__sequentialthinking` MCP server must be configured.
> For full ST documentation, see the `sequential-thinking-mastery` skill.
>
> **Load when**: A figma-console-mastery workflow triggers ST activation per the conditions in
> SKILL.md (multi-step diagnostic chains, branching decisions, iterative fix loops).

## Activation Protocol

### Pre-Check

Before using ST in any Figma workflow:
1. Verify ST server is available (attempt a single thought with `totalThoughts: 1, nextThoughtNeeded: false`)
2. If unavailable, proceed with the workflow normally — ST is never a hard dependency

### Suppress Conditions

Skip ST even when triggers are met if:
- The design session is a Quick Audit with <3 deviations found
- The workflow follows a simple G1 (instantiate) or G2 (<5 nodes) path
- The user explicitly requests fast-track execution
- The total workflow has fewer than 3 decision points

### Placeholder Reference

Templates below use `{braces}` placeholders. Fill them from actual tool outputs:

| Placeholder | Source |
|-------------|--------|
| `{root_name}`, `{root_id}` | `figma_get_file_for_plugin` or `figma_execute` return value |
| `{total_nodes}`, `{missing_auto_layout}`, `{hardcoded_colors}`, `{generic_names}` | Deep Node Tree Analysis recipe output |
| `{patterns_found}`, `{top_count}`, `{fingerprint}` | Repeated Pattern Detection recipe output |
| `{health_score}` | `figma_audit_design_system` scorecard |
| `{deviation_count}` | Sum of all deviation categories from analysis |
| `{auto_layout_pct}` | Computed: `(totalFrames - missingAutoLayout) / totalFrames * 100` |

---

## Template Index

| Template | Workflow | ST Pattern | Thoughts | Section |
|----------|----------|------------|----------|---------|
| Phase 1 Analysis | Design Restructuring | TAO Loop + Hypothesis | 7-9 | [Link](#template-phase-1-analysis) |
| Path A/B Fork-Join | Design Restructuring Phase 2 | Fork-Join | 6-8 | [Link](#template-path-ab-fork-join) |
| Visual Fidelity Loop | Restructuring Phase 3A/3B | TAO Loop + Revision | 3-5 per cycle | [Link](#template-visual-fidelity-loop) |
| Naming Audit Reasoning | Code Handoff Protocol | TAO Loop | 5-7 | [Link](#template-naming-audit-reasoning) |
| Iterative Refinement | Any screenshot-fix cycle | TAO Loop + Revision + Circuit Breaker | 3-6 per cycle | [Link](#template-iterative-refinement) |
| Design System Bootstrap | recipes-advanced.md | Checkpoint | 5-7 | [Link](#template-design-system-bootstrap-checkpoint) |
| Reflection Quality Assessment | Any phase/session reflection (R2+) | TAO Loop | 5-7 | [Link](#template-reflection-quality-assessment) |

---

## Template: Phase 1 Analysis

**When**: Design Restructuring Phase 1 finds deviations in 3+ categories after running Deep Node Tree Analysis.

**Pattern**: TAO Loop — alternate `sequentialthinking` calls with Figma tool calls. Each thought generates or eliminates a hypothesis about the design's structural health.

**Thought chain** (7 thoughts interleaved with Figma tool calls):

```
Thought 1: Frame scope → Action: Deep Node Tree Analysis
Thought 2: Analyze deviations → Action: Repeated Pattern Detection
Thought 3: Assess patterns → Action: figma_get_design_system_summary + figma_get_variables
Thought 4: Cross-reference tokens → Action: figma_audit_design_system
Thought 5: Integrate health score (Rule of 5 checkpoint)
Thought 6: Compile findings summary (phase boundary checkpoint)
Thought 7: Determine recommended path → nextThoughtNeeded: false
```

### JSON Examples

**Thought 1 — Frame the analysis scope:**

```json
{
  "thought": "RESTRUCTURING ANALYSIS: Scanning frame '{root_name}' (ID: {root_id}). Hypotheses ranked by likelihood: H1 - Flat hierarchy with missing auto-layout (common in freehand designs, 70% prior). H2 - Hardcoded colors with no token system (60% prior). H3 - Generic names indicating no naming convention (50% prior). Running Deep Node Tree Analysis to quantify deviations and update priors.",
  "thoughtNumber": 1,
  "totalThoughts": 7,
  "nextThoughtNeeded": true
}
```

> **Action**: `figma_execute` with Deep Node Tree Analysis recipe

**Thought 2 — Analyze deviation report:**

```json
{
  "thought": "ANALYSIS RESULTS: {total_nodes} nodes scanned. Deviations: {missing_auto_layout} frames without auto-layout ({auto_layout_pct}% coverage), {hardcoded_colors} hardcoded fills, {non_grid_spacing} non-4px spacing values, {generic_names} generic names, {flat_hierarchy} flat containers (10+ children). H1 CONFIRMED: {missing_auto_layout} frames lack auto-layout. H2 status: {hardcoded_colors} unbound fills — need to verify whether variable collections exist before confirming. H3 CONFIRMED: {generic_names} generic names. Running pattern detection to assess componentization potential.",
  "thoughtNumber": 2,
  "totalThoughts": 7,
  "nextThoughtNeeded": true
}
```

> **Action**: `figma_execute` with Repeated Pattern Detection recipe

**Thought 3 — Assess patterns (with conditional revision):**

```json
{
  "thought": "PATTERN DETECTION: Found {patterns_found} repeated patterns. Top pattern appears {top_count}x with fingerprint '{fingerprint}'. This suggests {top_count} elements are candidates for a single component. Checking design system inventory to determine if matching library components already exist — if so, componentization becomes replacement rather than extraction.",
  "thoughtNumber": 3,
  "totalThoughts": 7,
  "nextThoughtNeeded": true
}
```

> **Action**: `figma_get_design_system_summary` + `figma_get_variables(format="summary")`

**If tool output contradicts initial hypothesis** (e.g., tokens exist but are not bound), use revision:

```json
{
  "thought": "REVISION: Token collections DO exist ({collection_count} collections, {variable_count} variables) but {hardcoded_colors} fills are not bound. Revising H2: the problem is not absence of tokens but incomplete binding. This changes the restructuring scope — token creation is unnecessary; batch token binding is the corrective action.",
  "thoughtNumber": 3,
  "totalThoughts": 7,
  "isRevision": true,
  "revisesThought": 2,
  "nextThoughtNeeded": true
}
```

**Thought 4 — Cross-reference tokens against deviations:**

```json
{
  "thought": "DESIGN SYSTEM INVENTORY: {collection_count} variable collections found with {variable_count} total variables. {component_count} published components available. Cross-referencing: {hardcoded_colors} unbound fills could potentially map to {matching_token_count} existing tokens. Updating H2: {h2_revised_status}. Running health score baseline to quantify overall structural quality.",
  "thoughtNumber": 4,
  "totalThoughts": 7,
  "nextThoughtNeeded": true
}
```

> **Action**: `figma_audit_design_system`

**Thought 5 — Rule of 5 checkpoint:**

```json
{
  "thought": "CHECKPOINT (Rule of 5): Health score {health_score}/100. Reviewing totalThoughts estimate — findings are comprehensive, no additional diagnostic tools needed. Remaining thoughts: compile summary (1) + recommend path (1). Estimate holds at 7.",
  "thoughtNumber": 5,
  "totalThoughts": 7,
  "nextThoughtNeeded": true
}
```

**Thought 6 — Phase boundary checkpoint:**

```json
{
  "thought": "PHASE 1 SUMMARY: Frame '{root_name}' — {total_nodes} nodes, {health_score}/100 health. Key findings: (1) {auto_layout_pct}% auto-layout coverage — {missing_auto_layout} frames need conversion. (2) {hardcoded_colors} unbound fills — token system {exists_or_needs_creation}. (3) {patterns_found} repeated patterns — top candidate ({top_count}x) suitable for component extraction. (4) {generic_names} generic names. (5) {flat_hierarchy} flat containers need grouping. Ready for Phase 2 Socratic questioning.",
  "thoughtNumber": 6,
  "totalThoughts": 7,
  "nextThoughtNeeded": true
}
```

**Thought 7 — Path recommendation:**

```json
{
  "thought": "PATH RECOMMENDATION: Based on deviation density ({deviation_pct}% of nodes affected) and structural depth analysis: Path {A_or_B} is recommended. Rationale: {path_reasoning}. Presenting Phase 1 findings and path recommendation to user for Phase 2 Socratic discussion. Analysis complete.",
  "thoughtNumber": 7,
  "totalThoughts": 7,
  "nextThoughtNeeded": false
}
```

---

## Template: Path A/B Fork-Join

**When**: Phase 1 analysis is complete and both restructuring paths are viable. Use Fork-Join to evaluate trade-offs before presenting the recommendation to the user.

**Pattern**: Fork-Join — create parallel branches from a shared origin thought, analyze each path independently, then synthesize into a recommendation. No Figma tool calls — pure reasoning.

### JSON Examples

**Thought 1 — Frame the decision:**

```json
{
  "thought": "DECISION: Restructuring approach for '{root_name}'. Phase 1 findings: {health_score}/100 health, {deviation_count} total deviations across {category_count} categories. Evaluating Path A (in-place modification) vs Path B (reconstruction). Key decision factors: deviation density, structural depth, visual complexity, preservation requirements.",
  "thoughtNumber": 1,
  "totalThoughts": 6,
  "nextThoughtNeeded": true
}
```

**Thought 2 — Branch: Evaluate Path A:**

```json
{
  "thought": "PATH A EVALUATION (In-Place Modification):\nPROS: Preserves node IDs (external links survive), incremental changes are reviewable, lower risk of visual regression per step, familiar canvas position preserved.\nCONS: {missing_auto_layout} frames need conversion (risk of cascading layout shifts), {flat_hierarchy} flat containers require careful reparenting order (innermost-out), {hardcoded_colors} fills need individual binding.\nEFFORT: ~{path_a_tool_calls} tool calls across Phases 3A-4A.\nRISK: Visual fidelity degradation during structural changes (mitigated by blueprint comparison per step, max 3 fix cycles each).",
  "thoughtNumber": 2,
  "totalThoughts": 6,
  "branchFromThought": 1,
  "branchId": "path-a-eval",
  "nextThoughtNeeded": true
}
```

**Thought 3 — Branch: Evaluate Path B:**

```json
{
  "thought": "PATH B EVALUATION (Reconstruction):\nPROS: Clean slate with auto-layout from start, components built correctly from inception, naming applied during creation, no cascading layout risk.\nCONS: Higher total effort (~{path_b_tool_calls} tool calls in Phase 3B), original must be archived, new node IDs (external links break), requires full visual reproduction from blueprint.\nEFFORT: ~{path_b_tool_calls} tool calls in Phase 3B.\nRISK: Blueprint extraction may miss subtle visual properties — mitigated by section-by-section screenshot comparison.",
  "thoughtNumber": 3,
  "totalThoughts": 6,
  "branchFromThought": 1,
  "branchId": "path-b-eval",
  "nextThoughtNeeded": true
}
```

**Thought 4 — Synthesis (back to main trunk):**

```json
{
  "thought": "SYNTHESIS: Comparing branches.\nPath A preferred when: deviation density <30% of nodes, structural hierarchy is moderately deep (containers exist but need auto-layout), existing node IDs must be preserved.\nPath B preferred when: >50% of frames lack auto-layout, hierarchy is deeply flat (most children at root level), naming is chaotic, or the design has complex gradient/effect properties that would be disrupted by reparenting.\nFor '{root_name}': {specific_assessment}.\nRECOMMENDATION: Path {A_or_B}.",
  "thoughtNumber": 4,
  "totalThoughts": 6,
  "nextThoughtNeeded": true
}
```

**Thought 5 — Prepare Socratic questions:**

```json
{
  "thought": "SOCRATIC PREPARATION: Based on Path {recommended} recommendation, the key questions for Phase 2 are: (1) Confirm restructuring path preference. (2) {component_question_if_patterns_found}. (3) {naming_question_if_generic_names}. (4) {token_question_if_hardcoded_colors}. Filling Socratic question templates from recipes-restructuring.md with Phase 1 data.",
  "thoughtNumber": 5,
  "totalThoughts": 6,
  "nextThoughtNeeded": true
}
```

**Thought 6 — Finalize:**

```json
{
  "thought": "Plan complete. Presenting Phase 1 findings with Path {recommended} recommendation and Socratic questions to the user. Awaiting user decisions before proceeding to Phase 3.",
  "thoughtNumber": 6,
  "totalThoughts": 6,
  "nextThoughtNeeded": false
}
```

---

## Template: Visual Fidelity Loop

**When**: During Phase 3A/3B structural changes or Phase 5 polish, after each major modification that could affect visual output.

**Pattern**: TAO Loop with Revision — predict expected state, take screenshot, compare against blueprint. If mismatch, revise the assumption and plan a fix. Circuit breaker at cycle 3.

### JSON Examples (Single Cycle)

> **Positional placeholders**: `"thoughtNumber": "N"` and `"totalThoughts": "T"` below are positional markers — replace with actual integers at runtime (e.g., `"thoughtNumber": 3`). The actual values depend on where the fidelity check falls within the parent thought chain.

**Thought N — Predict expected state:**

```json
{
  "thought": "FIDELITY CHECK: After {change_description}, expecting visual output to match blueprint. Key expectations: (1) {element} at position ~({x}, {y}), (2) fill color {color}, (3) spacing {spacing}px between children. Taking screenshot to verify.",
  "thoughtNumber": "N",
  "totalThoughts": "T",
  "nextThoughtNeeded": true
}
```

> **Action**: `figma_take_screenshot` or `figma_capture_screenshot(nodeId)`

**Thought N+1 — Match confirmed:**

```json
{
  "thought": "FIDELITY CONFIRMED: Screenshot matches blueprint expectations. Position, colors, and spacing are correct within tolerance. Proceeding to next structural change.",
  "thoughtNumber": "N+1",
  "totalThoughts": "T",
  "nextThoughtNeeded": true
}
```

**Thought N+1 — Mismatch (REVISION):**

```json
{
  "thought": "FIDELITY VIOLATION: Screenshot shows {deviation_description}. Expected {expected} but observed {actual}. REVISING: the {change_type} operation caused {side_effect}. Root cause: {diagnosis}. Fix plan: {fix_steps}. This is fix cycle {cycle}/3.",
  "thoughtNumber": "N+1",
  "totalThoughts": "T",
  "isRevision": true,
  "revisesThought": "N",
  "nextThoughtNeeded": true
}
```

> **Action**: `figma_execute` (apply fix) + `figma_take_screenshot` (re-verify)

**Circuit Breaker — Cycle 3 exhausted:**

```json
{
  "thought": "CIRCUIT BREAKER: 3 fix cycles exhausted for {change_description}. Residual deviation: {remaining_issue}. Accepting current state and documenting deviation in Phase 5 fidelity report. Moving to next structural change.",
  "thoughtNumber": "N+2",
  "totalThoughts": "T",
  "nextThoughtNeeded": true
}
```

---

## Template: Naming Audit Reasoning

**When**: Code Handoff Protocol step 1 (Naming Audit) surfaces >5 issues, some of which may be false positives requiring case-by-case reasoning.

**Pattern**: TAO Loop — classify each flagged naming issue, apply fixes for genuine errors, document exceptions for acceptable deviations.

### JSON Examples

**Thought 1 — Frame the audit:**

```json
{
  "thought": "NAMING AUDIT: {total_components} components scanned, {issues_found} naming issues flagged. Categories: {non_pascal_count} non-PascalCase names, {uppercase_key_count} uppercase variant property keys. Known false positive patterns to check: abbreviations (CTA, FAQ, UI), size tokens (2XL, SM), M3 prefixes (M3Card). Classifying each flag systematically.",
  "thoughtNumber": 1,
  "totalThoughts": 5,
  "nextThoughtNeeded": true
}
```

**Thought 2 — Classify flags:**

```json
{
  "thought": "FLAG CLASSIFICATION:\nTRUE POSITIVES (rename): {list — e.g., 'product card' → 'ProductCard', 'Frame 42' → contextual name}\nFALSE POSITIVES (skip): {list — e.g., 'CTA' is an accepted abbreviation, 'M3TopAppBar' follows M3 convention}\nAMBIGUOUS (need context): {list — e.g., 'nav-link' might be kebab-case convention in this project}\nRenaming true positives to PascalCase. Adding exception descriptions for false positives.",
  "thoughtNumber": 2,
  "totalThoughts": 5,
  "nextThoughtNeeded": true
}
```

> **Action**: `figma_execute` (batch rename true positives)
> **Action**: `figma_set_description` (exception descriptions for false positives)

**Thought 3 — Handle ambiguous cases:**

```json
{
  "thought": "AMBIGUOUS RESOLUTION: For '{ambiguous_name}' — checking if the target codebase uses this naming convention. If the project follows kebab-case for navigation components, this name is correct and should get an exception description noting the convention. Otherwise, rename to PascalCase.",
  "thoughtNumber": 3,
  "totalThoughts": 5,
  "nextThoughtNeeded": true
}
```

**Thought 4 — Verify and summarize:**

```json
{
  "thought": "NAMING AUDIT COMPLETE: {fixed_count} components renamed to PascalCase, {exception_count} exception descriptions added (code name differs from Figma name), {skipped_count} false positives documented. Variant property keys: {key_fixes} lowercased. Proceeding to token alignment (step 4).",
  "thoughtNumber": 4,
  "totalThoughts": 5,
  "nextThoughtNeeded": true
}
```

> **Action**: `figma_audit_design_system` (verify naming score improved)

**Thought 5 — Final verification:**

```json
{
  "thought": "HEALTH CHECK: Naming score improved from {before} to {after}. All genuine naming issues resolved. Exception descriptions document {exception_count} intentional deviations. Naming audit complete.",
  "thoughtNumber": 5,
  "totalThoughts": 5,
  "nextThoughtNeeded": false
}
```

---

## Template: Iterative Refinement

**When**: Any screenshot-fix cycle during design creation (not specific to restructuring). Activated when the first screenshot after creation reveals issues.

**Pattern**: TAO Loop + Revision + Circuit Breaker. Identical structure to Visual Fidelity Loop but generalized — the comparison target is the user's intent rather than a blueprint snapshot.

### Thought Progression

```
Thought 1: State creation intent and acceptance criteria
→ Action: figma_execute or figma_render (create design)
Thought 2: Predict expected visual appearance
→ Action: figma_take_screenshot
Thought 3: Analyze screenshot against acceptance criteria
  ├── Match → nextThoughtNeeded: false (accept)
  └── Mismatch → isRevision: true, plan fix
→ Action: figma_execute (apply fix)
Thought 4: Re-verify after fix
→ Action: figma_take_screenshot
Thought 5: Final assessment (cycle 2/3 if needed, circuit breaker at 3)
```

### Key Differences from Visual Fidelity Loop

| Aspect | Visual Fidelity Loop | Iterative Refinement |
|--------|---------------------|---------------------|
| **Reference** | Blueprint snapshot (pixel-precise) | User intent (acceptance criteria) |
| **Tolerance** | Strict (>2px deviation = failure) | Flexible (visual quality judgment) |
| **Context** | Restructuring phases only | Any design creation |
| **Cycle limit** | Max 3 per structural change | Max 3 per creation step |

---

## Template: Design System Bootstrap Checkpoint

**When**: The Design System Bootstrap workflow (from `recipes-advanced.md`) crosses phase boundaries: Tokens → Components → Documentation.

**Pattern**: Checkpoint thoughts at each phase transition, verifying preconditions before proceeding.

### JSON Examples

**Thought 1 — Initialize bootstrap:**

```json
{
  "thought": "DESIGN SYSTEM BOOTSTRAP: Creating token system for '{project_name}'. Phase plan: (1) Create token collection with Light/Dark modes, (2) Batch create color + spacing variables, (3) Build reference components using tokens, (4) Document components, (5) Audit coverage. Starting with token collection creation.",
  "thoughtNumber": 1,
  "totalThoughts": 5,
  "nextThoughtNeeded": true
}
```

> **Action**: `figma_setup_design_tokens` or `figma_create_variable_collection` + `figma_batch_create_variables`

**Thought 2 — Token phase checkpoint:**

```json
{
  "thought": "TOKEN CHECKPOINT: Collection '{collection_name}' created with {mode_count} modes. {variable_count} variables created: {color_count} colors, {spacing_count} spacing, {other_count} other. Verifying precondition for component phase: all semantic colors (primary, on-primary, surface, on-surface, error) must exist. {verification_result}. Proceeding to component creation.",
  "thoughtNumber": 2,
  "totalThoughts": 5,
  "nextThoughtNeeded": true
}
```

**Thought 2 — Checkpoint with revision (missing tokens):**

```json
{
  "thought": "TOKEN CHECKPOINT: INCOMPLETE — missing semantic colors: {missing_list}. Cannot proceed to component phase without core tokens. REVISING plan: adding missing variables before continuing.",
  "thoughtNumber": 2,
  "totalThoughts": 5,
  "isRevision": true,
  "revisesThought": 1,
  "needsMoreThoughts": true,
  "nextThoughtNeeded": true
}
```

> `needsMoreThoughts`: signals the ST server to extend `totalThoughts` beyond the original estimate. Use when preconditions fail and additional recovery steps are needed before the chain can converge.

> **Action**: `figma_batch_create_variables` (create missing tokens)

**Thought 4 — Component phase checkpoint:**

```json
{
  "thought": "COMPONENT CHECKPOINT: {component_count} reference components created, all bound to token variables. Token binding coverage: {bound_pct}% of fills, {spacing_bound_pct}% of spacing values. Precondition for documentation: all components must have descriptions. Proceeding to documentation and audit.",
  "thoughtNumber": 4,
  "totalThoughts": 5,
  "nextThoughtNeeded": true
}
```

> **Action**: `figma_set_description` + `figma_audit_design_system`

**Thought 5 — Final audit:**

```json
{
  "thought": "BOOTSTRAP COMPLETE: Design system health score {health_score}/100. Token coverage: {token_coverage}. Component documentation: {doc_coverage}. Bootstrap workflow finished.",
  "thoughtNumber": 5,
  "totalThoughts": 5,
  "nextThoughtNeeded": false
}
```

---

## Template: Reflection Quality Assessment

**When**: Standard Reflect (R2) activated at a phase boundary and evaluation requires cross-referencing 3+ data sources (node tree + journal + audit). Also used by R3 coordinator when synthesizing 3 judge reports.

**Pattern**: TAO Loop — alternate `sequentialthinking` calls with Figma data gathering. Each thought evaluates one or two quality dimensions.

**Thought chain** (5-7 thoughts interleaved with data gathering):

```
Thought 1: Frame reflection scope → Action: Read journal, count ops by type
Thought 2: Evaluate D1 (Structural) + D4 (Naming) → Action: figma_get_file_for_plugin
Thought 3: Evaluate D2 (Token Binding) + D3 (Component Reuse) → Action: figma_execute (boundVariables + instance scan)
Thought 4: Evaluate D5 (Visual Fidelity) → Action: figma_audit_design_system
Thought 5: Evaluate D6 (Operational Efficiency) — journal analysis (no tool call)
Thought 6: CoV self-verification — 3-5 questions, adjust scores
Thought 7: Compute composite, issue list, verdict → nextThoughtNeeded: false
```

### JSON Examples

**Thought 1 — Frame reflection scope:**

```json
{
  "thought": "REFLECTION (R2): Phase {phase_number} complete. Evaluating quality across 6 dimensions. Session stats from journal: {total_ops} operations, {screen_count} screens processed, {batch_count} batch scripts, {fix_cycles} fix cycles used. Gathering structural data for D1/D4 assessment.",
  "thoughtNumber": 1,
  "totalThoughts": 7,
  "nextThoughtNeeded": true
}
```

> **Action**: Read `operation-journal.jsonl`, compute operation statistics

**Thought 2 — Structural + Naming assessment:**

```json
{
  "thought": "D1 STRUCTURAL: {auto_layout_pct}% auto-layout coverage, {group_count} residual GROUPs, max nesting depth {max_depth}. D4 NAMING: {generic_count} generic names out of {total_nodes} nodes ({naming_pct}% semantic). Slash-convention compliance: {slash_pct}%. Scoring D1={d1_score}, D4={d4_score}.",
  "thoughtNumber": 2,
  "totalThoughts": 7,
  "nextThoughtNeeded": true
}
```

> **Action**: `figma_get_file_for_plugin` node tree analysis

**Thought 3 — Token Binding + Component Reuse:**

```json
{
  "thought": "D2 TOKEN BINDING: {bound_count}/{total_fills} fills bound ({binding_pct}%). {hardcoded_semantic} hardcoded semantic colors. D3 COMPONENT REUSE: {instance_count} library instances placed. {custom_duplicates} custom elements matching library patterns. {recurring_uncomponentized} recurring patterns (3+) not componentized. Scoring D2={d2_score}, D3={d3_score}.",
  "thoughtNumber": 3,
  "totalThoughts": 7,
  "nextThoughtNeeded": true
}
```

> **Action**: `figma_execute` — scan `boundVariables` and instance types

**Thought 4 — Visual Fidelity:**

```json
{
  "thought": "D5 VISUAL FIDELITY: Health score {health_score}/100 from figma_audit_design_system. Grid compliance: {grid_issues} non-4px values. Alignment: {alignment_issues} deviations. Fix cycles used: {fix_count} (avg {avg_per_screen}/screen). Scoring D5={d5_score}.",
  "thoughtNumber": 4,
  "totalThoughts": 7,
  "nextThoughtNeeded": true
}
```

> **Action**: `figma_audit_design_system`

**Thought 5 — Operational Efficiency (journal-only):**

```json
{
  "thought": "D6 OPERATIONAL EFFICIENCY: batch_ratio={batch_ratio} ({batch_ops} batched / {total_batchable} batchable). native_tools_first={native_ratio} ({native_uses} native / {total_native_eligible} eligible). convergence_compliance={conv_ratio}. redundant_ops={redundant_count}. Scoring D6={d6_score}.",
  "thoughtNumber": 5,
  "totalThoughts": 7,
  "nextThoughtNeeded": true
}
```

**Thought 6 — Chain of Verification:**

```json
{
  "thought": "CoV SELF-VERIFICATION: Q1: Did I check all screens or only a sample for D1? A: {answer}. Q2: Is low D2 justified by absence of token system? A: {answer}. Q3: Are D6 individual calls justified debugging fallbacks? A: {answer}. Adjustments: {adjustments_or_none}.",
  "thoughtNumber": 6,
  "totalThoughts": 7,
  "nextThoughtNeeded": true
}
```

**Thought 7 — Verdict:**

```json
{
  "thought": "REFLECTION VERDICT: Composite={composite} (D1:{d1}*0.25 + D2:{d2}*0.15 + D3:{d3}*0.15 + D4:{d4}*0.15 + D5:{d5}*0.15 + D6:{d6}*0.15). Verdict: {pass|conditional_pass|fail}. Issues: {issue_list}. {fix_plan_if_needed}. Logging to journal.",
  "thoughtNumber": 7,
  "totalThoughts": 7,
  "nextThoughtNeeded": false
}
```

**If conditional_pass/fail — extend with fix planning:**

```json
{
  "thought": "FIX PLAN: Lowest dimensions: {dim_name}={score}. Targeted fixes: {fix_list}. Executing fix iteration 1/{max_iterations}.",
  "thoughtNumber": 7,
  "totalThoughts": 9,
  "needsMoreThoughts": true,
  "nextThoughtNeeded": true
}
```

---

## Session Protocol Mapping

The 4-phase Session Protocol maps to ST activation as follows:

| Session Phase | ST Activation | Rationale |
|---------------|---------------|-----------|
| **Phase 1 — Preflight** | No ST | Deterministic checks, <3 steps, no decisions |
| **Phase 2 — Discovery** | ST if findings require cross-referencing across 3+ tools | Multiple discovery tools producing data that must be synthesized |
| **Phase 3 — Creation** | ST for complex compositions (Shell Injection, multi-call recipes). Skip for single `figma_execute` | Multi-call chains benefit from hypothesis tracking between calls |
| **Phase 4 — Validation** | ST TAO Loop for screenshot-fix cycles. Always use Revision when fix does not match expectation. ST for R2+ reflection when cross-referencing 3+ data sources | Prevents reflexive responses to unexpected screenshot results. Reflection benefits from structured data gathering across node tree, journal, and audit |

### Alternative Session Protocols

| Session Type | ST Activation |
|--------------|---------------|
| **Quick Audit** | ST if deviations span 3+ categories; skip for <3 deviations |
| **Design Restructuring** | ST for Phase 1 analysis (3+ categories), Phase 2 path decision (Fork-Join), Phase 3 fidelity loops |
| **Code Handoff** | ST for naming audit with >5 ambiguous flags |

---

## Integration Rules Summary

These rules apply whenever ST is activated within a figma-console-mastery workflow:

1. **TAO Loop**: Alternate `sequentialthinking` calls with Figma tool calls — never batch all thinking before all actions
2. **Checkpoint at phase boundary**: Before transitioning between phases, emit a checkpoint thought summarizing findings
3. **Revision on contradiction**: When `figma_take_screenshot` reveals a result contradicting the previous thought, use `isRevision: true`
4. **Circuit breaker**: If a thought chain exceeds 15 steps within a single phase, checkpoint and request user guidance
5. **Max 3 fix cycles**: The existing max-3-screenshot-fix-cycles rule supersedes ST's dynamic horizon — never extend fix loops beyond 3 using `needsMoreThoughts`
6. **Evidence-based progression**: Each thought must generate a new hypothesis, eliminate one, or revise a previous conclusion. No rubber-stamp thoughts ("Step 2: Thinking...")

---

## Cross-Skill Reference

For advanced ST mechanics (branching semantics, revision edge cases, dynamic horizon management), load from the sibling skill:

```
# Optional — for advanced branching and revision patterns
Read: $CLAUDE_PLUGIN_ROOT/skills/sequential-thinking-mastery/references/branching-revision.md
```
