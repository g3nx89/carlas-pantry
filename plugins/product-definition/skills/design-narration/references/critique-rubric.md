---
stage: critique
artifacts_written: []
---

# Screen Narrative Self-Critique Rubric

LLM-as-Judge pattern for evaluating the quality of per-screen UX narrative descriptions.
Apply this rubric AFTER generating a screen narrative and BEFORE presenting questions to the user.

**CRITICAL RULES (High Attention Zone - Start)**

1. Use the 1-4 scale only — never score outside this range
2. Score all 5 dimensions (Completeness, Interaction Clarity, State Coverage, Navigation Context, Ambiguity) for every evaluation
3. Map weak dimensions (scoring 1-2) to question categories (BEHAVIOR, STATE, NAVIGATION, CONTENT, EDGE, ANIMATION)

**CRITICAL RULES (High Attention Zone - End)**

---

## Rubric Overview

| Dimension | Focus |
|-----------|-------|
| Completeness | Every visible element accounted for |
| Interaction Clarity | Every interactive element has explicit behavior |
| State Coverage | All plausible states identified |
| Navigation Context | Entry/exit points and flow position explicit |
| Ambiguity | No vague language a developer could misinterpret |

---

## Dimension 1: Completeness

| Score | Level | Observable Characteristics |
|-------|-------|---------------------------|
| 1 | Poor | Major elements missing. Description has fewer elements than visible in the screenshot. |
| 2 | Adequate | Core interactive elements present but notable gaps in static elements, labels, or text content. |
| 3 | Good | All primary elements covered. Minor secondary elements may be missing (decorative separators, background patterns). |
| 4 | Excellent | Every element described. Secondary elements (dividers, badges, status indicators) included. Background, spacing, and decorative elements noted. |

**Evidence to Look For:**
- Count elements in screenshot vs Elements table
- Check for images, icons, badges, status indicators
- Verify labels, placeholder text, and helper text are captured
- Confirm decorative and structural elements (dividers, cards, shadows) are noted

**Remediation if Score 1-2:**
Systematically scan the screenshot top-to-bottom, left-to-right. Add every visible element to the Elements table, including static text, icons, and decorative separators.

---

## Dimension 2: Interaction Clarity

| Score | Level | Observable Characteristics |
|-------|-------|---------------------------|
| 1 | Poor | Multiple interactive elements have no behavior specified. A developer cannot implement without guessing. |
| 2 | Adequate | Interactive elements listed but behaviors vague or generic ("shows a message", "navigates somewhere"). |
| 3 | Good | Primary interactions (tap) clear for all interactive elements. Some secondary gestures (swipe, long-press) may be undefined. |
| 4 | Excellent | All interactions specified with exact outcomes for every relevant gesture. Edge cases covered (disabled state, double-tap, long-press). |

**Evidence to Look For:**
- Every button, link, input, toggle, slider, and switch has a Behavior table entry
- No instances of "appropriate" or "relevant" in behavior descriptions
- Disabled states defined for conditionally active elements
- Loading behavior specified for async actions

**Remediation if Score 1-2:**
For each interactive element, define: tap result, disabled behavior, loading behavior. Replace vague descriptions with specific outcomes and target screens.

---

## Dimension 3: State Coverage

| Score | Level | Observable Characteristics |
|-------|-------|---------------------------|
| 1 | Poor | No explicit state analysis. Only what is visible in the current screenshot. |
| 2 | Adequate | Default state only. Loading or error states missing on data-dependent screens. |
| 3 | Good | Default + most states. One contextual state may be missing (e.g., offline state for a data screen). |
| 4 | Excellent | Default + all contextual states. For data screens: empty + loading + error + success. For forms: validation states (valid, invalid, submitting). Offline state if network-dependent. |

**Evidence to Look For:**
- Data-dependent screens must have loading + error + empty states
- Forms must have validation states (valid, invalid, submitting)
- Network-dependent screens must have an offline state
- Conditional UI sections have both visible and hidden states documented

**Remediation if Score 1-2:**
List all data sources on screen. For each, add loading, error, and empty states. For forms, add validation states per field. For network-dependent screens, add offline fallback behavior.

