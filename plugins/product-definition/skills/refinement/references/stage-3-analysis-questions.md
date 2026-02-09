---
stage: stage-3-analysis-questions
artifacts_written:
  - requirements/analysis/thinkdeep-insights.md (conditional)
  - requirements/analysis/questions-product-strategy.md
  - requirements/analysis/questions-user-experience.md (conditional)
  - requirements/analysis/questions-business-ops.md (conditional)
  - requirements/working/QUESTIONS-{NNN}.md
---

# Stage 3: Analysis & Question Generation (Coordinator)

> This stage executes ThinkDeep analysis (if mode requires) then launches MPA agents for question generation.

## CRITICAL RULES (must follow — failure-prevention)

1. **CONTINUATION IDs ARE PER-CHAIN**: Each perspective×model combination gets its OWN `continuation_id` thread. NEVER share continuation_ids across different perspective×model combinations.
2. **ThinkDeep MUST complete before MPA agents**: MPA agents use ThinkDeep insights to inform option generation. Do NOT launch MPA agents until all ThinkDeep calls finish.
3. **PROBLEM_CONTEXT is MANDATORY**: Every ThinkDeep call MUST include `problem_context` with "This is BUSINESS/PRD ANALYSIS, not code analysis." Without it, models request source files that don't exist.
4. **FINDINGS must NEVER be empty**: Every ThinkDeep call MUST have non-empty `findings`. Empty findings = model has no context = hallucinated analysis.
5. **ABSOLUTE paths only**: All `relevant_files` MUST use absolute paths. Relative paths cause tool errors.

## Part A: Deep Analysis (ThinkDeep)

### Step 3A.1: Mode Check

```
IF ANALYSIS_MODE in {standard, rapid}:
    -> Skip Part A entirely

IF PAL_AVAILABLE = false:
    -> Skip Part A (graceful degradation)

IF ANALYSIS_MODE in {complete, advanced}:
    -> Continue to Step 3A.2
```

### Step 3A.2: ThinkDeep Execution

**CRITICAL:** ThinkDeep MUST complete before Part B. Insights inform option generation.

**ThinkDeep Framing Best Practices:**
See `@$CLAUDE_PLUGIN_ROOT/skills/refinement/references/config-reference.md` -> "PAL Tool Quick Reference"

Key points:
- `step`: Your current analysis and specific questions to extend (NOT just a title)
- `findings`: Your initial discoveries/assessment (NOT empty)
- `problem_context`: Explicit "This is BUSINESS/PRD ANALYSIS, not code analysis"
- `relevant_files`: Use ABSOLUTE paths

#### ThinkDeep Matrix

| Perspective | Focus Areas |
|-------------|-------------|
| COMPETITIVE | competitive_analysis, market_positioning |
| RISK | risk_assessment, assumption_validation |
| CONTRARIAN | assumption_challenge, blind_spots |

Models: Use model IDs from `config/requirements-config.yaml` -> `pal.thinkdeep.models[].id`
Steps per call: Use `config/requirements-config.yaml` -> `analysis_modes.{mode}.pal_thinkdeep_steps_per_call` (default: 3)

#### Execution

FOR each perspective in [COMPETITIVE, RISK, CONTRARIAN]:
  FOR each model in config -> pal.thinkdeep.models[].id:

```
# Step 1: Initial exploration
mcp__pal__thinkdeep(
  step: "{perspective.step_content}",
  step_number: 1,
  total_steps: 3,
  next_step_required: true,
  model: "{model}",
  thinking_mode: "high",
  confidence: "exploring",
  focus_areas: {perspective.focus_areas},
  findings: "{perspective.initial_findings}",
  hypothesis: "{perspective.hypothesis}",
  problem_context: "{PROBLEM_CONTEXT_TEMPLATE}",
  relevant_files: ["{ABSOLUTE_PATH_TO_DRAFT}"]
)
# -> Save continuation_id from response

# Step 2: Deepen analysis based on step 1 findings
mcp__pal__thinkdeep(
  step: "Deepen analysis: [summarize key findings from step 1, ask focused follow-ups]",
  step_number: 2,
  total_steps: 3,
  next_step_required: true,
  model: "{model}",
  thinking_mode: "high",
  confidence: "low",
  findings: "[Key discoveries from step 1]",
  continuation_id: "<from_step_1>",
  relevant_files: ["{ABSOLUTE_PATH_TO_DRAFT}"]
)
# -> Save continuation_id from response

# Step 3: Validate and synthesize
mcp__pal__thinkdeep(
  step: "Validate findings and synthesize final assessment for {perspective}",
  step_number: 3,
  total_steps: 3,
  next_step_required: false,
  model: "{model}",
  thinking_mode: "high",
  confidence: "high",
  findings: "[Accumulated evidence from steps 1-2]",
  continuation_id: "<from_step_2>",
  relevant_files: ["{ABSOLUTE_PATH_TO_DRAFT}"]
)

IF any step fails for model:
  -> Display PAL Model Failure notification (see error-handling.md)
  -> Log to state: thinkdeep_failures.append({model, perspective, step_number})
  -> Skip remaining steps for this model×perspective combination
```

