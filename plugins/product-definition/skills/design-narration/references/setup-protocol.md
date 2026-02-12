---
stage: setup
artifacts_written:
  - design-narration/context-input.md (optional)
  - design-narration/.narration-state.local.md (created or resumed)
  - design-narration/.narration-lock
  - design-narration/.figma-discovery.md (transient — overwritten each dispatch)
---

# Setup Protocol (Stage 1)

> Execute inline (no coordinator dispatch). This file details the setup steps
> summarized in SKILL.md Stage 1.

## CRITICAL RULES (must follow)

1. **Figma MCP is a hard requirement**: If `mcp__figma-desktop__get_metadata` is unavailable, STOP immediately.
2. **Lock before modifying state**: Acquire lock before any state file read/write.
3. **Onboarding digest for resumed sessions**: Compile completed-screens digest to pass to Stage 2 coordinators.

---

## Step 1.0b: Batch Mode Detection

```
CHECK if $ARGUMENTS contains "--batch"

IF "--batch" found:
    SET workflow_intent = "batch"
    NOTIFY user: "Batch mode detected. Will process all screens in consolidated Q&A cycles."
ELSE:
    SET workflow_intent = "interactive"
```

> This flag is used in Step 1.5 to branch between single-screen selection (interactive) and
> Figma page selection + screen descriptions parsing (batch).

---

## Step 1.0: Config Validation (MANDATORY)

Before any other setup step, validate that required config keys exist with valid values:

```
READ @$CLAUDE_PLUGIN_ROOT/config/narration-config.yaml

VALIDATE the following keys exist and have valid types:

| Config Key | Expected Type | Valid Range |
|-----------|---------------|-------------|
| self_critique.thresholds.good.min | integer | 1-20 |
| self_critique.thresholds.acceptable.min | integer | 1-20 |
| self_critique.stall_detection.plateau_rounds | integer | >= 1 |
| self_critique.stall_detection.min_improvement | integer | >= 0 |
| self_critique.stall_detection.max_rounds_hard_cap | integer | >= 1 |
| self_critique.stall_detection.hard_cap_extension | integer | >= 1 |
| maieutic_questions.max_per_batch | integer | >= 1 |
| state.lock_stale_timeout_minutes | integer | >= 1 |
| state.lock_freshness_check_minutes | integer | >= 1 |
| token_budgets.patterns_yaml_max_lines | integer | >= 10 |
| token_budgets.qa_history_max_lines | integer | >= 10 |
| token_budgets.completed_screens_digest_max_lines | integer | >= 10 |
| orchestrator_context.screens_before_compaction | integer | >= 2 |
| coherence.max_screens_per_dispatch | integer | >= 2 |
| validation.pal_consensus.enabled | boolean | true or false |
| validation.pal_consensus.minimum_models | integer | >= 1 |
| validation.pal_consensus.models[].model | string | non-empty, PAL model alias (run `listmodels` to verify) |
| validation.pal_consensus.models[].stance | string | one of: for, against, neutral |
| validation.pal_consensus.models[].stance_prompt | string or absent | optional, omit for neutral balanced evaluation |
| validation.synthesis.source_dominance_max_pct | integer | 1-100 |
| session_resume.max_digest_lines | integer | >= 10 |
| session_resume.per_screen_summary_max_lines | integer | >= 1 |
| session_resume.screen_summarization_threshold | integer | >= 2 |
| state.schema_version | integer | >= 1 |
| coherence.per_screen_digest_lines | integer | >= 1 |
| coherence.clink_enabled | boolean | true or false |
| coherence.clink_threshold | integer | >= 2 |
| coherence.clink_cli | string | non-empty, valid PAL CLI client name |
| coherence.clink_timeout_seconds | integer | >= 60 |
| screen_narrative.target_lines | integer | >= 20 |
| screen_narrative.max_lines | integer | > screen_narrative.target_lines |
| batch_mode.questions_soft_cap_per_cycle | integer | >= 1 |
| batch_mode.max_cycles | integer | >= 1 |
| batch_mode.stall_detection.plateau_cycles | integer | >= 1 |
| batch_mode.required_fields | array | non-empty |
| token_budgets.screen_description_max_lines | integer | >= 10 |
| token_budgets.batch_consolidation_context_max_lines | integer | >= 10 |
| batch_mode.frame_matching.case_insensitive | boolean | true or false |
| batch_mode.frame_matching.strip_prefixes | array | may be empty |
| batch_mode.result_handoff.strategy | string | "file-based" |
| batch_mode.result_handoff.refinement_dispatch | string | one of: parallel, sequential |
| batch_mode.result_handoff.completion_timeout_seconds | integer | >= 60 |
| batch_mode.result_handoff.minimal_response_instruction | boolean | true or false |
| validation.mpa.clink_implementability.enabled | boolean | true or false |
| validation.mpa.clink_implementability.cli_name | string | non-empty, valid PAL CLI client name |
| validation.mpa.clink_implementability.timeout_seconds | integer | >= 60 |
| validation.mpa.clink_implementability.model_hint | string or null | null or non-empty string (PAL model name) |
| validation.mpa.clink_implementability.use_thinking | boolean | true or false |
| coherence.clink_model | string | non-empty (exact Gemini model name) |
| coherence.clink_use_thinking | boolean | true or false |
| auto_resolve.enabled | boolean | true or false |
| auto_resolve.confidence_required | string | one of: high, medium, low |
| auto_resolve.sources | array | non-empty, valid source types: prior_answers, context_document, accumulated_patterns |
| auto_resolve.registry_file | string | non-empty, valid relative path |
| auto_resolve.include_in_report | boolean | true or false |
| auto_resolve.notify_user | boolean | true or false |

CROSS-KEY VALIDATIONS (after individual key checks):
- screen_narrative.max_lines > screen_narrative.target_lines (hard cap must exceed target)
- self_critique.thresholds.good.min > self_critique.thresholds.acceptable.min (good must be stricter)

IF any key is missing, has an invalid value, or a cross-key validation fails:
    STOP workflow.
    NOTIFY user: "Config validation failed: {key} is {missing|invalid}. Check narration-config.yaml."
```

