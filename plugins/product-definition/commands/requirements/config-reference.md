# Configuration & Variables Reference

> **Source:** Centralized reference for `/product-definition:requirements` workflow

## Template Variables

These placeholders are used throughout the workflow and templates:

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
| `{DRAFT_CONTENT}` | Contents of draft file | (file contents) |
| `{FEATURE_DIR}` | Requirements directory | `requirements` |
| `{COUNT}` | Question/item count | `15` |
| `{VERSION}` | PRD version | `1.0.0` |
| `{HOURS}` | Hours elapsed | `2` |
| `{MINUTES}` | Minutes elapsed | `45` |
| `{MODEL_NAME}` | PAL model identifier | `gpt-5.2` |
| `{ERROR_MESSAGE}` | Error details | `Connection timeout` |
| `{PHASE_NUMBER}` | Current phase number | `6` |
| `{PHASE_NAME}` | Current phase name | `DEEP_ANALYSIS` |
| `{REMAINING_COUNT}` | Remaining models after failure | `2` |
| `{TOTAL}` | Total models configured | `3` |

---

## File Naming Conventions

| File Pattern | Purpose | Example |
|--------------|---------|---------|
| `QUESTIONS-{NNN}.md` | Question rounds | `QUESTIONS-001.md` |
| `questions-*.md` | Agent-specific questions | `questions-product-strategy.md` |
| `thinkdeep-insights.md` | Phase 6 synthesis | (fixed name) |
| `research-synthesis.md` | Research findings | (fixed name) |
| `PRD.md` | Final output | (fixed name) |
| `decision-log.md` | Decision traceability | (fixed name) |
| `completion-report.md` | Final summary | (fixed name) |
| `.requirements-state.local.md` | Workflow state | (fixed name) |
| `.requirements-lock` | Session lock | (fixed name) |

---

## PAL Tool Best Practices

> **CRITICAL:** ThinkDeep and Consensus have DIFFERENT parameter schemas. Do not mix them.

### Tool Comparison

| Aspect | ThinkDeep | Consensus |
|--------|-----------|-----------|
| **Purpose** | Extend YOUR analysis with deeper reasoning | Get multi-model perspectives on a decision |
| **Main param** | `step` | `prompt` |
| **Files param** | `relevant_files` | `files` |
| **Multi-step?** | Yes (`step_number`, `total_steps`) | NO - single call, auto-synthesizes |
| **Context param** | `findings`, `problem_context` | Include context IN `prompt` |
| **Model selection** | Single `model` param | `models` array with stances |

### ThinkDeep Framing (for Phase 6)

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

### Consensus Framing (for Phase 9, 10)

```
mcp__pal__consensus(
  prompt: """
[CONTEXT - what you're evaluating]

MY CURRENT ANALYSIS:
[Your findings and assessment]

QUESTIONS FOR CONSENSUS:
1. [Question 1]
2. [Question 2]

DELIVERABLE:
[What you want synthesized]
""",
  models: [
    {"model": "...", "stance": "neutral", "stance_prompt": "..."},
    {"model": "...", "stance": "for", "stance_prompt": "..."},
    {"model": "...", "stance": "against", "stance_prompt": "..."}
  ],
  files: ["/absolute/path/file.md"],
  focus_areas: ["area1", "area2"],
  thinking_mode: "medium"
)
```

### Common Mistakes

| Mistake | Impact | Fix |
|---------|--------|-----|
| Using `step` for Consensus | Wrong parameter, may fail | Use `prompt` |
| Using `step_number/total_steps` for Consensus | Consensus is single-call | Remove these params |
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
- `complete` mode: 3 perspectives x 3 models = 9 calls
- `advanced` mode: 2 perspectives x 3 models = 6 calls
- `standard/rapid` mode: 0 calls (skip Phase 6)

---

## PAL Consensus Configuration

### Parameter Reference

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `prompt` | string | Yes | Detailed description of proposal/decision to analyze |
| `models` | array | Yes | List of model configs with stance and stance_prompt |
| `files` | array | No | Context files (ABSOLUTE paths) |
| `images` | array | No | Visual references (ABSOLUTE paths) |
| `focus_areas` | array | No | Specific aspects to emphasize |
| `thinking_mode` | string | No | Analysis depth: minimal/low/medium/high/max (default: medium) |
| `temperature` | number | No | Control consistency (default: 0.2) |
| `continuation_id` | string | No | Continue previous consensus discussions |

### Common Mistakes

| Wrong | Correct | Notes |
|-------|---------|-------|
| `step` | `prompt` | Consensus uses `prompt`, not `step` |
| `step_number`, `total_steps` | REMOVE | Consensus is SINGLE-CALL (auto-synthesizes) |
| `next_step_required` | REMOVE | Not a multi-step tool |
| `findings` | Include in `prompt` | Provide context INSIDE the prompt text |
| `relevant_files` | `files` | Different parameter name than ThinkDeep |

### Usage by Phase

| Phase | Purpose | Models | Focus Areas | Thinking Mode |
|-------|---------|--------|-------------|---------------|
| 9 | Response validation | gemini-3-pro-preview, gpt-5.2, x-ai/grok-4 | consistency, completeness, contradiction_detection | medium |
| 10 | PRD readiness | gemini-3-pro-preview, gpt-5.2, x-ai/grok-4 | product_definition, scope_clarity, developer_handoff_readiness | high |

**Minimum Models Required:** 2 (consensus cannot proceed with < 2)

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

| Agent | Phase | Purpose |
|-------|-------|---------|
| `requirements-product-strategy` | 7 | Product strategy questions |
| `requirements-user-experience` | 7 | UX and persona questions |
| `requirements-business-ops` | 7 | Business viability questions |
| `requirements-question-synthesis` | 7 | Merge and format questions |
| `requirements-prd-generator` | 11 | Generate/extend PRD |
| `research-discovery-business` | 4 | Strategic research questions |
| `research-discovery-ux` | 4 | UX research questions |
| `research-discovery-technical` | 4 | Technical/viability research |
| `research-question-synthesis` | 4 | Synthesize research agenda |

---

## Scoring Thresholds

**Source:** `$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml` -> `scoring.*`

### PRD Readiness (Phase 10)

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

### Completion Rate (Phase 9)

| Rate | Action |
|------|--------|
| 100% | Required - all questions answered |
| 80% | Warning threshold |

---

## Analysis Mode Summary

| Mode | MPA Agents | ThinkDeep Calls | Sequential | Consensus | Est. Cost |
|------|------------|-----------------|------------|-----------|-----------|
| complete | 3 | 9 (3x3) | Yes | Yes | $0.80-1.50 |
| advanced | 3 | 6 (2x3) | No | No | $0.50-0.80 |
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
