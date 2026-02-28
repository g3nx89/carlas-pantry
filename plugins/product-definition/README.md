# Product Definition Plugin

A Claude Code plugin for the full product definition lifecycle: PRD generation, technical specification, design handoff preparation, and UX narrative creation from Figma mockups.

## Overview

This plugin provides four interconnected workflows:

- **Requirements** (`/requirements`) - Transform rough product ideas into structured PRD documents through iterative file-based Q&A with multi-perspective analysis
- **Specify** (`/specify`) - Create detailed technical specifications with acceptance criteria, design briefs, and V-Model test strategies
- **Handoff** (`/handoff`) - Prepare Figma designs for coding agent consumption: structural cleanup, gap detection, and compact supplement generation with LLM-as-judge quality gates
- **Narrate** (`/narrate`) *(superseded by `/handoff`)* - Generate UX/interaction narratives from Figma Desktop mockups

**Pipeline:** `requirements (PRD.md) → specify (spec.md) → handoff (manifest + supplement)`

## Quick Start

```bash
# Requirements: place your draft in requirements/draft/, then:
/product-definition:requirements

# Specification: after PRD is ready:
/product-definition:specify

# Design Handoff: with figma-console MCP running:
/product-definition:handoff
```

## Installation

### From Marketplace

```bash
/plugin install product-definition@carlas-pantry
```

### From Local Directory

```bash
claude plugins add /path/to/product-definition
claude plugins enable product-definition
```

## Commands

### `/product-definition:requirements`

Orchestrates a 6-stage PRD refinement workflow.

**Workflow:**
1. **Initialization** - Detects draft, creates workspace
2. **Mode Selection** - User chooses analysis depth
3. **Research (Optional)** - Generate research agenda for market analysis
4. **Question Generation** - Multi-perspective analysis creates questions
5. **User Response** - User answers questions in markdown files
6. **Gap Analysis** - Detects coverage gaps, may generate more questions
7. **PRD Validation** - Multi-model consensus on readiness
8. **PRD Generation** - Creates finalized non-technical PRD

**Analysis Modes:**

| Mode | Description | MCP Required | Cost/Round |
|------|-------------|--------------|------------|
| **Complete** | Panel (2-5 members) + PAL ThinkDeep (9 calls) + Sequential | Yes | $0.80-1.50 |
| **Advanced** | Panel (2-5 members) + PAL ThinkDeep (6 calls) | Yes | $0.50-0.80 |
| **Standard** | Panel (2-5 members) only | No | $0.15-0.25 |
| **Rapid** | Single agent | No | $0.05-0.10 |

### `/product-definition:specify`

Creates detailed technical specifications from a completed PRD.

**Features:**
- Acceptance criteria generation per feature
- Design brief creation with Figma capture integration
- V-Model test strategy (inner/outer loop classification)
- Specification completeness checklists (general + mobile)

### `/product-definition:handoff`

Prepares Figma designs for coding agent consumption. Two-track approach: **Track A** prepares the Figma file itself (naming, structure, components), **Track B** generates a compact supplement covering ONLY what Figma cannot express (behaviors, transitions, states, edge cases).

**6-Stage Workflow:**

| Stage | Name | Description |
|-------|------|-------------|
| 1 | Discovery & Inventory | figma-console MCP check, page scan, readiness audit, TIER decision, designer approval |
| 2 | Figma Preparation | Per-screen structural cleanup via figma-console-mastery (one screen per dispatch) |
| 2J/3J/3.5J/5J | Judge Checkpoints | LLM-as-judge quality gates at critical boundaries |
| 3 | Gap & Completeness | Gap detection + missing screen/state detection via figma-console |
| 3.5 | Design Extension | Create missing screens in Figma (conditional — only if gaps detected) |
| 4 | Designer Dialog | Per-screen interactive Q&A about gaps only |
| 5 | Output Assembly | HANDOFF-SUPPLEMENT.md + handoff-manifest.md generation |

**Modes:**
- **Guided** (default) — Batch discovery, interactive per-screen dialog
- **Quick** — Single screen, no Figma preparation (Stages 1→3→4→5)
- **Batch** — File-based Q&A, no interactive dialog

**Key features:**
- Figma is the visual source of truth — supplement NEVER describes what's already visible
- figma-console MCP only (live Plugin API state — no REST API staleness)
- Smart Componentization with 3-gate TIER system (recurrence, variants, codebase match)
- LLM-as-judge (opus) at 4 stage boundaries with checkpoint-specific rubrics
- One-screen-per-dispatch pattern prevents context compaction
- Missing screen detection with designer-approved creation in Figma
- Confidence tagging on gaps (high/medium/low) for prioritization
- N/A applicability assessment eliminates false positives on static screens
- Step-level crash recovery via state file

