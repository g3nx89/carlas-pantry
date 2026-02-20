---
name: skill-analyzer
version: 0.1.0
description: >
  This skill should be used when the user asks to "review a skill", "analyze a skill",
  "audit skill quality", "check my skill", "evaluate this skill", "skill review",
  "improve my skill", "what's wrong with this skill", "review skill best practices",
  or when performing quality assessment of any Claude Code plugin skill. Provides
  multi-perspective analysis by dispatching parallel sub-agents, each loading a
  specialized evaluation lens (structure, prompt quality, context efficiency, writing
  quality, effectiveness, reasoning, architecture) to produce a consolidated
  modification plan. Optional lenses available for configuration quality, agent
  design, reasoning methodology, and escalation strategy.
version: 0.1.0
---

# Skill Analyzer — Multi-Perspective Skill Review

> **Compatibility**: Designed for Claude Code plugin skills following the SKILL.md + references/ pattern. Version 0.1.0 (February 2026).

## Overview

Skill Analyzer applies Multi-Perspective Analysis (MPA) to skill quality review. Instead of a single static checklist, it dispatches 7 parallel sub-agents — each loading a real skill as its "evaluation lens." Each lens sub-agent analyzes the target skill from its specialized perspective, produces a severity-classified analysis, and the coordinator synthesizes all findings into a deduplicated, prioritized modification plan. Four additional optional lenses are available for specialized analysis.

**Core principle**: Evaluation criteria come from living skills (not embedded checklists), so review standards evolve automatically as lens skills are updated.

## Quick Start

Provide the target skill path or name:

```
"Review the skill at plugins/meta-skills/skills/pal-mcp-mastery"
"Analyze the research-mcp-mastery skill quality"
"Check my skill at /path/to/skill-directory"
```

**Defaults**: 7 lenses, report written to `{target-skill-dir}/skill-review-report.md`, summary in conversation.

## Architecture

```
User request
  │
  ├─ 1. Validate target path (confirm SKILL.md exists)
  ├─ 2. Inventory target files (list all files + sizes)
  ├─ 3. Read target SKILL.md (parse name from frontmatter)
  ├─ 4. Load lens config (read references/lens-config.md)
  │
  ├─ 5. Dispatch 7 sub-agents IN PARALLEL (single message):
  │     ├─ Lens: Structure & Progressive Disclosure
  │     ├─ Lens: Prompt Engineering Quality
  │     ├─ Lens: Context Engineering Efficiency
  │     ├─ Lens: Writing Quality & Conciseness
  │     ├─ Lens: Overall Effectiveness
  │     ├─ Lens: Reasoning & Decomposition
  │     └─ Lens: Architecture & Coordination
  │     Each writes → {target-dir}/.skill-review/{lens-id}-analysis.md
  │
  ├─ 6. Read all analysis files from .skill-review/
  ├─ 7. Synthesize: dedup, prioritize, group, score
  ├─ 8. Write report → {target-dir}/skill-review-report.md
  └─ 9. Present summary in conversation
```

## Default Lenses

| # | Lens | Skill Reference | Primary Focus |
|---|------|-----------------|---------------|
| 1 | Structure | `plugin-dev:skill-development` | Frontmatter, triggers, progressive disclosure, file wiring |
| 2 | Prompt Quality | `customaize-agent:prompt-engineering` | Instruction clarity, LLM guidance, decision coverage |
| 3 | Context Efficiency | `customaize-agent:context-engineering` | Token management, progressive loading, attention placement |
| 4 | Writing Quality | `docs:write-concisely` | Conciseness, active voice, clarity, terminology |
| 5 | Effectiveness | `customaize-agent:agent-evaluation` | Purpose delivery, completeness, edge case coverage |
| 6 | Reasoning | `customaize-agent:thought-based-reasoning` | Reasoning chains, decomposition, verification, anti-patterns |
| 7 | Architecture | `sadd:multi-agent-patterns` | Coordination patterns, bottlenecks, failure propagation |

> Full lens definitions with fallback criteria: `references/lens-config.md`

## Workflow Steps

### Step 1: Validate Target

Confirm the target path exists and contains a `SKILL.md` file. If only a skill name is provided, search installed plugins for a matching skill directory.

### Step 2: Inventory Target

List all files in the target skill directory recursively. Record file names and approximate sizes. This inventory is passed to each sub-agent so it can selectively choose which reference files to read.

### Step 3: Read Target SKILL.md

Read the target's `SKILL.md`. Parse the `name:` field from frontmatter. Note the word count of the body.

### Step 4: Load Lens Configuration

Read `$CLAUDE_PLUGIN_ROOT/skills/skill-analyzer/references/lens-config.md` to load the 7 default lenses. Apply user overrides if provided (see Customization section).

### Step 5: Dispatch Lens Sub-Agents

Read the prompt template from `$CLAUDE_PLUGIN_ROOT/skills/skill-analyzer/references/sub-agent-prompt-template.md`.

Create the output directory: `{target-skill-dir}/.skill-review/`

Dispatch **7 `Task(subagent_type="general-purpose")` calls in a SINGLE message** for true parallelism. For each lens, fill the prompt template variables:
- `{LENS_ID}`, `{LENS_SKILL_REF}`, `{LENS_NAME}`, `{LENS_FOCUS}`, `{LENS_FALLBACK_CRITERIA}` — from lens-config.md
- `{TARGET_SKILL_PATH}`, `{TARGET_SKILL_NAME}`, `{TARGET_SKILL_FILES}` — from Steps 1-3
- `{OUTPUT_PATH}` — `{target-skill-dir}/.skill-review/{lens-id}-analysis.md`

