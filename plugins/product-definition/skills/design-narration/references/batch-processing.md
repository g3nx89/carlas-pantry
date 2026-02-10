---
stage: 2-batch
artifacts_written:
  - design-narration/screens/{nodeId}-{name}.md (per screen)
  - design-narration/screens/{nodeId}-{name}-summary.md (per screen)
  - design-narration/figma/{nodeId}-{name}.png (per screen)
  - design-narration/working/.consolidation-summary.md
  - design-narration/working/BATCH-QUESTIONS-{NNN}.md (per cycle)
---

# Batch Processing Protocol (Stage 2-BATCH)

> Alternative to Stage 2's interactive per-screen loop. Processes all screens in batch cycles:
> analyze all → consolidate questions → pause for user answers → refine → repeat until convergence.
>
> **Entry condition:** `workflow_mode == "batch"` in state file (set during Stage 1 setup).
> **Exit condition:** All screens at GOOD threshold with zero pending questions, or user accepts current state.

## CRITICAL RULES (must follow)

1. **Sequential analysis, not parallel**: Process screens one at a time in Figma page order. Each screen benefits from patterns accumulated from prior screens.
2. **Consolidate before presenting**: Never show raw per-screen questions. Always run the question consolidator to dedup, detect conflicts, and group.
3. **Complete answers required**: Do not proceed to refinement if any question is unanswered. Notify user and re-pause.
4. **Cycle state is checkpoint-safe**: Update state after every screen analysis and after consolidation. Crashes resume from last completed screen.
5. **Coordinator never talks to users**: Return consolidated questions via summary; orchestrator writes the BATCH-QUESTIONS document and mediates all user interaction.

---

## Step 2B.0: Validate Batch Inputs

```
READ state file
VERIFY: workflow_mode == "batch"
VERIFY: batch_mode section exists in state

READ batch_mode.screens_input_document
VERIFY: file exists and is parseable

VERIFY: batch_mode.figma_page_node_id is set
VERIFY: screens[] array is populated (matched during Stage 1)

IF any verification fails:
    SET batch_mode.status = "analyzing"  (allow recovery to re-attempt)
    LOG error per references/error-handling.md
    STOP with BLOCKING error
```

---

## Step 2B.1: Batch Analysis (Sequential)

Process all screens sequentially, accumulating patterns:

```
READ config: batch_mode.working_directory
READ config: token_budgets.screen_description_max_lines
READ config: token_budgets.patterns_yaml_max_lines
READ config: token_budgets.qa_history_max_lines

SET accumulated_patterns = state.patterns (or empty if first cycle)
SET pending_questions = []
SET qa_history = [] (from decisions_audit_trail if cycle > 1)

FOR each screen in state.screens[] (ordered by Figma page position):
    IF screen.status == "signed_off":
        SKIP (already completed in prior cycle)

    UPDATE state: screen.status = "in_progress"
    UPDATE state: batch_mode.status = "analyzing"
    CHECKPOINT state (per references/checkpoint-protocol.md)

    # Extract textual description for this screen
    PARSE screen description from batch_mode.screens_input_document
        WHERE screen name matches screen.name
    TRUNCATE to screen_description_max_lines

    # Prepare context variables
    COMPILE patterns_yaml from accumulated_patterns
        TRUNCATE to patterns_yaml_max_lines
    COMPILE qa_history_summary from qa_history
        TRUNCATE to qa_history_max_lines

    # Dispatch screen analyzer
    DISPATCH narration-screen-analyzer via Task(subagent_type="narration-screen-analyzer"):
        prompt includes:
            - NODE_ID: screen.node_id
            - SCREEN_NAME: screen.name
            - ENTRY_TYPE: "batch_analysis"
            - SCREEN_DESCRIPTION: {parsed textual description}
            - CONTEXT_DOC_PATH: state.context_document (if exists)
            - PATTERNS_YAML: {compiled patterns}
            - QA_HISTORY_SUMMARY: {compiled history}
            - Reference to critique-rubric.md
            - Reference to screen-narrative-template.md

    READ analyzer summary file
    IF summary.status == "error":
        LOG error, SET screen.status = "pending"
        CONTINUE to next screen (do not halt batch)

    # Collect results
    EXTRACT questions from summary → APPEND to pending_questions[]
    EXTRACT patterns from summary → MERGE into accumulated_patterns
    UPDATE state: screen critique_scores, narrative_file, screenshot_file
    UPDATE state: screen.status = "described"
    UPDATE state: screen.refinement_rounds += 1 (if cycle > 1)
    UPDATE state: batch_mode.screens_analyzed += 1
    CHECKPOINT state
```

