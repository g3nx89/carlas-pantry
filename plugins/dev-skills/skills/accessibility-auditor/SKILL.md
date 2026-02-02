---
name: accessibility-auditor
description: This skill should be used when the user asks to "audit accessibility", "check WCAG compliance", "fix accessibility issues", "add ARIA attributes", "test with screen readers", "make this accessible", "ensure ADA compliance", or needs guidance on semantic HTML, keyboard navigation, color contrast, and assistive technology compatibility.
allowed-tools: Read, Glob, Grep
---

# Accessibility Auditor

Create accessible web experiences that comply with WCAG standards and serve users of all abilities.

## WCAG 2.1 Principles (POUR)

| Principle | Meaning | Key Focus |
|-----------|---------|-----------|
| **Perceivable** | Users can perceive information | Alt text, contrast, captions |
| **Operable** | Users can operate the interface | Keyboard, timing, navigation |
| **Understandable** | Users can understand content | Readable, predictable, errors |
| **Robust** | Works with assistive tech | Valid HTML, ARIA support |

## Quick Audit Checklist

### Critical (Fix First)

- [ ] Images have meaningful alt text (or `alt=""` for decorative)
- [ ] Color contrast >= 4.5:1 for text, >= 3:1 for large text
- [ ] All interactive elements keyboard accessible
- [ ] Form fields have visible labels
- [ ] Page has proper heading hierarchy (h1 -> h2 -> h3)
- [ ] Focus indicators visible

### Important

- [ ] Skip link to main content
- [ ] ARIA landmarks (`<main>`, `<nav>`, `<header>`, `<footer>`)
- [ ] Error messages announced to screen readers
- [ ] Modals trap and restore focus
- [ ] No content flashes more than 3 times/second

## Common Issues Quick Reference

| Issue | Fix |
|-------|-----|
| Missing alt text | Add descriptive alt, or `alt=""` for decorative |
| Low contrast | Increase to 4.5:1 minimum |
| Clickable div | Use `<button>` or add `role="button"` + `tabindex="0"` |
| Missing label | Add `<label for="id">` or `aria-label` |
| Non-semantic HTML | Use `<button>`, `<nav>`, `<main>`, `<h1>-<h6>` |
| No focus indicator | Add `:focus { outline: 2px solid }` |

## Semantic HTML Priority

Always prefer native HTML over ARIA:

```html
<!-- GOOD: Native HTML -->
<button>Submit</button>
<nav>...</nav>
<main>...</main>

<!-- AVOID: ARIA on divs -->
<div role="button" tabindex="0">Submit</div>
<div role="navigation">...</div>
<div role="main">...</div>
```

## Keyboard Navigation Requirements

| Element | Expected Behavior |
|---------|-------------------|
| Links/Buttons | Tab to focus, Enter to activate |
| Checkboxes | Tab to focus, Space to toggle |
| Radio buttons | Tab to group, Arrow keys to select |
| Menus | Tab to open, Arrow keys to navigate, Escape to close |
| Modals | Focus trapped inside, Escape to close |

## Testing Quick Start

1. **Keyboard test**: Unplug mouse, navigate with Tab/Enter/Escape
2. **Screen reader test**: Enable VoiceOver (Cmd+F5 on Mac) or NVDA (Windows)
3. **Automated scan**: Run axe DevTools browser extension
4. **Contrast check**: Use WebAIM Contrast Checker

## Reference Files

For detailed guidance:

| File | When to Read |
|------|--------------|
| **[references/common-issues.md](references/common-issues.md)** | Detailed fixes for 8 most common accessibility issues with code examples |
| **[references/aria-patterns.md](references/aria-patterns.md)** | ARIA attributes, live regions, custom component patterns (tabs, accordions, menus) |
| **[references/testing-checklist.md](references/testing-checklist.md)** | Complete testing checklist, screen reader shortcuts, accessibility statement template |

## Resources

**Tools:**
- axe DevTools (browser extension)
- WAVE (web accessibility evaluation tool)
- Lighthouse (Chrome DevTools)
- Colour Contrast Analyser

**Guidelines:**
- WCAG 2.1: https://www.w3.org/WAI/WCAG21/quickref/
- ARIA Authoring Practices: https://www.w3.org/WAI/ARIA/apg/

---

Accessibility is not optional - it's a fundamental requirement for inclusive web experiences. Prioritize it from the start of every project, not as an afterthought.
