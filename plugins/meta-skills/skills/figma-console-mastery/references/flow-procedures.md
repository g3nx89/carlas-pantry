# Flow Procedures

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Detailed phase procedures for Flow 1 (Design Session, 4 modes) and Flow 2 (Handoff QA).
> Subagents load this file when dispatched for phase execution.
>
> **Load when**: Subagent dispatched for Flow 1 or Flow 2 phase execution.

---

## 1. Flow 1 — Design Session

Unified flow for design creation, restructuring, targeted fixes, and audits. Replaces Session Protocol, Quick Audit, and Design Restructuring workflows.

### 1.0 Mode Selection

| User Intent | Mode | Phase 2 | Phase 3 | Phase 4 |
|-------------|------|---------|---------|---------|
| "Create a design" / "Build a screen" | **Create** | Socratic planning (creation-focused subset) | Full creation pipeline (subagent) | Spot per screen, Standard at end |
| "Restructure this design" | **Restructure** | Full analysis + Socratic planning (all categories) | Path A/B transform (subagent) | Standard + before/after metrics |
| "Check/fix this frame" | **Audit** | Selection scan (subagent) | Targeted fixes (subagent) | Screenshot only (Spot) |
| "Create components" / "Setup tokens" | **Targeted** | Targeted discovery | Specific operations (subagent) | Spot after completion |

### 1.1 Phase 1 — Preflight & Discovery

#### Shared (all modes) — inline (main context)

1. `figma_get_status` → verify connection and mode
2. `figma_list_open_files` → confirm correct file is active
3. `figma_navigate` → open target page/file if needed
4. **Build/validate Session Index** — if `specs/figma/session-index.jsonl` does not exist or meta `file_key` differs from current file, call `figma_get_file_data(verbosity='summary', depth=1)` and write the index (see `session-index-protocol.md`). If the index exists and is fresh (< 5 min), skip.
5. **Load compound learnings** — if `~/.figma-console-mastery/learnings.md` exists, read entries relevant to the current task type
6. `figma_get_design_system_summary` → understand existing tokens, components, styles
7. `figma_get_variables(format="summary")` → catalog available variables

#### Restructure mode additions (Sonnet subagent)

1. Baseline screenshot of target frame
2. `figma_get_file_for_plugin` → full node tree JSON
3. Deep analysis → layer structure, auto-layout usage, hardcoded values, naming patterns
4. `figma_audit_design_system` → 0-100 health scorecard
5. Structured findings report → saved to `specs/figma/analysis/{screen-name}.md`

#### Audit mode additions (Sonnet subagent)

1. Ask user to select target frame or page in Figma Desktop
2. `figma_get_file_for_plugin({ selectionOnly: true })` → node tree for selection only
3. Deviation analysis → hardcoded colors (no `boundVariables`), non-4px spacing, missing auto-layout, generic layer names
4. Deviation inventory → grouped by type with node IDs

### 1.2 Phase 2 — Analysis & Planning (Expanded Socratic Protocol)

**Skip for**: Audit and Targeted modes (go directly to Phase 3)

**Run for**: Create and Restructure modes

The Socratic Protocol ensures user-approved design decisions before execution. For each applicable category: present key questions via `AskUserQuestion`, capture decisions, and add to the checklist.

**Convergence criteria**:
- Minimum 1 question per applicable category (skip only categories marked N/A for the mode)
- Maximum 3 Socratic rounds per category (question → answer → follow-up)
- Converged when 2 consecutive rounds produce no new design decisions
- On convergence: compile checklist and present for explicit user approval before Phase 3

#### Category 0 — Existing Documentation Check

- Check for existing screen specs, design briefs, or wireframes in `specs/`
- If found, summarize and ask user if these should guide the design
- Output: reference to existing docs or confirmation to proceed without

#### Category 1 — User Description of Screen (optional for Create)

- Ask user to describe the screen's purpose, key elements, and user flow
- Capture text, images, or references
- Output: user-provided screen description or "No description provided"

#### Category 2 — Cross-Screen Comparison (optional)

- If multiple screens in the project, ask user if this screen should match existing patterns
- Show list of existing screens, ask if any should serve as reference
- Output: reference screens or "Standalone design"

#### Category 3 — General Approach (Restructure only)

- Present two paths based on Phase 1 analysis:
  - **Path A (Surgical)**: Preserve existing structure, apply auto-layout and tokens selectively
  - **Path B (Rebuild)**: Reconstruct from scratch using best practices
