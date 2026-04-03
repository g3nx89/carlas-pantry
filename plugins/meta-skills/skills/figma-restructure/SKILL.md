---
name: figma-restructure
version: 1.0.0
description: This skill should be used when the user asks to "restructure this design", "clean up this Figma file", "convert to auto-layout", "fix the structure", "organize layers", "refactor the design", "apply auto-layout to existing frames", "componentize repeated elements", or any structural improvement of an existing Figma design. Do NOT trigger for creating new designs from scratch (use figma-execute), quality audits without structural changes (use figma-qa), handoff orchestration (use design-handoff), skill/command development (use figma-console-mastery), FigJam, Figma REST API, or figma-desktop/Official Figma MCP.
---

# Figma Restructure — Analysis + Transform

> **Compatibility**: figma-console-mcp v1.11.2+ (Southleft, 61 tools)
>
> **Scope**: Restructuring existing Figma designs through 4 phases: Analyze → Plan → Transform → Validate. Includes convergence journaling (anti-regression) and simplified Socratic planning (5 categories). Standard audit at the end.
>
> **Reference hub**: All reference files live in `../figma-console-mastery/references/`.

## Prerequisites

| Requirement | Check |
|-------------|-------|
| Figma Desktop App | Running with file open |
| Desktop Bridge Plugin | Installed and active (WebSocket ports 9223-9232) |
| Local mode | Required for all mutation tools |

**Always first**: `figma_get_status`. If not connected, ask user to check Figma Desktop and Bridge Plugin.

## Phase 1 — Analysis (subagent)

1. `figma_get_status` → `figma_list_open_files` → `figma_navigate` to target
2. Baseline screenshot via `figma_capture_screenshot`
3. `figma_get_file_for_plugin` → full node tree JSON
4. `figma_get_design_system_kit(format="summary")` → tokens, components, styles
5. Deep analysis → produce findings:
   - Layer structure: nesting depth, GROUP vs FRAME ratio, floating elements
   - Auto-layout: frames missing auto-layout, inconsistent spacing, hardcoded positions
   - Design tokens: hardcoded colors/spacing count, variable coverage
   - Naming: generic names ("Frame 42"), inconsistent patterns
   - Components: repeated elements, instance integrity
6. `figma_audit_design_system` → 0-100 health scorecard
7. Return structured findings to orchestrator

## Phase 2 — Planning (Simplified Socratic, inline)

Present findings from Phase 1, then run 5 question categories. Max 2 rounds per category. Every question MUST include "Let's discuss this" option.

### Category 1 — General Approach
Based on analysis: **Path A (Surgical)** preserves structure, applies fixes selectively. **Path B (Rebuild)** reconstructs from scratch. If prototype connections exist, warn that Path B breaks them.
- "Which approach: Path A (surgical, preserves prototypes) or Path B (full rebuild, cleaner result)?"

### Category 2 — Structure & Layers
Show problematic nesting (5+ level GROUPs, floating elements). Propose flatten/reparent.
- "I found [N] deep GROUP trees and [M] floating elements. Approve structural cleanup?"

### Category 3 — Auto-Layout & Spacing
Identify frames needing auto-layout. Propose spacing system (4px or 8px base).
- "I'll apply auto-layout to [N] frames with [X]px gaps. Confirm spacing values?"

### Category 4 — Componentization
Identify repeated elements (3+ occurrences). Apply Smart Criteria: recurrence, behavioral variants, codebase match.
- "These elements repeat 3+ times: [list]. Which should become components?"

### Category 5 — Design Tokens & Colors
Map hardcoded values to existing variables or propose new tokens.
- "I found [N] hardcoded colors and [M] spacing values. Bind to tokens?"

### Checklist Compilation
After all categories, compile numbered checklist. Present for explicit user approval.
**Do NOT proceed to Phase 3 until user approves.**

## Phase 3 — Transform (subagent)

Dispatch subagent with approved checklist. Subagent loads `convergence-protocol.md` for anti-regression journaling.

**Path A (Surgical)**:
1. Convert GROUPs to FRAMEs where needed
2. Apply auto-layout with approved spacing
3. Bind design tokens via `setBoundVariable()`
4. Rename per approved naming rules
5. Preserve existing content and prototype connections

**Path B (Rebuild)**:
1. Capture text/colors/content from original
2. Create new structure from scratch per checklist
3. Apply all improvements (auto-layout, tokens, naming, components)

**Both paths**:
- Log every operation to `specs/figma/journal/{screen-name}.jsonl`
- Read journal before each mutation (convergence check C1-C3)
- Log `phase_complete` entry when done

### Essential Rules (Transform)

> Canonical source: `../figma-console-mastery/references/essential-rules.md` (23 MUST + 13 AVOID). Critical subset below.

1. Wrap `figma_execute` in async IIFE with outer `return`
2. Use `figma.getNodeByIdAsync(id)` — sync throws in `dynamic-page` mode
3. Load fonts before setting text
4. Set `layoutMode` before padding/spacing
5. GROUP→FRAME before applying constraints
6. Never mutate Figma arrays directly — clone, modify, reassign
7. Never return raw Figma nodes — return `{ id, name }`

## Phase 4 — Validate (subagent)

Standard audit (11 dimensions) on restructured screens.

1. Capture post-transform screenshot via `figma_capture_screenshot`
2. Run 11-dimension audit (see `quality-dimensions.md`)
3. Score each dimension 0-10
4. Compare before/after metrics (Phase 1 vs Phase 4)
5. If issues found: targeted fix cycle (max 2 iterations per screen)
6. Log `quality_audit` entry to journal
7. Present before/after comparison to user

**Verdicts**: pass (composite ≥7.0) | conditional_pass (≥6.0, ask user) | fail (loop back)

## Phase Transition Guards

- Phase 1 → 2: `figma_get_status` returned connected AND analysis complete
- Phase 2 → 3: User explicitly approved checklist
- Phase 3 → 4: `phase_complete` journal entry exists
- Phase 4 → end: Audit pass OR user accepted conditional_pass

## Reference Loading

```
# Tier 1 — Always load
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-foundation.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/convergence-protocol.md

# Tier 2 — Load for Analysis + Transform (max 3-4 simultaneously)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-restructuring.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/plugin-api-foundation.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/design-rules.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/essential-rules.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/tool-playbook.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-handoff.md

# Tier 2 — Load for Validation (Phase 4 subagent)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/quality-dimensions.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/quality-audit-scripts.md

# Tier 3 — Load by need
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/anti-patterns.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/plugin-api-visuals.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/plugin-api-advanced.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/convergence-execution.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/field-learnings.md
```

## When NOT to Use

- **Creating new designs from scratch** → use `figma-execute`
- **Quality audits without structural changes** → use `figma-qa`
- **Full protocol with compound learning, ST, session index** → use `figma-console-mastery`
- **Draft-to-Handoff orchestration** → use `design-handoff` skill (product-definition plugin)
