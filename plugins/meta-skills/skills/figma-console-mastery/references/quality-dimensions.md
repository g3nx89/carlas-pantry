# Quality Dimensions

> Consolidated quality dimensions, scoring rubrics, composite scoring, depth tiers, and contradiction resolutions.
> Part of the Unified Quality Model for figma-console design validation.
> Version: 1.0.0

**Load when**: Flow 1 Phase 4, Flow 2 Phases 2-4, any quality audit dispatch

**Related files**: This file is part of a 3-file split:
- **quality-dimensions.md** (this file) — 10 dimensions, rubrics, composite scoring, depth tiers, contradiction resolutions
- **quality-audit-scripts.md** — JavaScript audit scripts A-F, diff templates, positional analysis
- **quality-procedures.md** — Spot/Standard/Deep audit procedures, fix cycles, judge templates

---

## 1. 10 Unified Dimensions

All Figma design quality is evaluated across these 10 dimensions. Each scores 0-10.

| Cat. | # | Dimension | Notes |
|------|---|-----------|-------|
| **Visual** | D1 | Visual Quality | Screenshot + positional diff. Thresholds: 3px Minor / 8px Major |
| **Structural** | D2 | Layer Structure | Hierarchy, nesting max 6, no GROUP wrapper, no orphaned siblings |
| | D3 | Semantic Naming | Audit against **naming rules** (single source of truth). Meaningful nomenclature (role-based, not visual-description). No generic ("Frame N"). Cross-screen consistency check |
| | D4 | Auto-Layout | 6 automated checks A-F (script-only, no manual findings). Screen root on fixed viewport exempt |
| | D5 | Component Compliance | 3-layer: instance-to-DS, expected components (ID-authoritative), no spurious raw frames |
| | D6 | Constraints & Position | Per-type constraint rules. Per-element position analysis: verify each element uses appropriate positioning (absolute/auto-layout/anchored). Different rules for fixed viewport vs scrollable |
| | D7 | Screen Properties | Root=FRAME, cornerRadius, clipsContent, dimensions. Scrollability: structure consistent with scroll/non-scroll intent |
| | D8 | Instance Integrity | Override correctness via `.characters`, no residual placeholder text |
| **Design System** | D9 | Token Binding | % fills/strokes/effects/spacing bound to variables. Flag magic numbers not confirmed by user |
| **Process** | D10 | Operational Efficiency | Batch ratio, convergence compliance, native-tools-first |

---

## 2. Dimension Scoring Rubrics

### D1 — Visual Quality

**Data sources**: `figma_capture_screenshot` (post-mutation) or `figma_take_screenshot` (baseline), positional diff script

| Score | Criteria |
|-------|----------|
| 10 | Visual match to intent within 2px. All spacing on 4px grid. Zero positional deltas >3px |
| 8-9 | Minor spacing deviations (<4px). Positional deltas 3-8px on 1-2 non-critical elements |
| 6-7 | Noticeable spacing issues (4-8px). Some positional deltas >8px but alignment correct |
| 4-5 | Significant visual deviations (>8px). Multiple Major positional deltas. Misalignment visible |
| 0-3 | Major regression. Elements mispositioned >16px or missing. Visual fidelity broken |

**Issue severity:**
- **Critical**: Missing content, wrong copy, broken visual hierarchy
- **Major**: Positional delta >8px, spacing deviation >8px, color mismatch, typography deviation
- **Minor**: Positional delta 3-8px, spacing deviation 3-8px

**figma-console tools**: `figma_capture_screenshot`, `figma_take_screenshot`, positional diff script (quality-audit-scripts.md Script B)

---

### D2 — Layer Structure

**Data sources**: `figma_get_file_for_plugin`, parent context check script

| Score | Criteria |
|-------|----------|
| 10 | Screen is direct child of SECTION/PAGE. Zero orphaned siblings. Nesting depth max 6. Zero residual GROUPs |
| 8-9 | Nesting depth max 6. 1 non-critical orphaned sibling or 1 GROUP with valid semantic reason |
| 6-7 | Nesting depth 7-8. 2-3 orphaned siblings. 1-2 GROUPs with layout role (should be FRAME) |
| 4-5 | Nesting depth >8. Multiple orphaned siblings. Multiple GROUPs with layout responsibilities |
| 0-3 | Screen wrapped in GROUP. Nesting depth >10. Heavy GROUP usage. Broken hierarchy |

