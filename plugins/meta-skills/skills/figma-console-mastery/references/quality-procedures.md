# Quality Procedures

> Spot/Standard/Deep audit execution procedures, fix cycles, judge templates, journal integration, and compound learning.
> Part of the Unified Quality Model for figma-console design validation.
> Version: 1.0.0

**Load when**: Any quality audit trigger (Spot inline, Standard/Deep subagent dispatch)

**Related files**: This file is part of a 3-file split:
- **quality-dimensions.md** — 11 dimensions, rubrics, composite scoring, depth tiers, contradiction resolutions
- **quality-audit-scripts.md** — JavaScript audit scripts A-I, diff templates, positional analysis
- **quality-procedures.md** (this file) — Spot/Standard/Deep audit procedures, fix cycles, 3+1 judge templates

---

## 1. Spot Check Procedure (Inline)

**When**: After each screen modification within per-screen subagents. Runs inline (exception to subagent-first rule).

**Dimensions**: D1 (Visual Quality), D4 (Auto-Layout — script only), D10 (Operational Efficiency)

**Procedure**:

```
1. Gather data (most already available from screen pipeline):
   - D1: figma_capture_screenshot (post-mutation), compare to baseline if available
   - D4: Auto-layout inspection script (quality-audit-scripts.md Script F) — report issues from checks A-F only
   - D10: Journal entries for this screen — batch ratio, any redundant calls

2. Score each dimension (0-10) per rubric (quality-dimensions.md Section 2)

3. Quick verdict:
   - All 3 >= 7.0 → pass (log and proceed)
   - Any dimension < 7.0 → flag with specific issue
   - Any dimension < 5.0 → targeted fix before declaring screen_complete

4. Log to journal (op: "quality_audit", tier: "spot")
```

**Token budget**: ~1K — no additional Figma tool calls beyond what the screen pipeline already executed.

---

## 2. Standard Audit Procedure (Sonnet Subagent)

**When**: At phase boundaries or per-screen in Flow 2.

**Dimensions**: All 11 (excluding N/A per `quality-dimensions.md` Section 3).

**Dispatch**: `Task(subagent_type="general-purpose", model="sonnet")` with Handoff Audit Template (Section 4).

**Procedure**:

```
1. Dispatch Audit Subagent (Sonnet) with Handoff Audit Template
   - Input: fileKey, nodeId, screen name, draft reference (if available), expected components
   - Subagent runs all structural scripts, captures screenshots, scores all 11 dimensions (excl. N/A)
   - Returns: structured audit report with scores, issues, severity, node IDs

2. Evaluate pass threshold:
   - Composite >= 8.0 AND no Critical/Major → PASS
   - Composite < 8.0 OR any Critical/Major → NEEDS WORK

3. If NEEDS WORK:
   - Enter Fix Cycle (Section 5)
   - Max 2 iterations per phase boundary, max 3 per screen

4. Log to journal (op: "quality_audit", tier: "standard", all 10 scores + composite)
```

**Token budget**: ~5K per screen — includes structural scripts, accessibility check (Script G), copy quality check (Script H), screenshot, analysis.

---

## 3. Deep Critique Procedure (3 Figma-Domain Judges + 1 UX Critic + Debate)

**When**: Session completion (all phases done) or user-triggered with "critique" keyword. Runs exactly once per session.

**Pattern**: Multi-Agent Debate with 3 Figma-domain judges + 1 UX Critic judge dispatched in parallel, followed by coordinator synthesis.

### Judge Dispatch

All judges are `Task(subagent_type="general-purpose", model="sonnet")` with prompts from Section 7.

**Judge 1: Visual Fidelity Expert**
- Evaluates: D1 (Visual Quality), D6 (Constraints & Position), D7 (Screen Properties)
- Data sources: screenshots, positional diff, constraints inspection

**Judge 2: Structural & Component Expert**
- Evaluates: D2 (Layer Structure), D3 (Semantic Naming), D4 (Auto-Layout), D5 (Component Compliance), D8 (Instance Integrity), D11 (Accessibility Compliance)
- Data sources: node tree, auto-layout scripts, component registry, instance inspection, Script G

**Judge 3: Design System & Token Expert**
- Evaluates: D9 (Token Binding), D10 (Operational Efficiency)
- Data sources: `boundVariables` inspection, journal analysis

**Judge 4: UX Design Critic** (advisory, no score)
- Evaluates: Visual Hierarchy, Usability, Consistency, First Impression (qualitative only)
- Data sources: screenshots (screenshot-based analysis)
- Produces findings and suggestions but does NOT contribute to composite score

### Coordinator Synthesis

After all 4 judges return:

