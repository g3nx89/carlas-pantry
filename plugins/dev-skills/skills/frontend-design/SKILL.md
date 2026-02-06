---
name: frontend-design
description: This skill should be used when the user asks to "build a website", "create a landing page", "design a dashboard", "build a React component", "style a web UI", "beautify this page", "create a web application", or needs distinctive, production-grade frontend interfaces. Triggers include requests for HTML/CSS layouts, web components, posters, artifacts, or any frontend work requiring high design quality and creative aesthetics.
license: Complete terms in LICENSE.txt
allowed-tools: Read, Glob, Grep, Write, Edit
---

# Frontend Design

Create distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics. Implement real working code with exceptional attention to aesthetic details and creative choices.

## Workflow

1. **Clarify Requirements** - Understand purpose, audience, constraints
2. **Choose Aesthetic Direction** - Commit to a BOLD, distinctive vision
3. **Design System Setup** - Define typography, colors, spacing
4. **Implement Structure** - Build semantic HTML/component hierarchy
5. **Apply Styling** - Execute aesthetic vision with precision
6. **Add Motion** - Animations, transitions, micro-interactions
7. **Refine Details** - Polish every pixel

## When NOT to Use

Delegate to specialized skills:
- **Accessibility auditing** → `accessibility-auditor` skill
- **Mobile-first design** → `mobile-design` skill
- **Design system tokens** → `figma-create-design-system-rules` skill
- **Scroll animations** → `scroll-experience` skill

## Design Thinking

Before coding, understand the context and commit to a BOLD aesthetic direction:

| Question | Why It Matters |
|----------|----------------|
| **Purpose** | What problem does this interface solve? Who uses it? |
| **Tone** | Pick an extreme aesthetic (see Aesthetic Directions below) |
| **Constraints** | Framework, performance budget, accessibility requirements |
| **Differentiation** | What makes this UNFORGETTABLE? |

**CRITICAL**: Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work - the key is intentionality, not intensity.

## Aesthetic Directions

Pick one and commit fully:

| Direction | Characteristics | Best For |
|-----------|-----------------|----------|
| **Brutally Minimal** | Extreme whitespace, monospace fonts, zero decoration | Developer tools, portfolios |
| **Maximalist Chaos** | Layered elements, mixed fonts, vibrant colors | Creative agencies, art |
| **Retro-Futuristic** | CRT effects, terminal green, synthwave gradients | Tech products, gaming |
| **Organic/Natural** | Earthy tones, rounded shapes, texture overlays | Wellness, sustainability |
| **Luxury/Refined** | Serif fonts, muted golds, editorial layouts | Fashion, high-end products |
| **Playful/Toy-like** | Bright colors, bouncy animations, rounded corners | Kids, casual apps |
| **Editorial/Magazine** | Grid-breaking layouts, dramatic typography | Media, portfolios |
| **Brutalist/Raw** | Exposed structure, harsh contrasts, no polish | Art, statements |
| **Art Deco/Geometric** | Gold accents, geometric patterns, symmetry | Luxury, events |
| **Industrial/Utilitarian** | Exposed UI, monospace, functional aesthetic | Dashboards, data tools |

## Frontend Aesthetics Guidelines

### Typography

```css
/* NEVER: Generic fonts */
font-family: Arial, sans-serif;
font-family: Inter, system-ui;

/* DO: Distinctive choices */
font-family: 'Playfair Display', serif;  /* Editorial */
font-family: 'JetBrains Mono', monospace; /* Technical */
font-family: 'Clash Display', sans-serif; /* Bold modern */
```

**Rules:**
- Pair distinctive display font with refined body font
- Use variable fonts for performance and flexibility
- Never exceed 3 font families per project

### Color System

```css
:root {
  /* Define with intention - not defaults */
  --color-primary: #1a1a2e;    /* Deep, not generic blue */
  --color-accent: #e94560;     /* Sharp, memorable accent */
  --color-surface: #0f0f23;    /* Atmospheric, not white */
  --color-text: #eaeaea;       /* Soft, not harsh white */
}
```

**Rules:**
- Commit to a cohesive palette (dominant + 1-2 accents)
- Use CSS custom properties for consistency
- Avoid timid, evenly-distributed color schemes

### Motion & Animation

