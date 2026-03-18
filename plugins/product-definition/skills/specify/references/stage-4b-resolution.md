---
stage: stage-4b-resolution
artifacts_written:
  - specs/{FEATURE_DIR}/spec.md (updated)
  - specs/{FEATURE_DIR}/clarification-report.md (created)
  - specs/{FEATURE_DIR}/rtm.md (updated, conditional)
  - specs/{FEATURE_DIR}/analysis/mpa-triangulation.md (conditional)
---

# Stage 4B: Resolution & Spec Update (Coordinator — Re-Entry After User Edits)

> This stage parses user answers from `clarification-questions.md`, runs optional
> MPA-Triangulation for additional questions, then updates the spec with all answers.
>
> **Only dispatched after user has edited the clarification file** from Stage 4A.

## CRITICAL RULES (must follow — failure-prevention)

1. **Spec updates additive only**: ONLY add/refine requirements, NEVER remove existing ones
2. **Never re-ask**: Questions from `user_decisions.clarifications` are IMMUTABLE
3. **NEVER interact with users directly**: Return status in summary for orchestrator
4. **CLI dispatch**: Follow rules in `cli-dispatch-patterns.md` → CLI Critical Rules

## Step 4.3: Parse Answers

Read `specs/{FEATURE_DIR}/clarification-questions.md` and parse answers per the clarification protocol's Answer Parsing Rules (`@$CLAUDE_PLUGIN_ROOT/skills/specify/references/clarification-protocol.md`).

**Validation:**
- Verify file has been modified since generation (check frontmatter timestamp vs file mtime)
- Parse all answers: auto-resolved (check for overrides), user-provided, blank (use recommendation)
- Save all answers to state file under `user_decisions.clarifications`

**RTM Disposition Parsing (if RTM enabled):**

For each question in the `## RTM Dispositions` section (identified by `source: rtm_disposition`):

- **"Map to existing story"** selected with US-NNN specified:
  - Update `rtm.md`: set REQ disposition = COVERED, set "Traced To" = US-NNN
  - Record in `user_decisions.rtm_dispositions`: `{req_id: "REQ-NNN", disposition: "COVERED", target: "US-NNN", timestamp: "{ISO}"}`

- **"Needs new story"** selected:
  - Update `rtm.md`: set REQ disposition = PENDING_STORY
  - Queue for BA in Step 4.5: new US must be created for this REQ
  - Record in `user_decisions.rtm_dispositions`: `{req_id: "REQ-NNN", disposition: "PENDING_STORY", target: null, timestamp: "{ISO}"}`

- **"Defer (out of scope)"** selected with rationale:
  - Update `rtm.md`: set REQ disposition = DEFERRED, add rationale to Notes
  - Add to spec Section 13 (Out of Scope): `- {REQ description} @RTMRef(req="REQ-NNN", disposition="DEFERRED")`
  - Record in `user_decisions.rtm_dispositions`: `{req_id: "REQ-NNN", disposition: "DEFERRED", target: null, timestamp: "{ISO}"}`

- **"Remove"** selected:
  - Update `rtm.md`: set REQ disposition = REMOVED, note reason
  - Record in `user_decisions.rtm_dispositions`: `{req_id: "REQ-NNN", disposition: "REMOVED", target: null, timestamp: "{ISO}"}`

**Generate:** `specs/{FEATURE_DIR}/clarification-report.md` per auto-resolve-protocol.md format.

## Step 4.4: MPA-Triangulation CLI Dispatch (Optional)

**Check:** `cli_dispatch.integrations.triangulation.enabled` in config AND CLI_AVAILABLE

**If enabled:**

Execute **Integration 3: Triangulation** per `@$CLAUDE_PLUGIN_ROOT/skills/specify/references/cli-dispatch-patterns.md`.

**Variables for dispatch:**
- `FEATURE_DIR`: specs/{FEATURE_DIR}
- `SPEC_CONTENT`: spec summary
- `EXISTING_QUESTION_LIST`: questions from clarification-questions.md
- `EDGE_CASE_SUMMARY`: from mpa-edgecases report
- `OPENCODE_MODEL`: {OPENCODE_MODEL}
- `TIMEOUT`: 90 seconds

