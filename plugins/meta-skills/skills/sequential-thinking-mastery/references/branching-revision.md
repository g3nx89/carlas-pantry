# Branching and Revision Mechanics

## How Branching Works

Branches explore alternative reasoning paths without losing the main thought chain. The server stores branched thoughts in a separate `branches` dictionary keyed by `branchId`, enabling a **"multiverse" of reasoning** where alternatives exist without polluting the main trunk.

```json
{
  "thought": "Alternative approach: what if we use event sourcing instead?",
  "thoughtNumber": 1,
  "totalThoughts": 4,
  "nextThoughtNeeded": true,
  "branchFromThought": 3,
  "branchId": "event-sourcing-exploration"
}
```

### When to Branch

- Initial approach hits dead ends but context should be preserved
- Comparing architectural approaches before committing
- Exploring multiple solution paths simultaneously
- Risk assessment requiring adversarial analysis

## The Fork-Join Decision Tree Pattern

Essential for architectural decisions with mutually exclusive options.

### Phase 1: The Fork

Upon reaching a decision point, create the first branch:

```json
{
  "thought": "Exploring Option A: Redis Cache. Pros: Persistence, mature ecosystem. Cons: Infrastructure cost, operational overhead.",
  "thoughtNumber": 2,
  "branchFromThought": 1,
  "branchId": "option-redis",
  "totalThoughts": 8,
  "nextThoughtNeeded": true
}
```

Perform 2-3 analysis steps within this branch.

### Phase 2: The Parallel

Create second branch from the SAME origin point:

```json
{
  "thought": "Exploring Option B: In-Memory Cache. Pros: Zero infrastructure, fast. Cons: No persistence, memory limits.",
  "thoughtNumber": 4,
  "branchFromThought": 1,
  "branchId": "option-inmemory",
  "totalThoughts": 8,
  "nextThoughtNeeded": true
}
```

### Phase 3: The Join (Synthesis)

Return to main trunk (no branchId) and synthesize:

```json
{
  "thought": "Synthesis: After comparing branches, Option B (In-Memory) meets requirements for this project tier. Redis would be over-engineering. Proceeding with in-memory approach.",
  "thoughtNumber": 6,
  "totalThoughts": 8,
  "nextThoughtNeeded": true
}
```

**Why it works:** The rejected branch exists in history but is semantically marked as explored-and-rejected, keeping main trunk clean.

## How Revision Works

Revisions enable **non-destructive backtracking**—the original thought is preserved while a new thought explicitly corrects it. This maintains full provenance and auditability.

```json
{
  "thought": "Reconsidering my earlier assumption—the bottleneck is actually I/O bound, not CPU bound",
  "thoughtNumber": 6,
  "totalThoughts": 8,
  "nextThoughtNeeded": true,
  "isRevision": true,
  "revisesThought": 2
}
```

**Critical:** Revisions do NOT modify or delete the original thought—they are appended to history with metadata linking back to the corrected thought.

### When to Revise

- Later steps reveal flaws in earlier assumptions
- Tool output contradicts previous conclusions
- Logical inconsistencies are identified
- New information invalidates previous decisions

## The Revision Loop Pattern (Error Containment)

In standard CoT, if a model makes an error in step 3, it often doubles down in step 4 to maintain consistency. The Revision Loop breaks this pattern.

### Example Flow

**Thought N:**
```json
{
  "thought": "I will use API endpoint /v1/users to fetch user data.",
  "thoughtNumber": 3,
  "totalThoughts": 6,
  "nextThoughtNeeded": true
}
```

**Action:** Agent calls fetch on /v1/users. Result: 404 Not Found.

**Thought N+1 (Revision):**
```json
{
  "thought": "I was incorrect. The endpoint returned 404. Based on error response, the correct endpoint is likely /v2/users. Revising my approach.",
  "thoughtNumber": 4,
  "totalThoughts": 6,
  "nextThoughtNeeded": true,
  "isRevision": true,
  "revisesThought": 3
}
```

**Outcome:** The reasoning chain remains coherent. The error is acknowledged and "overwritten" logically, preventing downstream corruption from the flawed assumption.

## Branch Convergence Rule

Every branch MUST end with a convergence thought that integrates findings back into the main flow.

**Enforcement prompt:**
```
Every branch MUST end with a convergence thought that integrates findings back into the main flow.
```

**Warning signs** of orphaned branches:
- Branch created but no subsequent thought without `branchId` references findings
- Final thought doesn't mention branch conclusions

For the complete anti-patterns list with circuit breakers, see `SKILL.md#anti-patterns-avoid-these`.

## The Dynamic Horizon Pattern

Novice users treat `totalThoughts` as a deadline. Expert implementations treat it as a **heuristic**.

**Concept:** Start with a conservative estimate (e.g., `totalThoughts: 5`). If at `thoughtNumber: 3` the problem reveals hidden complexity, invoke `needsMoreThoughts: true`.

```json
{
  "thought": "This is more complex than initially estimated. The codebase has circular dependencies I didn't anticipate. Extending analysis.",
  "thoughtNumber": 3,
  "totalThoughts": 5,
  "needsMoreThoughts": true,
  "nextThoughtNeeded": true
}
```

**Behavioral effect:** This tells the server (and the model's future context): "I am not failing; I am discovering." Prevents rushing to hallucinated conclusions to satisfy an arbitrary constraint.

## State Management Notes

- State is **in-memory only** - resets on server restart or connection drop
- Revisions are **append-only** - originals never modified
- `totalThoughts` auto-adjusts upward if `thoughtNumber` exceeds current estimate
- No maximum limit on chain length (potential memory concern for very long chains)
- **State echo mechanism:** Every response includes full thoughtHistory, re-injecting context into LLM's window

