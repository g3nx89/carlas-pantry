---
purpose: "Canonical pattern for deep reasoning escalation via manual user submission"
used_by: [orchestrator-loop]
---

# Deep Reasoning Escalation Dispatch Pattern

> **Canonical reference for deep reasoning escalation in the orchestrator loop.**
> The orchestrator invokes this pattern when quality gates fail or security triggers fire.
> Coordinators NEVER execute this pattern — it runs exclusively in orchestrator context.

## Prerequisites

Before executing this pattern, the orchestrator MUST verify:

```
IF config.deep_reasoning_escalation.{ESCALATION_FLAG}.enabled
   AND analysis_mode in config.deep_reasoning_escalation.{ESCALATION_FLAG}.modes
   AND state.deep_reasoning.escalations.count_for_phase({PHASE}) < config.deep_reasoning_escalation.limits.max_escalations_per_phase
   AND state.deep_reasoning.escalations.total < config.deep_reasoning_escalation.limits.max_escalations_per_session:
  EXECUTE pattern below
ELSE:
  LOG: "Deep reasoning escalation unavailable — skipping"
  FALL THROUGH to existing retry/skip/abort flow
```

## Parameters (provided by calling context)

| Parameter | Description |
|-----------|-------------|
| `ESCALATION_TYPE` | One of: `architecture_wall`, `circular_failure`, `security_deep_dive`, `algorithm_escalation` |
| `ESCALATION_FLAG` | Config flag name: `architecture_wall_breaker`, `circular_failure_recovery`, `security_deep_dive`, `abstract_algorithm_detection` |
| `PHASE` | Phase number where escalation was triggered (e.g., "6", "6b", "4") |
| `TEMPLATE` | Which CTCO template to use from `$CLAUDE_PLUGIN_ROOT/templates/deep-reasoning-templates.md` |
| `CONTEXT_SOURCES` | Array of file paths to include in CTCO Context section |
| `GATE_HISTORY` | Object: `{ retries, scores[], failing_dimensions[], feedback[] }` — null for security trigger |
| `SPECIFIC_FOCUS` | What the deep reasoning model should focus on (e.g., lowest scoring dimension) |

## Escalation Type Mapping

Canonical mapping between the three naming layers used across the system:

| Escalation Type | Config Flag | Context Limit Key | Template Heading |
|-----------------|-------------|-------------------|------------------|
| `architecture_wall` | `architecture_wall_breaker` | `architecture_wall` | Template 1: Architecture Wall Breaker |
| `circular_failure` | `circular_failure_recovery` | `circular_failure` | Template 2: Circular Failure Recovery |
| `security_deep_dive` | `security_deep_dive` | `security_deep_dive` | Template 3: Security Deep Dive |
| `algorithm_escalation` | `abstract_algorithm_detection` | `algorithm_escalation` | Template 4: Abstract Algorithm Escalation |

> **TEMPLATE parameter**: Pass the `Escalation Type` value (column 1) — matches the `**Escalation type**` field in each template.
> **Context limits**: Resolved via `config.deep_reasoning_escalation.context_limits.{ESCALATION_TYPE}`.

## Step A: Context Assembly

```
1. READ artifacts listed in CONTEXT_SOURCES from {FEATURE_DIR}/
   - design.md, plan.md, test-plan.md, analysis/expert-review.md, etc.
   - Read ONLY sections relevant to SPECIFIC_FOCUS (respect context budget)

2. READ prior phase summaries relevant to this escalation:
   - For architecture_wall: phase-4-summary.md, phase-5-summary.md, phase-6-summary.md
   - For circular_failure: summary of the failing phase + its predecessor
   - For security_deep_dive: phase-6b-summary.md
   - For algorithm_escalation: phase-4-summary.md or phase-7-summary.md

3. COMPILE into <prior_context> XML format using Context Handoff Format
   from $CLAUDE_PLUGIN_ROOT/templates/deep-reasoning-templates.md

4. CHECK context length against config.deep_reasoning_escalation.context_limits.{ESCALATION_TYPE}:
   - IF exceeds max: TRIM artifacts to summaries only, cut less relevant sections
   - IF below min: ADD more context from related artifacts
```

## Step B: CTCO Prompt Generation

