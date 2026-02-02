# Accessibility Testing Checklist

## Automated Testing

- [ ] Run axe DevTools or WAVE browser extension
- [ ] Check HTML validation (W3C Validator)
- [ ] Test color contrast ratios
- [ ] Verify heading hierarchy
- [ ] Check for missing alt text

## Manual Testing

- [ ] Navigate entire site using only keyboard (Tab, Enter, Escape, Arrow keys)
- [ ] Test with screen reader (NVDA, JAWS, or VoiceOver)
- [ ] Verify focus indicators are visible
- [ ] Check form validation messages are announced
- [ ] Test modal focus trapping
- [ ] Verify skip links work
- [ ] Test with browser zoom at 200%
- [ ] Check page reflow at different viewport sizes
- [ ] Disable JavaScript and verify core functionality
- [ ] Test with Windows High Contrast mode

## Screen Reader Testing

### VoiceOver (Mac)

| Action | Shortcut |
|--------|----------|
| Enable | Cmd + F5 |
| Navigate | Control + Option + Arrow keys |
| Read all | Control + Option + A |
| Rotor (landmarks) | Control + Option + U |

### NVDA (Windows)

| Action | Shortcut |
|--------|----------|
| Navigate | Arrow keys (browse mode) or Tab (focus mode) |
| Read all | NVDA + Down Arrow |
| Elements list | NVDA + F7 |
| Toggle mode | NVDA + Space |

### Test Scenarios

- Can users understand page structure?
- Are headings descriptive and hierarchical?
- Are form labels clear and associated?
- Are error messages announced?
- Can users complete key tasks without vision?
- Do images have meaningful alt text?
- Are live regions announcing updates?

## Keyboard Navigation Checklist

- [ ] All interactive elements focusable with Tab
- [ ] Focus order matches visual order
- [ ] No keyboard traps
- [ ] Skip link works
- [ ] Modals trap focus correctly
- [ ] Escape closes modals/popups
- [ ] Arrow keys work in menus/tabs
- [ ] Enter/Space activate buttons

## Color and Contrast

- [ ] Text contrast >= 4.5:1 (normal) or >= 3:1 (large)
- [ ] UI component contrast >= 3:1
- [ ] Information not conveyed by color alone
- [ ] Focus indicators visible
- [ ] Works in high contrast mode

## Tools

**Browser Extensions:**
- axe DevTools (Chrome, Firefox)
- WAVE (Chrome, Firefox)
- Lighthouse (Chrome DevTools)

**Contrast Checkers:**
- WebAIM Contrast Checker
- Colour Contrast Analyser (desktop app)

**Screen Readers:**
- NVDA (Windows, free)
- JAWS (Windows, paid)
- VoiceOver (Mac/iOS, built-in)
- TalkBack (Android, built-in)

**Guidelines:**
- WCAG 2.1: https://www.w3.org/WAI/WCAG21/quickref/
- ARIA Authoring Practices: https://www.w3.org/WAI/ARIA/apg/

## Accessibility Statement Template

```markdown
# Accessibility Statement

We are committed to ensuring digital accessibility for people with
disabilities. We continually improve the user experience for everyone
and apply relevant accessibility standards.

## Conformance Status

This website is partially conformant with WCAG 2.1 Level AA.
"Partially conformant" means that some parts of the content do not
fully conform to the accessibility standard.

## Feedback

We welcome your feedback on the accessibility of this site:
- Email: accessibility@example.com
- Phone: +1-555-0123

## Known Issues

- [List any known accessibility issues and planned fixes]

Last updated: [Date]
```
