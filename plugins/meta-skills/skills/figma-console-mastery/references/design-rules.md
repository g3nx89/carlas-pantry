# Design Rules — Making Design Decisions

> **Compatibility**: Verified against Figma Plugin API and Material Design 3 (February 2026)

This reference consolidates mandatory rules, recommended practices, anti-patterns, standard dimensions, typography scales, and QA checklists for making design decisions when creating or modifying Figma designs programmatically.

> For working code implementing M3 components, see `recipes-components.md` and `recipes-m3.md`.
> For Plugin API code patterns, see `plugin-api.md`.

---

## MUST Rules (Mandatory)

| # | Rule | Motivation |
|---|------|------------|
| 1 | **MUST** load fonts before any text operation | `Cannot write to node with unloaded font` error. Even setting `characters` on the default Inter font requires loading it first. |
| 2 | **MUST** set `layoutMode` before any auto-layout properties | Padding, spacing, sizing modes, alignment all throw or are ignored when `layoutMode = 'NONE'`. |
| 3 | **MUST** clone fills/strokes/effects before modifying | These are read-only frozen arrays. Direct mutation throws `Cannot assign to read only property`. |
| 4 | **MUST** use auto-layout for every frame containing UI elements | Ensures designs reflow properly, are developer-friendly, and maintain consistent spacing. |
| 5 | **MUST** use 4px spacing scale (4, 8, 12, 16, 20, 24, 32, 40, 48, 64) | Prevents subpixel rendering issues and ensures consistent visual rhythm across all elements. |
| 6 | **MUST** name every layer with semantic names | Default names like "Frame 1" are useless for dev handoff and design maintenance. Use "Header", "Card/Body", "Button/Primary". |
| 7 | **MUST** use fills as arrays | `node.fills = [paint]` not `node.fills = paint`. Figma always expects an array, even for single fills. |
| 8 | **MUST** await all async operations | `loadFontAsync`, `exportAsync`, `getNodeByIdAsync` return Promises. Unawaited promises cause silent failures or race conditions. |
| 9 | **MUST** meet minimum text sizes | Body >= 14px (recommended 16px), caption >= 12px. Below these thresholds text is illegible. |
| 10 | **MUST** meet WCAG AA contrast | Normal text: 4.5:1 ratio. Large text (>=24px or >=18.5px bold): 3:1. UI components: 3:1. |

## SHOULD Rules (Recommended)

| # | Rule | Motivation |
|---|------|------------|
| 1 | **SHOULD** use `layoutSizingHorizontal`/`Vertical` shorthand | Cleaner than manually managing `layoutGrow`, `layoutAlign`, `primaryAxisSizingMode`, `counterAxisSizingMode`. |
| 2 | **SHOULD** use variables/tokens for colors and spacing | Enables theming, mode switching (light/dark), and consistent design system enforcement. |
| 3 | **SHOULD** use `figma.util.solidPaint()` for colors | Accepts CSS hex strings like `"#FF00FF88"` with alpha. Cleaner than manual paint construction. |
| 4 | **SHOULD** search for existing components before creating from scratch | Prevents duplicates. Use `figma.currentPage.findAll()` or check component libraries. |
| 5 | **SHOULD** use slash naming convention | `Button/Primary/Large`, `Icon/Navigation/Home`. Creates hierarchical organization in assets panel. |
| 6 | **SHOULD** set `textAutoResize` for dynamic text | `'WIDTH_AND_HEIGHT'` or `'HEIGHT'` prevents text from being clipped when content changes. |
| 7 | **SHOULD** validate with screenshot after every significant creation | Agents operate blind --- screenshots are the only verification mechanism. |
| 8 | **SHOULD** load all fonts upfront with `Promise.all()` | More efficient than sequential loads. Cached, so re-loading is free. |
| 9 | **SHOULD** use consistent border radius from a scale | Pick from: 0, 2, 4, 6, 8, 12, 16, 24, 9999px (full round). |
| 10 | **SHOULD** follow internal <= external spacing | Spacing within a group < spacing between groups. E.g., card padding 16px, gap between cards 24px. |

## AVOID Rules (Anti-Patterns)

