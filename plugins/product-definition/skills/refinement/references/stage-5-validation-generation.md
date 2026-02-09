---
stage: stage-5-validation-generation
artifacts_written:
  - requirements/PRD.md (conditional - only if validation passes)
  - requirements/decision-log.md (conditional - only if PRD generated)
---

# Stage 5: Validation & PRD Generation (Coordinator)

> This stage validates PRD readiness and generates/extends the PRD.

## CRITICAL RULES (must follow — failure-prevention)

1. **RED validation = NO PRD generation**: If validation score < `conditional` threshold, set `flags.next_action: "loop_questions"` and STOP. Do NOT generate PRD.
2. **Technical content MUST be filtered**: PRD MUST NOT contain any forbidden technical keywords. Scan and remove BEFORE finalizing.
3. **EXTEND mode preserves existing sections**: NEVER overwrite complete sections in existing PRD. Only add/update incomplete sections.
4. **Consensus requires minimum 2 models**: If < 2 PAL models available after failures, FAIL and notify user.
5. **All file paths MUST be absolute** in PAL `relevant_files` parameter.

## Step 5.1: Validation Level Selection

Set `status: needs-user-input` with `pause_type: interactive`:

**If PAL_AVAILABLE = true:**
```yaml
flags:
  block_reason: "Ask user for validation level"
  question_context:
    question: "All information gathered. What validation level for PRD readiness?"
    header: "Validation"
    options:
      - label: "PAL Consensus (3 models) (Recommended)"
        description: "Multi-model validation for highest confidence"
      - label: "Single model validation"
        description: "Faster, less thorough"
      - label: "Skip validation"
        description: "Generate PRD without validation gate"
```

**If PAL NOT available:**
```yaml
flags:
  block_reason: "Ask user for validation level (PAL unavailable)"
  question_context:
    question: "All information gathered. What validation level for PRD readiness?\n\n**Note:** PAL tools unavailable."
    header: "Validation"
    options:
      - label: "Internal validation (Recommended)"
        description: "Single-perspective validation using internal reasoning"
      - label: "Skip validation"
        description: "Generate PRD without validation gate"
```

## Step 5.2: Execute Validation

### If PAL Consensus selected AND PAL_AVAILABLE = true:

Execute multi-step Consensus for PRD readiness validation:

```
# Step 1: YOUR independent readiness analysis
mcp__pal__consensus(
  step: """
I need to evaluate if this PRD is ready for development handoff.

CONTEXT: {N} question rounds, {TOTAL} questions answered.

DIMENSION CHECKLIST (score 1-4 each):
1. Product Definition - Is the vision clear and bounded?
2. Target Users - Are personas specific and validated?
3. Problem Validation - Is the problem real and worth solving?
4. Value Proposition - Is the differentiation clear?
5. Workflow Coverage - Are core user journeys defined?
6. Feature Inventory - Is scope clear (what's in/out)?
7. No Technical Content - Is PRD free of implementation details? (MUST be 4/4)

MY INITIAL FINDINGS:
- Questions answered: {N}/{TOTAL}
- Gaps identified: {list}
- Contradictions found: {list}

DELIVERABLE:
Final PRD readiness score (0-20) with per-dimension scores.
Recommendation: READY (>=16), CONDITIONAL (12-15), or NOT READY (<12).
""",
  step_number: 1,
  total_steps: 4,           # 3 models + 1 synthesis (adjust to 3 if grok-4 unavailable)
  next_step_required: true,
  findings: "Initial assessment: {N}/{TOTAL} questions answered. Gaps: {list}. Contradictions: {list}.",
  # NOTE: If x-ai/grok-4 is unavailable (optional: true in config), remove it from
  # the models array and set total_steps = 3 (2 models + 1 synthesis).
  models: [
    {"model": "gemini-3-pro-preview", "stance": "neutral", "stance_prompt": "Objective assessment of readiness against all 7 dimensions."},
    {"model": "gpt-5.2", "stance": "for", "stance_prompt": "Advocate for proceeding where reasonable. Score generously where evidence supports."},
    {"model": "x-ai/grok-4", "stance": "against", "stance_prompt": "Challenge completeness. Find what's MISSING. Score strictly."}
  ],
  relevant_files: [
    "{ABSOLUTE_PATH}/requirements/working/QUESTIONS-001.md",
    "{ABSOLUTE_PATH}/requirements/working/QUESTIONS-002.md",
    "{ABSOLUTE_PATH}/requirements/working/draft-copy.md",
    "{ABSOLUTE_PATH}/requirements/research/research-synthesis.md"
  ]
)
# -> Save continuation_id from response

# Step 2: Process first model's readiness assessment
mcp__pal__consensus(
  step: "Notes on gemini-3-pro-preview (neutral) readiness assessment",
  step_number: 2,
  total_steps: 4,
  next_step_required: true,
  findings: "Gemini (neutral) scores: [per-dimension scores]. Recommendation: [READY/CONDITIONAL/NOT_READY]",
  continuation_id: "<from_step_1>"
)

# Step 3: Process second model's readiness assessment
mcp__pal__consensus(
  step: "Notes on gpt-5.2 (for) readiness assessment",
  step_number: 3,
  total_steps: 4,
  next_step_required: true,
  findings: "GPT-5.2 (for) scores: [per-dimension scores]. Recommendation: [READY/CONDITIONAL/NOT_READY]",
  continuation_id: "<from_step_2>"
)

# Step 4: Final synthesis with aggregated scores
mcp__pal__consensus(
  step: "Synthesize all model assessments into final readiness score and recommendation",
  step_number: 4,
  total_steps: 4,
  next_step_required: false,
  findings: "Final consensus: [aggregated score]/20. Recommendation: [READY/CONDITIONAL/NOT_READY]",
  continuation_id: "<from_step_3>"
)
```

