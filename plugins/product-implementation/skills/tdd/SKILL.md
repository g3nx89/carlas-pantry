---
name: tdd
description: Use when implementing any feature or bugfix inside the harness. Write the test first, watch it fail, write minimal code to pass. Invoke when a harness gate blocks you or when starting any implementation task. If `.harness/analysis.json` defines a `tdd_composition` block, this skill ALSO enforces per-commit file-composition rules (chore-stub, RED, GREEN) — read the "Commit Chain Composition" section below BEFORE staging files for any TDD commit.
---

# Test-Driven Development (TDD)

## Overview

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

**Violating the letter of the rules is violating the spirit of the rules.**

## Project Context

Before running any test command, read `.harness/analysis.json` from the feature root.

```bash
cat .harness/analysis.json
```

Extract these values and use them throughout this skill:

| Field | Usage |
|-------|-------|
| `test_runner` | The test framework (jest, vitest, go test, pytest, etc.) |
| `test_command` | Exact command to run tests — use this verbatim |
| `test_file_pattern` | How test files are named (`.test.ts`, `_test.go`, `_spec.rb`) |
| `test_dir` | Where tests live relative to the feature root |

**If `.harness/analysis.json` does not exist:** Ask the user for these four values before proceeding. Do not guess.

Replace `{TEST_COMMAND}` in all examples below with the actual value from `test_command`.

## Commit Chain Composition

If `.harness/analysis.json` contains a `tdd_composition` block, it defines
per-commit file-composition rules that MUST be satisfied in addition to the
Red-Green-Refactor discipline below. A project harness gate (named in
`tdd_composition.history_gate_script`) typically enforces these rules at
commit time and will block violations.

**Why this exists.** Some projects enforce strict commit-chain discipline:
each commit in a RED → GREEN chain touches a specific subset of files, and
violations are rejected by a mechanical gate or a review pass. The purpose
is to make the TDD sequence auditable in git history — the chore-stub
introduces the API, the RED commit proves the test is actually red (not a
compile error), the GREEN commit introduces the fix. Mixing file
categories across commits makes the chain unverifiable.

**If `tdd_composition` is absent or `enabled: false`:** ignore this
section. The generic Red-Green-Refactor discipline below is sufficient.

### Before composing any TDD commit

1. **Classify the intended commit.** Match it to one of the chains defined
   in `tdd_composition.commit_chains`:

   - **`two_commit`** — use when your RED test compiles against APIs that
     already exist (you're fixing wrong behavior in an existing class, not
     introducing a new class). The chain is:
     ```
     test(<module>): RED — <failing scenario>
     fix(<module>): GREEN — <what the fix does>
     ```

   - **`three_commit`** — use when your RED test references a production
     class, interface, or method that does NOT yet exist. The test cannot
     compile without a stub. The chain is:
     ```
     chore(<module>): stub <api> for upcoming RED test
     test(<module>): RED — <failing scenario>
     fix(<module>): GREEN — <what the fix does>
     ```

2. **Identify which step you're about to compose** (index 0, 1, or 2).

3. **Stage ONLY files that match the step's `allowed_paths` glob.** Any
   other file belongs to a different step of the chain.

4. **Verify body constraints.** If the step has `body_constraints` (typical
   for chore-stub steps), every added method body must match one of the
   constraint patterns — usually `TODO()` / `error(` / `throw
   NotImplementedError`. The chore-stub commit must NOT pass the RED test
   on its own; if it does, you're smuggling production code.

5. **Confirm the order.** The gate enforces that commits arrive in the
   order defined by the chain. Reordering or interleaving with unrelated
   commits breaks the chain.

### Common composition mistakes

The following all trigger history-gate blocks:

- **Harness state in a chore-stub or RED commit.** Sprint contracts,
  feature-list toggles, progress logs, and learnings entries are harness
  state. They belong exclusively in the GREEN step (the catch-all), not
  bundled with the stub or the test. The chore/RED steps must remain
  pure per their `allowed_paths`.
- **Test files in a chore-stub commit.** The stub is main-source only.
  Tests arrive in the next step.
- **Production code in a RED commit.** The test-only RED commit is the
  permanent proof that the test was actually red against a pre-fix state.
  Mixing prod code into it invalidates that proof.
- **Chore-stub commit with real behavior.** If any added method has a
  non-stub body, the chain is smuggling production code past the RED
  commit. The body-constraint check exists to catch this.
- **Skipping the chore step when the test compiles anyway.** If the test
  can compile against existing APIs, prefer the `two_commit` chain —
  adding an unnecessary chore commit is noise, and the gate will accept
  it but reviewers will flag it.