- Ask user which path to take, or suggest based on analysis findings
- Output: "Path A" or "Path B" with brief rationale

#### Category 4 — Screen Structure & Positioning (Restructure only)

- Show current layer hierarchy, identify problematic nesting (deep GROUP trees, floating elements)
- Ask user to approve proposed structure changes (flatten, reparent, section grouping)
- Output: approved structural changes list

#### Category 5 — Auto-Layout, Padding & Spacing

- Identify frames that should use auto-layout (stacks, grids)
- Propose 4px-based spacing and padding values
- Ask user to confirm or adjust spacing rules
- Output: auto-layout targets with spacing/padding values

#### Category 6 — Componentization

- Identify repeated elements (buttons, cards, headers)
- Apply Smart Componentization Criteria (3 gates: recurrence 3+, behavioral variants exist, codebase match)
- Ask user which elements should become components
- Output: component targets with variant properties

#### Category 7 — Naming Rules (Single Source of Truth)

- Check for existing naming rules text block in Figma Components section
- If exists: load and present to user, ask if changes needed
- If not exists: ask user to define naming conventions (frame naming, layer naming, component naming)
- Persist approved naming rules as text block in Figma Components section
- Output: naming rules reference (location in Figma) + brief summary

#### Category 8 — Design Tokens & Colors

- Identify hardcoded colors, spacing, typography
- Map to existing variables or propose new tokens
- Ask user to confirm token bindings and approve new tokens
- Output: token binding plan + new tokens to create

#### Category 9 — Interactions & Behaviors (mostly Restructure)

- Identify interactive elements (buttons, links, overlays)
- Ask user if prototype connections should be added
- Output: interaction targets or "No interactions"

#### Category 10 — Content & Interaction Specifications (optional)

- Capture content constraints: character limits, truncation strategies, string expansion for i18n
- Document empty states, loading states, and error states for interactive elements
- Record gesture/hover/focus behaviors beyond what Figma prototype captures
- Output: content and interaction specs for Handoff Manifest OR "Skipped — handled elsewhere"

#### Mode-specific category subsets

- **Create mode**: Run Cat. 0, 1, 2 (optional), 5, 6, 7, 8, 10 (optional). Skip Cat. 3, 4, 9.
- **Restructure mode**: Run all categories (0-10).

#### Checklist output

After all categories, compile a user-approved checklist with numbered items across all categories. Do NOT proceed to Phase 3 until user explicitly approves the checklist.

### 1.3 Phase 3 — Execution

**ALWAYS in subagent.** Main context dispatches subagent with approved checklist and relevant references.

#### Create mode

1. Create frame with approved dimensions
2. Instantiate library components where applicable
3. Create custom elements with `figma_execute` (frames, text, shapes)
4. Apply auto-layout with approved spacing/padding
5. Bind design tokens using `setBoundVariable()`
6. Apply naming rules from Cat. 7
7. Log every operation to per-screen journal: `specs/figma/journal/{screen-name}.jsonl`

#### Restructure mode

1. **Path A (Surgical)**: Convert GROUPs to FRAMEs, apply auto-layout to target frames, bind tokens, rename per rules, preserve existing content
2. **Path B (Rebuild)**: Capture text/colors from original, create new structure from scratch following checklist, apply all improvements
3. Log every operation to per-screen journal

#### Audit mode

1. Apply targeted fixes per deviation type (naming → `figma_rename_node`, colors → `figma_set_fills`, text → `figma_set_text`, layout → `figma_execute`)
2. Log fixes to per-screen journal

#### Targeted mode

1. Execute specific operation (component creation, token setup, etc.)
2. Log to per-screen journal

#### Subagent loads

**Required**: `recipes-foundation.md`, `convergence-protocol.md`, `convergence-execution.md`, `essential-rules.md`

**Mode-specific**: `recipes-components.md`, `recipes-restructuring.md`, `recipes-advanced.md`, etc.

#### Phase 3 Completion Contract

Phase 3 subagent MUST log a `phase_complete` journal entry before returning:

```jsonl
{"v":1,"ts":"...","op":"phase_complete","target":"phase:3","detail":{"screens_modified":3,"operations_count":47,"errors_count":0},"phase":3}
```

**Orchestrator validation** (inline, before dispatching Phase 4):

