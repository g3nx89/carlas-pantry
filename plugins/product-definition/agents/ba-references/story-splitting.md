# Story Splitting Protocol

> This rule is invoked when user stories fail the "atomic story" check.
> Related: `business-analyst.md` Phase 4.5, `spec-template.md` Splitting Check

---

## Core Principle

**A user story is atomic when it has exactly ONE `When` and ONE `Then` in its acceptance criteria.**

Multiple `When` or `Then` clauses indicate a compound story that must be split.

---

## Quick Reference: 8 Splitting Criteria

Apply these criteria **IN ORDER**. Stop at the first one that applies.

| # | Trigger Question | Split Along |
|---|------------------|-------------|
| 1 | Multiple workflow steps? | Workflow steps |
| 2 | Business rule variations? | Business rules |
| 3 | Data variations? | Data types |
| 4 | Complex acceptance criteria? | When/Then pairs |
| 5 | Major effort required? | Effort milestones |
| 6 | External dependencies? | Dependencies |
| 7 | Significant DevOps effort? | DevOps steps |
| 8 | None apply? | Tiny Acts of Discovery |

---

## Detailed Criteria with Examples

### Criterion 1: Multiple Workflow Steps

**Trigger:** Story describes a sequence of user actions that could be done independently.

**Before (Compound):**
```
As a user, I want to register, verify my email, and set up my profile
so that I can start using the app.
```

**After (Split):**
```
US-001: User Registration
As a new user, I want to register with email/password,
so that I can create an account,
but I might abandon if the form is too long.

US-002: Email Verification
As a registered user, I want to verify my email via link,
so that I can prove ownership of my email,
but the link might expire or land in spam.

US-003: Profile Setup
As a verified user, I want to set up my profile,
so that I can personalize my experience,
but I might skip optional fields.
```

---

### Criterion 2: Business Rule Variations

**Trigger:** Story has different behaviors based on business rules or user types.

**Before (Compound):**
```
As a user, I want to pay for my order.
```

**After (Split by payment method):**
```
US-001: Pay with Credit Card
As a customer, I want to pay with credit card,
so that I can complete my purchase immediately,
but card validation might fail.

US-002: Pay with Digital Wallet
As a customer, I want to pay with Google Pay/Apple Pay,
so that I can pay without entering card details,
but my wallet might not be set up.

US-003: Pay with Bank Transfer
As a customer, I want to pay via bank transfer,
so that I can use my preferred payment method,
but confirmation might be delayed.
```

---

### Criterion 3: Variations in Data

**Trigger:** Story handles multiple data types that require different processing.

**Before (Compound):**
```
As a user, I want to upload files to my profile.
```

**After (Split by data type):**
```
US-001: Upload Profile Image
As a user, I want to upload a profile image (JPG/PNG),
so that I can personalize my account,
but the image might exceed size limits.

US-002: Upload Documents
As a user, I want to upload documents (PDF),
so that I can share certifications,
but the file might be corrupted.

US-003: Upload Videos
As a user, I want to upload short videos,
so that I can showcase my work,
but upload might fail on slow connections.
```

---

### Criterion 4: Complex Acceptance Criteria

**Trigger:** Acceptance criteria have multiple `When` actions or `Then` outcomes.

**Red Flag Example:**
```gherkin
Scenario: User submits registration form
Given user is on registration page
When user fills all required fields
And user clicks submit                    # Multiple When!
Then form is validated
And user sees confirmation message        # Multiple Then!
And email is sent to user
And analytics event is fired
```

**After (Split by outcome):**
```gherkin
# US-001: Form Validation
Scenario: Registration form validates input
Given user is on registration page with all fields filled
When user clicks submit
Then form validation errors are displayed for invalid fields

# US-002: Registration Confirmation
Scenario: User sees registration confirmation
Given user has submitted valid registration form
When registration is processed successfully
Then user sees confirmation message with next steps

# US-003: Registration Email
Scenario: System sends welcome email
Given user has completed registration
When registration is confirmed
Then welcome email is sent to user's email address

# US-004: Registration Analytics
Scenario: Registration event is tracked
Given user has completed registration
When registration is confirmed
Then registration_complete event is sent to analytics
```

---

### Criterion 5: Major Effort Required

**Trigger:** Story requires significant development effort across multiple areas.

**Before (Compound):**
```
As a user, I want to see a dashboard with my activity metrics.
```

**After (Split by effort milestone):**
```
US-001: Dashboard Empty State
As a new user, I want to see an empty dashboard with onboarding hints,
so that I understand what the dashboard will show,
but I might not know how to generate data.

US-002: Dashboard Data Display
As an active user, I want to see my activity metrics visualized,
so that I can understand my usage patterns,
but data might be incomplete.

US-003: Dashboard Filters
As a power user, I want to filter dashboard by date range,
so that I can analyze specific periods,
but filter combinations might return no data.

US-004: Dashboard Export
As a user, I want to export dashboard data,
so that I can share or analyze externally,
but export might timeout for large datasets.
```

---

### Criterion 6: External Dependencies

**Trigger:** Story depends on external systems or APIs.

**Before (Compound):**
```
As a user, I want to sync my data with Google Calendar.
```