**Issue severity:**
- **Critical**: Screen wrapped in GROUP (parent.type === 'GROUP')
- **Major**: Orphaned siblings (parent has other direct children), nesting depth >8
- **Minor**: Nesting depth 7-8, residual GROUP with no layout role (semantic grouping only)

**figma-console tools**: `figma_get_file_for_plugin`, `figma_execute` (parent context check in quality-audit-scripts.md Script A)

---

### D3 — Semantic Naming

**Data sources**: Node tree name analysis from `figma_get_file_for_plugin`

| Score | Criteria |
|-------|----------|
| 10 | All layers use semantic slash-convention names. Zero generic. Logical hierarchy. PascalCase components. Cross-screen naming consistency |
| 8-9 | 95%+ named. 1-2 generic in deep children. Mostly consistent cross-screen |
| 6-7 | 80-94% named. Some generic in visible sections. Partial cross-screen consistency |
| 4-5 | 60-79% named. Generic names in primary surfaces. Inconsistent cross-screen |
| 0-3 | <60% named. "Frame 42", "Group 1" throughout. No naming convention |

**Generic name patterns** (auto-detect): `Frame \d+`, `Group \d+`, `Rectangle \d+`, `Vector \d+`, `Ellipse \d+`

**Issue severity:**
- **Critical**: None (naming is never Critical)
- **Major**: Generic names in primary surfaces (top 2 hierarchy levels), inconsistent component naming
- **Minor**: Generic names in deep children (level 3+), missing slash-convention

**figma-console tools**: `figma_get_file_for_plugin`

---

### D4 — Auto-Layout

**Data sources**: Auto-layout inspection script (6 automated checks A-F)

| Score | Criteria |
|-------|----------|
| 10 | Zero issues from automated checks A-F |
| 8-9 | 1-2 Minor issues (Check C/D/E/F) |
| 6-7 | 3-4 Minor issues or 1 Major issue (Check A/B) |
| 4-5 | Multiple Major issues or 5+ Minor issues |
| 0-3 | Pervasive auto-layout misuse. 3+ Major issues |

**Issue severity:**
- **Critical**: None (auto-layout is never Critical)
- **Major**: Check A (repeated component family without container), Check B (3+ stacked/aligned children without auto-layout)
- **Minor**: Check C (spacer frames), Check D (hardcoded width ~ parent inner width), Check E (absolute positioning in auto-layout), Check F (implicit padding)

**IMPORTANT — script-only rule**: Report ONLY issues detected by the 6 automated checks. Do NOT add manual findings like "root frame should have auto-layout" unless Check B fires. The screen root frame on fixed-size mobile screens is a **stage**, not a layout container.

**figma-console tools**: `figma_execute` (auto-layout inspection script in quality-audit-scripts.md Script F)

---

### D5 — Component Compliance

**Data sources**: `figma_search_components`, `figma_execute` (instance enumeration + mainComponent resolution)

| Score | Criteria |
|-------|----------|
| 10 | All expected components present (ID match). Zero raw frames where components exist. All instances map to DS registry or remote libraries |
| 8-9 | All expected components present. 1 raw frame where DS component available |
| 6-7 | 1 expected component missing (non-critical) OR 2-3 raw frames where DS components available |
| 4-5 | 2+ expected components missing OR multiple instances reference wrong mainComponent IDs |
| 0-3 | Expected component missing in critical screen section. Heavy raw frame usage where components exist |

**Issue severity:**
- **Critical**: Expected component missing (ID mismatch or zero instances), instance references wrong mainComponent ID for expected component
- **Major**: Raw frame where DS component should be used (name + child structure match)
- **Minor**: Instance from local copy instead of library (when library version available)

**3-layer check:**
- **Layer A**: Every INSTANCE mainComponent ID in DS registry or `mcRemote=true`
- **Layer B**: Every `{{EXPECTED_COMPONENTS}}` ID has ≥1 matching instance (ID-authoritative)
- **Layer C**: No raw FRAMEs with name/child structure matching DS components

**figma-console tools**: `figma_search_components`, `figma_execute` (instance inspection + mainComponent resolution)

---

### D6 — Constraints & Position

**Data sources**: `figma_execute` (constraints inspection), per-element position analysis

| Score | Criteria |
|-------|----------|
| 10 | All elements use appropriate positioning. Correct per-type constraints. No MIN+MIN on full-width or centered elements |
| 8-9 | 1-2 elements with suboptimal positioning (works but not ideal). Constraints mostly correct |
| 6-7 | 3-4 elements with incorrect positioning or constraints. Full-width elements on MIN+MIN |
| 4-5 | Multiple constraint misconfigurations. Bottom-anchored elements not on MAX vertical |
| 0-3 | Pervasive constraint failures. Elements not positioned appropriately for screen type |

