---
stage: screen-processing
artifacts_written: []
---

# Screen Narrative Self-Critique Rubric

LLM-as-Judge pattern for evaluating the quality of per-screen UX narrative descriptions.
Apply this rubric AFTER generating a screen narrative and BEFORE presenting questions to the user.

## CRITICAL RULES (must follow)

1. Use the 1-4 scale only — never score outside this range
2. Score all 5 dimensions (Completeness, Interaction Clarity, State Coverage, Navigation Context, Ambiguity) for every evaluation
3. Map weak dimensions (scoring 1-2) to question categories (BEHAVIOR, STATE, NAVIGATION, CONTENT, EDGE, ANIMATION)

---

## Failure Mode Checklist (Prime Before Scoring)

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

### Calibration Example — Completeness

**Score 2 (Adequate):**
> Narrative lists: header, search bar, product grid (6 items), bottom nav bar. Missing: status bar content, filter chips row, "Sort by" dropdown, cart badge with count on nav icon, promotional banner between rows 2 and 3, pull-to-refresh indicator. The core interactive elements are present but ~6 secondary elements are unaccounted for.
> **Verdict:** Core interactive elements present; notable gaps in static elements, labels, and status indicators → Score 2.

**Score 4 (Excellent):**
> Narrative lists 23 elements including: status bar (time, signal, battery), header with back chevron + "Products" title + cart icon (badge: "3"), search bar with magnifying glass icon + placeholder "Search products...", filter chips row (All, Popular, New, Sale — "All" active with blue fill), sort dropdown ("Relevance ▼"), product grid (6 cards each with: image, heart icon, title, price, star rating, reviews count), promotional banner ("Free shipping on orders over $50" with gradient background), bottom nav (Home filled, Categories, Cart with badge, Profile), pull-to-refresh area. Every visible pixel accounted for.
> **Verdict:** Every element described including decorative and status elements → Score 4.

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

### Calibration Example — State Coverage

**Score 2 (Adequate):**
> Narrative documents only the default loaded state for a product listing screen: header, search bar, product grid with items, bottom navigation. No loading state, no error state for network failure, no empty state for zero results, no offline fallback. Core interaction elements are described but state analysis is absent.
> **Verdict:** Default state only; loading/error states missing on data-dependent screen → Score 2.

**Score 4 (Excellent):**
> Same product listing screen with full state enumeration: **Default** (loaded with products — grid populated, all interactive elements active), **Loading** (skeleton placeholders with shimmer animation replacing product cards, search bar disabled), **Error** (centered error illustration, "Something went wrong" heading, "Tap to retry" button, bottom nav still active), **Empty** (illustration of empty shelf, "No products found" heading, "Browse categories" CTA button), **Offline** (cached data shown with stale data banner at top, "You're offline" snackbar auto-dismisses after 3s, pull-to-refresh disabled).
> **Verdict:** All contextual states enumerated with visual diffs for data-dependent screen → Score 4.

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

### Calibration Example — Ambiguity

**Score 2 (Adequate):**
> "Tapping 'Submit' shows an appropriate success message and may navigate to a relevant screen. The loading indicator appears for some time before the result is shown. Error handling shows suitable feedback."
> **Issues:** "appropriate", "relevant", "some time", "suitable" — four vague qualifiers. A developer must guess the success message text, destination screen, loading duration threshold, and error feedback format.
> **Verdict:** Several vague descriptions with forbidden qualifier words → Score 2.

**Score 4 (Excellent):**
> "Tapping 'Submit' disables the button, replaces label with a spinner, and sends POST /orders. On 200: navigate (push) to Order Confirmation screen, show toast 'Order placed successfully!' for 3s. On 4xx: re-enable button, show inline error 'Please check your details and try again' in red (#E53935) below the form. On 5xx or timeout (>10s): show full-screen error state with 'Something went wrong' heading, 'Tap to retry' button."
> **Issues:** None. Every qualifier replaced with a specific value, target, or threshold. A developer could implement without questions.
> **Verdict:** Zero vague qualifiers, every statement implementation-ready → Score 4.

---

## Score Calculation

```
Total = Completeness + Interaction + States + Navigation + Ambiguity
Maximum = 20 points (each dimension max 4)

Thresholds (from config self_critique.thresholds):
  >= good.min = GOOD — proceed to sign-off without questions
  >= acceptable.min = ACCEPTABLE — generate targeted questions for weak dimensions
  < acceptable.min = NEEDS WORK — generate questions, iterate
```

---

## Reasoning Protocol (MANDATORY)

Apply this evidence-first scoring procedure for EVERY dimension. Do NOT jump to a score.

**For each dimension, execute these 4 steps in order:**

1. **List elements relevant to this dimension** — enumerate the specific narrative content that addresses this dimension (e.g., for Completeness: "Elements table has 18 entries; screenshot shows header, search bar, 6 product cards...")
2. **List gaps** — enumerate what is MISSING or insufficiently described (e.g., "Status bar content not mentioned; pull-to-refresh indicator absent; filter chips row omitted")
3. **Match to level description** — compare your evidence against the scoring table. Which level description best matches the combination of coverage and gaps?
4. **Anchor-check against levels 2 and 3** — explicitly ask: "Is this BETTER than level 2?" and "Does this REACH level 3?" If unsure, score conservatively (lower)

**Anti-pattern:** Scanning the narrative once, feeling "this seems good", and assigning a 3. The protocol requires enumerated evidence.

---

## Dimension-to-Question Category Mapping

When dimensions score 1-2, map them to question categories using this table:

| Weak Dimension | Primary Question Categories | Secondary Categories |
|---------------|---------------------------|---------------------|
| Completeness | CONTENT, BEHAVIOR | EDGE |
| Interaction Clarity | BEHAVIOR, ANIMATION | STATE |
| State Coverage | STATE, EDGE | CONTENT |
| Navigation Context | NAVIGATION, BEHAVIOR | — |
| Ambiguity | CONTENT, all others as needed | — |

Use this mapping to ensure generated questions target the right category. A weak Completeness score should produce CONTENT/BEHAVIOR questions, not NAVIGATION questions.

---

## Self-Consistency Check (Borderline Scores)

When total score falls within 2 points of the GOOD threshold (per `self_critique.thresholds.good.min` in config):

1. **Re-evaluate independently** — score all 5 dimensions a second time without referencing the first pass
2. **Take the lower total** — if the two passes produce different totals, use the lower one
3. **Report both passes** in the output format below

**Rationale:** Borderline false positives at the GOOD threshold skip question rounds entirely, leaving narrative gaps undiscovered. Conservative scoring ensures questions are generated when quality is uncertain.

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

### Borderline Check (include if total is within 2 points of GOOD threshold)
Borderline check: Pass 1 = {X}/20, Pass 2 = {Y}/20 → Final = {min(X,Y)}/20

### Weak Dimensions
[List dimensions scoring 1-2 with specific gaps]

### Question Categories Needed
[Map weak dimensions to question categories: BEHAVIOR, STATE, NAVIGATION, CONTENT, EDGE, ANIMATION]
```

---

## Self-Verification

Before submitting critique results:

1. All 5 dimensions have a score between 1 and 4 (no nulls, no zeros)
2. Total is the sum of all 5 dimension scores
3. Weak dimensions (scoring 1-2) have mapped question categories
4. Evidence column is populated for every dimension (no empty citations)
5. All failure modes from the Failure Mode Checklist verified as CLEAR

## CRITICAL RULES REMINDER

1. Use the 1-4 scale only
2. Score all 5 dimensions for every evaluation
3. Map weak dimensions to question categories