### `/product-definition:narrate`

> **Superseded by `/handoff`.** Retained for backward compatibility.

Transforms Figma Desktop mockups into detailed UX/interaction narrative documents. Produces comprehensive UX-NARRATIVE.md files describing all screen interactions, states, and behaviors.

## Skills

| Skill | Purpose |
|-------|---------|
| `design-handoff` | Figma preparation + compact gap supplement for coding agents (v1.0.0) |
| `design-narration` | UX narrative generation from Figma mockups (v1.8.0) — superseded by `design-handoff` |
| `specify` | Technical specification generation (v1.1.0) |
| `refinement` | PRD refinement orchestration |

## Directory Structures

### Requirements Workspace

```
requirements/
├── draft/                    # Place your drafts here
│   └── my-product-draft.md
├── working/                  # Generated question files
│   ├── QUESTIONS-001.md
│   └── QUESTIONS-002.md
├── research/                 # Optional research outputs
├── PRD.md                    # Final output
├── decision-log.md           # Question → PRD traceability
└── .requirements-state.local.md
```

### Design Handoff Workspace

```
design-handoff/
├── working/                  # Intermediate artifacts
│   ├── gap-report.md         # Gap & completeness analysis
│   └── judge-verdicts/       # LLM-as-judge verdict files
│       ├── 2J-verdict.md
│       ├── 3J-verdict.md
│       └── 5J-verdict.md
├── screenshots/              # Figma screenshots for visual diff
├── .screen-inventory.md      # Raw scanner output
├── handoff-manifest.md       # Screen inventory, component mapping, tokens
├── HANDOFF-SUPPLEMENT.md     # Final output — gaps only
├── .handoff-state.local.md   # Workflow state (YAML + markdown)
└── .handoff-lock             # Lock file
```

### Design Narration Workspace

```
design-narration/
├── screens/                  # Per-screen narratives
│   └── {nodeId}-{name}.md
├── figma/                    # Figma context/screenshots
├── working/                  # Batch mode: consolidated Q&A documents
│   ├── BATCH-QUESTIONS-001.md
│   └── .consolidation-summary.md
├── validation/               # MPA + synthesis outputs
│   ├── mpa-implementability.md
│   ├── mpa-ux-completeness.md
│   ├── mpa-edge-cases.md
│   └── synthesis.md
├── coherence-report.md       # Cross-screen consistency
├── UX-NARRATIVE.md           # Final output
└── .narration-state.local.md
```

## MCP Dependencies

| MCP Server | Used By | Purpose | Fallback |
|------------|---------|---------|----------|
| `figma-desktop` | `/narrate` | Screen metadata, screenshots, design context | **Required** for narration |
| `figma-console` | `/handoff` | Figma file read + mutations, audit, screenshots, component search | **Required** for handoff |
| `pal` | `/requirements`, `/narrate` | Multi-model consensus, ThinkDeep analysis | Single-model analysis |
| `sequential-thinking` | `/requirements` | Deep structured analysis | Standard reasoning |

If MCP tools are unavailable:
- `/handoff`: `figma-console` required — no graceful degradation
- `/requirements`: Complete and Advanced modes degrade to Standard when PAL unavailable
- `/narrate`: Stage 4 validation runs MPA-only (PAL consensus skipped)
- User is notified of degraded capability in all cases

## Plugin Components

### Agents (26)