### Reading the config

Example `tdd_composition` block (projects adapt values to their
conventions):

```json
{
  "tdd_composition": {
    "enabled": true,
    "history_gate_script": "verify-tdd-history.sh",
    "commit_chains": {
      "two_commit": {
        "when": "The RED test compiles against existing APIs",
        "sequence": [
          {
            "subject_prefix": ["test(", "RED "],
            "allowed_paths": [
              "**/src/test/**",
              "**/src/androidTest/**",
              "**/src/testFixtures/**"
            ]
          },
          {
            "subject_prefix": ["fix(", "GREEN "],
            "allowed_paths": ["*"]
          }
        ]
      },
      "three_commit": {
        "when": "The RED test references a production class or interface that does not yet exist",
        "sequence": [
          {
            "subject_regex": "^chore\\([a-z:,-]+\\): stub .* for (upcoming )?(test\\(|RED )",
            "allowed_paths": ["**/src/main/**/*.kt"],
            "body_constraints": [
              "TODO()",
              "error(",
              "throw NotImplementedError"
            ]
          },
          {
            "subject_prefix": ["test(", "RED "],
            "allowed_paths": [
              "**/src/test/**",
              "**/src/androidTest/**",
              "**/src/testFixtures/**"
            ]
          },
          {
            "subject_prefix": ["fix(", "GREEN "],
            "allowed_paths": ["*"]
          }
        ]
      }
    },
    "bypass_file": ".harness/tdd-bypass-next-commit",
    "bypass_keywords": ["[hotfix-skip-tdd]"],
    "harness_dir": ".harness"
  }
}
```

### Bypass

If `tdd_composition.bypass_file` is set, the harness typically allows a
one-shot bypass by writing one of `tdd_composition.bypass_keywords` to
that file before committing:

```bash
echo "[hotfix-skip-tdd] <one-line reason>" > "$(cat .harness/analysis.json | jq -r '.tdd_composition.bypass_file')"
git commit ...
```

Use bypass ONLY for genuine production emergencies where writing a test
first is impossible (external API change, test infrastructure itself is
broken, crashlytics-level incident). Every bypass is logged and reviewed
at the next phase boundary. `[refactor]`, `[chore]`, `[docs]` are NOT
sanctioned bypass keywords — those either don't trigger the gate
(doc-only, non-source) or should go through the proper chain.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over.

**No exceptions:**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete

Implement fresh from tests. Period.

## Red-Green-Refactor

### RED - Write Failing Test

Write one minimal test showing what should happen.

**Good** (TypeScript/Jest — illustrative, adapt to your stack):
```typescript
test('retries failed operations 3 times', async () => {
  let attempts = 0;
  const operation = () => {
    attempts++;
    if (attempts < 3) throw new Error('fail');
    return 'success';
  };

  const result = await retryOperation(operation);

  expect(result).toBe('success');
  expect(attempts).toBe(3);
});
```
Clear name, tests real behavior, one thing.

**Bad**:
```typescript
test('retry works', async () => {
  const mock = jest.fn()
    .mockRejectedValueOnce(new Error())
    .mockRejectedValueOnce(new Error())
    .mockResolvedValueOnce('success');
  await retryOperation(mock);
  expect(mock).toHaveBeenCalledTimes(3);
});
```
Vague name, tests mock not code.

**Requirements:**
- One behavior per test
- Name describes the behavior
- Real code — no mocks unless the dependency is external I/O

### Verify RED - Watch It Fail (MANDATORY)

Never skip this step.

```bash
{TEST_COMMAND} path/to/test-file
```

Confirm all three:
- Test **fails** (not errors out on syntax/import)
- Failure message is the expected one
- Fails because the feature is missing, not a typo

**Test passes immediately?** You're testing existing behavior. Fix the test.

**Test errors (not fails)?** Fix the error and re-run until you see a real failure.

### GREEN - Minimal Code

Write the simplest code that makes the test pass.

**Good**:
```typescript
async function retryOperation<T>(fn: () => Promise<T>): Promise<T> {
  for (let i = 0; i < 3; i++) {
    try {
      return await fn();
    } catch (e) {
      if (i === 2) throw e;
    }
  }
  throw new Error('unreachable');
}
```
Just enough to pass.

**Bad**:
```typescript
async function retryOperation<T>(
  fn: () => Promise<T>,
  options?: {
    maxRetries?: number;
    backoff?: 'linear' | 'exponential';
    onRetry?: (attempt: number) => void;
  }
): Promise<T> {
  // YAGNI — none of these options are tested yet
}
```
Over-engineered. No test covers these options.

Don't add features, refactor adjacent code, or "improve" beyond the test.

