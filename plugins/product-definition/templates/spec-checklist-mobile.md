# Specification Quality Checklist: [FEATURE NAME]

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: [DATE]
**Feature**: [Link to spec.md]
**Type**: Mobile Application (Android/iOS)

---

## 1. Problem Framing Canvas

- [ ] **Persona Defined**: "I am" section describes a concrete persona with 3+ pain points
- [ ] **Goals Clear**: "Trying to" states desired outcomes in one sentence
- [ ] **Barriers Identified**: "But" lists 3+ specific barriers/obstacles
- [ ] **Root Cause Found**: "Because" explains the empathetic root cause
- [ ] **Emotional Impact**: "Which makes me feel" captures persona emotions
- [ ] **Problem Statement**: Final statement is concise, powerful, and captures WHO/WHAT/WHY

---

## 2. Jobs-to-be-Done Analysis

- [ ] **Functional Jobs**: At least 2 tasks the user needs to perform
- [ ] **Social Jobs**: How the user wants to be perceived (or marked N/A with rationale)
- [ ] **Emotional Jobs**: Feelings the user seeks to achieve/avoid
- [ ] **Pains Mapped**: Challenges, costliness, common mistakes, unresolved problems
- [ ] **Gains Mapped**: Expectations, savings, adoption factors, life improvements
- [ ] **JTBD-Story Alignment**: Each user story traces back to a documented job

---

## 3. Epic Hypothesis

- [ ] **If/Then Statement**: Clear action, target persona, and expected outcome
- [ ] **Experiments Defined**: At least 2 Tiny Acts of Discovery to test assumption
- [ ] **Validation Measures**: Quantitative AND qualitative measures with timeframe
- [ ] **Pivot Criteria**: Clear thresholds for when to abandon/pivot

---

## 4. User Stories Quality

### Obstacle-Aware Format
- [ ] **All Stories Have "but" Clause**: Every story identifies an obstacle/constraint
- [ ] **Persona in Context**: Stories specify persona AND context, not just role
- [ ] **JTBD Alignment**: "so that I can" connects to documented jobs

### Gherkin Acceptance Criteria
- [ ] **Single When**: Each story has exactly ONE atomic action
- [ ] **Single Then**: Each story has exactly ONE observable outcome
- [ ] **Rich Context**: Multiple "Given" clauses load sufficient context
- [ ] **Testable**: QA can write automated tests from criteria

### Story Atomicity
- [ ] **Splitting Check Passed**: All stories pass the 4-point splitting check
- [ ] **No Compound Logic**: No AND/OR in When or Then clauses
- [ ] **Single Role**: Each story addresses one user type
- [ ] **Sprint-Sized**: Each story completable in one sprint or less

---

## 5. Content Quality

- [ ] **No Implementation Details**: No references to languages, frameworks, APIs, databases, or architecture
- [ ] **User-Centric**: Requirements describe user experience and business needs, not developer tasks
- [ ] **Written for Non-Technical Stakeholders**: Product managers, designers, and business owners can understand and validate without engineering background
- [ ] **Clean Document**: No `[TBD]`, `[NEEDS CLARIFICATION]`, or `?` placeholders remain
- [ ] **Structure Complete**: All mandatory spec sections present and filled

---

## 6. Requirement Completeness

- [ ] **Scope Bounded**: In scope and out of scope explicitly defined
- [ ] **Primary Flows Covered**: User scenarios address all main use cases
- [ ] **Edge Cases Identified**: Boundary conditions and unhappy paths documented
- [ ] **Dependencies Documented**: External systems and integration points identified
- [ ] **Assumptions Stated**: Key assumptions explicitly listed

---

## 7. UI States (Mobile-Specific)

*Mental model: Every screen has multiple faces — define them all.*

- [ ] **Loading Feedback**: User sees clear indication while waiting, for every async operation
- [ ] **Empty States**: Behavior defined for zero-data scenarios (first use, empty results, cleared filters)
- [ ] **Error Feedback by Severity**: Distinct feedback for minor (recoverable), blocking (action required), and field-level validation errors
- [ ] **Success Confirmation**: Feedback defined for completed actions
- [ ] **Disabled/Enabled Conditions**: Interactive elements have clear enable/disable rules
- [ ] **Keyboard Behavior**: When shown/dismissed, focus management, content visibility
- [ ] **Pull-to-Refresh**: Defined where applicable, with loading indicators
- [ ] **Skeleton Screens**: Considered for content-heavy screens vs spinners

