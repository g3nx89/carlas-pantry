# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Carla's Pantry is a marketplace/collection of Claude Code plugins focused on product development workflows. Each plugin is a self-contained directory under `plugins/`.

## Repository Structure

```
carlas-pantry/
├── plugins/
│   └── {plugin-name}/
│       ├── .claude-plugin/plugin.json   # Required manifest
│       ├── commands/                     # Slash commands (*.md)
│       ├── agents/                       # Subagent definitions (*.md)
│       ├── templates/                    # Document templates
│       ├── config/                       # Plugin configuration
│       └── README.md                     # Plugin docs
└── README.md                             # Marketplace index
```

## Plugin Development

### Creating a New Plugin

1. Create directory: `plugins/{plugin-name}/`
2. Add manifest: `.claude-plugin/plugin.json`
3. Add at least one command in `commands/`
4. Document in `README.md`

### Plugin Manifest Format

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "What this plugin does",
  "author": { "name": "Author Name" },
  "keywords": ["relevant", "tags"],
  "license": "MIT"
}
```

### Testing Plugins Locally

```bash
claude plugins add ./plugins/plugin-name
claude plugins enable plugin-name
```

## Conventions

- Plugin names: lowercase with hyphens (`product-definition`)
- Commands: `commands/{command-name}.md` with YAML frontmatter
- Agents: `agents/{domain}-{role}.md` with model specification
- Use `$CLAUDE_PLUGIN_ROOT` for plugin-relative paths in prompts

## Plugin Architecture Patterns

### Multi-Phase Workflows
- Embed tightly-coupled functionality as phases within a single skill rather than separate skills
- Separate skills for coupled workflows create state sync issues
- Use checkpoints for resumability: `PHASE_NAME` markers in state files

### Multi-Perspective Analysis (MPA)
- Launch 2-3 specialized agents in parallel for complex analysis
- Define agent variants, mode availability, and output synthesis rules
- Examples: architecture analysis with multiple approaches, QA review with different focus areas

### Configuration Management
- Single source of truth: all config values in `config/{plugin}-config.yaml`
- Document that external model names are configurable placeholders
- Use explicit comparison operators for thresholds (>=, <, not ambiguous boundaries)

### Template Design
- Include glossary sections for non-technical users
- Add evidence/sign-off sections where approval is needed
- Cross-reference related templates

### Quality Verification Checklist
- [ ] No duplicate reference files across skills
- [ ] Config values sourced from single location
- [ ] Related phases have reconciliation steps
- [ ] Templates have glossaries for non-technical users
- [ ] Agents specify model and mode availability in frontmatter
- [ ] Cross-references between skills point to existing skill directories
- [ ] All reference files listed in skill's Reference Map table AND `references/README.md` (usage table, file sizes, cross-references)
- [ ] No project-specific hardcoded content in generic skills
- [ ] Canonical definitions (Priority, Severity) live in SKILL.md, not duplicated in references
- [ ] Cross-plugin artifact names match the producer's actual output (grep to verify)
- [ ] Agent prompt templates list all variables explicitly (no "Same as X" shortcuts)
- [ ] External content injection features define token budgets in config (per-source, per-phase, per-agent)
- [ ] Agent awareness hints added to all agents that may receive optional injected content

### Git Workflow for Multi-Plugin Commits

When committing changes scoped to a single plugin:
- **Stage by explicit file path**, not `git add .` or directory globs — untracked files from other plugins can silently infiltrate the index
- **Always verify** with `git diff --cached --stat` before committing; check that no files outside the target plugin appear
- **Unstaging new files**: `git reset HEAD -- <file>` silently does nothing for files that have no HEAD version (i.e., never-committed files). Use `git rm --cached <file>` to remove newly staged but untracked files from the index
- **After `git reset --soft HEAD~1`**: new files from the undone commit remain in the index. Use `git rm --cached` (not `git reset HEAD`) to clean them out
- **Commit grouping**: In this mono-repo, prefer one commit per plugin to keep changes reviewable and independently revertable

### Command → Skill Migration

When a command outgrows its single-file format or multiple coupled commands need unification:
1. Lift command logic into `skills/{name}/SKILL.md` + `references/` directory
2. Merge coupled commands into a single skill (e.g., implement + document → implement skill with 5 stages)
3. Audit `agents/` directory — unused agents from command-era often remain; remove any not referenced by the new skill
4. Run multi-agent critique to catch contradictions, missing config, version misalignment
5. If workflow has 3+ stages, refactor to lean orchestrator delegation (see below)
- **Gotcha**: Legacy command files in `commands/` should be kept but marked as superseded (git tracks the deletion, but users may still reference old paths)

### Lean Orchestrator Delegation

Proven pattern for multi-stage plugin workflows (used in product-planning and product-implementation):
- **SKILL.md as dispatch table** (<300 lines): stage list, critical rules, reference map — no procedural detail
- **Coordinators dispatched** via `Task(subagent_type="general-purpose")` with prompt pointing to stage reference file
- **Summary contract**: each coordinator writes a summary file with YAML frontmatter (`stage`, `status`, `artifacts_written`, `summary`, `flags`)
- **User interaction protocol**: coordinators NEVER interact with users directly; they set `status: needs-user-input` + `flags.block_reason` in summary; orchestrator mediates ALL user prompts via `AskUserQuestion`
- **Crash recovery**: if coordinator produces no summary, orchestrator reconstructs minimal summary from artifact state
- **Inline exception**: Stage 1 (lightweight setup) runs inline to avoid dispatch overhead; subsequent stages are delegated
- **Trade-off**: each coordinator dispatch adds latency overhead, accepted for significant context reduction and fault isolation

### Subagent-Delegated Context Injection

When a coordinator needs external content (plugin skills, MCP responses, large files) but loading it directly would bloat coordinator context:
- **Pattern**: Dispatch a throwaway `Task(general-purpose)` subagent to read/process the source material and write a condensed output file (<3K tokens). Coordinator reads only the small output file, never the raw source
- **Token savings**: Significant reduction vs inline loading (typically 70%+ — raw content condensed to key findings only)
- **Rule**: Define max token budgets per source, per phase, and per agent in config — hardcoded limits in prose are not auditable
- **Anti-pattern**: Loading raw external content directly into coordinator or orchestrator context — causes context pollution and reduces reasoning quality on the primary task

### Cross-Plugin Feature Parity

When adding a capability that spans multiple plugins (e.g., dev-skills integration across product-planning and product-implementation):
- **Design independently per plugin** — each plugin's implementation must respect its own architectural constraints (coordinator-delegated in planning vs orchestrator-transparent in implementation)
- **Grep sibling plugins** for shared concepts before finalizing design — naming, config keys, and domain mappings should align even if implementation differs
- **Config structure parity** — use similar YAML key names and structures across plugins for the same feature to reduce cognitive load

### Agent Awareness Hints

When adding external content injection (skill references, MCP context, cross-plugin artifacts) that agents may optionally receive:
- **Pattern**: Add a lightweight 5-10 line "Skill Awareness" or "Context Awareness" section to affected agent files, telling agents what optional sections may appear in their prompt and how to use them
- **Format**: "Your prompt may include a `## Domain Reference (from {source})` section. When present: [2-3 usage bullets]. If absent, proceed normally."
- **Rule**: Never hard-depend on injected content — agents must function identically when the optional section is absent

