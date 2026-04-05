---
name: code-review
description: >-
  Review code after completing a task, phase, or sprint. Reads .harness/analysis.json
  for review_granularity to determine when review is mandatory. Runs two stages in
  sequence: spec compliance first ("did you build what was asked?"), then code quality
  ("is it well-built?"). Writes review artifacts to .harness/reviews/ for gate verification.
---

# Code Review

Two-stage review after implementation: spec compliance first, then code quality. The harness
gates block progress until both stages pass and artifacts are written.

**Core principle:** Review is not optional. The gate enforces it. Do it right the first time.

---

## Project Context

Read `.harness/analysis.json` at the start of any review session. The key field is:

```json
{
  "review_granularity": "per-task" | "per-phase" | "per-sprint"
}
```

If `analysis.json` does not exist, default to **per-task** behavior.

---

## When to Review

**Mandatory triggers** — the harness gate will block you if skipped:

| Granularity | Mandatory trigger |
|-------------|-------------------|
| `per-task` | After every task completes |
| `per-phase` | At each phase boundary before starting the next phase |
| `per-sprint` | Before merging to main |

**Optional but valuable:**
- When stuck — a fresh-eye spec review often surfaces the real issue
- Before a refactor — establish a baseline first
- After a complex bug fix — verify the fix didn't introduce drift

---

## Stage 1: Spec Compliance

**Question: Did you build what was asked?**

Dispatch a subagent using the Task tool. Fill in the template below with the actual task
description and implementer report. Do not summarize — provide the full text.

```
Task tool (general-purpose):
  description: "Spec compliance review for [task_id]"
  prompt: |
    You are reviewing whether an implementation matches its specification.

    ## What Was Requested

    [FULL TEXT of task requirements — paste the complete task description]

    ## What the Implementer Claims They Built

    [From implementer's report or commit message]

    ## CRITICAL: Do Not Trust the Report

    The implementer finished. Their report may be incomplete, inaccurate, or optimistic.
    You MUST verify everything independently by reading the actual code.

    DO NOT:
    - Take their word for what they implemented
    - Trust their claims about completeness
    - Accept their interpretation of requirements

    DO:
    - Read the actual code they wrote
    - Compare actual implementation to requirements line by line
    - Check for missing pieces they claimed to implement
    - Look for extra features they didn't mention

    ## Your Job

    Read the implementation code and verify:
    - Missing requirements: everything requested, no skipped or partially-implemented items
    - Extra work: nothing built beyond spec, no over-engineering or uninvited "nice to haves"
    - Misunderstandings: correct problem, correct interpretation, correct approach

    Verify by reading code, not by trusting the report.

    Report one of:
    - PASS: [brief explanation after code inspection]
    - FAIL: [list each issue with file:line reference]
```

Write the artifact immediately after the subagent returns (see Review Artifacts below).
Only proceed to Stage 2 if the verdict is PASS.

---

## Stage 2: Code Quality

**Question: Is it well-built?**

Only dispatch after Stage 1 PASS.

```
Task tool (code-reviewer or general-purpose):
  description: "Code quality review for [task_id]"
  prompt: |
    Review code quality for the implementation described below.

    ## What Was Implemented

    [From implementer's report]

    ## Requirements Reference

    Task [task_id] from [plan file path]

    ## Commits

    Base SHA: [commit before task]
    Head SHA: [current HEAD]

    ## Review Dimensions

    - File responsibility: one clear responsibility per file, independently testable units
    - Pattern consistency: naming, error handling, structure match existing codebase
    - Scope: follows plan file structure; flag new files that are already large or grew significantly
    - Tests: present for new behavior, verify behavior not just code paths

    ## Verdict Format

    Strengths: [bullet list]
    Issues:
      Critical: [breaks correctness or security — must fix before proceeding]
      Important: [degrades maintainability — fix before next task]
      Minor: [style or preference — note for later]
    Assessment: [APPROVED | APPROVED WITH NOTES | NEEDS WORK]
```

Write the artifact immediately after the subagent returns (see Review Artifacts below).

---

## Review Artifacts

After each stage, write a JSON file. Do this before acting on any findings.

**Paths:**

