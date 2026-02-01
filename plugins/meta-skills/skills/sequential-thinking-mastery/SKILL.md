---
name: sequential-thinking-mastery
description: >
  This skill should be used when the user asks "use sequential thinking", "help me reason through this",
  "analyze this systematically", "debug with ST", "compare options with branching", or when facing problems like
  "I need to make a complex decision", "my reasoning keeps going in circles", "I want an auditable thought process",
  "how do I structure my analysis", or developing skills/commands that leverage ST internally.
  Provides decision framework, prompting patterns, branching/revision mechanics, troubleshooting, and anti-patterns.
---

# Sequential Thinking MCP Mastery

> **Compatibility**: Verified against ST server v0.2.0 (npm 2025.12.18). Parameter behavior may differ in other versions.

## Overview

Sequential Thinking MCP is a **structured workspace** that externalizes Chain-of-Thought into a reversible, branching protocol. It provides **System 2 reasoning** capabilities to stateless LLMs—transforming fast intuitive responses into deliberate, auditable thought chains.

**Key insight:** The server is **passive infrastructure**—it records and organizes thoughts but does NOT reason itself. It provides cognitive scaffolding; the quality of output depends on how effectively the LLM leverages the framework. Benchmarks show **54% improvement** on complex multi-step tasks with strategic prompting.

**Note:** `totalThoughts` is a **heuristic estimate**, not a hard limit. The server auto-adjusts it upward if `thoughtNumber` exceeds the current estimate. Use prompt engineering to guide reasonable chain lengths.

### Core Architecture

The server maintains two in-memory structures:
- **thoughtHistory**: Linear array of all thoughts (working memory)
- **branches**: Dictionary mapping `branchId` to thought arrays (parallel exploration)

**Critical:** State is ephemeral—if MCP connection drops, all reasoning state is lost. Best suited for session-scoped problem solving.

### Key Architectural Concepts

Understanding these three mechanisms is essential for effective ST usage:

**1. Thought History as Working Memory**
The `thoughtHistory` array acts as externalized working memory. Unlike internal CoT where thoughts are probabilistic token streams, ST thoughts become **immutable data**. Once committed, the model can't silently drift from a premise—it must explicitly revise. This "deterministic anchoring" prevents hallucination spirals.

**2. Branch Dictionary as Parallel Exploration**
The `branches` dictionary enables a "multiverse" of reasoning. Each branch is isolated, allowing exploration of mutually exclusive options without polluting the main reasoning trunk. Branches exist semantically as "explored alternatives"—rejected branches remain in history as auditable decision records.

**3. State Echo Mechanism**
Every ST response echoes the ENTIRE `thoughtHistory` back. This "state echo" re-injects the full reasoning context into the LLM's window on each turn, ensuring the model never loses its place in the sequence even across conversation turns. The cost is linear context growth—very long chains (100+ thoughts) may approach token limits.

### ST vs Extended Thinking

**When to choose ST over Extended Thinking:** Use ST when reasoning must be visible, auditable, or when you need explicit branching/revision. Extended Thinking is preferred for general reasoning where visibility isn't required.

For detailed comparison table and Anthropic guidance, see `references/technical-reference.md#sequential-thinking-vs-extended-thinking`.

## When to Use ST (Decision Framework)

### Trigger Conditions (USE ST when)

1. **Complexity**: Task involves >3 distinct interdependent steps
2. **Ambiguity**: Task input is vague (e.g., "Fix the build")
3. **High Stakes**: Task involves destructive actions (rm, DROP TABLE, production deploys)
4. **Architectural Choice**: Selecting between valid alternatives with trade-offs
5. **Auditability**: Stakeholders need to review decision process

### Suppression Conditions (SKIP ST when)

1. **Triviality**: "Fix this typo" - single operation tasks
2. **Read-Only**: "What is in file X?" - use filesystem directly
3. **Latency-Sensitive**: Real-time chat interactions
4. **Domain Knowledge**: Problems answered by existing knowledge

### High-Value Scenarios

- **Tool output analysis** - processing outputs before deciding next action. ST provides a structured pause between tool result and next action, preventing reflexive responses to unexpected outputs.
- **Policy-heavy environments** - step-by-step compliance verification. Each thought can reference specific policy rules, creating an auditable compliance trail.
- **Complex debugging** - systematic hypothesis testing with revision. The revision mechanism allows backtracking when evidence disproves earlier assumptions without losing context.
- **Architecture decisions** - Fork-Join pattern for trade-off evaluation. Branches explore mutually exclusive options in parallel, with explicit synthesis.
- **Risk assessment** - Red Team branches to find flaws in plans. Adversarial analysis in a dedicated branch prevents self-censoring during critique.

## Quick Reference - Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `thought` | string | Current thinking step content |
| `thoughtNumber` | integer (min: 1) | Position in sequence |
| `totalThoughts` | integer (min: 1) | Estimated total (adjustable) |
| `nextThoughtNeeded` | boolean | Whether to continue |

## Quick Reference - Optional Parameters

| Parameter | Description |
|-----------|-------------|
| `isRevision` + `revisesThought` | Reconsider earlier conclusion |
| `branchFromThought` + `branchId` | Explore alternative path |
| `needsMoreThoughts` | Signal estimate needs extending |

## Minimum Viable Invocation

```json
{
  "thought": "Your reasoning content here",
  "thoughtNumber": 1,
  "totalThoughts": 5,
  "nextThoughtNeeded": true
}
```

## Anti-Patterns (Avoid These)

1. **Rubber Stamping** - Shallow thoughts like "Step 1: Analyzing", "Step 2: Thinking". Every thought MUST contain a new hypothesis, data point, or decision.