**After (Split by dependency):**
```
US-001: Calendar Sync - Mock Integration
As a user, I want to see calendar sync UI,
so that I can understand the feature,
but this uses mock data for development.

US-002: Calendar Sync - OAuth Flow
As a user, I want to authenticate with Google,
so that I can grant calendar access,
but OAuth might be rejected or revoked.

US-003: Calendar Sync - Read Events
As an authenticated user, I want to see my Google Calendar events,
so that I can view my schedule in-app,
but API rate limits might apply.

US-004: Calendar Sync - Write Events
As an authenticated user, I want to create events in Google Calendar,
so that I can manage my schedule from the app,
but write permissions might be denied.
```

---

### Criterion 7: Significant DevOps Effort

**Trigger:** Story requires infrastructure or deployment changes.

**Before (Compound):**
```
As a team, we want to deploy the new feature to production.
```

**After (Split by DevOps step):**
```
US-001: CI Pipeline Setup
As a developer, I want CI to run tests on every PR,
so that I catch issues early,
but pipeline might timeout on large test suites.

US-002: CD Pipeline Setup
As a developer, I want automatic deployment to staging,
so that I can test in production-like environment,
but deployment might fail due to config issues.

US-003: Production Deployment
As a release manager, I want controlled rollout to production,
so that I can minimize risk,
but rollback might be needed.

US-004: Monitoring Setup
As an operator, I want alerts for the new feature,
so that I can respond to issues quickly,
but alert fatigue might occur.
```

---

### Criterion 8: Tiny Acts of Discovery (TADs)

**Trigger:** None of the above criteria apply, but story is still too large or unclear.

**Use TADs to:**
- **Spike:** Time-boxed investigation to reduce unknowns
- **Prototype:** Quick implementation to validate approach
- **User Interview:** Direct feedback to clarify requirements

**Example TAD Stories:**
```
SPIKE-001: Investigate Payment Provider APIs
As a developer, I want to evaluate Stripe vs Braintree APIs,
so that I can recommend the best option,
but documentation might be incomplete.
Timebox: 2 days
Output: Recommendation document

PROTOTYPE-001: Validate Gesture Navigation
As a designer, I want to prototype swipe-to-delete,
so that I can test with users,
but gesture might conflict with system navigation.
Timebox: 1 day
Output: Interactive prototype

INTERVIEW-001: Clarify Export Requirements
As a PM, I want to interview 3 power users about export needs,
so that I can specify the right formats,
but users might have conflicting needs.
Timebox: 3 days
Output: Requirements summary
```

---

## Android-Specific Splitting Patterns

### Screen State Splitting

Large screens with multiple states should be split:

```
US-001: [Screen] Empty State
US-002: [Screen] Loading State
US-003: [Screen] Content State
US-004: [Screen] Error State
US-005: [Screen] Offline State
```

### Navigation Flow Splitting

Complex navigation should be split per destination:

```
US-001: Navigate to [Screen] from [Source]
US-002: Navigate to [Screen] with deep link
US-003: Navigate back from [Screen] with result
```

### Form Splitting

Large forms should be split by validation group:

```
US-001: [Form] Field validation
US-002: [Form] Cross-field validation
US-003: [Form] Server-side validation
US-004: [Form] Submit success flow
US-005: [Form] Submit error handling
```

---

## Anti-Patterns

### Layer-Based Splitting

```
BAD: "Backend story" + "Frontend story"
```
- Creates integration risk
- Neither story is independently valuable
- Handoff overhead

### Person-Based Splitting

```
BAD: "Dev A's part" + "Dev B's part"
```
- Creates artificial dependencies
- Breaks ownership
- Coordination overhead

### Technical-Component Splitting

```
BAD: "Database story" + "API story" + "UI story"
```
- No user value in isolation
- Integration testing nightmare
- Violates vertical slicing

### Correct: Value-Based Splitting

```
GOOD: Each story delivers independently testable user value
```
- User can verify completion
- Can be released independently
- No artificial dependencies

---

## Splitting Checklist

Before finalizing a story, verify:

- [ ] Exactly ONE `When` clause in acceptance criteria
- [ ] Exactly ONE `Then` clause in acceptance criteria
- [ ] Story delivers value independently (user can verify)
- [ ] Story can be completed in one sprint (or less)
- [ ] No hidden dependencies on other stories in same sprint
- [ ] Clear "done" definition without ambiguity

If any check fails, apply the 8 criteria to split.

---

## Integration with Gherkin

The splitting criteria directly map to Gherkin structure:

| Gherkin Issue | Splitting Action |
|---------------|------------------|
| Multiple `Given` | OK - context can be rich |
| Multiple `When` | SPLIT - one action per story |
| Multiple `Then` | SPLIT - one outcome per story |
| `And` after `When` | SPLIT - compound action |
| `And` after `Then` | SPLIT - compound outcome |

---

## References

- [The Humanizing Work Guide to Splitting User Stories](https://www.humanizingwork.com/the-humanizing-work-guide-to-splitting-user-stories/)
- Richard Lawrence & Peter Green's Splitting Flowchart
- Mike Cohn's User Story Format