1. Read journal, find `op: "phase_complete"` with `target: "phase:3"`
2. If `errors_count > 0`: present error summary to user with `AskUserQuestion` before proceeding to Phase 4
3. If no `phase_complete` entry found (subagent crash): reconstruct from journal — count distinct `target` screens, sum operations, count entries with `"error"` in detail. Log reconstructed entry with `"reconstructed": true`

### 1.4 Phase 4 — Validation

**ALWAYS in subagent.** Main context dispatches audit subagent with `quality-dimensions.md` reference.

#### Quality audit tiers (per `quality-dimensions.md`)

- **Spot** (D1, D4, D10): Quick visual check, screenshot analysis, 3 dimensions (D1 Visual Quality, D4 Auto-Layout, D10 Operational Efficiency). Run after each screen in Create/Targeted, after each fix in Audit.
- **Standard**: 11-dimension audit (add Layer Structure, Semantic Naming, Component Compliance 3-layer, Constraints, Screen Properties, Instance Override Integrity, Token Bindings, Operational Efficiency, Accessibility Compliance). Run at end of Create, after Restructure completion.
- **Deep**: Standard + multi-judge critique (Visual Fidelity Expert, Structural & Component Expert, Design System & Token Expert). Run at session end for Restructure.

#### Validation steps