| # | Anti-Pattern | Why Harmful |
|---|-------------|-------------|
| 1 | **AVOID** frames without auto-layout for UI | Creates brittle, non-reflowing layouts that break on content changes. |
| 2 | **AVOID** hardcoded colors when design system variables exist | Prevents theming, makes bulk color changes impossible. |
| 3 | **AVOID** non-4px-multiple spacing (5px, 7px, 13px, etc.) | Causes subpixel rendering, visual inconsistency, developer confusion. |
| 4 | **AVOID** generic layer names ("Frame 1", "Rectangle 5") | Useless for dev handoff, maintenance, and component search. |
| 5 | **AVOID** creating duplicate components | Check for existing components first. Duplicates fragment the design system. |
| 6 | **AVOID** fixed width/height when hug-contents or fill-container fits | Rigid sizing breaks when content changes. Use HUG for dynamic content, FILL for responsive layouts. |
| 7 | **AVOID** mutating node arrays directly | `node.fills[0].color.r = 0.5` throws. Always clone, modify, then reassign. |
| 8 | **AVOID** setting `layoutAlign='STRETCH'` with `sizingMode='AUTO'` | Contradictory: frame cannot hug children AND have a child stretching to fill it. |
| 9 | **AVOID** toggling layoutMode on/off expecting restoration | Auto-layout repositions children irreversibly. Removing it leaves children in new positions. |
| 10 | **AVOID** text smaller than 12px | Fails accessibility standards and is illegible for most users. |

---

## Standard Reference Dimensions

### Buttons

| Size | Height | H-Padding | Font Size | Icon Size | Min Width | Corner Radius |
|------|--------|-----------|-----------|-----------|-----------|---------------|
| Small | 32px | 12px | 13-14px | 16px | 64px | 4-6px |
| Medium | 40px | 16px | 14px | 16-20px | 80px | 6-8px |
| Large | 48px | 24px | 16px | 20px | 96px | 8px |

### Input Fields

| Size | Height | H-Padding | Font Size | Border Radius | Border Width |
|------|--------|-----------|-----------|---------------|-------------|
| Small | 32px | 12px | 14px | 4-6px | 1px |
| Medium | 40px | 12px | 14-16px | 6-8px | 1px |
| Large | 48px | 16px | 16px | 8px | 1px |

### Cards

| Property | Value |
|----------|-------|
| Padding | 16-24px |
| Border radius | 8-12px |
| Shadow | `0 1px 3px rgba(0,0,0,0.12)`, `0 1px 2px rgba(0,0,0,0.08)` |
| Gap between cards | 16-24px |
| Min width | 280px |

### Modals

| Size | Width | Max Height | Padding |
|------|-------|------------|---------|
| Small | 400px | 480px | 24px |
| Medium | 560px | 560px | 24px |
| Large | 800px | 600px | 24-32px |

### Navigation

| Component | Height |
|-----------|--------|
| Top navbar (desktop) | 56-64px |
| Top navbar (mobile) | 44-56px |
| Bottom tab bar (mobile) | 48-56px |
| Sidebar width | 240-280px |
| Sidebar collapsed | 56-72px |

### Icons

| Context | Size |
|---------|------|
| Inline/small | 16px |
| Default UI | 20px |
| Standard | 24px |
| Large/feature | 32px |
| Touch target min | 44px container |

### Responsive Breakpoints

| Device | Frame Width | Columns | Gutter | Margin |
|--------|-------------|---------|--------|--------|
| Mobile Small | 320px | 4 | 16px | 16px |
| Mobile | 375px | 4 | 16px | 16-20px |
| Mobile Large | 428px | 4 | 16px | 16-24px |
| Tablet | 768px | 8 | 24px | 24-32px |
| Desktop Small | 1024px | 12 | 24px | 32px |
| Desktop | 1280px | 12 | 24px | 32-64px |
| Desktop Large | 1440px | 12 | 24-32px | 64-120px |

---

## Typography Scale