| Agent | Command/Skill | Purpose | Model |
|-------|--------------|---------|-------|
| `requirements-panel-builder` | requirements | Compose dynamic MPA panel | sonnet |
| `requirements-panel-member` (template) | requirements | Parametric template per panel member | sonnet |
| `requirements-question-synthesis` | requirements | Merge & deduplicate N perspectives | opus |
| `requirements-prd-generator` | requirements | PRD document creation | opus |
| `research-discovery-business` | requirements | Market research questions | sonnet |
| `research-discovery-technical` | requirements | Viability research | sonnet |
| `research-discovery-ux` | requirements | User research questions | sonnet |
| `research-question-synthesis` | requirements | Research agenda synthesis | opus |
| `question-synthesis` | requirements | Generic question synthesis | opus |
| `business-analyst` | specify | Specification generation | sonnet |
| `design-brief-generator` | specify | Design brief creation | sonnet |
| `gap-analyzer` | specify | Specification gap analysis | sonnet |
| `gate-judge` | specify | Quality gate evaluation | sonnet |
| `qa-strategist` | specify | V-Model test strategy | sonnet |
| `handoff-screen-scanner` | handoff | Figma frame discovery, structural analysis, readiness scoring | haiku |
| `handoff-figma-preparer` | handoff | Per-screen Figma preparation via figma-console-mastery | sonnet |
| `handoff-gap-analyzer` | handoff | Gap detection + missing screen/state detection via figma-console | sonnet |
| `handoff-judge` | handoff | LLM-as-judge at 4 stage boundaries | opus |
| `narration-figma-discovery` | narrate | Figma frame detection + batch page discovery with matching | haiku |
| `narration-screen-analyzer` | narrate | Per-screen narrative + self-critique | sonnet |
| `narration-question-consolidator` | narrate | Batch mode: cross-screen question dedup + conflict detection | sonnet |
| `narration-coherence-auditor` | narrate | Cross-screen consistency | sonnet |
| `narration-developer-implementability` | narrate | MPA: implementability audit | sonnet |
| `narration-ux-completeness` | narrate | MPA: journey/state coverage | sonnet |
| `narration-edge-case-auditor` | narrate | MPA: unusual conditions | sonnet |
| `narration-validation-synthesis` | narrate | Merge MPA + PAL, prioritize fixes | opus |

### Templates (23)

| Template | Purpose |
|----------|---------|
| `draft-template.md` | User input format for requirements |
| `prd-template.md` | PRD output structure |
| `questions-template.md` | Question file format |
| `decision-log-template.md` | Traceability log |
| `research-synthesis-template.md` | Research findings |
| `research-report-template.md` | Individual reports |
| `.requirements-state-template.local.md` | Requirements workflow state |
| `spec-template.md` | Technical specification structure |
| `spec-checklist.md` | Specification completeness checklist |
| `spec-checklist-mobile.md` | Mobile-specific checklist |
| `design-brief-template.md` | Design brief structure |
| `design-supplement-template.md` | Design supplement format |
| `figma_context-template.md` | Figma context capture |
| `test-strategy-template.md` | V-Model test strategy |
| `handoff-supplement-template.md` | Handoff supplement output structure |
| `handoff-screen-template.md` | Per-screen supplement section |
| `handoff-manifest-template.md` | Screen inventory + component-to-code mapping |
| `screen-narrative-template.md` | Per-screen narrative structure |
| `ux-narrative-template.md` | Final UX narrative document (single-file mode) |
| `ux-narrative-index-template.md` | UX narrative index (multi-file mode) |
| `batch-questions-template.md` | Batch mode consolidated Q&A document |
| `screen-descriptions-template.md` | User input format for batch screen descriptions |
| `.panel-config-template.local.md` | Panel composition config for MPA agents |

## Configuration

| Config File | Command/Skill |
|-------------|--------------|
| `config/requirements-config.yaml` | `/requirements` |
| `config/specify-config.yaml` | `/specify` |
| `config/handoff-config.yaml` | `/handoff`, design-handoff skill |
| `config/narration-config.yaml` | `/narrate`, design-narration skill |

Key configuration areas:
- Analysis mode parameters and MPA agent settings
- PAL ThinkDeep/Consensus model aliases and stance steering
- Question generation rules and PRD validation thresholds
- Self-critique thresholds and stall detection parameters
- Token budgets for context management
- Handoff: TIER thresholds, readiness scoring, scenario detection, judge rubrics, visual diff settings

## EXTEND Mode

When the workflow detects an existing `PRD.md`:

1. Analyzes each section for completeness
2. Presents EXTEND options:
   - **Expand** - Add detail to partial sections
   - **Regenerate** - Rewrite specific sections
   - **Specific** - Target particular gaps
3. Preserves existing content while filling gaps

## Troubleshooting

### "Lock file exists" error
```bash
# For requirements:
rm requirements/.requirements-lock
# For design handoff:
rm design-handoff/.handoff-lock
# For design narration:
rm design-narration/.narration-lock
```

### State file corruption
```bash
# For requirements:
rm requirements/.requirements-state.local.md
# For design handoff:
rm design-handoff/.handoff-state.local.md
# For design narration:
rm design-narration/.narration-state.local.md
# Then re-run the command to reinitialize
```

### MCP tools unavailable
- Plugin automatically degrades — PAL consensus skipped, modes limited
- User is notified of degraded capability
- No manual intervention required

### Figma not detected
- Ensure Figma Desktop is open with the design file
- `/handoff` requires `figma-console` MCP server running
- `/narrate` requires `figma-desktop` MCP only

## Version

- **Plugin Version:** 3.0.0
- **Schema Version:** 2

## License

MIT