Each CLI generates 2-4 additional questions not covered by BA.

**Semantic deduplication** against existing questions using DUPLICATE/RELATED/UNIQUE classification (see `cli-dispatch-patterns.md` → Semantic Deduplication Scheme):
- DUPLICATE → discard
- RELATED → keep (probes different aspect)
- UNIQUE → keep
- Priority boost on cross-source agreement

**If new unique questions found:** Add to `clarification-questions.md` and write updated summary with `pause_type: file_based` — the orchestrator will re-pause for user to answer new questions. Otherwise proceed.

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

RTM new stories: {RTM_NEW_STORIES}

RULES:
- ONLY add or refine requirements — NEVER remove existing ones
- Remove [NEEDS CLARIFICATION] markers that have been resolved
- Add @ResearchRef annotations where clarifications cite evidence
- Maintain consistent formatting with existing spec sections
- Preserve non-technical language — no framework/API references
- If RTM_NEW_STORIES is non-empty: create new US entries for each, with @RTMRef annotations
```

**Constructing RTM_NEW_STORIES variable:**

Before dispatching BA, build the `RTM_NEW_STORIES` value from state:
```
IF RTM_ENABLED AND any user_decisions.rtm_dispositions have disposition == "PENDING_STORY":
    RTM_NEW_STORIES = formatted list of pending requirements:
    "- REQ-{NNN}: {requirement description} (from REQUIREMENTS-INVENTORY.md)"
    for each PENDING_STORY disposition
ELSE:
    RTM_NEW_STORIES = "" (empty — BA skips RTM story creation)
```

**After BA update (if RTM enabled AND any PENDING_STORY dispositions):**

1. Re-read updated `specs/{FEATURE_DIR}/spec.md` — find newly created US entries
2. Update `specs/{FEATURE_DIR}/rtm.md`:
   - For each PENDING_STORY REQ: update disposition to COVERED, set "Traced To" = new US-NNN
3. Update Section 15 metrics in `spec.md`
4. Verify zero UNMAPPED or PENDING_STORY dispositions remain

**PENDING_STORY Recovery:** If BA fails to create a US for a PENDING_STORY REQ (e.g., coordinator crash),
the RTM re-evaluation in Stage 3 (next iteration) will detect the still-PENDING_STORY entry and
re-surface it. The disposition gate in Stage 4A Step 4.0a treats PENDING_STORY as equivalent to UNMAPPED
for re-disposition purposes — user gets another chance to map, defer, or remove it.

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
  rtm:
    status: {completed|skipped}
    disposition_status: "{resolved|pending|null}"
    dispositions_applied: {N}
    remaining_unmapped: {N}
    coverage_pct: {N}
```

**RTM User Decisions (immutable):**
```yaml
user_decisions:
  rtm_dispositions:
    - req_id: "REQ-NNN"
      disposition: "{COVERED|DEFERRED|REMOVED|PENDING_STORY}"
      target: "{US-NNN | null}"
      timestamp: "{ISO_TIMESTAMP}"
```

## Summary Contract (after answers parsed)

> **Size limits:** `summary` max 500 chars, Context body max 1000 chars. Details in artifacts, not summaries.

```yaml
---
stage: "resolution-spec-update"
stage_number: 4
status: completed
checkpoint: CLARIFICATION
artifacts_written:
  - specs/{FEATURE_DIR}/spec.md
  - specs/{FEATURE_DIR}/clarification-questions.md
  - specs/{FEATURE_DIR}/clarification-report.md
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
3. `specs/{FEATURE_DIR}/clarification-report.md` exists with audit trail
4. All clarification answers are recorded in state file
5. Summary YAML frontmatter has no placeholder values
6. No previously answered questions were re-asked

**If ANY check fails:** Fix the issue. If unfixable: set `status: failed` with `block_reason` describing the failure.
