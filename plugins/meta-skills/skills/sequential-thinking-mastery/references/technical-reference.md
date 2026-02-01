# Complete Technical Reference

## Package Information

| Property | Value |
|----------|-------|
| Repository | `modelcontextprotocol/servers` |
| Path | `src/sequentialthinking/` |
| Package | `@modelcontextprotocol/server-sequential-thinking` |
| Version | `0.2.0` (server), `2025.12.18` (npm) |
| License | MIT |
| Transport | stdio (standard input/output) |

> **Version Note:** This documentation targets ST server version 0.2.0 (npm 2025.12.18). Parameter behavior may differ in other versions—check the official repository for updates.

## ThoughtData Interface

```typescript
interface ThoughtData {
  thought: string;              // Current thinking step content (REQUIRED)
  thoughtNumber: number;        // Current position in sequence (REQUIRED, min: 1)
  totalThoughts: number;        // Estimated total steps (REQUIRED, min: 1, adjustable)
  nextThoughtNeeded: boolean;   // Whether to continue thinking (REQUIRED)
  isRevision?: boolean;         // Marks thought as revising previous work
  revisesThought?: number;      // Which thought number is being reconsidered
  branchFromThought?: number;   // Origin point for alternative exploration
  branchId?: string;            // Unique identifier for the branch
  needsMoreThoughts?: boolean;  // Signal that estimate needs extending
}
```

## State Management

```typescript
class SequentialThinkingServer {
  private thoughtHistory: ThoughtData[] = [];           // Working memory - all thoughts chronologically
  private branches: Record<string, ThoughtData[]> = {}; // Multiverse - parallel reasoning paths
}
```

### Cognitive State Architecture

The two data structures define the "cognitive state" of the agent:

1. **thoughtHistory**: Linear registry acting as "working memory," preserving chronological sequence of all accepted thoughts
2. **branches**: Dictionary enabling non-linear "multiverse" of reasoning—exploring alternatives without polluting main trunk

### In-Memory Implications

- **Benefit:** Extremely low latency for read/write during thought loop
- **Risk:** If MCP connection severs or parent process restarts, reasoning state is **instantly vaporized**
- **Best suited for:** Session-scoped problem solving, NOT long-term memory

### State Echo Mechanism

The `processThought` method returns the ENTIRE `thoughtHistory` as JSON in every response. This "state echo" re-injects context into the LLM's window, ensuring the model doesn't lose its place in the sequence.

## Input/Output Contracts

### Successful Response

```json
{
  "content": [{
    "type": "text",
    "text": "{\"thoughtNumber\":3,\"totalThoughts\":7,\"nextThoughtNeeded\":true,\"branches\":[],\"thoughtHistoryLength\":3}"
  }]
}
```

### Error Response

```json
{
  "content": [{
    "type": "text",
    "text": "{\"error\":\"Invalid thoughtNumber: must be a number\",\"status\":\"failed\"}"
  }],
  "isError": true
}
```

## Performance Metrics

| Metric | Observation |
|--------|-------------|
| **Latency** | P95: ~290ms per thought (Smithery stats) |
| **Success rate** | 86% (Smithery stats) |
| **Token overhead** | Each thought adds ~50-200 tokens depending on content |
| **Schema overhead** | ~1,500 tokens just for tool definition |
| **MAS variants** | 3-6x higher token consumption (multi-agent versions) |

### Latency Cycle

```
User Request → LLM Generation → MCP Transport → Server Process → MCP Transport → LLM Generation
```

### The "Stop-and-Go" Penalty

Unlike native Chain-of-Thought which streams continuously, Sequential Thinking forces "stop-and-go" behavior—model must stop generating to wait for tool result. In high-latency environments, this adds seconds per step.

### Memory Growth

`thoughtHistory` grows linearly. For chains of 100+ steps, the JSON echoed back can approach token limits. Community benchmarks show hundreds of tokens consumed per thought step.

## Behavioral Analysis

Using Sequential Thinking fundamentally alters the cognitive profile of the AI agent:

### Deterministic Anchoring
Native CoT is probabilistic—model "surfs" token probability distributions. ST anchors this process. Once a thought is committed to `thoughtHistory`, it becomes **immutable data**. The model can no longer "drift" from a premise without explicitly revising it.

