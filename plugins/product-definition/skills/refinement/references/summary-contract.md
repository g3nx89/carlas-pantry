# Summary Contract

> Defines the schema for all coordinator summaries and the Interactive Pause protocol.
> Referenced by orchestrator-loop.md dispatch template and all stage files.

---

## Summary File Convention

All coordinator summaries follow this convention:

**Path:** `requirements/.stage-summaries/stage-{N}-summary.md`

```yaml
---
stage: "{stage_name}"
stage_number: {N}
status: completed | needs-user-input | failed
checkpoint: "{CHECKPOINT_NAME}"
artifacts_written:
  - "{path/to/artifact}"
summary: "{1-2 sentence description of what happened}"
flags:
  round_number: {N}
  analysis_mode: "{mode}"
  questions_count: {N}           # Stage 3 only
  thinkdeep_calls: {N}           # Stage 3 only (0 if skipped)
  thinkdeep_completion_pct: {N}  # Stage 3 only (actual/expected %)
  block_reason: null | "{reason}"
  pause_type: null | "exit_cli" | "interactive"
  next_action: null | "loop_questions" | "loop_research" | "proceed"
---

## Context for Next Stage
{What the next coordinator needs to know}
```

---

## Example (Filled Stage 3 Summary)

```yaml
---
stage: "analysis-questions"
stage_number: 3
status: completed
checkpoint: ANALYSIS_QUESTIONS
artifacts_written:
  - requirements/analysis/thinkdeep-insights.md
  - requirements/analysis/questions-product-strategist.md
  - requirements/analysis/questions-ux-researcher.md
  - requirements/analysis/questions-functional-analyst.md
  - requirements/working/QUESTIONS-001.md
summary: "Generated 14 questions across 3 panel members (product-focused) with ThinkDeep insights from 27 calls"
flags:
  round_number: 1
  questions_count: 14
  analysis_mode: "complete"
  panel_preset: "product-focused"
  panel_members_count: 3
  panel_member_ids: ["product-strategist", "ux-researcher", "functional-analyst"]
  thinkdeep_calls: 27
  thinkdeep_completion_pct: 100
---

## Context for Next Stage
Round 1 generated 14 questions covering all 10 PRD sections. ThinkDeep convergent
insight: all 3 models flagged revenue model uncertainty as CRITICAL priority.
3 CRITICAL questions, 5 HIGH, 6 MEDIUM. User must fill QUESTIONS-001.md.
```

> **Note:** `panel_member_ids` are dynamic -- composed at runtime by the Panel Builder agent from the perspective registry in config. They are not hardcoded agent names.

---

## Interactive Pause Schema

When coordinators need user input, they encode the question in `flags` for the orchestrator to relay via `AskUserQuestion`:

```yaml
flags:
  pause_type: "interactive" | "exit_cli"
  block_reason: "{human-readable reason for pause}"
  question_context:           # Present when pause_type = interactive
    question: "{question text}"
    header: "{short label, max 12 chars}"
    options:
      - label: "{option label}"
        description: "{option description}"
  next_action_map:            # Optional -- maps option labels to next_action values
    "{option label}": "loop_questions" | "loop_research" | "proceed"
```

- `exit_cli`: orchestrator updates state, displays `block_reason`, and TERMINATES (user works offline)
- `interactive`: orchestrator reads `question_context`, calls `AskUserQuestion`, then re-dispatches the stage or maps the answer via `next_action_map`
