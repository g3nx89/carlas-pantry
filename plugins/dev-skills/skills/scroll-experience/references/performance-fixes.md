# Scroll Performance Fixes

## Fixing Scroll Jank

Scroll jank occurs when animations can't keep up with 60fps during scrolling.

### Common Causes

1. **JavaScript animations blocking main thread**
2. **Layout thrashing** (reading then writing DOM repeatedly)
3. **Heavy paint operations**
4. **Unoptimized images/videos**

### Solutions

**Use CSS transforms instead of position properties:**
```css
/* BAD - triggers layout */
.element {
  animation: move 1s;
}
@keyframes move {
  to { top: 100px; left: 100px; }
}

/* GOOD - GPU accelerated */
.element {
  animation: move 1s;
  will-change: transform;
}
@keyframes move {
  to { transform: translate(100px, 100px); }
}
```

**Use `will-change` sparingly:**
```css
/* Only on elements that will animate */
.animated-element {
  will-change: transform, opacity;
}

/* Remove when animation completes */
```

**Debounce scroll handlers:**
```javascript
let ticking = false;

window.addEventListener('scroll', () => {
  if (!ticking) {
    requestAnimationFrame(() => {
      // Do scroll work here
      ticking = false;
    });
    ticking = true;
  }
});
```

**Use `passive` event listeners:**
```javascript
window.addEventListener('scroll', handler, { passive: true });
```

## Mobile-Safe Parallax

Mobile devices have limited GPU memory and different scroll physics.

### Mobile-First Approach

```javascript
// Detect mobile
const isMobile = window.matchMedia('(max-width: 768px)').matches;

// Simpler effects on mobile
if (isMobile) {
  // Disable parallax, use simple fade-ins
  gsap.to('.element', {
    scrollTrigger: { trigger: '.element' },
    opacity: 1,
    y: 0
  });
} else {
  // Full parallax on desktop
  gsap.to('.background', {
    scrollTrigger: { scrub: true },
    y: '-30%'
  });
}
```

### Reduce Layer Count on Mobile

```css
@media (max-width: 768px) {
  .parallax-layer {
    transform: none !important;
    will-change: auto;
  }
}
```

### Test on Real Devices

- iOS Safari has different scroll behavior
- Android Chrome has its own quirks
- Always test on actual phones, not just DevTools

## Content-First Scroll Design

Animations should enhance content, not hide it.

### Above the Fold

Critical content should be visible without scrolling:
- Main headline
- Key value proposition
- Primary CTA

### Graceful Degradation

```javascript
// Check for reduced motion preference
const prefersReducedMotion = window.matchMedia(
  '(prefers-reduced-motion: reduce)'
).matches;

if (prefersReducedMotion) {
  // Skip animations entirely
  gsap.set('.animated', { opacity: 1, y: 0 });
} else {
  // Full animation experience
  gsap.from('.animated', {
    scrollTrigger: { trigger: '.animated' },
    opacity: 0,
    y: 50
  });
}
```

### Loading States

Don't hide content behind scroll that hasn't loaded:
```javascript
// Wait for images before enabling scroll animations
Promise.all(
  Array.from(document.images)
    .filter(img => !img.complete)
    .map(img => new Promise(resolve => {
      img.onload = img.onerror = resolve;
    }))
).then(() => {
  // Initialize scroll animations
  initScrollAnimations();
});
```