**Per-type constraint rules:**
- Bottom-anchored elements: `vertical = MAX` (Bottom)
- Horizontally centered elements: `horizontal = CENTER`
- Full-width elements: `horizontal = STRETCH` or `LEFT_RIGHT`
- Default `MIN+MIN` (Top+Left) only acceptable for top-left anchored elements

**Per-element position analysis:**
- Fixed viewport: absolute positioning acceptable for overlays/badges, auto-layout for content flow
- Scrollable screens: auto-layout required for main content (vertical stack), absolute only for pinned elements

**Issue severity:**
- **Critical**: None (constraints rarely Critical unless blocking functionality)
- **Major**: Full-width element on MIN+MIN, bottom-anchored element not on MAX, scrollable screen content on absolute positioning
- **Minor**: Centered element not on CENTER horizontal, suboptimal positioning (works but not maintainable)

**figma-console tools**: `figma_execute` (constraints inspection)

---

### D7 — Screen Properties

**Data sources**: `figma_execute` (root node inspection)

| Score | Criteria |
|-------|----------|
| 10 | Root=FRAME, cornerRadius=32, clipsContent=true, dimensions match target. Scrollability structure correct |
| 8-9 | 1 property deviation (e.g., cornerRadius=24 instead of 32). Scrollability correct |
| 6-7 | 2 property deviations. Scrollability structure partially inconsistent with intent |
| 4-5 | 3 property deviations. Scrollability structure incorrect (MIN+MIN on scrollable) |
| 0-3 | Root not FRAME (e.g., GROUP, COMPONENT). Multiple property failures |

**Screen property checklist:**
- Root type = `FRAME` (not GROUP, COMPONENT, etc.)
- `cornerRadius = 32` (default mobile; adjust per project)
- `clipsContent = true`
- Width = target viewport width (default 360px)
- Height = viewport height (fixed) OR content height (scrollable)

**Scrollability structure:**
- **Scrollable screens**: constraints `MIN+MIN` everywhere (content flows top-down)
- **Fixed viewport screens**: per-type constraints (D6), root frame is stage

**Issue severity:**
- **Critical**: Root not FRAME
- **Major**: Wrong root type (GROUP instead of FRAME), scrollability structure inconsistent with intent
- **Minor**: cornerRadius or clipsContent deviation, dimension mismatch <10px

**figma-console tools**: `figma_execute` (root node inspection)

---

### D8 — Instance Integrity

**Data sources**: `figma_execute` (`.characters` read on TEXT nodes inside INSTANCEs)

| Score | Criteria |
|-------|----------|
| 10 | All instance text overrides correct. Zero residual placeholder text |
| 8-9 | 1 instance with incorrect override (non-critical content) |
| 6-7 | 2-3 instances with incorrect overrides or 1 instance with critical placeholder text |
| 4-5 | Multiple instances with residual placeholder text. Overrides mismatched vs intent |
| 0-3 | Expected copy missing. Placeholder text in primary surfaces. Overrides not applied |

**Residual placeholder patterns** (auto-detect): `Title text here`, `Body text here`, `Label`, `Placeholder`, `Lorem ipsum`

**Issue severity:**
- **Critical**: Expected copy missing, placeholder text in critical screen section (title, CTA)
- **Major**: Placeholder text in secondary surfaces (body, labels)
- **Minor**: Override correct but formatting inconsistent (e.g., capitalization)

**figma-console tools**: `figma_execute` (`.characters` read). NEVER rely on screenshots alone — REST API screenshots show stale component defaults, not live overrides.

---

### D9 — Token Binding

**Data sources**: `figma_execute` (`boundVariables` inspection)

| Score | Criteria |
|-------|----------|
| 10 | 95%+ fills bound to variables. Spacing from tokens. Zero hardcoded semantic colors |
| 8-9 | 85-94% bound. Few hardcoded values in non-critical locations |
| 6-7 | 70-84% bound. Hardcoded in secondary surfaces |
| 4-5 | 50-69% bound. Hardcoded in primary surfaces despite token system available |
| 0-3 | <50% bound, or no token system when one was available |

**Binding targets:**
- Fills: `boundVariables.fills` set on nodes with semantic colors
- Strokes: `boundVariables.strokes` set
- Effects: `boundVariables.effects` set (shadows, blurs)
- Spacing: auto-layout `itemSpacing` from tokens (check via variable name match)