---

## Step 1.1: Figma Desktop MCP Check

```
VERIFY mcp__figma-desktop__get_metadata is available

IF unavailable:
    NOTIFY user: "Figma Desktop MCP not detected. Ensure Figma Desktop is open with the Claude plugin active."
    STOP workflow.
```

---

## Step 1.2: Context Document (Optional)

```
PRESENT via AskUserQuestion:
    question: "Provide a context document (PRD, functional description, product brief)?
    This helps the analyzer understand screen purpose and domain vocabulary."

    options:
      - "Yes — I'll paste or reference a document"
      - "No — proceed without context document"

IF "Yes":
    PROMPT for document content or file path
    SAVE to design-narration/context-input.md
```

---

## Step 1.3: Lock Acquisition

```
LOCK_FILE = design-narration/.narration-lock

IF lock file exists AND age < lock_stale_timeout_minutes (from config):
    PRESENT via AskUserQuestion:
        question: "Another narration session may be active. Override?"
        options:
          - "Yes — override and continue"
          - "No — cancel"
    IF "No": STOP workflow

IF lock file exists AND age >= lock_stale_timeout_minutes:
    NOTIFY user: "Stale lock detected (>{lock_stale_timeout_minutes} min). Clearing and proceeding."

WRITE lock file with timestamp
```

> **Known limitation:** Lock acquisition is not atomic. If two sessions check simultaneously before either writes the lock, both may proceed. This is acceptable because Claude Code runs single-threaded per terminal — the lock protects against *forgotten sessions*, not concurrent access.



---

## Step 1.4: State Check