### If Single model / Internal validation:
Perform internal evaluation using the same 7 dimensions. Score 1-4 each.

### If Skip validation:
Proceed to Step 5.4 with warning: "PRD generated without validation gate"

## Step 5.3: Process Validation Result

**Thresholds from config -> `scoring.prd_readiness.*`:**

| Total Score | Decision |
|-------------|----------|
| >= `ready` threshold | GREEN: READY -> Proceed to Step 5.4 |
| >= `conditional` threshold | YELLOW: CONDITIONAL -> Proceed with warnings |
| < `conditional` threshold | RED: NOT READY -> Set flags.next_action: loop_questions |

**If RED:**
Set in summary:
```yaml
flags:
  validation_decision: "NOT_READY"
  validation_score: {N}
  next_action: "loop_questions"
```
Do NOT proceed to PRD generation. Orchestrator will loop back to Stage 3.

## Step 5.4: Launch PRD Generator

```
Task(subagent_type="requirements-prd-generator", prompt="
Pass:
- All completed QUESTIONS files
- research-synthesis.md (if exists)
- PRD.md (if EXTEND mode)
- User decisions from state
")
```

**If PRD_MODE = "NEW":**
Generate complete PRD.md from template at `$CLAUDE_PLUGIN_ROOT/templates/prd-template.md`

**If PRD_MODE = "EXTEND":**
Merge new answers into existing PRD.md sections.
Preserve existing complete sections.
Add/update incomplete sections.

## Step 5.5: Technical Content Filter

Scan PRD.md for forbidden keywords:
- API, endpoint, backend, frontend, database, server
- architecture, implementation, deploy, microservice
- sprint, story point, velocity, refactor, technical debt
- latency, throughput, cache, optimization
- Kotlin, Swift, React, AWS, Firebase, PostgreSQL, MongoDB

**If found:** Remove or replace with non-technical alternatives.

## Step 5.6: Generate Decision Log

Create/Update `requirements/decision-log.md` using template at `$CLAUDE_PLUGIN_ROOT/templates/decision-log-template.md`:
- All questions with selected answers
- Rationale for each decision
- Cross-references to PRD sections

## Step 5.7: Update State (CHECKPOINT)

```yaml
current_stage: 5
phases:
  validation:
    status: completed
    mode: "{pal_consensus|single|internal|skipped}"
    score: {N}/20
    decision: "{READY|CONDITIONAL|NOT_READY}"
  prd_generation:
    status: completed
    prd_mode: "{NEW|EXTEND}"
    sections_generated: {N}
    sections_extended: {N}
```

**Git Suggestion:**
```
git add requirements/PRD.md requirements/decision-log.md
git commit -m "prd(req): generate PRD v{VERSION}"
git tag prd-v{VERSION}.0.0
```

## Summary Contract

```yaml
---
stage: "validation-generation"
stage_number: 5
status: completed
checkpoint: VALIDATION_PRD
artifacts_written:
  - requirements/PRD.md
  - requirements/decision-log.md
summary: "Validation score: {N}/20 ({DECISION}). PRD generated in {MODE} mode."
flags:
  validation_score: {N}
  validation_decision: "READY" | "CONDITIONAL" | "NOT_READY"
  dimension_scores:
    product_definition: {1-4}
    target_users: {1-4}
    problem_validation: {1-4}
    value_proposition: {1-4}
    workflow_coverage: {1-4}
    feature_inventory: {1-4}
    no_technical_content: {1-4}
  weak_dimensions:
    - "{dimension with score <= 2}"
  strong_dimensions:
    - "{dimension with score >= 3}"
  prd_mode: "{NEW|EXTEND}"
  next_action: null | "loop_questions"
---
```

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. If validation passed: `requirements/PRD.md` exists and is non-empty
2. If validation passed: `requirements/decision-log.md` exists
3. PRD does NOT contain any forbidden technical keywords (run scan)
4. If RED validation: PRD was NOT generated and `flags.next_action` = `"loop_questions"`
5. State file was updated with `current_stage: 5`
6. Summary YAML frontmatter has no placeholder values

## CRITICAL RULES REMINDER

- RED validation = NO PRD generation — loop back to Stage 3
- Technical content MUST be filtered from PRD
- EXTEND mode preserves existing complete sections
- Consensus requires minimum 2 models