| Role | Size | Weight | Line Height | Letter Spacing |
|------|------|--------|-------------|----------------|
| Display / Hero | 48-60px | Bold (700) | 56-68px (1.15x) | -0.5 to -1px |
| H1 | 36-40px | Bold (700) | 44-48px (1.2x) | -0.5px |
| H2 | 28-32px | Semibold (600) | 36-40px (1.25x) | -0.25px |
| H3 | 24px | Semibold (600) | 32px (1.33x) | 0 |
| H4 | 20px | Medium (500) | 28px (1.4x) | 0 |
| H5 / Subtitle | 18px | Medium (500) | 24px (1.33x) | 0 |
| Body Large | 18px | Regular (400) | 28px (1.55x) | 0 |
| Body (default) | 16px | Regular (400) | 24px (1.5x) | 0 |
| Body Small | 14px | Regular (400) | 20px (1.43x) | 0 |
| Caption | 12px | Regular (400) | 16px (1.33x) | 0.25px |
| Overline / Label | 12px | Medium (500) | 16px (1.33x) | 0.5-1px |
| Button text | 14-16px | Medium (500-600) | 20-24px | 0.25px |

---

## Spacing Scale Quick Reference

| Value | Context |
|-------|---------|
| 4px | Tight: icon-to-text, tag padding |
| 8px | Compact: related inline items, small gaps |
| 12px | Default small: form label to field, compact card padding |
| 16px | Standard: card padding, section gaps, standard component gap |
| 20px | Medium: comfortable spacing between groups |
| 24px | Generous: section padding, modal padding, card padding (large) |
| 32px | Section: between major content sections |
| 40px | Large section gaps |
| 48px | Page-level spacing |
| 64px | Hero/display spacing |

---

## Material Design 3 Specifications

### M3 Typography Scale (Roboto)

| Token | Size | Line Height | Weight | Letter Spacing |
|-------|------|-------------|--------|----------------|
| Display Large | 57px | 64px | 400 | -0.25px |
| Display Medium | 45px | 52px | 400 | 0px |
| Display Small | 36px | 44px | 400 | 0px |
| Headline Large | 32px | 40px | 400 | 0px |
| Headline Medium | 28px | 36px | 400 | 0px |
| Headline Small | 24px | 32px | 400 | 0px |
| Title Large | 22px | 28px | 400 | 0px |
| Title Medium | 16px | 24px | 500 | 0.15px |
| Title Small | 14px | 20px | 500 | 0.1px |
| Body Large | 16px | 24px | 400 | 0.5px |
| Body Medium | 14px | 20px | 400 | 0.25px |
| Body Small | 12px | 16px | 400 | 0.4px |
| Label Large | 14px | 20px | 500 | 0.1px |
| Label Medium | 12px | 16px | 500 | 0.5px |
| Label Small | 11px | 16px | 500 | 0.5px |

### M3 Color Tokens --- Light Theme Baseline

| Token | Hex | Figma RGB (0-1) |
|-------|-----|-----------------|
| **Primary** | #6750A4 | (0.404, 0.314, 0.643) |
| On Primary | #FFFFFF | (1, 1, 1) |
| Primary Container | #EADDFF | (0.918, 0.867, 1) |
| **Secondary** | #625B71 | (0.384, 0.357, 0.443) |
| Secondary Container | #E8DEF8 | (0.910, 0.871, 0.973) |
| **Tertiary** | #7D5260 | (0.490, 0.322, 0.376) |
| **Error** | #B3261E | (0.702, 0.149, 0.118) |
| **Surface** | #FFFBFE | (1, 0.984, 0.996) |
| On Surface | #1C1B1F | (0.110, 0.106, 0.122) |
| Outline | #79747E | (0.475, 0.455, 0.494) |
| Surface Container | #F3EDF7 | (0.953, 0.929, 0.969) |
| Surface Container High | #ECE6F0 | (0.925, 0.902, 0.941) |
| Surface Container Low | #F7F2FA | (0.969, 0.949, 0.980) |
| On Surface Variant | #49454F | (0.286, 0.271, 0.310) |
| Inverse Surface | #313033 | (0.192, 0.188, 0.200) |
| Inverse On Surface | #F4EFF4 | (0.957, 0.937, 0.957) |
| Inverse Primary | #D0BCFF | (0.816, 0.737, 1.0) |

### M3 Button Specifications

All common buttons share: **height 40px**, **corner radius 20px** (full-round), **Label Large typography** (Roboto Medium 14px), **horizontal padding 24px** (16px on icon side if icon present), **icon size 18px**, **icon-label gap 8px**.

