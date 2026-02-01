---
name: sadd-orchestrator
description: Orchestrates SADD multi-agent patterns for the specification workflow
version: 1.1.0
---

# SADD Orchestrator Skill

## Purpose

Coordinate multi-agent execution for specification workflow enhancements. This skill handles:
- Parallel agent dispatch
- Debate protocols between judges
- Consensus detection
- File-based inter-agent communication

## Capabilities

### 1. Parallel Dispatch

Invoke via: `sadd:parallel-dispatch`

Launches multiple agents in parallel and collects their results.

**Input:**
```yaml
agents:
  - name: "{agent_name}"
    path: "{agent_file_path}"
    model: "sonnet|opus|haiku"
    context:
      SPEC_FILE: "{path}"
      FEATURE_NAME: "{name}"
      FEATURE_DIR: "{dir}"

output_dir: "{directory for agent outputs}"
timeout_per_agent: 120  # seconds
```

**Output:**
```yaml
results:
  - agent: "{agent_name}"
    status: "completed|failed|timeout"
    output_file: "{path to agent's output}"
    duration_seconds: {N}

success_count: {N}
failure_count: {N}
errors:
  - agent: "{agent_name}"
    error: "{error message}"
```

### 2. Judge Debate

Invoke via: `sadd:judge-debate`

Orchestrates adversarial debate between judges with different stances.

**Input:**
```yaml
question:
  id: "{question_id}"
  text: "{question text}"
  options:
    - id: "A"
      description: "{option A}"
    - id: "B"
      description: "{option B}"
    - id: "C"
      description: "{option C}"

judges:
  - name: "risk"
    path: "$CLAUDE_PLUGIN_ROOT/agents/recommendation-judges/risk-judge.md"
    stance: "skeptical"
  - name: "value"
    path: "$CLAUDE_PLUGIN_ROOT/agents/recommendation-judges/value-judge.md"
    stance: "optimistic"
  - name: "effort"
    path: "$CLAUDE_PLUGIN_ROOT/agents/recommendation-judges/effort-judge.md"
    stance: "pragmatic"

context: "{shared context from spec}"
feature_dir: "{output directory}"
max_rounds: 2
```

**Output:**
```yaml
consensus: true|false
consensus_option: "{option ID if consensus}"
confidence: "HIGH|MEDIUM|LOW|REQUIRES_INPUT"

round_1:
  - judge: "risk"
    recommendation: "{option}"
    confidence: "HIGH|MEDIUM|LOW"
  - judge: "value"
    recommendation: "{option}"
    confidence: "HIGH|MEDIUM|LOW"
  - judge: "effort"
    recommendation: "{option}"
    confidence: "HIGH|MEDIUM|LOW"

round_2: # if needed
  - judge: "risk"
    previous: "{option}"
    final: "{option}"
    changed: true|false
    change_reason: "{if changed}"

perspectives:
  risk_favors: "{option} - {reason}"
  value_favors: "{option} - {reason}"
  effort_favors: "{option} - {reason}"

debate_files:
  - "{path to debate-{id}-risk.md}"
  - "{path to debate-{id}-value.md}"
  - "{path to debate-{id}-effort.md}"
```

### 3. Consensus Check

Invoke via: `sadd:consensus-check`

Analyzes judge recommendations to determine if consensus exists.

**Input:**
```yaml
recommendations:
  - judge: "{judge_name}"
    option: "{chosen_option}"
    confidence: "HIGH|MEDIUM|LOW"

threshold: 0.67  # 2/3 agreement required
```

**Output:**
```yaml
consensus: true|false
majority_option: "{option if 2/3+ agree}"
distribution:
  - option: "A"
    votes: 2
    judges: ["risk", "effort"]
  - option: "B"
    votes: 1
    judges: ["value"]
unanimous: false
```

### 4. File Coordination

Invoke via: `sadd:file-coordinator`

Manages file-based communication between agents.

