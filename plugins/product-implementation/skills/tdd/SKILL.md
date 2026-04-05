---
name: tdd
description: Use when implementing any feature or bugfix inside the harness. Write the test first, watch it fail, write minimal code to pass. Invoke when a harness gate blocks you or when starting any implementation task.
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