---

## Step 2B.2: Question Consolidation

After all screens are analyzed, consolidate questions:

```
UPDATE state: batch_mode.status = "consolidating"
CHECKPOINT state

READ config: batch_mode.questions_soft_cap_per_cycle
READ config: token_budgets.batch_consolidation_context_max_lines

# Compile all pending questions with screen tags
COMPILE pending_questions_formatted:
    FOR each question in pending_questions[]:
        INCLUDE: screen_name, question_id, dimension, question_text, options[]

# Include prior cycle answers (if any) for the consolidator to avoid re-asking
COMPILE prior_answers from decisions_audit_trail

# Dispatch question consolidator
DISPATCH narration-question-consolidator via Task(subagent_type="narration-question-consolidator"):
    prompt includes:
        - PENDING_QUESTIONS: {pending_questions_formatted}
        - SCREEN_NAMES: {ordered list of screen names}
        - PRIOR_ANSWERS: {prior_answers}
        - SOFT_CAP: {questions_soft_cap_per_cycle}

IF consolidator dispatch failed OR design-narration/working/.consolidation-summary.md does not exist:
    LOG error per references/error-handling.md
    PRESENT via orchestrator AskUserQuestion:
        question: "Question consolidation failed. How to proceed?"
        options:
            - "Retry consolidation"
            - "Skip consolidation — present raw questions grouped by screen"
            - "Stop workflow"
    IF "Retry": re-dispatch consolidator (repeat DISPATCH above)
    IF "Skip": write BATCH-QUESTIONS with raw questions (no dedup), set dedup_stats.reduction_pct = 0
    IF "Stop": STOP workflow, preserve all work

READ consolidator output: design-narration/working/.consolidation-summary.md
EXTRACT from YAML frontmatter:
    - consolidated_question_count
    - reduction_pct
    - cross_cutting_count
    - conflict_count
    - screen_specific_count
    - soft_cap_exceeded
    - tier_split (if applicable)

UPDATE state: batch_mode.dedup_stats
CHECKPOINT state
```

---

## Step 2B.3: Write BATCH-QUESTIONS Document

```
SET cycle_num = state.batch_mode.cycle
SET questions_file = batch_mode.working_directory + "/BATCH-QUESTIONS-" + zero_pad(cycle_num, 3) + ".md"

READ consolidation summary body (markdown sections)
READ template: $CLAUDE_PLUGIN_ROOT/templates/batch-questions-template.md

ASSEMBLE BATCH-QUESTIONS document:
    - Fill template header: CYCLE_NUMBER, PRODUCT_NAME, SCREEN_COUNT, QUESTION_COUNT, dedup stats
    - Section 1: Cross-cutting [CROSS] questions from consolidation
    - Section 2: Conflict [CONFLICT] questions from consolidation
    - Section 3: Screen-specific questions from consolidation (grouped by screen)
    - Each question: options table with Recommended marker, [ ] checkboxes, "Other" option
    - Response Summary table at bottom (all counts start at 0 answered)

WRITE to: design-narration/{questions_file}

UPDATE state:
    batch_mode.questions_file = questions_file
    batch_mode.questions_pending = consolidated_question_count
CHECKPOINT state
```

---

## Step 2B.4: Pause for User

```
UPDATE state: batch_mode.status = "waiting_for_user"
CHECKPOINT state

RETURN to orchestrator with summary:
    status: needs-user-input
    message: |
        Batch questions for cycle {cycle_num} ready.
        {screens_analyzed}/{total_screens} screens analyzed.
        File: design-narration/{questions_file}
        {consolidated_question_count} questions ({reduction_pct}% reduction from consolidation)
        Answer all questions, then re-run: /narrate --batch
    questions_file: {questions_file}
    questions_pending: {consolidated_question_count}

# Orchestrator will:
# 1. Present the message to user via AskUserQuestion
# 2. EXIT the workflow (user answers offline)
```

---

## Step 2B.5: Read User Answers (on re-invocation)

