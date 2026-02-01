# PAL MCP Anti-Patterns

> **Legend**: ❌ Bad pattern | ✅ Good pattern | ⚠️ Warning

## ⚠️ Context Budget Catastrophe

**The Problem:** PAL tool definitions consume ~90KB of context—nearly 60% of available context in some configurations.

**Solution:**
```bash
# Always disable unused tools
DISABLED_TOOLS=analyze,refactor,testgen,secaudit,docgen,tracer
```

**Rule:** Enable only the tools needed. Add tools as needed rather than enabling everything.

---

## ⚠️ The Sycophancy Trap

**The Problem:** AI agents frequently suffer from "Sycophancy" — agreeing with the developer's proposed solution even if it is suboptimal. This is particularly dangerous in architectural planning.

**Detection Signals:**
- Responding with "You're absolutely right!"
- "That's a great idea!"
- "I completely agree!"
- Enthusiastic agreement without testing assumptions

**Solution:** **Auto-invoke `challenge`** upon detecting enthusiastic agreement. The `challenge` tool is the primary guardrail against this behavior.

**Pattern:**
```
# ❌ BAD: Reflexive agreement
User: "Let's use microservices for our 3-person team"
Agent: "That's a great idea! Microservices will give you..."

# ✅ GOOD: Challenge before agreement
User: "Let's use microservices for our 3-person team"
Agent: [Internally detects enthusiastic agreement → auto-invoke challenge]
challenge(prompt="Microservices are the right choice for a team of 3 developers")
→ Surfaces: operational overhead, distributed debugging complexity, etc.
```

---

## ❌ Tool Misuse Patterns

| Don't Do This | Why It Fails | Do This Instead |
|---------------|--------------|-----------------|
| `thinkdeep` for simple questions | Overkill, wastes tokens and time | Use `chat` for quick questions |
| `consensus` for clear-cut decisions | Wastes resources when answer is obvious | Use `chat` to verify, `consensus` only for genuine debates |
| `challenge` every decision | Counterproductive, slows workflow | Reserve for critical assumptions |
| `continuation_id` across unrelated topics | Pollutes context, confuses models | Start fresh threads for new topics |
| Relative file paths | `./file.py` fails silently | Always use `/absolute/path/to/file.py` |
| Vision task to non-vision model | Model can't provide feedback | Check `listmodels` for vision capability |
| `analyze` + `codereview` same file | Overlapping logic, wastes tokens | Choose one based on goal |

---

## ❌ Parameter Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Wrong step_number/total_steps ratio | Investigation feels incomplete | Start with estimated total, adjust as you go |
| `confidence="high"` too early | Premature conclusions | Progress naturally: exploring → low → medium → high |
| `thinking_mode="high"` for simple tasks | Slow, expensive | Use `low` or `medium` for routine checks |
| Forgetting `next_step_required=false` | Workflow never terminates | Set to `false` on your final step |
| Setting `total_steps: 1` for complex problems | Forces premature conclusions | Use 3-6 steps for thorough analysis |

---

## ⚠️ Workflow Failures

| Problem | Signs | Recovery |
|---------|-------|----------|
| Circular reasoning loop | Same hypotheses keep recurring | Break chain, manually provide new evidence |
| Context overflow | Responses truncate, timeout errors | Use `clink` for isolation, delegate to Gemini (1M tokens) |
| Breaking continuation prematurely | Loss of context between steps | Always capture and pass `continuation_id` |
| Skipping validation | Bugs slip through | Always end with `codereview` → `precommit` |

---

## ⚠️ When to Abandon and Start Fresh

- Confidence stuck at "exploring" after **3+ iterations**
- Models **fundamentally disagree** on basic facts
- `precommit` finds **new critical issues** not caught in earlier reviews
- Conversation thread exceeds **20 turns** (MAX_CONVERSATION_TURNS default)

---

## ⚠️ API Key Anti-Patterns

### Mixing OpenRouter with Native APIs

**Problem:** Using both OpenRouter AND native provider APIs creates routing ambiguity.

**Solution:** Choose one strategy:
- **Native APIs**: Direct connections (lowest latency, multiple keys)
- **OpenRouter**: Single API for all models (simpler, added latency)

### Forgetting to Restart After Config Changes

**Problem:** Changes to `.env` or `DISABLED_TOOLS` don't take effect until restart.

**Solution checklist:**
1. Set `FORCE_ENV_FILE=true` in `.env`
2. Save `.env` file
3. Completely restart Claude Code
4. Verify with `listmodels`

---

## ❌ Workflow Anti-Patterns

### Redundant Multi-Model Calls

**❌ Bad:**
```
consensus with ["pro", "flash", "o3", "gpt5", "gpt5-mini"]
→ Question: "What's the best way to parse JSON in Python?"
```

**✅ Good:**
```
chat with pro → "What's the best way to parse JSON in Python?"
```

Save multi-model calls for genuinely contested decisions.

### Ignoring continuation_id

