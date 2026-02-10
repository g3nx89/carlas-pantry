---
stage: setup
artifacts_written:
  - design-narration/context-input.md (optional)
  - design-narration/.narration-state.local.md (created or resumed)
  - design-narration/.narration-lock
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
        design-narration/figma/, design-narration/validation/
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

CALL mcp__figma-desktop__get_metadata() to detect selection
EXTRACT node_id and frame name
UPDATE state: workflow_mode = "interactive"
ADVANCE to Stage 2
```

### Step 1.5b: Batch Mode

```
# 1. Screen descriptions document
READ config: batch_mode.screens_document (default filename)
READ config: batch_mode.required_fields

PRESENT via AskUserQuestion:
    question: "Provide the path to your screen descriptions document
              (or press enter for default: design-narration/{screens_document})."
    options:
      - "Use default location"
      - "I'll provide a path"

READ and PARSE the screen descriptions document:
    SPLIT on "## Screen:" delimiters
    FOR each screen section:
        EXTRACT name (from header)
        EXTRACT required fields (purpose, elements, navigation)
        VALIDATE: all required_fields present
        IF any required field missing:
            NOTIFY user: "Screen '{name}' missing required field: {field}. Add it and re-run."
            STOP

# 2. Figma page selection
PRESENT via AskUserQuestion:
    question: "Select the Figma page containing all screen frames, then confirm."
    options:
      - "Ready — I've selected the page in Figma"

CALL mcp__figma-desktop__get_metadata() to get page structure
EXTRACT page_node_id
EXTRACT child frames[] (direct children of the page that are FRAME type)

# 3. Match frame names to screen descriptions
READ config: batch_mode.frame_matching

FOR each screen_description:
    FIND best matching frame:
        - Exact match (case-insensitive if config.case_insensitive)
        - After stripping config.strip_prefixes from both sides
        - Fuzzy match: normalize whitespace, hyphens, underscores

COMPILE match_table:
    | # | Screen Description | Figma Frame | Node ID | Match Type |
    |---|-------------------|-------------|---------|------------|
    For each: description name, matched frame name (or "UNMATCHED"), node_id, exact/fuzzy/unmatched

IDENTIFY:
    - unmatched_descriptions: descriptions with no Figma frame match
    - unmatched_frames: Figma frames with no description match

IF unmatched_descriptions or unmatched_frames:
    PRESENT match table via AskUserQuestion:
        question: "Some screens couldn't be matched automatically.
                   {N} descriptions unmatched, {M} Figma frames unmatched.
                   Review the match table and confirm or adjust."
        options:
          - "Matches look correct — proceed with matched screens only"
          - "I'll fix names and re-run"
          - "Include unmatched Figma frames (analyze without descriptions)"
    IF "fix names": STOP
    IF "include unmatched": add unmatched frames to screens[] with source = "figma"
ELSE:
    PRESENT match table via AskUserQuestion:
        question: "All {N} screens matched successfully. Confirm to proceed."
        options:
          - "Confirmed — proceed"

# 4. Initialize batch state
UPDATE state: workflow_mode = "batch"
CREATE design-narration/working/ directory

FOR each matched screen (in Figma page order):
    APPEND to state.screens[]:
        node_id: {frame_node_id}
        name: {screen_name}
        source: "batch_description+figma" (or "figma" if no description)
        status: "pending"
        ...  (other fields per state-schema.md defaults)

UPDATE state: batch_mode section:
    screens_input_document: {path to descriptions file}
    figma_page_node_id: {page_node_id}
    cycle: 1
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

1. Figma MCP confirmed available
2. Lock file created with timestamp
3. State file exists (created or resumed)
4. Directories exist (screens/, figma/, validation/)
5. **Interactive:** First screen node_id extracted from Figma
6. **Batch:** Screen descriptions parsed, Figma frames matched, working/ directory created

**Error handling:** For error classification and logging format, see `references/error-handling.md`.

## CRITICAL RULES REMINDER

1. Figma MCP is a hard requirement
2. Lock before modifying state
3. Onboarding digest for resumed sessions