```
1. Collect all 11 dimension scores from Judges 1-3
2. Compute composite score (dynamic denominator, excluding N/A)
3. Identify areas of agreement (all scoring judges flag same concern)
4. Identify contradictions (>2pt spread on any dimension between judges)
5. If contradictions exist:
   - Determine which judge has stronger evidence (node IDs, journal entries, screenshots)
   - Run mini-debate: present both judge findings to a 5th Sonnet subagent, ask for arbitration
   - Accept arbitrator's ruling
5.5. Incorporate Judge 4 UX Critique findings as advisory section in consensus report.
   Flag contradictions between Judge 4 findings and Judge 1 (visual fidelity).
   Do NOT include Judge 4 findings in composite score.
6. Produce consensus verdict (pass / conditional_pass / fail)
7. Generate prioritized action items:
   - Must Do: dimensions < 5.0
   - Should Do: dimensions 5.0-6.9
   - Could Do: dimensions 7.0-7.9
   - UX Advisory: Judge 4 top 3 improvements (informational, not blocking)
8. Log to journal (op: "quality_audit", tier: "deep", all scores, judges, consensus, ux_critique)
```

**Token budget**: ~18K total — 3 scoring judges (~3K each) + Judge 4 (~3K) + synthesis (~6K).

---

## 4. Handoff Audit Template (Single Screen, All 11 Dimensions)

Use for Standard Audit (phase boundary, per-screen Flow 2). Dispatch as `Task(subagent_type="general-purpose", model="sonnet")`.

### Placeholders Reference

| Placeholder | Description | Example |
|---|---|---|
| `{{FILE_KEY}}` | Figma file key | `ygStDl4bV47BLbbPrQhLo0` |
| `{{NODE_ID}}` | Handoff screen node ID | `157:1296` |
| `{{SCREEN_NAME}}` | Human-readable screen name | `ONB-01 — Welcome` |
| `{{DRAFT_NODE_ID}}` | Draft reference node ID (optional) | `24:3558` |
| `{{COMPONENTS_SECTION_ID}}` | Node ID of the Components section/frame | `139:2121` |
| `{{EXPECTED_COMPONENTS}}` | Comma-separated `name:componentId` pairs required on this screen. ID match is authoritative — name is for readability only | `SwipeGestureIcon:157:1092, TitleBodyGroup:157:539` |
| `{{VIEWPORT_WIDTH}}` | Target device viewport width (default: 360px) | `360` |
| `{{VIEWPORT_HEIGHT}}` | Target device viewport height (default: 871px) | `871` |

### Pre-Audit Verification

**IMPORTANT**: Before setting `{{EXPECTED_COMPONENTS}}`, always run Script C (DS registry enumeration, quality-audit-scripts.md Section 3) first. Cross-check each expected `componentId` against the registry output. If an expected ID is not in the registry: (a) search by name to find actual current ID, (b) update session-state metadata, (c) use corrected ID. Never blindly copy IDs from session-state without verification — stale IDs produce Critical false positives.

### Prompt Template

Replace `{{PLACEHOLDERS}}` before dispatching.