**CRITICAL:** Each perspective×model combination gets its own 3-step chain with its own `continuation_id` thread. Different perspective×model combinations MUST NOT share continuation_ids — doing so corrupts the analysis context.

#### PROBLEM_CONTEXT_TEMPLATE (use for ALL perspectives)

```
IMPORTANT: This is a BUSINESS/PRD ANALYSIS, not code analysis.
We are evaluating market viability for a new product concept.
No source code exists yet - this is the requirements gathering phase.
Please analyze from a product strategy perspective, not engineering.

PRODUCT SUMMARY:
{Extract from draft: Vision, Problem, Target Users, Value Prop - 5-10 lines}
```

#### STEP CONTENT TEMPLATES

**COMPETITIVE:**
```
I'm analyzing the competitive landscape for {PRODUCT_NAME}.

MY CURRENT ANALYSIS:
{List 3-5 existing alternatives with assessment}

MY INITIAL THINKING:
- {Hypothesis about market gaps}
- {Hypothesis about positioning}

EXTEND MY ANALYSIS:
1. Identify competitors I may have missed
2. Analyze if existing players could easily add this feature
3. Evaluate the strength of the proposed positioning
4. Identify positioning opportunities and risks
```

**RISK:**
```
I'm analyzing BUSINESS RISKS for {PRODUCT_NAME}.

MY CURRENT RISK ASSESSMENT:
{Identified risks from draft}

MY INITIAL THINKING:
- {Hypothesis about highest-impact risks}
- {Hypothesis about weakest assumptions}

EXTEND MY RISK ANALYSIS:
1. What critical business risks am I missing?
2. Which assumptions are most likely WRONG?
3. What could cause complete failure?
4. How should risks be prioritized?
```

**CONTRARIAN:**
```
I need you to be a DEVIL'S ADVOCATE for {PRODUCT_NAME}.

THE CURRENT PROPOSAL:
{Brief summary of vision, problem, solution}

ASSUMPTIONS BEING MADE:
{List from draft}

CHALLENGE EVERYTHING:
1. Why might this problem NOT be worth solving?
2. Why might target users NOT pay?
3. What fundamental flaw might doom this?
4. What are we refusing to see?
5. Is there a simpler solution?
```

#### FINDINGS TEMPLATES

**COMPETITIVE:** "Initial assessment: {Summary from draft}. Existing solutions are {characterization}."
**RISK:** "Initial risk inventory: {N} major categories. Draft acknowledges doubts about {X}."
**CONTRARIAN:** "The proposal assumes {list}. Strongest point: {X}. Weakest point: {Y}."

#### Mode Variations

| Mode | Perspectives | Models | Steps/Call | Total Calls |
|------|-------------|--------|------------|-------------|
| complete | All 3 | 3 | 3 | 27 (3×3×3) |
| advanced | COMPETITIVE + RISK | 3 | 3 | 18 (2×3×3) |
| standard/rapid | Skip Part A | - | - | 0 |

> **Cost note:** Each perspective×model now uses 3 multi-step calls instead of 1. This improves analysis depth significantly but increases PAL usage. The `thinking_mode: "high"` setting already dominates cost — the additional steps add context chaining overhead but not additional thinking tokens per step.

### Step 3A.3: Synthesize ThinkDeep Insights

**BLOCKING:** Wait for ALL ThinkDeep calls to complete.

Aggregate insights by perspective and model. Write to: `requirements/analysis/thinkdeep-insights.md`

