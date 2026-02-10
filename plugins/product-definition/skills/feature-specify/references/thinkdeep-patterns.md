# ThinkDeep Execution Patterns

> Parameterized execution patterns for MPA/ThinkDeep integration points in the Feature Specify workflow.
> Referenced by Stage 2 (Challenge), Stage 4 (EdgeCases, Triangulation).

---

## Pattern: Parallel Multi-Model ThinkDeep

This pattern is used at 3 integration points. Each follows the same structure but with different parameters.

### Execution Template

```
FOR EACH model IN integration.parallel.models:
    CALL mcp__pal__thinkdeep with:
        model: {model.alias}
        thinking_mode: {model.thinking_mode}
        focus_areas: [{model.focus}]
        problem_context: "This is BUSINESS/SPECIFICATION ANALYSIS, not code analysis.
                         Feature: {FEATURE_NAME}
                         Integration: {INTEGRATION_NAME}"
        step: "{ANALYSIS_PROMPT}"
        step_number: 1
        total_steps: 3
        next_step_required: true
        findings: "{INITIAL_CONTEXT}"
        relevant_files: ["{ABSOLUTE_PATH_TO_SPEC}"]
        confidence: "exploring"

    CONTINUE chain for steps 2-3:
        step_number: 2, 3
        continuation_id: {from previous step}
        confidence: "low" → "high"
        next_step_required: true → false (on step 3)

    CAPTURE: model_result = {findings from final step}

SYNTHESIZE:
    CALL Task(subagent_type="general-purpose", model="haiku") with:
        strategy: {integration.parallel.synthesizer.strategy}
        inputs: [all model_results]
        Output: merged findings with deduplication and cross-model agreement
```

### Model Failure Handling

```
IF model call fails:
    LOG to model_failures
    DO NOT substitute with another model (variety principle)
    CONTINUE with remaining models

IF all models fail:
    SKIP ThinkDeep for this integration point
    PROCEED with internal reasoning
    LOG: "ThinkDeep skipped — all models failed"
```

---

## Integration 1: Challenge (Stage 2)

**Phase reference:** `thinkdeep.integrations.challenge` in config
**Trigger:** After BA spec draft, before Gate 1
**Purpose:** Challenge problem framing assumptions

### Parameters

| Parameter | Value |
|-----------|-------|
| Models | gpt5.2 (root_cause_analysis), pro (alternative_interpretations), x-ai/grok-4 (assumption_validation) |
| Thinking mode | high (all models) |
| Timeout | `thinkdeep.integrations.challenge.timeout_seconds` (default: 120s) |
| Synthesizer | haiku, union_with_dedup strategy |

### Analysis Prompt Template

```
Analyze this feature specification for problem framing quality:

1. Are the stated assumptions valid? Challenge each one.
2. Is the problem statement addressing root cause or symptoms?
3. Are there alternative interpretations of the user need?
4. What implicit assumptions might be wrong?
5. What market/competitive factors could invalidate this approach?

Feature: {FEATURE_NAME}
User Input: {USER_INPUT}
Spec sections: Problem Statement, True Need, JTBD
```

### Synthesis Output

```markdown
## MPA-Challenge Synthesis

### Cross-Model Agreement
| Finding | gpt5.2 | pro | grok-4 | Risk Level |
|---------|--------|-----|--------|------------|
| {finding} | {agree/disagree} | ... | ... | {GREEN/YELLOW/RED} |

### Risk Assessment
- Overall Risk: {GREEN | YELLOW | RED}
- Assumptions challenged: {N}
- Alternative interpretations: {N}
- Critical findings (require user review): {N}

### Findings by Model
#### gpt5.2 — Root Cause Analysis
{findings}
#### pro — Alternative Interpretations
{findings}
#### grok-4 — Assumption Validation
{findings}
```

### RED Flag Workflow

If overall risk is RED:
- Coordinator signals `needs-user-input`
- Present challenge findings with options:
  - "Revise problem framing" → re-invoke BA with findings
  - "Acknowledge and proceed" → proceed with noted risks
  - "Reject findings" → proceed without changes

