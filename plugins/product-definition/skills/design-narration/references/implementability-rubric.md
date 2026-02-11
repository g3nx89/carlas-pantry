---
stage: validation
artifacts_written: []
---

# Implementability Evaluation Rubric (Shared)

> Shared rubric used by both:
> - `agents/narration-developer-implementability.md` (Task subagent pathway)
> - `references/validation-protocol.md` (clink/Codex inline prompt)
>
> **Single source of truth.** If this file is updated, the clink prompt in
> `validation-protocol.md` Step 4.1 MUST be regenerated from this content.

## 5 Evaluation Dimensions (score 1-5 each)

### 1. Component Specification

Determine whether all UI components are identifiable with their type and variant:
- Can each element be mapped to a concrete widget/component? (e.g., "text field" vs "search bar with autocomplete")
- Are component variants specified? (e.g., filled vs outlined text field, primary vs secondary button)
- Are dimensions, padding, and spacing derivable from the narrative or explicit?
- Are color/typography tokens referenced or at least described consistently?

### 2. Interaction Completeness

Verify every user action has a defined system response:
- Every tappable element has a documented tap behavior
- Form submissions define validation rules and success/failure responses
- Gesture-based interactions specify exact gesture and threshold (e.g., "swipe left > 50% width to delete")
- Transitions specify type (push, modal, fade) or at least direction

### 3. Data Requirements

Confirm what data each element displays and where it comes from:
- Each text element specifies whether content is static, user-generated, or server-provided
- Lists specify the data source, sort order, and pagination behavior
- Images specify placeholder, loading, and error states
- Conditional visibility rules are explicit (e.g., "badge shown only when count > 0")

### 4. Layout Precision

Assess whether enough detail exists to reproduce the layout structure:
- Vertical/horizontal grouping of elements is clear
- Scrolling behavior is specified (fixed header, sticky footer, scroll-within-scroll)
- Responsive behavior or breakpoint rules are documented (if applicable)
- Safe area and notch handling are addressed for mobile

### 5. Platform Specifics

Check for mobile-specific implementation details:
- Keyboard types specified for text inputs (email, numeric, phone, default)
- Input validation rules documented (max length, regex patterns, real-time vs on-submit)
- Accessibility hints present (labels, roles, traits, reading order)
- Platform-specific behaviors noted (iOS vs Android differences, if applicable)

## Scoring Format

Produce a per-screen scores table:

| Screen | Components | Interactions | Data | Layout | Platform | Average |
|--------|-----------|-------------|------|--------|----------|---------|
| {name} | {1-5} | {1-5} | {1-5} | {1-5} | {1-5} | {avg} |

Overall average across all screens serves as the aggregate implementability score.

## "Would Need to Ask" List

For every score below 4, list the specific questions a developer would be blocked on:

### {Screen Name} — {Dimension} (Score: {N})
1. {Specific question a developer would ask}

Classify each question as:
- **Blocking** — cannot proceed without an answer
- **Degraded** — can implement a reasonable default but may be wrong

Tag each question with confidence:
- **high** — definitively missing from narrative
- **medium** — present but ambiguous
- **low** — possibly covered elsewhere

Example: `1. What keyboard type for the email field? — Degraded, Confidence: **medium**`

## Output YAML Frontmatter

```yaml
---
status: complete
overall_score: {average across all screens}
screen_scores:
  - screen: "{name}"
    components: {1-5}
    interactions: {1-5}
    data: {1-5}
    layout: {1-5}
    platform: {1-5}
    average: {float}
blocker_count: {total blocking questions}
degraded_count: {total degraded questions}
---
```