2. **Orphaned Branches** - Creating branches without synthesis. **Rule:** Every branch MUST end with a convergence thought integrating findings back to main trunk.

3. **Infinite Analysis Loop** - Continuously setting `nextThoughtNeeded: true` creating 50+ circular steps. **Circuit Breaker:** If `thoughtNumber > 20`, ask user for guidance or attempt partial solution.

4. **Premature Termination** - Setting `nextThoughtNeeded: false` before conclusion is solid.

5. **Ignoring Revision** - Not using `isRevision: true` when tool outputs contradict assumptions.

## Chain Management Guidelines

### The Rule of 5
Every 5 thoughts, explicitly re-evaluate `totalThoughts`. If end not in sight, set `needsMoreThoughts: true`. This prevents both premature termination (rushing to meet arbitrary deadline) and runaway analysis (endless exploration without closure).

### State Dump (Checkpoint)
If chain exceeds 15 steps, create a checkpoint thought summarizing progress. This acts as a mental buffer clear, consolidating findings and freeing cognitive space for the next analysis phase. Checkpoint thoughts should list: key findings so far, remaining hypotheses, and next planned investigation step.

### Explicit Stop
Final thought MUST state "Plan complete" and set `nextThoughtNeeded: false`. Never leave dangling chains—they cause infinite loop freezes in some MCP clients.

### Evidence-Based Progression
Each thought should either (1) generate a new hypothesis based on evidence, (2) eliminate a hypothesis based on tool output, or (3) revise a previous thought based on new information. Thoughts that don't meet these criteria are likely rubber stamps and should be revised.

## Termination Criteria

End a thought chain when:
1. **Verification** - Hypothesis proven true by tool result (test passes)
2. **Exhaustion** - All hypotheses proven false (ask user for help)
3. **Actionable Plan** - Complete list of actions ready for execution

## Common Workflows

### Quick Debug Session (5 Thoughts)

For systematic bug investigation with tool interleaving:

1. **Initialize** - State symptoms, generate 2-3 hypotheses ranked by likelihood
2. **Investigate** - Call diagnostic tool (logs, config, state inspection)
3. **Analyze** - Evaluate evidence, eliminate/confirm hypotheses. Use `isRevision: true` if tool output contradicts initial assessment
4. **Narrow** - Focus on surviving hypothesis, call targeted tool
5. **Conclude** - State root cause and fix, set `nextThoughtNeeded: false`

**Key pattern:** Each thought eliminates possibilities. If no progress by thought 5, extend estimate or ask user.

### Architecture Decision (Fork-Join)

For evaluating mutually exclusive options with trade-offs:

1. **Frame** - Define problem, constraints, and options to evaluate
2. **Branch A** - `branchFromThought: 1, branchId: "option-a"` - Analyze first option (pros/cons)
3. **Branch B** - `branchFromThought: 1, branchId: "option-b"` - Analyze second option (pros/cons)
4. **Synthesize** - Return to main trunk (no `branchId`), compare findings, recommend
5. **Finalize** - Document decision rationale, set `nextThoughtNeeded: false`

**Key pattern:** Branches share origin point. Synthesis MUST reference both branches explicitly.

### Risk Assessment (Red Team)

For adversarial analysis of plans or designs:

1. **State Plan** - Document the proposal being evaluated
2. **Red Team Branch** - `branchId: "red-team"` - Assume adversarial stance, identify attack vectors, edge cases, failure modes
3. **Blue Team Response** - For each red team finding, assess likelihood and impact
4. **Mitigate** - Propose concrete mitigations for high-severity findings
5. **Conclude** - Updated plan with mitigations, residual risks documented

**Key pattern:** Red team branch is explicitly adversarial. Don't self-censor—find real flaws.

## Selective Context Loading

For detailed information, load references as needed:

### Reference Files

- **Branching/Revision mechanics**: `references/branching-revision.md` - Fork-Join pattern, Revision Loop, synthesis rules
- **Prompting patterns by use case**: `references/prompting-patterns.md` - Debug protocol, architecture trade-offs, quality heuristics
- **Integration with other MCP servers**: `references/integration-patterns.md` - Orchestration patterns, TAO loop, domain workflows
- **Complete technical reference**: `references/technical-reference.md` - ThoughtData interface, state management, performance, known gaps
- **Troubleshooting guide**: `references/troubleshooting.md` - Token optimization, error -32000, infinite loop fixes

### Example Files

Working JSON examples in `examples/`:

- **`examples/debug-session.json`** - 5-thought systematic debugging with hypothesis elimination
- **`examples/fork-join-decision.json`** - Architecture decision with parallel branch evaluation
- **`examples/revision-loop.json`** - Error containment when assumptions are invalidated

## For Skill/Command Development

When building skills that use ST internally:

1. **Define clear thought progressions** - List expected thought sequence in prompts
2. **Use the strategic prompting template** (see `references/prompting-patterns.md`)
3. **Specify when to branch** - Architecture comparisons, dead ends with preservable context
4. **Specify when to revise** - Flaws in assumptions, invalidated conclusions

## Quick Reference Checklist

**Use ST if ANY of these are true:**
- [ ] Task involves >3 interdependent steps
- [ ] Input is ambiguous or vague
- [ ] Destructive actions involved (rm, DROP, deploy)
- [ ] Multiple valid approaches to evaluate
- [ ] Reasoning trace needed for audit/compliance
- [ ] Multi-tool orchestration required

**Skip ST if ALL of these are true:**
- [ ] Single-step or trivial task
- [ ] Read-only query answerable directly
- [ ] Time-critical/latency-sensitive context
- [ ] Domain knowledge sufficient (no exploration needed)
