# Design-Specification Correlation Protocol

This reference defines the 7-step process for correlating Figma designs with specification requirements.

**Trigger:** Execute this protocol when `<figma-context>` is provided to the BA agent.

---

## Protocol Overview

| Step | Focus | Output |
|------|-------|--------|
| 1 | Inventory Screens | Screen list with nodeIds |
| 2 | Map to Requirements | Requirement → Screen mapping |
| 3 | Identify Gaps | Missing screen coverage |
| 4 | Identify Extras | Orphan screens |
| 5 | Analyze UX Flow | Implied user journeys |
| 6 | Find Edge Cases | Missing states |
| 7 | Synthesize | Clarification questions |

---

## Step 1: Inventory Screens

**Purpose:** List all captured Figma screens by name and nodeId.

**Format:**

```
Screens captured:
1. {Screen Name A} (nodeId: X:Y)
2. {Screen Name B} (nodeId: X:Y)
3. {Screen Name C} (nodeId: X:Y)
...
```

**Example:**

```
Screens captured:
1. Login Screen (nodeId: 123:456)
2. Home Dashboard (nodeId: 123:789)
3. Profile View (nodeId: 124:100)
4. Settings Page (nodeId: 124:200)
```

---

## Step 2: Map to Requirements

**Purpose:** For each user story/requirement, identify which screen(s) address it.

**Confidence Levels:**
- **HIGH:** Clear visual match (element visible, text present)
- **MEDIUM:** Reasonable inference from context
- **LOW:** Ambiguous, multiple interpretations possible
- **NO MATCH:** No corresponding screen found (GAP)

**Format:**

```
Requirement → Screen Mapping:
- US-001: {requirement} → "{Screen Name}" ({nodeId}) [CONFIDENCE]
- US-002: {requirement} → "{Screen Name}" ({nodeId}) [CONFIDENCE]
- US-003: {requirement} → ??? [NO MATCH - GAP]
```

**Example:**

```
Requirement → Screen Mapping:
- US-001: User Login → "Login Screen" (123:456) [HIGH]
- US-002: View Dashboard → "Home Dashboard" (123:789) [HIGH]
- US-003: View Profile → "Profile View" (124:100) [MEDIUM]
- US-004: Edit Settings → "Settings Page" (124:200) [MEDIUM]
- US-005: Error Recovery → ??? [NO MATCH - GAP]
```

---

## Step 3: Identify Gaps

**Purpose:** Flag requirements without corresponding screens for design team attention.

**Format:**

```
Design Gaps:
- US-XXX: {requirement} - {reason for gap}
- US-YYY: {requirement} - {reason for gap}
```

**Example:**

```
Design Gaps:
- US-005: Error Recovery - no error state screens designed
- US-008: Offline Mode - no offline state screens captured
- US-012: Onboarding Flow - only first screen captured, multi-step flow incomplete
```

**Actions:**
- Flag for design team review
- Add clarification questions about missing designs
- Document in spec as "Design Pending"

---

## Step 4: Identify Extras

**Purpose:** Find screens that don't map to any requirement (potential missing requirements).

**Format:**

```
Unmapped Screens:
- "{Screen Name}" ({nodeId}) - not in requirements
  → Possible purpose: {inference}
  → Action: {Add requirement OR Question design necessity}
```

**Example:**

```
Unmapped Screens:
- "Onboarding Welcome" (456:123) - not in requirements
  → Possible purpose: First-time user experience
  → Action: Add US-XXX for onboarding flow?

- "Premium Upgrade" (456:456) - not in requirements
  → Possible purpose: Monetization/upsell
  → Action: Confirm if premium tier is in scope
```

**Actions:**
- Consider adding requirements for valuable features
- Question whether orphan screens should be in scope
- Document decision either way

---

## Step 5: Analyze UX Flow

**Purpose:** Document the implied user journey from screen sequence.

**Format:**

```
Implied Flow:
{Screen A} → {Screen B} → {Screen C} → ...

Flow branches:
- From {Screen X}:
  - Success → {Screen Y}
  - Error → {Screen Z}
```

**Example:**

```
Implied Flow:
Login → Home Dashboard → Profile View → Settings

Flow branches:
- From Login:
  - Success → Home Dashboard
  - Failure → Login (with error)
  - Forgot Password → Password Reset (NOT CAPTURED)

- From Profile View:
  - Edit → Edit Profile (NOT CAPTURED)
  - Logout → Login
```

**Actions:**
- Identify flow gaps (missing intermediate screens)
- Document expected navigation patterns
- Flag unclear transitions

---

## Step 6: Find Edge Cases

**Purpose:** Identify missing UI states that should be designed.

**Checklist:**

| State | Required For | Status |
|-------|--------------|--------|
| Empty state | Data lists, search results | [ ] Present / [ ] Missing |
| Loading state | Async operations | [ ] Present / [ ] Missing |
| Error state | Form submissions, API calls | [ ] Present / [ ] Missing |
| Offline state | Network-dependent features | [ ] Present / [ ] Missing |
| Permission denied | Protected features | [ ] Present / [ ] Missing |

**Format:**

