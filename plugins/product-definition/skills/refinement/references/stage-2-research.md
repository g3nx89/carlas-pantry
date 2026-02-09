---
stage: stage-2-research
artifacts_written:
  - requirements/research/RESEARCH-AGENDA.md (conditional - manual research path)
  - requirements/research/research-synthesis.md (conditional - both auto and manual paths)
---

# Stage 2: Research Discovery (Coordinator)

> This stage is OPTIONAL. It generates research questions for offline user investigation.

## CRITICAL RULES (must follow — failure-prevention)

1. **Research is OPTIONAL**: NEVER block the workflow if user skips research. Set `status: completed` and proceed.
2. **User decisions are IMMUTABLE**: If `user_decisions.research_decision_round_N` exists, do NOT re-ask. Respect the prior decision.
3. **Exit pause MUST set state correctly**: When pausing for offline research, `waiting_for_user: true` and `pause_stage: 2` MUST be set in state — otherwise resume routing breaks.
4. **Research MCP failures are non-blocking**: If Tavily/Ref calls fail, fall back to manual research flow. NEVER abort the workflow due to research MCP errors.
5. **Never use Tavily for library documentation**: Use Ref (`ref_search_documentation`) for tech docs. Tavily is for market/competitive research only.

## Step 2.1: Determine Entry Point

Check the `ENTRY_TYPE` context variable provided by the orchestrator:
- If `ENTRY_TYPE: "re_entry_after_user_input"` -> User returning from offline research. Jump to Step 2.2 (check for reports).
- If `ENTRY_TYPE: "first_entry"` -> New entry. Check user_decisions below.
- **Fallback** (if ENTRY_TYPE not provided): Check state — if `waiting_for_user: true` AND `pause_stage: 2` -> Re-entry, otherwise -> First entry.

### Research Skip Check

**If user_decisions.research_decision_round_N exists:**
- `conduct_research` -> Check for reports (Step 2.2)
- `skip_with_context` -> Set status: completed, proceed
- `skip_entirely` -> Set status: completed, proceed

## Step 2.2: Check for Existing Research Reports

```bash
find requirements/research/reports -name "*.md" 2>/dev/null | wc -l
```

**If reports found > 0:** Jump to Step 2.6 (Research Synthesis)

## Step 2.3: Research Decision

**Check Research MCP availability** from state: `mcp_availability.research_mcp.tavily`

**If Tavily available:** Offer auto-research as the recommended option:

Set `status: needs-user-input` in summary with:
```yaml
flags:
  pause_type: interactive
  block_reason: "Ask user which research approach to use"
  question_context:
    question: "How would you like to conduct research before question generation?"
    header: "Research"
    options:
      - label: "Auto-research with MCP (Recommended)"
        description: "Automatically research market, competitors, and trends using web search (3-5 queries, ~$0.03-0.05)"
      - label: "Generate research agenda"
        description: "Generate targeted research questions I can investigate offline"
      - label: "Skip - I have domain knowledge"
        description: "I'll provide context directly, no external research needed"
      - label: "Skip entirely"
        description: "Proceed directly to question generation"
```

**If Tavily NOT available:** Use original options (no auto-research):

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
- "Auto-research with MCP" -> Continue to Step 2.4b (auto-research)
- "Yes"/"Generate research agenda" -> Continue to Step 2.4 (manual agenda)
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

## Step 2.4b: Auto-Research Execution (MCP Path)

> **Reference:** Load `@$CLAUDE_PLUGIN_ROOT/skills/refinement/references/research-mcp-reference.md` for query patterns and anti-patterns.

IF user chose "Auto-research with MCP":

### Step 2.4b.1: Extract Research Queries from Draft

Read `requirements/working/draft-copy.md` and decompose into 3-5 focused search queries:

| # | Category | Query Template | Required |
|---|----------|----------------|----------|
| 1 | Market Size | `"{product_category} market size revenue {current_year}"` | Yes |
| 2 | Competitors | `"{product_type} competitors comparison {target_audience} {current_year}"` | Yes |
| 3 | Target Audience | `"{target_audience} behavior trends {problem_domain} {current_year}"` | Yes |
| 4 | Industry Trends | `"{industry} trends regulations {current_year}"` | If draft mentions regulatory/compliance |
| 5 | Tech Documentation | Use `ref_search_documentation` (NOT Tavily) | If draft contains tech framework names |

**Query optimization rules:**
- Always append current year to market/trend queries
- Use specific multi-word queries (not broad keywords)
- Include target audience and product category in every query
- See `research-mcp-reference.md` -> "Query Patterns" for Poor → Good → Best examples

### Step 2.4b.2: Execute Tavily Searches

For each query (max `config.research_mcp.tavily.max_searches_per_round` searches):

```
mcp__tavily__tavily_search(
  query: "{optimized_query}",
  search_depth: config.research_mcp.tavily.search_depth,  # default: "basic"
  max_results: config.research_mcp.tavily.max_results,     # default: 5
  topic: config.research_mcp.tavily.topic                  # default: "general"
)
```

