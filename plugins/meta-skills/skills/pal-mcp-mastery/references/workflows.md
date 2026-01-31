# PAL MCP Workflow Templates

## Workflow A: Complex Bug Investigation

**Trigger:** Difficult bug requiring systematic hypothesis testing and multi-model validation.

```
Step 1: debug
─────────────────────────────────────────────────
debug(
  step="Reproduce and characterize the issue",
  step_number=1,
  total_steps=4,
  next_step_required=True,
  findings="Initial symptoms: [describe]",
  model="o3",
  relevant_files=["/src/affected_file.py"],
  confidence="exploring"
)

Step 2: debug (continue)
─────────────────────────────────────────────────
debug(
  step="Test hypothesis: [specific theory]",
  step_number=2,
  total_steps=4,
  next_step_required=True,
  findings="Evidence for/against hypothesis",
  hypothesis="[Your theory]",
  confidence="low",
  model="o3",
  continuation_id="<from_step_1>"
)

Step 3: thinkdeep (extend analysis)
─────────────────────────────────────────────────
thinkdeep(
  step="Explore edge cases and alternative root causes",
  step_number=3,
  total_steps=4,
  next_step_required=True,
  findings="Additional considerations",
  thinking_mode="high",
  relevant_files=["/src/affected_file.py"],
  continuation_id="<from_debug>"
)

Step 4: codereview (validate fix)
─────────────────────────────────────────────────
codereview(
  step="Verify fix doesn't introduce new issues",
  step_number=1,
  total_steps=2,
  next_step_required=True,
  findings="Fix analysis",
  model="pro",
  relevant_files=["/src/affected_file.py"],
  focus_on="regression safety"
)

Step 5: precommit (final gate)
─────────────────────────────────────────────────
precommit(
  step="Final validation before commit",
  step_number=1,
  total_steps=1,
  next_step_required=False,
  findings="All checks pass",
  model="pro",
  confidence="high"
)
```

**Stop if:** Confidence stays at "exploring" after 3+ iterations → manually investigate.

---

## Workflow B: Code Review Before PR

**Trigger:** Changes ready for PR, need quality assurance.

```
Step 1: codereview (initial pass)
─────────────────────────────────────────────────
codereview(
  step="Initial security and quality scan",
  step_number=1,
  total_steps=4,
  next_step_required=True,
  findings="Initial findings",
  model="auto",
  relevant_files=["/src/module/"],
  confidence="exploring"
)

Step 2: codereview (second opinion)
─────────────────────────────────────────────────
codereview(
  step="Deep secondary review for edge cases",
  step_number=2,
  total_steps=4,
  next_step_required=True,
  findings="Additional findings",
  model="pro",
  issues_found=[{severity: "...", description: "..."}],
  confidence="medium",
  continuation_id="<from_step_1>"
)

Step 3: codereview (architectural check)
─────────────────────────────────────────────────
codereview(
  step="Architectural and logical consistency review",
  step_number=3,
  total_steps=4,
  next_step_required=True,
  findings="Architecture notes",
  model="o3",
  confidence="high",
  continuation_id="<from_step_2>"
)

Step 4: precommit (final validation)
─────────────────────────────────────────────────
precommit(
  step="Validate all changes meet requirements",
  step_number=1,
  total_steps=3,
  next_step_required=False,
  findings="Final validation complete",
  model="pro",
  relevant_files=["/src/module/"],
  continuation_id="<from_step_3>"
)
```

**Key insight:** Each model knows what previous ones found—full context flows between models.

---

## Workflow C: Architectural Decision Making

**Trigger:** Critical technical decision needing bias-free multi-model validation.

```
Step 1: thinkdeep (initial analysis)
─────────────────────────────────────────────────
thinkdeep(
  step="Analyze [Option A] vs [Option B] tradeoffs",
  step_number=1,
  total_steps=3,
  next_step_required=True,
  findings="Initial analysis",
  thinking_mode="high",
  model="pro"
)

Step 2: challenge (test assumptions)
─────────────────────────────────────────────────
challenge(
  prompt="[Statement of your current leaning, e.g., 'Option A is better for our team']"
)

Step 3: consensus (multi-model debate)
─────────────────────────────────────────────────
consensus(
  step="Multi-model evaluation of options",
  step_number=1,
  total_steps=4,
  next_step_required=True,
  findings="My analysis before consulting models",
  models=[
    {model: "gpt-5", stance: "for"},
    {model: "gemini-pro", stance: "against"},
    {model: "o3", stance: "neutral"}
  ]
)

Step 4: planner (implementation roadmap)
─────────────────────────────────────────────────
planner(
  step="Create implementation roadmap for chosen approach",
  step_number=1,
  total_steps=3,
  next_step_required=True,
  model="pro",
  continuation_id="<from_consensus>"
)
```

**Stop if:** All models agree immediately → likely missing nuance, add more context.

---

## Workflow D: Learning New API/Library

**Trigger:** Working with unfamiliar API, need current documentation.