Structure:
```
===============================================================
COMPETITIVE PERSPECTIVE - Multi-Model Synthesis
===============================================================
### {MODEL_1} (Competitive) - {findings}
### {MODEL_2} (Competitive) - {findings}
### {MODEL_3} (Competitive) - {findings}
**Convergent Insights:** {where all 3 models agree}
**Divergent Insights:** {where models disagree - FLAG for questions}

[Repeat for RISK and CONTRARIAN perspectives]

===============================================================
CROSS-PERSPECTIVE SYNTHESIS
===============================================================
**Key Questions to Generate (from divergence):**
1. {Question where models disagreed}

**Assumptions Requiring User Validation:**
1. {Assumption flagged by multiple perspectives}
```

**Key Rule:** Divergence between models/perspectives = HIGH PRIORITY questions.
When all 3 models agree on a risk, the question is CRITICAL priority.

---

## Part B: MPA Question Generation

### Step 3B.1: Determine Question Focus

**If PRD_MODE = "EXTEND":** Focus on incomplete/missing sections only.
**If PRD_MODE = "NEW":** Generate questions for all PRD sections.

### Step 3B.2: Section Decomposition (Least-to-Most)

Before launching MPA agents, decompose complex PRD sections into sub-problems.
This ensures questions target specific aspects rather than addressing broad sections in one pass.

**For each required PRD section from config -> `prd.sections`:**

```
DECOMPOSE into sub-problems:

"Product Definition" ->
  1. Product vision and elevator pitch
  2. Is/Is Not boundaries (explicit scope)
  3. Success metrics and measurable outcomes

"Target Users" ->
  1. Primary persona (demographics, goals, pain points)
  2. Secondary personas
  3. Anti-personas (who this is NOT for)

"Problem Analysis" ->
  1. Problem statement and evidence
  2. Current alternatives and workarounds
  3. Cost of inaction

"Value Proposition" ->
  1. Core value and differentiation
  2. Competitive positioning
  3. Unique selling points

"Core Workflows" ->
  1. Primary user journey (happy path)
  2. Secondary journeys
  3. Edge cases and error recovery flows
  4. Cross-journey transitions

"Feature Inventory" ->
  1. MVP features (must-have for launch)
  2. Post-MVP features (nice-to-have)
  3. Explicit exclusions (will NOT do)

"Business Constraints" ->
  1. Budget and resource constraints
  2. Regulatory and compliance requirements
  3. Timeline and launch constraints
```

**If PRD_MODE = "EXTEND":** Only decompose sections with PARTIAL or MISSING status.

**If REFLECTION_CONTEXT is provided (from iteration loop):**
Prioritize sub-problems that map to weak dimensions identified in the reflection.

Pass decomposition to MPA agents as `SECTION_DECOMPOSITION` in their prompt context.

### Step 3B.3: MPA Agent Dispatch

**If ANALYSIS_MODE in {complete, advanced, standard}:**

Launch 3 MPA agents **in parallel** using Task tool, passing ThinkDeep insights (if available from Part A):

```
Task(subagent_type="requirements-product-strategy", prompt="
FEATURE_DIR: requirements
DRAFT_CONTENT: {contents of requirements/working/draft-copy.md}
PRD_MODE: {NEW|EXTEND}
RESEARCH_SYNTHESIS: {contents of research-synthesis.md if exists}

===============================================================
SECTION DECOMPOSITION (generate questions at sub-problem level)
===============================================================
{SECTION_DECOMPOSITION from Step 3B.2}

===============================================================
THINKDEEP INSIGHTS (USE THESE TO INFORM YOUR OPTIONS)
===============================================================
{contents of thinkdeep-insights.md if exists, otherwise 'No ThinkDeep insights available'}

===============================================================
REFLECTION CONTEXT (from previous round — if available)
===============================================================
{REFLECTION_CONTEXT if provided, otherwise 'First round — no prior reflection'}

CRITICAL INSTRUCTIONS:
1. Use ThinkDeep CONVERGENT insights to strengthen recommended options
2. Use ThinkDeep DIVERGENT insights to identify questions needing multiple options
3. When ThinkDeep flags a risk, ensure at least one option mitigates it
4. When ThinkDeep identifies a market gap, ensure options address it
5. Priority assignment:
   - CRITICAL: Flagged by all 3 ThinkDeep perspectives
   - HIGH: Flagged by 2+ perspectives or model divergence
   - MEDIUM: Flagged by 1 perspective

Generate strategic questions following your 6-step Sequential Thinking protocol.
Output to: requirements/analysis/questions-product-strategy.md
")

Task(subagent_type="requirements-user-experience", prompt="...")
Task(subagent_type="requirements-business-ops", prompt="...")
```