### Metacognitive Loading
The requirement to fill `totalThoughts` and `nextThoughtNeeded` forces "Metacognition"—thinking about thinking. The model must evaluate progress relative to goal at every step. This constant self-evaluation significantly reduces "hallucination spirals" where the model invents facts to support previous errors.

### Token Economics (Cost-Benefit)

| Factor | Impact |
|--------|--------|
| **Overhead** | Tool definition + JSON wrapping adds ~20-30% per step |
| **Benefit** | `isRevision=true` catches errors early, saving tokens wasted on flawed code generation |
| **Net effect** | For complex tasks, total tokens often DECREASE because "Time to Correct Solution" is lower |

## Known Issues and Workarounds

### Type Validation Errors

**Symptom:** LLMs sometimes generate string values (`"1"`) instead of integers (`1`).
**Workaround:** Explicit prompting to ensure numeric types.

### OpenAI Description Length Limit

**Symptom:** OpenAI models fail with "string too long" error (tool description is 2,780 chars, limit is 1,024).
**Workaround:** Use Claude models, or implement a proxy that truncates the description.

### Windows Connection Issues

**Symptom:** "Not connected" errors on Windows 11 with some MCP clients.
**Workaround:** Install globally instead of using npx:
```bash
npm install -g @modelcontextprotocol/server-sequential-thinking
```

## Sequential Thinking vs Extended Thinking

| Feature | Extended Thinking | Sequential Thinking MCP |
|---------|-------------------|------------------------|
| **Visibility** | Internal, invisible | External, visible |
| **State** | Single pre-generation | Persistent across calls |
| **Branching** | No | Yes |
| **Revision** | No | Yes |
| **User intervention** | No | Yes (can guide process) |
| **Auditability** | Limited | Full reasoning trail |
| **Token cost** | Lower | Higher |
| **Best for** | General reasoning | Complex, auditable decisions |

**Anthropic guidance (December 2025):** "Extended thinking capabilities have improved such that we recommend using that feature instead of a dedicated think tool in most cases."

**Use Sequential Thinking MCP when:**
- Reasoning process must be visible and auditable
- Explicit branching or revision capabilities needed
- Working with non-Claude models
- Building agent systems that need structured reasoning state

## Design Clarifications

### No External totalThoughts Constraint

**Common misconception:** Users cannot externally limit the number of thoughts via configuration.

**Reality:** This is by design—`totalThoughts` is a **heuristic estimate** that the LLM adjusts dynamically during reasoning. The server auto-adjusts `totalThoughts` upward if `thoughtNumber` exceeds the current estimate.

**Implication:** Use prompt engineering to guide reasonable limits (e.g., "Complete analysis in 5-7 thoughts"). The model controls chain length, not configuration.

### Passive Infrastructure Model

The Sequential Thinking server is **passive infrastructure**—it records and organizes thoughts but does **not** perform reasoning itself. It provides cognitive scaffolding; the quality of output depends entirely on how effectively the LLM leverages the structured framework.

**Key distinction:**
- ✗ ST does NOT: Generate insights, make decisions, or reason autonomously
- ✓ ST DOES: Store state, enable branching, track revisions, provide auditability

## Uncertainty and Known Gaps

### Areas of Uncertainty

| Area | Current State |
|------|---------------|
| **Optimal chain lengths** | No definitive research on ideal lengths by problem type; current guidance is heuristic-based |
| **Branch convergence** | Limited documentation on best practices for synthesizing insights from multiple branches |
| **Long-term memory** | No clear guidance on maximum practical chain lengths before context degradation |
| **Model-specific behavior** | Most documentation assumes Claude; behavior with GPT-4, Gemini less documented |

### Conflicting Information

1. **Necessity debate**: Some developers report ST is redundant with Extended Thinking; others report continued value. The distinction likely depends on need for **visibility and auditability**.

2. **Version compatibility**: Some GitHub issues suggest recent updates may have changed parameter handling; verify behavior with current versions.

### Recommendation

When encountering edge cases or unexpected behavior:
1. Check the official repository for recent issues/changes
2. Test with explicit prompting patterns
3. Use the troubleshooting guide for common problems

---

## Related References

- **Prompting patterns**: `prompting-patterns.md` - Strategic templates, debug protocols, quality heuristics
- **Branching/Revision**: `branching-revision.md` - Fork-Join pattern, revision loop, convergence rules
- **Troubleshooting**: `troubleshooting.md` - Error -32000, infinite loops, token optimization