---

## Dimension 4: Navigation Context

| Score | Level | Observable Characteristics |
|-------|-------|---------------------------|
| 1 | Poor | No navigation context. Screen described in isolation with no reference to other screens. |
| 2 | Adequate | Some navigation mentioned but entry/exit not systematically covered. Missing back navigation behavior. |
| 3 | Good | Main entry/exit points listed. Minor navigation paths (back button, swipe-to-dismiss) may be implicit. |
| 4 | Excellent | All entry/exit points listed with specific triggers. Flow position unambiguous. Back navigation behavior defined. Deep link behavior noted. |

**Evidence to Look For:**
- Navigation table has at least 2 entries (one arrival, one departure)
- Back button behavior defined explicitly
- Position in flow is clear from context
- Modal dismiss behavior specified if applicable

**Remediation if Score 1-2:**
Add "From" entries (how the user arrives at this screen). Add "To" entries (where the user can go next). Define back button and swipe-back behavior. State the screen's position within the overall flow.

---

## Dimension 5: Ambiguity

| Score | Level | Observable Characteristics |
|-------|-------|---------------------------|
| 1 | Poor | Pervasively vague. A developer would need to ask 5+ clarifying questions to implement. |
| 2 | Adequate | Several vague descriptions. Words like "appropriate", "relevant", "suitable", "some", "various" appear. |
| 3 | Good | Mostly specific. 1-2 minor ambiguities that surrounding context resolves (e.g., "standard loading spinner" when spinner style is defined in Global Patterns). |
| 4 | Excellent | Every description is implementation-ready. No vague terms. A developer could code this screen from the narrative + screenshot without any questions. |

**Evidence to Look For:**
- Grep for forbidden vague words: "appropriate", "relevant", "suitable", "some", "various", "etc.", "may", "might", "possibly"
- Verify color values, spacing, and sizing use concrete tokens or pixel values
- Confirm text content is verbatim, not paraphrased
- Check that conditional logic uses explicit conditions, not "if needed"

**Remediation if Score 1-2:**
Replace every vague word with a specific value, name, or action. Example: "Appropriate message" becomes "Error: Please enter a valid email address". Remove all instances of "etc." by listing exhaustive options.

---

## Score Calculation

```
Total = Completeness + Interaction + States + Navigation + Ambiguity
Maximum = 20 points (each dimension max 4)

Thresholds (from config):
  14+ = GOOD — proceed to sign-off without questions
  10-13 = ACCEPTABLE — generate targeted questions for weak dimensions
  <10 = NEEDS WORK — generate questions, iterate
```

---

## Failure Mode Checklist

Verify all failure modes are CLEAR before submitting:

| Failure Mode | Check |
|--------------|-------|
| Orphan elements | Element visible in screenshot but not in Elements table |
| Dead-end navigation | Screen references another screen not in the screen list |
| Vague behavior | Behavior cell contains non-specific language |
| Missing error state | Data/network-dependent screen without error state |
| Ambiguous terminology | Same component called different names across screens |
| Missing animation | Screen transition or state change without animation description |
| Inconsistent naming | Element names do not match names used in prior screens |

**If any failure mode is FOUND:** Fix before proceeding. Iterate until all are CLEAR.

---

## Required Output Format

After self-critique, include:

```markdown
## Self-Critique Summary

| Dimension | Score | Evidence |
|-----------|-------|----------|
| Completeness | [1-4] | [Brief citation] |
| Interaction Clarity | [1-4] | [Brief citation] |
| State Coverage | [1-4] | [Brief citation] |
| Navigation Context | [1-4] | [Brief citation] |
| Ambiguity | [1-4] | [Brief citation] |
| **TOTAL** | **[X]/20** | |

### Weak Dimensions
[List dimensions scoring 1-2 with specific gaps]

### Question Categories Needed
[Map weak dimensions to question categories: BEHAVIOR, STATE, NAVIGATION, CONTENT, EDGE, ANIMATION]
```

**CRITICAL RULES REMINDER (High Attention Zone - End)**

1. Use the 1-4 scale only
2. Score all 5 dimensions for every evaluation
3. Map weak dimensions to question categories
