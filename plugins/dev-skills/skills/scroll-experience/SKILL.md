---
name: scroll-experience
description: This skill should be used when the user asks to "add scroll animations", "create parallax effects", "build a scroll story", "make an interactive narrative", "create a cinematic website", "add scroll-triggered reveals", or needs immersive scroll-driven experiences like NY Times interactives or Apple product pages.
source: vibeship-spawner-skills (Apache 2.0)
allowed-tools: Read, Glob, Grep
---

# Scroll Experience

Create immersive scroll-driven experiences where scrolling becomes a narrative device, not just navigation.

## Library Selection

| Library | Best For | Learning Curve |
|---------|----------|----------------|
| GSAP ScrollTrigger | Complex animations | Medium |
| Framer Motion | React projects | Low |
| Locomotive Scroll | Smooth scroll + parallax | Medium |
| Lenis | Smooth scroll only | Low |
| CSS scroll-timeline | Simple, native | Low |

## Quick Start Examples

### GSAP ScrollTrigger

```javascript
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

// Basic scroll animation
gsap.to('.element', {
  scrollTrigger: {
    trigger: '.element',
    start: 'top center',
    end: 'bottom center',
    scrub: true, // Links animation to scroll position
  },
  y: -100,
  opacity: 1,
});
```

### Framer Motion (React)

```jsx
import { motion, useScroll, useTransform } from 'framer-motion';

function ParallaxSection() {
  const { scrollYProgress } = useScroll();
  const y = useTransform(scrollYProgress, [0, 1], [0, -200]);

  return (
    <motion.div style={{ y }}>
      Content moves with scroll
    </motion.div>
  );
}
```

### CSS Native (2024+)

```css
@keyframes reveal {
  from { opacity: 0; transform: translateY(50px); }
  to { opacity: 1; transform: translateY(0); }
}

.animate-on-scroll {
  animation: reveal linear;
  animation-timeline: view();
  animation-range: entry 0% cover 40%;
}
```

## Parallax Layer Speeds

| Layer | Speed | Effect |
|-------|-------|--------|
| Background | 0.2x | Far away, slow |
| Midground | 0.5x | Middle depth |
| Foreground | 1.0x | Normal scroll |
| Content | 1.0x | Readable |
| Floating | 1.2x | Pop forward |

## Story Structure

```
Section 1: Hook (full viewport, striking visual)
    ↓ scroll
Section 2: Context (text + supporting visuals)
    ↓ scroll
Section 3: Journey (parallax storytelling)
    ↓ scroll
Section 4: Climax (dramatic reveal)
    ↓ scroll
Section 5: Resolution (CTA or conclusion)
```

## Sticky Sections

Pin elements while scrolling through content:

```javascript
gsap.to('.content', {
  scrollTrigger: {
    trigger: '.section',
    pin: true, // Pins the section
    start: 'top top',
    end: '+=1000', // Pin for 1000px of scroll
    scrub: true,
  },
  x: '-100vw', // Animate while pinned
});
```

## Anti-Patterns

### Scroll Hijacking

**Why bad:** Users lose scroll control. Accessibility nightmare. Frustrating on mobile.

**Instead:** Enhance scroll, don't replace it. Keep natural scroll speed. Use scrub animations.

### Animation Overload

**Why bad:** Distracting. Performance tanks. Content becomes secondary.

**Instead:** Less is more. Animate key moments. Guide attention, don't overwhelm.

### Desktop-Only

**Why bad:** Mobile is majority of traffic. Touch scroll is different. Performance issues.

**Instead:** Mobile-first design. Simpler effects on mobile. Test on real devices.

## Common Issues

| Issue | Severity | Solution |
|-------|----------|----------|
| Animations stutter during scroll | High | See [references/performance-fixes.md](references/performance-fixes.md) |
| Parallax breaks on mobile | High | See [references/performance-fixes.md](references/performance-fixes.md) |
| Scroll experience is inaccessible | Medium | See [references/accessibility.md](references/accessibility.md) |
| Critical content hidden below animations | Medium | See [references/performance-fixes.md](references/performance-fixes.md) |

## Reference Files

| File | When to Read |
|------|--------------|
| **[references/performance-fixes.md](references/performance-fixes.md)** | Fixing scroll jank, mobile-safe parallax, content-first design |
| **[references/accessibility.md](references/accessibility.md)** | Reduced motion support, keyboard navigation, screen readers |

## Related Skills

Works well with: `frontend-design`, `accessibility-auditor`
