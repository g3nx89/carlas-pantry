# Phase 6: Deep Analysis (ThinkDeep)

> **Source:** Extracted from `/product-definition:requirements` main orchestration

**Checkpoint:** `DEEP_ANALYSIS`

**Goal:** Execute multi-model ThinkDeep analysis across competitive, risk, and contrarian perspectives.

> **Note:** This phase only runs for `complete` and `advanced` analysis modes.
> For `standard` and `rapid` modes, skip directly to Phase 7 (Question Generation).

## Step 6.1: Check Analysis Mode

```
IF ANALYSIS_MODE in {standard, rapid}:
    -> Skip to Phase 7 (Question Generation)

IF PAL_AVAILABLE = false:
    -> Skip to Phase 7 (graceful degradation)

IF ANALYSIS_MODE in {complete, advanced}:
    -> Continue to Step 6.2
```

## Step 6.2: PAL ThinkDeep Execution

**IMPORTANT:** This step MUST complete before Phase 7 (MPA agents). ThinkDeep insights inform option generation.

### ThinkDeep Framing Best Practices

> **CRITICAL:** See `config-reference.md` → "PAL Tool Best Practices" for full documentation.
>
> Key points:
> - `step`: Your current analysis and specific questions to extend (NOT just a title)
> - `findings`: Your initial discoveries/assessment (NOT empty)
> - `problem_context`: Explicit "This is BUSINESS/PRD ANALYSIS, not code analysis"
> - `relevant_files`: Use ABSOLUTE paths (e.g., `/Users/.../requirements/working/draft-copy.md`)

### ThinkDeep Matrix Definition

| Perspective | Focus Areas |
|-------------|-------------|
| COMPETITIVE | competitive_analysis, market_positioning |
| RISK | risk_assessment, assumption_validation |
| CONTRARIAN | assumption_challenge, blind_spots |

### Models

- `gpt-5.2`
- `gemini-3-pro-preview`
- `x-ai/grok-4`

### Execution (Complete mode = 3x3 = 9 calls)

FOR each `perspective` in [COMPETITIVE, RISK, CONTRARIAN]:
  FOR each `model` in [gpt-5.2, gemini-3-pro-preview, x-ai/grok-4]:

```
mcp__pal__thinkdeep(
  step: "{perspective.step_content}",  // See STEP CONTENT TEMPLATES below
  step_number: 1,
  total_steps: 1,
  next_step_required: false,
  model: "{model}",
  thinking_mode: "high",
  focus_areas: {perspective.focus_areas},
  findings: "{perspective.initial_findings}",  // See FINDINGS TEMPLATES below
  hypothesis: "{perspective.hypothesis}",
  problem_context: "{PROBLEM_CONTEXT_TEMPLATE}",  // See below - ALWAYS include PRD disclaimer
  relevant_files: ["{ABSOLUTE_PATH_TO_DRAFT}"]  // MUST be absolute path!
)

IF model fails:
  -> Display PAL Model Failure notification (see error-handling.md)
  -> Log to state: thinkdeep_failures.append({model, perspective})
```

### PROBLEM_CONTEXT_TEMPLATE (use for ALL perspectives)

```
IMPORTANT: This is a BUSINESS/PRD ANALYSIS, not code analysis.
We are evaluating market viability for a new mobile app concept.
No source code exists yet - this is the requirements gathering phase.
Please analyze from a product strategy perspective, not engineering.

PRODUCT SUMMARY:
{Extract from draft: Vision, Problem, Target Users, Value Prop - 5-10 lines}
```

### STEP CONTENT TEMPLATES

**COMPETITIVE Perspective:**
```
I'm analyzing the competitive landscape for {PRODUCT_NAME}.

MY CURRENT ANALYSIS:
{List 3-5 existing alternatives from draft section 3.5, with your assessment of each}

1. **{Alternative 1}**: {Description}. Problems: {issues}
2. **{Alternative 2}**: {Description}. Problems: {issues}
...

MY INITIAL THINKING:
- {Your hypothesis about market gaps}
- {Your hypothesis about positioning}
- {Your hypothesis about competitive moat}

EXTEND MY ANALYSIS - I need you to:
1. Identify competitors I may have missed (especially digital/app solutions)
2. Analyze if existing players could easily add this feature
3. Evaluate the strength of the proposed positioning
4. Identify positioning opportunities and risks from competition
```

