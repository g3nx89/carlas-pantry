---
stage: validation
artifacts_written:
  - design-narration/validation/mpa-implementability.md (conditional — MPA agent may fail)
  - design-narration/validation/mpa-ux-completeness.md (conditional — MPA agent may fail)
  - design-narration/validation/mpa-edge-cases.md (conditional — MPA agent may fail)
  - design-narration/validation/synthesis.md
  - design-narration/.narration-state.local.md (updated)
---

# Validation Protocol (Stage 4)

> Orchestrator dispatches MPA agents in parallel + PAL Consensus for quality validation.
> Synthesis agent merges findings. Critical issues presented to user.

## CRITICAL RULES (must follow)

1. **MPA agents run in parallel**: Dispatch all 3 via Task in a SINGLE message (parallel execution).
2. **PAL Consensus is multi-step**: Call sequentially (analysis → model responses → synthesis) with `continuation_id` chaining. NOT a single call.
3. **PAL minimum 2 models with stance steering**: Models sourced from config with for/against/neutral stances. If fewer than 2 respond, mark as PARTIAL and notify user.
4. **Graceful degradation**: If PAL unavailable, skip consensus (MPA results only). NOTIFY user.
5. **User sees critical findings**: CRITICAL findings are presented via AskUserQuestion. IMPORTANT/MINOR are applied automatically.

---

## Step 4.1: MPA Agent Dispatch (Parallel)

Dispatch all 3 agents in a SINGLE message for parallel execution:

```
# Agent 1: Developer Implementability
Task(subagent_type="general-purpose", prompt="""
You are a coordinator for Design Narration, Stage 4 (Validation — Implementability).
You MUST NOT interact with users directly. Write all output to files.

Read and execute: @$CLAUDE_PLUGIN_ROOT/agents/narration-developer-implementability.md

## Input
- Screens directory: design-narration/screens/
- Screen files: {LIST_OF_SCREEN_FILES}
- Figma directory: design-narration/figma/

## Constraints
- READ-ONLY evaluation: do NOT modify any screen narrative files
- Write output ONLY to design-narration/validation/mpa-implementability.md
- Do NOT create files outside design-narration/validation/

## Output
Write to: design-narration/validation/mpa-implementability.md
""")

# Agent 2: UX Completeness
Task(subagent_type="general-purpose", prompt="""
You are a coordinator for Design Narration, Stage 4 (Validation — UX Completeness).
You MUST NOT interact with users directly. Write all output to files.

Read and execute: @$CLAUDE_PLUGIN_ROOT/agents/narration-ux-completeness.md

## Input
- Screens directory: design-narration/screens/
- Screen files: {LIST_OF_SCREEN_FILES}
- Coherence report: design-narration/coherence-report.md

## Constraints
- READ-ONLY evaluation: do NOT modify any screen narrative files
- Write output ONLY to design-narration/validation/mpa-ux-completeness.md
- Do NOT create files outside design-narration/validation/

## Output
Write to: design-narration/validation/mpa-ux-completeness.md
""")

# Agent 3: Edge Case Auditor
Task(subagent_type="general-purpose", prompt="""
You are a coordinator for Design Narration, Stage 4 (Validation — Edge Cases).
You MUST NOT interact with users directly. Write all output to files.

Read and execute: @$CLAUDE_PLUGIN_ROOT/agents/narration-edge-case-auditor.md

## Input
- Screens directory: design-narration/screens/
- Screen files: {LIST_OF_SCREEN_FILES}

## Constraints
- READ-ONLY evaluation: do NOT modify any screen narrative files
- Write output ONLY to design-narration/validation/mpa-edge-cases.md
- Do NOT create files outside design-narration/validation/

## Output
Write to: design-narration/validation/mpa-edge-cases.md
""")
```

---

## Step 4.1b: MPA Dispatch Failure Handling

After dispatching the 3 MPA agents, check which outputs were produced:

```
CHECK existence of:
  - design-narration/validation/mpa-implementability.md
  - design-narration/validation/mpa-ux-completeness.md
  - design-narration/validation/mpa-edge-cases.md

COUNT successful outputs

IF 3/3 outputs exist:
    PROCEED to Step 4.2 (PAL Consensus)

IF 2/3 outputs exist:
    IDENTIFY missing agent
    RETRY the failed agent ONCE (single Task dispatch)
    IF retry succeeds: PROCEED to Step 4.2
    IF retry fails:
        NOTIFY user: "MPA agent '{agent_name}' failed after retry. Proceeding with 2/3 validation perspectives."
        PROCEED to Step 4.2 with available outputs
        MARK validation.mpa_status: "partial" in state

IF 0-1/3 outputs exist:
    RETRY ALL 3 agents (single message, parallel dispatch)
    IF retry produces >= 2 outputs: PROCEED to Step 4.2
    IF retry produces < 2 outputs:
        PRESENT via AskUserQuestion:
            question: "MPA validation largely failed ({N}/3 agents produced output).
            Proceed with available results or skip validation?"
            options:
              - "Proceed with partial validation"
              - "Skip validation entirely — generate output as-is"
              - "Stop workflow"
        HANDLE accordingly
```

---

## Step 4.1c: Post-MPA Conflict Verification

Before passing MPA outputs to synthesis, the orchestrator checks for inter-agent contradictions:

```
FOR each available MPA output file:
    READ YAML frontmatter (status, screen-level verdicts, severity ratings)

COMPARE across agents — ONLY flag conflicts on overlapping concerns:
    # NOTE: Different verdicts across different evaluation criteria are EXPECTED
    # (e.g., implementability pass + edge-case fail is normal multi-perspective output).
    # Only flag conflicts when agents evaluate the SAME element or behavior differently.

    FOR each screen mentioned by 2+ agents:
        FOR each UI element or behavior referenced by 2+ agents on that screen:
            IF agents give contradictory verdicts on the SAME element/behavior:
                ADD to conflict_flags: { screen, element, agent_a_verdict, agent_b_verdict }
            IF severity ratings diverge by 2+ levels for the SAME element/behavior:
                ADD to conflict_flags: { screen, element, agent_a_severity, agent_b_severity }

IF conflict_flags is non-empty:
    INJECT into synthesis dispatch prompt:
        "## MPA Conflicts Detected
        The following inter-agent contradictions require explicit resolution in your synthesis:
        {FORMATTED_CONFLICT_TABLE}
        You MUST address each conflict with a reasoned resolution in the improvement plan."
```

---

## Step 4.2: PAL Consensus (Multi-Step Workflow)

After MPA agents complete, invoke PAL Consensus. The consensus tool is a **multi-step workflow** —
it requires sequential calls (analysis → model responses → synthesis), NOT a single invocation.

Models and stances are sourced from `validation.pal_consensus.models` in `narration-config.yaml`.
Each config entry has a `model` field (PAL alias), a `stance` (for/against/neutral), and an optional `stance_prompt`.