### Verify GREEN - Watch It Pass (MANDATORY)

```bash
{TEST_COMMAND}
```

Confirm:
- The new test passes
- All previously passing tests still pass
- Output is pristine — no errors, no warnings

**Test fails?** Fix code, not the test.

**Other tests fail?** Fix them now before continuing.

### REFACTOR - Clean Up

After green only:
- Remove duplication
- Improve names
- Extract helpers if they clarify intent

Keep all tests green. Do not add behavior during refactor.

### Repeat

Next failing test for the next behavior.

## Anti-Rationalizations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests written after pass immediately — prove nothing. |
| "Tests after achieve same goals" | Tests-after = "what does this do?" Tests-first = "what should this do?" |
| "Already manually tested" | Ad-hoc is not systematic. No record, can't re-run. |
| "Deleting X hours is wasteful" | Sunk cost fallacy. Keeping unverified code is technical debt. |
| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete. |
| "Need to explore first" | Fine. Throw away the exploration, then start with TDD. |
| "Test hard = design unclear" | Listen to the test. Hard to test = hard to use. Simplify the design. |
| "TDD will slow me down" | TDD is faster than debugging production failures. Pragmatic means test-first. |
| "Manual test faster" | Manual doesn't prove edge cases. You'll re-test every change manually forever. |
| "Existing code has no tests" | You're improving it. Add tests for the code you touch. |

## Red Flags — STOP

Any of these means: delete the code, start over.

- Code written before the test
- Test written after the implementation
- Test passes immediately on first run
- Can't explain why the test failed
- Tests planned to be added "later"
- Rationalizing "just this once"
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "It's about the spirit, not the ritual"
- "Keep as reference" or "adapt existing code"
- "Already spent X hours, deleting is wasteful"
- "TDD is dogmatic, I'm being pragmatic"
- "This is different because..."

## When Stuck

| Problem | Action |
|---------|--------|
| Don't know how to test | Write the wished-for API call first. Write the assertion. Work backward to the setup. Ask the user if still blocked. |
| Test too complicated | The design is too complicated. Simplify the interface before implementing. |
| Must mock everything | Code is too coupled. Introduce dependency injection so the seam is explicit. |
| Test setup is huge | Extract setup helpers. If still complex, simplify the design — setup size mirrors design complexity. |

## Testing Anti-Patterns

When writing mocks or test utilities, avoid these three:

- **Testing mock behavior** — asserting that a mock was called is not testing real behavior. Test what the production code does.
- **Test-only methods in production classes** — if a method is only called from tests, move it to test utilities, not the production class.
- **Mocking without understanding** — know the side effects of the method you're mocking. Over-mocking removes the behavior your test depends on.

**Rule:** Mock the complete data structure as it exists in reality, not just the fields your current test uses. Partial mocks fail silently when downstream code accesses omitted fields.

## Self-Review Checklist

Before reporting any implementation as complete:

**Completeness**
- [ ] Every new function or method has at least one test
- [ ] Edge cases and error paths are covered

**Discipline**
- [ ] Watched each test fail before writing implementation
- [ ] Each test failed for the expected reason (feature missing, not a typo)
- [ ] Wrote minimal code to pass each test — nothing more

**Quality**
- [ ] All tests pass
- [ ] Test output is pristine — no errors, no warnings
- [ ] Tests use real code (mocks only where external I/O makes real calls impossible or destructive)

Can't check every box? You skipped TDD. Start over.

## Escalation Protocol

Stop and set task status to `BLOCKED` or `NEEDS_CONTEXT` when:

- You cannot write a meaningful failing test after two attempts
- The test infrastructure itself is broken (runner not found, config errors)
- A required dependency is unavailable and cannot be mocked safely
- You have deleted and restarted three times without reaching GREEN

**Bad work is worse than no work.** A blocked status with a clear reason is more valuable than shipped code without tests.

Format your block reason:
```
BLOCKED: <what you tried> / <what failed> / <what you need>
```

## Integration with Harness Gates

The harness enforces TDD through two commit-time gates:

**`verify-test-delta.sh`** — blocks commits where production files changed but no corresponding test file changed. If this gate blocks you:
1. You wrote production code without tests
2. Follow this skill: write the missing tests, watch them fail against a state before your change, then verify green

**`gate-commit-on-state.sh`** — blocks commits when `task-state.json` records an in-progress review. If this gate blocks you:
1. The review cycle is not complete
2. Update `task-state.json` to reflect actual review outcome before committing

When a gate blocks you, the block message names which gate fired. Treat it as a TDD signal: the gate caught a process violation. Fix the process, not the gate.
