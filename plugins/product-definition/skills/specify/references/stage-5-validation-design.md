---
stage: stage-5-validation-design
artifacts_written:
  - specs/{FEATURE_DIR}/design-brief.md
  - specs/{FEATURE_DIR}/design-supplement.md
  - specs/{FEATURE_DIR}/analysis/mpa-evaluation.md (conditional)
---

# Stage 5: CLI Validation & Design (Coordinator)

> This stage runs multi-stance CLI evaluation of the spec, then generates
> MANDATORY design artifacts (design-brief.md + design-supplement.md).
> CLI evaluation retry is coordinator-internal (max 2 attempts).

## CRITICAL RULES (must follow — failure-prevention)

1. **CLI Evaluation minimum 2 responses**: If < 2 substantive CLI responses, signal `needs-user-input` (NEVER self-assess)
2. **No model substitution**: If a CLI fails, continue with remaining, do NOT swap
3. **design-brief.md is MANDATORY**: NEVER skip — even if CLI evaluation fails
4. **design-supplement.md is MANDATORY**: NEVER skip — even if CLI evaluation fails
5. **Verify BOTH files exist** before writing summary
6. **Retry max 2**: If REJECTED after 2 retries, signal `needs-user-input`
7. **NEVER interact with users directly**: signal `needs-user-input` in summary
8. **Spec content inline**: NEVER pass local file paths to CLIs — embed spec content in prompt files

## Step 5.0b: Prepare Inline Content for CLI Evaluation

**Purpose:** External CLIs cannot access local files. Spec content MUST be embedded inline in prompt files.

```
READ specs/{FEATURE_DIR}/spec.md
COUNT words in spec content

IF word_count <= 4000 (from cli_dispatch.integrations.evaluation inline_word_limit):
    SET eval_content = full spec content
ELSE:
    GENERATE structured summary:
        - Problem statement (full)
        - User stories with acceptance criteria (full)
        - NFRs (full)
        - Scope boundaries (full)
        - Technical constraints / Information architecture (summarized)
        - Appendices / detailed context (omitted, note: "Detailed appendices omitted for brevity")
    SET eval_content = structured summary
```

**CRITICAL:** NEVER pass file paths (e.g., `@specs/...`) to CLI dispatch prompt files. External CLIs cannot read local files.

## Step 5.1: CLI Evaluation (Optional)

**Check:** `feature_flags.enable_cli_validation` in config AND CLI_AVAILABLE

**If enabled:**

Load execution pattern from: `@$CLAUDE_PLUGIN_ROOT/skills/specify/references/cli-dispatch-patterns.md` → Integration 4: Evaluation

Write prompt files for each CLI at `specs/{FEATURE_DIR}/analysis/cli-prompts/evaluation-{cli}.md`.
Embed `eval_content` inline — do NOT reference file paths.

**Dispatch order:**
1. gemini (`spec_evaluator_neutral`) — run first to establish neutral baseline
2. codex (`spec_evaluator_for`) + opencode (`spec_evaluator_against`) — run in parallel after gemini completes

**Dispatch each CLI via Bash:**
```bash
$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
  --cli {cli} \
  --role {role} \
  --prompt-file specs/{FEATURE_DIR}/analysis/cli-prompts/evaluation-{cli}.md \
  --output-file specs/{FEATURE_DIR}/analysis/cli-outputs/evaluation-{cli}.md \
  --timeout 120 \
  --expected-fields "score,dimension,decision"
```

**If disabled OR CLI_AVAILABLE = false:** Skip to Step 5.5 (design artifacts).

## Step 5.1b: Validate CLI Responses

**Purpose:** Detect non-substantive responses from CLIs that couldn't process the spec.

