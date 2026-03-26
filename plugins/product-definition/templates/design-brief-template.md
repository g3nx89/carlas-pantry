# Design Brief: {Feature Name}

> **Generated**: {ISO_DATE}
> **Feature ID**: {FEATURE_ID}
> **Specification**: {SPEC_FILE}
> **Platform**: {PLATFORM_TYPE}
> **Status**: 🎨 Ready for Design

---

## Executive Summary

{2-3 sentence overview of the feature from the user's perspective. Focus on the primary user goal and the value this feature provides.}

**Target Platform**: {Mobile (Android/iOS) | Web | Cross-platform}
**Key User Goal**: {The primary thing the user wants to accomplish with this feature}
**Complexity**: {Low | Medium | High} - {N} screens, {M} states

---

## Screen Inventory

### Overview

| Metric | Count |
|--------|-------|
| Total Screens | {N} |
| Total States Required | {M} |
| High Priority Screens | {list top 3} |
| Dialogs/Overlays | {count} |

### Derivation Rationale

How screens were derived from requirements:

| Screen ID | Screen Name | Derived From | Reasoning |
|-----------|-------------|--------------|-----------|
| SCR-001 | {name} | {US-XXX or requirement} | {Why this screen is needed} |
| SCR-002 | {name} | {US-XXX or requirement} | {Why this screen is needed} |

---

## Screen Details

### SCR-001: {Screen Name}

| Property | Value |
|----------|-------|
| **Type** | {Full Screen / Bottom Sheet / Dialog / Overlay} |
| **Description** | {What this screen does and why it exists} |
| **Entry Points** | {How user gets here: navigation, deep link, notification, etc.} |
| **Key Actions** | {What user can do on this screen} |
| **Exit Points** | {Where user can go next from this screen} |
| **Priority** | {P1 / P2 / P3} |

**State Requirements:**

| State | Required | Trigger Condition | Design Notes |
|-------|----------|-------------------|--------------|
| Default | ✅ | Normal loaded state | Show populated content |
| Loading | {✅/⚪} | {When this state appears} | {Skeleton, spinner, etc.} |
| Empty | {✅/⚪} | {When this state appears} | {Empty state illustration, CTA} |
| Error | {✅/⚪} | {Error scenarios} | {Error message, retry action} |
| Offline | {✅/⚪} | {No network condition} | {Cached data, offline banner} |
| Permission Denied | {✅/⚪} | {Missing permission} | {Rationale, settings link} |

**Accessibility Considerations:**
- {Specific accessibility note for this screen}

**Edge Cases:**
- {Specific edge case for this screen}

---

### SCR-002: {Screen Name}

{Repeat the above structure for each screen}

---

## State Matrix (Quick Reference)

| Screen | Default | Loading | Empty | Error | Offline | Permission |
|--------|:-------:|:-------:|:-----:|:-----:|:-------:|:----------:|
| SCR-001 {name} | ✅ | ✅ | ✅ | ✅ | ⚪ | ⚪ |
| SCR-002 {name} | ✅ | ✅ | ⚪ | ✅ | ✅ | ⚪ |
| SCR-003 {name} | ✅ | ⚪ | ⚪ | ✅ | ⚪ | ✅ |

**Legend:**
- ✅ = Required (must be designed)
- ⚪ = Not Applicable
- ⚠️ = Optional (nice to have)

**State Reasoning:**

| Screen | State | Reasoning |
|--------|-------|-----------|
| SCR-001 | Loading | Fetches data from API on each visit |
| SCR-001 | Empty | User may have no items (first-time user scenario) |
| SCR-002 | Offline | Data is cached locally, can show stale with refresh option |

---

## User Journeys

### Journey 1: {Primary Journey Name}

**Goal**: {What the user is trying to accomplish}
**Entry Point**: {Where this journey starts}
**Success Criteria**: {How we know the journey succeeded}

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Entry     │────▶│   Action    │────▶│   Success   │
│  (SCR-001)  │     │  (SCR-002)  │     │  (SCR-003)  │
└─────────────┘     └──────┬──────┘     └─────────────┘
                          │
                          ▼ (on error)
                   ┌─────────────┐
                   │   Error     │
                   │   State     │
                   └──────┬──────┘
                          │
                          ▼ (retry)
                   ┌─────────────┐
                   │   Action    │
                   │  (SCR-002)  │
                   └─────────────┘
```

**Step-by-Step Flow:**

| Step | Screen | User Action | System Response | Next Screen |
|------|--------|-------------|-----------------|-------------|
| 1 | SCR-001 | {action} | {response} | SCR-002 |
| 2 | SCR-002 | {action} | {response} | SCR-003 |
| 3 | SCR-003 | {action} | {response} | End |

**Error Paths:**
- If {error condition}: Show {error state} with {recovery action}

---

### Journey 2: {Secondary Journey Name}

{Repeat journey structure}

---

## Edge Cases & Interruptions

### Interruption Handling

| Scenario | Expected Behavior | Screens Affected | Design Consideration |
|----------|-------------------|------------------|---------------------|
| App backgrounded | {Preserve state / Save draft / Pause operation} | {list} | {What to show on return} |
| Incoming call | {Pause / Continue in background} | {list} | {State preservation UI} |
| Orientation change | {Portrait only / Both / Lock} | {list} | {Responsive layout needs} |
| Low memory warning | {Save state / Graceful degradation} | {list} | {Minimal memory UI} |
| System back gesture | {Navigate back / Confirm exit / Discard changes} | {list} | {Confirmation dialog?} |

### Platform-Specific Considerations

**Android:**
- Back button/gesture behavior per screen
- Split-screen/multi-window support
- Foldable device considerations
- Widget integration (if applicable)

**iOS (if applicable):**
- Swipe-to-go-back gesture
- Home indicator area
- Dynamic Island interactions (if applicable)

---

## Accessibility Requirements

### Global Requirements

| Requirement | Standard | Notes |
|-------------|----------|-------|
| Touch Targets | Minimum 48dp × 48dp | All interactive elements |
| Color Contrast | WCAG AA (4.5:1 text, 3:1 graphics) | Use contrast checker |
| Screen Reader | All elements must have content descriptions | Test with TalkBack/VoiceOver |
| Font Scaling | Support 100% to 200% system font | Test layouts at max scale |
| Motion | Respect "Reduce Motion" setting | Provide static alternatives |

### Screen-Specific Accessibility

| Screen | Key Accessibility Considerations |
|--------|----------------------------------|
| SCR-001 | {Specific considerations} |
| SCR-002 | {Specific considerations} |

---

## Clarified Decisions

These decisions were made during the specification phase and should inform design choices:

| Decision Area | Question Asked | Resolution | Design Implication |
|---------------|----------------|------------|-------------------|
| {topic} | {original question} | {user's answer} | {how this affects design} |
| {topic} | {original question} | {user's answer} | {how this affects design} |

### AI-Inferred Decisions

The following decisions were made by the system based on best practices. Please review and confirm:

| Decision | Inference | Rationale | Confirm/Override |
|----------|-----------|-----------|------------------|
| {topic} | {inferred answer} | {why this was chosen} | ☐ Confirmed / ☐ Override: ___ |

---

## Open Questions for Design Team

The following questions emerged during specification and require designer input before finalizing:

### High Priority

- [ ] **{Question 1}**
  - Context: {Why this question matters}
  - Options considered: {A, B, C}
  - Recommendation: {If any}

- [ ] **{Question 2}**
  - Context: {Why this question matters}

### Medium Priority

- [ ] **{Question 3}**
  - Context: {Why this question matters}

---

## Design System Alignment

### Recommended Components

Based on the screen inventory, these design system components are likely needed:

| Component | Usage | Screens |
|-----------|-------|---------|
| {Component name} | {How it's used} | {Where it appears} |
| {Component name} | {How it's used} | {Where it appears} |

### New Components Needed

If the design system doesn't have these, they may need to be created:

| Component | Description | Priority |
|-----------|-------------|----------|
| {Component name} | {What it does} | {P1/P2/P3} |

---

## Reference Links

| Resource | Link |
|----------|------|
| Feature Specification | `{SPEC_FILE}` |
| Quality Checklist | `{CHECKLIST_FILE}` |
| Related Figma (when available) | {Link or "To be created"} |
| Design System | {Link to design system} |
| Brand Guidelines | {Link if applicable} |

---

## Next Steps

### For Design Team

1. 📋 **Review** this brief with product/engineering
2. 🎨 **Create** screens for each item in Screen Inventory
3. 🔄 **Design** all required states (Loading, Empty, Error)
4. ♿ **Validate** accessibility requirements
5. 💬 **Answer** open questions in this document
6. ✅ **Mark** screens complete as Figma frames are created

### For Engineering Team

1. ⏳ **Wait** for design completion
2. 🔗 **Re-run** `/product-definition:specify --figma` to capture designs
3. 📐 **Proceed** to `/sdd:plan` for architecture planning

---

## Completion Tracking

| Screen | Design Started | Design Complete | Figma Link |
|--------|:--------------:|:---------------:|------------|
| SCR-001 | ☐ | ☐ | |
| SCR-002 | ☐ | ☐ | |
| SCR-003 | ☐ | ☐ | |

**Overall Progress**: 0/{N} screens complete

---

*Generated by `/product-definition:specify` • Design Brief Mode*
*Analysis Method: Sequential Thinking ({THINKING_STEPS} steps)*
