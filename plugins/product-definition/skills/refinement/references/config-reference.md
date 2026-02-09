# Configuration & Variables Reference

> Centralized reference for the Requirements Refinement workflow.

## Template Variables

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `{TIMESTAMP}` | ISO 8601 datetime | `2026-01-27T10:30:00Z` |
| `{ISO_DATE}` | Date portion | `2026-01-27` |
| `{ISO_TIMESTAMP}` | Full ISO timestamp | `2026-01-27T10:30:00Z` |
| `{NNN}` | Zero-padded round number | `001`, `002` |
| `{N}` | Non-padded number | `1`, `2` |
| `{ANALYSIS_MODE}` | Selected mode | `complete`, `advanced`, `standard`, `rapid` |
| `{PRD_MODE}` | PRD creation mode | `NEW`, `EXTEND` |
| `{WORKFLOW_MODE}` | Workflow state | `NEW`, `RESUME` |
| `{DRAFT_FILE}` | User's draft filename | `my-product-draft.md` |
| `{PRODUCT_NAME}` | Product name from draft heading | `My Product` |
| `{DRAFT_CONTENT}` | Contents of draft file | (file contents) |
| `{FEATURE_DIR}` | Requirements directory | `requirements` |
| `{COUNT}` | Question/item count | `15` |
| `{VERSION}` | PRD version | `1.0.0` |
| `{HOURS}` | Hours elapsed | `2` |
| `{MINUTES}` | Minutes elapsed | `45` |
| `{MODEL_NAME}` | PAL model identifier | `gpt-5.2` |
| `{ERROR_MESSAGE}` | Error details | `Connection timeout` |
| `{STAGE_NUMBER}` | Current stage number | `3` |
| `{STAGE_NAME}` | Current stage name | `ANALYSIS_QUESTIONS` |
| `{REMAINING_COUNT}` | Remaining models after failure | `2` |
| `{TOTAL}` | Total models configured | `3` |

---

## File Naming Conventions

| File Pattern | Purpose | Example |
|--------------|---------|---------|
| `QUESTIONS-{NNN}.md` | Question rounds | `QUESTIONS-001.md` |
| `questions-*.md` | Agent-specific questions | `questions-product-strategy.md` |
| `thinkdeep-insights.md` | Stage 3 synthesis | (fixed name) |
| `research-synthesis.md` | Research findings | (fixed name) |
| `PRD.md` | Final output | (fixed name) |
| `decision-log.md` | Decision traceability | (fixed name) |
| `completion-report.md` | Final summary | (fixed name) |
| `.requirements-state.local.md` | Workflow state | (fixed name) |
| `.requirements-lock` | Session lock | (fixed name) |
| `stage-{N}-summary.md` | Stage summaries | `stage-3-summary.md` |

---

## PAL Tool Best Practices

> **IMPORTANT:** ThinkDeep and Consensus share the same multi-step workflow parameters (`step`, `step_number`, `total_steps`, `next_step_required`, `findings`, `relevant_files`, `continuation_id`). The key difference is model selection.

### Tool Comparison

| Aspect | ThinkDeep | Consensus |
|--------|-----------|-----------|
| **Purpose** | Extend YOUR analysis with deeper reasoning | Get multi-model perspectives on a decision |
| **Main param** | `step` (your analysis/questions) | `step` (your analysis/questions) |
| **Files param** | `relevant_files` | `relevant_files` |
| **Multi-step?** | Yes (`step_number`, `total_steps`) | Yes (`step_number`, `total_steps`) — steps = N models + synthesis |
| **Context params** | `findings`, `problem_context`, `hypothesis` | `findings` |
| **Model selection** | Single `model` param | `models` array with stances |
| **Unique params** | `confidence`, `use_assistant_model`, `focus_areas`, `problem_context` | `models[].stance`, `models[].stance_prompt` |

### ThinkDeep Framing (Stage 3)

```
mcp__pal__thinkdeep(
  step: """
I'm analyzing [TOPIC] for {PRODUCT_NAME}.

MY CURRENT ANALYSIS:
[Your actual findings - 5-10 bullet points]

MY INITIAL THINKING:
- [Your hypothesis 1]
- [Your hypothesis 2]

EXTEND MY ANALYSIS:
1. [Specific question for model]
2. [Another question]
""",
  findings: "[Summary of discoveries - NOT empty]",
  problem_context: """
IMPORTANT: This is a BUSINESS/PRD ANALYSIS, not code analysis.
No source code exists yet - this is the requirements gathering phase.
""",
  relevant_files: ["/absolute/path/file.md"],
  model: "gemini-3-pro-preview",
  thinking_mode: "high"
)
```

