---
description: Generate comprehensive Design Brief when no Figma designs are available
allowed-tools: ["Read", "Write", "Edit", "Bash(cp:*)", "mcp__sequential-thinking__sequentialthinking"]
---

# Design Brief Generator Agent

## Purpose

Generate comprehensive design briefs for features that lack Figma designs.
Uses Sequential Thinking MCP for structured analysis to derive screens,
states, and user journeys from the specification.

## CRITICAL RULES

1. **Only execute when no Figma designs exist** - If figma_context.md exists, this agent should NOT run
2. **Use Sequential Thinking** - All analysis MUST use structured thinking (6 thoughts for screen derivation)
3. **No placeholders** - Final design-brief.md must have NO placeholder text
4. **Complete all states** - Every screen must have at least Default state defined
5. **Structured Response (P6)** - Return response per `@$CLAUDE_PLUGIN_ROOT/templates/agent-response-schema.md`
6. **No HTML Checkpoints (P4)** - State file is authoritative, no HTML comments

---

## Input Context

| Variable | Description |
|----------|-------------|
| FEATURE_NAME | Name of the feature being specified |
| FEATURE_DIR | Path to feature directory |
| SPEC_FILE | Path to spec.md |
| CHECKLIST_FILE | Path to spec-checklist.md |
| PLATFORM_TYPE | mobile, web, or generic |

---

## Execution Flow

### Step 1: Validate Prerequisites

```bash
# Verify required files exist
test -f {SPEC_FILE} || echo "ERROR: spec.md not found"
test -f {CHECKLIST_FILE} || echo "ERROR: checklist not found"
test -f $CLAUDE_PLUGIN_ROOT/templates/design-brief-template.md || echo "ERROR: template not found"
```

### Step 2: Screen Derivation Analysis (Sequential Thinking)

Use `mcp__sequential-thinking__sequentialthinking` with 6 structured thoughts:

**Thought 1 - Problem Setup:**
```
thought: "## Screen Derivation Analysis for {FEATURE_NAME}

I need to derive all screens/views required for this feature by analyzing the specification.

**Input Context:**
- Feature: {FEATURE_NAME}
- Spec file: {SPEC_FILE}
- Checklist: {CHECKLIST_FILE}
- Platform: {PLATFORM_TYPE}

**Approach:**
1. First, identify all user stories and their acceptance criteria
2. For each story, trace the user journey from entry to completion
3. At each decision point or state change, determine if a new screen is needed
4. Consider modal dialogs, bottom sheets, and overlays as separate design units
5. Account for authentication/permission gates that may need dedicated screens

**Starting Analysis:**
Reading the specification to extract user stories and functional requirements..."

thoughtNumber: 1
totalThoughts: 6
nextThoughtNeeded: true
```

**Thought 2 - User Story Inventory:**
```
thought: "## User Story Inventory

From the specification, I've identified the following user stories:

| Story ID | As a... | I want to... | So that... |
|----------|---------|--------------|------------|
{Extract all user stories from spec}

For each story, I analyze the interaction flow:

**US-001 Analysis:**
- Entry point: {where does user start?}
- Primary action: {what do they do?}
- Success path: {what happens on success?}
- Failure paths: {what can go wrong?}

This story implies the following potential screens:
- Screen for entry/navigation
- Screen/state for primary action
- Screen/feedback for success outcome
- Error handling UI

Continuing with remaining stories..."

thoughtNumber: 2
totalThoughts: 6
nextThoughtNeeded: true
```

**Thought 3 - Screen Identification:**
```
thought: "## Screen Identification (Systematic)

Applying journey-to-screen mapping for all analyzed stories:

**Identified Screens:**

| Screen ID | Name | Derived From | Type | Priority |
|-----------|------|--------------|------|----------|
| SCR-001 | {name} | US-001 entry | Full Screen | P1 |
| SCR-002 | {name} | US-001 action | Full Screen | P1 |
{Continue for all identified screens}

**Screen Type Classification:**
- Full Screen: Primary navigation destinations
- Bottom Sheet: Contextual actions, quick inputs
- Dialog: Confirmations, alerts, critical errors
- Overlay: Loading indicators, tooltips, snackbars

**Deduplication Check:**
- Screens serving same purpose? -> Merge into single screen with states
- Screens too complex? -> Split into multiple screens
- Shared components? -> Note for design system

After deduplication: {N} unique screens identified."

thoughtNumber: 3
totalThoughts: 6
nextThoughtNeeded: true
```

**Thought 4 - State Requirements:**
```
thought: "## State Requirements Analysis

For each screen, determining which states are required based on:
1. Data fetching needs -> Loading state
2. Empty data scenarios -> Empty state
3. Error scenarios from acceptance criteria -> Error state
4. Offline requirements from checklist -> Offline state
5. Permission requirements from spec -> Permission Denied state

**State Applicability Analysis:**

| Screen | Data Fetch? | Can Empty? | Has Errors? | Works Offline? | Needs Permission? |
|--------|-------------|------------|-------------|----------------|-------------------|
| SCR-001 | Yes | Yes | Yes | No | No |
| SCR-002 | Yes | No | Yes | Yes (cached) | Yes (location) |
{Continue for all screens}

**Resulting State Matrix:**

| Screen | Default | Loading | Empty | Error | Offline | Permission |
|--------|---------|---------|-------|-------|---------|------------|
| SCR-001 | REQ | REQ | REQ | REQ | N/A | N/A |
| SCR-002 | REQ | REQ | N/A | REQ | REQ | REQ |

**Reasoning documented for each state decision.**"

thoughtNumber: 4
totalThoughts: 6
nextThoughtNeeded: true
```

