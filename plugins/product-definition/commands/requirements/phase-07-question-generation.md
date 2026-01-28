# Phase 7: Question Generation (MPA Agents)

> **Source:** Extracted from `/product-definition:requirements` main orchestration

**Checkpoint:** `QUESTION_GENERATION`

**Goal:** Generate clarification questions using MPA agents with ThinkDeep-informed options and recommendations.

## Step 7.1: Determine Question Focus

**If PRD_MODE = "EXTEND":**
Focus questions on incomplete/missing sections only

**If PRD_MODE = "NEW":**
Generate questions for all PRD sections

---

## Step 7.2: MPA Agent Execution

**PREREQUISITE:** If ANALYSIS_MODE in {complete, advanced}, Phase 6 (ThinkDeep insights) MUST be complete.

### If ANALYSIS_MODE in {complete, advanced, standard}:

Launch 3 MPA agents **in parallel** using Task tool, **passing ThinkDeep insights** (if available):

```
Task(subagent_type="requirements-product-strategy", description="Product Strategy questions", prompt="
FEATURE_DIR: requirements
DRAFT_CONTENT: {contents of requirements/working/draft-copy.md}
PRD_MODE: {NEW|EXTEND}
RESEARCH_SYNTHESIS: {contents of research-synthesis.md if exists}

===============================================================
THINKDEEP INSIGHTS (USE THESE TO INFORM YOUR OPTIONS)
===============================================================
{contents of requirements/analysis/thinkdeep-insights.md if exists, otherwise "No ThinkDeep insights available - using standard analysis"}

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
If Sequential Thinking unavailable, use internal structured reasoning.
Output to: requirements/analysis/questions-product-strategy.md
")

Task(subagent_type="requirements-user-experience", description="UX questions", prompt="
FEATURE_DIR: requirements
DRAFT_CONTENT: {contents of requirements/working/draft-copy.md}
PRD_MODE: {NEW|EXTEND}
RESEARCH_SYNTHESIS: {contents of research-synthesis.md if exists}

===============================================================
THINKDEEP INSIGHTS (USE THESE TO INFORM YOUR OPTIONS)
===============================================================
{contents of requirements/analysis/thinkdeep-insights.md if exists}

CRITICAL INSTRUCTIONS:
1. Use COMPETITIVE insights to understand how competitors solve UX problems
2. Use RISK insights to identify UX assumptions needing validation
3. Use CONTRARIAN insights to challenge UX assumptions
4. Ensure options reflect real market alternatives

Generate UX questions following your protocol.
Output to: requirements/analysis/questions-user-experience.md
")

Task(subagent_type="requirements-business-ops", description="Business Ops questions", prompt="
FEATURE_DIR: requirements
DRAFT_CONTENT: {contents of requirements/working/draft-copy.md}
PRD_MODE: {NEW|EXTEND}
RESEARCH_SYNTHESIS: {contents of research-synthesis.md if exists}

===============================================================
THINKDEEP INSIGHTS (USE THESE TO INFORM YOUR OPTIONS)
===============================================================
{contents of requirements/analysis/thinkdeep-insights.md if exists}

CRITICAL INSTRUCTIONS:
1. Use RISK insights directly - they map to business operations concerns
2. Use COMPETITIVE insights to understand operational differentiators
3. Ensure at least one option addresses each identified business risk

Generate business ops questions following your protocol.
Output to: requirements/analysis/questions-business-ops.md
")
```

### If ANALYSIS_MODE = rapid:

Launch single BA agent (no ThinkDeep insights available):
```
Task(subagent_type="requirements-product-strategy", description="Rapid question generation", prompt="
FEATURE_DIR: requirements
DRAFT_CONTENT: {contents of requirements/working/draft-copy.md}
PRD_MODE: {NEW|EXTEND}

Generate ALL essential questions covering all PRD sections. NO LIMIT on number - completeness is the goal.
Skip detailed Sequential Thinking - use direct analysis.
Output to: requirements/analysis/questions-product-strategy.md
")
```

### If ANALYSIS_MODE = standard (no ThinkDeep):

Launch 3 MPA agents **in parallel** WITHOUT ThinkDeep insights:
```
Task(subagent_type="requirements-product-strategy", description="Product Strategy questions", prompt="
FEATURE_DIR: requirements
DRAFT_CONTENT: {contents of requirements/working/draft-copy.md}
PRD_MODE: {NEW|EXTEND}
RESEARCH_SYNTHESIS: {contents of research-synthesis.md if exists}

Generate strategic questions following your 6-step protocol.
Output to: requirements/analysis/questions-product-strategy.md
")

Task(subagent_type="requirements-user-experience", description="UX questions", prompt="...")
Task(subagent_type="requirements-business-ops", description="Business Ops questions", prompt="...")
```

