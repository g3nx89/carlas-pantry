# Accessible Scroll Experiences

## Respect User Preferences

### Reduced Motion

Always check and respect the user's motion preferences:

```javascript
const prefersReducedMotion = window.matchMedia(
  '(prefers-reduced-motion: reduce)'
).matches;

if (prefersReducedMotion) {
  // Disable all scroll animations
  // Show content immediately
  document.querySelectorAll('.animate-on-scroll').forEach(el => {
    el.style.opacity = 1;
    el.style.transform = 'none';
  });
}
```

### CSS-Only Approach

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

## Keyboard Navigation

### Skip Animation Links

Provide skip links for long animated sections:

```html
<a href="#section-after-animation" class="skip-link">
  Skip animation
</a>

<section class="long-scroll-animation">
  <!-- Scroll-driven content -->
</section>

<section id="section-after-animation">
  <!-- Rest of page -->
</section>
```

### Focus Management

Don't trap focus in animated sections:

```javascript
// Bad: Focus trapped during animation
element.addEventListener('scroll', () => {
  document.activeElement.blur(); // Don't do this
});

// Good: Maintain focus through animations
// Let users tab through normally
```

## Screen Reader Considerations

### ARIA Live Regions

For dynamically revealed content:

```html
<div
  aria-live="polite"
  aria-atomic="false"
  class="scroll-revealed-content"
>
  <!-- Content appears on scroll -->
</div>
```

### Hidden Content

If content is visually hidden but will appear, don't hide from screen readers:

```css
/* BAD - hides from everyone */
.hidden {
  display: none;
}

/* GOOD - visually hidden but accessible */
.visually-hidden-until-scroll {
  opacity: 0;
  /* Screen readers can still access */
}
```

## Vestibular Disorders

Some users experience motion sickness from parallax and scroll animations.

### Best Practices

1. **Limit parallax depth** - Subtle movement (0.1-0.3 speed difference) is safer
2. **Avoid autoplay video** - Let users control media
3. **No infinite scrolling animations** - Have clear start/end
4. **Provide static alternatives** - Option to view content without animation

### Safe Animation Patterns

```javascript
// Safe: Fade and subtle translate
gsap.from('.element', {
  opacity: 0,
  y: 20, // Small movement
  duration: 0.5
});

// Risky: Large parallax movement
gsap.to('.background', {
  y: '-100%', // Large movement - needs reduced motion check
});
```

## Testing

### Manual Testing

1. Enable "Reduce motion" in OS settings
2. Navigate with keyboard only
3. Test with screen reader (VoiceOver, NVDA)
4. Check content is accessible without JavaScript

### Automated Testing

```javascript
// Test that content is visible with reduced motion
test('content visible with reduced motion', () => {
  window.matchMedia = jest.fn().mockReturnValue({
    matches: true, // Simulate reduced motion
    addListener: jest.fn()
  });

  // Initialize component
  // Assert content is visible immediately
});
```