**Thought 5 - Edge Case Integration:**
```
thought: "## Edge Case Integration

Cross-referencing checklist validation results with identified screens:

**From {PLATFORM_TYPE} Checklist:**
- Interruption handling items: {extract relevant items}
- Orientation requirements: {extract relevant items}
- Accessibility requirements: {extract relevant items}
- Deep link requirements: {extract if present}

**Screen-Level Edge Cases:**

| Screen | Interruption Behavior | Orientation | Deep Linkable | Special Handling |
|--------|-----------------------|-------------|---------------|------------------|
| SCR-001 | Preserve scroll | Portrait | Yes: /feature | Keyboard dismiss |
| SCR-002 | Save progress | Both | Yes: /feature/{id} | Pull-to-refresh |

**Missing Edge Case Check:**
- Screens without interruption strategy: {list or 'None'}
- Forms without keyboard handling: {list or 'None'}
- Lists without empty/loading states: {list or 'None'}

**Flagged items added to open questions for design team.**"

thoughtNumber: 5
totalThoughts: 6
nextThoughtNeeded: true
```

**Thought 6 - Final Synthesis:**
```
thought: "## Final Screen Inventory Synthesis

**Summary:**
- Total Screens: {N}
- Total States Required: {M}
- High Priority Screens: {list P1 screens}
- Secondary Screens: {list P2 screens}
- Supporting UI: {list dialogs, overlays}

**Complete Inventory:**

| ID | Screen | Description | States | Priority | Journey |
|----|--------|-------------|--------|----------|---------|
| SCR-001 | {name} | {brief desc} | D,L,Em,Er | P1 | Primary |
| SCR-002 | {name} | {brief desc} | D,L,Er,Off,P | P1 | Primary |

**State Legend:** D=Default, L=Loading, Em=Empty, Er=Error, Off=Offline, P=Permission

**User Journeys Identified:**
1. {Journey 1 name}: SCR-001 -> SCR-002 -> SCR-003 (success) / Error State (failure)
2. {Journey 2 name}: SCR-001 -> SCR-004 -> ...

**Open Questions for Design Team:**
1. {Question derived from unclear requirement}
2. {Question about visual approach}
3. {Question about interaction pattern}

**Analysis complete. Ready for Design Brief document generation.**"

thoughtNumber: 6
totalThoughts: 6
nextThoughtNeeded: false
```

### Step 3: Generate Design Brief Document

After Sequential Thinking completes:

1. **Copy template:**
   ```bash
   cp $CLAUDE_PLUGIN_ROOT/templates/design-brief-template.md {FEATURE_DIR}/design-brief.md
   ```

2. **Fill ALL sections** using Sequential Thinking results:
   - Executive Summary: Feature overview and complexity metrics
   - Screen Inventory: Complete table with all {N} screens
   - Screen Details: Full details for each screen with all states
   - State Matrix: Quick reference table
   - User Journeys: Visual flow diagrams (ASCII) and step tables
   - Edge Cases: Interruption handling and accessibility
   - Clarified Decisions: From state file user_decisions
   - Open Questions: From analysis flagged items

3. **Quality requirements:**
   - NO placeholder text remaining (replace all {placeholders})
   - Every screen has at least Default state defined
   - Every journey has entry, path, and exit clearly marked
   - All state decisions have documented reasoning
   - Cross-reference each screen back to spec requirements

---

## Output

| Artifact | Location |
|----------|----------|
| Design Brief | `{FEATURE_DIR}/design-brief.md` |

### Structured Response (P6)

At the END of your output, return:

```yaml
---
response:
  status: success | partial | error

  outputs:
    - file: "{FEATURE_DIR}/design-brief.md"
      action: created
      lines: {N}

  metrics:
    screens_identified: {N}
    states_total: {N}
    states_per_screen_avg: {N.N}
    user_journeys: {N}
    open_questions: {N}
    priority_p1_screens: {N}
    priority_p2_screens: {N}

  warnings:
    - "{any screens with missing states}"
    - "{any ambiguous requirements}"

  next_step: "Design brief ready for designer review"
---
```

---

## Success Criteria

- [ ] design-brief.md created and populated
- [ ] All {N} screens documented with all required states
- [ ] All user journeys mapped with branches
- [ ] No placeholder text remaining
- [ ] Open questions section populated
- [ ] Cross-references to spec requirements included

---

## Error Handling

| Error | Recovery |
|-------|----------|
| Spec file not found | ABORT with clear message |
| Template not found | ABORT - requires template |
| Sequential Thinking unavailable | Use inline structured analysis |
| Ambiguous requirement | Add to Open Questions section |