```
Missing States by Screen:

{Screen Name}:
- [ ] Empty state (no data)
- [ ] Loading state (in progress)
- [x] Error state (failure) - PRESENT
- [ ] Offline state (no connectivity)
- [ ] Permission denied state

{Another Screen}:
- [x] Empty state - PRESENT
- [ ] Loading state
...
```

**Example:**

```
Missing States by Screen:

Home Dashboard:
- [ ] Empty state (new user, no activity)
- [ ] Loading state (data fetching)
- [ ] Error state (API failure)
- [ ] Offline state (cached data display?)

Profile View:
- [x] Default state - PRESENT
- [ ] Loading state
- [ ] Error state (profile fetch failed)
- [ ] Editing state (inline edit?)
```

---

## Step 7: Synthesize

**Purpose:** Generate clarification questions based on findings.

**Question Categories:**

1. **LOW Confidence Mappings:** Clarify ambiguous screen-requirement relationships
2. **Identified Gaps:** Request missing screen designs
3. **Missing Edge Cases:** Request state designs
4. **Orphan Screens:** Clarify purpose or scope

**Format:**

```
Clarification Questions (Design Correlation):

1. [GAP] {Question about missing screen}
2. [EDGE CASE] {Question about missing state}
3. [LOW CONFIDENCE] {Question about ambiguous mapping}
4. [ORPHAN] {Question about unmapped screen}
```

**Example:**

```
Clarification Questions (Design Correlation):

1. [GAP] What should the error recovery screen show when API calls fail?
2. [GAP] Is there a design for the onboarding flow (screens 2-N)?
3. [EDGE CASE] What does the Home Dashboard show when user has no activity?
4. [EDGE CASE] What loading indicator should appear during data fetch?
5. [LOW CONFIDENCE] Does "Settings Page" cover both app settings AND account settings?
6. [ORPHAN] Is the "Premium Upgrade" screen in scope for this feature?
```

---

## Output Format: @FigmaRef Annotations

Add `@FigmaRef` annotations to requirements that have corresponding designs:

```markdown
### US-001: User Login

As a user, I want to log in with my credentials,
so that I can access my account.

@FigmaRef(nodeId="123:456", screen="Login Screen")

**Acceptance Criteria:**
- Given I am on the login screen
- When I enter valid credentials and tap "Login"
- Then I am redirected to the home screen
```

---

## Edge Case Handling Matrix

| Situation | Expected Behavior |
|-----------|-------------------|
| Figma context empty/missing | Proceed without correlation. Add note: "Design mocks pending" |
| Single screen for multi-step flow | Flag gap: "Multi-step flow requires additional screens" |
| Annotations contradict requirements | Prioritize written requirements, flag contradiction in clarifications |
| Screen has unclear purpose | Add clarification: "What requirement does [Screen] address?" |
| Duplicate screens (variants) | Consolidate, note variants exist in design notes |
| Very many screens (>20) | Group by flow/section, summarize in mapping |

---

## Few-Shot Example

**Input Requirement:**
> As a user, I want to view my profile information so that I can verify my details.

**Figma Context:**
> Screen: "Profile View" (nodeId: "123:456")
> Elements: Avatar, Name label, Email label, Edit button

**Output with Correlation:**

```markdown
### US-003: View Profile

As a user, I want to view my profile information,
so that I can verify my account details.

@FigmaRef(nodeId="123:456", screen="Profile View")

**Acceptance Criteria:**
- Given I am logged in
- When I navigate to my profile
- Then I see my avatar, name, and email

**Design Notes:**
- Edit button present → implies US-004 (Edit Profile) may be needed
- Missing: Loading state, Error state (flagged for design team)
```

**Clarification Questions Generated:**
1. What should the profile screen show while loading?
2. What error message appears if profile fetch fails?
3. The design shows an "Edit" button - should editing profile be in scope?

---

## Integration with Self-Critique

When Figma context is provided, the Self-Critique rubric adds a 6th dimension:

**Design Alignment (1-4):**

| Score | Observable Characteristics |
|-------|---------------------------|
| 1 (Poor) | Ignores Figma context entirely. No @FigmaRef annotations. No design-related questions. |
| 2 (Adequate) | References some screens but mapping incomplete or contains errors. Missing confidence levels. |
| 3 (Good) | Maps most requirements to screens with confidence. Identifies major gaps. Some edge cases noted. |
| 4 (Excellent) | Full correlation with HIGH/MEDIUM/LOW confidence. All gaps identified with actionable feedback. All edge case states flagged. Clear synthesis into clarification questions. |

**Scoring Adjustment:**
- Without Figma: 5 dimensions × 4 = 20 points max
- With Figma: 6 dimensions × 4 = 24 points (scale to 20 for consistency)

---

## Checkpoint Output

After completing Design-Spec Correlation, emit:

```markdown
<!-- CHECKPOINT: DESIGN_CORRELATION -->
Phase: DESIGN_CORRELATION
Status: completed
Timestamp: {ISO_DATE}
Key Outputs:
- Screens correlated: [N] of [TOTAL]
- Gaps identified: [N]
- Edge cases flagged: [N]
- Clarification questions: [N]
<!-- END_CHECKPOINT -->
```
