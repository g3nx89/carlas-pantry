---
stage: stage-4-clarification
artifacts_written:
  - specs/{FEATURE_DIR}/spec.md (updated)
  - specs/{FEATURE_DIR}/clarification-questions.md (created)
  - specs/{FEATURE_DIR}/clarification-report.md (created, after answers parsed)
  - specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md (conditional)
  - specs/{FEATURE_DIR}/analysis/mpa-edgecases.md (conditional)
  - specs/{FEATURE_DIR}/analysis/mpa-triangulation.md (conditional)
  - design-handoff/figma-screen-briefs/FSB-*.md (conditional — Step 4.0, when figma mock gaps found)
  - design-handoff/figma-briefs-index.md (conditional — Step 4.0.2, when user chooses "Create mocks first")
---

# Stage 4: Edge Cases & Clarification (Coordinator)

> This stage discovers edge cases via tri-CLI dispatch, generates all clarification
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
    # First entry — run Step 4.0 then proceed to Step 4.1
    PROCEED to Step 4.0
```

## Step 4.0: Figma Mock Gap Resolution (First Entry Only)

**Runs only if `STATE.handoff_supplement.available == true` AND Stage 3 summary flag `figma_mock_gaps_count > 0`.**
If either condition is false, skip directly to Step 4.1.

### Step 4.0.1: Generate figma-screen-briefs for missing mocks

> FSB directory: read from `directories.figma_screen_briefs` in `@$CLAUDE_PLUGIN_ROOT/config/handoff-config.yaml`.
> Use this value (let's call it `{FSB_DIR}`) everywhere below instead of hardcoded paths.

Read `figma_mock_gaps` from Stage 3 summary. For each item:

```
1. Deduplicate against existing FSBs (semantic match — not name-based):
   FOR EACH existing FSB in EXISTING_BRIEFS[] (from STATE.handoff_supplement):
     Check if the existing FSB is for the same conceptual screen by testing ANY of:
       (a) Implied-by match: existing FSB `source` references the same US or AC as the new gap item
       (b) Context match: existing FSB `Context.Entry` trigger OR `Context.Exit` destination is
           substantively equivalent to the new gap item's entry/exit (same action type + same source screen)
     IF match found:
       → Reuse existing FSB: append current US-NNN to its `source` field, update `status` if needed
       → Record reuse: add to `STATE.handoff_supplement.specify_briefs_reused[]`
       → Skip to next gap item (do NOT create a new FSB)
   IF no match: assign new FSB number = count of all FSB-*.md files in {FSB_DIR}/ + 1
2. Read template: @$CLAUDE_PLUGIN_ROOT/templates/figma-screen-brief-template.md
3. Populate and write: {FSB_DIR}/FSB-{NNN}-{ScreenName}.md
   - id: FSB-{NNN}
   - name: derived from US scenario description
   - status: pending
   - trigger: "specify"
   - source: "{US-NNN} — {scenario description}"
   - figma_node_id: null
   - Purpose: "{what this screen accomplishes based on the AC scenario}"
   - Context.Entry: from surrounding US context (which US, which action triggers it)
   - Context.Exit: inferred from AC outcome (stay on screen, navigate forward, dismiss)
   - Layout: inferred from screen type and scenario (1-3 sentences, no colors/spacing)
   - States: derived from AC rows for this scenario
   - Behaviors: derived from the AC outcome + neighboring ACs in the same obstacle group
   - Content: placeholder labels from AC descriptions
   - Figma Components: leave as placeholder
   - figma-console Notes: "Reference similar screens from supplement Screen Reference Table"
```

Update `STATE.handoff_supplement.specify_briefs_count` with count of new briefs generated.

### Step 4.0.2: Present Figma Mock Gaps to User

Signal `status: needs-user-input` with interactive question:

```yaml
flags:
  pause_type: "interactive"
  block_reason: "Figma mock gaps found — user decision needed"
  question_context:
    header: "Missing Figma Mocks"
    question: "Stage 3 found {N} user story scenarios without Figma reference.
    {N} Figma screen briefs have been generated in {FSB_DIR}/.

    Missing mocks:
    {LIST: - US-NNN: scenario description → FSB-NNN-ScreenName.md}

    How would you like to proceed?"
    options:
      - label: "Create mocks first (Recommended)"
        description: "Exit now. Give FSB files to a figma-console agent, re-run /design-handoff, then re-run /specify."
      - label: "Continue without mocks"
        description: "Specs will reference [FSB-NNN pending] placeholders. Mocks can be created later."
```

**If "Create mocks first":**
1. Write `design-handoff/figma-briefs-index.md` with the list of all pending briefs (new + existing)
2. Return `status: needs-user-input` — orchestrator exits workflow with instructions:
   ```
   Figma screen briefs generated in {FSB_DIR}/.

   Next steps:
   1. Give each FSB-*.md file to a figma-console agent (run /meta-skills:figma-console-mastery)
   2. Re-run /product-definition:design-handoff to update the supplement with new screens
   3. Re-run /product-definition:specify to continue with complete Figma coverage
   ```

**If "Continue without mocks":**
- Mark each gap item in spec.md: replace `[FIGMA MOCK MISSING: ...]` with `[FSB-NNN pending]` link
- Proceed to Step 4.1

## Step 4.1: MPA-EdgeCases CLI Dispatch (Optional)

**Check:** `cli_dispatch.integrations.edge_cases.enabled` in config AND CLI_AVAILABLE

**If enabled:**

Load execution pattern from: `@$CLAUDE_PLUGIN_ROOT/skills/specify/references/cli-dispatch-patterns.md` → Integration 2: Edge Cases

Write prompt files for each CLI at `specs/{FEATURE_DIR}/analysis/cli-prompts/edgecases-{cli}.md`.
Embed spec content and checklist gaps inline — do NOT reference file paths.

Dispatch 3 CLIs in parallel via Bash:
- codex (`edge_security_perf`): security, performance, data integrity, boundary conditions
- gemini (`edge_ux_coverage`): missing UI states, incomplete flows, user error recovery
- opencode (`edge_contrarian_a11y`): accessibility, i18n/l10n, adversarial/non-standard users

```bash
$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
  --cli codex --role edge_security_perf \
  --prompt-file specs/{FEATURE_DIR}/analysis/cli-prompts/edgecases-codex.md \
  --output-file specs/{FEATURE_DIR}/analysis/cli-outputs/edgecases-codex.md \
  --timeout 150 &

