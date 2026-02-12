---
stage: stage-4-clarification
artifacts_written:
  - specs/{FEATURE_DIR}/spec.md (updated)
  - specs/{FEATURE_DIR}/clarification-questions.md (created)
  - specs/{FEATURE_DIR}/clarification-report.md (created, after answers parsed)
  - specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md (conditional)
  - specs/{FEATURE_DIR}/analysis/mpa-edgecases.md (conditional)
  - specs/{FEATURE_DIR}/analysis/mpa-triangulation.md (conditional)
---

# Stage 4: Edge Cases & Clarification (Coordinator)

> This stage discovers edge cases via multi-model ThinkDeep, generates all clarification
> questions (with auto-resolve filtering), writes them to a file for offline user editing,
> then — on re-entry — parses answers and updates the spec.

## CRITICAL RULES (must follow — failure-prevention)

1. **No question limits**: Generate ALL questions needed — no artificial caps
2. **Never re-ask**: Questions from `user_decisions.clarifications` are IMMUTABLE — check before generating
3. **File-based clarification**: Write ALL questions to `clarification-questions.md` — NO AskUserQuestion calls for clarification
4. **Edge case severity boost**: 2+ models agree = MEDIUM->HIGH, 3/3 = HIGH->CRITICAL
5. **CRITICAL/HIGH edge cases**: Auto-inject as clarification questions
6. **NEVER interact with users directly**: Return `status: needs-user-input, pause_type: file_based` after writing question file
7. **Spec updates additive only**: ONLY add/refine requirements, NEVER remove existing ones

## Re-Entry Handling

```
IF ENTRY_TYPE == "re_entry_after_user_input":
    # User has edited clarification-questions.md — parse and continue
    SKIP to Step 4.3 (Parse Answers)
ELSE:
    # First entry — generate questions
    PROCEED to Step 4.1
```

## Step 4.1: MPA-EdgeCases ThinkDeep (Optional)

**Check:** `thinkdeep.integrations.edge_cases.enabled` in config AND PAL_AVAILABLE

**If enabled:**

Load execution pattern from: `@$CLAUDE_PLUGIN_ROOT/skills/feature-specify/references/thinkdeep-patterns.md` -> Integration 2: Edge Cases

Execute parallel ThinkDeep with 3 models:
- pro: security & performance focus (thinking_mode: max)
- gpt5.2: user experience focus (thinking_mode: high)
- x-ai/grok-4: accessibility, i18n, contrarian focus (thinking_mode: high)

**Synthesize** with severity boost:
- 2+ models identify same edge case -> boost severity (MEDIUM->HIGH)
- 3/3 models identify -> boost severity (HIGH->CRITICAL)

**Auto-inject** CRITICAL and HIGH edge cases as pending clarification questions:
```
FOR EACH edge_case WHERE severity IN [CRITICAL, HIGH]:
    ADD to pending_clarifications:
        question: "How should the system handle: {edge_case.description}?"
        source: "edge_case"
        severity: {edge_case.severity}
```

Write report: `specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md`

**If disabled OR PAL_AVAILABLE = false:** Skip, proceed to Step 4.1b.

## Step 4.1b: Auto-Resolve Gate

Load and execute: `@$CLAUDE_PLUGIN_ROOT/skills/feature-specify/references/auto-resolve-protocol.md`

For each pending question (from checklist gaps + edge cases + triangulation):
1. Attempt auto-resolution against input documents, prior decisions, spec content
2. Classify as AUTO_RESOLVED, INFERRED, or REQUIRES_USER
3. Build the two question lists: auto-resolved (with citations) and requires-user

**Stats to track:**
```yaml
auto_resolve_stats:
  total_questions: {N}
  auto_resolved: {N}
  inferred: {N}
  requires_user: {N}
```

## Step 4.2: Write Clarification Questions File

Generate `specs/{FEATURE_DIR}/clarification-questions.md` following the format defined in:
`@$CLAUDE_PLUGIN_ROOT/skills/feature-specify/references/clarification-protocol.md`

**Structure:**
1. YAML frontmatter with counts and status
2. Auto-Resolved section: questions with answers and citations (user can override)
3. Requires Your Input section: questions with BA recommendations and options

**After writing, return summary with file-based pause:**

```yaml
---
stage: "clarification"
stage_number: 4
status: needs-user-input
checkpoint: CLARIFICATION
artifacts_written:
  - specs/{FEATURE_DIR}/clarification-questions.md
  - specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md  # if ThinkDeep ran
summary: "Generated {N} clarification questions ({A} auto-resolved, {U} require user input). Question file written."
flags:
  questions_total: {N}
  questions_auto_resolved: {A}
  questions_require_user: {U}
  edgecases_found: {E}
  block_reason: "Clarification questions written to file — awaiting user answers"
  pause_type: "file_based"
  clarification_file: "specs/{FEATURE_DIR}/clarification-questions.md"
  next_action: "await_user_answers"
---

## Context for Next Stage
Clarification questions written to specs/{FEATURE_DIR}/clarification-questions.md.
{A} questions auto-resolved from input documents.
{U} questions require user input.
User should edit the file and re-run /feature-specify to continue.
```

**STOP HERE on first entry.** The orchestrator will pause the workflow and notify the user.

## Step 4.3: Parse Answers (Re-Entry Only)

**Triggered when:** `ENTRY_TYPE == "re_entry_after_user_input"`

Read `specs/{FEATURE_DIR}/clarification-questions.md` and parse answers per the clarification protocol's Answer Parsing Rules.

