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

## Tool Combination Patterns

| Pattern | Sequence | Use Case |
|---------|----------|----------|
| Deep Analysis | thinkdeep → consensus → challenge | Major architecture decisions |
| Code Quality | codereview → precommit | Pre-merge validation |
| Research-to-Implement | apilookup → chat → planner → clink | Building with unfamiliar APIs |
| Debugging | debug → thinkdeep → chat | Complex bug investigation |
| Validated Planning | planner → consensus → challenge → planner | High-stakes planning |