```
# PAL_AVAILABLE means: mcp__pal__consensus is callable AND
#   validation.pal_consensus.enabled == true in narration-config.yaml
IF PAL_AVAILABLE:

    # Collect absolute paths for screen narrative files
    SET screen_files = [absolute paths to all files in design-narration/screens/]

    # Prepare context summary for the consensus prompt
    SET context_summary = "
        Screens: {LIST_OF_SCREEN_NAMES}
        Per-screen critique scores: {SCORES_TABLE}
        Coherence check result: {COHERENCE_STATUS}
        MPA quality score: {MPA_QUALITY_SCORE}
    "

    # Read models from config — each entry has model (PAL alias) + stance + optional stance_prompt
    SET pal_models = validation.pal_consensus.models from narration-config.yaml
    SET num_models = LENGTH(pal_models)
    SET total_steps = num_models + 1  # 1 analysis + (N-1) intermediate model responses + 1 final synthesis

    # Build models array for the API — conditionally omit stance_prompt when null
    SET models_array = []
    FOR each entry in pal_models:
        SET model_entry = {model: entry.model, stance: entry.stance}
        IF entry.stance_prompt is not null:
            model_entry.stance_prompt = entry.stance_prompt
        APPEND model_entry to models_array

    # ── Step 1: Orchestrator's independent analysis ──
    TRY:
        response_1 = mcp__pal__consensus(
            step: "Evaluate UX narrative document readiness for developer handoff.
                   Assess completeness, implementability, and ambiguity across all screens.
                   " + context_summary,
            step_number: 1,
            total_steps: total_steps,
            next_step_required: true,
            findings: "MPA agents produced {N_MPA} outputs. Coherence: {COHERENCE_STATUS}.
                       {SCREENS_COMPLETED} screens documented. Quality score: {SCORE}/100.",
            models: models_array,
            relevant_files: screen_files
        )
    CATCH:
        # Step 1 failure means PAL is available but the call itself failed
        LOG error per error-handling.md format (DEGRADED severity)
        NOTIFY user: "PAL Consensus failed on initial analysis. Proceeding with MPA results only."
        MARK validation.pal_status: "skipped"
        SKIP to Step 4.3 (Synthesis)

    STORE continuation_id FROM response_1
    SET models_responded = 0

    # ── Steps 2..N: Process each model response ──
    # Note: step_number increments per call, but if a model fails, that step number
    # is skipped. PAL tolerates non-contiguous step numbers within a continuation chain.
    FOR i IN 2..num_models:
        SET current_model = pal_models[i - 2]  # 0-indexed: step 2 = model[0], step 3 = model[1]
        TRY:
            response_i = mcp__pal__consensus(
                step: "Process " + current_model.model + " (" + current_model.stance + ") response",
                step_number: i,
                total_steps: total_steps,
                next_step_required: true,
                findings: current_model.model + " (" + current_model.stance + ") finds: "
                          + "{summary of model response from previous step}",
                continuation_id: continuation_id
            )
            STORE continuation_id FROM response_i
            INCREMENT models_responded
        CATCH:
            LOG error per error-handling.md format (DEGRADED severity, include step_number: i)
            CONTINUE to next model

    # ── Check minimum models threshold ──
    IF models_responded < validation.pal_consensus.minimum_models:
        NOTIFY user: "PAL Consensus partial — only {models_responded} model(s) responded
                      (minimum: {minimum_models})."
        MARK validation.pal_status: "partial"
        # Still run synthesis with available responses

    # ── Final step: Synthesis (last model response + consensus synthesis) ──
    TRY:
        SET last_model = pal_models[num_models - 1]
        final_response = mcp__pal__consensus(
            step: "Process " + last_model.model + " (" + last_model.stance + ") response, "
                  + "then synthesize all model perspectives into final readiness assessment. "
                  + "Rate overall: READY / NEEDS_REVISION / NOT_READY. "
                  + "List specific gaps or ambiguities found.",
            step_number: total_steps,
            total_steps: total_steps,
            next_step_required: false,
            findings: "Models responded: {models_responded}/{num_models}. "
                      + last_model.model + " (" + last_model.stance + ") finds: "
                      + "{summary of last model response}. "
                      + "Synthesizing consensus on document readiness.",
            continuation_id: continuation_id
        )
        INCREMENT models_responded  # Count the last model from synthesis step
    CATCH:
        LOG error per error-handling.md format (DEGRADED severity, step: synthesis)
        # Synthesis failed — use partial results from intermediate steps
        MARK validation.pal_status: "partial"

    IF models_responded >= validation.pal_consensus.minimum_models:
        MARK validation.pal_status: "completed"

    STORE final_response for synthesis agent (Step 4.3)
    STORE continuation_id for downstream reference

ELSE IF mcp__pal__consensus is callable BUT validation.pal_consensus.enabled == false:
    NOTIFY user: "PAL Consensus disabled via config. Validation based on MPA results only."
    MARK validation.pal_status: "skipped"

ELSE:
    NOTIFY user: "PAL tools unavailable. Validation based on MPA results only."
    MARK validation.pal_status: "skipped"
```

---

## Step 4.3: Synthesis

Dispatch the synthesis agent:

```
Task(subagent_type="general-purpose", prompt="""
You are a coordinator for Design Narration, Stage 4 (Validation — Synthesis).
You MUST NOT interact with users directly. Write all output to files.
You MUST write the synthesis report upon completion.

Read and execute: @$CLAUDE_PLUGIN_ROOT/agents/narration-validation-synthesis.md

## Input — Read in randomized order
Read the following MPA outputs in a RANDOM order (vary per invocation — do not always start with implementability):
- MPA Implementability: design-narration/validation/mpa-implementability.md
- MPA UX Completeness: design-narration/validation/mpa-ux-completeness.md
- MPA Edge Cases: design-narration/validation/mpa-edge-cases.md
- PAL Consensus: {PAL_RESPONSE or "PAL skipped"}

## MPA Conflicts Detected
{CONFLICT_TABLE or "No inter-agent conflicts detected."}

## Output
Write to: design-narration/validation/synthesis.md
""")
```

### Synthesis Output Format

```yaml
---
quality_score: [0-100]
recommendation: ready | needs-revision
critical_findings: {N}
important_findings: {N}
minor_findings: {N}
---
```

Followed by:

```markdown
## Critical Findings (Must Fix)
| # | Screen | Finding | Suggested Fix |
[Blocking implementation — present to user]

## Important Findings (Should Fix)
| # | Screen | Finding | Suggested Fix |
[Apply automatically — notify user]

## Minor Findings (Optional)
| # | Screen | Finding | Suggested Fix |
[Apply if straightforward — no notification needed]
```

---

## Orchestrator: Handle Findings

```
READ synthesis.md

IF critical_findings > 0:
    FOR each critical finding (batch of up to {maieutic_questions.max_per_batch}):
        PRESENT via AskUserQuestion:
            question: "[CRITICAL] {FINDING_DESCRIPTION}
            Screen: {SCREEN_NAME}
            Impact: {WHY_THIS_BLOCKS_IMPLEMENTATION}"

            options:
              - "Fix as suggested: {SUGGESTED_FIX} (Recommended)"
              - "Skip this — I'll handle it manually"
              - "Let's discuss this"

        IF user approves fix:
            UPDATE affected screen narrative file
            ADD to decision audit trail

FOR important_findings:
    APPLY suggested fixes to screen narratives
    NOTIFY user: "Applied {N} important improvements to screen narratives."

FOR minor_findings:
    APPLY if straightforward (no structural changes)
    No notification needed

UPDATE state:
    validation.status: completed
    validation.quality_score: {score}
    validation.recommendation: {recommendation}
    validation.pal_status: {completed|partial|skipped}
```

---

## Orchestrator: Validation Gate

```
IF recommendation == "ready":
    ADVANCE to Stage 5

IF recommendation == "needs-revision" AND critical_findings were all addressed:
    ADVANCE to Stage 5 (user acknowledged gaps)

IF recommendation == "needs-revision" AND critical_findings remain:
    PRESENT via AskUserQuestion:
        question: "Validation found unresolved critical issues.
        Proceed to generate UX-NARRATIVE.md anyway?"

        options:
          - "Yes, generate with known gaps noted"
          - "No, let me address these first"

    IF "No": EXIT workflow (user will re-invoke after fixes)
    IF "Yes": ADVANCE to Stage 5 with gaps noted in output
```

---

## Self-Verification

Before advancing to Stage 5:

1. `design-narration/validation/` directory exists with all MPA output files
2. Synthesis file has populated YAML frontmatter (no null scores)
3. All critical findings presented to user (none silently skipped)
4. State file validation section updated
5. PAL status recorded (completed/partial/skipped)

**Error handling:** For error classification and logging format, see `references/error-handling.md`.

## CRITICAL RULES REMINDER

1. MPA agents run in parallel (single message, 3 Task calls)
2. PAL Consensus is multi-step (analysis → model responses → synthesis) with continuation_id
3. PAL minimum 2 models with stance steering (for/against/neutral from config)
4. Graceful degradation if PAL unavailable
5. Critical findings always go through user
