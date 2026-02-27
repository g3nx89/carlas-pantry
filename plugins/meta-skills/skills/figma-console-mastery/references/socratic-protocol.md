# Socratic Protocol

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Interactive planning protocol for Flow 1 Phase 2 (Create and Restructure modes).
> Captures user-approved design decisions before execution via 11 structured question categories (Cat. 0-10).
>
> **Load when**: Orchestrator enters Phase 2 of Flow 1 (Create or Restructure mode).

---

## Overview

The Socratic Protocol ensures user-approved design decisions before execution. Each category prompts the user with key questions using `AskUserQuestion`, captures decisions, and builds an approved checklist.

**Critical rule**: Every `AskUserQuestion` MUST include a "Let's discuss this" option (Cross-Cutting Principle P3). Never force users into constrained choices.

---

## Mode-Specific Category Subsets

| Mode | Categories | Skip |
|------|-----------|------|
| **Create** | Cat. 0, 1, 2 (optional), 5, 6, 7, 8, 10 (optional) | Cat. 3, 4, 9 |
| **Restructure** | All categories (0-10) | None |

---

## Category 0 — Existing Documentation Check

**Purpose**: Identify existing specifications, design briefs, or wireframes that should guide the work.

**Key questions**:
1. **Check specs directory**: Search `specs/` for files related to this screen.
   - Options: "Use [file] as reference", "Ignore and start fresh", "Let's discuss this"

2. **External references**: "Do you have design briefs, wireframes, or mockups outside Figma that should guide this work?"
   - Options: "Yes, I'll provide them", "No, proceed without", "Let's discuss this"

**Output**: Reference to existing docs (file path or user-provided content) OR "No documentation — proceeding without reference"

---

## Category 1 — User Description of Screen

**Purpose**: Capture the user's vision for the screen's purpose, key elements, and user flow.

**Key questions**:
1. **Screen purpose**: "What is the primary purpose of this screen? What should users accomplish here?"
   - Free-form text input + "Let's discuss this"

2. **Key elements**: "What are the main UI elements you envision? (e.g., header, form, data table, action buttons)"
   - Free-form list + "Let's discuss this"

3. **User flow**: "How do users arrive at this screen, and where do they go next?"
   - Free-form flow description + "Let's discuss this"

**Output**: User-provided screen description OR "No description provided — proceeding with visual analysis only"

**Mode notes**: Optional for Create mode (skip if user has no specific vision). Always run for Restructure if major changes planned.

---

## Category 2 — Cross-Screen Comparison (optional)

**Purpose**: Identify existing screens that should serve as design reference for consistency.

**Key questions**:
1. **Pattern matching**: "This project has existing screens: [list]. Should this screen match the design patterns of any existing screen?"
   - Options: "[Screen name]", "Standalone design", "Let's discuss this"

2. **Component reuse**: "Should this screen reuse components from [reference screen]?"
   - Options: "Yes, reuse components", "No, create new", "Let's discuss this"

**Output**: Reference screen(s) with specific patterns to match OR "Standalone design — no cross-screen constraints"

**Mode notes**: Optional for both modes. Skip if project has only one screen or user requests standalone design.

---

## Category 3 — General Approach (Restructure only)

**Purpose**: Choose between surgical fixes (preserve structure) or full rebuild.

**Key questions**:
1. **Path selection**: "Based on Phase 1 analysis, I found [N issues]:
   - **Path A (Surgical)**: Preserve existing structure, apply auto-layout and tokens selectively. Lower risk of breaking prototype connections.
   - **Path B (Rebuild)**: Reconstruct from scratch. Cleaner result, requires re-wiring prototypes.

   Which path?"
   - Options: "Path A (Surgical)", "Path B (Rebuild)", "Let's discuss this"

2. **Preserve prototype?**: If prototype connections exist: "I detected [N] prototype connections. Path B will break these. Should I preserve the prototype?"
   - Options: "Yes, preserve (forces Path A)", "No, I'll re-wire later", "Let's discuss this"

**Output**: "Path A" or "Path B" with brief rationale (e.g., "Path A chosen to preserve 12 prototype connections")

**Mode notes**: Restructure mode only. Skip for Create mode.

---

## Category 4 — Screen Structure & Positioning (Restructure only)

**Purpose**: Get user approval for structural changes to layer hierarchy.

**Key questions**:
1. **Flatten deep nesting**: "I found [N] deeply nested GROUP layers (5+ levels). Should I flatten these?"
   - Options: "Yes, flatten all", "Show me the list first", "Let's discuss this"

