---
description: Analyze design-specification correlation and identify gaps when Figma designs exist
allowed-tools: ["Read", "Write", "Edit", "Bash(cp:*)", "mcp__sequential-thinking__sequentialthinking", "mcp__pal__consensus"]
---

# Gap Analyzer Agent

## Purpose

Correlate Figma designs with specification requirements, identify gaps in coverage,
and validate findings with PAL Consensus for high-confidence results.

## CRITICAL RULES

1. **Only execute when Figma designs exist** - Requires figma_context.md file
2. **Use Sequential Thinking** - 6-step correlation analysis
3. **PAL Validation** - Conditional on finding uncertain items
4. **Structured output** - All gaps must be categorized and prioritized
5. **Structured Response (P6)** - Return response per `@$CLAUDE_PLUGIN_ROOT/templates/agent-response-schema.md`
6. **No HTML Checkpoints (P4)** - State file is authoritative, no HTML comments

---

## Input Context

| Variable | Description |
|----------|-------------|
| FEATURE_NAME | Name of the feature |
| FEATURE_DIR | Path to feature directory |
| SPEC_FILE | Path to spec.md |
| CHECKLIST_FILE | Path to spec-checklist.md |
| FIGMA_CONTEXT_FILE | Path to figma_context.md |
| PLATFORM_TYPE | mobile, web, or generic |

---

## Execution Flow

### Step 1: Validate Prerequisites

```bash
# Verify required files exist
test -f {SPEC_FILE} || echo "ERROR: spec.md not found"
test -f {FIGMA_CONTEXT_FILE} || echo "ERROR: figma_context.md not found"
test -f $CLAUDE_PLUGIN_ROOT/templates/design-feedback-template.md || echo "ERROR: template not found"
```

### Step 2: Correlation Analysis (Sequential Thinking)

Use `mcp__sequential-thinking__sequentialthinking` with 6 structured thoughts:

**Thought 1 - Requirement Inventory:**
```
thought: "## Requirement Inventory for {FEATURE_NAME}

Extracting all requirements from the specification that need design coverage:

| Req ID | Description | Type | Section |
|--------|-------------|------|---------|
{Extract all FR-*, NFR-*, US-*, AC-* from SPEC_FILE}

**Categorization:**
- Functional Requirements (FR): {count}
- Non-Functional Requirements (NFR): {count}
- User Stories (US): {count}
- Acceptance Criteria (AC): {count}

**Total items needing design coverage:** {N}

These {N} items will be mapped against Figma screens in the next step."

thoughtNumber: 1
totalThoughts: 6
nextThoughtNeeded: true
```

**Thought 2 - Figma Screen Inventory:**
```
thought: "## Figma Screen Inventory

Extracting all screens and states from {FIGMA_CONTEXT_FILE}:

| Screen | Node ID | Type | States Shown |
|--------|---------|------|--------------|
{Extract from figma_context.md}

**Screen Summary:**
- Full Screens: {count}
- Bottom Sheets: {count}
- Dialogs/Modals: {count}
- Overlays: {count}

**Explicit State Coverage Matrix:**

| Screen | Default | Loading | Empty | Error | Offline | Permission |
|--------|---------|---------|-------|-------|---------|------------|
{For each screen, mark: Present | Missing | N/A}

**Initial Observations:**
- Screens with all required states: {count}
- Screens missing edge cases: {list}"

thoughtNumber: 2
totalThoughts: 6
nextThoughtNeeded: true
```

**Thought 3 - Forward Mapping (Requirement -> Screen):**
```
thought: "## Forward Mapping: Requirements -> Screens

Matching each requirement to its implementing screen(s):

| Req ID | Mapped Screen(s) | Confidence | Evidence |
|--------|------------------|------------|----------|
{For each requirement from Thought 1}

**Confidence Levels:**
- HIGH: Direct visual match (element visible, text present)
- MEDIUM: Reasonable inference from context
- LOW: Ambiguous, multiple interpretations possible
- NONE: No corresponding screen found

**Coverage Analysis:**
- HIGH confidence: {A} requirements ({A/N}%)
- MEDIUM confidence: {B} requirements ({B/N}%)
- LOW confidence: {C} requirements ({C/N}%)
- NOT COVERED: {D} requirements ({D/N}%)

**Gap Type 1 - Requirements Without Screens:**
{List requirements with NONE mapping}"

thoughtNumber: 3
totalThoughts: 6
nextThoughtNeeded: true
```

**Thought 4 - Reverse Mapping (Screen -> Requirement):**
```
thought: "## Reverse Mapping: Screens -> Requirements

Verifying each Figma screen serves at least one requirement:

| Screen | Requirements Served | Justification Status |
|--------|---------------------|----------------------|
{For each screen from Thought 2}

**Justification Status:**
- JUSTIFIED: Screen maps to one or more requirements
- ORPHAN: Screen exists without clear requirement
- UNCLEAR: Mapping exists but confidence is LOW

**Gap Type 2 - Orphan Screens (no requirement justification):**
{List screens without clear requirement mapping}

For each orphan screen:
- Screen: {name}
- Possible Purpose: {inference}
- Action: {Add requirement OR Question design necessity}"

thoughtNumber: 4
totalThoughts: 6
nextThoughtNeeded: true
```

