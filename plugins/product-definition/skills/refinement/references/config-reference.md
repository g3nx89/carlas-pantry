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
| `{REFLECTION_CONTEXT}` | Reflexion from previous RED round | (generated text or empty) |
| `{SECTION_DECOMPOSITION}` | Least-to-Most section breakdown | (decomposition from Step 3B.2) |

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
| `reflection-round-{N}.md` | Persisted REFLECTION_CONTEXT for crash recovery | `reflection-round-2.md` |

---

## PAL Tool Quick Reference

> **IMPORTANT:** Authoritative PAL call syntax lives in each stage file (stage-3 for ThinkDeep, stages 4-5 for Consensus). This section is a parameter reference only — do NOT duplicate call patterns here.

### Shared Parameters (ThinkDeep & Consensus)

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `step` | string | Yes | Your current analysis — NOT just a title. Include findings and specific questions |
| `step_number` | integer | Yes | Current step in multi-step chain |
| `total_steps` | integer | Yes | ThinkDeep: 3 per chain. Consensus: number of models + 1 (synthesis) |
| `next_step_required` | boolean | Yes | True until final step |
| `findings` | string | Yes | Summary of discoveries — MUST NOT be empty |
| `relevant_files` | array | No | Context files — MUST use ABSOLUTE paths |
| `continuation_id` | string | No | Thread ID from previous step — required on steps 2+ |

### ThinkDeep-Only Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `model` | string | Single model ID (e.g., `gpt-5.2`) |
| `thinking_mode` | string | Set to `"high"` for deep analysis |
| `confidence` | string | `"exploring"` → `"low"` → `"high"` across steps |
| `focus_areas` | array | e.g., `["competitive_analysis", "market_positioning"]` |
| `problem_context` | string | MUST include "This is BUSINESS/PRD ANALYSIS, not code analysis" |
| `hypothesis` | string | Your current hypothesis to test |

### Consensus-Only Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `models` | array | List of `{model, stance, stance_prompt}` objects |
| `models[].stance` | string | `"neutral"`, `"for"`, or `"against"` |
| `models[].stance_prompt` | string | Instructions for model's perspective |

### Common Mistakes (CRITICAL — review before every PAL call)

| Mistake | Impact | Fix |
|---------|--------|-----|
| Using `prompt` instead of `step` | Wrong parameter name | Both tools use `step` |
| Using `files` instead of `relevant_files` | Wrong parameter name | Both tools use `relevant_files` |
| Treating Consensus as single-call | Skips model processing | Multi-step: step 1 = your analysis, steps 2-N = models, final = synthesis |
| Missing `continuation_id` on steps 2+ | Loses context between steps | Pass continuation_id from each previous step |
| Setting `next_step_required: false` too early | Skips remaining models | Only set false on final synthesis step |
| Empty `findings` | Model has no context | Populate with discoveries — NEVER empty |
| No PRD disclaimer in `problem_context` | Model requests source files | Add "This is BUSINESS/PRD ANALYSIS" |
| Relative file paths | Tool error | MUST use absolute paths |

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

Consensus shares multi-step workflow parameters with ThinkDeep (see "PAL Tool Quick Reference" section above):

**Consensus-specific rules:**
- `total_steps` = number of models + 1 (for synthesis step)
- Step 1 = YOUR independent analysis; Steps 2-N = model responses; Final step = synthesis
- Use diverse stances (`for`/`against`/`neutral`) for genuine debate
- `models` array is required for meaningful consensus in this workflow

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
