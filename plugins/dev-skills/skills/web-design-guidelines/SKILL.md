---
name: web-design-guidelines
description: This skill should be used when the user asks to "review my UI", "check accessibility", "audit design", "review UX", "check my site against best practices", "validate my frontend", or needs Web Interface Guidelines compliance checking. Fetches latest guidelines from Vercel's web-interface-guidelines and audits specified files.
argument-hint: <file-or-pattern>
allowed-tools: Read, Glob, Grep, WebFetch
---

# Web Interface Guidelines

Review files for compliance with Web Interface Guidelines.

## Guidelines Source

**Primary Source** (fetch fresh before each review):
```
https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md
```

If WebFetch fails, use the **Fallback Guidelines** below.

## Workflow

1. **Fetch Guidelines** - WebFetch from source URL
2. **If fetch fails** - Use Fallback Guidelines section below
3. **Identify Files** - Use argument or ask user for files/pattern
4. **Read Files** - Load specified files for review
5. **Apply Rules** - Check against all guidelines
6. **Report Findings** - Output in `file:line` format

## Error Handling

| Error | Action |
|-------|--------|
| WebFetch timeout | Use Fallback Guidelines |
| URL unavailable | Use Fallback Guidelines |
| No files specified | Ask user which files to review |
| Files not found | Report error, suggest glob pattern |

## Output Format

Report findings as:
```
path/to/file.tsx:42 - [Rule Category] Description of issue
```

Example:
```
src/components/Button.tsx:15 - [Accessibility] Button missing aria-label for icon-only content
src/pages/home.tsx:89 - [Performance] Large image without lazy loading
```

## Fallback Guidelines

Use these rules when external source is unavailable:

### Accessibility (a11y)

- All interactive elements must be keyboard accessible
- Images require alt text (empty `alt=""` for decorative)
- Color contrast must meet WCAG AA (4.5:1 for text)
- Focus indicators must be visible
- Form inputs need associated labels
- ARIA roles used correctly (prefer semantic HTML)
- Skip links for navigation-heavy pages
- No content accessible only via hover/focus

### Performance

- Images should use modern formats (WebP, AVIF)
- Large images should lazy load (`loading="lazy"`)
- Avoid layout shift (set explicit width/height)
- Bundle size awareness (no unnecessary dependencies)
- Critical CSS inlined, non-critical deferred
- Fonts should use `font-display: swap`

### Responsiveness

- Mobile-first approach preferred
- Touch targets minimum 44x44px
- No horizontal scrolling on mobile
- Content readable without zooming
- Forms usable on touch devices

### Code Quality

- Semantic HTML elements over generic divs
- CSS custom properties for theming
- No inline styles for repeated patterns
- Components follow single responsibility
- Event handlers properly cleaned up
- Keys provided for list items

### Usability

- Clear visual hierarchy
- Consistent interaction patterns
- Feedback for user actions (loading states, success/error)
- Error messages actionable and specific
- Forms validate with helpful messages
- Back button works as expected

### Security

- No sensitive data in client-side code
- User input sanitized before render
- External links use `rel="noopener noreferrer"`
- Forms protected against CSRF where applicable

## Review Checklist

When reviewing a file:

- [ ] Semantic HTML structure?
- [ ] Keyboard navigable?
- [ ] Alt text on images?
- [ ] Color contrast adequate?
- [ ] Loading states present?
- [ ] Error states handled?
- [ ] Responsive design?
- [ ] Performance optimized?

## Related Skills

| Need | Skill |
|------|-------|
| Detailed accessibility audit | `accessibility-auditor` |
| Mobile-specific review | `mobile-design` |
| Frontend design review | `frontend-design` |
