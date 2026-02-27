---
schema_version: 1
id: FSB-{NNN}
name: {ScreenName}
status: pending       # pending | created
trigger: "{design-handoff | specify}"
source: "{Gap report Section 2 | US-NNN AC-NN}"
figma_node_id: null   # auto-populated in Stage 3.5.6 (Option A); set manually after Option B/C creation
created_at: "{ISO_TIMESTAMP}"
---

# FSB-{NNN} — {ScreenName}

## Purpose
{One sentence: what this screen accomplishes and why it's needed.}

## Context

| Field | Value |
|-------|-------|
| **Entry** | From {SourceScreen} when {trigger condition} |
| **Exit** | {Where the user goes next / stays on this screen} |
| **Classification** | {MUST_CREATE \| SHOULD_CREATE} |
| **Implied by** | {Element or US that requires this screen} |
| **Reference screen** | {ClosestExistingScreen} (nodeId: {REF_NODE_ID}) — copy structural pattern |

## Layout
{1-3 sentences describing rough structure only — no colors or spacing.
Example: "Centered modal over the previous screen. Header at top, body with form, two action buttons stacked at bottom."}

## Content

| Element | Text / Value |
|---------|-------------|
| {element_1} | "{label or placeholder text}" |
| {element_2} | "{label or placeholder text}" |
| {element_N} | "{label or placeholder text}" |

## States

| State | Trigger | Visual Delta |
|-------|---------|-------------|
| {state_1} | {what causes it} | {what changes visually} |
| {state_2} | {what causes it} | {what changes visually} |

## Behaviors

| Interaction | Result |
|-------------|--------|
| {user action} | {system response / navigation} |
| {user action} | {system response / navigation} |

## Figma Components to Use
<!-- Reference existing components from the design system. Use figma_search_components to find them. -->
- {ComponentName} — {where/why}
- {ComponentName} — {where/why}

## Design Tokens
<!-- Only semantic tokens — no raw hex values. -->
- {token.semantic.name} — {what it applies to}

## figma-console Notes
<!-- Hints for the coding agent executing this brief. -->
- Clone structure from reference screen: `nodeId: {REF_NODE_ID}`
- {Any specific figma_execute hints, variant names, or component search terms}
