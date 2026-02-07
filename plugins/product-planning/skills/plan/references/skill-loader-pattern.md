---
purpose: "Canonical pattern for dev-skills context loading via subagent delegation"
used_by: [phase-2, phase-4, phase-6b, phase-7, phase-9]
---

# Skill Loader Subagent Pattern

Phase coordinators delegate skill loading to a throwaway `Task(general-purpose)` subagent to avoid context pollution. The subagent invokes `Skill("dev-skills:{name}")`, extracts specified sections, writes a condensed context file, and exits. The coordinator reads only the small output file.

## Prerequisites

- `state.dev_skills.available == true` (set in Phase 1, Step 1.5c)
- `analysis_mode != "rapid"`
- Config: `config.dev_skills_integration.enabled == true`

## Subagent Dispatch Template

```
IF state.dev_skills.available AND analysis_mode != "rapid":

  DISPATCH Task(subagent_type="general-purpose", prompt="""
    You are a skill context loader for Phase {N} ({phase_name}).

    ## Input
    - Detected domains: {state.dev_skills.detected_domains}
    - Technology markers: {state.dev_skills.technology_markers}

    ## Process
    FOR each required skill listed below:
      1. Invoke Skill("dev-skills:{skill_name}")
      2. Extract ONLY the specified sections
      3. Condense to within the token LIMIT for that skill
      4. IF Skill() call fails -> log skill name in skills_failed list, continue

    ## Required Skills
    {phase_specific_skill_list_with_extract_instructions_and_limits}

    ## Output
    WRITE to: {FEATURE_DIR}/.phase-summaries/phase-{N}-skill-context.md

    FORMAT:
    ---
    phase: "{N}"
    skills_loaded: [list of successfully loaded skill names]
    skills_failed: [list of skills that failed to load]
    total_tokens_approx: {approximate token count}
    ---

    ## {skill-name}: {section title}
    [condensed content within limit]

    ## {next-skill-name}: {section title}
    [condensed content within limit]

    TOTAL BUDGET: {budget} tokens max
    IF any Skill() call fails -> log in skills_failed, continue with remaining
  """)
```

## Coordinator Usage (After Subagent Returns)

```
1. READ {FEATURE_DIR}/.phase-summaries/phase-{N}-skill-context.md
   IF file missing or empty -> proceed without skill context (graceful degradation)

2. FOR each specialist agent prompt in this phase:
   INJECT relevant sections as:
   "## Domain Reference (from dev-skills)
   {matching section content from skill-context.md}"
   NOTE: Header name may vary per agent (e.g., "## Task Quality Standards (from dev-skills)" for tech-lead in Phase 9)

3. Respect per-agent injection limit:
   max_injected_per_agent: 1500 tokens (from config)
```

## Parallel Dispatch

When possible, dispatch the skill loader subagent IN PARALLEL with other prep work:
- Phase 2: Parallel with code-explorer and researcher agents
- Phase 4: Parallel with Research MCP queries (Step 4.0)
- Phase 6b: Sequential (short phase, minimal benefit from parallelism)
- Phase 7: Parallel with Research MCP queries (Step 7.1b)
- Phase 9: Sequential (runs before tech-lead dispatch)

## Graceful Degradation

| Condition | Behavior |
|-----------|----------|
| `state.dev_skills.available == false` | Skip skill loader entirely |
| `analysis_mode == "rapid"` | Skip skill loader entirely |
| Individual Skill() call fails | Log in `skills_failed`, continue with others |
| Skill-context.md file missing after dispatch | Proceed without skill context, log warning |
| All Skill() calls fail | Write empty context file with all skills in `skills_failed` |

## Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Invoke Skill() directly in coordinator | Context pollution (~5-15K tokens) | Always delegate to subagent |
| Load skills in Rapid mode | Unnecessary latency for simple features | Skip via mode guard |
| Exceed per-phase token budget | Coordinator context bloat | Enforce limits in loader prompt |
| Load skills not relevant to detected domains | Wasted tokens and latency | Filter by `state.dev_skills.detected_domains` |
| Skip domain detection in Phase 1 | All phases load max skills | Always run Step 1.5c |
| Cache skill content across phases | Stale if skills update between sessions | Load fresh per phase |

## Phase-Specific Parameters

| Phase | Budget | Parallel With | Key Skills |
|-------|--------|---------------|------------|
| 2 | 2500 | code-explorer, researcher agents | a11y, mobile, figma (conditional) |
| 4 | 3000 | Research MCP queries (Step 4.0) | api-patterns, database-design, c4, frontend (conditional) |
| 6b | 2000 | N/A (sequential) | clean-code, api-patterns (security) |
| 7 | 2000 | Research MCP queries (Step 7.1b) | qa-test-planner, accessibility-auditor (conditional) |
| 9 | 800 | N/A (sequential) | clean-code |
