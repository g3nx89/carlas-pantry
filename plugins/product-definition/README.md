# Product Definition Plugin

A Claude Code plugin for transforming rough product drafts into finalized, non-technical PRDs through iterative file-based Q&A.

## Overview

This plugin provides an intelligent requirements refinement workflow that:

- **Transforms** rough product ideas into structured PRD documents
- **Uses file-based Q&A** for offline, asynchronous user responses
- **Provides 3+ options** per question with pros, cons, and recommendations
- **Supports 4 analysis modes** from rapid single-agent to full multi-model consensus
- **Extends existing PRDs** when detected (EXTEND mode)
- **Degrades gracefully** when MCP tools are unavailable

## Quick Start

```bash
# 1. Place your draft in requirements/draft/
# 2. Run the workflow
/product-definition:requirements

# 3. Answer questions in requirements/working/QUESTIONS-001.md
# 4. Re-run to continue
/product-definition:requirements
```

## Installation

### From Local Directory

```bash
claude plugins add /path/to/product-definition
```

### Enable the Plugin

```bash
claude plugins enable product-definition
```

## Command

### `/product-definition:requirements`

The main command that orchestrates the entire PRD refinement workflow.

**Usage:**
```bash
/product-definition:requirements
```

**Workflow:**
1. **Initialization** - Detects draft, creates workspace
2. **Mode Selection** - User chooses analysis depth
3. **Research (Optional)** - Generate research agenda for market analysis
4. **Question Generation** - Multi-perspective analysis creates questions
5. **User Response** - User answers questions in markdown files
6. **Gap Analysis** - Detects coverage gaps, may generate more questions
7. **PRD Validation** - Multi-model consensus on readiness
8. **PRD Generation** - Creates finalized non-technical PRD

## Analysis Modes

| Mode | Description | MCP Required | Cost/Round |
|------|-------------|--------------|------------|
| **Complete** | MPA (3 agents) + PAL ThinkDeep (9 calls) + Sequential | Yes | $0.80-1.50 |
| **Advanced** | MPA (3 agents) + PAL ThinkDeep (6 calls) | Yes | $0.50-0.80 |
| **Standard** | MPA (3 agents) only | No | $0.15-0.25 |
| **Rapid** | Single agent | No | $0.05-0.10 |

When MCP tools are unavailable, the plugin automatically limits available modes to Standard and Rapid.

## Directory Structure

The plugin creates and uses the following structure in your project:

```
requirements/
├── draft/                    # Place your drafts here
│   └── my-product-draft.md
├── working/                  # Generated question files
│   ├── QUESTIONS-001.md
│   └── QUESTIONS-002.md
├── research/                 # Optional research outputs
│   ├── questions/
│   └── reports/
├── PRD.md                    # Final output
├── decision-log.md           # Question → PRD traceability
└── .requirements-state.local.md  # Workflow state (do not edit)
```

## Draft Format

Place your draft in `requirements/draft/` using this structure:

```markdown
# Product Draft: [Product Name]

## Part 1: Essential Information
**Product Name:** [Name]
**One-liner:** [Single sentence describing the product]
**Target User:** [Who is this for?]
**Core Problem:** [What problem does it solve?]

## Part 2: Product Definition
**What this IS:**
- [Core capability 1]
- [Core capability 2]

**What this is NOT:**
- [Explicit exclusion 1]
- [Explicit exclusion 2]

## Part 3: Additional Details
[Any other context, inspiration, constraints, etc.]
```

## Answering Questions

Questions are written to `requirements/working/QUESTIONS-NNN.md` with this format:

```markdown
### Q-001: Primary Target Audience

**Question:** Who is the primary user persona for this product?

**Multi-Perspective Analysis:**
- Product Strategy: [insight]
- User Experience: [insight]
- Business Ops: [insight]

| # | Answer | Pro | Con | Recommendation |
|---|--------|-----|-----|----------------|
| A | **Young professionals** | Large market | Price sensitive | Recommended |
| B | Small business owners | Higher value | Smaller market | |
| C | Enterprise teams | High revenue | Long sales cycle | |

**Your choice:**
- [x] A. Young professionals (Recommended)
- [ ] B. Small business owners
- [ ] C. Enterprise teams
- [ ] D. Other: _________________
```

Mark your choice with `[x]` and re-run the workflow.

## MCP Dependencies

This plugin optionally uses:

| MCP Server | Purpose | Fallback |
|------------|---------|----------|
| `sequential-thinking` | Deep structured analysis | Standard reasoning |
| `pal` | Multi-model consensus | Single-model analysis |

If these tools are unavailable:
- Complete and Advanced modes become unavailable
- Standard and Rapid modes continue to work
- User is notified of degraded capability

## Plugin Components

### Agents (11)

| Agent | Purpose | Model |
|-------|---------|-------|
| `requirements-product-strategy` | Product/market questions | sonnet |
| `requirements-user-experience` | UX/persona questions | sonnet |
| `requirements-business-ops` | Operations questions | sonnet |
| `requirements-question-synthesis` | Merge & deduplicate | opus |
| `requirements-prd-generator` | PRD document creation | opus |
| `research-discovery-business` | Market research questions | sonnet |
| `research-discovery-technical` | Viability research | sonnet |
| `research-discovery-ux` | User research questions | sonnet |
| `research-question-synthesis` | Research agenda synthesis | opus |
| `question-classifier` | Route question types | haiku |
| `question-synthesis` | Generic question synthesis | opus |

### Templates (7)

- `draft-template.md` - User input format
- `prd-template.md` - PRD output structure
- `questions-template.md` - Question file format
- `decision-log-template.md` - Traceability log
- `research-synthesis-template.md` - Research findings
- `research-report-template.md` - Individual reports
- `.requirements-state-template.local.md` - Workflow state

## Configuration

See `config/requirements-config.yaml` for full configuration options including:

- Analysis mode parameters
- MPA agent settings
- PAL ThinkDeep/Consensus configuration
- Question generation rules
- PRD validation thresholds
- Git commit suggestions

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
rm requirements/.requirements-lock
```

### State file corruption
```bash
rm requirements/.requirements-state.local.md
/product-definition:requirements  # Reinitializes
```

### MCP tools unavailable
- Plugin automatically degrades to Standard/Rapid modes
- User is notified of limitation
- No manual intervention required

## Version

- **Plugin Version:** 1.0.0
- **Schema Version:** 1
- **Based on:** `/sdd:00-requirements` from Context Engineering Kit

## License

MIT