2. **Reparent floating elements**: "I found [N] elements with absolute positioning that could be grouped into sections. Propose grouping?"
   - Options: "Yes, group by section", "Keep as-is", "Let's discuss this"

3. **Section naming**: "I'll create sections like [Header], [Main Content], [Footer]. Approve these names or suggest alternatives?"
   - Free-form name list + "Let's discuss this"

**Output**: Approved structural changes list (e.g., "Flatten 8 GROUP layers in left nav, reparent 5 floating cards to Main Content section")

**Mode notes**: Restructure mode only. Skip for Create mode (structure defined from scratch).

---

## Category 5 — Auto-Layout, Padding & Spacing

**Purpose**: Identify frames that should use auto-layout and define spacing rules.

**Key questions**:
1. **Auto-layout targets**: "I identified [N] frames that should use auto-layout: [list]. Approve this list?"
   - Options: "Yes, apply auto-layout", "Show me visual before/after", "Let's discuss this"

2. **Spacing system**: "I'll use 4px-based spacing (4, 8, 12, 16, 24, 32, 48). Confirm or adjust?"
   - Options: "Use 4px system", "Use 8px system", "Custom values", "Let's discuss this"

3. **Padding values**: "For containers, I propose: Cards=16px, Modals=24px, Page margins=32px. Confirm?"
   - Options: "Confirm", "Show alternatives", "Let's discuss this"

**Output**: Auto-layout targets with spacing/padding values (e.g., "Apply auto-layout to 12 frames: vertical gap=16px, horizontal padding=24px")

---

## Category 6 — Componentization

**Purpose**: Identify repeated elements that should become components, applying Smart Componentization Criteria.

**Smart Componentization Criteria** (3 gates):
1. **Recurrence**: Element appears 3+ times
2. **Behavioral variants**: Element has clear variants (size, state, type)
3. **Codebase match**: Element maps to a coded component (check with user)

**Key questions**:
1. **Component candidates**: "I found repeated elements: [list with recurrence count]. Which should become components?"
   - Show each candidate with recurrence count + proposed variants
   - Options: "Create all", "Select specific ones", "Let's discuss this"

2. **Variant properties**: For each approved component: "For [Button], I propose variants: Size (Small/Medium/Large), State (Default/Hover/Disabled). Confirm?"
   - Options: "Confirm", "Add more variants", "Simplify", "Let's discuss this"

3. **Codebase mapping**: "Does your codebase have corresponding components for [Button, Card, Header]?"
   - Options: "Yes, all match", "Some match (specify)", "No coded components yet", "Let's discuss this"

**Output**: Component targets with variant properties (e.g., "Create Button component: Size (SM/MD/LG), State (Default/Hover/Disabled/Loading), Type (Primary/Secondary/Ghost)")

---

## Category 7 — Naming Rules (Single Source of Truth)

**Purpose**: Define and persist naming conventions for frames, layers, and components.

**Key questions**:
1. **Check existing rules**: Search Figma Components section for "Naming Rules" text block.
   - If found: "I found existing naming rules: [summary]. Should I use these or update them?"
     - Options: "Use existing", "Update rules", "Let's discuss this"
   - If not found: "No naming rules found. Should I create a standard naming rules block?"
     - Options: "Yes, create standard", "I'll define custom rules", "Let's discuss this"

2. **Frame naming convention**: "For frames, I propose: [ScreenName]/[Section]/[Element]. Example: Dashboard/Header/Logo. Confirm?"
   - Options: "Confirm", "Show alternatives", "Let's discuss this"

3. **Component naming convention**: "For components, I propose: [ComponentType]/[Variant]. Example: Button/Primary. Confirm?"
   - Options: "Confirm", "Show alternatives", "Let's discuss this"

4. **Persist rules**: After approval: "I'll save these naming rules as a text block in Figma Components section. This becomes the single source of truth for future work. Confirm?"
   - Options: "Confirm", "Different location", "Let's discuss this"

**Output**: Naming rules reference (Figma text block location) + brief summary (e.g., "Naming rules at Components > Naming Rules text block: Frames use [Screen]/[Section]/[Element], Components use [Type]/[Variant]")

**Mode notes**: Critical for multi-screen consistency.

---

## Category 8 — Design Tokens & Colors

**Purpose**: Map hardcoded values to design tokens (colors, spacing, typography) and propose new tokens.

**Key questions**:
1. **Identify hardcoded values**: "I found [N] hardcoded colors, [M] spacing values, [P] typography styles. Should I map these to design tokens?"
   - Options: "Yes, map all", "Show me the list first", "Let's discuss this"