```
FOR each cli_output IN evaluation_outputs:
    CHECK for non-substantive patterns:
        - "cannot access"
        - "file not found"
        - "unable to read"
        - "no file provided"
        - "I don't have access"
        - response length < 50 words
        - all 5 dimension scores are identical

    IF any pattern matches:
        MARK response as non_substantive
        LOG in model_failures: {cli, stage: 5, operation: "cli_evaluation", error: "non-substantive response", action_taken: "excluded"}

COUNT substantive_responses

IF substantive_responses < 2:
    DO NOT fall back to self-assessment
    PROCEED to Step 5.4 (Handle Insufficient Responses)

IF substantive_responses >= 2:
    SCORE using only substantive responses
    PROCEED to Step 5.2
```

**CRITICAL:** Non-substantive responses MUST be excluded from scoring. NEVER self-assess when CLIs fail to engage with the spec content.

## Step 5.2: Process Evaluation Result

Synthesize scores from substantive CLI responses.
Write synthesis to: `specs/{FEATURE_DIR}/analysis/mpa-evaluation.md`

Aggregate score = average across substantive responses per dimension.

| Score | Decision | Action |
|-------|----------|--------|
| >= 16/20 | APPROVED | Proceed to design artifacts |
| 12-15/20 | CONDITIONAL | Proceed with warnings noted |
| < 12/20 | REJECTED | Retry loop (coordinator-internal) |

## Step 5.3: Handle REJECTED (Coordinator-Internal Loop)

**Max 2 retries** (from `limits.cli_rejection_retries_max`):

```
FOR retry IN 1..2:
    INVOKE BA with prompts/ba-address-gaps.md:
        - Pass dissenting views from CLI evaluation (challenger findings)
        - BA addresses identified weaknesses
        - BA updates spec.md

    RE-PREPARE eval_content (Step 5.0b)
    RE-RUN CLI Evaluation (Step 5.1)

    IF new_score >= 12/20:
        BREAK (proceed)

IF still REJECTED after max retries:
    Signal needs-user-input:
```

```yaml
flags:
  pause_type: "interactive"
  block_reason: "CLI evaluation REJECTED after 2 retries (score: {SCORE}/20)"
  question_context:
    question: "Specification scored {SCORE}/20 after 2 revision attempts. How would you like to proceed?"
    header: "Eval Gate"
    options:
      - label: "Re-run clarifications (Recommended)"
        description: "Gather more information to address weak areas"
      - label: "Force proceed"
        description: "Accept current spec quality and generate design artifacts"
      - label: "Abort"
        description: "Stop workflow and review spec manually"
  next_action_map:
    "Re-run clarifications (Recommended)": "loop_clarify"
    "Force proceed": "proceed"
    "Abort": "abort"
```

## Step 5.4: Handle Insufficient CLI Responses

If < 2 CLIs respond substantively:

Signal `needs-user-input`:
```yaml
flags:
  pause_type: "interactive"
  block_reason: "CLI evaluation failed: only {N} CLI(s) responded substantively (minimum 2 required)"
  question_context:
    question: "CLI evaluation requires minimum 2 responses but only {N} responded. How to proceed?"
    header: "CLI Eval"
    options:
      - label: "Retry (Recommended)"
        description: "Attempt CLI evaluation again"
      - label: "Skip validation"
        description: "Proceed without multi-model validation"
      - label: "Abort"
        description: "Stop workflow"
```

## Step 5.5: Launch design-brief-generator

**MANDATORY — always runs regardless of CLI evaluation outcome.**

Dispatch via `Task(subagent_type="general-purpose")`:

```
## Task: Generate Design Brief

Read the agent instructions: @$CLAUDE_PLUGIN_ROOT/agents/design-brief-generator.md

Spec: @specs/{FEATURE_DIR}/spec.md
{IF figma_context.md exists: Figma: @specs/{FEATURE_DIR}/figma_context.md}

Output: specs/{FEATURE_DIR}/design-brief.md

Use Sequential Thinking (if available, 6 thoughts):
1. Extract all screens from user stories
2. Identify states per screen (default, loading, error, empty, success)
3. Map user journeys across screens
4. Define navigation flows
5. Document interaction patterns
6. Self-critique completeness
```

## Step 5.6: Launch gap-analyzer (Design Supplement)

**MANDATORY — always runs regardless of CLI evaluation outcome.**

