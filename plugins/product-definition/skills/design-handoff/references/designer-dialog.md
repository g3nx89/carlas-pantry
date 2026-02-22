---
stage: "4"
description: "Designer Dialog — focused Q&A about gaps only"
agents_dispatched: []
artifacts_written: ["design-handoff/gap-report.md (updated with designer answers)"]
config_keys_used: ["designer_dialog.questions_per_batch", "designer_dialog.screen_ordering", "designer_dialog.accept_remaining_option", "designer_dialog.cross_screen_confirmation", "gap_analysis.severity_levels"]
---

# Stage 4 — Designer Dialog (Orchestrator-Mediated)

> Executed directly by orchestrator via AskUserQuestion. No coordinator dispatch.

## Purpose

Fill gaps that Figma cannot express — behaviors, states, animations, data contracts, logic,
and edge cases from the gap report (Stage 3). Never ask about layouts, colors, spacing, or
anything visible in Figma. If a screen has zero gaps, skip it entirely.

---

## CRITICAL RULES

1. **Gap report is the ONLY source of questions** — never invent questions beyond it
2. **Never ask about visual properties** — if a coding agent can see it in Figma, do not ask
3. **Answers are final** — once recorded, never re-ask or modify
4. **Batch size from config** — `designer_dialog.questions_per_batch` (default 4), never exceed
5. **Checkpoint after every screen** — update state before moving to next screen
6. **Accept-remaining is one-way** — once accepted, do not re-open

---

## Step 4.1: Pre-Dialog Summary

Present gap overview before starting questions:

```
AskUserQuestion:

## Gap Report Summary

| Screen | CRITICAL | IMPORTANT | NICE_TO_HAVE | Total |
|--------|----------|-----------|--------------|-------|
| Login  | 2        | 3         | 1            | 6     |
| Home   | 1        | 4         | 2            | 7     |
| Cart   | 3        | 1         | 0            | 4     |
| **Total** | **6** | **8**     | **3**        | **17** |

I will ask about each screen's gaps in batches of 4, CRITICAL first. Ready to begin?
```

If designer requests a different order, honor it (overrides config default).

## Step 4.2: Determine Screen Order

Per `designer_dialog.screen_ordering`:
- `most_gaps_first` — descending by total gap count, ties broken by CRITICAL then IMPORTANT
- `figma_page_order` — order from Figma page as recorded in state `screens` array

Exclude screens with zero gaps.

---

## Step 4.3: Per-Screen Loop

For each screen in order:

**Announce** the screen name and gap count, then present batches of up to
`questions_per_batch` gaps, ordered CRITICAL > IMPORTANT > NICE_TO_HAVE.

### Question Format

```
AskUserQuestion:

## Cart — Questions 1-4 of 6

**1. [CRITICAL | behaviors]** What happens when the user taps "Place Order"
while the cart contains out-of-stock items?

**2. [CRITICAL | states]** What should the screen show during payment
processing? (loading indicator type, disabled controls, timeout behavior)

**3. [IMPORTANT | logic]** If a coupon exceeds the cart total, is the
remaining balance stored as credit or forfeited?

**4. [IMPORTANT | edge_cases]** What happens if the session expires
mid-checkout? (redirect target, cart preservation, error message)

---
For each question, describe the expected behavior. Reply "N/A" if not applicable.
```

Each question maps 1:1 to a gap entry. After the designer responds, update each gap in
the gap report and increment `screens[].questions_answered` in state:

```yaml
# Each gap entry gains:
designer_answer: "{answer text}"
answered_at: "{ISO_TIMESTAMP}"
```

Continue batching until all gaps for the screen are answered, then checkpoint and advance.

### "Accept Remaining" Option

After completing each screen (not the first), if `accept_remaining_option` is `true`
AND remaining screens exist:

```
AskUserQuestion:

## Progress: 2/5 screens done

Remaining: Home (7 gaps), Profile (3 gaps), Settings (2 gaps)

(A) Continue to next screen (Home — 7 gaps)
(B) Accept remaining gaps as-is — coding agent will use best judgment
```

On (B): mark all remaining gaps as `designer_answer: "ACCEPTED_AS_IS"`, log decision
in progress log, skip to Step 4.5.

---

## Step 4.4: Missing Screen Descriptions (Option C Items)

After per-screen gaps are done, check state for missing screens with
`designer_decision: "document_only"` (Option C from Stage 3.5).