| Variant | Container | Label Color | Extra |
|---------|-----------|-------------|-------|
| **Filled** | Primary (#6750A4) | On Primary (white) | Elevation Level 0 |
| **Outlined** | Transparent | Primary | 1px outline = Outline (#79747E), Level 0 |
| **Text** | Transparent | Primary | 12px horizontal padding (reduced), no border |
| **Elevated** | Surface Container Low (#F7F2FA) | Primary | Level 1 shadow |
| **Tonal** | Secondary Container (#E8DEF8) | On Secondary Container (#1D192B) | Level 0 |
| **FAB** | 56x56px, radius 16px, icon 24px | --- | Small 40x40px; Large 96x96px |

### M3 Component Dimensions

| Component | Key Specs |
|-----------|-----------|
| **TextField** (filled/outlined) | Height 56px, corner radius 4px (top only for filled), padding 16px, body text 16px, label 12px focused |
| **Card** (all variants) | Corner radius 12px, padding 16px typical; outlined = 1px Outline Variant (#CAC4D0) |
| **Dialog** | Min 280px / max 560px width, corner radius 28px, padding 24px, Level 3 elevation (6dp) |
| **Snackbar** | Height 48-68px, corner radius 4px, container = Inverse Surface (#313033), Level 3 |
| **Top App Bar** | Small: 64px height, 16px padding, title = Title Large (22px) |
| **Bottom Navigation** | Height 80px, icon 24px, active indicator 64x32px pill (#E8DEF8), label = Label Medium (12px) |
| **Navigation Drawer** | Width 360px (modal) / 256px, item height 56px, item radius 28px |
| **Navigation Rail** | Width 80px, icon 24px, active indicator 56x32px pill |

### M3 Spacing System

M3 uses a **4px base grid**: 4, 8, 12, 16, 20, 24, 32, 40, 48, 56, 64px. Component internal padding is typically **16px or 24px**. Between related elements: **8px**. Between sections: **24-32px**.

### M3 Elevation Levels

| Level | Shadow Approximation |
|-------|---------------------|
| 0 | None |
| 1 (1dp) | `offset: {x:0, y:1}, radius: 3, color: rgba(0,0,0,0.3)` + `offset: {x:0, y:1}, radius: 3, spread: 1, color: rgba(0,0,0,0.15)` |
| 2 (3dp) | `offset: {x:0, y:1}, radius: 2, color: rgba(0,0,0,0.3)` + `offset: {x:0, y:2}, radius: 6, spread: 2, color: rgba(0,0,0,0.15)` |
| 3 (6dp) | `offset: {x:0, y:1}, radius: 3, color: rgba(0,0,0,0.3)` + `offset: {x:0, y:4}, radius: 8, spread: 3, color: rgba(0,0,0,0.15)` |

---

## QA Checklist

### Spacing and Grid

- [ ] All spacing values are multiples of 4px
- [ ] Padding uses consistent scale (8, 12, 16, 24, 32px)
- [ ] Internal spacing <= external spacing (Gestalt proximity)
- [ ] Item spacing between siblings is consistent within containers
- [ ] No orphaned 1px or 2px gaps (except intentional borders)

### Alignment

- [ ] All elements align to the 4px/8px grid
- [ ] Frame positions use whole pixel values (no fractional x/y)
- [ ] Text and elements consistently aligned (left, center, or right --- not mixed without intent)

### Typography

- [ ] Body text >= 14px (recommended >= 16px)
- [ ] Caption text >= 12px
- [ ] Line heights are multiples of 4px
- [ ] Line height ratio: body 1.4-1.6x, headings 1.1-1.3x
- [ ] No more than 3-4 font sizes per view
- [ ] Consistent font weights across same hierarchy levels

### Visual Hierarchy

- [ ] Primary action button is visually dominant
- [ ] Heading sizes decrease monotonically (H1 > H2 > H3)
- [ ] Only one primary CTA per view/section
- [ ] Content groups visually separated by spacing or dividers

### Accessibility and Contrast

- [ ] Text contrast ratio >= 4.5:1 (normal text)
- [ ] Large text contrast ratio >= 3:1 (>=24px or >=18.5px bold)
- [ ] UI component contrast >= 3:1 against adjacent colors
- [ ] All interactive elements have >= 44x44px touch targets
- [ ] Spacing between touch targets >= 8px

### Layer Quality

- [ ] No default names ("Frame 1", "Rectangle 5")
- [ ] Semantic layer names ("Header", "Card/Body", "Nav/Item")
- [ ] Slash convention for component hierarchy
- [ ] Consistent naming pattern across similar elements
