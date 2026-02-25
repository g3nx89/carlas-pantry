# Design Handoff — Reference Files Index

> **Skill:** `design-handoff` | **Plugin:** `product-definition`
> **Last updated:** 2026-02-22

---

## File Usage Table

| File | Stage | Lines | Purpose | Load When |
|------|-------|-------|---------|-----------|
| `setup-protocol.md` | 1 | 264 | Discovery, inventory, readiness audit, TIER decision | Stage 1 execution (inline) |
| `figma-preparation.md` | 2 | 504 | Per-screen Figma prep dispatch, visual diff enforcement | Stage 2 orchestrator loop |
| `gap-analysis.md` | 3 | 430 | Gap detection + missing screen detection, figma-console | Stage 3 dispatch |
| `design-extension.md` | 3.5 | 291 | Missing screen creation, designer decision flow | Stage 3.5 (conditional) |
| `designer-dialog.md` | 4 | 282 | Focused Q&A about gaps, cross-screen confirmation | Stage 4 orchestrator loop |
| `output-assembly.md` | 5 | 171 | Supplement + manifest generation from templates | Stage 5 execution (inline) |
| `judge-protocol.md` | 2J,3J,3.5J,5J | 216 | Shared judge dispatch pattern, 4 checkpoint rubrics | Every judge checkpoint |
| `state-schema.md` | All | 210 | YAML state schema, init template, resume protocol | State creation, crash recovery |
| `README.md` | — | 63 | This file — reference index | Orientation |

**Total:** ~2430 lines across 9 reference files

---

## Cross-References

| Source File | References | Why |
|-------------|-----------|-----|
| `setup-protocol.md` | `state-schema.md` | State initialization template |
| `figma-preparation.md` | `state-schema.md` | Per-screen progress tracking |
| `figma-preparation.md` | `judge-protocol.md` | Stage 2J checkpoint criteria |
| `gap-analysis.md` | `judge-protocol.md` | Stage 3J checkpoint criteria |
| `design-extension.md` | `figma-preparation.md` | Reuses `handoff-figma-preparer` in extend mode |
| `design-extension.md` | `judge-protocol.md` | Stage 3.5J checkpoint criteria |
| `output-assembly.md` | `judge-protocol.md` | Stage 5J checkpoint criteria |

---

## External Dependencies

| Dependency | Type | Used By |
|-----------|------|---------|
| `config/handoff-config.yaml` | Config | All reference files |
| `templates/handoff-supplement-template.md` | Template | `output-assembly.md` |
| `templates/handoff-screen-template.md` | Template | `output-assembly.md` |
| `templates/handoff-manifest-template.md` | Template | `figma-preparation.md`, `output-assembly.md` |
| `agents/handoff-screen-scanner.md` | Agent | `setup-protocol.md` (Stage 1 dispatch) |
| `agents/handoff-figma-preparer.md` | Agent | `figma-preparation.md` (Stage 2), `design-extension.md` (Stage 3.5) |
| `agents/handoff-gap-analyzer.md` | Agent | `gap-analysis.md` (Stage 3 dispatch) |
| `agents/handoff-judge.md` | Agent | `judge-protocol.md` (all checkpoints) |
| `figma-console-mastery` (meta-skills plugin) | Skill | Loaded by `handoff-figma-preparer` agent for Figma operation recipes |

---

## Stage Flow

```
1 (setup) → 2 (figma-prep) → 2J (judge) → 3 (gaps) → 3J (judge)
  → [3.5 (extend) → 3.5J (judge)] → 4 (dialog) → 5 (output) → 5J (judge) → complete
```

Stages 3.5/3.5J are conditional — only run if Stage 3 detects missing screens.
