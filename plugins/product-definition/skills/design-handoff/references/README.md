# Design Handoff — Reference Files Index

> **Skill:** `design-handoff` | **Plugin:** `product-definition`
> **Last updated:** 2026-03-01

---

## File Usage Table

| File | Stage | Lines | Purpose | Load When |
|------|-------|-------|---------|-----------|
| `setup-protocol.md` | 1 | 271 | Discovery, inventory, readiness audit, TIER decision | Stage 1 execution (inline) |
| `figma-preparation.md` | 2 | 556 | Per-screen Figma prep dispatch, visual diff, circuit breaker | Stage 2 orchestrator loop |
| `gap-analysis.md` | 3 | 454 | Gap detection + missing screen detection, figma-console | Stage 3 dispatch |
| `design-extension.md` | 3.5 | 314 | Missing screen creation, designer decision flow | Stage 3.5 (conditional) |
| `designer-dialog.md` | 4 | 295 | Focused Q&A about gaps, cross-screen confirmation | Stage 4 orchestrator loop |
| `output-assembly.md` | 5 | 238 | Supplement + manifest generation from templates | Stage 5 execution (inline) |
| `judge-protocol.md` | 2J,3J,3.5J,5J | 251 | Shared judge dispatch, 4 checkpoint rubrics, model selection | Every judge checkpoint |
| `state-schema.md` | All | 271 | YAML state schema, init template, resume protocol | State creation, crash recovery |
| `gap-category-examples.md` | 3 (agent) | 85 | Gap category calibration examples (6 tables) | Agent dispatch only (never coordinator) |
| `README.md` | — | 66 | This file — reference index | Orientation |

**Total:** ~2802 lines across 10 reference files

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
| `gap-analysis.md` | `gap-category-examples.md` | Agent-only calibration examples (extracted for context efficiency) |

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
| `templates/figma-screen-brief-template.md` | Template | `gap-analysis.md` (Stage 3 FSB generation) |
| `figma-console-mastery` (meta-skills plugin) | Skill | Loaded by `handoff-figma-preparer` agent for Figma operation recipes |

---

## Stage Flow

```
1 (setup) → 2 (figma-prep) → 2J (judge) → 3 (gaps) → 3J (judge)
  → [3.5 (extend) → 3.5J (judge)] → 4 (dialog) → 5 (output) → 5:supplement_written → 5J (judge) → complete
```

Stages 3.5/3.5J are conditional — only run if Stage 3 detects missing screens.
