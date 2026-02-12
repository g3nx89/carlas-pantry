---
stage: stage-3-checklist
artifacts_written:
  - specs/{FEATURE_DIR}/spec-checklist.md
---

# Stage 3: Checklist & Validation (Coordinator)

> This stage creates a platform-appropriate checklist and validates the spec against it.
> Produces a coverage score that drives the iteration loop (Stage 3 <-> Stage 4).

## CRITICAL RULES (must follow — failure-prevention)

1. **Platform detection**: Auto-detect from Figma context or prior specs; ask user only if ambiguous
2. **Coverage thresholds**: GREEN >= 85%, YELLOW 60-84%, RED < 60%
3. **BA marks gaps**: Add `[NEEDS CLARIFICATION]` markers in spec for unresolved items
4. **NEVER interact with users directly**: signal `needs-user-input` for platform choice if ambiguous
5. **Checklist template source**: Use `$CLAUDE_PLUGIN_ROOT/templates/spec-checklist-mobile.md` for mobile, `$CLAUDE_PLUGIN_ROOT/templates/spec-checklist.md` for generic

## Step 3.1: Platform Auto-Detection

Determine platform type from available context:

```
IF figma_context.md exists:
    GREP for mobile keywords: "iOS", "Android", "mobile", "screen", "tap", "swipe",
                              "notification", "push", "app store"
    IF mobile keywords found >= 3: PLATFORM = "mobile"
    ELSE: PLATFORM = "generic"

ELIF spec.md contains mobile-specific requirements:
    PLATFORM = "mobile"

ELSE:
    PLATFORM = "generic"
```

**If ambiguous** (mobile keywords = 1-2):
Signal `needs-user-input`:
```yaml
flags:
  pause_type: "interactive"
  block_reason: "Platform type is ambiguous — need user confirmation"
  question_context:
    question: "What platform is this feature for?"
    header: "Platform"
    options:
      - label: "Mobile (iOS/Android)"
        description: "Use mobile-specific checklist with platform considerations"
      - label: "Web/Generic"
        description: "Use standard specification checklist"
```

## Step 3.2: Create Checklist

Copy appropriate template to feature directory:

```bash
IF PLATFORM == "mobile":
    cp "$CLAUDE_PLUGIN_ROOT/templates/spec-checklist-mobile.md" "specs/{FEATURE_DIR}/spec-checklist.md"
ELSE:
    cp "$CLAUDE_PLUGIN_ROOT/templates/spec-checklist.md" "specs/{FEATURE_DIR}/spec-checklist.md"
```

## Step 3.3: Launch BA Validation

Dispatch BA agent via `Task(subagent_type="general-purpose")`:

```
## Task: Validate Specification Against Checklist

Read the specification and evaluate each checklist item:

Spec: @specs/{FEATURE_DIR}/spec.md
Checklist: @specs/{FEATURE_DIR}/spec-checklist.md

## Instructions
@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-validate.md

For each checklist item:
- COVERED: Mark with checkmark, cite spec section
- PARTIAL: Mark with warning, note what's missing
- MISSING: Mark with cross, add `[NEEDS CLARIFICATION]` marker in spec

Write updated checklist to: specs/{FEATURE_DIR}/spec-checklist.md
Update spec with [NEEDS CLARIFICATION] markers: specs/{FEATURE_DIR}/spec.md
```

## Step 3.4: Process Results

Parse BA validation output:
- `overall_score`: N out of total items
- `coverage_pct`: percentage covered (fully + partially)
- `gaps_list`: list of missing/partial items
- `markers_added`: count of `[NEEDS CLARIFICATION]` markers

**Apply thresholds:**
- coverage_pct >= 85%: GREEN — coverage is high
- coverage_pct >= 60%: YELLOW — moderate coverage, needs clarification
- coverage_pct < 60%: RED — low coverage, significant gaps

## Step 3.5: Checkpoint

Update state file:
```yaml
current_stage: 3
stages:
  checklist_validation:
    status: completed
    timestamp: "{ISO_TIMESTAMP}"
    platform_type: "{mobile|generic}"
    coverage_pct: {N}
    gaps_count: {N}
    markers_added: {N}
    iteration: {N}
```

## Summary Contract

> **Size limits:** `summary` max 500 chars, Context body max 1000 chars. Details in artifacts, not summaries.

```yaml
---
stage: "checklist-validation"
stage_number: 3
status: completed
checkpoint: CHECKLIST_VALIDATION
artifacts_written:
  - specs/{FEATURE_DIR}/spec-checklist.md
summary: "Checklist validation: {COVERAGE_PCT}% coverage ({COLOR}). {GAPS_COUNT} gaps found, {MARKERS} clarification markers added."
flags:
  coverage_pct: {N}
  coverage_color: "{GREEN|YELLOW|RED}"
  gaps_count: {N}
  markers_added: {N}
  platform_type: "{mobile|generic}"
  iteration: {N}
  next_action: "proceed" | "loop_clarify"
---

## Context for Next Stage
Checklist coverage: {COVERAGE_PCT}% ({COLOR}).
Gaps requiring clarification: {LIST_OF_GAPS}
Markers in spec: {MARKERS_COUNT} [NEEDS CLARIFICATION] markers.
```

**next_action logic:**
- If coverage_pct >= 85% AND gaps_count == 0: `"proceed"` (skip Stage 4 clarification loop)
- Otherwise: `"loop_clarify"` (dispatch Stage 4)

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. `specs/{FEATURE_DIR}/spec-checklist.md` exists with item-level evaluations
2. Coverage percentage is calculated correctly (not placeholder)
3. `[NEEDS CLARIFICATION]` markers in spec match gaps_count
4. Platform type is recorded in state
5. Summary YAML frontmatter has no placeholder values

## CRITICAL RULES REMINDER

- Platform auto-detect first, ask user only if ambiguous
- Coverage thresholds: 85% GREEN, 60% YELLOW, <60% RED
- BA adds [NEEDS CLARIFICATION] markers for all gaps
- NEVER interact with users directly