```css
/* Page load - staggered reveals */
.card {
  animation: fadeInUp 0.6s ease-out;
  animation-fill-mode: both;
}
.card:nth-child(1) { animation-delay: 0.1s; }
.card:nth-child(2) { animation-delay: 0.2s; }
.card:nth-child(3) { animation-delay: 0.3s; }

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* Hover states that surprise */
.button {
  transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
}
.button:hover {
  transform: scale(1.05) rotate(-1deg);
  box-shadow: 0 10px 40px rgba(0,0,0,0.3);
}
```

**Rules:**
- One orchestrated page load > scattered micro-interactions
- Use `cubic-bezier` for organic motion
- CSS-first; use Motion/Framer for React when needed

### Spatial Composition

**Techniques:**
- Asymmetric layouts that break the grid
- Overlapping elements for depth
- Diagonal flow and unexpected angles
- Generous negative space OR controlled density

```css
/* Grid-breaking hero */
.hero {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0; /* Elements intentionally overlap */
}

.hero-image {
  grid-column: 1 / 3;
  grid-row: 1;
}

.hero-content {
  grid-column: 1 / 2;
  grid-row: 1;
  z-index: 1;
  padding: 4rem;
  background: rgba(0,0,0,0.8);
  margin-top: 8rem; /* Intentional offset */
}
```

### Backgrounds & Atmosphere

```css
/* Gradient mesh */
background:
  radial-gradient(ellipse at 20% 80%, rgba(120, 119, 198, 0.3), transparent),
  radial-gradient(ellipse at 80% 20%, rgba(255, 119, 119, 0.2), transparent),
  #0a0a0a;

/* Noise texture overlay */
.surface::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image: url("data:image/svg+xml,...noise...");
  opacity: 0.05;
  pointer-events: none;
}

/* Grain overlay */
.grain {
  background-image: url('grain.png');
  mix-blend-mode: overlay;
  opacity: 0.15;
}
```

## Anti-Patterns (NEVER Do)

| Anti-Pattern | Why It Fails | Instead |
|--------------|--------------|---------|
| `font-family: Inter, Arial, sans-serif` | Generic, forgettable | Choose distinctive fonts |
| Purple gradient on white background | Cliché "AI look" | Commit to unique palette |
| Evenly distributed muted colors | No hierarchy, boring | Dominant color + sharp accents |
| Perfectly centered everything | Predictable, lifeless | Asymmetry, intentional offset |
| Generic rounded cards on grid | Cookie-cutter | Grid-breaking, overlaps |
| Same design every time | Lazy | Each project deserves unique vision |
| `Space Grotesk` as default | Overused | Explore font directories |

## Decision Framework

```
User Request
│
├── Is purpose/audience clear?
│   ├── No → Ask clarifying questions
│   └── Yes → Continue
│
├── Is technical stack specified?
│   ├── No → Recommend based on complexity
│   └── Yes → Use specified stack
│
├── Choose aesthetic direction
│   ├── Professional/Corporate → Refined, Editorial
│   ├── Creative/Art → Maximalist, Brutalist
│   ├── Tech/Developer → Minimal, Industrial
│   ├── Consumer/Fun → Playful, Organic
│   └── Luxury/Premium → Art Deco, Refined
│
└── Implement with full commitment to chosen direction
```

## Quick Reference

| Element | Distinctive Approach |
|---------|---------------------|
| Hero | Full-bleed image with overlapping text block |
| Cards | Varied sizes, intentional misalignment |
| Navigation | Unexpected placement (bottom, side, overlay) |
| Buttons | Custom shapes, dramatic hover states |
| Forms | Exposed labels, animated focus states |
| Footers | Full content blocks, not afterthoughts |

## Verification Checklist

Before delivering:

- [ ] Aesthetic direction is BOLD and intentional
- [ ] Typography choices are distinctive (not defaults)
- [ ] Color palette has clear hierarchy
- [ ] At least one "wow" moment (animation, layout, interaction)
- [ ] Code is production-grade and functional
- [ ] No generic "AI slop" patterns

## Resources

**Font Discovery:**
- [Google Fonts](https://fonts.google.com) - Filter by category
- [Font Share](https://www.fontshare.com) - Free unique fonts
- [Atipo Foundry](https://www.atipofoundry.com) - Quality free fonts

**Inspiration:**
- [Awwwards](https://www.awwwards.com) - Award-winning sites
- [Dribbble](https://dribbble.com) - UI explorations
- [Mobbin](https://mobbin.com) - Mobile patterns

**IMPORTANT**: Match implementation complexity to the aesthetic vision. Maximalist designs need elaborate code. Minimalist designs need precision and restraint. Elegance comes from executing the vision well.

Claude can produce extraordinary creative work when given bold direction. Commit fully to a distinctive vision.