**Actions:**
- `setup`: Create output directory structure
- `collect`: Gather all agent outputs
- `cleanup`: Remove temporary files (optional)

**Input (setup):**
```yaml
action: "setup"
feature_dir: "{path}"
```

**Output (setup):**
```yaml
created:
  - "{feature_dir}/sadd/"
  - "{feature_dir}/sadd/advocates/"
  - "{feature_dir}/sadd/debates/"
  - "{feature_dir}/sadd/questions/"
```

**Input (collect):**
```yaml
action: "collect"
feature_dir: "{path}"
pattern: "advocate-*.md"
```

**Output (collect):**
```yaml
files:
  - path: "{path}"
    size_bytes: {N}
    last_modified: "{timestamp}"
```

## Integration with 01-specify.md

The main command invokes this skill at key points:

### Phase 2: After BA Draft

```markdown
# Invoke SADD orchestrator for stakeholder advocates
Invoke skill: sadd-orchestrator
  Action: parallel-dispatch
  Agents:
    - end-user-advocate
    - business-advocate
    - operations-advocate
    - security-advocate
  Context:
    SPEC_FILE: {spec_file}
    FEATURE_NAME: {feature_name}
    FEATURE_DIR: {feature_dir}
  Output: {feature_dir}/sadd/
```

### Phase 2.5 & 2.7: Gate Evaluation

```markdown
# Invoke SADD orchestrator for gate judgment
Invoke skill: sadd-orchestrator
  Action: invoke-single
  Agent: gate-judge
  Context:
    CONTENT_TO_EVALUATE: {content}
    RUBRIC_FILE: {rubric_path}
    GATE_ID: {gate_id}
    FEATURE_DIR: {feature_dir}
```

### Phase 4.5: Question Discovery

```markdown
# Invoke SADD orchestrator for multi-perspective question discovery
Invoke skill: sadd-orchestrator
  Action: parallel-dispatch
  Agents:
    - ux-perspective
    - business-perspective
    - technical-perspective
  Context:
    SPEC_FILE: {spec_file}
    FEATURE_NAME: {feature_name}
    FEATURE_DIR: {feature_dir}
  Output: {feature_dir}/sadd/questions/
```

### Phase 4.5: Judge Debate (for SCOPE_CRITICAL questions)

```markdown
# Invoke SADD orchestrator for adversarial debate
For each SCOPE_CRITICAL question:
  Invoke skill: sadd-orchestrator
    Action: judge-debate
    Question: {question}
    Options: {options}
    Judges:
      - risk-judge (skeptical)
      - value-judge (optimistic)
      - effort-judge (pragmatic)
    MaxRounds: 2
```

## Configuration

The orchestrator reads configuration from `specs/config/specify-config.yaml`:

```yaml
sadd_patterns:
  enabled: true

  orchestration:
    skill: "$CLAUDE_PLUGIN_ROOT/skills/sadd-orchestrator/SKILL.md"
    timeout_per_agent: 120
    parallel_max_concurrent: 4
    file_coordination:
      base_dir: "sadd/"
      cleanup_on_complete: false
```

## Error Handling

### Agent Timeout

If an agent exceeds `timeout_per_agent`:
1. Log the timeout
2. Mark agent as failed in results
3. Continue with other agents
4. Report partial results

### Agent Failure

If an agent fails:
1. Log the error
2. Mark agent as failed
3. Continue with other agents
4. Report which agents failed

### Debate Deadlock

If debate exceeds `max_rounds` without consensus:
1. Report as "contested"
2. Include all judge perspectives
3. Mark confidence as "REQUIRES_INPUT"
4. Present to user with full context

## Fallback Strategy

If orchestration fails entirely:
1. Log the failure
2. Fall back to single-agent execution
3. Notify user of degraded mode
4. Continue with reduced multi-perspective coverage

```yaml
fallbacks:
  on_orchestration_failure:
    action: "fallback_to_single_agent"
    log: true
    notify_user: true
```
