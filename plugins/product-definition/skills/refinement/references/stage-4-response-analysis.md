---
stage: stage-4-response-analysis
artifacts_written:
  - requirements/analysis/response-validation-round-{N}.md (conditional)
---

# Stage 4: User Response & Gap Analysis (Coordinator)

> This stage collects user answers from the QUESTIONS file and analyzes gaps.
> On first entry, it presents the questions file and exits for offline response.
> On re-entry (after user fills answers), it parses and analyzes responses.

## Step 4.1: Determine Entry Point

Check state:
- If `waiting_for_user: true` AND `pause_stage: 4` -> Re-entry (Step 4.3)
- Otherwise -> First entry (Step 4.2)

## Step 4.2: Present Questions and Pause (First Entry)

Display:
```
## Questions Ready for Your Response

**Round:** {N}
**Questions:** {COUNT}
**File:** requirements/working/QUESTIONS-{NNN}.md

### Instructions:
1. Open requirements/working/QUESTIONS-{NNN}.md
2. For each question, mark your choice with [x]
3. If selecting "Other (custom answer)", fill in the text field
4. Add any notes in the Notes section
5. Save the file

**When ready to continue:**
/product-definition:requirements

**Git Suggestion (after filling):**
git add requirements/working/QUESTIONS-{NNN}.md
git commit -m "answer(req): round {N} responses completed"
```

Set status and exit:
```yaml
status: needs-user-input
flags:
  pause_type: exit_cli
  block_reason: "Fill QUESTIONS-{NNN}.md and run /product-definition:requirements"
  round_number: {N}
  questions_file: "requirements/working/QUESTIONS-{NNN}.md"
```

## Step 4.3: Answer File Schema Validation (Re-entry)

Read the QUESTIONS file and validate structure:

```bash
test -f "requirements/working/QUESTIONS-{NNN}.md" || echo "ERROR: File not found"
QUESTION_COUNT=$(grep -c "^### Q-[0-9]" "requirements/working/QUESTIONS-{NNN}.md")
SELECTION_COUNT=$(grep -c "\- \[x\]" "requirements/working/QUESTIONS-{NNN}.md")

if [ "$SELECTION_COUNT" -lt "$QUESTION_COUNT" ]; then
  echo "WARNING: $((QUESTION_COUNT - SELECTION_COUNT)) questions have no selection"
fi
```

Validation checks:
1. File exists
2. Frontmatter present with metadata
3. Each Q-XXX has question text and 3+ checkbox options
4. At least one `[x]` selection per question
5. No corrupted checkbox patterns

**On validation failure:** Report issues, set `status: needs-user-input` with `pause_type: interactive` asking user to fix.

## Step 4.4: Parse Responses

Read `requirements/working/QUESTIONS-{NNN}.md`. Extract:
- Selected options per question
- Custom answers (Other selections)
- Additional notes

## Step 4.5: Validate Completeness

```
completion_rate = answered_questions / total_questions
```

**Thresholds:** From config -> `scoring.completion.*`
- If completion_rate < 80%: Warn user, ask to continue or complete missing
- Required: 100% (all questions must be answered)

## Step 4.6: Analyze Responses (Based on Mode)

### If ANALYSIS_MODE = "complete" AND ST_AVAILABLE = true:

Execute Sequential Thinking for structured gap analysis (6 steps):
1. Parse all user responses, extract selected options and custom answers
2. Map each response to PRD sections
3. Identify answered vs still ambiguous
4. Detect contradictions between responses
5. Determine new questions needed
6. Calculate readiness score

### If ANALYSIS_MODE = "complete" AND PAL_AVAILABLE = true:

Execute PAL Consensus to validate response consistency using multi-step workflow:

```
# Step 1: YOUR independent analysis (sets up the debate)
mcp__pal__consensus(
  step: """
I need to validate user responses for internal consistency and identify remaining gaps.

CONTEXT: Round {N} collected {TOTAL} answers.

RESPONSE SUMMARY BY PRD SECTION:
- Product Definition: {N} questions answered, key decisions: {list}
- Target Users: {N} questions answered, key decisions: {list}
[... all sections ...]

POTENTIAL ISSUES:
1. {Potential contradiction between Q-X and Q-Y}
2. {Gap: section Z has no coverage}
3. {Ambiguity: Q-W answer is vague}

QUESTIONS FOR CONSENSUS:
1. Are there contradictions I missed?
2. Are there gaps that make PRD generation impossible?
3. Do responses align with original product vision?
4. What follow-up questions would resolve ambiguities?

DELIVERABLE:
(1) Confirmed gaps, (2) Contradictions, (3) Sections ready for PRD.
""",
  step_number: 1,
  total_steps: 4,           # 3 models + 1 synthesis
  next_step_required: true,
  findings: "Round {N} collected {TOTAL} answers. Summary: {brief section-by-section status}",
  models: [
    {"model": "gemini-3-pro-preview", "stance": "neutral", "stance_prompt": "Objective assessment of consistency and completeness."},
    {"model": "gpt-5.2", "stance": "for", "stance_prompt": "Look for ways the PRD CAN proceed. Advocate for readiness."},
    {"model": "x-ai/grok-4", "stance": "against", "stance_prompt": "Find contradictions, gaps, ambiguities. Be skeptical of completeness."}
  ],
  relevant_files: ["{ABSOLUTE_PATH}/requirements/working/QUESTIONS-{NNN}.md", "{ABSOLUTE_PATH}/requirements/working/draft-copy.md"]
)
# -> Save continuation_id from response

# Step 2: Process first model's response
mcp__pal__consensus(
  step: "Notes on gemini-3-pro-preview (neutral) response",
  step_number: 2,
  total_steps: 4,
  next_step_required: true,
  findings: "Gemini (neutral) finds: [summary of model response]",
  continuation_id: "<from_step_1>"
)

# Step 3: Process second model's response
mcp__pal__consensus(
  step: "Notes on gpt-5.2 (for) response",
  step_number: 3,
  total_steps: 4,
  next_step_required: true,
  findings: "GPT-5.2 (for) argues: [summary of model response]",
  continuation_id: "<from_step_2>"
)

# Step 4: Final synthesis (next_step_required = false)
mcp__pal__consensus(
  step: "Synthesize all model perspectives into final gap assessment",
  step_number: 4,
  total_steps: 4,
  next_step_required: false,
  findings: "Consensus assessment: [summary of convergence/divergence across all 3 models]",
  continuation_id: "<from_step_3>"
)
```

Output: `requirements/analysis/response-validation-round-{N}.md`

### If ANALYSIS_MODE in ["advanced", "standard", "rapid"] OR PAL unavailable:

Skip PAL validation — use direct gap analysis based on PRD section mapping.

## Step 4.7: Determine Next Action

**If significant gaps remain:**
Set `status: needs-user-input` with `pause_type: interactive`:
```yaml
flags:
  block_reason: "Gaps found — ask user how to proceed"
  question_context:
    question: "Gap analysis found {N} areas needing clarification. How to proceed?"
    header: "Gaps"
    options:
      - label: "Generate more questions (Recommended)"
        description: "Another round focusing on gaps"
      - label: "Research before next round"
        description: "Generate research agenda for gap areas"
      - label: "Proceed to PRD anyway"
        description: "Generate PRD with current information (some sections may be incomplete)"
  next_action_map:
    "Generate more questions": "loop_questions"
    "Research before next round": "loop_research"
    "Proceed to PRD anyway": "proceed"
```

**If gaps are minimal:**
Set `flags.next_action: proceed`

## Step 4.8: Update State (CHECKPOINT)

```yaml
current_stage: 4
phases:
  response_analysis:
    status: completed
    round: {N}
    completion_rate: {rate}
    gaps_found: {N}
```

## Summary Contract

```yaml
---
stage: "response-analysis"
stage_number: 4
status: completed | needs-user-input
checkpoint: RESPONSE_ANALYSIS
artifacts_written:
  - requirements/analysis/response-validation-round-{N}.md
summary: "Analyzed round {N} responses. Completion: {rate}%. Gaps: {N}."
flags:
  round_number: {N}
  completion_rate: {rate}
  gaps_found: {N}
  next_action: "loop_questions" | "loop_research" | "proceed"
  pause_type: null | "exit_cli" | "interactive"
  block_reason: null | "{reason}"
---
```