### Consensus Framing (Stages 4, 5)

Consensus uses the **same multi-step workflow** as ThinkDeep. The `total_steps` = number of models + 1 (synthesis step). Each step uses `continuation_id` from the previous step.

```
# Step 1: YOUR independent analysis (sets up the debate)
mcp__pal__consensus(
  step: """
[CONTEXT - what you're evaluating]

MY CURRENT ANALYSIS:
[Your findings and assessment]

QUESTIONS FOR CONSENSUS:
1. [Question 1]
2. [Question 2]

DELIVERABLE:
[What you want synthesized]
""",
  step_number: 1,
  total_steps: 4,           # 3 models + 1 synthesis
  next_step_required: true,
  findings: "[Summary of your analysis — NOT empty]",
  models: [
    {"model": "gemini-3-pro-preview", "stance": "neutral", "stance_prompt": "..."},
    {"model": "gpt-5.2", "stance": "for", "stance_prompt": "..."},
    {"model": "x-ai/grok-4", "stance": "against", "stance_prompt": "..."}
  ],
  relevant_files: ["/absolute/path/file.md"]
)

# Steps 2-3: Process each model response (use continuation_id from step 1)
mcp__pal__consensus(
  step: "Notes on model response (private — not shared with other models)",
  step_number: 2,
  total_steps: 4,
  next_step_required: true,
  findings: "Model X argues...",
  continuation_id: "<from_step_1>"
)

# Step 4: Final synthesis
mcp__pal__consensus(
  step: "Final synthesis of all perspectives",
  step_number: 4,
  total_steps: 4,
  next_step_required: false,
  findings: "Consensus: [summary of outcome]",
  continuation_id: "<from_previous>"
)
```

### Common Mistakes

| Mistake | Impact | Fix |
|---------|--------|-----|
| Using `prompt` for Consensus | Wrong parameter name | Use `step` (same as ThinkDeep) |
| Using `files` for Consensus | Wrong parameter name | Use `relevant_files` (same as ThinkDeep) |
| Treating Consensus as single-call | Skips model processing steps | Use multi-step: step 1 = your analysis, steps 2-N = model responses, final = synthesis |
| Missing `continuation_id` on steps 2+ | Loses debate context between steps | Pass continuation_id from each previous step |
| Setting `next_step_required: false` too early | Skips remaining model perspectives | Only set false on the final synthesis step |
| Empty `findings` in ThinkDeep | Model has no context | Populate with discoveries |
| No PRD disclaimer | Model requests source files | Add "This is BUSINESS/PRD ANALYSIS" |
| Relative file paths | Tool error | Use absolute paths |

---

## PAL ThinkDeep Configuration

| Perspective | Models | Focus Areas | Mode |
|-------------|--------|-------------|------|
| COMPETITIVE | gpt-5.2, gemini-3-pro-preview, x-ai/grok-4 | competitive_analysis, market_positioning | complete, advanced |
| RISK | gpt-5.2, gemini-3-pro-preview, x-ai/grok-4 | risk_assessment, assumption_validation | complete, advanced |
| CONTRARIAN | gpt-5.2, gemini-3-pro-preview, x-ai/grok-4 | assumption_challenge, blind_spots | complete only |

**Call Matrix:**
- `complete` mode: 3 perspectives × 3 models × 3 steps = 27 calls
- `advanced` mode: 2 perspectives × 3 models × 3 steps = 18 calls
- `standard/rapid` mode: 0 calls (skip ThinkDeep in Stage 3)

---

## PAL Consensus Configuration

### Parameter Reference

Consensus shares multi-step workflow parameters with ThinkDeep (see `shared-parameters.md`):

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `step` | string | Yes | Current step description — your analysis, model notes, or synthesis |
| `step_number` | integer | Yes | Current step (1 = your analysis, 2+ = model responses, last = synthesis) |
| `total_steps` | integer | Yes | Number of models + 1 (for synthesis step) |
| `next_step_required` | boolean | Yes | True until final synthesis step |
| `findings` | string | Yes | Step 1: your analysis; Steps 2+: model response summary |
| `models` | array | Yes* | List of model configs with stance and stance_prompt (*optional in PAL API, but required for meaningful consensus in this workflow) |
| `continuation_id` | string | No | Thread ID from previous step (required on steps 2+) |
| `relevant_files` | array | No | Context files (ABSOLUTE paths) |
| `images` | array | No | Visual references (ABSOLUTE paths) |

