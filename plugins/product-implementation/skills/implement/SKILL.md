---
name: implement
description: >-
  Session protocol for implementing tasks within a harness-configured project.
  Reads .harness/ artifacts, follows TDD cycle, delegates to code-review and
  verification skills, respects gate enforcement. Use when starting implementation,
  resuming work in a new session, or when a gate blocks you.
---

# Implement — Session Protocol

Protocol for working inside a harness-configured project. The harness already set up
knowledge (CLAUDE.md), enforcement (hooks), progress tracking (feature-list.json),
and evaluation criteria. This skill tells you how to work within those constraints.

**Not an orchestrator.** You reason freely. Gates catch mistakes mechanically.

---

## 1. Session Startup

Every session — fresh or resumed — begins here.

### 1a. Find the Feature Directory

The feature directory contains `.harness/`, `tasks.md`, and `plan.md`. To find it:
- Check the project's CLAUDE.md for a `feature_dir` or plan path reference
- Look for `.harness/` directories: `find . -name analysis.json -path '*/.harness/*' | head -5`
- If multiple found or none: ask the user

Once found, all `.harness/` paths below are relative to this directory.

### 1b. Load Harness Artifacts

1. **Read analysis.json** — `{feature_dir}/.harness/analysis.json`
   - Extract: `quality_dimensions.resolved` (tdd_enforcement, review_granularity, test_delta_gate)
   - Extract: `test_command`, `build_command`, `test_runner`
2. **Read feature-list.json** — `{feature_dir}/.harness/feature-list.json`
   - Find current state: how many tasks done, what's next
3. **Read progress.md** — `{feature_dir}/.harness/progress.md`
   - Last session's handoff notes, blockers, context
4. **Check git state** — `git status`, `git log --oneline -5`
   - If uncommitted changes exist from a previous session: review them, then
     either commit (if complete) or stash (if partial) before proceeding
5. **Verify baseline** — run `{build_command}` and `{test_command}`
   - If either fails: fix before starting new work
6. **Check eval reports** — if `{feature_dir}/.harness/eval-reports/latest.md` exists
   with critical issues, address those before new features
7. **Read learnings** — if `{feature_dir}/.harness/learnings.md` exists (compound
   learning enabled), read accumulated insights before starting new work

If any `.harness/` file is missing, run `/product-implementation:harness` first.

---

## 2. Task Selection

Find the next task to implement:

```
For each task in feature-list.json where passes == false:
  If dependencies[] is empty or all tasks in dependencies[] have passes == true:
    → This is your next task. Stop searching.
```

If `review_granularity == per-task`: also read `.harness/task-state.json`.
Resume from current state if a task was in-progress (needs-spec-review, etc.).

**One task at a time.** Complete it fully before starting the next.

---

## 3. Sprint Contract

Before coding, write or update `{feature_dir}/.harness/sprint-contract.md`:

- **Scope**: task ID + description from feature-list.json
- **Acceptance criteria**: copied verbatim from feature-list.json (immutable)
- **Verification table**: for each criterion, how to verify it and with what tool
- **Definition of done**: tests pass, build succeeds, review passed (if applicable)

This is your agreement with yourself (and the evaluator, if eval loop is enabled)
on what "done" means. Concrete and testable, not subjective.

**If eval loop is enabled:** The evaluator reviews your sprint contract before you
start coding. Write it, then check if the evaluator session produces a
`contract-review.md`. Iterate max 2 rounds — evaluator version wins on disagreement.

---

## 4. Build — TDD Cycle

Invoke `product-implementation:tdd` for the implementation cycle.

For each acceptance criterion in the sprint contract:
1. **RED** — Write a failing test that captures the criterion
2. **GREEN** — Write minimal code to make it pass
3. **REFACTOR** — Clean up while keeping tests green

**When `verify-test-delta.sh` blocks your commit:**
You wrote production code without tests. Go back to RED. Write the missing test,
watch it fail, then proceed.

**When `tdd_enforcement == off`:** TDD is recommended but not gate-enforced.
When `advisory`: gate warns but allows. When `strict`: gate blocks.

---

## 5. Review