---

## 8. Connectivity & Data Resilience (Mobile-Specific)

*Mental model: "The Tunnel Test" — what happens when connection drops mid-action?*

- [ ] **Offline Behavior**: What works, what doesn't, what user sees when offline
- [ ] **Degraded Network**: Behavior when connection is unstable or extremely slow (2G/3G)
- [ ] **Retry Approach**: Automatic vs user-triggered retries
- [ ] **Duplicate Action Prevention**: UI prevents accidental re-submission (debouncing)
- [ ] **Data Freshness**: When/how displayed data updates (cache policy)
- [ ] **Data Persistence**: What survives app closure (local storage strategy)
- [ ] **Conflict Resolution**: How conflicting edits are handled (if applicable)
- [ ] **Background Sync**: Behavior when app syncs in background

---

## 9. Interruption & State Resilience (Mobile-Specific)

*Mental model: The OS kills your app — what does the user lose?*

- [ ] **App Switch Recovery**: State preserved when user leaves and returns
- [ ] **Incoming Interruption**: Behavior during calls, notifications, system alerts
- [ ] **Long Absence**: Behavior when user returns after hours/days (session expiry)
- [ ] **Orientation Change**: Portrait/landscape behavior (or explicit lock)
- [ ] **Partial Input Preservation**: Draft data survives interruptions
- [ ] **Process Death Recovery**: Critical state survives Android process death
- [ ] **Low Memory Behavior**: Graceful degradation under memory pressure

---

## 10. Navigation & User Control (Mobile-Specific)

- [ ] **Escape Routes**: How user cancels, goes back, or exits from any state
- [ ] **Destructive Action Confirmation**: Warning before irreversible actions
- [ ] **In-Progress Cancellation**: Can user abort? What happens to partial data?
- [ ] **Deep Linking**: External entry points defined (URLs, notifications, widgets)
- [ ] **Back Button Behavior**: Android back vs in-app back navigation
- [ ] **Gesture Navigation**: Edge swipes, system gestures interaction
- [ ] **Bottom Sheet Behavior**: Dismiss behavior, swipe-to-dismiss rules

---

## 11. Platform & Accessibility (Mobile-Specific)

### Permissions
- [ ] **Permissions as UX Flow**: "Why" and "When" for each permission, not just "which"
- [ ] **Permission Denial Handling**: Graceful degradation when user declines
- [ ] **Permission Rationale**: Pre-prompt explanation for sensitive permissions
- [ ] **Settings Redirect**: Path to re-enable denied permissions

### Accessibility
- [ ] **Screen Reader Support**: All interactive elements have content descriptions
- [ ] **Contrast Ratios**: Text meets WCAG AA standards (4.5:1 normal, 3:1 large)
- [ ] **Touch Targets**: Minimum 48dp touch targets for all interactive elements
- [ ] **Focus Order**: Logical focus traversal for keyboard/switch access
- [ ] **Motion Sensitivity**: Reduced motion option for animations

### Adaptation
- [ ] **Theme Adaptation**: Light/dark behavior (or explicitly scoped out)
- [ ] **Scalable Text**: Behavior with increased system font size (up to 200%)
- [ ] **Localization**: Supported languages; RTL layout if applicable
- [ ] **Display Cutouts**: Notch/punch-hole handling
- [ ] **Foldables/Tablets**: Multi-window, large screen behavior (or explicit exclusion)

---

## 12. Success Criteria

- [ ] **Measurable**: All criteria include specific metrics (time, %, count)
- [ ] **Technology-Agnostic**: No mention of APIs, databases, or frameworks
- [ ] **User-Focused**: Describes outcomes from user/business perspective
- [ ] **Verifiable**: Can be tested without knowing implementation details
- [ ] **Mobile-Aware**: Criteria account for mobile context (battery, network, interruptions)
- [ ] **Cross-Validated**: Each criterion traces back to a functional requirement

---

## 13. Testability (The Gate)

