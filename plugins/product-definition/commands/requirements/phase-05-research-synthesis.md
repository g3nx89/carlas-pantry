# Phase 5: Research Synthesis (Optional)

> **Source:** Extracted from `/product-definition:requirements` main orchestration

**Checkpoint:** `RESEARCH_ANALYSIS`

**Goal:** Analyze user-provided research reports and synthesize findings for PRD context.

> **Note:** This phase only runs if user conducted research in Phase 4. Otherwise, skip to Phase 6.

## Step 5.1: Inventory Reports

```bash
ls -la requirements/research/reports/*.md 2>/dev/null
```

## Step 5.2: Analyze Reports

**If ST_AVAILABLE = true:**
Use `mcp__sequential-thinking__sequentialthinking` for systematic analysis:

Steps:
1. Extract Key Findings from each report
2. Cross-Reference findings across reports
3. Conflict Detection
4. Evidence Quality assessment
5. Gap Analysis (questions not addressed)
6. PRD Implications
7. Risk Identification
8. Synthesis

**If ST_AVAILABLE = false:**
Use internal reasoning to perform the same 8-step analysis. Document clearly in output that this was done without Sequential Thinking.

## Step 5.3: Generate Research Synthesis

Output: `requirements/research/research-synthesis.md`

Use template from `$CLAUDE_PLUGIN_ROOT/templates/research-synthesis-template.md`

## Step 5.4: Update State (CHECKPOINT)

```yaml
phases:
  research_analysis:
    status: completed
    reports_analyzed: {N}
    consensus_findings: {N}
    research_gaps: {N}
    st_used: {true|false}
```