**RISK Perspective:**
```
I'm analyzing BUSINESS RISKS for {PRODUCT_NAME}.

MY CURRENT RISK ASSESSMENT:
Based on the draft, I've identified these potential risks:

1. **{Risk Category 1}**: {Description of risk from draft doubts/uncertainties}
2. **{Risk Category 2}**: {Description}
...

MY INITIAL THINKING:
- {Your hypothesis about highest-impact risks}
- {Your hypothesis about which assumptions are weakest}

EXTEND MY RISK ANALYSIS:
1. What critical business risks am I missing?
2. Which assumptions in the draft are most likely to be WRONG?
3. What could cause this product to completely fail?
4. How should risks be prioritized (probability × impact)?
```

**CONTRARIAN Perspective:**
```
I need you to be a DEVIL'S ADVOCATE for {PRODUCT_NAME}.

THE CURRENT PROPOSAL:
{Brief summary of vision, problem, solution}

ASSUMPTIONS BEING MADE:
1. {Assumption from draft}
2. {Assumption from draft}
...

CHALLENGE EVERYTHING:
1. Why might this problem NOT be worth solving?
2. Why might the target users NOT pay for this?
3. What fundamental flaw might doom this product?
4. What are we refusing to see because we're emotionally invested?
5. Is there a simpler solution we're overcomplicating?
```

### FINDINGS TEMPLATES

**COMPETITIVE:**
```
Initial assessment: {Summary of competitive landscape from draft}.
Existing solutions are {characterization}. The combination of {unique factors}
appears to be {assessment of niche - unfilled/crowded/emerging}.
```

**RISK:**
```
Initial risk inventory identifies {N} major risk categories: {list}.
The draft acknowledges doubts about {from section 2.3}, but may underestimate
{your assessment of hidden risks}.
```

**CONTRARIAN:**
```
The proposal assumes {list key assumptions}. These assumptions are {assessment}.
The strongest point is {X}. The weakest point that could invalidate everything is {Y}.
```

### Mode Variations

| Mode | Perspectives | Models | Total Calls |
|------|--------------|--------|-------------|
| `complete` | All 3 (COMPETITIVE, RISK, CONTRARIAN) | 3 | 9 |
| `advanced` | COMPETITIVE + RISK only | 3 | 6 |
| `standard/rapid` | Skip Phase 6 entirely | - | 0 |

---

## Step 6.3: Synthesize ThinkDeep Insights

**BLOCKING STEP:** Wait for ALL ThinkDeep calls to complete before proceeding.

After all ThinkDeep calls complete, aggregate insights by perspective and model:

```
THINKDEEP_INSIGHTS = """
===============================================================
COMPETITIVE PERSPECTIVE - Multi-Model Synthesis
===============================================================

### gpt-5.2 (Competitive)
{findings from competitive/gpt-5.2}

### gemini-3-pro-preview (Competitive)
{findings from competitive/gemini-3-pro-preview}

### x-ai/grok-4 (Competitive)
{findings from competitive/x-ai/grok-4}

**Convergent Insights:** {where all 3 models agree}
**Divergent Insights:** {where models disagree - FLAG for questions}

===============================================================
RISK PERSPECTIVE - Multi-Model Synthesis
===============================================================

### gpt-5.2 (Risk)
{findings from risk/gpt-5.2}

### gemini-3-pro-preview (Risk)
{findings from risk/gemini-3-pro-preview}

### x-ai/grok-4 (Risk)
{findings from risk/x-ai/grok-4}

**Convergent Insights:** {where all 3 models agree}
**Divergent Insights:** {where models disagree - FLAG for questions}

===============================================================
CONTRARIAN PERSPECTIVE - Multi-Model Synthesis
===============================================================

### gpt-5.2 (Contrarian)
{findings from contrarian/gpt-5.2}

### gemini-3-pro-preview (Contrarian)
{findings from contrarian/gemini-3-pro-preview}

### x-ai/grok-4 (Contrarian)
{findings from contrarian/x-ai/grok-4}

===============================================================
CROSS-PERSPECTIVE SYNTHESIS
===============================================================

**Key Questions to Generate (from divergence):**
1. {Question where models disagreed significantly}
2. {Question where perspectives conflict}
3. ...

**Assumptions Requiring User Validation:**
1. {Assumption flagged by multiple perspectives}
2. ...
"""
```

Write to: `requirements/analysis/thinkdeep-insights.md`

**Key Insight:** Divergence between models/perspectives = HIGH PRIORITY questions.
When all 3 models agree on a risk, the question is CRITICAL priority.

---

## Step 6.4: Update State (CHECKPOINT)

```yaml
current_phase: "DEEP_ANALYSIS"
phase_status: "completed"

phases:
  deep_analysis:
    status: completed
    mode: "{ANALYSIS_MODE}"
    thinkdeep_calls: {9|6|0}
    insights_file: "requirements/analysis/thinkdeep-insights.md"
    timestamp: "{now}"
```

**Proceed to Phase 7 (Question Generation)**
