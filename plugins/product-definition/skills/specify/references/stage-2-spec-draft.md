---
stage: stage-2-spec-draft
artifacts_written:
  - specs/{FEATURE_DIR}/spec.md
  - specs/{FEATURE_DIR}/analysis/mpa-challenge-parallel.md (conditional)
  - specs/{FEATURE_DIR}/analysis/mpa-challenge.md (conditional)
  - specs/{FEATURE_DIR}/rtm.md (conditional)
---

# Stage 2: Spec Draft & Gates (Coordinator)

> This stage creates the specification draft, challenges problem framing via CLI dispatch, and validates through incremental quality gates.

## CRITICAL RULES (must follow — failure-prevention)

1. **BA recommendation**: first option MUST be "(Recommended)" with rationale
2. **No limits**: on user stories, acceptance criteria, or NFRs — capture ALL requirements
3. **CLI Challenge MUST complete before gates**: challenge insights inform evaluation
4. **Gate evaluation**: GREEN = proceed silently, YELLOW/RED = signal `needs-user-input`
5. **If gates require BA revision**: re-invoke BA then re-run gates (coordinator-internal loop)
6. **NEVER interact with users directly**: signal `needs-user-input` in summary for orchestrator

## Step 2.0: Validate Pre-Conditions

```bash
test -f "specs/{FEATURE_DIR}/.specify-state.local.md" || echo "BLOCKER: state file missing"
test -f "specs/{FEATURE_DIR}/spec.md" || echo "BLOCKER: spec template missing"
```

**If BLOCKER found:** Set `status: failed`, `block_reason: "Pre-condition failed"`. Do not proceed.

## Step 2.1: Launch BA Agent

Dispatch BA agent via `Task(subagent_type="general-purpose")`:

```
## Task: Create Feature Specification

{RESUME_CONTEXT}

Perform business analysis and requirements gathering for:
{USER_INPUT}

## Requirements Inventory
{IF RTM_ENABLED AND REQUIREMENTS-INVENTORY.md exists: Include content of specs/{FEATURE_DIR}/REQUIREMENTS-INVENTORY.md}
{ELSE: "No requirements inventory available."}

## Figma Context
{IF FIGMA_CONTEXT_FILE exists: Include content}
{ELSE: "No Figma designs available - proceed without design context"}

## Handoff Context
{HANDOFF_CONTEXT}

## Variables
- FEATURE_NAME: {value}
- FEATURE_DIR: specs/{FEATURE_DIR}
- SPEC_FILE: specs/{FEATURE_DIR}/spec.md
- HANDOFF_CONTEXT: {value from STATE.handoff_supplement or "No handoff supplement. Use [Frame: ScreenName] placeholders"}
- RTM_ENABLED: {true|false}
- REQUIREMENTS_INVENTORY: {content or "Not available"}

## Instructions
@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-spec-draft.md

Write specification to {SPEC_FILE} following template structure.
IF figma context provided: Correlate designs with requirements, add @FigmaRef annotations.
IF requirements inventory provided: Ensure every REQ-NNN is addressed in user stories, add @RTMRef annotations.
```

Use Sequential Thinking (if available) for 8 phases: problem framing → JTBD → requirements → context → stakeholders → specification → story splitting → self-critique.

**Note:** `{RESUME_CONTEXT}` is sourced from the orchestrator (Stage 1 Step 1.5). Empty on first run, populated with state data on resume.

## Step 2.2: Parse BA Response

Extract from agent output:
- `status`: success/partial/error
- `self_critique_score`: N/20
- `user_stories_count`: N
- `problem_statement_quality`: assessment
- `true_need_confidence`: low/medium/high

## Step 2.3: Generate Initial RTM (Conditional)

**Check:** `RTM_ENABLED == true` (from Stage 1 summary flags)

**If RTM disabled:** Skip entirely, proceed to Step 2.4.

**If RTM enabled:**

1. Read `specs/{FEATURE_DIR}/REQUIREMENTS-INVENTORY.md` — extract all REQ-NNN entries
2. Read `specs/{FEATURE_DIR}/spec.md` — extract all US-NNN, AC-NN, and NFR-*-NN identifiers
3. For each REQ-NNN, scan spec for:
   - `@RTMRef(req="REQ-NNN")` annotations in US headers (highest confidence)
   - Semantic matches: REQ description shares 2+ key terms with US title or AC description
     (e.g., REQ mentions "dietary restrictions" and US-003 covers "filter by dietary preference")
   - NFR matches: REQ performance/quality constraints match NFR entries