**❌ Bad:**
```
debug → "Investigate auth bug"
debug → "Check the login flow" (no continuation_id)
debug → "Look at session handling" (no continuation_id)
→ Each call starts from zero context
```

**✅ Good:**
```
debug → "Investigate auth bug" → continuation_id: abc123
debug → "Check the login flow" → continuation_id: abc123
debug → "Look at session handling" → continuation_id: abc123
→ Each call builds on previous findings
```

### Challenge Before Investigation

**❌ Bad:**
```
challenge → "Challenge whether we need a database"
→ No context, no analysis, premature criticism
```

**✅ Good:**
```
thinkdeep → "Analyze our data storage requirements" → findings
consensus → "Should we use PostgreSQL or DynamoDB?" → recommendation
challenge → "Challenge the PostgreSQL recommendation" → informed critique
```

### Premature Confidence Escalation

**Problem:** Agent marks hypothesis as "certain" to skip the expert analysis phase.

This removes the primary benefit of PAL: independent validation. Only use `certain` when solution is 100% verified with evidence.

### Memory/Context Overflow

**Problem:** Sending entire directories like `node_modules/` or `.git/` to server.

While PAL filters files, excessively large `relevant_files` lists still bloat context. Be selective.

### Local Model Timeout Triggers

**Problem:** Local models (Ollama) significantly slower than cloud APIs.

If `CUSTOM_READ_TIMEOUT` isn't tuned, complex reasoning tasks timeout before completion. Use lower `thinking_mode` or increase timeouts for local models.

---

## ❌ Tool Selection Anti-Patterns

| Wrong Tool | Right Tool | Scenario |
|------------|-----------|----------|
| `thinkdeep` | `chat` | Simple question needing quick answer |
| `consensus` | `thinkdeep` | Single-perspective deep analysis needed |
| `codereview` | `debug` | Investigating runtime bug, not code quality |
| `chat` | `apilookup` | Need current API documentation |
| `planner` | `chat` | Simple task, not complex project |
| Multiple tools | `clink` | Task would consume too much context |

---

## ❌ The Everything-At-Once Prompt

**Problem:** Cramming multiple tool requests in one prompt confuses the agent.

**❌ Bad:**
```
"Use debug to fix the error and then use the agent's internal scratchpad to optimize it."
→ Mixed instructions make Claude uncertain which tool to use
```

**✅ Good:**
```
# First, complete debug
"Use debug to find the root cause of this error."
→ Wait for completion

# Then, give new instruction
"Now optimize the fix you identified."
```

**Rule:** Split into clear sequential commands. Each tool should be invoked with a single focus.

---

## ⚠️ Ignoring Tool Output Signals

**Problem:** Tools output status indicators that require action.

| Status | Meaning | Action Required |
|--------|---------|-----------------|
| `pause_for_codereview` | Multi-step review in progress | Say "continue" or "proceed" |
| `pause_for_debug` | Investigation paused mid-step | Say "continue debugging" |
| `next_step_required: true` | Workflow expects more steps | Continue the workflow |
| `confidence: exploring` | Low certainty, more analysis needed | Provide more context or continue |

**Anti-pattern:** Assuming single output is final when tool clearly indicates more steps needed.

**Recovery:** If unsure, ask "Is the [tool] complete or should I continue?"

---

## ⚠️ Circular Reasoning Loops

**Symptoms:**
- Same hypotheses recurring without new evidence
- AI summarizing its own prior content repeatedly
- Token usage spiking without progress
- Debug or thinkdeep "gets stuck and runs forever"

**Causes:**
- Context overflow causing confusion
- Insufficient new information provided
- No clear termination criteria

**Recovery Steps:**
1. **Stop** the generation immediately
2. **Summarize**: "Stop and summarize findings so far"
3. **Reset**: Start fresh with the summary as input
4. **Narrow scope**: Break problem into smaller parts
5. **Add new info**: Provide additional logs, context, or constraints

**Prevention:** If no progress after 3+ iterations, intervene manually.

---

## ⚠️ Failure to Recover Gracefully

**Problem:** When something goes wrong, continuing blindly or giving up entirely.

### Recovery Strategies

| Failure | Recovery |
|---------|----------|
| Model timeout mid-workflow | Re-invoke that phase: "Continue codereview with o3 only" |
| Gemini failed in multi-model | "Retry consensus with fewer models" |
| Context overflow | Start fresh session with summary of key findings |
| Conversation utterly confused | "Recall what we discussed about X and continue" |

### Graceful Degradation

When a model causes issues (slow, rate limited):
```
# Instead of failing
"Using GPT-5-high is timing out, let's try with GPT-4 or medium mode."
```

**Principle:** Better to get some result with a smaller model than none with a larger one.

### Context Revival Pattern

If Claude's context resets but another model still has history:
```
"Continue with O3"
→ O3 still has combined context
→ O3's response reintroduces context to Claude
```

This "reminds" Claude of what was discussed via another model's memory.