---

## Step 7.3: Question Synthesis

### If ANALYSIS_MODE = complete AND ST_AVAILABLE = true:

First, execute Sequential Thinking for structured synthesis:

```
mcp__sequential-thinking__sequentialthinking(
  thought: "Step 1: Question Inventory - Count and categorize questions from all MPA agents by PRD section impact",
  thoughtNumber: 1,
  totalThoughts: 8,
  nextThoughtNeeded: true
)

mcp__sequential-thinking__sequentialthinking(
  thought: "Step 2: Semantic Deduplication - Identify questions asking the same thing differently, select clearest framing",
  thoughtNumber: 2,
  totalThoughts: 8,
  nextThoughtNeeded: true
)

// ... continue through 8 steps as defined in synthesis agent ...

mcp__sequential-thinking__sequentialthinking(
  thought: "Step 8: Final Formatting - Apply QUESTIONS template, add completion tracking, generate summary",
  thoughtNumber: 8,
  totalThoughts: 8,
  nextThoughtNeeded: false
)
```

**Then launch synthesis agent:**

```
Task(subagent_type="requirements-question-synthesis", description="Merge and dedupe questions", prompt="
FEATURE_DIR: requirements
ROUND_NUMBER: {N}
PRD_MODE: {NEW|EXTEND}
ANALYSIS_MODE: {MODE}

INPUT FILES (all already contain ThinkDeep-informed content):
- requirements/analysis/questions-product-strategy.md
- requirements/analysis/questions-user-experience.md
- requirements/analysis/questions-business-ops.md
- requirements/analysis/thinkdeep-insights.md (reference for priority validation)

NOTE: MPA agent questions ALREADY include ThinkDeep insights in their options
and recommendations. Your job is to:
1. Deduplicate questions across agents
2. MERGE options (preserving ThinkDeep alignment indicators)
3. Validate priority levels match ThinkDeep source
4. Ensure no ThinkDeep insight is lost in deduplication

Output: requirements/working/QUESTIONS-{NNN}.md
")
```

### If ANALYSIS_MODE in {advanced, standard}:

Launch synthesis agent WITHOUT Sequential Thinking pre-analysis (agent uses internal reasoning).

### If ANALYSIS_MODE = rapid:

Skip synthesis - use product-strategy agent output directly as QUESTIONS file.

## Step 7.4: Answer & Recommendation Process

> **Reference:** See [Appendix A: Option Generation Reference](appendix-option-generation.md) for detailed algorithms.

**Summary:** MPA agents generate questions with 3+ predefined options. Each option includes:
- Pros/Cons analysis (informed by ThinkDeep risk findings)
- Star rating (1-5 stars based on scoring algorithm)
- ThinkDeep alignment indicators (target symbol for market gap, warning symbol for risk mitigation)

The synthesis agent deduplicates questions across agents and merges options.

---

## Step 7.5: Format Questions File

Each question MUST include:
- Question ID (Q-001, Q-002, etc.)
- Question text with context
- **Priority level** (CRITICAL/HIGH/MEDIUM) - derived from ThinkDeep
- **Multi-perspective analysis** (target symbol for Product, user symbol for UX, briefcase symbol for Business)
- **ThinkDeep insights section** (convergent/divergent findings)
- 3+ predefined options with Pros/Cons, star rating, alignment indicators
- Custom answer option ("Other (custom answer)")
- Notes section for user context

> **See [Appendix A.6](appendix-option-generation.md#a6-example-question-format)** for complete example question format.

---

## Step 7.6: Update State (CHECKPOINT)

```yaml
current_phase: "QUESTION_GENERATION"
phase_status: "completed"
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

---

## Step 7.7: Pre-User Sanity Check (Fail-Fast)

Before presenting questions to user, perform lightweight validation:

### Checks

1. **Question count:** At least 5 questions generated
2. **PRD coverage:** All major sections have at least 1 question
3. **Option quality:** Each question has 3+ distinct options
4. **No duplicates:** Question titles are unique

### If validation fails:

Use `AskUserQuestion`:

```json
{
  "questions": [{
    "question": "Question generation produced potentially low-quality output:\n\n{ISSUES_LIST}\n\nHow to proceed?",
    "header": "Quality",
    "multiSelect": false,
    "options": [
      {"label": "Regenerate questions (Recommended)", "description": "Re-run Phase 7 with stricter criteria"},
      {"label": "Proceed anyway", "description": "Present questions to user despite issues"},
      {"label": "Add manual questions", "description": "Let me add questions before presenting"}
    ]
  }]
}
```

### If validation passes:

Proceed to Phase 8 (User Response).