1. Subagent runs tier-appropriate audit from quality-dimensions.md
2. Captures screenshot via `figma_capture_screenshot` (Desktop Bridge, live state)
3. Scores 11 dimensions (or 3 for Spot, excl. N/A)
4. If fail or conditional_pass: targeted fix cycle (max 2 iterations per screen — phase boundary limit per `quality-dimensions.md` Contradiction Resolution #3)
5. Logs audit results to per-screen journal: `op: "quality_audit"`
6. Returns findings to main context

**Main context** reviews findings, decides whether to proceed or loop back to Phase 3.

#### Save compound learnings

At session end, review for learning-worthy discoveries (triggers T1-T6 from `compound-learning.md`); append 0-3 new entries to `~/.figma-console-mastery/learnings.md`.

### Phase Transition Guards

- Phase 1 → 2: IF `figma_get_status` returned connected AND mode determined THEN proceed
- Phase 2 → 3: IF user approved checklist (explicit confirmation) THEN dispatch subagent
- Phase 3 → 4: IF `phase_complete` journal entry exists (or reconstructed) THEN validate Session Index freshness (C9), dispatch audit
- Phase 4 → end: IF audit verdict = pass OR user accepted conditional_pass THEN save learnings

---

## 2. Flow 2 — Handoff QA

Quality assurance flow for preparing designs for code handoff. Replaces Visual QA and Code Handoff workflows. Does NOT generate manifest — only ensures handoff readiness.

### 2.1 Phase 1 — Screen Inventory & Baseline

**In subagent (Sonnet)**:

1. `figma_list_open_files` → identify target file
2. `figma_navigate` → open target page
3. **Consult Session Index** — if `specs/figma/session-index.jsonl` exists and is valid (C9 check), use `Grep` to list all FRAME entries on the target page. If index is missing or stale, fall back to `figma_get_file_for_plugin` → full node tree (original behavior)
4. Identify top-level frames (screens) from index entries or node tree
5. Capture baseline screenshot for each screen via `figma_capture_screenshot`
6. Generate screen inventory: `specs/figma/inventory.md` with screen names, dimensions, frame IDs
7. Return inventory to main context

**Main context** presents inventory to user, asks which screens need QA.

### 2.2 Phase 2 — Quality Audit

**Per screen, in subagent**:

1. Load `quality-dimensions.md` for 11-dimension Standard audit
2. Load screen-specific context (baseline screenshot, node tree excerpt)
3. Run 11-dimension audit:
   - D1: Visual Quality
   - D2: Layer Structure
   - D3: Semantic Naming
   - D4: Auto-Layout (6 automated checks)
   - D5: Component Compliance (3-layer)
   - D6: Constraints
   - D7: Screen Properties
   - D8: Instance Override Integrity
   - D9: Token Bindings
   - D10: Operational Efficiency
   - D11: Accessibility Compliance
4. Score each dimension (0-10)
5. Identify deviations with node IDs
6. Write audit report: `specs/figma/audits/{screen-name}.md`
7. Return summary to main context (pass/fail, critical deviations count)

**Main context** aggregates results across all screens, presents summary to user.

### 2.3 Phase 3 — Modification-Audit-Loop

**For each screen with deviations**:

**Main context** asks user: "Fix automatically?" or "Review findings first?" or "Let's discuss this"

If approved for auto-fix:

> **Why separate subagents?** The modification subagent loads recipes and convergence references, while the audit subagent loads `quality-dimensions.md`. Combining both in one subagent would exceed recommended context budget. Separate dispatch ensures context isolation.

#### Modification subagent (Sonnet)

1. Load audit report for screen
2. Load `recipes-restructuring.md`, `convergence-protocol.md`
3. Apply fixes per deviation type (same pattern as Flow 1 Audit mode)
4. Log fixes to per-screen journal
5. Return completion status

#### Audit subagent (Sonnet, separate dispatch)

1. Load `quality-dimensions.md`
2. Re-run 11-dimension audit on modified screen
3. Compare scores to previous audit
4. Write updated audit report
5. Return pass/fail verdict

#### Per-Screen Loop Summary (context management)

After each screen's mod-audit-loop completes (pass or max iterations), write a summary file:

`specs/figma/audits/{screen-name}-loop-summary.md` containing:
- Final dimension scores (table)
- Issues fixed (count + list)
- Issues remaining (count + list)
- Iteration count used

**Context rule**: When starting the next screen's mod-audit-loop, orchestrator reads ONLY the previous screen's `*-loop-summary.md` for cross-screen context — never the full audit reports. This prevents context accumulation across 10+ screen iterations.

#### Main context checks verdict

- **Pass**: write loop summary, move to next screen
- **Conditional pass** or **Fail**: loop back (max 3 iterations per screen — per-screen limit)
- After 3 iterations: write loop summary with remaining issues, escalate to user with findings

### 2.4 Phase 4 — Handoff Readiness

**In subagent**:

#### Naming audit with single-source-of-truth

1. Check for existing naming rules text block in Figma Components section
2. If exists: load naming rules, audit all screens against rules, report deviations
3. If not exists: analyze all screens, derive naming patterns, present to user for approval, persist approved rules as text block in Figma Components section
4. If deviations found: ask user to approve auto-fix or manual review

#### Token alignment audit

1. `figma_get_variables(format="summary")` → list all variables
2. For each screen, check for hardcoded values that should use tokens
3. Present findings to user with explicit confirmation: "Bind to token X?" (never assume user intent for magic numbers)
4. Apply approved bindings

#### Behavioral & content specification extraction

1. Run Script I (`quality-audit-scripts.md` Section 9) per screen to auto-extract prototype connections
2. Prompt user for gesture/hover/focus behaviors not captured in Figma prototype
3. Compute current character counts for TEXT nodes, prompt user for limits and overflow rules
4. Present edge case checklist (i18n, degraded conditions) per `workflow-code-handoff.md` Behavioral Specification Extraction Steps
5. Write behavioral specifications to handoff manifest draft

#### Final design system audit

1. `figma_audit_design_system` → 0-100 health scorecard
2. Report overall score and category breakdowns

#### Readiness report

1. Compile handoff readiness report: `specs/figma/handoff-readiness.md`
2. Include: screen count, audit pass/fail summary, naming compliance, token coverage, design system score, outstanding issues
3. Present to main context

**Main context** presents readiness report to user, confirms handoff-ready status. Does NOT generate manifest — that's the responsibility of `design-handoff` skill.

### Phase Transition Guards

- Phase 1 → 2: IF screen inventory confirmed by user THEN proceed
- Phase 2 → 3: IF all screens audited AND deviations identified THEN start mod-loop
- Phase 3 → 4: IF all screens pass OR max iterations reached for all THEN proceed
- Phase 4 → end: IF naming audit + token check pass THEN declare handoff-ready

---

## Cross-References

- **SKILL.md** — Flow selection, mode selection, phase boundary rules
- **socratic-protocol.md** — Phase 2 question templates (Flow 1)
- **quality-dimensions.md** — Phase 4 audit dimensions, scripts, judge templates
- **convergence-protocol.md** — Per-screen journal, anti-regression rules
- **convergence-execution.md** — Batch scripting, subagent dispatch templates, session snapshots, compact recovery
- **recipes-foundation.md** — Required for any figma_execute code
- **recipes-restructuring.md** — Restructure mode patterns
- **recipes-components.md** — Component creation patterns
- **compound-learning.md** — Cross-session learning persistence