4. Assign disposition for each REQ (only COVERED, PARTIAL, and UNMAPPED are auto-assignable
   at this stage — DEFERRED and REMOVED require explicit user decision in Stage 4):
   - **COVERED**: REQ is fully addressed by one or more spec elements (via annotation or semantic match)
   - **PARTIAL**: REQ is partially addressed — some aspects not yet in spec
   - **UNMAPPED**: No matching spec element found
5. Load template: `@$CLAUDE_PLUGIN_ROOT/templates/rtm-template.md`
6. Write `specs/{FEATURE_DIR}/rtm.md` with the traceability matrix populated
7. Calculate coverage metrics:
   - `rtm_total`: count of all REQ entries
   - `rtm_covered`: count of COVERED dispositions
   - `rtm_partial`: count of PARTIAL dispositions
   - `rtm_unmapped`: count of UNMAPPED dispositions
   - `rtm_coverage_pct`: (covered + partial + deferred + removed) / total * 100
8. Populate Section 15 in `specs/{FEATURE_DIR}/spec.md` with summary metrics
9. Populate backward trace: scan for US-NNN entries not traced from any REQ (scope creep detection — informational only)

## Step 2.4: MPA-Challenge CLI Dispatch

**Check:** `cli_dispatch.integrations.challenge.enabled` in config

**If enabled AND CLI_AVAILABLE:**

Load execution pattern from: `@$CLAUDE_PLUGIN_ROOT/skills/specify/references/cli-dispatch-patterns.md` → Integration 1: Challenge

Write prompt files for each CLI at `specs/{FEATURE_DIR}/analysis/cli-prompts/challenge-{cli}.md`.
Embed spec content inline — do NOT reference file paths.

Dispatch 3 CLIs in parallel via Bash:
- codex (`spec_root_cause`): root cause vs symptoms, logical flaws
- gemini (`spec_alt_framing`): alternative interpretations, adjacent problems
- opencode (`spec_assumption_probe`): assumption probing, devil's advocate

```bash
# Run all 3 in parallel (background processes)
$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
  --cli codex --role spec_root_cause \
  --prompt-file specs/{FEATURE_DIR}/analysis/cli-prompts/challenge-codex.md \
  --output-file specs/{FEATURE_DIR}/analysis/cli-outputs/challenge-codex.md \
  --timeout 120 &

$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
  --cli gemini --role spec_alt_framing \
  --prompt-file specs/{FEATURE_DIR}/analysis/cli-prompts/challenge-gemini.md \
  --output-file specs/{FEATURE_DIR}/analysis/cli-outputs/challenge-gemini.md \
  --timeout 120 &

$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
  --cli opencode --role spec_assumption_probe \
  --prompt-file specs/{FEATURE_DIR}/analysis/cli-prompts/challenge-opencode.md \
  --output-file specs/{FEATURE_DIR}/analysis/cli-outputs/challenge-opencode.md \
  --timeout 120 &

wait  # collect all results
```

**Synthesize** findings using haiku agent (union_with_dedup strategy).

**Determine risk level:**
- GREEN: No critical findings, assumptions hold
- YELLOW: Some assumptions challenged, minor risks
- RED: Critical assumptions invalidated, major risks

**If RED:**
Signal `needs-user-input`:
```yaml
flags:
  pause_type: "interactive"
  block_reason: "MPA-Challenge found critical issues with problem framing"
  question_context:
    question: "CLI analysis identified critical issues with the problem framing. How would you like to proceed?"
    header: "Challenge"
    options:
      - label: "Revise problem framing (Recommended)"
        description: "Re-invoke BA with challenge findings to strengthen the spec"
      - label: "Acknowledge and proceed"
        description: "Proceed with noted risks documented"
      - label: "Reject findings"
        description: "Proceed without changes"
  next_action_map:
    "Revise problem framing (Recommended)": "revise_ba"
    "Acknowledge and proceed": "proceed"
    "Reject findings": "proceed"
```

**If user chose "Revise":** Re-invoke BA with challenge findings, then re-run MPA-Challenge.

