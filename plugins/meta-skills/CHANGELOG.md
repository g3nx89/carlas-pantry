# Changelog — meta-skills

## [0.9.0] — 2026-02-22

### Breaking Changes

- **figma-use MCP server removed**: The figma-use MCP server (`mcp__figma-use__*` tools) has been entirely removed from figma-console-mastery. The figma-use server had CDP dependency (`--remote-debugging-port=9222`), pre-1.0 stability issues, and connection reliability problems. Skills and agents that loaded `figma-use-overview.md`, `figma-use-jsx-patterns.md`, `figma-use-analysis.md`, or `figma-use-diffing.md` from this skill will now receive a "file not found" error.

### Removed Files

- `skills/figma-console-mastery/references/figma-use-overview.md`
- `skills/figma-console-mastery/references/figma-use-jsx-patterns.md`
- `skills/figma-console-mastery/references/figma-use-analysis.md`
- `skills/figma-console-mastery/references/figma-use-diffing.md`

### Migration Guide

If you referenced figma-use tools in your workflows, replace as follows:

| figma-use tool | Replacement |
|----------------|-------------|
| `figma_node_children` | `figma_execute: page.children.map(n => ({id:n.id, name:n.name}))` |
| `figma_diff_visual` | `figma_capture_screenshot` on both frames + visual comparison |
| `figma_analyze_*` | `figma_audit_design_system`, `figma_get_styles`, `figma_get_variables` |
| `figma_render` (JSX) | `figma_execute` with Plugin API creation patterns (see `recipes-foundation.md`) |
| `figma_query` (XPath) | `figma_execute` with `page.findAll(n => ...)` |
| `figma_node_clone` | `figma_execute: node.clone()` |

### Added

- figma-console-mastery learnings integration from `~/.figma-console-mastery/learnings.md`:
  - **SKILL.md**: Added AVOID rules #16-18 (stale screenshot, page-context split, primaryAxisSizingMode FILL). Updated Decision Matrix (G0-G3 gates). Revised screenshot validation rule throughout. Added 20+ troubleshooting rows.
  - **anti-patterns.md**: Added 15+ new entries — async IIFE outer return, getNodeByIdAsync requirement, GROUP child coordinates, instance rescale vs resize, page-context reversion, console-log 3x tripling, Desktop Bridge dropout, get_design_context false positives.
  - **recipes-foundation.md**: Fixed async IIFE outer return WARNING — outer `return` IS required and confirmed working.
  - **tool-playbook.md**: Updated strategy from "figma-use-first" to "native-tools-first". Updated three-server comparison with deprecation notice. Updated Complementary Workflow to two-server pattern.

### Changed

- **SKILL.md**: Default strategy changed from "figma-use-first" to "native-tools-first" (figma-console atomic tools + figma_execute for complex logic).
- **references/README.md**: Removed figma-use file entries from usage table and cross-references.
- **references/convergence-protocol.md**: Removed figma-use tool references from subagent prompt templates and batch scripting protocol.
- **references/workflow-draft-to-handoff.md**: Added migration note mapping figma-use tools to figma-execute equivalents.

---

## [0.8.0] — 2026-02-10

### Added

- `workflow-draft-to-handoff.md`: Full Draft-to-Handoff workflow (8 principles, 28 operational rules, per-screen pipeline).
- `convergence-protocol.md`: Operation Journal spec, anti-regression Convergence Check rules, Batch Scripting Protocol, Subagent Delegation Model.
- `compound-learning.md`: Cross-session knowledge persistence protocol.
- `st-integration.md`: Sequential Thinking integration templates.
- CSS Grid card layout recipe in `recipes-foundation.md`.
- Expanded prototype reactions in `plugin-api.md`.

---

*Follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format.*