Conditional on `review_granularity` from analysis.json:

| Granularity | When to review | Artifact path |
|-------------|---------------|---------------|
| `per-task` | After each task, before marking done | `.harness/reviews/{task_id}/` |
| `per-phase` | At phase boundary, before starting next phase | `.harness/reviews/phase-{N}/` |
| `per-sprint` | Before merging to main | Eval loop handles it, or run review before merge |

**Per-sprint fallback:** If `review_granularity == per-sprint` and eval loop is not
enabled, run `product-implementation:code-review` once before merging to main.

When review is required, invoke `product-implementation:code-review`.
It runs two stages: spec compliance first, then code quality.
Both must produce artifacts with `verdict: "pass"` before proceeding.

**When `gate-commit-on-state.sh` blocks:**
Task state is `needs-spec-review` or `needs-quality-review`. Complete the
pending review stage via `product-implementation:code-review`.

**When `gate-feature-list-on-state.sh` blocks:**
Review artifacts missing or have `verdict: "fail"`. Produce passing review
artifacts before marking `passes: true`.

### Per-task state machine

When `review_granularity == per-task`, update `.harness/task-state.json`:

```
implementing → needs-spec-review → needs-quality-review → approved
```

On rejection at any stage: return to `implementing`, fix issues, re-review.

---

## 6. Verify & Complete

Before marking any task done, invoke `product-implementation:verification`.

1. Run `{test_command}` — confirm 0 failures
2. Run `{build_command}` — confirm exit 0
3. Check each acceptance criterion from sprint-contract.md — line by line
4. **Capture learnings** — if compound learning is enabled, append any non-obvious
   insights to `{feature_dir}/.harness/learnings.md` (what surprised you, what broke,
   what you'd do differently). The commit-gate hook enforces this.
5. **Only then**: set `passes: true` in feature-list.json
6. Commit source code, feature-list.json, and learnings.md together

**Rule:** If you haven't run the verification command in THIS message,
you cannot claim it passes. Evidence before claims, always.

**Dirty-tree policy:** Source code must be committed before writing to
feature-list.json. The gate excludes `.harness/` from the dirty check.

---

## 7. Phase Boundary

Detect: all tasks in the current phase have `passes: true`.

At a phase boundary:
1. If `review_granularity == per-phase`: run review for the entire phase
2. If eval loop is enabled: trigger evaluation session (see eval-criteria.md)
3. If compound learning is enabled: promote learnings from learnings.md
4. Update progress.md with phase completion summary
5. Commit all `.harness/` changes

---

## 8. Session Handoff

When context is getting long, a phase is complete, or you're blocked:

1. Update `{feature_dir}/.harness/progress.md` with:
   - Last completed task ID
   - Next task to start
   - Any blockers or context the next session needs
2. Commit all `.harness/` changes
3. Print a handoff summary:
   ```
   Session complete.
   Done: [task IDs completed this session]
   Next: [next task ID and brief description]
   Blockers: [any blockers, or "none"]
   Progress: [N/M tasks complete]
   ```

The next session starts at Step 1 and picks up from progress.md.

---

## Gate Response Table

When a gate blocks you, read its error message. It tells you exactly what's missing.

| Gate script | What it blocks | Recovery action |
|-------------|---------------|-----------------|
| `verify-test-delta.sh` | Commit without matching test changes | Write missing tests → invoke `product-implementation:tdd` |
| `gate-commit-on-state.sh` | Commit during pending review | Complete review → invoke `product-implementation:code-review` |
| `gate-feature-list-on-state.sh` | Marking passes:true without evidence | Produce review artifacts → invoke `product-implementation:verification` |

**Do not work around gates.** They exist because evidence is missing. Produce the evidence.

---

## Anti-Patterns

- Skipping session startup → you work on the wrong task or miss failing baseline
- Marking `passes: true` before verification → gate blocks, you lose time
- Ignoring gate messages → they tell you exactly what's missing
- Starting next task before current is approved → dependency chain breaks
- Editing feature-list.json descriptions → only `passes` is mutable
- "Close enough" on spec compliance → spec review will reject it
- Self-approving without running review → gate checks for artifact files
