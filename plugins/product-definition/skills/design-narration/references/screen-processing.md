---
stage: screen-processing
artifacts_written:
  - design-narration/screens/{nodeId}-{name}.md
  - design-narration/figma/{nodeId}-{name}.png
  - design-narration/.narration-state.local.md (updated)
  - design-narration/.qa-digest.md (conditional — created after screens_before_compaction threshold)
---

# Screen Processing Loop (Stage 2)

> Orchestrator reads this file to manage the per-screen analysis loop.
> Each screen is processed by dispatching the `narration-screen-analyzer` agent.

## CRITICAL RULES (must follow)

1. **One screen at a time**: Process screens sequentially. Never dispatch multiple screen analyzers in parallel — user drives the order.
2. **Coordinator NEVER interacts with users**: All questions return via summary; orchestrator mediates via AskUserQuestion.
3. **Checkpoint after every screen**: Update state file with screen status, critique scores, and patterns BEFORE asking user to select next screen. Follow the exact procedure in `references/checkpoint-protocol.md`.
4. **No question limits**: Continue question rounds until critique score reaches GOOD threshold (per `self_critique.thresholds.good.min` in config) or user signs off.
5. **Decision revisions require user confirmation**: Never silently update a prior screen's narrative.

---

## Dispatch Template — 2A: Analysis

```
Task(subagent_type="general-purpose", prompt="""
You are a coordinator for Design Narration, Stage 2A (Analysis).
You MUST NOT interact with users directly. Write all output to files.
You MUST write a summary file upon completion (see Summary Contract below).

Read and execute the instructions in @$CLAUDE_PLUGIN_ROOT/agents/narration-screen-analyzer.md

## Context
- Node ID: {NODE_ID}
- Screen name: {SCREEN_NAME}
- Entry type: first_analysis
- Screens directory: design-narration/screens/
- Figma directory: design-narration/figma/
- Critique rubric: @$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/critique-rubric.md
- Screen template: @$CLAUDE_PLUGIN_ROOT/templates/screen-narrative-template.md

## Context Document
{IF context-input.md exists:}
Read: design-narration/context-input.md
{ELSE:}
No context document provided.

## Prior Patterns (from completed screens)
{PATTERNS_YAML}

## Q&A History (from all prior screens)
{QA_HISTORY_SUMMARY}

## Prior Screen Summaries
{COMPLETED_SCREENS_DIGEST}
""")
```

### Variable Sourcing

| Variable | Source | Default | Max Lines |
|----------|--------|---------|-----------|
| NODE_ID | User selection in Figma (orchestrator reads from get_metadata) | Required | — |
| SCREEN_NAME | From Figma frame name | Required | — |
| PATTERNS_YAML | State file `patterns` section | `"No prior patterns yet"` | 40 (per `token_budgets.patterns_yaml_max_lines`) |
| QA_HISTORY_SUMMARY | Compiled from completed screen files (Q&A sections) | `"No prior Q&A"` | 60 (per `token_budgets.qa_history_max_lines`) |
| COMPLETED_SCREENS_DIGEST | 1-line-per-screen table from completed narratives | `"First screen — no prior screens completed"` | 50 (per `token_budgets.completed_screens_digest_max_lines`) |

**Truncation:** When a variable exceeds its Max Lines budget, truncate oldest entries first, keeping the most recent screens. Append a note: `"[Truncated: {N} older entries omitted. See state file for full history.]"`

---

## Summary Contract — Analysis (2A)

The screen-analyzer coordinator MUST write a summary to `design-narration/screens/{nodeId}-{name}-summary.md`:

```yaml
---
screen_name: "{SCREEN_NAME}"
node_id: "{NODE_ID}"
status: needs-user-input | completed
narrative_file: "screens/{nodeId}-{name}.md"
screenshot_file: "figma/{nodeId}-{name}.png"
critique_scores:
  completeness: [1-4]
  interaction_clarity: [1-4]
  state_coverage: [1-4]
  navigation_context: [1-4]
  ambiguity: [1-4]
  total: [X]
questions:
  - category: "[BEHAVIOR|STATE|NAVIGATION|CONTENT|EDGE|ANIMATION]"
    question: "{question text}"
    options:
      - label: "{option} (Recommended)"
        description: "{rationale}"
      - label: "{option 2}"
        description: "{details}"
      - label: "Let's discuss this"
        description: "Open conversation about this topic"
decision_revisions: []
annotations_found: [list of annotation texts found in Figma]
---
## Context for Refinement
{Summary of what was found, what's strong, what needs user input}
```

---

## Orchestrator Q&A Mediation Loop

After receiving the 2A summary:

```
READ summary file

IF status == "completed" AND critique_scores.total >= self_critique.thresholds.good.min:
    SKIP questions, proceed to sign-off

IF status == "error":
    READ error_reason from summary
    PRESENT via AskUserQuestion:
        question: "Screen analysis failed: {error_reason}"
        options:
          - "Retry analysis for this screen"
          - "Skip this screen and continue"
          - "Stop workflow"
    IF "Retry": RE-DISPATCH 2A for same screen
    IF "Skip": MARK screen.status = "skipped" in state, proceed to next screen selection
    IF "Stop": EXIT workflow

IF questions is non-empty:
    WHILE questions remain:
        BATCH = next {maieutic_questions.max_per_batch} questions

        FOR each question in BATCH:
            ADD "Let's discuss this" option if not present

        PRESENT via AskUserQuestion

        FOR each answer:
            IF answer == "Let's discuss this":
                PROMPT user for freeform text input
                RECORD as custom answer
            ELSE:
                RECORD selected option

            CHECK: Does this answer contradict any prior Q&A?
            IF yes: ADD to pending_revisions

        SAVE answers to state file IMMEDIATELY after each batch

    DISPATCH 2B: Refinement (with collected answers)
```

---

## Dispatch Template — 2B: Refinement

```
Task(subagent_type="general-purpose", prompt="""
You are a coordinator for Design Narration, Stage 2B (Refinement).
You MUST NOT interact with users directly. Write all output to files.
You MUST write a summary file upon completion (see Summary Contract below).

Read and execute the instructions in @$CLAUDE_PLUGIN_ROOT/agents/narration-screen-analyzer.md

## Context
- Node ID: {NODE_ID}
- Screen name: {SCREEN_NAME}
- Entry type: refinement
- Narrative file: design-narration/screens/{NARRATIVE_FILE}
- Critique rubric: @$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/critique-rubric.md

## User Answers
{FORMATTED_USER_ANSWERS}

## Prior Patterns
{PATTERNS_YAML}

## Q&A History (including this screen's new answers)
{UPDATED_QA_HISTORY}
""")
```

### Variable Sourcing — 2B Refinement

| Variable | Source | Default | Max Lines |
|----------|--------|---------|-----------|
| NODE_ID | string — Figma node identifier from user's screen selection (same value used in 2A) | Required | — |
| SCREEN_NAME | string — Figma frame name extracted via `get_metadata` (same value used in 2A) | Required | — |
| NARRATIVE_FILE | From 2A summary `narrative_file` field | Required | — |
| FORMATTED_USER_ANSWERS | Collected from AskUserQuestion responses, formatted as `Q: ... A: ...` | Required | — |
| PATTERNS_YAML | State file `patterns` section (may have grown since 2A) | `"No prior patterns yet"` | 40 (per `token_budgets.patterns_yaml_max_lines`) |
| UPDATED_QA_HISTORY | Prior Q&A + this screen's new answers appended | `"No prior Q&A"` | 60 (per `token_budgets.qa_history_max_lines`) |

**Truncation:** Same rules as 2A Variable Sourcing — truncate oldest entries when exceeding Max Lines budget.

The refinement coordinator:
1. Reads existing narrative file
2. Incorporates user answers into the relevant sections
3. Re-runs self-critique
4. If score still below GOOD threshold (per `self_critique.thresholds.good.min` in config): generates new questions for remaining weak dimensions
5. Checks if any user answers contradict prior screen decisions → returns `decision_revisions`
6. Writes updated summary with new scores

---

## Orchestrator: Stall Detection (After 2B Refinement)

After each 2B refinement, check for stalled improvement:

```
READ new critique score from 2B summary
INCREMENT round_count for this screen

# Hard cap check
IF round_count >= self_critique.stall_detection.max_rounds_hard_cap (from config):
    PRESENT via AskUserQuestion:
        question: "Screen '{SCREEN_NAME}' has reached {round_count} refinement rounds
        (hard cap: {max_rounds_hard_cap}). Current score: {TOTAL}/20.
        How would you like to proceed?"

        options:
          - "Sign off on current narrative (Recommended)"
          - "Override: allow {self_critique.stall_detection.hard_cap_extension} more rounds"
          - "Flag for review and move on"

    HANDLE accordingly (sign-off / extend cap by hard_cap_extension from config / flag_for_review + advance)

# Plateau detection
IF score unchanged (improvement < self_critique.stall_detection.min_improvement)
   for self_critique.stall_detection.plateau_rounds consecutive rounds:
    PRESENT via AskUserQuestion:
        question: "Score for '{SCREEN_NAME}' has plateaued at {TOTAL}/20
        for {plateau_rounds} rounds. The remaining gaps may need direct user input."

        options:
          - "Sign off — this is good enough (Recommended)"
          - "Keep trying — I'll provide more detail"
          - "Flag for review and move on"

    IF "Sign off": PROCEED to sign-off
    IF "Keep trying": CONTINUE refinement (reset plateau counter)
    IF "Flag for review": SET screen.flagged_for_review = true, advance to next screen
```