```
Step 1: apilookup (current docs)
─────────────────────────────────────────────────
apilookup(
  prompt="[Technology] [specific feature] current documentation"
)

Step 2: chat (brainstorm patterns)
─────────────────────────────────────────────────
chat(
  prompt="What's the best approach for [specific use case]?",
  model="pro",
  continuation_id="<from_apilookup>"
)

Step 3: thinkdeep (edge cases)
─────────────────────────────────────────────────
thinkdeep(
  step="Explore error handling edge cases",
  step_number=1,
  total_steps=2,
  next_step_required=True,
  findings="Edge case analysis",
  thinking_mode="medium",
  continuation_id="<from_chat>"
)

Step 4: codereview (validate implementation)
─────────────────────────────────────────────────
codereview(
  step="Verify implementation follows current best practices",
  step_number=1,
  total_steps=1,
  next_step_required=False,
  findings="Best practices compliance",
  model="pro",
  focus_on="API usage patterns"
)
```

---

## Workflow E: Context-Heavy Investigation

**Trigger:** Task that would consume too much main context.

```
Step 1: clink (spawn isolated subagent)
─────────────────────────────────────────────────
clink(
  prompt="[Detailed task description]",
  cli_name="codex",
  role="codereviewer",
  absolute_file_paths=["/src/module/"]
)
→ Subagent returns report without polluting main context

Step 2: debug (systematic investigation)
─────────────────────────────────────────────────
debug(
  step="Investigate root cause based on subagent findings",
  step_number=1,
  total_steps=3,
  next_step_required=True,
  findings="<incorporate_clink_report>",
  model="o3",
  thinking_mode="max"
)

Step 3: codereview + precommit (fix validation)
─────────────────────────────────────────────────
codereview(step="Validate fix", ...)
precommit(step="Final regression check", ...)
```

---

## Workflow F: Refactoring with Validation

**Trigger:** Code cleanup, design pattern adoption, or tech debt reduction requiring safe, verified transformations.

```
Step 1: planner (outline refactor steps)
─────────────────────────────────────────────────
planner(
  step="Break down refactor into safe, atomic steps",
  step_number=1,
  total_steps=3,
  next_step_required=True,
  model="pro"
)
→ Output: numbered task list with logical sequence

Step 2: refactor/chat (execute transformations)
─────────────────────────────────────────────────
# If refactor tool enabled:
refactor(
  step="Execute step 1: [specific transformation]",
  ...
)

# If refactor disabled, use chat:
chat(
  prompt="Implement step 1: [specific transformation]",
  model="pro",
  continuation_id="<from_planner>"
)
→ Work step by step, run tests after each major change

Step 3: testgen (ensure coverage)
─────────────────────────────────────────────────
testgen(
  prompt="Create unit tests for refactored components"
)
→ Generates tests for critical paths and edge cases

Step 4: codereview (validate changes)
─────────────────────────────────────────────────
codereview(
  step="Verify refactor didn't introduce issues",
  step_number=1,
  total_steps=2,
  next_step_required=True,
  findings="Checking for incomplete changes, unused code",
  model="pro",
  relevant_files=["/src/refactored_module/"],
  continuation_id="<from_step_3>"
)

Step 5: precommit (final regression check)
─────────────────────────────────────────────────
precommit(
  step="Final validation before commit",
  step_number=1,
  total_steps=3,
  next_step_required=False,
  findings="All checks pass",
  model="pro",
  continuation_id="<from_step_4>"
)
```

**Key insight:** Interleave tests between steps. Don't save all validation for the end—catch issues early.

---

## Workflow G: Debugging Production Issues

**Trigger:** Production incident with logs/metrics but hard to reproduce locally.

```
Step 1: debug (analyze production logs)
─────────────────────────────────────────────────
debug(
  step="Analyze production logs for patterns",
  step_number=1,
  total_steps=4,
  next_step_required=True,
  findings="Initial log analysis: [paste abbreviated logs]",
  model="o3",
  thinking_mode="high"
)
→ Tip: Preprocess logs - summarize via chat first if too large

Step 2: thinkdeep (systemic causes)
─────────────────────────────────────────────────
thinkdeep(
  step="Explore architecture and environment factors",
  step_number=2,
  total_steps=4,
  next_step_required=True,
  findings="Considering: config issues, race conditions, resource leaks",
  hypothesis="[Theory based on evidence]",
  thinking_mode="max",
  continuation_id="<from_debug>"
)
→ Production issues often involve environment (Docker config, network, etc.)

Step 3: consensus (cross-check with another model)
─────────────────────────────────────────────────
consensus(
  step="Validate hypothesis with diverse perspectives",
  step_number=1,
  total_steps=3,
  next_step_required=True,
  findings="Cross-checking root cause hypothesis",
  models=[
    {model: "gpt-5", stance: "neutral", stance_prompt: "focus on code-level causes"},
    {model: "gemini-pro", stance: "neutral", stance_prompt: "focus on infrastructure causes"}
  ],
  continuation_id="<from_thinkdeep>"
)
→ Different models may catch environment vs code issues

Step 4: precommit (validate fix)
─────────────────────────────────────────────────
precommit(
  step="Verify fix addresses root cause",
  step_number=1,
  total_steps=3,
  next_step_required=False,
  findings="Fix validation complete",
  model="pro",
  continuation_id="<from_consensus>"
)
```