```
You are a Figma design quality auditor. Perform a comprehensive audit of a single screen
covering all 11 quality dimensions. For baseline screenshots of saved screens, use
figma_take_screenshot. After any figma_execute mutations in this session, use
figma_capture_screenshot (live state) instead. Use figma_execute for all structural and
component inspection.

## File Details
- **File key**: `{{FILE_KEY}}`
- **Screen node ID**: `{{NODE_ID}}`
- **Screen name**: `{{SCREEN_NAME}}`
- **Draft reference node ID** (optional): `{{DRAFT_NODE_ID}}`
- **Components section node ID**: `{{COMPONENTS_SECTION_ID}}`
- **Expected components on this screen**: `{{EXPECTED_COMPONENTS}}`
  Format: `name:componentId` pairs (e.g. `SwipeGestureIcon:157:1092, TitleBodyGroup:157:539`).
  Match on **componentId** (authoritative), not on name.
- **Target viewport**: `{{VIEWPORT_WIDTH}}` x `{{VIEWPORT_HEIGHT}}`

## Audit Procedure

### Step 0 — Parent Context Check (MANDATORY — run first)
Use Script A from quality-audit-scripts.md to verify screen is direct child of SECTION/PAGE with no
wrapper GROUP and no orphaned siblings. Flag Critical if parent.type === 'GROUP'. Flag Major
if siblings.length > 0.

### Step 1 — Visual Capture
Take screenshot of Handoff screen with figma_take_screenshot (if saved) or figma_capture_screenshot
(if just mutated). If Draft reference exists, take screenshot of it too.

### Step 1b — Positional Diff vs Draft (if DRAFT_NODE_ID provided)
Run Script B from quality-audit-scripts.md. Flag Major if |dx| > 8px or |dwidth| > 8px. Flag Minor
if |dx| > 3px or |dwidth| > 3px. Report findings under D1: Visual Quality.

### Step 2 — Build Design System Registry
Run Script C from quality-audit-scripts.md to enumerate all components in Components section.

### Step 3 — Inspect Screen Structure + Instance Compliance
Run Script D from quality-audit-scripts.md to collect full node tree + resolve each INSTANCE to
mainComponent. Verify every instance's mcId is in DS registry (skip if mcRemote=true).

### Step 3.5 — UX Copy Quality Check
Run Script H from quality-audit-scripts.md. Check CTA quality (H1), error message structure (H2),
empty state structure (H3), and dialog button labels (H4). Include findings under D8: Instance Integrity.

### Step 4 — Check for Spurious Raw Frames
Run Script E from quality-audit-scripts.md. Flag raw FRAMEs whose name/child structure matches DS components.

### Step 5 — Auto-Layout Inspection
Run Script F from quality-audit-scripts.md. Report ONLY issues from 6 automated checks A-F. Do NOT
add manual findings. Screen root on fixed viewport exempt from auto-layout (it's a stage).

### Step 5.5 — Accessibility Compliance Check
Run Script G from quality-audit-scripts.md. Check color contrast (G1), touch target size (G2),
text size (G3), interactive spacing (G4), and missing descriptions (G5). Score per D11 rubric.
If D11 is N/A (icon-only design, non-interactive wireframe), mark as N/A and exclude from composite.

### Step 6 — Audit All 11 Dimensions

**D1 — Visual Quality**: Screenshot comparison, positional diff (quality-dimensions.md Section 2, D1 rubric)
**D2 — Layer Structure**: Parent context check, nesting depth, GROUP count (quality-dimensions.md Section 2, D2 rubric)
**D3 — Semantic Naming**: Generic name detection, slash-convention, PascalCase (quality-dimensions.md Section 2, D3 rubric)
**D4 — Auto-Layout**: Script F findings only (quality-dimensions.md Section 2, D4 rubric)
**D5 — Component Compliance**: 3-layer check (instance-to-DS, expected components ID match, no spurious raw frames) (quality-dimensions.md Section 2, D5 rubric)
**D6 — Constraints & Position**: Per-type constraint rules, per-element position analysis (quality-dimensions.md Section 2, D6 rubric)
**D7 — Screen Properties**: Root type, cornerRadius, clipsContent, dimensions, scrollability structure (quality-dimensions.md Section 2, D7 rubric)
**D8 — Instance Integrity**: Text override correctness via .characters, no placeholder text, copy quality via Script H (quality-dimensions.md Section 2, D8 rubric)
**D9 — Token Binding**: boundVariables inspection, % fills/strokes/effects bound (quality-dimensions.md Section 2, D9 rubric)
**D10 — Operational Efficiency**: Not applicable for single-screen audit (score N/A)
**D11 — Accessibility Compliance**: Script G findings (contrast, touch targets, text size, spacing, descriptions) (quality-dimensions.md Section 2, D11 rubric). N/A for icon-only or non-interactive wireframes

### Step 7 — Compute Composite Score
Simple average of applicable dimensions (dynamic denominator). Exclude D10 for single-screen audits; exclude D11 if N/A.

## Output Format

# Screen Audit — {{SCREEN_NAME}}

## Visual Snapshot
[Describe what both screenshots show and overall visual impression. Note match/mismatch vs Draft.]

---

## Design System Registry
[List all components found in Components section — name, type, node ID]

## Instances in Screen
[Table: instance name | mainComponent name | mainComponent ID | in DS registry? | expected ID match?]

---

## Audit Results

| Dimension | Score | Status |
|---|---|---|
| D1: Visual Quality | X/10 | Pass / Issues / Fail |
| D2: Layer Structure | X/10 | Pass / Issues / Fail |
| D3: Semantic Naming | X/10 | Pass / Issues / Fail |
| D4: Auto-Layout | X/10 | Pass / Issues / Fail |
| D5: Component Compliance | X/10 | Pass / Issues / Fail |
| D6: Constraints & Position | X/10 | Pass / Issues / Fail |
| D7: Screen Properties | X/10 | Pass / Issues / Fail |
| D8: Instance Integrity | X/10 | Pass / Issues / Fail |
| D9: Token Binding | X/10 | Pass / Issues / Fail |
| D10: Operational Efficiency | N/A | N/A |
| D11: Accessibility Compliance | X/10 or N/A | Pass / Issues / Fail / N/A |
| **Overall** | **X/10** | **PASS / NEEDS WORK** |

---

## Issues Found

### [Dimension]: [Short title]

| Property | Current | Expected |
|---|---|---|
| [property] | [actual value] | [correct value] |

**Severity**: Critical / Major / Minor / Cosmetic
**Node**: `[node ID — name]`
**Action**: [specific fix required]

[Repeat for each issue]

---

## Summary

| Metric | Value |
|---|---|
| Total issues | N |
| Critical | N |
| Major | N |
| Minor | N |
| Cosmetic | N |

## Verdict
[**PASS** (overall >= 8.0, no Critical/Major) / **NEEDS WORK** — required fixes in priority order]

---

## Severity Definitions
| Severity | Definition |
|---|---|
| **Critical** | Expected component missing, wrong mainComponent reference, broken override, screen wrapped in GROUP wrapper |
| **Major** | Raw frame where DS component should be used, wrong structural root type, orphaned sibling nodes in parent container, positional delta >8px |
| **Minor** | Constraint misconfiguration, naming issue, suboptimal layout, positional delta 3-8px |
| **Cosmetic** | Negligible, no user or developer impact |
```