Write report: `specs/{FEATURE_DIR}/analysis/mpa-challenge-parallel.md`

**If disabled OR CLI_AVAILABLE = false:** Skip, proceed to Step 2.5.

## Step 2.5: Gate 1 — Problem Quality

**Check:** `feature_flags.enable_incremental_gates` in config

**If enabled:**

Dispatch `gate-judge` agent via `Task(subagent_type="general-purpose")` to evaluate 4 criteria:
1. Problem statement is specific (not generic)
2. Target persona is clearly identified
3. Impact/pain point is measurable or observable
4. Root cause is articulated (not just symptoms)

Score: Each criterion = 1 point (max 4)

**Thresholds:**
- 4 = GREEN → proceed silently
- 3 = YELLOW → signal `needs-user-input` with gate feedback
- <= 2 = RED → signal `needs-user-input` with gate feedback

**If YELLOW/RED:**
Signal `needs-user-input` with question:
```
"Problem statement scored {SCORE}/4. {DETAILS}. How would you like to proceed?"
Options: "Needs refinement" | "Proceed anyway"
```

**If user wants refinement:** Re-invoke BA with gate feedback (coordinator-internal loop).

## Step 2.6: Gate 2 — True Need

**If incremental gates enabled:**

Dispatch `gate-judge` agent via `Task(subagent_type="general-purpose")` to evaluate 4 criteria:
1. True need differs from stated request (root cause found)
2. Stakeholder motivations are documented
3. Success criteria are defined
4. Business value is articulated

Same GREEN/YELLOW/RED logic as Gate 1.

## Step 2.7: Checkpoint

Update state file:
```yaml
current_stage: 2
stage_status: "completed"
input_document_paths:
  - "{path to original user input file, if file-based}"
  - "{path to research reports, if any}"
  - "{path to any other input documents}"
stages:
  spec_draft:
    status: completed
    timestamp: "{ISO_TIMESTAMP}"
    self_critique_score: {N}
    user_stories_count: {N}
  mpa_challenge:
    status: {completed|skipped}
    risk_level: {GREEN|YELLOW|RED|null}
    findings_count: {N}
  gate_1_problem:
    status: {completed|skipped}
    score: {N}/4
  gate_2_true_need:
    status: {completed|skipped}
    score: {N}/4
  rtm:
    status: {completed|skipped}
    total: {N}
    covered: {N}
    partial: {N}
    unmapped: {N}
    coverage_pct: {N}
```

## Summary Contract

> **Size limits:** `summary` max 500 chars, Context body max 1000 chars. Details in artifacts, not summaries.

```yaml
---
stage: "spec-draft-gates"
stage_number: 2
status: completed | needs-user-input
checkpoint: SPEC_DRAFT
artifacts_written:
  - specs/{FEATURE_DIR}/spec.md
  - specs/{FEATURE_DIR}/analysis/mpa-challenge-parallel.md  # if CLI Challenge ran
  - specs/{FEATURE_DIR}/rtm.md  # if RTM enabled
summary: "Spec draft created with {N} user stories. Self-critique: {S}/20. Challenge risk: {LEVEL}. Gate 1: {S}/4. Gate 2: {S}/4. RTM: {N} total, {U} unmapped."
flags:
  self_critique_score: {N}
  user_stories_count: {N}
  challenge_risk_level: "{GREEN|YELLOW|RED|skipped}"
  gate_1_score: {N}
  gate_2_score: {N}
  rtm_total: {N|0}
  rtm_covered: {N|0}
  rtm_partial: {N|0}
  rtm_unmapped: {N|0}
  block_reason: null | "{reason}"
  pause_type: null | "interactive"
  question_context: {see above if needs-user-input}
---

## Context for Next Stage
Spec draft at specs/{FEATURE_DIR}/spec.md with {N} user stories.
{Challenge findings summary if available.}
{Gate results summary.}
```

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. `specs/{FEATURE_DIR}/spec.md` exists and has content (not just template)
2. If CLI Challenge ran: analysis report exists
3. Gate scores are populated (not placeholder values)
4. State file updated with stage 2 checkpoint data
5. Summary YAML frontmatter has no placeholder values

**If ANY check fails:** Fix the issue. If unfixable: set `status: failed` with `block_reason` describing the failure.