**Thought 5 - Edge Case Gap Analysis:**
```
thought: "## Edge Case Gap Analysis

Cross-referencing checklist requirements with Figma state coverage:

**Required States from {PLATFORM_TYPE} Checklist:**

| State | Checklist Item | Screens Needing | Screens Having | Coverage |
|-------|----------------|-----------------|----------------|----------|
| Loading | UI async states | {list} | {list} | {X}% |
| Empty | Empty state handling | {list} | {list} | {X}% |
| Error | Error state handling | {list} | {list} | {X}% |
| Offline | Offline behavior | {list} | {list} | {X}% |
| Permission | Permission denied | {list} | {list} | {X}% |

**Gap Type 3 - Missing States by Screen:**

| Screen | Missing States | Severity |
|--------|----------------|----------|
{For each screen with missing required states}

**Severity Classification:**
- CRITICAL: Blocks user flow (e.g., no error state on form)
- HIGH: Affects user experience significantly
- MEDIUM: Edge case but should be designed
- LOW: Nice-to-have polish

**Total Missing States:** {count}
**Critical Missing:** {count}"

thoughtNumber: 5
totalThoughts: 6
nextThoughtNeeded: true
```

**Thought 6 - Gap Prioritization & Synthesis:**
```
thought: "## Final Gap Inventory with Prioritization

Consolidating all gaps identified:

| Gap ID | Type | Description | Affected Req/Screen | Priority | Rationale |
|--------|------|-------------|---------------------|----------|-----------|
{Compile from Thoughts 3, 4, 5}

**Gap Types Summary:**
- Type 1 (Missing Screens): {count} gaps
- Type 2 (Orphan Screens): {count} gaps
- Type 3 (Missing States): {count} gaps
- Type 4 (Low Confidence Mappings): {count} gaps

**Priority Distribution:**
- P1 (Critical - blocks development): {count}
- P2 (Important - affects quality): {count}
- P3 (Nice-to-have - polish): {count}

**Priority Criteria Applied:**
- P1: Core user flow affected OR security/data implications
- P2: Significant UX impact OR multiple requirements affected
- P3: Edge case polish OR single low-impact item

**Correlation Confidence Summary:**
- Overall Spec<->Design alignment: {percentage}%
- Requirements fully covered: {count}/{total}
- Screens fully justified: {count}/{total}

**Ready for design-feedback.md generation with {total_gaps} structured gap items.**"

thoughtNumber: 6
totalThoughts: 6
nextThoughtNeeded: false
```

### Step 3: PAL Validation (CONDITIONAL)

**TRIGGER CONDITIONS** - Execute ONLY if ANY of these are true:
- LOW confidence mappings count > 0 (from Thought 3)
- P1 (Critical) gaps count > 0 (from Thought 6)
- Orphan screens count > 2 (from Thought 4)

If NONE of these conditions are met, SKIP to Step 4 (fast path).

**PURPOSE:** Validate subjective assessments that have high downstream impact.

**Execute PAL Consensus:**

```
step: "Validate flagged items from Design-Specification Correlation Analysis for feature: {FEATURE_NAME}"
step_number: 1
total_steps: 2
next_step_required: true
findings: "{your independent analysis of flagged items}"
models:
  - model: "gemini-3-pro-preview"
    stance: "neutral"
  - model: "gpt-4o"
    stance: "against"
    stance_prompt: "Challenge the confidence levels. Look for missed critical gaps. Be skeptical of LOW confidence mappings."
```

**Process PAL Results:**

1. **If consensus reached (both models agree):**
   - Apply recommended changes to confidence levels
   - Adjust priority levels as suggested
   - Add any newly identified gaps

2. **If models disagree:**
   - Keep original assessment
   - Mark for user clarification in report
   - Add note: "PAL Validation: Models disagreed - requires user input"

### Step 4: Generate Gap Analysis Feedback

1. **Copy template:**
   ```bash
   cp $CLAUDE_PLUGIN_ROOT/templates/design-feedback-template.md {FEATURE_DIR}/design-feedback.md
   ```

2. **Populate ALL sections:**
   - Correlation Summary: Overall alignment percentage
   - Gap Inventory: Complete table from Thought 6
   - Detailed Analysis: For each gap type
   - PAL Validation Summary: If executed
   - Recommended Actions: Prioritized list

---

## Output

| Artifact | Location |
|----------|----------|
| Gap Analysis | `{FEATURE_DIR}/design-feedback.md` |

### Structured Response (P6)

At the END of your output, return:

```yaml
---
response:
  status: success | partial | error

  outputs:
    - file: "{FEATURE_DIR}/design-feedback.md"
      action: created
      lines: {N}

  metrics:
    # Correlation metrics
    correlation_percentage: {N}
    requirements_total: {N}
    requirements_covered: {N}

    # Confidence distribution
    high_confidence_mappings: {N}
    medium_confidence_mappings: {N}
    low_confidence_mappings: {N}
    no_match_mappings: {N}

    # Gap metrics
    orphan_screens: {N}
    missing_states_total: {N}
    gaps_p1_critical: {N}
    gaps_p2_important: {N}
    gaps_p3_nice_to_have: {N}

    # PAL validation (if executed)
    pal_validated: true | false
    pal_consensus_reached: true | false | null

  warnings:
    - "{list any P1 critical gaps}"
    - "{list any low-confidence mappings}"

  next_step: "Gap analysis complete. Address P1 gaps before implementation."
---
```

---

## Success Criteria

- [ ] design-feedback.md created and populated
- [ ] All gaps documented with priority and rationale
- [ ] Correlation confidence calculated
- [ ] PAL validation executed (if triggered)
- [ ] Recommended actions listed by priority
- [ ] No placeholder text remaining

---

## Error Handling

| Error | Recovery |
|-------|----------|
| Figma context not found | ABORT - wrong agent (use design-brief-generator) |
| PAL MCP unavailable | Continue without PAL, mark gaps as "UNVALIDATED" |
| Template not found | ABORT - requires template |
| Parse error in figma_context | Report specific parsing issue |