Dispatch via `Task(subagent_type="general-purpose")`:

```
## Task: Generate Design Supplement

Read the agent instructions: @$CLAUDE_PLUGIN_ROOT/agents/gap-analyzer.md

Spec: @specs/{FEATURE_DIR}/spec.md
Design Brief: @specs/{FEATURE_DIR}/design-brief.md
{IF figma_context.md exists: Figma: @specs/{FEATURE_DIR}/figma_context.md}

Output: specs/{FEATURE_DIR}/design-supplement.md

Use Sequential Thinking (if available, 6 thoughts):
1. Extract all requirements needing visual/interaction coverage
2. Map requirements to Figma screens (or mark all NOT_COVERED if no Figma)
3. Specify missing screens with full layout, content, and interactions
4. Specify missing states as deltas from base screens
5. Specify missing reusable components with variants
6. Generate alignment summary — every requirement mapped to source
```

## Step 5.7: Verify Outputs

```bash
test -f "specs/{FEATURE_DIR}/design-brief.md" || echo "MISSING: design-brief.md"
test -f "specs/{FEATURE_DIR}/design-supplement.md" || echo "MISSING: design-supplement.md"
```

**If either file missing:** Re-run the missing agent step (5.5 or 5.6).
**If still missing after retry:** Set `status: failed` — mandatory outputs MUST exist.

## Step 5.8: Checkpoint

Update state file:
```yaml
current_stage: 5
stages:
  cli_gate:
    status: {completed|skipped}
    cli_score: {N|null}
    cli_decision: "{APPROVED|CONDITIONAL|REJECTED|skipped}"
    iterations: {N}
    clis_responded: {N}          # Total CLIs that returned a response
    clis_substantive: {N}        # CLIs with substantive responses (used for scoring)
  design_supplement:
    status: completed
    figma_available: {true|false}
    outputs:
      - design-brief.md
      - design-supplement.md
```

## Summary Contract

> **Size limits:** `summary` max 500 chars, Context body max 1000 chars. Details in artifacts, not summaries.

```yaml
---
stage: "cli-validation-design"
stage_number: 5
status: completed | needs-user-input | failed
checkpoint: CLI_GATE
artifacts_written:
  - specs/{FEATURE_DIR}/design-brief.md
  - specs/{FEATURE_DIR}/design-supplement.md
  - specs/{FEATURE_DIR}/analysis/mpa-evaluation.md  # if CLI evaluation ran
summary: "CLI eval: {DECISION} ({SCORE}/20). Design artifacts generated. Brief: {SCREENS} screens. Feedback: {GAPS} gaps identified."
flags:
  cli_score: {N|null}
  cli_decision: "{APPROVED|CONDITIONAL|REJECTED|skipped}"
  cli_iterations: {N}
  design_brief_exists: true
  design_supplement_exists: true
  block_reason: null | "{reason}"
  pause_type: null | "interactive"
  question_context: {see above if needs-user-input}
  next_action_map: {see above if needs-user-input}
---

## Context for Next Stage
CLI validation: {DECISION} ({SCORE}/20).
Design brief: {SCREENS} screens documented.
Design feedback: {GAPS} requirement-screen gaps found.
{IF CLI challenger findings: "Key challenges: {SUMMARY}"}
```

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. `specs/{FEATURE_DIR}/design-brief.md` exists and has content
2. `specs/{FEATURE_DIR}/design-supplement.md` exists and has content
3. CLI score is populated (or marked as skipped)
4. State file updated with stage 5 checkpoint data
5. Summary YAML frontmatter has no placeholder values

## CRITICAL RULES REMINDER

- CLI evaluation minimum 2 substantive responses — signal needs-user-input if < 2 (NEVER self-assess)
- Spec content inline — NEVER pass file paths to external CLIs
- No CLI substitution
- design-brief.md is MANDATORY — NEVER skip
- design-supplement.md is MANDATORY — NEVER skip
- Verify BOTH files exist before writing summary
- Retry max 2, then signal needs-user-input
- NEVER interact with users directly