**If ANALYSIS_MODE = rapid:**
Launch single agent (no ThinkDeep):
```
Task(subagent_type="requirements-product-strategy", prompt="
Generate ALL essential questions covering all PRD sections. NO LIMIT on number.
Output to: requirements/analysis/questions-product-strategy.md
")
```

**If ANALYSIS_MODE = standard (no ThinkDeep):**
Launch 3 MPA agents WITHOUT ThinkDeep insights.

### Step 3B.4: Question Synthesis

**If ANALYSIS_MODE = complete AND ST_AVAILABLE = true:**
Execute Sequential Thinking for structured synthesis (8 steps):
1. Question Inventory
2. Semantic Deduplication
3-7. [Analysis steps]
8. Final Formatting

Then launch synthesis agent.

**If ANALYSIS_MODE in {advanced, standard}:**
Launch synthesis agent WITHOUT Sequential Thinking.

**If ANALYSIS_MODE = rapid:**
Skip synthesis — use product-strategy agent output directly.

```
Task(subagent_type="requirements-question-synthesis", prompt="
FEATURE_DIR: requirements
ROUND_NUMBER: {N}
PRD_MODE: {NEW|EXTEND}
ANALYSIS_MODE: {MODE}

INPUT FILES:
- requirements/analysis/questions-product-strategy.md
- requirements/analysis/questions-user-experience.md
- requirements/analysis/questions-business-ops.md
- requirements/analysis/thinkdeep-insights.md (reference)

Output: requirements/working/QUESTIONS-{NNN}.md
")
```

> **See `option-generation-reference.md`** for detailed option/scoring algorithms.

### Step 3B.5: Sanity Check (Fail-Fast)

Before completing, validate:
1. At least 5 questions generated
2. All major PRD sections have at least 1 question
3. Each question has 3+ distinct options
4. Question titles are unique

**If validation fails:**
Set `status: needs-user-input` with options:
- Regenerate questions (Recommended)
- Proceed anyway
- Add manual questions

### Step 3B.6: Update State (CHECKPOINT)

```yaml
current_stage: 3
question_round: {N}
rounds:
  - round_number: {N}
    questions_file: "working/QUESTIONS-{NNN}.md"
    analysis_mode: "{MODE}"
    questions_count: {N}
    generated_at: "{timestamp}"
```

**Git Suggestion:**
```
git add requirements/working/QUESTIONS-{NNN}.md requirements/analysis/
git commit -m "question(req): round {N} questions generated ({COUNT} items)"
```

## Summary Contract

```yaml
---
stage: "analysis-questions"
stage_number: 3
status: completed
checkpoint: ANALYSIS_QUESTIONS
artifacts_written:
  - requirements/analysis/thinkdeep-insights.md (conditional - only if ThinkDeep ran)
  - requirements/analysis/questions-product-strategy.md
  - requirements/analysis/questions-user-experience.md (conditional - only if MPA mode)
  - requirements/analysis/questions-business-ops.md (conditional - only if MPA mode)
  - requirements/working/QUESTIONS-{NNN}.md
summary: "Generated {N} questions across {M} perspectives with ThinkDeep insights"
flags:
  round_number: {N}
  questions_count: {N}
  analysis_mode: "{MODE}"
  thinkdeep_calls: {27|18|0}
---
```

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. `requirements/working/QUESTIONS-{NNN}.md` exists and contains at least 5 questions
2. Each question has 3+ options with pros/cons
3. If ThinkDeep ran: `requirements/analysis/thinkdeep-insights.md` exists
4. State file was updated with `current_stage: 3`
5. Summary YAML frontmatter has no placeholder values (no `{N}` literals)

## CRITICAL RULES REMINDER

- Continuation IDs are PER-CHAIN — never shared across perspective×model combinations
- ThinkDeep MUST complete before MPA agents launch
- PROBLEM_CONTEXT and FINDINGS must NEVER be empty
- All file paths MUST be absolute