### Skill Optimization Patterns

When auditing or improving skills:
- **Hub-Spoke Model**: SKILL.md lean (<300 lines) with brief patterns; detail in `references/`. Enables progressive disclosure (metadata → skill body → references on-demand)
- **Deduplication**: Replace duplicate tables in references with cross-reference notes; surface unique reference content to SKILL.md if frequently needed
- **Multi-Agent Critique**: After bulk skill changes, run 3-judge critique (Requirements Validator, Solution Architect, Code Quality Reviewer) to catch broken references, orphaned files, and project-specific leakage
- **Common critique findings**: contradictions between rules (e.g., "skip tests" vs TDD enforcement), missing config centralization, unused agents in `agents/`, missing model specifications in agent frontmatter, version misalignment between SKILL.md and plugin.json

### State File Design

For skills that track execution progress across stages or sessions:
- **Version the schema**: include `version: N` in YAML frontmatter; implement auto-migration (v1→v2) with non-breaking field preservation
- **Lock protocol**: acquire at start, release at completion; define stale timeout in config (e.g., 60 min)
- **Immutable user decisions**: once a user decision is recorded (e.g., review outcome), never overwrite — only append new decisions
- **Checkpoint-based resume**: use `current_stage` + `stage_summaries` to determine entry point on re-invocation