---

## 5. Unified Fix Cycle

All fix cycles follow the Modification-Audit-Loop pattern. Modifications NEVER happen in main context — always delegated to subagents.

### Per-Screen Fix Cycle (Spot Check)

```
1. Identify the dimension(s) < 7.0
2. Dispatch Modification Subagent (Sonnet):
   - Input: issue list from Spot Check, node IDs, specific fixes
   - Uses: figma_execute to apply all changes
   - Returns: list of changes applied + node IDs modified
3. Re-run Spot Check (D1, D4, D10 only) — inline
4. If still < 5.0 after fix: flag in screen_complete journal entry, proceed
5. Max 3 iterations per screen
6. If still failing after 3 iterations -> escalate to user with AskUserQuestion
```

### Per-Phase Fix Cycle (Standard Audit)

```
1. Rank dimensions by score (lowest first)
2. Dispatch Modification Subagent (Sonnet) with bottom 2-3 dimensions as focus:
   - D1: Screenshot comparison + targeted adjustments
   - D2: Batch GROUP→FRAME conversion, fix nesting, remove orphaned siblings
   - D3: Batch rename using convergence-protocol batch rename template
   - D4: Apply auto-layout fixes from script findings
   - D5: Replace raw frames with DS instances, fix mainComponent references
   - D6: Update constraints via figma_execute setBoundVariable
   - D7: Fix root properties (cornerRadius, clipsContent, dimensions)
   - D8: Update instance overrides via figma_execute setCharacters
   - D9: Batch token binding via figma_execute setBoundVariable
   - D10: No retroactive fix (journal is immutable); note for remaining phases
3. Re-run Standard Audit Subagent on ALL dimensions (not just fixed ones — fixes can cause collateral regression)
4. Audit Fix Completeness Rule (MANDATORY):
   - Take previous audit's issue list, enumerate each by ID/description
   - Check each one in new audit output
   - If any issue absent from new audit (not marked resolved), treat as still open
   - NEVER accept fix subagent's "what I fixed" summary as ground truth — audit is only source of truth
5. If any previously-passing dimension regressed below its pre-fix score: revert the fix that caused regression, log as `fix_regression` in journal
6. Max 2 iterations per phase boundary
7. If still fail after 2 iterations: escalate to user with findings + "Let's discuss" option
```

### Session-End Fix Cycle (Deep Critique)

```
1. Deep findings are advisory — no automatic fix cycle at session end
2. Present consensus report to user with prioritized action items
3. User decides whether to address findings or accept current state
4. If user requests fixes: re-enter relevant phase, apply fixes, re-run Standard Audit
```

---

## 6. Mod-Audit-Loop Pattern

When any audit (Spot, Standard, Deep) triggers a fix cycle, follow this loop:

```
LOOP (max N iterations, N depends on tier):
  1. Dispatch Modification Subagent with issue list
  2. Subagent applies fixes using figma_execute (batched when possible)
  3. Subagent returns: changes_applied + node_ids_modified
  4. Re-run same audit tier (Spot inline, Standard/Deep subagent)
  5. Compare new scores to previous scores:
     - All fixed dimensions improved AND no regression → EXIT LOOP (success)
     - Fixed dimensions improved but some regression → revert regression fix, CONTINUE LOOP
     - Fixed dimensions unchanged or worse → escalate to user, EXIT LOOP (failure)
  6. If iteration count >= N → escalate to user, EXIT LOOP (failure)
END LOOP

Post-loop:
- Log final audit entry with verdict (pass/conditional_pass/fail)
- If fail after max iterations: present findings to user with "Let's discuss" option
```

**Iteration limits**: Spot = 3, Standard = 2, Deep = 0 (advisory only)