Each sub-agent:
1. Invokes `Skill("{LENS_SKILL_REF}")` to load evaluation criteria
2. Falls back to embedded criteria if the Skill tool fails
3. Reads target SKILL.md + up to 3 reference files
4. Writes structured analysis to `{OUTPUT_PATH}`

### Step 6: Read Analysis Files

After all sub-agents complete, read all `.skill-review/{lens-id}-analysis.md` files. If any analysis is missing, note the lens as degraded.

### Step 7: Synthesize

Apply synthesis rules from `$CLAUDE_PLUGIN_ROOT/skills/skill-analyzer/references/synthesis-rules.md`:
- Deduplicate cross-lens findings (merge when same file + same issue)
- Escalate priority for cross-validated findings
- Group into 7 default categories (additional categories for optional lenses)
- Calculate per-lens scores (1-5) and weighted overall score
- Build modification plan table (CRITICAL first; cap per config)

### Step 8: Write Report

Write the consolidated report to `{target-skill-dir}/skill-review-report.md` following the template in `$CLAUDE_PLUGIN_ROOT/skills/skill-analyzer/references/report-template.md`.

### Step 9: Present Summary

Display a concise summary in conversation:
- Overall score with interpretation
- Scores by lens (table)
- Top 3 priority changes
- Number of findings by severity
- Path to full report

## Customization

Override the default lens list when invoking the skill:

- **Exclude lenses**: "Review the skill but skip the writing quality lens" → exclude `writing`
- **Add a lens**: "Also evaluate from a security perspective using `my-plugin:security-audit`"
- **Replace all**: "Use only structure and prompt lenses"
- **Add optional lens**: "Also check configuration quality" → adds `config` lens

### Pre-defined Optional Lenses

These specialized lenses are defined in `references/lens-config.md` and can be added via `additional_lenses`:

| Lens ID | Lens Name | Skill Reference | When to Add |
|---------|-----------|-----------------|-------------|
| `config` | Configuration & State Quality | `plugin-dev:plugin-settings` | Skills with hardcoded thresholds, paths, or persistent state |
| `agent-design` | Agent Design Quality | `plugin-dev:agent-development` | Skills that define or dispatch autonomous agents |
| `reasoning-method` | Reasoning Methodology Depth | `meta-skills:sequential-thinking-mastery` | Skills with complex decision trees or diagnostic workflows |
| `escalation` | Escalation & Model Selection | `meta-skills:deep-reasoning-escalation` | Skills that delegate to external reasoning models |

Constraints (see `config/skill-analyzer-config.yaml` for exact thresholds):
- Any installed skill can serve as a custom lens

> Full override mechanism: `references/lens-config.md` (Override Mechanism section)

## Graceful Degradation

| Scenario | Behavior |
|----------|----------|
| Lens skill not installed | Sub-agent uses fallback criteria from lens-config.md. Report notes "fallback used." |
| Sub-agent fails entirely | Lens marked as degraded. Analysis proceeds with remaining lenses. |
| Fewer than 3 lenses succeed | Warn that analysis coverage is limited. Report still generated. |
| Target has no references/ | Analysis proceeds on SKILL.md alone. Not reported as an issue unless SKILL.md exceeds the `skill_too_large_words` threshold in config. |

## Token Budget

| Component | Estimated Tokens |
|-----------|-----------------|
| Lens skill loading (per agent) | 2,000 – 5,000 |
| Target reading (per agent) | 2,000 – 5,000 |
| Analysis generation (per agent) | 3,000 – 5,000 |
| Overhead (per agent) | 2,000 – 3,000 |
| **Total per sub-agent** | **~10,000 – 20,000** |
| **Total for 7 parallel agents** | **~70,000 – 140,000** |

To reduce cost: exclude 2-3 lenses (~30-40% savings) or set selective reading to max 1 reference file per agent.

For large target skills (>5 reference files), sub-agents read only the 3 most relevant reference files by filename matching against their focus areas.

## Reference Files

| File | Purpose | When to Load |
|------|---------|--------------|
| `references/lens-config.md` | Lens definitions, fallback criteria, override mechanism | Step 4 (always) |
| `references/sub-agent-prompt-template.md` | Parameterized prompt for each sub-agent | Step 5 (always) |
| `references/synthesis-rules.md` | Dedup, priority, grouping, scoring rules | Step 7 (always) |
| `references/report-template.md` | Output report structure | Step 8 (always) |
| `examples/sample-review-report.md` | Completed example report | On request |
| `config/skill-analyzer-config.yaml` | Centralized thresholds and weights | Step 4, Step 7 |
| `references/README.md` | File usage table, sizes, cross-references | Maintainers only |

## Output Cleanup

The `.skill-review/` directory contains intermediate lens analysis files. These are preserved for reference after report generation but can be safely deleted. Consider adding `.skill-review/` and `skill-review-report.md` to the target skill's `.gitignore` to avoid committing analysis artifacts.

## When NOT to Use

- **Quick feedback on a single aspect** — read the skill and give direct feedback instead
- **Non-skill files** — commands, agents, and hooks have different structures; this skill targets SKILL.md-based skills only
- **Skills without SKILL.md** — the analysis requires a valid SKILL.md as entry point
- **Token-constrained sessions** — the full 7-lens analysis uses ~70-140K tokens; use fewer lenses or direct review instead
