---
stage: stage-4-response-analysis
artifacts_written:
  - requirements/analysis/response-validation-round-{N}.md (conditional)
---

# Stage 4: User Response & Gap Analysis (Coordinator)

> This stage collects user answers from the QUESTIONS file and analyzes gaps.
> On first entry, it presents the questions file and exits for offline response.
> On re-entry (after user fills answers), it parses and analyzes responses.

## CRITICAL RULES (must follow — failure-prevention)

1. **ENTRY_TYPE determines behavior**: If `ENTRY_TYPE` context variable is `"re_entry_after_user_input"`, skip directly to Step 4.3. If `"first_entry"`, start at Step 4.2. NEVER confuse entry points.
2. **100% completion REQUIRED**: All questions MUST be answered. Do NOT proceed to gap analysis with unanswered questions.
3. **Consensus requires minimum 2 models**: If < 2 PAL models available, FAIL and notify user — do NOT attempt Consensus.
4. **next_action MUST be set**: Summary MUST include `flags.next_action` with one of: `loop_questions`, `loop_research`, `proceed`.

## Step 4.1: Determine Entry Point

Check the `ENTRY_TYPE` context variable provided by the orchestrator:
- If `ENTRY_TYPE: "re_entry_after_user_input"` -> Re-entry (Step 4.3)
- If `ENTRY_TYPE: "first_entry"` -> First entry (Step 4.2)
- **Fallback** (if ENTRY_TYPE not provided): Check state — if `waiting_for_user: true` AND `pause_stage: 4` -> Re-entry, otherwise -> First entry

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
QUESTION_COUNT=$(grep -c "^## Q-[0-9]" "requirements/working/QUESTIONS-{NNN}.md")
SELECTION_COUNT=$(grep -c "\- \[x\]" "requirements/working/QUESTIONS-{NNN}.md")

if [ "$SELECTION_COUNT" -lt "$QUESTION_COUNT" ]; then
  echo "WARNING: $((QUESTION_COUNT - SELECTION_COUNT)) questions have no selection"
fi
```

**MANDATORY validation checks (ALL must pass):**
1. File MUST exist
2. Frontmatter MUST be present with metadata
3. Each Q-XXX MUST have question text and 3+ checkbox options
4. Each question MUST have at least one `[x]` selection
5. No corrupted checkbox patterns

**On validation failure:** Report issues, set `status: needs-user-input` with `pause_type: interactive` asking user to fix. Do NOT proceed with partial data.

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

Execute PAL Consensus to validate response consistency using multi-step workflow.

#### Consensus Execution

**Follow shared pattern:** `@$CLAUDE_PLUGIN_ROOT/skills/refinement/references/consensus-call-pattern.md`

**Stage 4 parameters for the shared pattern:**

| Parameter | Value |
|-----------|-------|
| `{NEUTRAL_STANCE_PROMPT}` | "Objective assessment of consistency and completeness." |
| `{FOR_STANCE_PROMPT}` | "Look for ways the PRD CAN proceed. Advocate for readiness." |
| `{AGAINST_STANCE_PROMPT}` | "Find contradictions, gaps, ambiguities. Be skeptical of completeness." |
| `{RELEVANT_FILES}` | `"{ABSOLUTE_PATH}/requirements/working/QUESTIONS-{NNN}.md", "{ABSOLUTE_PATH}/requirements/working/draft-copy.md"` |

**Step 1 content (YOUR independent analysis):**

```
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
```

**Step 1 findings:** `"Round {N} collected {TOTAL} answers. Summary: {brief section-by-section status}"`

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
  gap_descriptions:
    - "{PRD section}: {what is missing or ambiguous}"
  sections_ready:
    - "{PRD section confirmed complete}"
  next_action: "loop_questions" | "loop_research" | "proceed"
  pause_type: null | "exit_cli" | "interactive"
  block_reason: null | "{reason}"
---
```

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. If re-entry: all questions have `[x]` selections (100% completion)
2. `flags.next_action` is set to one of the three valid values — NEVER null on completed status
3. If PAL Consensus ran: `requirements/analysis/response-validation-round-{N}.md` exists
4. State file was updated with `current_stage: 4`
5. Summary YAML frontmatter has no placeholder values

## CRITICAL RULES REMINDER

- ENTRY_TYPE determines first-entry vs re-entry — never confuse the two
- 100% completion required — do not proceed with unanswered questions
- Consensus requires minimum 2 models
- next_action MUST always be set in summary flags
