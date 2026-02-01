# Optimal Prompting Patterns by Use Case

## System Prompt Injection Template

To enable effective ST usage, inject into system prompt:

```
You possess the 'sequentialthinking' tool. This is your primary engine for complex problem solving.

- ALWAYS use it to decompose tasks requiring >3 steps.
- NEVER guess. If unsure, use branchId to explore alternatives.
- ALWAYS revise. If a tool output contradicts your thought, use isRevision=true to correct the record.
- DYNAMICALLY adjust totalThoughts. Do not feel bound by your first estimate.
- CONVERGE before acting. Ensure your final thought summarizes the plan.
```

## Strategic Prompting Template (54% benchmark improvement)

This pattern achieved **54% improvement** on complex tasks (Anthropic τ-Bench):

```
## Using the sequential thinking tool

Before taking any action or responding after receiving tool results,
use sequential thinking to:
- List the specific rules that apply to the current request
- Check if all required information is collected
- Verify that the planned action complies with all policies
- Iterate over tool results for correctness

<think_tool_example>
User wants to refactor the payment module.
- Need to verify: current dependencies, test coverage, API contracts
- Check refactoring rules:
  * Are there breaking changes to public interfaces?
  * Is backwards compatibility required?
- Verify no active incidents on this service
- Plan: map dependencies, identify safe refactoring boundaries, sequence changes
</think_tool_example>
```

## Architecture Decisions Pattern

```
We need to choose between GraphQL and REST for our new API. Consider team
expertise, client requirements, caching needs, and long-term maintenance.
Use the sequential thinking tool to analyze this systematically.

Expected thought progression:
1. Problem definition and constraints
2. Factor analysis (team skills, client needs, performance, maintenance)
3. Option evaluation with trade-offs
4. Trade-off assessment and weighting
5. Recommendation with rationale
```

## Complex Debugging Pattern

```
The payment service is intermittently failing with 502 errors in production.
Use sequential thinking to systematically diagnose the issue.

Expected thought progression:
1. Symptom analysis and pattern identification
2. System mapping (dependencies, failure propagation paths)
3. Hypothesis generation (potential root causes)
4. Investigation plan (systematic isolation approach)
5. Validation strategy (testing hypotheses)
```

## Deep Debug Protocol Template

Use this for root cause analysis with tool interleaving:

```json
// Thought 1: Initialization - Generate hypotheses
{
  "thought": "I need to diagnose the 'Connection Reset' error. Isolating variables. Hypothesis 1: Network firewall blocking. Hypothesis 2: Application timeout misconfiguration. Hypothesis 3: Database connection pool exhaustion.",
  "thoughtNumber": 1,
  "totalThoughts": 5,
  "nextThoughtNeeded": true
}

// → Tool call: Read firewall logs

// Thought 2: Analyze results
{
  "thought": "Firewall logs are clean - no blocked connections matching the error timeframe. Hypothesis 1 eliminated. Moving to Hypothesis 2.",
  "thoughtNumber": 2,
  "totalThoughts": 5,
  "nextThoughtNeeded": true
}

// → Tool call: Read nginx.conf

// Thought 3: Revision after evidence
{
  "thought": "The firewall logs are clean but nginx timeout is set to 60s while the upstream service can take 90s under load. This confirms Hypothesis 2. Revising my initial assessment to focus entirely on timeout configuration.",
  "thoughtNumber": 3,
  "isRevision": true,
  "revisesThought": 1,
  "totalThoughts": 5,
  "nextThoughtNeeded": true
}
```

## Architecture Trade-off Protocol Template

Use the **Fork-Join pattern** for design decisions with mutually exclusive options:

1. **Frame** (Thought 1): Define problem, constraints, and options to evaluate
2. **Fork** (Thoughts 2-3): Create parallel branches with `branchFromThought` pointing to frame, each with unique `branchId`
3. **Analyze**: 2-3 steps per branch evaluating pros/cons
4. **Join** (Synthesis): Return to main trunk (no `branchId`) and synthesize findings

**Key parameters:**
- `branchFromThought`: Origin thought number (same for all branches)
- `branchId`: Unique identifier per option (e.g., `"option-redis"`, `"option-inmemory"`)

For complete Fork-Join examples with full JSON, see `references/branching-revision.md#the-fork-join-decision-tree-pattern`.

## Code Review Pattern

```
Review this authentication module for security issues and architectural problems.
Use sequential thinking to ensure thorough analysis.

Expected thought progression:
1. Security surface analysis (attack vectors, input validation)
2. Architectural assessment (coupling, testability, extensibility)
3. Code quality evaluation (error handling, edge cases)
4. Prioritized findings with severity ratings
5. Refactoring recommendations with implementation order
```

## Quality Heuristics for Evaluating Chains

### Chain Quality Metrics

| Metric | Good Sign | Warning Sign |
|--------|-----------|--------------|
| **Branch Factor** | Multiple alternatives explored | Linear chain with no branches |
| **Revision Rate** | Self-corrections present | 10+ steps with zero revisions |
| **Thought Density** | Each thought adds new insight | "Thinking...", "Still analyzing..." |
| **Convergence** | Clear synthesis step | Abrupt termination |

**Suspicious pattern:** A linear chain of 10 steps with no revisions suggests the model is "autopiloting" rather than reasoning critically.

### Signs of Productive Chains

- Each thought contains a NEW hypothesis, data point, or decision
- Specific findings with evidence citations
- Appropriate branching when alternatives exist
- Revisions when tool outputs contradict assumptions
- Explicit convergence synthesizing branches

### Signs of Unproductive Chains

Quick checklist—if any are true, chain quality is suspect:
- [ ] Thoughts lack new hypotheses/data/decisions
- [ ] Circular reasoning (same points repeated)
- [ ] Tool outputs ignored or contradicted
- [ ] Abrupt termination without synthesis

For detailed anti-patterns with remediation prompts, see `SKILL.md#anti-patterns-avoid-these`.

### Termination Criteria

> See `SKILL.md#termination-criteria` for the complete list. Final thought MUST set `nextThoughtNeeded: false`.

## Quality Diagnostics

### Detecting Autopilot Mode

When chains appear like:
- "Step 1: Analyzing..."
- "Step 2: Thinking..."
- "Step 3: Continuing..."

The model is "rubber stamping" without real reasoning.

**Fix:** Update system prompt:
```
Every thought MUST contain at least one of:
- A new hypothesis or data point
- A decision or conclusion
- A revision of previous thinking
- A specific finding with evidence

Thoughts like "Analyzing..." or "Thinking..." are forbidden.
```

### Detecting Orphaned Branches

Check if branches are created but never synthesized. Look for:
- `branchId` created but no subsequent thought without `branchId` that references findings
- Final thought doesn't mention branch conclusions

**Fix:** Add synthesis rule to prompt:
```
Every branch MUST end with a convergence thought that integrates findings back into the main flow.
```