---

## 7. Deep Critique Judge Templates

Use when dispatching 3 judges for session-end Deep Critique. All judges are `Task(subagent_type="general-purpose", model="sonnet")`.

### Judge Prompt Variables

All templates use `{braces}` placeholders. Orchestrator fills from session state. If unavailable, use fallback default.

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
| `{components_section_id}` | string | Session state | `"Discover via figma_get_file_for_plugin"` |
| `{accessibility_summary}` | string | Script G output (if pre-run) | `"Not pre-gathered — run Script G during audit"` |

---

### Judge 1: Visual Fidelity Expert

**Evaluates**: D1 (Visual Quality), D6 (Constraints & Position), D7 (Screen Properties)

**Prompt template**:

```
## Role
Figma Visual Fidelity Expert — evaluate the visual quality, constraint correctness, and
screen-level properties of Figma designs created or modified in this session.

## Skill References (MANDATORY)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/quality-dimensions.md (Section 2: D1, D6, D7 rubrics)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/quality-audit-scripts.md (Section 10: Per-element position analysis, Section 11: Scrollability check)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/design-rules.md

## Context
- Figma file: {file_name}
- Screens processed: {screen_list}
- Target page ID: {target_page_id}
- Session journal: {journal_path}

## Evaluation Process

1. Visual Quality (D1):
   - figma_take_screenshot for each screen in {screen_list}
   - Check: 4px grid compliance, alignment, spacing consistency, color correctness
   - If Draft references available in journal: run positional diff script (quality-audit-scripts.md Script B)
   - Score per D1 rubric (0-10)

2. Constraints & Position (D6):
   - figma_execute to inspect constraints on all direct children of each screen
   - Per-element position analysis (quality-audit-scripts.md Section 10): verify appropriate positioning
   - Check: bottom-anchored elements on MAX vertical, full-width on STRETCH/LEFT_RIGHT horizontal
   - Score per D6 rubric (0-10)

3. Screen Properties (D7):
   - figma_execute to inspect root node properties for each screen
   - Check: type=FRAME, cornerRadius=32, clipsContent=true, dimensions match target
   - Scrollability check (quality-audit-scripts.md Section 11): structure consistent with scroll/non-scroll intent
   - Score per D7 rubric (0-10)

4. Self-verification (answer before scoring):
   - "Are constraint 'violations' justified by design intent (e.g., intentional absolute positioning)?"
   - "Is low visual quality score due to pre-existing issues, not session work?"
   - "Are screen property deviations project-specific standards vs defaults?"

5. Score D1, D6, D7 per rubric. Provide specific node IDs for issues.

## Output Format
Return JSON:
{
  "d1_score": <0-10>,
  "d6_score": <0-10>,
  "d7_score": <0-10>,
  "d1_issues": [{"screen": "...", "issue": "...", "severity": "Critical|Major|Minor", "node_id": "..."}],
  "d6_issues": [{"screen": "...", "node_id": "...", "issue": "...", "severity": "Critical|Major|Minor"}],
  "d7_issues": [{"screen": "...", "property": "...", "current": "...", "expected": "...", "severity": "Critical|Major|Minor"}],
  "verification_answers": ["...", "...", "..."],
  "summary": "1-2 sentence assessment"
}
```

---

### Judge 2: Structural & Component Expert

**Evaluates**: D2 (Layer Structure), D3 (Semantic Naming), D4 (Auto-Layout), D5 (Component Compliance), D8 (Instance Integrity), D11 (Accessibility Compliance)

**Prompt template**:

```
## Role
Figma Structural & Component Expert — evaluate the layer hierarchy, naming quality,
auto-layout correctness, component compliance, instance integrity, and accessibility compliance
of Figma designs in this session.

## Skill References (MANDATORY)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/quality-dimensions.md (Section 2: D2, D3, D4, D5, D8, D11 rubrics)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/quality-audit-scripts.md (Sections 1-8: Scripts A-H)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/design-rules.md

## Context
- Figma file: {file_name}
- Screens processed: {screen_list}
- Target page ID: {target_page_id}
- Components section node ID: {components_section_id}
- Available library components: {component_summary}

## Evaluation Process

1. Layer Structure (D2):
   - figma_execute Script A (quality-audit-scripts.md Section 1) for each screen: parent context check
   - figma_get_file_for_plugin: analyze nesting depth, GROUP count
   - Check: screen direct child of SECTION/PAGE, no orphaned siblings, nesting max 6, zero GROUPs
   - Score per D2 rubric (0-10)

2. Semantic Naming (D3):
   - From node tree: count generic vs semantic names (quality-dimensions.md Section 2, D3)
   - Check: slash-convention, PascalCase components, cross-screen consistency
   - Score per D3 rubric (0-10)

3. Auto-Layout (D4):
   - figma_execute Script F (quality-audit-scripts.md Section 6) for each screen
   - Report ONLY issues from 6 automated checks A-F (script-only rule)
   - Do NOT add manual findings — screen root on fixed viewport exempt from Check B
   - Score per D4 rubric (0-10)

4. Component Compliance (D5):
   - figma_execute Script C (quality-audit-scripts.md Section 3): build DS registry
   - figma_execute Script D (quality-audit-scripts.md Section 4): enumerate instances + resolve mainComponent IDs
   - figma_execute Script E (quality-audit-scripts.md Section 5): detect spurious raw frames
   - 3-layer check: (A) instance-to-DS mapping, (B) expected components present (ID-authoritative), (C) no spurious raw frames
   - Score per D5 rubric (0-10)

5. Instance Integrity (D8):
   - figma_execute to read .characters on TEXT nodes inside INSTANCEs
   - Check: no residual placeholder text, overrides match intent
   - Never rely on screenshots alone — REST API screenshots show stale defaults
   - Score per D8 rubric (0-10)

5b. UX Copy Quality (D8 sub-checks):
   - figma_execute Script H (quality-audit-scripts.md Section 8): CTA quality (H1), error message structure (H2), empty state structure (H3), dialog button labels (H4)
   - Include Script H findings in D8 score (copy violations lower the D8 score per rubric)

6. Accessibility Compliance (D11):
   - figma_execute Script G (quality-audit-scripts.md Section 7): contrast (G1), touch targets (G2), text size (G3), interactive spacing (G4), descriptions (G5)
   - If design is icon-only or non-interactive wireframe: score N/A
   - Score per D11 rubric (0-10)

8. Self-verification:
   - "Are residual GROUPs intentional (e.g., boolean operations)?"
   - "Does the project use a non-standard naming convention?"
   - "Are 'missing' expected components due to stale session-state IDs?"
   - "Is auto-layout 'violation' justified (e.g., stage vs layout container)?"
   - "Is D11 N/A because this is an icon-only or non-interactive design?"

9. Score D2, D3, D4, D5, D8, D11 per rubric. Provide specific node IDs for issues.

## Output Format
Return JSON:
{
  "d2_score": <0-10>,
  "d3_score": <0-10>,
  "d4_score": <0-10>,
  "d5_score": <0-10>,
  "d8_score": <0-10>,
  "d11_score": <0-10 or "N/A">,
  "d2_issues": [{"screen": "...", "issue": "...", "severity": "Critical|Major|Minor", "node_id": "..."}],
  "d3_issues": [{"screen": "...", "node_id": "...", "issue": "...", "severity": "Critical|Major|Minor"}],
  "d4_issues": [{"screen": "...", "check": "A|B|C|D|E|F", "issue": "...", "severity": "Major|Minor", "node_id": "..."}],
  "d5_issues": [{"screen": "...", "layer": "A|B|C", "issue": "...", "severity": "Critical|Major|Minor", "node_id": "..."}],
  "d8_issues": [{"screen": "...", "instance": "...", "issue": "...", "severity": "Critical|Major|Minor", "node_id": "..."}],
  "d11_issues": [{"screen": "...", "check": "G1|G2|G3|G4|G5", "issue": "...", "severity": "Critical|Major|Minor", "node_id": "..."}],
  "verification_answers": ["...", "...", "...", "...", "..."],
  "summary": "1-2 sentence assessment"
}
```

---

### Judge 3: Design System & Token Expert

**Evaluates**: D9 (Token Binding), D10 (Operational Efficiency)

**Prompt template**:

```
## Role
Figma Design System & Token Expert — evaluate token binding coverage and operational
efficiency of the design session.

## Skill References (MANDATORY)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/quality-dimensions.md (Section 2: D9/D10 rubrics)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/convergence-protocol.md

## Context
- Figma file: {file_name}
- Screens processed: {screen_list}
- Available variable collections: {collection_summary}
- Session journal: {journal_path}
- Session duration: {start_ts} to {end_ts}

## Evaluation Process

1. Token Binding (D9):
   - figma_execute: scan nodes on each screen, inspect boundVariables
   - Count: nodes with fills/strokes/effects bound to variables vs hardcoded
   - Check: spacing values from auto-layout bound to tokens (via variable name match)
   - Magic number rule: flag hardcoded values appearing 3+ times cross-screen (candidates for tokenization)
   - Score per D9 rubric (0-10)

2. Operational Efficiency (D10):
   - Read operation-journal.jsonl, compute:
     * batch_ratio = batch_ops / (batch_ops + individual_same_type_ops)
       (3+ same-type ops NOT batched = missed opportunities)
     * native_tools_first = native_tool_uses / (native_tool_uses + figma_execute_for_native_ops)
       (e.g., figma_execute for component search instead of figma_search_components)
     * convergence_compliance = convergence_check_ops / total_mutating_ops
     * redundant_ops = count of ops targeting same node+property with same value
   - Score per D10 rubric (0-10)

3. Self-verification:
   - "Is low token binding justified? (e.g., one-off illustration, no token system available)"
   - "Were individual calls justified (debugging fallback after batch failure)?"
   - "Is convergence compliance penalized unfairly for small inline workflows?"
   - "Are magic numbers false positives (intentionally repeated values)?"

4. Score D9 and D10 per rubric. List specific hardcoded values for D9, journal evidence for D10.

## Output Format
Return JSON:
{
  "d9_score": <0-10>,
  "d10_score": <0-10>,
  "d9_issues": [{"screen": "...", "node_id": "...", "property": "fills|strokes|effects|spacing", "current_value": "...", "suggested_variable": "...", "severity": "Major|Minor"}],
  "d10_stats": {"batch_ratio": <0-1>, "native_tools_first": <0-1>, "convergence_compliance": <0-1>, "redundant_ops": <N>},
  "d10_issues": [{"issue": "...", "journal_evidence": "...", "severity": "Minor"}],
  "verification_answers": ["...", "...", "..."],
  "summary": "1-2 sentence assessment"
}
```

---

### Judge 4: UX Design Critic (Deep only, advisory)

**Evaluates**: Visual Hierarchy, Usability, Consistency, First Impression (qualitative — no numeric dimension scores)

**Note**: Judge 4 produces qualitative findings only. Findings appear in the Deep consensus report as an advisory section but do NOT affect the composite score. Flag any contradictions with Judge 1 (Visual Fidelity Expert).

**Prompt template**:

```
## Role
UX Design Critic — evaluate the overall user experience quality of Figma designs
created or modified in this session. Provide qualitative critique on visual hierarchy,
usability, consistency, and first impressions. Your findings are ADVISORY — they
inform but do not gate the quality verdict.

## Skill References (MANDATORY)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/design-rules.md

## Context
- Figma file: {file_name}
- Screens processed: {screen_list}
- Target page ID: {target_page_id}

## Evaluation Process

1. Visual Hierarchy Assessment (per screen):
   - figma_take_screenshot for each screen in {screen_list}
   - Evaluate: clear focal points, logical reading flow (F-pattern/Z-pattern), proper contrast between primary and secondary content
   - Note: screens with strong hierarchy guide the eye naturally without effort

2. Usability Assessment (per screen):
   - Check: actionable elements are clearly tappable/clickable, navigation is discoverable, form flows are logical, error prevention patterns present
   - Evaluate: cognitive load (too many choices, unclear grouping, competing CTAs)

3. Consistency Assessment (cross-screen):
   - Check: same element types styled consistently across screens, spacing rhythm maintained, color usage semantically consistent
   - Flag: inconsistent button styles, mismatched section spacing, color meaning changes between screens

4. First Impression Test (per screen):
   - 2-second rule: what does the user notice first? Is it the right thing?
   - Overall aesthetic: does the design feel polished, professional, intentional?
   - Identify any "jarring" elements that break visual cohesion

5. Synthesize findings into actionable suggestions.

## Output Format
Return JSON:
{
  "findings": [
    {
      "pillar": "Visual Hierarchy|Usability|Consistency|First Impression",
      "screen": "screen name or 'cross-screen'",
      "observation": "what was observed",
      "suggestion": "specific improvement recommendation",
      "severity": "high|medium|low"
    }
  ],
  "first_impression_pass": [
    {"screen": "...", "focal_point": "...", "passes_2s_test": true/false, "notes": "..."}
  ],
  "overall_ux_assessment": "1-3 sentence holistic assessment",
  "top_3_improvements": [
    "Most impactful improvement suggestion",
    "Second most impactful",
    "Third most impactful"
  ]
}
```

---

## 8. Journal Integration

### New Operation Type

Add to the Operation Types table in `convergence-protocol.md`:

| `op` value | When to log | Key `detail` fields |
|-----------|-------------|-------------------|
| `quality_audit` | After every Spot/Standard/Deep audit completes | `tier` (spot/standard/deep), `scores` (per-dimension object), `composite_score`, `verdict` (pass/conditional_pass/fail), `issues` (list), `improvements_applied`. **Standard/Deep only**: `judges` (Deep only), `consensus` (Deep only) |

### Example Entries

