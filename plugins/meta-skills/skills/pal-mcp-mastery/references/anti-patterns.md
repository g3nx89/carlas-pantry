# PAL MCP Anti-Patterns

## Context Budget Catastrophe

**The Problem:** PAL tool definitions consume ~90KB of context—nearly 60% of available context in some configurations.

**Solution:**
```bash
# Always disable unused tools
DISABLED_TOOLS=analyze,refactor,testgen,secaudit,docgen,tracer
```

**Rule:** Enable only tools you'll use. Add tools as needed rather than enabling everything.

---

## Tool Misuse Patterns

| Don't Do This | Why It Fails | Do This Instead |
|---------------|--------------|-----------------|
| `thinkdeep` for simple questions | Overkill, wastes tokens and time | Use `chat` for quick questions |
| `consensus` for clear-cut decisions | Wastes resources when answer is obvious | Use `chat` to verify, `consensus` only for genuine debates |
| `challenge` every decision | Counterproductive, slows workflow | Reserve for critical assumptions |
| `continuation_id` across unrelated topics | Pollutes context, confuses models | Start fresh threads for new topics |
| Relative file paths | `./file.py` fails silently | Always use `/absolute/path/to/file.py` |

---

## Parameter Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Wrong step_number/total_steps ratio | Investigation feels incomplete | Start with estimated total, adjust as you go |
| `confidence="high"` too early | Premature conclusions | Progress naturally: exploring → low → medium → high |
| `thinking_mode="high"` for simple tasks | Slow, expensive | Use `low` or `medium` for routine checks |
| Forgetting `next_step_required=false` | Workflow never terminates | Set to `false` on your final step |
| Setting `total_steps: 1` for complex problems | Forces premature conclusions | Use 3-6 steps for thorough analysis |

---

## Workflow Failures

| Problem | Signs | Recovery |
|---------|-------|----------|
| Circular reasoning loop | Same hypotheses keep recurring | Break chain, manually provide new evidence |
| Context overflow | Responses truncate, timeout errors | Use `clink` for isolation, delegate to Gemini (1M tokens) |
| Breaking continuation prematurely | Loss of context between steps | Always capture and pass `continuation_id` |
| Skipping validation | Bugs slip through | Always end with `codereview` → `precommit` |

---

## When to Abandon and Start Fresh

- Confidence stuck at "exploring" after **3+ iterations**
- Models **fundamentally disagree** on basic facts
- `precommit` finds **new critical issues** not caught in earlier reviews
- Conversation thread exceeds **20 turns** (MAX_CONVERSATION_TURNS default)

---

## API Key Anti-Patterns

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

## Workflow Anti-Patterns

### Redundant Multi-Model Calls

**Bad:**
```
consensus with ["pro", "flash", "o3", "gpt5", "gpt5-mini"]
→ Question: "What's the best way to parse JSON in Python?"
```

**Good:**
```
chat with pro → "What's the best way to parse JSON in Python?"
```

Save multi-model calls for genuinely contested decisions.

### Ignoring continuation_id

**Bad:**
```
debug → "Investigate auth bug"
debug → "Check the login flow" (no continuation_id)
debug → "Look at session handling" (no continuation_id)
→ Each call starts from zero context
```

**Good:**
```
debug → "Investigate auth bug" → continuation_id: abc123
debug → "Check the login flow" → continuation_id: abc123
debug → "Look at session handling" → continuation_id: abc123
→ Each call builds on previous findings
```

### Challenge Before Investigation

**Bad:**
```
challenge → "Challenge whether we need a database"
→ No context, no analysis, premature criticism
```

**Good:**
```
thinkdeep → "Analyze our data storage requirements" → findings
consensus → "Should we use PostgreSQL or DynamoDB?" → recommendation
challenge → "Challenge the PostgreSQL recommendation" → informed critique
```

---

## Tool Selection Anti-Patterns

| Wrong Tool | Right Tool | Scenario |
|------------|-----------|----------|
| `thinkdeep` | `chat` | Simple question needing quick answer |
| `consensus` | `thinkdeep` | Single-perspective deep analysis needed |
| `codereview` | `debug` | Investigating runtime bug, not code quality |
| `chat` | `apilookup` | Need current API documentation |
| `planner` | `chat` | Simple task, not complex project |
| Multiple tools | `clink` | Task would consume too much context |
