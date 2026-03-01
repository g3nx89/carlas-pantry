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

## Step 3.0: Validate Pre-Conditions

```bash
test -f "specs/{FEATURE_DIR}/spec.md" || echo "BLOCKER: spec.md missing — Stage 2 must complete first"
```

**If BLOCKER found:** Set `status: failed`, `block_reason: "Pre-condition failed"`. Do not proceed.

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

## Step 3.3b: Figma Mock Coverage Check

**Runs only if `STATE.handoff_supplement.available == true`.**

For each user story in `spec.md`, scan its Figma references row:
- `[Happy→Frame-X]` → verify `Frame-X` exists in the HANDOFF-SUPPLEMENT Screen Reference Table
- `[FSB-NNN pending]` → this is already documented — not a new missing mock, just not yet created
- `[Frame: ScreenName]` placeholder (no node ID) → screen name not found in supplement → **FIGMA MOCK MISSING**
- No Figma reference at all for a story with behavioral AC → **FIGMA MOCK MISSING**

For each AC row tagged `FIGMA MOCK MISSING`, add a marker in `spec.md`:
```
[FIGMA MOCK MISSING: {US-NNN} {scenario description} — no Figma frame for this scenario]
```

Track:
```yaml
figma_mock_gaps:
  count: {N}
  items:
    - us_id: "US-NNN"
      scenario: "{scenario description}"
      reason: "{why mock is needed}"
```

**If count > 0:** Set `flags.figma_mock_gaps_count: {N}` in summary contract.
**If count == 0:** Set `flags.figma_mock_gaps_count: 0` — no action needed.

This check is independent of the checklist coverage score. Figma mock gaps do NOT reduce coverage_pct —
they are surfaced separately in Stage 4 (see stage-4-clarification.md Step 4.0b).

## Step 3.3c: RTM Coverage Re-Evaluation (Conditional)

**Check:** `RTM_ENABLED == true` (from state file `rtm_enabled`)

**If RTM disabled:** Skip entirely, proceed to Step 3.4.
Mark RTM checklist items (Section 10 in generic / Section 15 in mobile) as `N/A — RTM tracking disabled`
in the checklist output. These items MUST NOT count toward the coverage denominator.

**If RTM enabled:**

1. Re-read `specs/{FEATURE_DIR}/rtm.md` and `specs/{FEATURE_DIR}/spec.md`
2. Re-evaluate dispositions — previously UNMAPPED REQs may now be COVERED after BA validation
   added or refined user stories during checklist iteration
3. For each UNMAPPED REQ:
   - Search spec for new `@RTMRef` annotations or semantic matches
   - If match found: update disposition to COVERED or PARTIAL
4. Update `specs/{FEATURE_DIR}/rtm.md` with revised dispositions
5. Calculate updated metrics:
   - `rtm_coverage_pct = (covered + partial + deferred + removed) / total * 100`
   - `rtm_unmapped_count`: count of remaining UNMAPPED entries

**Note:** RTM coverage is an independent metric from checklist `coverage_pct`.
It does NOT affect the main checklist coverage score or the Stage 3↔4 iteration loop.
UNMAPPED requirements are resolved through the disposition gate in Stage 4 (Step 4.0a).

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
  figma_mock_gaps_count: {N}
  rtm_unmapped_count: {N|0}
  rtm_coverage_pct: {N|0}
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

**If ANY check fails:** Fix the issue. If unfixable: set `status: failed` with `block_reason` describing the failure.