---

## Orchestrator: Decision Revision Handling

After 2B completes, check for `decision_revisions`:

```
IF decision_revisions is non-empty:
    FOR each revision:
        PRESENT via AskUserQuestion:
            question: "REVISION: {original_question}
            Originally on '{original_screen}': {original_answer}
            Now on '{current_screen}', analysis suggests: {proposed_revision}
            Reason: {rationale}"

            options:
              - "Yes, revise to: {proposed_answer} (Recommended)"
              - "No, keep original"
              - "Let's discuss this"

        IF user confirms revision:
            UPDATE prior screen narrative file
            UPDATE state decision audit trail (append revision record)
            MARK original decision as superseded

        IF user rejects:
            RECORD rejection in audit trail
```

---

## Orchestrator: Screen Sign-off

After all questions resolved and critique score is satisfactory:

```
PRESENT via AskUserQuestion:
    question: "**Progress: {COMPLETED_COUNT} screen(s) completed.**

    Screen '{SCREEN_NAME}' narrative complete.
    Score: {TOTAL}/20 (C:{C}, I:{I}, S:{S}, N:{N}, A:{A})
    Proceed?"

    options:
      - "Approve and continue"
      - "Flag for review"
      - "Add a note"

IF "Add a note":
    PROMPT for freeform text
    APPEND to screen narrative as user annotation

IF "Flag for review":
    SET screen.flagged_for_review = true in state
```

---

## Orchestrator: Next Screen Selection

```
PRESENT via AskUserQuestion:
    question: "**{COMPLETED_COUNT} screen(s) completed so far.**

    Select the next screen to analyze in Figma Desktop, then confirm.
    Or indicate that all screens are done."

    options:
      - "Ready — I've selected the next screen"
      - "No more screens — proceed to coherence check"

IF "Ready":
    CALL mcp__figma-desktop__get_metadata() to detect selection
    EXTRACT node_id and frame name
    DISPATCH 2A for new screen

IF "No more screens":
    ADVANCE to Stage 3
```

---

## Pattern Accumulation

After each screen sign-off, update the `patterns` section in state:

```
READ completed screen narrative
EXTRACT:
  - Shared components (elements appearing on this + prior screens)
  - Navigation patterns (common navigation structures)
  - Naming conventions (button styles, section headers)
  - Interaction patterns (gestures and their result classes)
MERGE into state.patterns (deduplicate)
```

---

## Orchestrator Context Management

The orchestrator accumulates Q&A mediation history across screens. To prevent context bloat:

```
AFTER each screen sign-off:
    IF screens_completed >= orchestrator_context.screens_before_compaction (from config):
        COMPACT older screen Q&A into 1-line-per-screen digest:
            "{SCREEN_NAME}: {TOTAL}/20, {N} questions, key patterns: {top 2-3 patterns}"

        WRITE compacted digest to design-narration/.qa-digest.md
        USE compacted digest (not raw history) for QA_HISTORY_SUMMARY in subsequent 2A dispatches

    ELSE:
        CONTINUE passing full Q&A history as QA_HISTORY_SUMMARY
```

This ensures the orchestrator's context stays bounded even when processing 15+ screens, while preserving the full history in the state file for crash recovery.

---

## Session Resume — Onboarding Context

When the skill is re-invoked and screens have been completed, compile onboarding digest per the format defined in `references/setup-protocol.md` Step 1.4 (5-item structure: product context, screens table, patterns, decisions, current status).

```
PASS digest to next coordinator as COMPLETED_SCREENS_DIGEST
```

Maximum digest size: per `session_resume.max_digest_lines` in config. For screens exceeding `session_resume.screen_summarization_threshold`, summarize oldest screens to 1 line each.

---

## Self-Verification (MANDATORY before advancing to next screen)

Before allowing the user to pick the next screen, verify:

1. Screen narrative file exists at expected path
2. Screenshot file exists in figma/ directory
3. State file updated with screen status = `signed_off`
4. Critique scores populated (no null values)
5. All user answers recorded in screen file
6. Patterns section updated
7. Decision audit trail consistent (no orphan revision references)

**Error handling:** For error classification and logging format, see `references/error-handling.md`.

## CRITICAL RULES REMINDER

1. One screen at a time — user drives order
2. Coordinator NEVER interacts with users — orchestrator mediates
3. Checkpoint after every screen
4. No question limits
5. Decision revisions require user confirmation
