# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Plugin Overview

This is a Claude Code plugin that transforms rough product drafts into finalized, non-technical PRDs through iterative file-based Q&A. Users place drafts in `requirements/draft/`, run `/product-definition:requirements`, answer questions in generated markdown files, and iterate until a complete PRD is produced.

## Plugin Testing

```bash
# Install locally for testing
claude plugins add /path/to/product-definition
claude plugins enable product-definition

# Run the main workflow
/product-definition:requirements
```

## Architecture

### Multi-Phase Workflow

The command `commands/requirements.md` orchestrates a 12-phase workflow with phases split into separate files under `commands/requirements/`:

1. **Setup (1-3):** Initialize workspace, detect state, select analysis mode
2. **Research (4-5):** Optional market/user research agenda generation
3. **Analysis (6-7):** Deep analysis (if MCP available), then MPA question generation
4. **Collection (8-10):** User responses, gap analysis, PRD readiness validation
5. **Output (11-12):** PRD generation/extension, completion

### Multi-Perspective Analysis (MPA) Pattern

Question generation uses 3 parallel specialist agents (`agents/requirements-*.md`):
- `requirements-product-strategy` - Market positioning, business model
- `requirements-user-experience` - Personas, user journeys
- `requirements-business-ops` - Operational viability, constraints

These run in parallel via the Task tool, then `requirements-question-synthesis` merges and deduplicates their output.

### Analysis Mode Hierarchy

| Mode | Description | MCP Required |
|------|-------------|--------------|
| Complete | MPA + PAL ThinkDeep (9 calls) + Sequential Thinking | Yes |
| Advanced | MPA + PAL ThinkDeep (6 calls) | Yes |
| Standard | MPA only | No |
| Rapid | Single agent | No |

The plugin gracefully degrades when MCP tools are unavailable—Complete/Advanced modes fall back to Standard.

### State Management

State is persisted in `requirements/.requirements-state.local.md` (YAML frontmatter + markdown). The workflow is resumable—user decisions in `user_decisions` are immutable and never re-asked.

### File-Based Q&A Pattern

Questions are written to `requirements/working/QUESTIONS-NNN.md` with structured format:
- Multi-perspective analysis section
- 3+ options per question with pros/cons and star ratings
- Checkbox format for user selection (`[x]` marks choice)

Users answer offline, then re-run the command to continue.

## Key Design Patterns

### PRD EXTEND Mode

When `PRD.md` exists, the workflow analyzes sections for completeness and extends rather than recreates. Never overwrite existing decisions.

### No Artificial Limits

Configuration explicitly sets `max_questions_total: null`—generate ALL questions necessary for PRD completeness. Users must answer 100% of questions (no skipping).

### Non-Technical Focus

PRDs must NOT contain technical implementation details (APIs, architecture, databases). The config includes `technical_keywords_forbidden` validation.

### PAL/ThinkDeep Integration

Phase 6 runs multi-model ThinkDeep analysis (gpt-5.2, gemini-3-pro-preview, grok-4) across perspectives (competitive, risk, contrarian). These insights inform MPA agent option generation.

## File Naming Conventions

- Agents: `agents/{domain}-{role}.md` (e.g., `requirements-product-strategy.md`)
- Phase modules: `commands/requirements/phase-NN-{name}.md`
- Templates: `templates/{purpose}-template.md`
- User workspace files: `requirements/working/QUESTIONS-{NNN}.md`
- State: `requirements/.requirements-state.local.md`

## Plugin Path Variable

Use `$CLAUDE_PLUGIN_ROOT` to reference plugin-relative paths in commands and agents. This resolves to the plugin installation directory.