### Common Mistakes

| Wrong | Correct | Notes |
|-------|---------|-------|
| `prompt` | `step` | Consensus uses `step`, same as ThinkDeep |
| `files` | `relevant_files` | Consensus uses `relevant_files`, same as ThinkDeep |
| Omitting `step_number`/`total_steps` | Include them | Consensus IS a multi-step tool |
| Missing `continuation_id` on step 2+ | Pass from previous step | Required to maintain debate context |
| Wrong stance config (all same stance) | Use diverse stances | Use for/against/neutral for genuine debate |
| `total_steps` = number of models | models + 1 | Must include the final synthesis step |

### Usage by Stage

| Stage | Purpose | Models | Stances |
|-------|---------|--------|---------|
| 4 | Response validation | gemini-3-pro-preview, gpt-5.2, x-ai/grok-4 | neutral, for, against |
| 5 | PRD readiness | gemini-3-pro-preview, gpt-5.2, x-ai/grok-4 | neutral, for, against |

**Minimum Models Required:** 2 (consensus requires at least 2 model perspectives before synthesis is meaningful)

### Stance Configuration Pattern

```json
[
  {"model": "gemini-3-pro-preview", "stance": "neutral", "stance_prompt": "Provide objective assessment without favoring either side. Focus on factual gaps and measurable criteria."},
  {"model": "gpt-5.2", "stance": "for", "stance_prompt": "Look for reasons the proposal IS ready/valid. Advocate for proceeding."},
  {"model": "x-ai/grok-4", "stance": "against", "stance_prompt": "Challenge completeness. Find what's MISSING. Be skeptical."}
]
```

---

## Agent References

| Agent | Stage | Purpose |
|-------|-------|---------|
| `requirements-product-strategy` | 3 | Product strategy questions |
| `requirements-user-experience` | 3 | UX and persona questions |
| `requirements-business-ops` | 3 | Business viability questions |
| `requirements-question-synthesis` | 3 | Merge and format questions |
| `requirements-prd-generator` | 5 | Generate/extend PRD |
| `research-discovery-business` | 2 | Strategic research questions |
| `research-discovery-ux` | 2 | UX research questions |
| `research-discovery-technical` | 2 | Technical/viability research |
| `research-question-synthesis` | 2 | Synthesize research agenda |

---

## Scoring Thresholds

**Source:** `$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml` -> `scoring.*`

### PRD Readiness (Stage 5)

| Score | Decision | Color |
|-------|----------|-------|
| >= 16/20 | READY | GREEN |
| 12-15/20 | CONDITIONAL | YELLOW |
| < 12/20 | NOT READY | RED |

### Star Rating for Options

| Rating | Score Range | Label |
|--------|-------------|-------|
| 5 stars | 90-100 | Recommended |
| 4 stars | 75-89 | Strong alternative |
| 3 stars | 60-74 | Viable with trade-offs |
| 2 stars | 40-59 | Risky or niche |
| 1 star | 0-39 | Not recommended |

### Completion Rate (Stage 4)

| Rate | Action |
|------|--------|
| 100% | Required — all questions answered |
| 80% | Warning threshold |

---

## Analysis Mode Summary

| Mode | MPA Agents | ThinkDeep Calls | Sequential | Consensus | Est. Cost |
|------|------------|-----------------|------------|-----------|-----------|
| complete | 3 | 27 (3×3×3) | Yes | Yes | $2.00-4.00 |
| advanced | 3 | 18 (2×3×3) | No | No | $1.20-2.50 |
| standard | 3 | 0 | No | No | $0.15-0.25 |
| rapid | 1 | 0 | No | No | $0.05-0.10 |

---

## Graceful Degradation Matrix

| MCP Status | Available Modes | Degraded Features |
|------------|-----------------|-------------------|
| All available | Complete, Advanced, Standard, Rapid | None |
| PAL unavailable | Standard, Rapid | No ThinkDeep, no Consensus |
| ST unavailable | Complete*, Advanced, Standard, Rapid | Internal reasoning replaces ST |
| Both unavailable | Standard, Rapid | Maximum degradation |

*Complete mode with ST unavailable uses internal reasoning but maintains MPA + PAL