### Basic Testability
- [ ] **All FRs Have AC**: Every functional requirement has acceptance criteria
- [ ] **Binary Pass/Fail**: All criteria are unambiguous
- [ ] **QA Ready**: Test cases can be written solely from this document
- [ ] **No Implementation Leakage**: AC don't depend on technical implementation
- [ ] **Device Matrix Defined**: Target devices/OS versions specified
- [ ] **E2E Testable**: Critical flows can be automated with mobile-mcp
- [ ] **Feature Completeness**: Feature meets all measurable outcomes defined in Success Criteria

### V-Model Test Alignment (Mobile)
- [ ] **ViewModel State Logic**: ACs describing state changes are unit-testable
- [ ] **Repository/Data Flow**: ACs describing data persistence are integration-testable
- [ ] **User Journey ACs**: ACs describing user flows are E2E-testable via mobile-mcp
- [ ] **UI Appearance ACs**: ACs describing visual elements are screenshot-verifiable
- [ ] **Offline Edge Cases**: Offline scenarios have corresponding test scenarios

### Mobile Test Coverage Readiness
- [ ] **Happy Path Clear**: Primary success scenario fully described for E2E
- [ ] **Error States Defined**: Snackbar/dialog/inline error scenarios documented
- [ ] **Empty States Defined**: Zero-data scenarios documented per screen
- [ ] **Loading States Defined**: Skeleton/spinner scenarios documented
- [ ] **Permission Denial Flows**: Denied permission scenarios documented
- [ ] **Process Death Recovery**: State restoration scenarios documented

---

## 14. V-Model Traceability (Test Strategy)

> Validates specification readiness for V-Model test planning.

### Acceptance Criteria Format
- [ ] **Gherkin Format**: All AC use Given/When/Then structure
- [ ] **Single When Clause**: Each AC has exactly ONE action (atomic)
- [ ] **Single Then Clause**: Each AC has exactly ONE outcome (verifiable)
- [ ] **Testable Assertions**: Then clauses are observable/measurable on device

### Test Level Mapping (Mobile)
- [ ] **Unit-Testable Logic**: ViewModels, UseCases, Repositories testable in isolation
- [ ] **Component Boundaries Clear**: ViewModel ↔ Repository, Repository ↔ Database identifiable
- [ ] **User Flows Documented**: E2E scenarios extractable (can be automated with mobile-mcp)
- [ ] **Visual States Enumerated**: UI states documented per screen (matching Figma)

### Risk-Based Testing (Mobile)
- [ ] **Failure Modes Identified**: Network, permissions, process death documented
- [ ] **Critical Paths Marked**: Must-work scenarios distinguishable
- [ ] **Mobile Edge Cases Listed**: Offline, rotation, interruption scenarios
- [ ] **Error Recovery Defined**: How users recover from mobile-specific failures

---

## Checklist Summary

| Section | Items | Passed |
|---------|-------|--------|
| Problem Framing | 6 | [ ]/6 |
| JTBD Analysis | 6 | [ ]/6 |
| Epic Hypothesis | 4 | [ ]/4 |
| User Stories | 11 | [ ]/11 |
| Content Quality | 5 | [ ]/5 |
| Requirements | 5 | [ ]/5 |
| UI States | 8 | [ ]/8 |
| Connectivity | 8 | [ ]/8 |
| Interruption | 7 | [ ]/7 |
| Navigation | 7 | [ ]/7 |
| Platform & A11y | 14 | [ ]/14 |
| Success Criteria | 6 | [ ]/6 |
| Testability (Basic) | 7 | [ ]/7 |
| Testability (V-Model) | 5 | [ ]/5 |
| Test Coverage (Mobile) | 6 | [ ]/6 |
| V-Model Traceability | 12 | [ ]/12 |
| **TOTAL** | **117** | **[ ]/117** |

**Passing Threshold**: ≥105/117 items (90%) to proceed to `/sdd:02-plan`

---

## Notes

{Issues found during validation}

---

## Validator Sign-off

| Validator | Date | Result |
|-----------|------|--------|
| business-analyst | | PASS / FAIL |
| PAL Consensus | | APPROVED / CONDITIONAL / REJECTED |
