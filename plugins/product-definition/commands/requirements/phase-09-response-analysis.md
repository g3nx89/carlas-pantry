# Phase 9: Response Analysis

> **Source:** Extracted from `/product-definition:requirements` main orchestration

**Checkpoint:** `RESPONSE_ANALYSIS`

**Goal:** Parse user responses, validate completeness, detect contradictions, and identify remaining gaps.

## Step 9.0: Answer File Schema Validation

Before parsing responses, validate the QUESTIONS file structure:

### Validation Checks

1. **File exists:** `requirements/working/QUESTIONS-{NNN}.md`
2. **Frontmatter present:** Contains metadata header with `Generated`, `Round`, `Total Questions`
3. **Question structure:** Each Q-XXX has:
   - `**Question:**` line
   - At least 3 checkbox options `- [ ]` or `- [x]`
   - `**PRD Section:**` mapping
4. **At least one selection:** Each question has exactly one `[x]` or an "Other:" with text
5. **No corrupted checkboxes:** Pattern `- \[(x| )\]` validates

### Validation Script

```bash
# Check file exists
test -f "requirements/working/QUESTIONS-{NNN}.md" || echo "ERROR: File not found"

# Count questions
QUESTION_COUNT=$(grep -c "^### Q-[0-9]" "requirements/working/QUESTIONS-{NNN}.md")

# Count selections
SELECTION_COUNT=$(grep -c "\- \[x\]" "requirements/working/QUESTIONS-{NNN}.md")

# Validate
if [ "$SELECTION_COUNT" -lt "$QUESTION_COUNT" ]; then
  echo "WARNING: $((QUESTION_COUNT - SELECTION_COUNT)) questions have no selection"
fi
```

### On validation failure:

Display error with specific issues and ask user to fix before continuing.

---

## Step 9.1: Parse Completed Questions File

Read `requirements/working/QUESTIONS-{NNN}.md`
Extract:
- Selected options per question
- Custom answers
- Additional notes

## Step 9.2: Validate Completeness

Calculate completion rate:
```
completion_rate = answered_questions / total_questions
```

**Threshold:** See `$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml` -> `scoring.completion.*`

**If completion_rate < 80%:**
Warn user, ask to continue or complete missing

## Step 9.3: Analyze Responses (Based on Mode)

### If ANALYSIS_MODE = "complete" AND ST_AVAILABLE = true:

Execute Sequential Thinking for structured gap analysis:

```
mcp__sequential-thinking__sequentialthinking(
  thought: "Step 1: Parse all user responses from QUESTIONS-{NNN}.md, extract selected options and custom answers",
  thoughtNumber: 1,
  totalThoughts: 6,
  nextThoughtNeeded: true
)

mcp__sequential-thinking__sequentialthinking(
  thought: "Step 2: Map each response to PRD sections - which sections are now answerable?",
  thoughtNumber: 2,
  totalThoughts: 6,
  nextThoughtNeeded: true
)

mcp__sequential-thinking__sequentialthinking(
  thought: "Step 3: Identify answered vs still ambiguous - which questions need follow-up?",
  thoughtNumber: 3,
  totalThoughts: 6,
  nextThoughtNeeded: true
)

mcp__sequential-thinking__sequentialthinking(
  thought: "Step 4: Detect contradictions - are any responses inconsistent with each other?",
  thoughtNumber: 4,
  totalThoughts: 6,
  nextThoughtNeeded: true
)

mcp__sequential-thinking__sequentialthinking(
  thought: "Step 5: Determine new questions needed - what gaps require additional clarification?",
  thoughtNumber: 5,
  totalThoughts: 6,
  nextThoughtNeeded: true
)

mcp__sequential-thinking__sequentialthinking(
  thought: "Step 6: Calculate readiness score - estimate PRD section coverage percentage",
  thoughtNumber: 6,
  totalThoughts: 6,
  nextThoughtNeeded: false
)
```

### If ANALYSIS_MODE in ["complete", "advanced"] AND PAL_AVAILABLE = true:

Execute PAL Consensus to validate response consistency:

> **IMPORTANT:** See `config-reference.md` → "PAL Consensus Configuration" for parameter reference.
> Consensus is a SINGLE-CALL tool that auto-synthesizes perspectives. Do NOT use multi-step pattern.

```
mcp__pal__consensus(
  prompt: """
I need to validate user responses for internal consistency and identify remaining gaps.

CONTEXT:
Round {N} collected {TOTAL_QUESTIONS} answers from the user.

MY ANALYSIS OF RESPONSES:

RESPONSE SUMMARY BY PRD SECTION:
- Product Definition: {N} questions answered, key decisions: {list}
- Target Users: {N} questions answered, key decisions: {list}
- Problem/Value Prop: {N} questions answered, key decisions: {list}
- Workflows: {N} questions answered, key decisions: {list}
- Features: {N} questions answered, key decisions: {list}
- Business: {N} questions answered, key decisions: {list}

POTENTIAL ISSUES I'VE SPOTTED:
1. {Potential contradiction between Q-X and Q-Y}
2. {Gap: section Z has no coverage}
3. {Ambiguity: Q-W answer is vague}

QUESTIONS FOR CONSENSUS:
1. Are there contradictions I missed between user responses?
2. Are there gaps that make PRD generation impossible?
3. Do responses align with the original product vision from the draft?
4. What follow-up questions would resolve ambiguities?

DELIVERABLE:
Synthesize into: (1) Confirmed gaps requiring more questions, (2) Contradictions requiring resolution, (3) Sections ready for PRD generation.
""",
  models: [
    {"model": "gemini-3-pro-preview", "stance": "neutral", "stance_prompt": "Provide objective assessment. Focus on factual gaps and measurable criteria without favoring either side."},
    {"model": "gpt-5.2", "stance": "for", "stance_prompt": "Assume responses are consistent and sufficient. Look for ways the PRD CAN proceed."},
    {"model": "x-ai/grok-4", "stance": "against", "stance_prompt": "Find contradictions, gaps, and ambiguities. What's MISSING? What would block PRD generation?"}
  ],
  files: [
    "{ABSOLUTE_PATH}/requirements/working/QUESTIONS-{NNN}.md",
    "{ABSOLUTE_PATH}/requirements/working/draft-copy.md"
  ],
  focus_areas: ["consistency", "completeness", "contradiction_detection"],
  thinking_mode: "medium",
  temperature: 0.2
)
```

Output: `requirements/analysis/response-validation-round-{N}.md`

### If ANALYSIS_MODE in ["standard", "rapid"] OR PAL unavailable:

Skip PAL validation - use direct gap analysis based on PRD section mapping.

## Step 9.4: Determine Next Step

**If significant gaps remain:**
Use `AskUserQuestion`:

```json
{
  "questions": [{
    "question": "Gap analysis found {N} areas needing clarification. How to proceed?",
    "header": "Gaps",
    "multiSelect": false,
    "options": [
      {"label": "Generate more questions (Recommended)", "description": "Another round focusing on gaps"},
      {"label": "Research before next round", "description": "Generate research agenda for gap areas"},
      {"label": "Proceed to PRD anyway", "description": "Generate PRD with current information (some sections may be incomplete)"}
    ]
  }]
}
```

**If "Generate more questions":**
Ask for analysis mode for new round
-> GOTO Phase 4 (with new round number)

**If "Research before next round":**
Generate focused RESEARCH-AGENDA for gaps
-> GOTO Phase 4

**If "Proceed to PRD":**
-> GOTO Phase 10

**If gaps are minimal:**
-> GOTO Phase 10
