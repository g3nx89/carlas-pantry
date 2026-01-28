# Phase 3: Configuration

> **Source:** Extracted from `/product-definition:requirements` main orchestration

**Checkpoint:** `ANALYSIS_MODE_SELECTION`

**Goal:** Select the analysis mode for the current round (Complete/Advanced/Standard/Rapid).

## Step 3.1: Check for --mode Flag

If `$ARGUMENTS` contains `--mode=X`:
- `--mode=complete` ANALYSIS_MODE = "complete"
- `--mode=advanced` ANALYSIS_MODE = "advanced"
- `--mode=standard` ANALYSIS_MODE = "standard"
- `--mode=rapid` ANALYSIS_MODE = "rapid"
Skip to Step 3.3

## Step 3.2: Ask User for Analysis Mode

**Check MCP availability first:**

If `PAL_AVAILABLE = false`:
- Only offer Standard and Rapid modes
- Explain: "Complete and Advanced modes require PAL tools which are not available"

Use `AskUserQuestion`:

**If PAL available (full options):**
```json
{
  "questions": [{
    "question": "Which analysis level do you want for this round?",
    "header": "Analysis",
    "multiSelect": false,
    "options": [
      {"label": "Complete Analysis (MPA + PAL + ST) (Recommended)", "description": "3 MPA agents + 3 PAL perspectives + Sequential Thinking + PAL Consensus. Maximum depth, ~$0.50-1.00/round"},
      {"label": "Advanced Analysis (MPA + PAL)", "description": "3 MPA agents + 2 PAL ThinkDeep perspectives. Good depth, ~$0.30-0.50/round"},
      {"label": "Standard Analysis (MPA only)", "description": "3 MPA agents only. Solid coverage, ~$0.15-0.25/round"},
      {"label": "Rapid Analysis (Single agent)", "description": "Single BA agent. Fast and minimal cost, ~$0.05-0.10/round"}
    ]
  }]
}
```

**If PAL NOT available (degraded options):**
```json
{
  "questions": [{
    "question": "Which analysis level do you want for this round?\n\n**Note:** PAL tools unavailable. Complete and Advanced modes disabled.",
    "header": "Analysis",
    "multiSelect": false,
    "options": [
      {"label": "Standard Analysis (MPA only) (Recommended)", "description": "3 MPA agents. Solid coverage, ~$0.15-0.25/round"},
      {"label": "Rapid Analysis (Single agent)", "description": "Single BA agent. Fast and minimal cost, ~$0.05-0.10/round"}
    ]
  }]
}
```

## Step 3.3: Update State (CHECKPOINT)

```yaml
user_decisions:
  analysis_mode_round_1: "{ANALYSIS_MODE}"

phases:
  analysis_mode_selection:
    status: completed
    mode: "{ANALYSIS_MODE}"
    timestamp: "{now}"
```

**IMMUTABLE**: This mode applies to the current round. User can change for subsequent rounds.
