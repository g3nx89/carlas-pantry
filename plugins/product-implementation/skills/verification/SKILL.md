---
name: verification
description: Require verification evidence before any completion claims. If you have not run the verification command in this message, you cannot claim it passes.
---

# Verification Before Completion

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you have not run the verification command in this message, you cannot claim it passes.

## The Gate Function

```
BEFORE claiming any status:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

## Common Claims

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | "should pass", previous run |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |

## Red Flags — STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- Thinking "just this once"
- ANY wording implying success without having run verification

## Anti-Rationalizations

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence is not evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter is not the compiler |
| "Agent said success" | Verify independently |
| "I'm tired" | Exhaustion is not an excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule does not apply" | Spirit over letter |

## Key Patterns

**Tests:**
```
PASS: [Run test command] -> see 0 failures -> claim "Tests pass"
FAIL: "Should pass now" / "Looks correct"
```

**Build:**
```
PASS: [Run build command] -> see exit 0 -> claim "Build succeeds"
FAIL: "Linter passed" (linter does not check compilation)
```

**Requirements:**
```
PASS: Re-read plan -> create checklist -> verify each item -> claim or report gaps
FAIL: "Tests pass, phase complete"
```

**Agent delegation:**
```
PASS: Agent reports success -> check VCS diff -> verify changes exist -> report actual state
FAIL: Trust agent report at face value
```

## Integration with Harness Gates

The harness gate `gate-feature-list-on-state.sh` mechanically blocks marking tasks complete without:

- Review artifacts with verdict: "pass"
- Source code committed (git clean excluding `.harness/`)

This gate is the **mechanical enforcement**. This skill is the **behavioral guidance**.

If the gate blocks you, use the Gate Function above to identify what verification is missing, run it, and confirm the result before re-attempting.

**When the gate blocks:** Do not look for workarounds. The block exists because evidence is missing. Produce the evidence.
