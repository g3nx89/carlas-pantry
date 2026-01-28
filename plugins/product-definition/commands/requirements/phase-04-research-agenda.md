# Phase 4: Research Agenda (Optional)

> **Source:** Extracted from `/product-definition:requirements` main orchestration

**Checkpoint:** `RESEARCH_DISCOVERY`

**Goal:** Generate targeted research questions for user investigation to ground PRD in market reality.

## Step 4.1: Check Research Skip

**If resuming and `user_decisions.research_decision_round_N` exists:**
- `conduct_research` -> Jump to check for reports (Step 4.2)
- `skip_with_context` -> Skip to Phase 6 (Deep Analysis)
- `skip_entirely` -> Skip to Phase 6 (Deep Analysis)

## Step 4.2: Check for Existing Research Reports

```bash
find requirements/research/reports -name "*.md" 2>/dev/null | wc -l
```

**If reports found > 0:**
Jump to Phase 5: Research Synthesis

## Step 4.3: Ask User About Research

Use `AskUserQuestion`:

```json
{
  "questions": [{
    "question": "Would you like to generate a research agenda before question generation? This helps ground the PRD in market reality.",
    "header": "Research",
    "multiSelect": false,
    "options": [
      {"label": "Yes, generate research agenda (Recommended)", "description": "Generate targeted research questions I can investigate offline"},
      {"label": "Skip - I have domain knowledge", "description": "I'll provide context directly, no external research needed"},
      {"label": "Skip entirely", "description": "Proceed directly to question generation"}
    ]
  }]
}
```

**Handle Response:**
- "Yes" -> Continue to Step 4.4
- "Skip - I have domain knowledge" -> Ask for context, store in state, proceed to Phase 6 (Deep Analysis)
- "Skip entirely" -> Update state, proceed to Phase 6 (Deep Analysis)

## Step 4.4: Generate Research Agenda

**Available research agents:**
- `research-discovery-business`
- `research-discovery-ux`
- `research-discovery-technical`
- `research-question-synthesis`

If `ANALYSIS_MODE` in ["complete", "advanced", "standard"]:
Launch 3 agents in parallel using Task tool:

1. `research-discovery-business` -> questions-strategic.md
2. `research-discovery-ux` -> questions-ux.md
3. `research-discovery-technical` (with `focus_override: business_viability`) -> questions-viability.md

Then run `research-question-synthesis` -> RESEARCH-AGENDA.md

If `ANALYSIS_MODE = "rapid"`:
Single agent generates RESEARCH-AGENDA.md

## Step 4.5: Present Research Agenda and Pause

```markdown
## Research Agenda Generated

**Total Questions:** {N}
**CRITICAL Priority:** {N}
**HIGH Priority:** {N}

Research agenda saved to: `requirements/research/RESEARCH-AGENDA.md`
```

Use `AskUserQuestion`:

```json
{
  "questions": [{
    "question": "Research agenda is ready. How would you like to proceed?",
    "header": "Research",
    "multiSelect": false,
    "options": [
      {"label": "I'll conduct research (Recommended)", "description": "Save reports to requirements/research/reports/. Run /product-definition:requirements to resume."},
      {"label": "Proceed without research", "description": "Continue to question generation using AI's internal knowledge"}
    ]
  }]
}
```

**If "I'll conduct research":**
Update state:
```yaml
current_phase: "RESEARCH_DISCOVERY"
phase_status: "waiting_for_user"
waiting_for_user: true
next_step: "Conduct research and save to requirements/research/reports/. Then run /product-definition:requirements"
```

**Git Suggestion:**
```
git add requirements/research/
git commit -m "research(req): generate research agenda"
```

EXIT (user pause for research)