```
1. LOAD template matching TEMPLATE parameter from
   $CLAUDE_PLUGIN_ROOT/templates/deep-reasoning-templates.md

2. FILL template variables:
   - Use Variable Sourcing table in the template for each variable
   - For missing optional variables, use fallback: "Not available"
   - For missing required variables (e.g., design.md doesn't exist), LOG warning

3. ASSEMBLE final prompt:
   prompt = context_handoff + filled_template

4. SAVE prompt to {FEATURE_DIR}/analysis/deep-reasoning-prompt-{PHASE}.md
   (for audit trail and resume capability)

5. UPDATE state:
   state.deep_reasoning.pending_escalation = {
     phase: {PHASE},
     type: {ESCALATION_TYPE},
     prompt_file: "analysis/deep-reasoning-prompt-{PHASE}.md",
     response_file: "analysis/deep-reasoning-response-{PHASE}.md",
     timestamp: now()
   }
   WRITE state
```

## Step C: User Presentation

Present the escalation to the user via `AskUserQuestion`:

```
header: "Deep Reasoning Escalation"
question: """
  {EXPLANATION}

  The prompt has been saved to: {FEATURE_DIR}/analysis/deep-reasoning-prompt-{PHASE}.md

  To proceed:
  1. Open the prompt file and copy its contents
  2. Paste into your deep reasoning model's web interface
     (GPT-5 Pro at chat.openai.com, or Google Deep Think at AI Studio)
  3. Wait for the response (typically {EXPECTED_WAIT})
  4. Save the response to: {FEATURE_DIR}/analysis/deep-reasoning-response-{PHASE}.md
     OR paste it back here when asked

  What would you like to do?
"""
options:
  - label: "I'll submit to a deep reasoning model"
    description: "Copy the prompt, submit externally, then provide the response"
  - label: "Skip escalation, retry normally"
    description: "Continue with the standard retry/loop-back flow"
  - label: "Skip escalation, abort workflow"
    description: "Stop the planning workflow here"
```

Where `{EXPLANATION}` is built per escalation type:

| ESCALATION_TYPE | EXPLANATION |
|-----------------|-------------|
| `architecture_wall` | "The architecture has failed validation {retries} times (score: {score}/{max}). The weakest dimensions are: {lowest_dims}. External deep reasoning models have demonstrated stronger performance on architectural analysis." |
| `circular_failure` | "Quality gate '{gate_name}' has failed {retries} times despite retry attempts. External deep reasoning models can help identify what is being systematically missed." |
| `security_deep_dive` | "{critical_count} CRITICAL security vulnerabilities were found in the expert review. External deep reasoning models have demonstrated 87% accuracy on CVE-level security analysis (CVE-Bench)." |
| `algorithm_escalation` | "This feature requires algorithmic design (keywords: {keywords}) that the planning agents could not adequately address. External deep reasoning models have a 44% advantage on abstract reasoning tasks." |

Expected wait times:

| ESCALATION_TYPE | EXPECTED_WAIT |
|-----------------|---------------|
| `architecture_wall` | "5-15 minutes" |
| `circular_failure` | "3-10 minutes" |
| `security_deep_dive` | "5-15 minutes" |
| `algorithm_escalation` | "5-15 minutes" |

## Step D: Response Ingestion

```
IF user selected "I'll submit to a deep reasoning model":

  1. ASK user: "Have you saved the response to {response_file_path}?
     If yes, confirm. If you'd prefer to paste inline, select 'Paste inline'."

     options:
       - "Response file is ready"
       - "Paste inline"
       - "Cancel (skip escalation)"

  2. IF "Response file is ready":
     response_path = {FEATURE_DIR}/analysis/deep-reasoning-response-{PHASE}.md
     IF file exists AND file is not empty:
       LOG: "Deep reasoning response received from file"
     ELSE:
       ASK user: "File not found or empty. Please check the path and try again."
       # Re-ask once, then fall through to skip

  3. IF "Paste inline":
     response_text = user's pasted text
     WRITE response_text to {FEATURE_DIR}/analysis/deep-reasoning-response-{PHASE}.md
     LOG: "Deep reasoning response received inline, saved to file"

  4. IF "Cancel":
     FALL THROUGH to existing retry/skip/abort flow
```

## Step E: State Update

```
1. ADD escalation record:
   state.deep_reasoning.escalations.append({
     phase: {PHASE},
     type: {ESCALATION_TYPE},
     prompt_file: "analysis/deep-reasoning-prompt-{PHASE}.md",
     response_file: "analysis/deep-reasoning-response-{PHASE}.md",
     timestamp: now(),
     status: "completed"
   })

2. CLEAR pending escalation:
   state.deep_reasoning.pending_escalation = null

3. WRITE state
```

## Step F: Re-dispatch with Enriched Context