**Issue severity:**
- **Critical**: None (token binding rarely Critical)
- **Major**: Hardcoded semantic colors in primary surfaces (backgrounds, primary text), 0% binding when token system available
- **Minor**: Hardcoded spacing, hardcoded colors in secondary surfaces, <85% binding

**Magic number rule**: Flag hardcoded values that appear 3+ times across screens — likely candidates for tokenization. Report to user for confirmation before marking as issue.

**figma-console tools**: `figma_execute` (`boundVariables` inspection)

---

### D10 — Operational Efficiency

**Data sources**: `operation-journal.jsonl` analysis

| Score | Criteria |
|-------|----------|
| 10 | All 3+ same-type ops batched. Native tools used. Zero redundant calls. Convergence checks before mutations. Journal current |
| 8-9 | Most batching taken. 1-2 missed native-tool-first opportunities |
| 6-7 | Partial batching. Some individual calls where batching available |
| 4-5 | Minimal batching. Multiple individual same-type calls. Missing convergence checks |
| 0-3 | No batching. Redundant calls. No convergence checks |

**Metrics:**
- `batch_ratio = batch_ops / (batch_ops + individual_same_type_ops)`
- `native_tools_first = native_tool_uses / (native_tool_uses + figma_execute_for_native_ops)`
- `convergence_compliance = convergence_check_ops / total_mutating_ops`
- `redundant_ops = count of ops targeting same node+property with same value`

**Issue severity:**
- **Critical**: None (efficiency never Critical)
- **Major**: None (efficiency never Major)
- **Minor**: Batch ratio <0.7, native-tools-first <0.8, convergence compliance <0.9, redundant ops >3

**figma-console tools**: Read `operation-journal.jsonl`

---

## 3. Composite Scoring

**Formula**: Simple average (equal weight per dimension)

```
composite = (D1 + D2 + D3 + D4 + D5 + D6 + D7 + D8 + D9 + D10) / 10
```

| Composite | Verdict | Action |
|-----------|---------|--------|
| >= 8.0 | **Pass** | Quality gate cleared, proceed |
| 6.0-7.9 | **Conditional Pass** | Flag dimensions <7.0 for targeted improvement; proceed with caveats |
| < 6.0 | **Fail** | Mandatory fix cycle on lowest-scoring dimensions (max 2 iterations per phase, max 3 per screen) |

**Pass threshold**: Composite >= 8.0 AND no Critical/Major issues remaining

---

## 4. Depth Tiers

Three tiers match audit depth to operation significance.

| Tier | When | Dimensions | Who executes | Token Budget |
|------|------|-----------|-------------|--------|
| **Spot** | After each screen modification, single ops | D1, D4, D10 | Inline (exception to subagent-first rule) | ~1K |
| **Standard** | Phase boundary, per-screen in Flow 2 | All 10 | Sonnet subagent | ~4K |
| **Deep** | Session end, Flow 2 final gate | All 10 + 3 judges + debate | 3 parallel Sonnet subagents | ~12K |

### Triage Decision Matrix

```
Has the session involved >0 mutating operations?
  No  -> Skip (no audit)
  Yes ->
    Was this a single-node operation (rename, fill, move)?
      Yes -> Skip (no audit)
    Was this a per-screen pipeline completion?
      Yes -> Spot (D1, D4, D10 only)
    Was this a phase boundary?
      Yes -> Standard (all 10 dimensions)
    Was this session completion (all phases)?
      Yes -> Deep (3 judges + debate)
    Was this user-triggered?
      "audit" keyword -> Standard
      "critique" keyword -> Deep
```

### Suppress Conditions

Skip audit even when tier triggers are met if:
- Session total token usage already exceeds 150K (context conservation)
- User explicitly requests fast-track execution
- Phase produced zero mutations (analysis-only)

---

## 5. Contradiction Resolutions

This unified model resolves 10 contradictions between reflection-protocol.md (R0-R3 tiers) and visual-qa-protocol.md (8-dimension audit).

