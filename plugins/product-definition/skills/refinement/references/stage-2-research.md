---
stage: stage-2-research
artifacts_written:
  - requirements/research/RESEARCH-AGENDA.md (conditional)
  - requirements/research/research-synthesis.md (conditional)
---

# Stage 2: Research Discovery (Coordinator)

> This stage is OPTIONAL. It generates research questions for offline user investigation.

## Step 2.1: Research Skip Check

**If resuming and user_decisions.research_decision_round_N exists:**
- `conduct_research` -> Check for reports (Step 2.2)
- `skip_with_context` -> Set status: completed, proceed
- `skip_entirely` -> Set status: completed, proceed

## Step 2.2: Check for Existing Research Reports

```bash
find requirements/research/reports -name "*.md" 2>/dev/null | wc -l
```

**If reports found > 0:** Jump to Step 2.6 (Research Synthesis)

## Step 2.3: Research Decision

Set `status: needs-user-input` in summary with:
```yaml
flags:
  pause_type: interactive
  block_reason: "Ask user whether to generate research agenda"
  question_context:
    question: "Would you like to generate a research agenda before question generation? This helps ground the PRD in market reality."
    header: "Research"
    options:
      - label: "Yes, generate research agenda (Recommended)"
        description: "Generate targeted research questions I can investigate offline"
      - label: "Skip - I have domain knowledge"
        description: "I'll provide context directly, no external research needed"
      - label: "Skip entirely"
        description: "Proceed directly to question generation"
```

**Handle Response:**
- "Yes" -> Continue to Step 2.4
- "Skip - I have domain knowledge" -> Ask for context, store in state, set status: completed
- "Skip entirely" -> Update state, set status: completed

## Step 2.4: Generate Research Agenda

**If ANALYSIS_MODE in [complete, advanced, standard]:**
Launch 3 agents in parallel using Task tool:
1. `research-discovery-business` -> questions-strategic.md
2. `research-discovery-ux` -> questions-ux.md
3. `research-discovery-technical` (with focus_override: business_viability) -> questions-viability.md

Then run `research-question-synthesis` -> RESEARCH-AGENDA.md

**If ANALYSIS_MODE = rapid:**
Single agent generates RESEARCH-AGENDA.md

## Step 2.5: Present Agenda and Pause

Display:
```
## Research Agenda Generated

**Total Questions:** {N}
**CRITICAL Priority:** {N}
**HIGH Priority:** {N}

Research agenda saved to: requirements/research/RESEARCH-AGENDA.md
```

Set `status: needs-user-input` in summary:
```yaml
flags:
  pause_type: interactive
  block_reason: "Ask user to conduct research or proceed"
  question_context:
    question: "Research agenda is ready. How would you like to proceed?"
    header: "Research"
    options:
      - label: "I'll conduct research (Recommended)"
        description: "Save reports to requirements/research/reports/. Run /product-definition:requirements to resume."
      - label: "Proceed without research"
        description: "Continue to question generation using internal knowledge"
```

**If "I'll conduct research":**
Set `status: needs-user-input` with `pause_type: exit_cli`:
```yaml
flags:
  pause_type: exit_cli
  block_reason: "Conduct research and save to requirements/research/reports/. Then run /product-definition:requirements"
```

**Git Suggestion:**
```
git add requirements/research/
git commit -m "research(req): generate research agenda"
```

## Step 2.6: Research Synthesis

Runs when research reports exist (on re-entry or if user proceeds without pause).

**If ST_AVAILABLE = true:**
Use Sequential Thinking for systematic 8-step analysis:
1. Extract Key Findings from each report
2. Cross-Reference findings across reports
3. Conflict Detection
4. Evidence Quality assessment
5. Gap Analysis (questions not addressed)
6. PRD Implications
7. Risk Identification
8. Synthesis

**If ST_AVAILABLE = false:**
Use internal reasoning for the same 8-step analysis.

Output: `requirements/research/research-synthesis.md`
Use template from `$CLAUDE_PLUGIN_ROOT/templates/research-synthesis-template.md`

## Step 2.7: Update State (CHECKPOINT)

```yaml
phases:
  research:
    status: completed
    reports_analyzed: {N}
    consensus_findings: {N}
    research_gaps: {N}
    st_used: {true|false}
```

## Summary Contract

```yaml
---
stage: "research"
stage_number: 2
status: completed
checkpoint: RESEARCH
artifacts_written:
  - requirements/research/RESEARCH-AGENDA.md (conditional - only if user chose to research)
  - requirements/research/research-synthesis.md (conditional - only if research reports exist)
summary: "Generated research agenda with {N} questions. Synthesized {M} reports."
flags:
  reports_analyzed: {N}
  research_gaps: {N}
  round_number: {N}
---
```