```
AskUserQuestion:

## Missing Screen: Delete Confirmation (supplement-only)

**Reason:** Destructive action on Cart screen has no confirmation dialog in Figma
**Classification:** MUST_CREATE

No Figma screen exists. Please describe for the coding agent:
1. **Layout intent** — rough structure (e.g., "centered modal with icon + two buttons")
2. **Content** — text, labels, placeholder values
3. **Behavior** — trigger, actions, navigation after
4. **States** — loading/error variations if applicable

If it should mirror an existing screen's layout, name that screen.
```

Record in gap report: `supplement_description: "{text}"`, `described_at: "{ISO_TIMESTAMP}"`.

---

## Step 4.5: Cross-Screen Pattern Confirmation

**Guard:** Only if `designer_dialog.cross_screen_confirmation` is `true`.

Review state `patterns` section (`shared_behaviors`, `common_transitions`,
`global_edge_cases`). Confirm each pattern works identically across all screens.

```
AskUserQuestion:

## Cross-Screen Pattern Confirmation

**1. Pull-to-refresh** (Home, Search Results, Order History)
   Answer: "Spinner at top, refreshes data, hides after 2s max"
   → Same on all 3 screens? If not, describe differences.

**2. Session expiry** (Checkout, Profile, Settings)
   Answer: "Redirect to login, preserve navigation stack"
   → Same on all 3 screens? If not, describe differences.

**3. Network error toast** (all API screens)
   Answer: "Bottom toast, 3s auto-dismiss, retry button"
   → Same everywhere? If not, describe differences.

Reply "Confirmed" or describe the exception per pattern.
```

Record in state:
```yaml
patterns:
  shared_behaviors:
    - name: "pull-to-refresh"
      screens: ["Home", "Search Results", "Order History"]
      behavior: "Spinner at top, refreshes data, hides after 2s max"
      confirmed: true
      exceptions: []
    - name: "session-expiry"
      screens: ["Checkout", "Profile", "Settings"]
      behavior: "Redirect to login, preserve navigation stack"
      confirmed: true
      exceptions:
        - screen: "Checkout"
          difference: "Also saves cart state before redirect"
```

---

## Step 4.6: State Updates & Checkpoint

After dialog completion, append to state progress log:

```markdown
## Stage 4 — Designer Dialog Complete

- Screens with gaps: {N}
- Questions asked: {N}, answered: {N}, accepted as-is: {N}
- Option C descriptions: {N}
- Cross-screen patterns confirmed: {N} ({E} with exceptions)
- Completed at: {ISO_TIMESTAMP}
```

The gap report now contains inline designer answers — primary input for Stage 5.

---

## Exit Conditions

Dialog is complete when ALL hold:
1. Every gap has `designer_answer` or `ACCEPTED_AS_IS`
2. Every Option C missing screen has `supplement_description`
3. Cross-screen patterns confirmed (if enabled in config)

Orchestrator advances `current_stage` to `"5"` and dispatches supplement generation.

---

## Resume Protocol

On interrupted workflow re-entry:
1. Find first screen where `questions_answered < questions_total`
2. Find first gap in that screen without `designer_answer`
3. Show: "Resuming: {DONE}/{TOTAL} screens, currently on {SCREEN} (Q{N} of {M})"
4. Continue from the next unanswered gap

---

## Batch Mode File Format

When `workflow_mode == "batch"`, Stage 4 is replaced with file-based Q&A. Instead of AskUserQuestion, the orchestrator writes gaps to a file for offline answering.

**Output file:** `{WORKING_DIR}/QUESTIONS-HANDOFF.md`

```markdown
# Design Handoff — Gap Questions

> Answer each question inline. Mark your answer below the question.
> When done, re-run /product-definition:design-handoff to continue.

## Screen: {ScreenName} ({N} gaps)

### 1. [CRITICAL | behaviors] What happens on Submit tap?
**Your answer:**


### 2. [CRITICAL | states] What loading state should display?
**Your answer:**


---

## Cross-Screen Patterns

### Pull-to-refresh (Home, SearchResults, OrderHistory)
Does this work identically on all screens? If not, describe differences.
**Your answer:**

```

**Resume protocol:** On re-invocation, the orchestrator reads `QUESTIONS-HANDOFF.md`, extracts answers from `**Your answer:**` blocks, and records them in the gap report as `designer_answer` entries. Empty answers are treated as unanswered — the orchestrator re-prompts for those specific questions.

---

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|-------------|-----------------|
| Asking about colors, spacing, or layout | Only ask about gap categories |
| Inventing questions beyond the gap report | 1:1 mapping to gap entries |
| Batching across multiple screens | One screen at a time |
| Modifying a recorded answer | Answers are final |
| Skipping cross-screen confirmation | Always confirm (unless config disables) |
| Offering accept-remaining on first screen | Only after one screen is complete |