**Validation:**
- Verify file has been modified since generation (check frontmatter timestamp vs file mtime)
- Parse all answers: auto-resolved (check for overrides), user-provided, blank (use recommendation)
- Save all answers to state file under `user_decisions.clarifications`

**Generate:** `specs/{FEATURE_DIR}/clarification-report.md` per auto-resolve-protocol.md format.

## Step 4.4: MPA-Triangulation ThinkDeep (Optional)

**Check:** `thinkdeep.integrations.triangulation.enabled` in config AND PAL_AVAILABLE

**If enabled:**

Load execution pattern from: `@$CLAUDE_PLUGIN_ROOT/skills/feature-specify/references/thinkdeep-patterns.md` -> Integration 3: Triangulation

Execute dual+ model dispatch:
- pro: technical perspective
- gpt5.2: business perspective
- x-ai/grok-4: contrarian perspective

Each generates 2-4 additional questions not covered by BA.

**Semantic deduplication** against existing questions (similarity threshold: 0.85):
- Discard duplicates
- Priority boost on cross-source agreement

**If new unique questions found:** Add to `clarification-questions.md` and return to Step 4.2 pattern (file-based pause). Otherwise proceed.

Write report: `specs/{FEATURE_DIR}/analysis/mpa-triangulation.md`

**If disabled OR PAL_AVAILABLE = false:** Skip, proceed to Step 4.5.

## Step 4.5: Update Specification

Dispatch BA agent to incorporate all clarification answers:

```
## Task: Update Specification with Clarifications

Spec: @specs/{FEATURE_DIR}/spec.md
Clarification answers: {ALL_ANSWERS_FROM_PARSED_FILE}
Edge case findings: {EDGE_CASE_SUMMARY}
Triangulation findings: {TRIANGULATION_SUMMARY}

## Instructions
@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-update-spec.md

RULES:
- ONLY add or refine requirements — NEVER remove existing ones
- Remove [NEEDS CLARIFICATION] markers that have been resolved
- Add @ResearchRef annotations where clarifications cite evidence
- Maintain consistent formatting with existing spec sections
- Preserve non-technical language — no framework/API references
```

## Step 4.6: Checkpoint

Update state file:
```yaml
current_stage: 4
stages:
  clarification:
    status: completed
    timestamp: "{ISO_TIMESTAMP}"
    clarification_file_path: "specs/{FEATURE_DIR}/clarification-questions.md"
    clarification_status: "answered"
    questions_total: {N}
    questions_auto_resolved: {N}
    questions_user_answered: {N}
    questions_accepted_recommendation: {N}
    user_overrides: {N}
    markers_found: {N}
    markers_resolved: {N}
    iteration: {N}
  mpa_edgecases:
    status: {completed|skipped}
    findings_count: {N}
    injected_clarifications: {N}
  mpa_triangulation:
    status: {completed|skipped}
    additional_questions: {N}
    deduplicated: {N}
  auto_resolve:
    status: {completed|skipped}
    auto_resolved: {N}
    inferred: {N}
    requires_user: {N}
```

## Summary Contract (after answers parsed)

> **Size limits:** `summary` max 500 chars, Context body max 1000 chars. Details in artifacts, not summaries.

```yaml
---
stage: "clarification"
stage_number: 4
status: completed
checkpoint: CLARIFICATION
artifacts_written:
  - specs/{FEATURE_DIR}/spec.md
  - specs/{FEATURE_DIR}/clarification-questions.md
  - specs/{FEATURE_DIR}/clarification-report.md
  - specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md  # if ThinkDeep ran
  - specs/{FEATURE_DIR}/analysis/mpa-triangulation.md  # if triangulation ran
summary: "Clarification complete: {N} questions ({A} auto-resolved, {U} user-answered, {R} accepted recommendations). {M} markers resolved. Edge cases: {E} found."
flags:
  questions_total: {N}
  questions_auto_resolved: {A}
  questions_user_answered: {U}
  questions_accepted_recommendation: {R}
  user_overrides: {O}
  markers_resolved: {M}
  remaining_markers: {N}
  edgecases_found: {E}
  triangulation_questions: {T}
  iteration: {N}
  next_action: "proceed"
---

## Context for Next Stage
Clarification resolved {M} of {TOTAL} markers.
{IF remaining_markers > 0: "Remaining markers: {LIST}"}
Auto-resolve: {A} questions resolved from input documents.
Edge case severity distribution: {CRITICAL: N, HIGH: N, MEDIUM: N}
Spec updated with all clarification answers.
```

**Note on iteration:** After this stage, the orchestrator re-dispatches Stage 3 for re-validation. The loop continues until coverage >= 85% or user requests proceed. The `next_action` from this stage is always `"proceed"` — the orchestrator checks Stage 3's `coverage_pct` to decide whether to loop back.

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. `specs/{FEATURE_DIR}/spec.md` has been updated (not unchanged from input)
2. Resolved `[NEEDS CLARIFICATION]` markers have been removed from spec
3. Edge case report exists (if ThinkDeep ran)
4. `specs/{FEATURE_DIR}/clarification-report.md` exists with audit trail
5. All clarification answers are recorded in state file
6. Summary YAML frontmatter has no placeholder values
7. No previously answered questions were re-asked

## CRITICAL RULES REMINDER

- No question limits — generate EVERYTHING needed
- Never re-ask questions from user_decisions.clarifications
- File-based clarification — NO AskUserQuestion calls for clarification questions
- Edge case severity boost on cross-model agreement
- CRITICAL/HIGH edge cases auto-inject as questions
- Spec updates are additive only — NEVER remove requirements
- NEVER interact with users directly
