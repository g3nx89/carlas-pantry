# Product Definition Plugin

A Claude Code plugin for the full product definition lifecycle: PRD generation, technical specification, and UX narrative creation from Figma mockups.

## Overview

This plugin provides three interconnected workflows:

- **Requirements** (`/requirements`) - Transform rough product ideas into structured PRD documents through iterative file-based Q&A with multi-perspective analysis
- **Specify** (`/specify`) - Create detailed technical specifications with acceptance criteria, design briefs, and V-Model test strategies
- **Narrate** (`/narrate`) - Generate UX/interaction narratives from Figma Desktop mockups, producing developer-ready handoff documents

**Pipeline:** `requirements (PRD.md) → specify (spec.md) → narrate (UX-NARRATIVE.md)`

## Quick Start

```bash
# Requirements: place your draft in requirements/draft/, then:
/product-definition:requirements

# Specification: after PRD is ready:
/product-definition:specify

# Design Narration: with Figma Desktop open:
/product-definition:narrate
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

Orchestrates a 12-phase PRD refinement workflow.

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
| **Complete** | MPA (3 agents) + PAL ThinkDeep (9 calls) + Sequential | Yes | $0.80-1.50 |
| **Advanced** | MPA (3 agents) + PAL ThinkDeep (6 calls) | Yes | $0.50-0.80 |
| **Standard** | MPA (3 agents) only | No | $0.15-0.25 |
| **Rapid** | Single agent | No | $0.05-0.10 |

### `/product-definition:specify`

Creates detailed technical specifications from a completed PRD.

**Features:**
- Acceptance criteria generation per feature
- Design brief creation with Figma capture integration
- V-Model test strategy (inner/outer loop classification)
- Specification completeness checklists (general + mobile)

### `/product-definition:narrate`

Transforms Figma Desktop mockups into detailed UX/interaction narrative documents.

**5-Stage Workflow:**

| Stage | Name | Description |
|-------|------|-------------|
| 1 | Setup | Figma MCP check, optional context doc, state init/resume |
| 2 | Screen Processing | Per-screen analysis with self-critique, Q&A, refinement loop |
| 3 | Coherence Check | Cross-screen consistency, pattern extraction, mermaid diagrams |
| 4 | Validation | MPA (3 agents) + PAL Consensus (multi-step with stance steering) + synthesis |
| 5 | Output | Assemble UX-NARRATIVE.md from screens + patterns + validation |

**Key features:**
- One screen at a time, user-driven order
- Self-critique rubric with 5 dimensions scores each screen
- Stall detection prevents infinite refinement loops
- Mutable decisions with full audit trail
- PAL Consensus with stance steering (for/against/neutral) for validation
- Graceful degradation when PAL or Figma MCP unavailable

## Skills

| Skill | Purpose |
|-------|---------|
| `design-narration` | UX narrative generation from Figma mockups (v1.4.0) |
| `feature-specify` | Technical specification generation (v1.0.0) |
| `refinement` | PRD refinement orchestration |
| `sadd-orchestrator` | Subagent-driven development patterns |
| `specify-clarification` | Specification clarification workflows |
| `specify-figma-capture` | Figma design capture for specifications |

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

### Design Narration Workspace

```
design-narration/
├── screens/                  # Per-screen narratives
│   └── {nodeId}-{name}.md
├── figma/                    # Figma context/screenshots
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
| `pal` | `/requirements`, `/narrate` | Multi-model consensus, ThinkDeep analysis | Single-model analysis |
| `sequential-thinking` | `/requirements` | Deep structured analysis | Standard reasoning |

If PAL tools are unavailable:
- `/requirements`: Complete and Advanced modes degrade to Standard
- `/narrate`: Stage 4 validation runs MPA-only (PAL consensus skipped)
- User is notified of degraded capability in both cases

## Plugin Components

### Agents (23)

| Agent | Command/Skill | Purpose | Model |
|-------|--------------|---------|-------|
| `requirements-product-strategy` | requirements | Product/market questions | sonnet |
| `requirements-user-experience` | requirements | UX/persona questions | sonnet |
| `requirements-business-ops` | requirements | Operations questions | sonnet |
| `requirements-question-synthesis` | requirements | Merge & deduplicate | opus |
| `requirements-prd-generator` | requirements | PRD document creation | opus |
| `research-discovery-business` | requirements | Market research questions | sonnet |
| `research-discovery-technical` | requirements | Viability research | sonnet |
| `research-discovery-ux` | requirements | User research questions | sonnet |
| `research-question-synthesis` | requirements | Research agenda synthesis | opus |
| `question-classifier` | requirements | Route question types | haiku |
| `question-synthesis` | requirements | Generic question synthesis | opus |
| `business-analyst` | specify | Specification generation | sonnet |
| `design-brief-generator` | specify | Design brief creation | sonnet |
| `gap-analyzer` | specify | Specification gap analysis | sonnet |
| `gate-judge` | specify | Quality gate evaluation | sonnet |
| `qa-strategist` | specify | V-Model test strategy | sonnet |
| `stakeholder-synthesis` | specify | Stakeholder input synthesis | opus |
| `narration-screen-analyzer` | narrate | Per-screen narrative + self-critique | sonnet |
| `narration-coherence-auditor` | narrate | Cross-screen consistency | sonnet |
| `narration-developer-implementability` | narrate | MPA: implementability audit | sonnet |
| `narration-ux-completeness` | narrate | MPA: journey/state coverage | sonnet |
| `narration-edge-case-auditor` | narrate | MPA: unusual conditions | sonnet |
| `narration-validation-synthesis` | narrate | Merge MPA + PAL, prioritize fixes | opus |

### Templates (16)

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
| `design-feedback-template.md` | Design feedback format |
| `figma_context-template.md` | Figma context capture |
| `test-plan-template.md` | V-Model test plan |
| `screen-narrative-template.md` | Per-screen narrative structure |
| `ux-narrative-template.md` | Final UX narrative document |

## Configuration

| Config File | Command/Skill |
|-------------|--------------|
| `config/requirements-config.yaml` | `/requirements` |
| `config/specify-config.yaml` | `/specify` |
| `config/narration-config.yaml` | `/narrate`, design-narration skill |

Key configuration areas:
- Analysis mode parameters and MPA agent settings
- PAL ThinkDeep/Consensus model aliases and stance steering
- Question generation rules and PRD validation thresholds
- Self-critique thresholds and stall detection parameters
- Token budgets for context management

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
# For design narration:
rm design-narration/.narration-lock
```

### State file corruption
```bash
# For requirements:
rm requirements/.requirements-state.local.md
# For design narration:
rm design-narration/.narration-state.local.md
# Then re-run the command to reinitialize
```

### MCP tools unavailable
- Plugin automatically degrades — PAL consensus skipped, modes limited
- User is notified of degraded capability
- No manual intervention required

### Figma Desktop not detected
- Ensure Figma Desktop is open with the design file
- The Figma MCP plugin must be installed and running
- `/narrate` requires Figma Desktop MCP — it cannot run without it

## Version

- **Plugin Version:** 2.0.0
- **Schema Version:** 1

## License

MIT