### Cross-Plugin Artifact Contracts

When one plugin consumes artifacts produced by another (e.g., product-implementation consuming product-planning outputs):
- **Verify naming at the source**: grep the producer plugin's config/templates for exact file names, subdirectory names, and ID patterns before hardcoding them in the consumer — naming drift (e.g., `contracts.md` vs `contract.md`, `visual/` vs `uat/`) causes silent mismatches
- **Externalize handoff contracts to config**: put expected file names, subdirectory lists, and ID patterns in `config/{plugin}-config.yaml` so they're auditable and changeable without editing reference prose
- **Three-tier validation for handoff files**: Required (halt if missing) → Expected (warn if missing, continue) → Optional (silent if missing) — avoids blocking execution for non-critical artifacts while surfacing incomplete planning
- **Summary-as-context-bus**: when a bootstrapping stage loads many artifacts, compile a structured summary (table + 1-line-per-file) and pass it to all downstream stages — avoids each coordinator re-discovering and re-reading the same files

### Agent Prompt Variable Discipline

When defining prompt templates used by coordinators to dispatch agents:
- **Explicit variable lists per prompt** — never use "Same as X Prompt" shortcuts; each prompt template must list its own variables with types and sourcing instructions, because coordinators fill only what's explicitly listed
- **Fallback defaults for optional variables** — every variable that may not be available (e.g., from a conditional artifact) must specify fallback text (e.g., `"Not available"`) so the agent prompt is always well-formed
- **Cross-validate variable lists against agent behavior** — if a prompt instructs the agent to do something conditional (e.g., "cross-validate test IDs"), verify the variables needed for that behavior are in the variable list

### Instruction File Integrity

Rules for phase/stage instruction files read by coordinator subagents:

- **Step ordering**: Physical order in the file MUST match logical execution order — coordinators read top-to-bottom regardless of step numbers
- **Artifacts completeness**: Frontmatter `artifacts_written` must list ALL outputs including conditional ones — crash recovery depends on this
- **Config-to-implementation alignment**: Every config value promising runtime behavior (retries, timeouts, circuit breakers) must have corresponding implementation in a workflow file — "dead config" misleads users
- **DRY for repeated patterns**: When 3+ phase files share the same multi-step workflow (e.g., MCP dispatch + retry + synthesis), extract to a shared parameterized reference file instead of duplicating pseudocode
- **Explicit mode guards per step**: Every optional step needs its own mode check (`IF analysis_mode in {X, Y}`), even if the parent phase restricts modes in frontmatter
- **YAML range values**: Never use `3-5` for numeric ranges in YAML (parses as string) — use structured `min/max` instead
- **Section renumbering cascade**: When inserting a new numbered section (e.g., Section 1.6), all subsequent section numbers shift. After any section insert, grep ALL reference files for the old section numbers (e.g., `Section 1.7`, `Section 1.8`) and update them — cross-file references break silently
- **New reference file wiring**: When adding a new file to `references/`, register it in 3 places: (1) `references/README.md` file usage table + file sizes table + cross-references, (2) `SKILL.md` Reference Map table, (3) any stage files that should cross-reference the shared pattern. Missing wiring is the most common incomplete-task artifact when sessions exhaust context

---

*Last updated: 2026-02-19*