**Spot (per-screen, inline)**:
```jsonl
{"v":1,"ts":"2026-02-24T10:30:00Z","op":"quality_audit","target":"screen:ONB-03","detail":{"tier":"spot","scores":{"d1":9.0,"d4":8.0,"d10":9.0},"composite_score":8.7,"verdict":"pass","issues":[],"improvements_applied":0},"phase":3}
```

**Standard (per-phase boundary)**:
```jsonl
{"v":1,"ts":"2026-02-24T11:00:00Z","op":"quality_audit","target":"screen:ONB-03","detail":{"tier":"standard","composite_score":8.2,"scores":{"d1":9.0,"d2":8.0,"d3":8.0,"d4":7.0,"d5":9.0,"d6":8.0,"d7":9.0,"d8":9.0,"d9":7.0,"d10":8.0,"d11":8.0},"verdict":"pass","issues":["D4: Check C — spacer frame in auto-layout","D9: 2 hardcoded fills in secondary surfaces"],"improvements_applied":0},"phase":3}
```

**Deep (session-end)**:
```jsonl
{"v":1,"ts":"2026-02-24T12:00:00Z","op":"quality_audit","target":"session","detail":{"tier":"deep","composite_score":7.9,"scores":{"d1":8.0,"d2":8.0,"d3":7.0,"d4":7.0,"d5":9.0,"d6":8.0,"d7":9.0,"d8":9.0,"d9":7.0,"d10":8.0,"d11":8.0},"verdict":"conditional_pass","issues":["D3: 5 generic names in deep children","D4: Check B — 1 frame with 3 stacked children, no auto-layout","D9: 8 hardcoded fills remain"],"improvements_applied":2,"judges":{"visual_fidelity":{"d1":8.0,"d6":8.0,"d7":9.0},"structural_component":{"d2":8.0,"d3":7.0,"d4":7.0,"d5":9.0,"d8":9.0,"d11":8.0},"design_system":{"d9":7.0,"d10":8.0},"ux_critic":"advisory — see consensus report"},"consensus":"Structural quality strong. Naming and token binding are primary gaps. No Critical/Major blockers."},"phase":4}
```

---

## 9. Compound Learning Integration

### New Trigger

Add to the Auto-Detect Triggers table in `compound-learning.md`:

| # | Trigger | Category | Example |
|---|---------|----------|---------|
| T6 | **Quality audit reveals systematic gap** — same dimension scored <7.0 across 2+ screens or 2+ sessions | Effective Strategies or Performance Patterns | "Token binding consistently low — batch binding at phase boundary is more effective than per-screen" |

### Audit-to-Learning Pipeline

During Phase 4 compound learning save (after checking T1-T6 triggers), additionally:

```
1. Read all op: "quality_audit" entries from session journal
2. Identify any dimension scoring <7.0 in 2+ audit entries
   (cross-screen pattern within session, or cross-session if learnings file has prior audit notes)
3. If found: compose a compound learning entry:
   - H3 key: dimension-name-systematic-gap (e.g., "token-binding-batch-at-phase-boundary")
   - Category: Effective Strategies or Performance Patterns
   - Problem: description of systematic gap
   - Solution: corrective approach that improved scores when applied
   - Tags: dimension name + workflow type
4. Deduplicate per standard protocol (H3 key match + keyword spot-check)
```

---

## 10. Maintenance Checklist

When modifying any quality procedure:

- [ ] Update this file (quality-procedures.md) with procedure changes
- [ ] Update quality-dimensions.md if dimension rubrics change
- [ ] Update quality-audit-scripts.md if new scripts are needed
- [ ] Update references/README.md file usage table and cross-references
- [ ] Test new procedure with live Figma file before committing
- [ ] Document any new placeholders in Section 4 or Section 7
- [ ] Update journal schema documentation if new fields added
- [ ] Update compound-learning.md if new trigger added

---

## Cross-References

- **quality-dimensions.md** — 11 dimension rubrics, composite scoring formula, depth tier definitions, contradiction resolutions
- **quality-audit-scripts.md** — JavaScript audit scripts A-I, positional diff script, per-element position analysis, scrollability check
- **Convergence Protocol** (journal schema for audit results): `convergence-protocol.md`
- **Compound Learning** (save triggers T1-T6, cross-session persistence): `compound-learning.md`
- **Anti-patterns** (known errors to distinguish from quality gaps): `anti-patterns.md`
- **Design Rules** (MUST/SHOULD/AVOID — referenced by all judges): `design-rules.md`
- **Plugin API** (figma_execute patterns used in audit scripts): `plugin-api.md`
- **Field Learnings** (production strategies): `field-learnings.md`
- **Component Recipes** (fixes for component issues): `recipes-components.md`
- **SKILL.md** (Phase 4 protocol, MUST/AVOID rules): `SKILL.md`