When the skill is re-invoked and state shows `batch_mode.status == "waiting_for_user"`:

```
READ batch_mode.questions_file
PARSE document for [x] selections and "Other:" responses

COLLECT answers into user_answers[]:
    FOR each question section:
        FIND checkbox marked [x]
        IF "Other" is marked: extract user's free-text response
        RECORD: question_id, selected_option, screen_names_affected[]

VALIDATE completeness:
    COMPUTE unanswered = questions WHERE no [x] found
    IF unanswered > 0:
        NOTIFY user: "{N} questions unanswered in {questions_file}. Complete all questions before continuing."
        STOP (remain in waiting_for_user status)

# Record all answers in audit trail (append-only)
FOR each answer in user_answers[]:
    APPEND to decisions_audit_trail:
        id: "{question_id}"
        screen: "{screen_name}" (or "cross-cutting" for [CROSS] questions)
        question: "{question_text}"
        answer: "{selected_option_text}"
        cycle: {batch_mode.cycle}
        timestamp: "{ISO}"

UPDATE state: batch_mode.questions_answered_total += len(user_answers)
CHECKPOINT state
```

---

## Step 2B.6: Refine All Screens

Apply user answers to affected screens:

```
UPDATE state: batch_mode.status = "refining"
CHECKPOINT state

SET next_cycle_questions = []

# Determine which screens need refinement
COMPILE screens_to_refine:
    FOR each answer in user_answers[]:
        ADD each screen in answer.screen_names_affected[] to set

FOR each screen in screens_to_refine (in Figma page order):
    # Compile answers relevant to this screen
    FILTER user_answers WHERE screen in screen_names_affected[]

    # Prepare context
    COMPILE patterns_yaml from accumulated_patterns (current)
    COMPILE qa_history from decisions_audit_trail (all cycles)

    DISPATCH narration-screen-analyzer via Task(subagent_type="narration-screen-analyzer"):
        prompt includes:
            - NODE_ID: screen.node_id
            - SCREEN_NAME: screen.name
            - ENTRY_TYPE: "refinement"
            - FORMATTED_USER_ANSWERS: {filtered answers for this screen}
            - PATTERNS_YAML: {compiled patterns}
            - QA_HISTORY_SUMMARY: {compiled history}
            - Existing narrative_file path (for updating)
            - Reference to critique-rubric.md

    READ analyzer summary
    IF summary.status == "error":
        LOG error, CONTINUE to next screen

    EXTRACT new_questions from summary → APPEND to next_cycle_questions[]
    EXTRACT patterns → MERGE into accumulated_patterns
    UPDATE state: screen critique_scores (updated)
    UPDATE state: screen.refinement_rounds += 1

    # Handle decision revisions flagged by analyzer
    IF summary.decision_revisions is non-empty:
        # In batch mode, collect all revisions for orchestrator to present after refinement loop
        COLLECT revisions for post-refinement user confirmation

    CHECKPOINT state
```

---

## Step 2B.7: Convergence Check

After all screens are refined, check if another cycle is needed:

```
# Run consolidation on new questions (if any)
IF next_cycle_questions is non-empty:
    RUN Step 2B.2 consolidation on next_cycle_questions
    SET new_consolidated_count = consolidator.consolidated_question_count
ELSE:
    SET new_consolidated_count = 0

# Record cycle question count for trend tracking
APPEND new_consolidated_count to batch_mode.convergence.cycle_question_counts[]

# Count screens by score
SET screens_at_good = count(screens WHERE critique_scores.total >= good.min)
SET screens_below_good = count(screens WHERE critique_scores.total < good.min)
UPDATE state: batch_mode.convergence.screens_at_good = screens_at_good
UPDATE state: batch_mode.convergence.screens_below_good = screens_below_good

READ config: batch_mode.max_cycles
READ config: batch_mode.stall_detection.plateau_cycles

# Check convergence conditions
IF new_consolidated_count == 0 AND screens_at_good == total_screens:
    # Perfect convergence — all screens at GOOD, no new questions
    UPDATE state: batch_mode.status = "complete"
    CHECKPOINT state
    ADVANCE to Stage 3

ELSE IF new_consolidated_count == 0 AND screens_below_good > 0:
    # No new questions but some screens below GOOD — user must accept or intervene
    PRESENT via orchestrator AskUserQuestion:
        question: "{screens_below_good} screen(s) below GOOD threshold but no more questions to ask.
                   Proceed to coherence check, or flag screens for manual review?"
        options:
            - "Proceed — accept current quality"
            - "Flag below-GOOD screens for review and proceed"
    IF "Proceed": ADVANCE to Stage 3
    IF "Flag": SET flagged_for_review = true on below-GOOD screens, ADVANCE to Stage 3

ELSE IF batch_mode.cycle >= max_cycles:
    # Hard cap reached
    PRESENT via orchestrator AskUserQuestion:
        question: "Reached maximum batch cycles ({max_cycles}). {new_consolidated_count} questions remain.
                   Proceed with current narratives, or extend by 1 cycle?"
        options:
            - "Proceed — accept current state"
            - "Extend by 1 cycle"
            - "Stop workflow"
    IF "Proceed": ADVANCE to Stage 3
    IF "Extend": INCREMENT max_cycles by 1, continue to next cycle
    IF "Stop": STOP workflow, preserve all work

ELSE IF is_stalled(batch_mode.convergence.cycle_question_counts, plateau_cycles):
    # Stall detected — question count not decreasing
    PRESENT via orchestrator AskUserQuestion:
        question: "Question count is not decreasing (stall detected). This may indicate sparse screen
                   descriptions. Continue with another cycle, or proceed with current narratives?"
        options:
            - "Proceed — accept current state"
            - "Continue — try another cycle"
            - "I'll enhance my screen descriptions and restart"
    IF "Proceed": ADVANCE to Stage 3
    IF "Continue": continue to next cycle
    IF "Enhance": STOP workflow, preserve all work

ELSE:
    # Normal case — more questions, under cap, not stalled
    INCREMENT batch_mode.cycle
    WRITE new BATCH-QUESTIONS-{NNN+1}.md (Step 2B.3)
    GOTO Step 2B.4 (pause for user)
```

### Stall Detection Function

```
FUNCTION is_stalled(cycle_question_counts[], plateau_cycles):
    IF len(cycle_question_counts) < plateau_cycles + 1:
        RETURN false

    # Check if the last N counts are non-decreasing
    recent = cycle_question_counts[-(plateau_cycles + 1):]
    FOR i in range(1, len(recent)):
        IF recent[i] < recent[i-1]:
            RETURN false  # Counts are decreasing — not stalled
    RETURN true  # Counts flat or increasing
```

---

## Decision Revision Handling (Batch Mode)

When refinement (Step 2B.6) detects decision revisions:

```
AFTER refinement loop completes:

IF collected_revisions is non-empty:
    FOR each revision:
        PRESENT via orchestrator AskUserQuestion:
            question: "Conflict detected: '{original_answer}' (from {original_screen})
                       vs '{proposed_revision}' (from current refinement of {screen}).
                       Which should apply across all affected screens?"
            options:
                - "Keep original: {original_answer}"
                - "Use revision: {proposed_revision}"
                - "Let's discuss this"

        RECORD decision in audit_trail with revises pointer
        IF revision applied: re-flag affected screens for next cycle
```

---

## Checkpoint Triggers

Update state file at these points (per `references/checkpoint-protocol.md`):

1. After each screen analysis completes (2B.1)
2. After consolidation completes (2B.2)
3. After BATCH-QUESTIONS document is written (2B.3)
4. Before pausing for user (2B.4)
5. After reading and validating user answers (2B.5)
6. After each screen refinement completes (2B.6)
7. After convergence check (2B.7)

---

## Self-Verification

Before advancing to Stage 3:

1. All screens have status `described` or `signed_off` (none `pending` or `in_progress`)
2. `batch_mode.status == "complete"`
3. All user answers recorded in `decisions_audit_trail`
4. Accumulated patterns reflect all screen analyses
5. `batch_mode.convergence.cycle_question_counts` records every cycle
6. No orphan summary files (every summary has a matching narrative)

**Error handling:** For error classification and logging format, see `references/error-handling.md`.

## CRITICAL RULES REMINDER

1. Sequential analysis, not parallel — patterns accumulate across screens
2. Consolidate before presenting — always run question consolidator
3. Complete answers required — all questions must be answered before refinement
4. Cycle state is checkpoint-safe — crashes resume from last completed screen
5. Coordinator never talks to users — orchestrator mediates all interaction