```
CHECK if design-narration/.narration-state.local.md exists

IF exists:
    READ state file
    RUN crash recovery check (see references/recovery-protocol.md)
    COMPILE onboarding context from completed screens:
        1. Product name + context document summary (2-3 sentences)
        2. Completed screens table: | # | Screen | Score | Key Patterns |
        3. Accumulated patterns (YAML block)
        4. Key decisions made (from audit trail, latest versions only)
        5. Current screen status (if mid-processing)
    NOTIFY user: "Resuming from {current_stage}. {N} screens completed."

IF not exists:
    CREATE directories: design-narration/, design-narration/screens/,
        design-narration/figma/, design-narration/validation/, design-narration/working/
    INITIALIZE state file per references/state-schema.md Initialization Template
```

---

## Step 1.5: Screen Selection

Branch based on `workflow_intent` from Step 1.0b:

### Step 1.5a: Interactive Mode (default)

```
PRESENT via AskUserQuestion:
    question: "Select the first screen to analyze in Figma Desktop, then confirm."

    options:
      - "Ready — I've selected a screen in Figma"

# Dispatch discovery agent to detect user's Figma selection
DISPATCH narration-figma-discovery via Task(subagent_type="general-purpose"):
    prompt includes:
        - Reference: @$CLAUDE_PLUGIN_ROOT/agents/narration-figma-discovery.md
        - DISCOVERY_MODE: "interactive_selection"
        - WORKING_DIR: "design-narration/"

READ design-narration/.figma-discovery.md
IF status == "error":
    PRESENT via AskUserQuestion:
        question: "Figma frame detection failed: {error_reason}"
        options:
            - "Retry — I'll re-select the screen"
            - "Stop workflow"
    IF "Retry": re-ask user to select, re-dispatch discovery agent
    IF "Stop": STOP workflow

EXTRACT node_id and frame_name from discovery output YAML frontmatter
UPDATE state: workflow_mode = "interactive"
ADVANCE to Stage 2
```

### Step 1.5b: Batch Mode