2. **Map to existing tokens**: "I can map [N] values to existing variables: [list]. Approve these mappings?"
   - Show: Hardcoded value → Existing variable
   - Options: "Approve all", "Review individually", "Let's discuss this"

3. **Create new tokens**: "I need to create [M] new variables for unmapped values: [list]. Approve these new tokens?"
   - Show: New variable name → Value → Usage count
   - Options: "Create all", "Review individually", "Let's discuss this"

4. **Color naming**: "For new color tokens, I propose semantic names (Primary/Secondary/Accent) or literal names (Blue-500/Gray-200)?"
   - Options: "Semantic", "Literal", "Mixed", "Let's discuss this"

**Output**: Token binding plan (e.g., "Bind 12 colors to existing tokens, create 3 new spacing tokens (Spacing/Card-Gap=16px, Spacing/Section-Gap=32px, Spacing/Page-Margin=48px)")

**Mode notes**: Critical for design system consistency.

---

## Category 9 — Interactions & Behaviors (mostly Restructure)

**Purpose**: Define prototype connections, overlays, and interactive behaviors.

**Key questions**:
1. **Identify interactive elements**: "I found [N] buttons, [M] links, [P] overlays. Should I add prototype connections for these?"
   - Options: "Yes, add interactions", "Show me the list first", "Skip interactions", "Let's discuss this"

2. **Interaction targets**: For each interactive element: "Button [Name] should navigate to [Screen/Overlay]. Confirm?"
   - Options: "Confirm", "Different target", "Let's discuss this"

3. **Overlay behaviors**: "For modals/overlays, I propose: Click outside to close, ESC key support. Confirm?"
   - Options: "Confirm", "Different behavior", "Let's discuss this"

**Output**: Interaction targets (e.g., "Add prototype: Login Button → Dashboard screen, Help icon → Help overlay (close on outside click)") OR "No interactions — static mockup"

**Mode notes**: Mostly Restructure mode (preserving/adding interactions). Optional for Create mode if user requests interactive prototype.

---

## Category 10 — Content & Interaction Specifications (optional)

**Purpose**: Capture content constraints, interaction behaviors, and edge case specifications that inform the Handoff Manifest.

**Key questions**:
1. **Character limits**: "Do any text fields have maximum character limits? What truncation strategy should be used (ellipsis, fade, wrap)?"
   - Options: "Yes, I'll provide limits", "Use current lengths as defaults", "Skip — not applicable", "Let's discuss this"

2. **Empty/loading/error states**: "Should I document empty states, loading states, and error states for interactive elements on this screen?"
   - Options: "Yes, document all", "Only error states", "Skip — handled in PRD", "Let's discuss this"

3. **i18n considerations**: "Will this design support multiple languages? If so, what's the expected maximum string expansion factor?"
   - Options: "1.5x expansion", "2x expansion", "Not applicable", "Let's discuss this"

4. **Interaction behaviors**: "Are there gesture interactions (long press, swipe, pinch), hover states, or focus behaviors beyond what's in the Figma prototype?"
   - Options: "Yes, I'll describe them", "No, prototype is complete", "Let's discuss this"

**Output**: Content and interaction specifications for the Handoff Manifest OR "Skipped — specifications handled elsewhere"

**Mode notes**: Optional for both modes. Most useful when preparing for code handoff. Populates the Interaction/Content/Edge Case sections of the Handoff Manifest (`workflow-code-handoff.md`).

---

## Checklist Compilation

After all applicable categories are completed, compile a user-approved checklist with numbered items across all categories.

**Format**:
```
User-Approved Design Checklist:
1. [Category 0] Use specs/dashboard-brief.md as reference
2. [Category 1] Screen purpose: User dashboard showing active projects
3. [Category 5] Apply auto-layout to 12 frames with 16px gaps
4. [Category 6] Create Button component with 3 size variants
5. [Category 7] Use naming rules at Components > Naming Rules
6. [Category 8] Bind 12 colors to existing tokens, create 3 spacing tokens
... (numbered items for all approved decisions)
```

**Present to user**: "Here's the complete design checklist based on our discussion. Please review and explicitly approve before I proceed to Phase 3 execution."

**Do NOT proceed to Phase 3 until user explicitly approves the checklist.**

---

## Cross-References

- **SKILL.md** (Flow 1 Phase 2 — dispatches this protocol)
- **recipes-restructuring.md** (Socratic question templates — detailed technical questions for Restructure mode)
- **flow-procedures.md** (Phase 3 execution steps that follow this protocol)
- **tool-playbook.md** (Tools used during Phase 3 execution: `figma_execute`, `figma_batch_create_variables`, etc.)
