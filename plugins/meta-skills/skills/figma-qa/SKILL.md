---
name: figma-qa
version: 1.0.0
description: This skill should be used when the user asks to "check this design", "audit the design", "quality check", "validate the design", "handoff readiness check", "review design quality", "run a design audit", "check for issues", "is this design ready", or any Figma design quality assessment task. Do NOT trigger for creating new designs (use figma-execute), restructuring existing designs (use figma-restructure), generating handoff manifests (use design-handoff), skill/command development (use figma-console-mastery), FigJam, Figma REST API, or figma-desktop/Official Figma MCP.
---

# Figma QA — Quality Audit & Readiness

> **Compatibility**: figma-console-mcp v1.11.2+ (Southleft, 61 tools)
>
> **Scope**: Quality audit, fix loop, and handoff readiness reporting. Full 11-dimension quality model. No design creation or structural restructuring.
>
> **Reference hub**: All reference files live in `../figma-console-mastery/references/`.

## Prerequisites

| Requirement | Check |
|-------------|-------|
| Figma Desktop App | Running with file open |
| Desktop Bridge Plugin | Installed and active (WebSocket ports 9223-9232) |
| Local mode | Required for fix operations (audit is read-only) |

**Always first**: `figma_get_status`. If not connected, ask user to check Figma Desktop and Bridge Plugin.

## Audit Depth Selection

| User Intent | Depth | Dimensions | Use Case |
|-------------|-------|------------|----------|
| "Quick check" / single frame | **Spot** | D1 Visual, D4 Auto-Layout, D10 Efficiency | Fast sanity check |
| "Full audit" / "check quality" | **Standard** | All 11 dimensions | Thorough review |
| "Deep review" / explicit request | **Deep** | Standard + multi-judge critique | Pre-handoff final review |

When ambiguous, default to **Standard**.

## Quality Dimensions (11)

| # | Dimension | What It Checks |
|---|-----------|---------------|
| D1 | Visual Quality | Alignment, spacing, proportions, visual balance |
| D2 | Layer Structure | Nesting depth, GROUP vs FRAME, hierarchy |
| D3 | Semantic Naming | Descriptive names vs "Frame 42", consistency |
| D4 | Auto-Layout | Correct usage, padding, gap, fill vs hug |
| D5 | Component Compliance | Library usage, instance integrity, variant coverage |
| D6 | Constraints & Position | Responsive behavior, constraint correctness |
| D7 | Screen Properties | Dimensions, device targets, overflow |
| D8 | Instance Integrity | Override quality, UX copy, text consistency |
| D9 | Token Binding | Variable usage vs hardcoded values |
| D10 | Operational Efficiency | Redundant layers, performance, cleanup |
| D11 | Accessibility | Contrast ratios, touch targets, text size |

Each scored 0-10. Composite score = weighted average (see `quality-dimensions.md` for formula).

## Phase 1 — Screen Inventory (subagent)

1. `figma_get_status` → `figma_list_open_files` → `figma_navigate` to target page
2. Identify top-level frames (screens) via `figma_get_file_data(verbosity='summary', depth=1)`
3. Capture baseline screenshot for each screen via `figma_capture_screenshot`
4. Generate inventory: screen names, dimensions, frame IDs
5. Present to user → ask which screens need QA

## Phase 2 — Quality Audit (subagent per screen)

1. Load `quality-dimensions.md` for scoring rubrics
2. Load `quality-audit-scripts.md` for automated checks (Scripts A-I)
3. Run tier-appropriate audit:
   - **Spot**: Scripts A (parent context) + D (structure) + visual screenshot analysis
   - **Standard**: All scripts A-I, score all 11 dimensions
   - **Deep**: Standard + 3 judge critiques (Visual Fidelity, Structural, Design System)
4. Score each dimension 0-10, identify deviations with node IDs
5. Write audit report per screen
6. Return summary to orchestrator (pass/conditional/fail, deviation count)

**Verdicts**: pass (composite ≥7.0, no dimension <5.0) | conditional_pass (composite ≥6.0) | fail

## Phase 3 — Fix Loop (subagents)

Ask user: "Fix automatically?" / "Review findings first?" / "Let's discuss this"

If approved for auto-fix, per screen:

1. **Modification subagent**: Load audit report + `recipes-restructuring.md` + `convergence-protocol.md`. Apply fixes per deviation type:
   - Naming → `figma_rename_node`
   - Colors → `figma_set_fills` or `figma_execute` with `setBoundVariable`
   - Layout → `figma_execute` for auto-layout fixes
   - Text → `figma_set_text`
   - Log fixes to per-screen journal: `specs/figma/journal/{screen-name}.jsonl`

2. **Audit subagent** (separate dispatch): Re-run audit on modified screen, compare scores

3. **Verdict check**:
   - **Pass** → move to next screen
   - **Conditional/Fail** → loop back (max 3 iterations per screen)
   - After 3 iterations → escalate remaining issues to user

4. Write loop summary per screen (final scores, fixed count, remaining count)

## Phase 4 — Readiness Report (subagent)

1. **Naming audit**: Check for naming rules text block in the Figma file's Components section. If exists, audit against rules. If not, derive patterns and propose to user.
2. **Token alignment**: `figma_get_variables(format="summary")` → check for hardcoded values that should use tokens. Present findings, apply approved bindings.
3. **Design system health**: `figma_audit_design_system` → 0-100 scorecard
4. **Compile report**: `specs/figma/handoff-readiness.md` with screen count, pass/fail summary, naming compliance, token coverage, DS score, outstanding issues
5. Present to user. Does NOT generate handoff manifest (that's `design-handoff`'s job).

## Reference Loading

```
# Tier 1 — Always load
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-foundation.md

# Tier 2 — Load for audit (Phase 2 subagent, max 3-4 simultaneously)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/quality-dimensions.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/quality-audit-scripts.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/quality-procedures.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/tool-playbook.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/essential-rules.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/design-rules.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-code-handoff.md

# Tier 2 — Load for fix loop (Phase 3 subagent MUST load both)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-restructuring.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/convergence-protocol.md  # Required: defines journal format and anti-regression rules

# Tier 3 — Load by need
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/anti-patterns.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/plugin-api-foundation.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/field-learnings.md
```

## When NOT to Use

- **Creating new designs** → use `figma-execute`
- **Restructuring existing designs** → use `figma-restructure`
- **Full protocol with convergence, compound learning, ST** → use `figma-console-mastery`
- **Draft-to-Handoff orchestration / manifest generation** → use `design-handoff` skill (product-definition plugin)