The behavior after response ingestion depends on the escalation type:

```
IF ESCALATION_TYPE in ["architecture_wall", "circular_failure"]:
  # Re-dispatch the target phase coordinator with deep reasoning context
  target_phase = IF ESCALATION_TYPE == "architecture_wall" THEN "4"
                 ELSE {phase or its loop-back target}

  # Add response file to coordinator prompt
  MODIFY coordinator prompt to include:
    "## Deep Reasoning Model Analysis
     Read: {FEATURE_DIR}/analysis/deep-reasoning-response-{PHASE}.md
     This contains analysis from an external deep reasoning model addressing
     the quality gate failures. Use it to inform your approach, but apply
     your own judgment — verify specific claims before incorporating them."

  RE-DISPATCH_COORDINATOR(target_phase)

ELSE IF ESCALATION_TYPE == "security_deep_dive":
  # Do NOT re-dispatch Phase 6b — just enrich the expert review
  READ response from analysis/deep-reasoning-response-{PHASE}.md
  APPEND to {FEATURE_DIR}/analysis/expert-review.md:
    "## Deep Reasoning Security Audit (External Model)
     {response content}"
  UPDATE phase-6b-summary.md: flags.deep_reasoning_supplement = true
  CONTINUE to next phase

ELSE IF ESCALATION_TYPE == "algorithm_escalation":
  # Re-dispatch the phase that flagged algorithm difficulty
  RE-DISPATCH_COORDINATOR({PHASE})
```

## Resume Handling

When the orchestrator detects a pending escalation on resume:

```
IF state.deep_reasoning.pending_escalation:
  pending = state.deep_reasoning.pending_escalation
  ASK user:
    "A deep reasoning escalation was started for Phase {pending.phase}
     ({pending.type}) but no response was received.
     The prompt is saved at: {pending.prompt_file}

     What would you like to do?"
    options:
      - "Provide the response now (file or inline)"
      - "Skip this escalation and continue normally"

  IF user provides response:
    EXECUTE Step D (Response Ingestion)
    EXECUTE Step E (State Update)
    EXECUTE Step F (Re-dispatch)
  ELSE:
    CLEAR state.deep_reasoning.pending_escalation
    WRITE state
    CONTINUE with normal flow from pending.phase
```

## Graceful Degradation

| Scenario | Behavior |
|----------|----------|
| User declines escalation | Fall through to existing retry/skip/abort flow |
| User provides empty response | Re-ask once, then fall through to skip |
| Feature flag disabled | Never offer escalation; existing behavior unchanged |
| Standard/Rapid mode | Never offer escalation; existing behavior unchanged |
| Escalation limit reached (per-phase) | Log and fall through to existing flow |
| Escalation limit reached (per-session) | Log and fall through to existing flow |
| Response file not found | Re-ask once for file path, then offer inline paste |
| Resume with pending escalation | Re-present the saved prompt with option to skip |
| Prompt file fails to generate | Log error, fall through to existing flow |

## Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Escalate before 2 gate retries | Premature; normal retries may succeed | Only invoke after `retries >= max_retries` |
| Escalate for creative tasks | Deep reasoning models regress on creativity | Check ESCALATION_TYPE is one of the 4 supported types |
| Pass response inline to coordinator | Context pollution; violates summary-only pattern | Always write to file; coordinator reads file |
| Auto-escalate without user consent | User may not have model access; manual step required | Always present via AskUserQuestion |
| Escalate in Standard/Rapid modes | Unnecessary latency for simple features | Mode guard in prerequisites |
| Trust deep reasoning response blindly | Models can hallucinate APIs and patterns | Coordinator instructions include "verify specific claims" |
| Coordinator offers escalation | Violates no-user-interaction rule | Only orchestrator mediates escalation |

## Phase-Specific Parameters

| Escalation Type | Phase | ESCALATION_FLAG | CONTEXT_SOURCES | Re-dispatch Target |
|-----------------|-------|-----------------|-----------------|-------------------|
| `architecture_wall` | 6 | `architecture_wall_breaker` | design.md, plan.md, validation-report.md | Phase 4 |
| `circular_failure` | Any gated | `circular_failure_recovery` | Failing phase artifacts + summary | Same phase or loop-back target |
| `security_deep_dive` | 6b | `security_deep_dive` | expert-review.md, cli-security-report.md, design.md | No re-dispatch (append) |
| `algorithm_escalation` | 4 or 7 | `abstract_algorithm_detection` | spec.md (algo section), design.md, research.md | Same phase |
