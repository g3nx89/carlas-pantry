# Business Analyst: Checklist Validation

## Prompt Context

{RESUME_CONTEXT}

## Task

Validate the specification against the platform-specific checklist.
Identify gaps, coverage issues, and areas needing clarification.

## Variables

| Variable | Value |
|----------|-------|
| FEATURE_NAME | {value} |
| FEATURE_DIR | {value} |
| SPEC_FILE | {value} |
| CHECKLIST_FILE | {value} |
| STATE_FILE | {value} |
| PLATFORM_TYPE | {value} |

## Validation Process

### Step 1: Load Artifacts

1. Read specification: `{SPEC_FILE}`
2. Read checklist template based on PLATFORM_TYPE:
   - mobile: `specs/templates/spec-checklist-mobile.md`
   - web: `specs/templates/spec-checklist-web.md` (if exists)
   - generic: `specs/templates/spec-checklist.md`

### Step 2: Copy and Populate Checklist

```bash
cp specs/templates/{appropriate-checklist} {FEATURE_DIR}/spec-checklist.md
```

### Step 3: Evaluate Each Item

For EACH checklist item:
1. Search spec for coverage
2. Mark as:
   - `[x]` - Covered with evidence
   - `[ ]` - Not covered (gap)
3. Add notes for partial coverage or special circumstances

## Checklist Scoring Guide

### Calculation
- Each checklist item: 0 (unchecked) or 1 (checked)
- Score = (checked_items / total_items) x 100

### Thresholds

| Score Range | Status | Action |
|-------------|--------|--------|
| 80-100 | GREEN | Proceed to PAL Consensus |
| 60-79 | YELLOW | Proceed with warnings, note gaps |
| 0-59 | RED | BLOCK - Address critical gaps first |

### Iteration Rules
- Max iterations: 3
- After iteration 3 with RED: Escalate to user
- Each iteration should improve score by >= 10 points

## Output Requirements

### Checklist File Updates

1. Mark all items with evidence from spec
2. Add `<!-- Evidence: {spec_section} -->` comments
3. List uncovered items at the end

### State File Updates

```yaml
phases:
  checklist_validation:
    status: completed
    timestamp: "{now}"
    score: {calculated_score}
    coverage_pct: {percentage}
    gaps_identified:
      - item: "{checklist_item}"
        severity: "{CRITICAL|HIGH|MEDIUM|LOW}"
        reason: "{why not covered}"
    iteration: {N}
```

### Output Format

```text
Checklist Validation Result:
- Score: {score}/100 [{GREEN|YELLOW|RED}]
- Checked: {checked}/{total} items
- Critical gaps: {list of unchecked P1 items}
- Iteration: {N}/3
```