**After each search:**
- Filter results: keep only those with `score >= config.research_mcp.tavily.relevance_threshold` (default: 0.5)
- Extract key data points (numbers, names, dates) — not full page content
- Track `queries_executed` count against `max_searches_per_round`

**If any search fails:** Log the error, continue with remaining queries. See `error-handling.md` -> "Research MCP Failure Recovery".

### Step 2.4b.3: Optional Ref Documentation Lookup

**IF** `mcp_availability.research_mcp.ref = true` **AND** draft contains tech keywords from `config.research_mcp.ref.tech_keywords`:

```
mcp__Ref__ref_search_documentation(
  query: "{framework_name} {feature_area} documentation setup guide"
)
```

If results found, use `mcp__Ref__ref_read_url` to read the most relevant result.

**If Ref fails or returns no results:** Skip silently. Tech context is supplementary.

### Step 2.4b.4: Condense into Research Synthesis

Write `requirements/research/research-synthesis.md` using template from `$CLAUDE_PLUGIN_ROOT/templates/research-synthesis-template.md`.

**Token budget:** Output MUST NOT exceed `config.research_mcp.token_budgets.auto_research_output` tokens (default: 3,000).

**Per-query token limit:** Each individual search result fed into condensation MUST NOT exceed `config.research_mcp.token_budgets.per_query_input` tokens (default: 500). Truncate longer results to key data points before synthesis.

**Condensation structure and rules:** See `research-mcp-reference.md` -> "Output Condensation" for the full template, section ordering, and priority-based trimming rules.

### Step 2.4b.5: Present Results and Offer Supplementation

Set `status: needs-user-input` in summary:
```yaml
flags:
  pause_type: interactive
  block_reason: "Auto-research complete. Ask user to review and choose next step."
  question_context:
    question: "Auto-research complete. {N} queries executed, {M} sources analyzed. Research synthesis saved to requirements/research/research-synthesis.md. How would you like to proceed?"
    header: "Research"
    options:
      - label: "Proceed to questions (Recommended)"
        description: "Use auto-research findings for question generation"
      - label: "I'll add supplementary research"
        description: "Save additional reports to requirements/research/reports/. Re-run to continue."
      - label: "Discard and research manually"
        description: "Remove auto-research, generate offline research agenda instead"
  next_action_map:
    "Proceed to questions (Recommended)": "proceed"
    "I'll add supplementary research": "supplement_research"
    "Discard and research manually": "manual_fallback"
```

**Handle Response:**
- "Proceed" -> Set status: completed, proceed to Stage 3
- "Supplement" -> Set `waiting_for_user: true`, `pause_type: exit_cli`. User adds reports to `requirements/research/reports/` and re-runs. On re-entry, run Step 2.6 (synthesis) which merges auto-research with manual reports.
- "Discard" -> Delete `research-synthesis.md`, run Step 2.4 (manual agenda generation)

**Git Suggestion:**
```
git add requirements/research/
git commit -m "research(req): auto-research via MCP ({N} sources)"
```

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

**If both auto-research AND manual reports exist** (user chose "supplement" in Step 2.4b.5):
Merge auto-research synthesis with manual reports. Load `requirements/research/research-synthesis.md` (auto-research output) as baseline, then layer manual report findings on top. Resolve conflicts by preferring manual reports (user-curated data takes precedence over automated search results).

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
    research_method: "auto_mcp" | "manual" | "skipped"
    queries_executed: {N}       # Tavily queries run (0 if manual/skipped)
    tavily_used: {true|false}
    ref_used: {true|false}
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
  - requirements/research/RESEARCH-AGENDA.md (conditional - manual research path only)
  - requirements/research/research-synthesis.md (conditional - auto-research OR manual reports exist)
summary: "{see conditional text below}"
flags:
  research_method: "auto_mcp" | "manual" | "skipped"
  queries_executed: {N}       # 0 if manual/skipped
  sources_analyzed: {N}       # 0 if skipped
  reports_analyzed: {N}
  research_gaps: {N}
  round_number: {N}
---
```

**Conditional summary text:**
- Auto-research: `"Auto-research via MCP: {queries_executed} queries, {sources_analyzed} sources. Synthesis saved."`
- Manual: `"Generated research agenda with {N} questions. Synthesized {M} reports."`
- Skipped: `"Research skipped by user decision."`

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. If research agenda generated (manual path): `requirements/research/RESEARCH-AGENDA.md` exists
2. If auto-research executed (MCP path): `requirements/research/research-synthesis.md` exists and contains source URLs
3. If synthesis ran (manual reports): `requirements/research/research-synthesis.md` exists
4. User decision recorded in state: `user_decisions.research_decision_round_{N}`
5. State file was updated
6. Summary YAML frontmatter has no placeholder values
7. If auto-research: token count of research-synthesis.md does not exceed config budget

## CRITICAL RULES REMINDER

- Research is OPTIONAL — never block workflow if skipped
- User decisions are IMMUTABLE — never re-ask
- Exit pause MUST set waiting_for_user and pause_stage correctly
- Research MCP failures are non-blocking — fall back to manual flow
- Never use Tavily for library docs — use Ref for tech documentation
