# Parallel Dispatch Protocol

## Purpose

Execute multiple agents in parallel to gather diverse perspectives efficiently. This protocol ensures agents run concurrently while maintaining proper coordination and error handling.

## When to Use

Use parallel dispatch when:
- Multiple independent analyses are needed
- Agents don't depend on each other's output
- Time savings from parallelization are valuable
- You need diverse perspectives on the same input

## Protocol Steps

### Step 1: Prepare Output Directory

```bash
# Create SADD output structure
mkdir -p {FEATURE_DIR}/sadd/
```

### Step 2: Dispatch Agents

Use the Claude Code Task tool to launch agents in parallel:

```typescript
// Launch all agents in a single message with multiple Task calls
Task(
  description: "End User Advocate analysis",
  prompt: `
    Read the specification at {SPEC_FILE}.
    Analyze from the end user perspective.
    Write findings to {FEATURE_DIR}/sadd/advocate-user.md
  `,
  subagent_type: "general-purpose",
  model: "sonnet"
)

Task(
  description: "Business Advocate analysis",
  prompt: `
    Read the specification at {SPEC_FILE}.
    Analyze from the business perspective.
    Write findings to {FEATURE_DIR}/sadd/advocate-business.md
  `,
  subagent_type: "general-purpose",
  model: "sonnet"
)

// ... additional agents
```

### Step 3: Wait for Completion

The Task tool handles parallel execution. All agents will complete before results are returned.

### Step 4: Collect Results

After all agents complete:

```typescript
// Check which output files exist
Glob(pattern: "{FEATURE_DIR}/sadd/advocate-*.md")

// Read each file to verify completion
Read(file_path: "{FEATURE_DIR}/sadd/advocate-user.md")
Read(file_path: "{FEATURE_DIR}/sadd/advocate-business.md")
// ...
```

### Step 5: Report Status

Generate dispatch report:

```yaml
parallel_dispatch_report:
  total_agents: 4
  completed: 4
  failed: 0

  agents:
    - name: "end-user-advocate"
      status: "completed"
      output: "sadd/advocate-user.md"
      gaps_found: 5

    - name: "business-advocate"
      status: "completed"
      output: "sadd/advocate-business.md"
      gaps_found: 3

    - name: "operations-advocate"
      status: "completed"
      output: "sadd/advocate-ops.md"
      gaps_found: 4

    - name: "security-advocate"
      status: "completed"
      output: "sadd/advocate-security.md"
      gaps_found: 6
```

## Agent Configurations

### Stakeholder Advocates

```yaml
stakeholder_advocates:
  agents:
    - name: "end-user-advocate"
      prompt_file: "$CLAUDE_PLUGIN_ROOT/agents/stakeholder-advocates/end-user-advocate.md"
      model: "sonnet"
      output: "sadd/advocate-user.md"

    - name: "business-advocate"
      prompt_file: "$CLAUDE_PLUGIN_ROOT/agents/stakeholder-advocates/business-advocate.md"
      model: "sonnet"
      output: "sadd/advocate-business.md"

    - name: "operations-advocate"
      prompt_file: "$CLAUDE_PLUGIN_ROOT/agents/stakeholder-advocates/operations-advocate.md"
      model: "sonnet"
      output: "sadd/advocate-ops.md"

    - name: "security-advocate"
      prompt_file: "$CLAUDE_PLUGIN_ROOT/agents/stakeholder-advocates/security-advocate.md"
      model: "sonnet"
      output: "sadd/advocate-security.md"
```

### Question Discovery

```yaml
question_discovery:
  agents:
    - name: "ux-perspective"
      prompt_file: "$CLAUDE_PLUGIN_ROOT/agents/question-discovery/ux-perspective.md"
      model: "sonnet"
      output: "sadd/questions-ux.md"

    - name: "business-perspective"
      prompt_file: "$CLAUDE_PLUGIN_ROOT/agents/question-discovery/business-perspective.md"
      model: "sonnet"
      output: "sadd/questions-business.md"

    - name: "technical-perspective"
      prompt_file: "$CLAUDE_PLUGIN_ROOT/agents/question-discovery/technical-perspective.md"
      model: "sonnet"
      output: "sadd/questions-technical.md"
```

## Error Handling

### Agent Failure

If an agent fails:

```yaml
error_handling:
  on_agent_failure:
    - log_error: true
    - continue_others: true
    - mark_failed: true
    - report_partial: true
```

### Partial Results

When some agents fail:

```yaml
partial_results:
  total_agents: 4
  completed: 3
  failed: 1

  failed_agents:
    - name: "security-advocate"
      error: "Timeout after 120 seconds"

  action: "Proceed with partial results, note missing perspective"
```

## Concurrency Limits

To avoid overwhelming the system:

```yaml
concurrency:
  max_parallel: 4  # Maximum concurrent agents
  stagger_start: false  # Start all at once
  timeout_per_agent: 120  # Seconds
```

## Context Passing

Each agent receives shared context:

```yaml
shared_context:
  SPEC_FILE: "{path to spec.md}"
  FEATURE_NAME: "{feature name}"
  FEATURE_DIR: "{feature directory}"
  PLATFORM_TYPE: "Android"  # For security advocate
```

## Output Validation

After dispatch, validate outputs:

```yaml
validation:
  check_file_exists: true
  check_minimum_size: 100  # bytes
  check_required_sections:
    - "## Summary"
    - "## Gaps Identified"
```

## Integration Example

```typescript
// Full parallel dispatch for stakeholder advocates
async function dispatchStakeholderAdvocates(
  specFile: string,
  featureName: string,
  featureDir: string
) {
  // Step 1: Setup
  await Bash({ command: `mkdir -p ${featureDir}/sadd/` });

  // Step 2: Parallel dispatch (single message, multiple Task calls)
  // In Claude Code, this is done by including multiple Task tool calls
  // in a single assistant message

  // Step 3: Collect results
  const files = await Glob({ pattern: `${featureDir}/sadd/advocate-*.md` });

  // Step 4: Validate and report
  const report = {
    completed: files.length,
    failed: 4 - files.length,
    outputs: files
  };

  return report;
}
```
