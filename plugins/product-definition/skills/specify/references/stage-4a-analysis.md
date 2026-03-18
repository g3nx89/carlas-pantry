---
stage: stage-4a-analysis
artifacts_written:
  - specs/{FEATURE_DIR}/clarification-questions.md (created)
  - specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md (conditional)
  - specs/{FEATURE_DIR}/analysis/mpa-edgecases.md (conditional)
  - design-handoff/figma-screen-briefs/FSB-*.md (conditional — Step 4.0b, when figma mock gaps found)
  - design-handoff/figma-briefs-index.md (conditional — Step 4.0b.2, when user chooses "Create mocks first")
---

# Stage 4A: Analysis & Question Generation (Coordinator — First Entry)

> This stage discovers edge cases via tri-CLI dispatch, resolves RTM dispositions,
> generates all clarification questions (with auto-resolve filtering), and writes them
> to a file for offline user editing. Ends with a file-based pause.
>
> **Re-entry after user edits goes to Stage 4B** (`stage-4b-resolution.md`).

## CRITICAL RULES (must follow — failure-prevention)

1. **No question limits**: Generate ALL questions needed — no artificial caps
2. **Never re-ask**: Questions from `user_decisions.clarifications` are IMMUTABLE — check before generating
3. **File-based clarification**: Write ALL questions to `clarification-questions.md` — NO AskUserQuestion calls for clarification
4. **Edge case severity boost**: 2+ models agree = MEDIUM->HIGH, 3/3 = HIGH->CRITICAL
5. **CRITICAL/HIGH edge cases**: Auto-inject as clarification questions
6. **NEVER interact with users directly**: Return `status: needs-user-input, pause_type: file_based` after writing question file. **Exception:** Step 4.0b (Figma mock gaps) and Step 4.0a (RTM dispositions) use `pause_type: interactive` since they are decision gates, not clarification batches.
7. **CLI dispatch**: Follow rules in `cli-dispatch-patterns.md` → CLI Critical Rules

## Step 4.0: Validate Pre-Conditions

```bash
test -f "specs/{FEATURE_DIR}/spec.md" || echo "BLOCKER: spec.md missing"
test -f "specs/{FEATURE_DIR}/spec-checklist.md" || echo "BLOCKER: checklist missing — Stage 3 must complete first"
```

**If BLOCKER found:** Set `status: failed`, `block_reason: "Pre-condition failed"`. Do not proceed.

## Step 4.0b: Figma Mock Gap Resolution

**Runs only if `STATE.handoff_supplement.available == true` AND Stage 3 summary flag `figma_mock_gaps_count > 0`.**
If either condition is false, skip directly to Step 4.0a.

### Step 4.0b.1: Generate figma-screen-briefs for missing mocks

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

### Step 4.0b.2: Present Figma Mock Gaps to User

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
- Proceed to Step 4.0a

## Step 4.0a: RTM Disposition Resolution (Conditional)

**Check:** `RTM_ENABLED == true` AND (`rtm_unmapped_count > 0` OR any PENDING_STORY dispositions remain in `rtm.md`) (from Stage 3 summary flags)

**If any condition is false:** Skip entirely, proceed to Step 4.1.

**If all conditions met:**

1. Read `specs/{FEATURE_DIR}/rtm.md` — extract all UNMAPPED and PENDING_STORY REQ entries
2. For each UNMAPPED or PENDING_STORY REQ-NNN, write a disposition question to `specs/{FEATURE_DIR}/clarification-questions.md`
   (prepended before BA clarification questions, in a dedicated `## RTM Dispositions` section):

```markdown
## RTM Dispositions

> The following source requirements are not yet traced to any spec element.
> Choose a disposition for each.

### REQ-{NNN}: {Requirement description}

**Source**: {source from inventory}

- [ ] **Map to existing story**: This requirement is already covered by an existing user story
  - If selected, specify which: US-___ (write the story ID)
- [ ] **Needs new story**: A new user story should be created for this requirement
- [ ] **Defer (out of scope)**: This requirement is valid but out of scope for this iteration
  - If selected, add rationale: ___
- [ ] **Remove**: This is not actually a requirement (context statement, duplicate, etc.)
```

3. Set `source: rtm_disposition` on these questions for parsing in Stage 4B Step 4.3

**Note:** RTM disposition questions are part of the clarification file, following the same file-based
Q&A pattern. They are processed during the normal answer parsing flow (Stage 4B Step 4.3).

## Step 4.1: MPA-EdgeCases CLI Dispatch (Optional)

**Check:** `cli_dispatch.integrations.edge_cases.enabled` in config AND CLI_AVAILABLE

**If enabled:**

Execute **Integration 2: Edge Cases** per `@$CLAUDE_PLUGIN_ROOT/skills/specify/references/cli-dispatch-patterns.md`.

**Variables for dispatch:**
- `FEATURE_DIR`: specs/{FEATURE_DIR}
- `SPEC_CONTENT`: spec.md content (or structured summary if > 4000 words)
- `GAPS_FROM_STAGE_3`: checklist gap list from Stage 3 summary
- `OPENCODE_MODEL`: {OPENCODE_MODEL}
- `TIMEOUT`: 150 seconds

**Synthesize** with severity boost per the decision table in `cli-dispatch-patterns.md`.

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
stage: "analysis-questions"
stage_number: 4
status: needs-user-input
checkpoint: CLARIFICATION_WRITE
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

**STOP HERE.** The orchestrator will pause the workflow and notify the user.

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. `specs/{FEATURE_DIR}/clarification-questions.md` exists with questions
2. Edge case report exists (if CLI EdgeCases ran)
3. No previously answered questions were re-asked
4. RTM disposition questions included (if RTM enabled and UNMAPPED exist)
5. Summary YAML frontmatter has no placeholder values

**If ANY check fails:** Fix the issue. If unfixable: set `status: failed` with `block_reason` describing the failure.
