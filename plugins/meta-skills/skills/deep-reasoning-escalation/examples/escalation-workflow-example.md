# Escalation Workflow Example: Mathematical Proof

This example demonstrates the complete escalation workflow when Claude fails twice on a mathematical proof construction task. The example uses GPT-5 Pro, but the same workflow applies to other deep reasoning models.

## Scenario

User asks: "Prove that for all positive integers n, the sum 1² + 2² + ... + n² = n(n+1)(2n+1)/6"

## Phase 1: Claude's First Attempt

Claude attempts the proof using standard induction but makes an error in the inductive step, failing to properly verify the algebraic manipulation.

**Result**: Proof incomplete; algebraic error in step 3.

## Phase 2: Claude's Second Attempt

Claude tries a different approach (telescoping sums) but gets stuck on the transformation.

**Result**: Proof incomplete; stuck at intermediate step.

## Phase 3: Trigger Recognition

At this point, the escalation trigger is met:
- ✅ Verifiable reasoning task (mathematical proof)
- ✅ Claude failed 2+ times
- ✅ Mathematical proof construction (high-confidence trigger)
- ✅ Not in anti-pattern list

**Decision**: RECOMMEND escalation to a deep reasoning model (e.g., GPT-5 Pro, Google Deep Think)

## Phase 4: Context Handoff Preparation

Generate the handoff package using the context transfer template:

```xml
<prior_context>
## Project Background
- Mathematical proof verification task
- Formal proof required with numbered steps

## Decisions Made
1. Attempted standard induction: Failed at algebraic simplification
2. Attempted telescoping sums: Got stuck at transformation step

## Current State
- Files modified: none (pure reasoning task)
- Last action taken: Two failed proof attempts
- Known issues: Inductive step verification failing

## Claude's Attempts
- Attempt 1: Standard induction → algebraic error in (k+1)² expansion
- Attempt 2: Telescoping sums → stuck converting to closed form
</prior_context>

<current_request>
Construct a formal proof for: For all positive integers n,
1² + 2² + ... + n² = n(n+1)(2n+1)/6
</current_request>
```

## Phase 5: Prompt Generation

Apply the mathematical proof template from `references/prompt-templates.md`:

```xml
<task>
Construct a formal proof for the following mathematical statement.
Think hard about this—take your time to verify each step.
</task>

<problem>
Prove that for all positive integers n:
1² + 2² + ... + n² = n(n+1)(2n+1)/6
</problem>

<context>
Claude's previous attempts:
1. Standard induction - failed at algebraic simplification in inductive step
2. Telescoping sums - stuck at transformation to closed form

Issue: Verification of algebraic manipulation in inductive step
</context>

<output_format>
1. Proof strategy overview (2-3 sentences)
2. Formal proof with numbered steps
3. Verification that each step follows logically
4. Alternative approaches considered
</output_format>
```

## Phase 6: User Instructions

Present to user:

---

**Escalation Recommended**

Claude has attempted this proof twice without success. Deep reasoning models have demonstrated stronger performance on mathematical proof construction.

**To proceed:**
1. Copy the prompt below to your deep reasoning model's interface:
   - **GPT-5 Pro**: chat.openai.com (requires Pro subscription)
   - **Google Deep Think**: AI Studio or Gemini Advanced
2. Wait for response (typically 3-5 minutes for proofs)
3. Paste the response back here

**Expected wait time:** 3-5 minutes

[Prompt to copy]

---

## Phase 7: Processing Deep Reasoning Model Response

User returns with the model's response containing:
- Proof strategy: Mathematical induction with careful algebraic verification
- Complete proof with 8 numbered steps
- Verification of each algebraic transformation
- Note about alternative approach using finite calculus

## Phase 8: Integration

Claude verifies the proof steps compile logically and helps the user understand the key insight that resolved the earlier failures.

**Outcome**: Successful proof obtained through escalation.

---

## Key Takeaways

1. **Trigger met clearly**: Mathematical proof + 2 failures = high-confidence escalation
2. **Anti-patterns checked**: Not creative, not urgent, not CLI work
3. **Context preserved**: Claude's failed attempts included in handoff
4. **User informed**: Clear instructions with expected wait time
5. **Value delivered**: Deep reasoning model solved what Claude couldn't

## When NOT to Escalate (Similar Scenarios)

- Simple algebra verification → Claude sufficient
- Code that implements the formula → Claude excels at implementation
- Explaining the proof to a student → Claude's warmth preferred
- Needing the result in under 2 minutes → Claude's speed required