| Granularity | Spec review path | Quality review path |
|-------------|-----------------|---------------------|
| `per-task` | `.harness/reviews/{task_id}/spec-review.json` | `.harness/reviews/{task_id}/quality-review.json` |
| `per-phase` | `.harness/reviews/phase-{N}/spec-review.json` | `.harness/reviews/phase-{N}/quality-review.json` |
| `per-sprint` | `.harness/reviews/sprint-{N}/spec-review.json` | `.harness/reviews/sprint-{N}/quality-review.json` |

**Schema:**

```json
{
  "schema_version": 1,
  "task_id": "T1.2",
  "review_type": "spec-compliance" | "code-quality",
  "reviewer": "subagent" | "self" | "codex" | "gemini",
  "verdict": "pass" | "fail",
  "timestamp": "2026-04-04T10:00:00Z",
  "findings": [
    {
      "severity": "critical" | "important" | "minor",
      "description": "What is wrong",
      "file": "src/foo.ts:42"
    }
  ]
}
```

The evidence gate checks for these files. An empty `findings` array is valid on a PASS verdict.
Create parent directories with `mkdir -p` before writing.

---

## Fix Loop

When a stage returns FAIL:

1. Give findings to the implementer subagent — include file:line references from the artifact.
2. Implementer fixes the issues.
3. Re-dispatch the same review stage.
4. Overwrite the artifact with the new result.
5. Repeat until verdict is PASS.

**Rules:**
- Do not skip the re-review. "I fixed it" is not the same as "reviewer confirmed it."
- Do not proceed to Stage 2 while Stage 1 has open issues.
- Do not proceed past review while Stage 2 has open Critical or Important issues.
- "Close enough" on spec compliance is not done. Spec reviewer found issues = not done.
- Minor issues from Stage 2 may be noted and deferred. Critical and Important may not.

---

## Receiving Review Feedback

When a reviewer returns findings, apply this pattern before acting:

```
READ     — Complete the full feedback before reacting to any item
UNDERSTAND — Restate each requirement in your own words (or ask for clarification)
VERIFY   — Check the finding against the actual code — is it accurate?
EVALUATE — Is this technically sound for this codebase?
RESPOND  — Technical acknowledgment or reasoned pushback
IMPLEMENT — One item at a time, test each individually
```

**Forbidden responses:**
- "You're absolutely right!"
- "Great point!" / "Excellent feedback!"
- "Thanks for catching that!" / any gratitude expression
- "Let me implement that now" (before verification)

Instead: state what you found, state what you will fix, or just fix it. Actions speak.

**When to push back:**
- Suggestion breaks existing functionality
- Reviewer lacks full context about a constraint
- Suggestion violates YAGNI — grep the codebase, confirm nothing calls it
- Suggestion is technically incorrect for this stack
- Suggestion conflicts with an architectural decision already made

**How to push back:** Use technical reasoning. Show the specific code or test that contradicts
the suggestion. Ask a precise question. Involve the user if the disagreement is architectural.

**When feedback is correct:** State what changed, or just fix it and let the commit speak.
`"Fixed. [one sentence on what changed]"` or `"Verified — [issue]. Fixed in [file:line]."`

**Implementation order:** Clarify unclear items first. Then: blocking issues → simple fixes →
complex fixes. Test each individually before moving on.

---

## Anti-Rationalizations

| Rationalization | Reality |
|----------------|---------|
| "Code is simple, doesn't need review" | Simple code has simple bugs. Review catches them. |
| "I already self-reviewed" | Self-review complements peer review, does not replace it. |
| "Review will slow me down" | Review catches issues now. Debugging catches them later, slower. |
| "It's just a small change" | Small changes cause big outages. Review anyway. |
| "The tests pass, so it must be correct" | Tests verify behavior. Review verifies design. |
| "I'll get review on the next one" | No. This one. Every time. |

---

## Integration with Harness Gates

**task-state.json transitions (per-task mode):**

```
implementing -> needs-spec-review -> needs-quality-review -> approved
```

The gate checks for review artifact files, not task-state.json directly. Write the artifacts
first; the state transitions follow.

**gate-commit-on-state.sh** — blocks commits when task state is `needs-spec-review` or
`needs-quality-review`. If the gate blocks you, you are here: run both review stages,
write artifacts, confirm both pass, then the gate clears.

**Evidence gate** — checks that `.harness/reviews/{task_id}/spec-review.json` and
`quality-review.json` both exist and have `verdict: "pass"` before allowing phase advancement.
