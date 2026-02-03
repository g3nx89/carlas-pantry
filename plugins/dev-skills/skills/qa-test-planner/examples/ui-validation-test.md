# TC-UI-045: Primary Button Visual Validation

**Priority:** P1 (High)
**Type:** UI/Visual
**Status:** Not Run
**Figma Design:** https://figma.com/file/abc123/Design-System?node-id=123:456
**Breakpoints:** Desktop, Tablet, Mobile

---

## Objective

Verify the primary button component matches Figma design specifications across all states and responsive breakpoints.

---

## Preconditions

- [ ] Access to Figma design file
- [ ] Browser DevTools available
- [ ] Color picker extension installed
- [ ] Test page with primary button component loaded

---

## Design Specifications (from Figma)

### Layout

| Property | Value |
|----------|-------|
| Min Width | 120px |
| Height | 40px |
| Padding | 12px 24px |
| Border Radius | 8px |

### Typography

| Property | Value |
|----------|-------|
| Font Family | Inter |
| Font Size | 16px |
| Font Weight | 600 (Semi-bold) |
| Line Height | 24px |
| Text Transform | None |

### Colors - Default State

| Element | Hex Value |
|---------|-----------|
| Background | #0066FF |
| Text | #FFFFFF |
| Border | None |

### Interactive States

| State | Background | Text | Additional |
|-------|------------|------|------------|
| Default | #0066FF | #FFFFFF | - |
| Hover | #0052CC | #FFFFFF | cursor: pointer |
| Active/Pressed | #003D99 | #FFFFFF | - |
| Focus | #0066FF | #FFFFFF | 2px outline #0066FF offset 2px |
| Disabled | #E0E0E0 | #9E9E9E | cursor: not-allowed |

---

## Test Steps

### Desktop Validation (1920x1080)

1. **Inspect button dimensions**
   - Open DevTools → Select primary button
   - **Expected:** Width ≥ 120px, Height = 40px

2. **Verify padding**
   - Check computed styles
   - **Expected:** padding: 12px 24px

3. **Check background color**
   - Use color picker on button background
   - **Expected:** #0066FF (exact match)

4. **Validate typography**
   - Check computed font styles
   - **Expected:** Inter, 16px, 600 weight, #FFFFFF

5. **Test hover state**
   - Hover mouse over button
   - **Expected:** Background changes to #0052CC smoothly

6. **Test active state**
   - Click and hold button
   - **Expected:** Background changes to #003D99

7. **Test focus state**
   - Tab to button using keyboard
   - **Expected:** 2px outline visible, #0066FF color

8. **Test disabled state**
   - Locate disabled variant
   - **Expected:** Background #E0E0E0, text #9E9E9E, cursor not-allowed

---

## Validation Checklist

### Layout
- [ ] Min width: 120px
- [ ] Height: 40px
- [ ] Padding: 12px 24px
- [ ] Border radius: 8px

### Typography
- [ ] Font: Inter
- [ ] Size: 16px
- [ ] Weight: 600
- [ ] Line-height: 24px
- [ ] Color: #FFFFFF

### Colors
- [ ] Default background: #0066FF
- [ ] Hover background: #0052CC
- [ ] Active background: #003D99
- [ ] Disabled background: #E0E0E0
- [ ] Disabled text: #9E9E9E

### States
- [ ] Hover transition smooth
- [ ] Focus ring visible on keyboard nav
- [ ] Disabled state prevents interaction

### Responsive
- [ ] Desktop (1920px): Full size
- [ ] Tablet (768px): Full width on mobile nav
- [ ] Mobile (375px): Full width, adequate touch target (≥44px)

---

## Discrepancy Log

| Property | Expected (Figma) | Actual | Match | Bug ID |
|----------|------------------|--------|-------|--------|
| Background | #0066FF | | [ ] | |
| Font Weight | 600 | | [ ] | |
| Padding | 12px 24px | | [ ] | |
| Hover Color | #0052CC | | [ ] | |
| Border Radius | 8px | | [ ] | |

---

## Related Test Cases

- TC-UI-046: Secondary button validation
- TC-UI-047: Tertiary/ghost button validation
- TC-UI-048: Icon button validation
- TC-UI-050: Button group spacing

---

## Notes

- Use browser's color picker for exact hex comparison
- Check both light and dark theme if applicable
- Verify button text doesn't overflow on different languages
- Test with screen reader for accessibility compliance
