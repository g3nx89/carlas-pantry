# Handoff Supplement — {{PRODUCT_NAME}}

**Figma file is the visual source of truth.**
This document covers ONLY behaviors, transitions, and logic not expressible in Figma.

| Field | Value |
|-------|-------|
| Screens | {{SCREEN_COUNT}} |
| Screens with supplements | {{SUPPLEMENT_COUNT}} |
| Date | {{DATE}} |
| Figma Page | {{PAGE_NAME}} |
| TIER | {{TIER_LEVEL}} |

---

## Cross-Screen Patterns

### Shared Behaviors

| Pattern | Screens | Description |
|---------|---------|-------------|
[Generated from cross-screen pattern extraction]

### Navigation Model

```mermaid
graph LR
[Generated navigation map — edges represent user-reachable transitions]
```

### Common Transitions

| Transition | Used Between | Type | Duration |
|------------|-------------|------|----------|
[Generated from pattern extraction — only transitions shared by 2+ screens]

---

## Per-Screen Supplements

[Per-screen sections inserted here using handoff-screen-template.md.
 Screens are ordered by Figma page position (top-left to bottom-right).
 Screens with ZERO gaps are listed with "No supplement needed" one-liner.
 Screens WITH gaps include full section from handoff-screen-template.md.]

---

## Missing Screens (Documented Only)

[Screens that should exist but are not in Figma.
 Only present if Stage 3 detected items classified as "supplement only" (option C).
 Omit this entire section if no missing screens were documented.]

### {{MISSING_SCREEN_NAME}} (not in Figma)

**Reason:** {{REASON}}
**Description:** {{DESCRIPTION}}

| Element | Behavior | Notes |
|---------|----------|-------|
| {{ELEMENT}} | {{BEHAVIOR}} | {{NOTES}} |

---

## Appendix: Glossary

| Term | Meaning |
|------|---------|
[Optional — include only if domain-specific terms appear in supplement.
 Non-technical users reviewing this document benefit from definitions.]

---

## Appendix: Gap Classification Key

| Tag | Meaning |
|-----|---------|
| CRITICAL | Blocks implementation — coding agent cannot proceed without this information |
| IMPORTANT | Improves quality — coding agent can approximate but result may be suboptimal |
| NICE_TO_HAVE | Polish item — coding agent can skip without functional impact |

---

<!-- Generation metadata (do not edit)
  Skill: design-handoff
  Template: handoff-supplement-template.md
  Config: handoff-config.yaml
-->
