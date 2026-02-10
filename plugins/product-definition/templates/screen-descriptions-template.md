# Screen Descriptions — {PRODUCT_NAME}

> **Author:** {AUTHOR_NAME}
> **Date:** {DATE}
> **Screen count:** {N}
>
> This document provides textual descriptions for each screen to supplement Figma mockups.
> The design-narration skill uses these descriptions alongside Figma Desktop data to generate
> UX narratives. Screen names should match Figma frame names for automatic matching.

---

## How to Use This Template

1. Copy this template to your working directory (e.g., `design-narration/screen-descriptions.md`)
2. Add one `## Screen: {NAME}` section per screen
3. Fill in at least the **Required** fields for each screen
4. Screen names should match your Figma frame names exactly (case-insensitive matching is applied for minor differences)
5. Run `/narrate --batch` — the system will match these descriptions to Figma frames

### Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| **Purpose** | Yes | What this screen is for — the user goal it serves |
| **Elements** | Yes | Key interactive and content elements visible on screen |
| **Primary Actions** | Yes | What the user can do here — main tap/swipe/input actions |
| **Navigation** | Yes | How the user arrives and where they go next |
| **States** | No | Different visual states (empty, loading, error, success) |
| **Notes** | No | Constraints, business rules, or design rationale |

---

## Screen: {SCREEN_NAME_1}

**Purpose:**
{What this screen is for — the user goal it serves.}

**Elements:**
- {Element 1 — e.g., "Search bar at top with placeholder 'Search recipes...'"}
- {Element 2 — e.g., "Category filter chips: All, Breakfast, Lunch, Dinner, Snacks"}
- {Element 3 — e.g., "Recipe cards grid (2 columns) showing image, title, cook time, rating"}

**Primary Actions:**
- {Action 1 — e.g., "Tap recipe card → navigates to recipe detail"}
- {Action 2 — e.g., "Tap search bar → opens search with keyboard"}
- {Action 3 — e.g., "Tap filter chip → filters grid to that category"}

**Navigation:**
- **Arrives from:** {e.g., "App launch (default tab), or tab bar from any screen"}
- **Goes to:** {e.g., "Recipe Detail (tap card), Search Results (submit search), Profile (tab bar)"}

**States:**
- {State 1 — e.g., "Empty: 'No recipes found' illustration when filter returns zero results"}
- {State 2 — e.g., "Loading: Skeleton cards while recipes load"}

**Notes:**
- {Note 1 — e.g., "Recipe cards should show cached data if offline"}
- {Note 2 — e.g., "Max 20 recipes per page with infinite scroll"}

---

## Screen: {SCREEN_NAME_2}

**Purpose:**
{What this screen is for.}

**Elements:**
- {Element 1}
- {Element 2}

**Primary Actions:**
- {Action 1}
- {Action 2}

**Navigation:**
- **Arrives from:** {source screens}
- **Goes to:** {destination screens}

**States:**
- {State 1}

**Notes:**
- {Note 1}

---

<!-- Copy the section above for each additional screen. -->
<!-- Delete this comment and unused template sections before submitting. -->
