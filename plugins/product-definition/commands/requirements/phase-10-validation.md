# Phase 10: PRD Validation

> **Source:** Extracted from `/product-definition:requirements` main orchestration

**Checkpoint:** `VALIDATION`

**Goal:** Assess PRD readiness through multi-model validation and determine if requirements are sufficient.

## Step 10.1: Ask for Validation Level

**Check PAL availability first:**

If `PAL_AVAILABLE = false`:
- Only offer "Single model validation" (internal) or "Skip validation"
- Explain: "PAL Consensus unavailable. Using internal validation only."

Use `AskUserQuestion`:

**If PAL available:**
```json
{
  "questions": [{
    "question": "All information gathered. What validation level for PRD readiness?",
    "header": "Validation",
    "multiSelect": false,
    "options": [
      {"label": "PAL Consensus (3 models) (Recommended)", "description": "Multi-model validation for highest confidence"},
      {"label": "Single model validation", "description": "Faster, less thorough"},
      {"label": "Skip validation", "description": "Generate PRD without validation gate"}
    ]
  }]
}
```

**If PAL NOT available:**
```json
{
  "questions": [{
    "question": "All information gathered. What validation level for PRD readiness?\n\n**Note:** PAL tools unavailable. Multi-model validation disabled.",
    "header": "Validation",
    "multiSelect": false,
    "options": [
      {"label": "Internal validation (Recommended)", "description": "Single-perspective validation using internal reasoning"},
      {"label": "Skip validation", "description": "Generate PRD without validation gate"}
    ]
  }]
}
```

## Step 10.2: Execute PAL Consensus (if selected and available)

> **IMPORTANT:** See `config-reference.md` → "PAL Consensus Configuration" for parameter reference.
> Consensus is a SINGLE-CALL tool that auto-synthesizes perspectives. Do NOT use multi-step pattern.
> Pattern wildcards (e.g., `*.md`) are NOT supported - list each file explicitly.

### If user selected "PAL Consensus (3 models)" AND PAL_AVAILABLE = true:

```
mcp__pal__consensus(
  prompt: """
I need to evaluate if this PRD is ready for development handoff.

CONTEXT:
I've gathered user responses across {N} question rounds totaling {TOTAL} questions answered.

MY CURRENT ASSESSMENT:

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
- Gaps identified: {list any remaining gaps}
- Contradictions found: {list any conflicts in responses}

QUESTIONS FOR CONSENSUS:
1. Score each dimension 1-4 (1=missing, 2=partial, 3=adequate, 4=complete)
2. Flag any blocking issues that prevent PRD generation
3. Identify sections that need user clarification vs can proceed with assumptions

DELIVERABLE:
Synthesize into a final PRD readiness score (0-20) with:
- Per-dimension scores with justification
- Blocking issues (if any)
- Final recommendation: READY (>=16), CONDITIONAL (12-15), or NOT READY (<12)

Weight the 'against' perspective heavily - if blocking issues are found, they must be addressed.
""",
  models: [
    {"model": "gemini-3-pro-preview", "stance": "neutral", "stance_prompt": "Provide objective assessment. Score each dimension fairly based on evidence. Don't favor proceeding or blocking without justification."},
    {"model": "gpt-5.2", "stance": "for", "stance_prompt": "Assume requirements are sufficient, validate completeness. Look for reasons this PRD IS ready. Advocate for proceeding where reasonable."},
    {"model": "x-ai/grok-4", "stance": "against", "stance_prompt": "Challenge PRD completeness. Find what's MISSING. Be skeptical. What would a developer complain about? What gaps would block implementation?"}
  ],
  files: [
    "{ABSOLUTE_PATH}/requirements/working/QUESTIONS-001.md",
    "{ABSOLUTE_PATH}/requirements/working/QUESTIONS-002.md",
    "{ABSOLUTE_PATH}/requirements/working/draft-copy.md",
    "{ABSOLUTE_PATH}/requirements/research/research-synthesis.md"
  ],
  focus_areas: ["product_definition", "scope_clarity", "developer_handoff_readiness"],
  thinking_mode: "high",
  temperature: 0.2
)
```

### If user selected "Single model validation" or "Internal validation":

Perform internal evaluation using the same 7 dimensions. Score 1-4 for each and calculate total.

### If user selected "Skip validation":

Skip to Phase 11 with warning: "PRD generated without validation gate"

## Step 10.3: Process Validation Result

**Evaluation Dimensions (1-4 each):**
1. Product Definition completeness
2. Target Users clarity
3. Problem Validation depth
4. Value Proposition strength
5. Workflow Coverage
6. Feature Inventory completeness
7. No Technical Content (MUST be 4/4)

**Thresholds:** See `$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml` -> `scoring.prd_readiness.*`

| Total Score | Decision |
|-------------|----------|
| >=16/20 | GREEN READY -> Proceed to Phase 11 |
| 12-15/20 | YELLOW CONDITIONAL -> Proceed with warnings |
| <12/20 | RED NOT READY -> Gather more information |

## Step 10.4: Update State (CHECKPOINT)

```yaml
phases:
  validation:
    status: completed
    mode: "{pal_consensus|single|internal|skipped}"
    score: {N}/20
    decision: "{READY|CONDITIONAL|NOT_READY}"
```