```
# 1. Screen descriptions document (optional)
READ config: batch_mode.screens_document (default filename)
READ config: batch_mode.required_fields
READ config: batch_mode.frame_matching

PRESENT via AskUserQuestion:
    question: "Do you have a screen descriptions document?
              This helps match Figma frames to your intended screen names and purposes."
    options:
      - "Yes — use default location (design-narration/{screens_document})"
      - "Yes — I'll provide a path"
      - "No — discover all frames from the Figma page without descriptions"

IF "default location":
    SET descriptions_path = "design-narration/{screens_document}"
    VERIFY file exists; IF not: NOTIFY and STOP
IF "provide a path":
    PROMPT for path
    SET descriptions_path = {user-provided path}
    VERIFY file exists; IF not: NOTIFY and STOP
IF "No":
    SET descriptions_path = null

# 2. Figma page selection
PRESENT via AskUserQuestion:
    question: "Select the Figma page containing all screen frames, then confirm."
    options:
      - "Ready — I've selected the page in Figma"

# 3. Dispatch discovery agent for batch page discovery
DISPATCH narration-figma-discovery via Task(subagent_type="general-purpose"):
    prompt includes:
        - Reference: @$CLAUDE_PLUGIN_ROOT/agents/narration-figma-discovery.md
        - DISCOVERY_MODE: "batch_page_discovery"
        - WORKING_DIR: "design-narration/"
        - SCREEN_DESCRIPTIONS_PATH: {descriptions_path} (or omit if null)
        - REQUIRED_FIELDS: {batch_mode.required_fields from config}
        - FRAME_MATCHING_CASE_INSENSITIVE: {from config}
        - FRAME_MATCHING_STRIP_PREFIXES: {from config}

READ design-narration/.figma-discovery.md
IF status == "error":
    PRESENT via AskUserQuestion:
        question: "Figma frame discovery failed: {error_reason}"
        options:
            - "Retry — I'll re-select the Figma page"
            - "Stop workflow"
    IF "Retry": re-ask user to select page, re-dispatch discovery agent
    IF "Stop": STOP workflow

EXTRACT from discovery output YAML frontmatter:
    page_node_id, total_frames_found, match_table (or frames_list),
    unmatched_descriptions, unmatched_frames, validation_errors

# 4. Handle validation errors from descriptions parsing
IF validation_errors is non-empty:
    NOTIFY user: "Screen descriptions validation issues: {validation_errors}"
    PRESENT via AskUserQuestion:
        question: "Some screen descriptions have missing required fields. Fix and re-run?"
        options:
            - "Fix and re-run"
            - "Proceed anyway with valid screens only"
    IF "Fix": STOP

# 5. Present match results for user confirmation
IF descriptions_path is not null:
    # Matching mode — show match table from discovery output
    READ match_table from discovery output

    IF unmatched_descriptions or unmatched_frames:
        PRESENT match table (from discovery output markdown body) via AskUserQuestion:
            question: "Some screens couldn't be matched automatically.
                       {unmatched_descriptions_count} descriptions unmatched,
                       {unmatched_frames_count} Figma frames unmatched.
                       Review the match table and confirm or adjust."
            options:
              - "Matches look correct — proceed with matched screens only"
              - "I'll fix names and re-run"
              - "Include unmatched Figma frames (analyze without descriptions)"
        IF "fix names": STOP
        IF "include unmatched": add unmatched frames to screens list with source = "figma"
    ELSE:
        PRESENT match table via AskUserQuestion:
            question: "All {matched_count} screens matched successfully. Confirm to proceed."
            options:
              - "Confirmed — proceed"
ELSE:
    # No descriptions — show frames list from discovery output
    READ frames_list from discovery output

    PRESENT frames list (from discovery output markdown body) via AskUserQuestion:
        question: "{total_frames_found} frames found on the Figma page.
                   All frames will be analyzed. Confirm to proceed."
        options:
          - "Confirmed — proceed with all frames"
          - "I'll provide a screen descriptions document first"
    IF "provide descriptions": STOP (user provides doc, re-runs)

# 6. Initialize batch state
UPDATE state: workflow_mode = "batch"

IF descriptions_path is not null:
    # Build screens[] from match_table
    FOR each entry in match_table WHERE match_type != "unmatched":
        APPEND to state.screens[]:
            node_id: {entry.node_id}
            name: {entry.screen_description}
            source: "batch_description+figma"
            status: "pending"
            ...  (other fields per state-schema.md defaults)
ELSE:
    # Build screens[] from frames_list
    FOR each frame in frames_list:
        APPEND to state.screens[]:
            node_id: {frame.node_id}
            name: {frame.name}
            source: "figma"
            status: "pending"
            ...  (other fields per state-schema.md defaults)

UPDATE state: batch_mode section:
    screens_input_document: {descriptions_path or null}
    figma_page_node_id: {page_node_id}
    cycle: 1
    screens_analyzed: 0
    status: "parsing"
    questions_file: null
    questions_pending: 0
    questions_answered_total: 0
    dedup_stats: { original: 0, consolidated: 0, reduction_pct: 0 }
    convergence:
      cycle_question_counts: []
      screens_at_good: 0
      screens_below_good: 0

CHECKPOINT state
ADVANCE to Stage 2-BATCH
```

---

## Self-Verification

Before advancing to Stage 2 (interactive) or Stage 2-BATCH (batch):

1. Config validated (all keys present and valid)
2. Figma MCP confirmed available
3. Lock file created with timestamp
4. State file exists (created or resumed)
5. Directories exist (screens/, figma/, validation/, working/)
6. Workflow mode resolved (`workflow_mode` set in state: "interactive" or "batch")
7. **Interactive:** Discovery agent produced valid output with node_id and frame_name
8. **Batch:** Discovery agent produced valid match table (or frames list), user confirmed, screens[] populated in state

**Error handling:** For error classification and logging format, see `references/error-handling.md`.

## CRITICAL RULES REMINDER

1. Figma MCP is a hard requirement
2. Lock before modifying state
3. Onboarding digest for resumed sessions