$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
  --cli gemini --role edge_ux_coverage \
  --prompt-file specs/{FEATURE_DIR}/analysis/cli-prompts/edgecases-gemini.md \
  --output-file specs/{FEATURE_DIR}/analysis/cli-outputs/edgecases-gemini.md \
  --timeout 150 &

$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
  --cli opencode --role edge_contrarian_a11y \
  --prompt-file specs/{FEATURE_DIR}/analysis/cli-prompts/edgecases-opencode.md \
  --output-file specs/{FEATURE_DIR}/analysis/cli-outputs/edgecases-opencode.md \
  --timeout 150 &

wait
```

**Synthesize** with severity boost:
- 2+ CLIs identify same edge case -> boost severity (MEDIUM->HIGH)
- 3/3 CLIs identify -> boost severity (HIGH->CRITICAL)

**Auto-inject** CRITICAL and HIGH edge cases as pending clarification questions:
```
FOR EACH edge_case WHERE severity IN [CRITICAL, HIGH]:
    ADD to pending_clarifications:
        question: "How should the system handle: {edge_case.description}?"
        source: "edge_case"
        severity: {edge_case.severity}
```

Write report: `specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md`

**If disabled OR CLI_AVAILABLE = false:** Skip, proceed to Step 4.1b.

## Step 4.1b: Auto-Resolve Gate

Load and execute: `@$CLAUDE_PLUGIN_ROOT/skills/specify/references/auto-resolve-protocol.md`

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
`@$CLAUDE_PLUGIN_ROOT/skills/specify/references/clarification-protocol.md`

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
  - specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md  # if CLI EdgeCases ran
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
User should edit the file and re-run /specify to continue.
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

## Step 4.4: MPA-Triangulation CLI Dispatch (Optional)

**Check:** `cli_dispatch.integrations.triangulation.enabled` in config AND CLI_AVAILABLE

**If enabled:**

Load execution pattern from: `@$CLAUDE_PLUGIN_ROOT/skills/specify/references/cli-dispatch-patterns.md` → Integration 3: Triangulation

Write prompt files for each CLI at `specs/{FEATURE_DIR}/analysis/cli-prompts/triangulation-{cli}.md`.
Embed spec summary, existing question list, and edge case summary inline.

Dispatch 3 CLIs in parallel via Bash:
- codex (`spec_q_technical`): technical product gaps, integration/dependency questions
- gemini (`spec_q_coverage`): missing requirements, underrepresented stakeholders, NFR gaps
- opencode (`spec_q_contrarian`): premise challenges, scope challenges, uncomfortable questions

```bash
$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
  --cli codex --role spec_q_technical \
  --prompt-file specs/{FEATURE_DIR}/analysis/cli-prompts/triangulation-codex.md \
  --output-file specs/{FEATURE_DIR}/analysis/cli-outputs/triangulation-codex.md \
  --timeout 90 &

$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
  --cli gemini --role spec_q_coverage \
  --prompt-file specs/{FEATURE_DIR}/analysis/cli-prompts/triangulation-gemini.md \
  --output-file specs/{FEATURE_DIR}/analysis/cli-outputs/triangulation-gemini.md \
  --timeout 90 &

$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
  --cli opencode --role spec_q_contrarian \
  --prompt-file specs/{FEATURE_DIR}/analysis/cli-prompts/triangulation-opencode.md \
  --output-file specs/{FEATURE_DIR}/analysis/cli-outputs/triangulation-opencode.md \
  --timeout 90 &

wait
```

Each CLI generates 2-4 additional questions not covered by BA.

**Semantic deduplication** against existing questions (similarity threshold: 0.85):
- Discard duplicates
- Priority boost on cross-source agreement

**If new unique questions found:** Add to `clarification-questions.md` and return to Step 4.2 pattern (file-based pause). Otherwise proceed.

Write report: `specs/{FEATURE_DIR}/analysis/mpa-triangulation.md`

**If disabled OR CLI_AVAILABLE = false:** Skip, proceed to Step 4.5.

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
  - specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md  # if CLI EdgeCases ran
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
3. Edge case report exists (if CLI EdgeCases ran)
4. `specs/{FEATURE_DIR}/clarification-report.md` exists with audit trail
5. All clarification answers are recorded in state file
6. Summary YAML frontmatter has no placeholder values
7. No previously answered questions were re-asked

## CRITICAL RULES REMINDER

- No question limits — generate EVERYTHING needed
- Never re-ask questions from user_decisions.clarifications
- File-based clarification — NO AskUserQuestion calls for clarification questions (Step 4.0 is the only interactive step)
- Edge case severity boost on cross-CLI agreement
- CRITICAL/HIGH edge cases auto-inject as questions
- Spec updates are additive only — NEVER remove requirements
- Figma mock gaps: generate FSBs first, then present user choice (Step 4.0)
- NEVER interact with users directly — except Step 4.0 via `status: needs-user-input`