**Expected Outcome:** RCA document with systematic hypothesis trail, suitable for incident documentation.

**Watch For:** If debug loops without progress, stop and restart with "Summarize findings so far."

---

## Workflow H: Architectural Transformation

**Trigger:** Refactoring a legacy system requiring architectural understanding spanning hundreds of files.

```
Step 1: Discovery (analyze)
─────────────────────────────────────────────────
analyze(
  step="Map architecture, data flows, and design patterns",
  analysis_type="architecture",
  output_format="detailed",
  relevant_files=["/src/legacy/"],
  model="pro"
)
→ Identifies key components across the directory structure

Step 2: Debate (consensus with stance steering)
─────────────────────────────────────────────────
consensus(
  step="Evaluate proposed microservices extraction",
  step_number=1,
  total_steps=3,
  next_step_required=True,
  findings="Technical proposal for service boundaries",
  models=[
    {model: "gpt-5", stance: "for", stance_prompt: "Advocate for the proposed architecture"},
    {model: "gemini-pro", stance: "against", stance_prompt: "Critique integration risks and complexity"}
  ]
)
→ Structured debate highlights potential integration risks

Step 3: Planning (planner)
─────────────────────────────────────────────────
planner(
  step="Convert agreed architecture into phased implementation plan",
  step_number=1,
  total_steps=4,
  next_step_required=True,
  model="pro",
  continuation_id="<from_consensus>"
)
→ Defined checkpoints for validation

Step 4: Execution (clink for heavy lifting)
─────────────────────────────────────────────────
clink(
  prompt="Decompose UserService module into smaller testable units",
  cli_name="codex",
  role="codereviewer",
  absolute_file_paths=["/src/legacy/user/"],
  continuation_id="<from_planner>"
)
→ Heavy refactor in isolated context
```

---

## Workflow I: Learning New Technologies

**Trigger:** Developers adopting current-year technologies where standard model training data is insufficient.

```
Step 1: Research (apilookup)
─────────────────────────────────────────────────
apilookup(
  prompt="React 19 Server Components streaming patterns documentation"
)
→ Targeted search for latest SDK docs and breaking change logs

Step 2: Context Building (chat with high-context model)
─────────────────────────────────────────────────
chat(
  prompt="Based on the current docs, explain the streaming data flow",
  model="pro",  # Gemini Pro: 1M token context
  continuation_id="<from_apilookup>"
)
→ Build mental model of the new framework

Step 3: Prototyping (planner)
─────────────────────────────────────────────────
planner(
  step="Plan minimal viable implementation with streaming SSR",
  step_number=1,
  total_steps=3,
  next_step_required=True,
  model="pro",
  continuation_id="<from_chat>"
)

Step 4: Safety Check (precommit)
─────────────────────────────────────────────────
precommit(
  step="Verify prototype aligns with project constraints",
  step_number=1,
  total_steps=3,
  next_step_required=False,
  findings="Technology choice validated against requirements",
  model="pro",
  continuation_id="<from_planner>"
)
```

**Key insight**: `apilookup` prevents "hallucinated fixes" based on outdated knowledge of third-party libraries.

---

## Tool Combination Patterns

| Pattern | Sequence | Use Case |
|---------|----------|----------|
| Deep Analysis | thinkdeep → consensus → challenge | Major architecture decisions |
| Code Quality | codereview → precommit | Pre-merge validation |
| Research-to-Implement | apilookup → chat → planner → clink | Building with unfamiliar APIs |
| Debugging | debug → thinkdeep → chat | Complex bug investigation |
| Validated Planning | planner → consensus → challenge → planner | High-stakes planning |
| Safe Refactoring | planner → refactor → testgen → codereview → precommit | Tech debt cleanup |
| Production RCA | debug → thinkdeep → consensus → precommit | Incident investigation |
| Feature Implementation | planner → consensus → chat → codereview → precommit | New feature development |
| Large-Scale Refactor | analyze → clink → thinkdeep → debug | Cross-file dependency work |

---

## Model Selection Best Practices

For high-performance workflows, use this tiered model strategy:

| Role | Model | Rationale |
|------|-------|-----------|
| **Primary Agent** | Claude 3.5 Sonnet | Orchestration and tool calling |
| **Deep Reasoning** | Gemini 3.0 Pro or GPT-5.2 | Expert phases, complex analysis |
| **Fast Validation** | Gemini 2.5 Flash or GPT-4o-mini | Quick checks, subagent tasks |

This ensures expensive reasoning tokens are consumed only when complexity warrants it.