| # | Contradiction | Resolution |
|---|--------------|------------|
| 1 | **Screen root auto-layout**: Reflection penalized no auto-layout on root. VQA exempted fixed-viewport roots. | **VQA wins**: Root on fixed viewport is "stage", exempt from auto-layout. Script F Check B will never fire on screen root (by design). |
| 2 | **Auto-layout subjective vs script-only**: Reflection allowed manual judgment. VQA enforced script-only. | **VQA wins**: D4 (Auto-Layout) reports ONLY issues from 6 automated checks A-F. No manual findings. Eliminates subjectivity. |
| 3 | **Fix iterations 2 vs 3**: Reflection allowed max 2 per phase. VQA allowed max 3 per screen. | **Unified**: Max 3 per screen (per-screen fix cycles), max 2 per phase boundary (Standard Audit). Deep Critique (session-end) has no automatic fix cycle (advisory only). |
| 4 | **Missing component severity**: Reflection treated as Major. VQA treated as Critical. | **VQA wins**: Expected component missing (ID mismatch or zero instances) = Critical. Breaks design system contract. |
| 5 | **Positional thresholds**: Reflection used 2px/8px. VQA used 3px/8px. | **VQA wins**: 3px Minor / 8px Major. Tunable per project (tighter for pixel-perfect, looser for prototypes). |
| 6 | **Scoring scale**: Reflection used 0-100. VQA used 0-10. | **Unified**: 0-10 per dimension (simpler, aligns with industry norms). Composite = average (no weights). |
| 7 | **Weights vs equal**: Reflection used weighted (D1=0.25, others 0.15). VQA implied equal. | **Drop weights**: 3 structural dimensions (D2, D3, D4) + 2 component dimensions (D5, D8) = 5/10 = 50% natural structural emphasis. Equal weights simpler and adequate. |
| 8 | **Inline vs subagent**: Reflection ran R1 inline. VQA enforced subagent-first. | **Unified**: Spot check runs inline (exception to subagent-first rule). Standard/Deep always dispatch subagents. Spot is lightweight enough (~1K tokens) to justify inline execution. |
| 9 | **3 judges vs single audit**: Reflection used 3 judges at session-end. VQA used single audit per screen. | **Coexist**: 3 judges only for Deep tier (session-end). Single audit for Standard tier (phase boundary, per-screen). Spot tier (inline) audits 3 dimensions only. |
| 10 | **Screenshot tool**: Reflection didn't specify. VQA specified capture vs take. | **VQA wins (clarification)**: `figma_capture_screenshot` for post-mutation validation (Desktop Bridge, live state). `figma_take_screenshot` for saved/baseline designs (REST API). Not a contradiction, just missing guidance in Reflection. |

---

## Cross-References

- **quality-audit-scripts.md** — JavaScript audit scripts A-F, positional diff script, per-element position analysis, scrollability check
- **quality-procedures.md** — Spot/Standard/Deep audit procedures, fix cycles, judge templates, journal integration, compound learning integration
- **Convergence Protocol** (journal schema, subagent prompt template, batch operations): `convergence-protocol.md`
- **Compound Learning** (save triggers T1-T6, cross-session persistence): `compound-learning.md`
- **Anti-patterns** (known errors to distinguish from quality gaps): `anti-patterns.md`
- **Design Rules** (MUST/SHOULD/AVOID — referenced by all judges): `design-rules.md`
- **Plugin API** (figma_execute patterns used in audit scripts): `plugin-api.md`
- **Field Learnings** (production strategies): `field-learnings.md`
- **Component Recipes** (fixes for component issues): `recipes-components.md`
- **SKILL.md** (Phase 4 protocol, MUST/AVOID rules): `SKILL.md`

---

## Maintenance Notes

### Adding a New Dimension

When adding dimension D11 (or modifying existing dimensions), update:

- [ ] **Section 1 table** — add dimension row with category, notes
- [ ] **Section 2 rubric** — add 5-tier scoring rubric (0-3, 4-5, 6-7, 8-9, 10)
- [ ] **Section 3 composite** — update formula (still simple average)
- [ ] **quality-procedures.md Section 2 (Standard) or Section 3 (Deep)** — add data gathering for new dimension
- [ ] **quality-procedures.md Section 4 (Handoff Audit Template)** — add dimension to audit procedure
- [ ] **quality-procedures.md Section 7 (Judge templates)** — assign to existing judge or create new judge
- [ ] **quality-procedures.md Section 7 variable table** — add any new variables the dimension needs
- [ ] **quality-procedures.md Section 9 (Journal)** — new dimension appears in `scores` object
- [ ] **quality-procedures.md Section 10 (Compound Learning)** — new dimension eligible for T6 systematic gap detection
- [ ] **references/README.md** — update file description line count and content summary

### Tuning Thresholds

When adjusting positional/spacing thresholds per project:

- [ ] Update D1 rubric (Section 2) with new thresholds
- [ ] Update quality-audit-scripts.md Script B with new threshold values
- [ ] Document threshold rationale in project-specific config or notes
- [ ] Update quality-procedures.md Handoff Audit Template threshold note