### Report Output

Write to: `specs/{FEATURE_DIR}/analysis/mpa-challenge-parallel.md` (if parallel) or `analysis/mpa-challenge.md` (if single)

Use template: `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-challenge-parallel.md` or `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-challenge.md`

---

## Integration 2: Edge Cases (Stage 4)

**Phase reference:** `thinkdeep.integrations.edge_cases` in config
**Trigger:** After checklist validation, before clarification
**Purpose:** Mine edge cases across multiple dimensions

### Parameters

| Parameter | Value |
|-----------|-------|
| Models | pro (security_performance), gpt5.2 (user_experience), x-ai/grok-4 (accessibility_i18n_contrarian) |
| Thinking mode | pro=max, gpt5.2=high, grok-4=high |
| Timeout | `thinkdeep.integrations.edge_cases.timeout_seconds` (default: 150s) |
| Synthesizer | haiku, union_with_dedup with severity_boost |

### Analysis Prompt Template

```
Analyze this specification for edge cases and failure modes:

1. What happens when things go wrong? (error states, timeouts, failures)
2. What boundary conditions exist? (limits, extremes, empty states)
3. What security vulnerabilities could exist?
4. What performance bottlenecks are likely?
5. What accessibility issues might arise?
6. What i18n/l10n considerations are missing?
7. What concurrency or race conditions could occur?

Feature: {FEATURE_NAME}
Spec: {SPEC_CONTENT_SUMMARY}
Checklist gaps: {GAPS_FROM_STAGE_3}
```

### Severity Boost Protocol

Cross-model agreement boosts severity:
- 2 models agree on same edge case: MEDIUM → HIGH
- 3 models agree: HIGH → CRITICAL

### Auto-Injection to Clarification

CRITICAL and HIGH severity edge cases are automatically converted to clarification questions:

```
FOR EACH edge_case WHERE severity IN [CRITICAL, HIGH]:
    CREATE clarification question:
        question: "How should the system handle: {edge_case.description}?"
        context: "Identified by {N} models as {severity} severity"
        source: "MPA-EdgeCases"
```

### Report Output

Write to: `specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md` (if parallel) or `analysis/mpa-edgecases.md`

Use template: `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-edgecases-parallel.md` or `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-edgecases.md`

---

## Integration 3: Triangulation (Stage 4)

**Phase reference:** `thinkdeep.integrations.triangulation` in config
**Trigger:** After BA clarification questions generated, before user answers
**Purpose:** Generate additional questions from cross-model perspectives

### Parameters

| Parameter | Value |
|-----------|-------|
| Models | pro (technical), gpt5.2 (business), x-ai/grok-4 (contrarian) |
| Thinking mode | medium (all models) |
| Timeout | `thinkdeep.integrations.triangulation.timeout_seconds` (default: 90s) |
| Max additional questions | null (no limit) |
| Similarity threshold | 0.85 (for deduplication) |

### Analysis Prompt Template

```
Review this specification and existing clarification questions.
Generate 2-4 ADDITIONAL questions that are NOT covered by existing ones:

Existing questions: {EXISTING_QUESTION_LIST}
Spec: {SPEC_CONTENT_SUMMARY}
Edge cases found: {EDGE_CASE_SUMMARY}

Focus on questions that:
- Challenge scope boundaries
- Probe undefined behavior
- Question implicit requirements
- Explore cross-cutting concerns
```

### Semantic Deduplication

```
FOR EACH new_question FROM models:
    COMPARE against existing_questions using similarity_model (flash)
    IF similarity > threshold (0.85):
        DISCARD as duplicate
    ELSE:
        ADD to additional_questions

PRIORITY BOOST:
    All 3 sources agree (BA + both models) → CRITICAL
    2 sources agree → HIGH
    1 source only → MEDIUM
```

### Report Output

Write to: `specs/{FEATURE_DIR}/analysis/mpa-triangulation.md`

Use template: `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-triangulation.md`
