# Debate Protocol

## Purpose

Orchestrate adversarial debate between judges with different stances to reach robust recommendations for scope-critical questions. This protocol prevents sycophancy through assigned stances and structured disagreement.

## When to Use

Use debate protocol when:
- Question is classified as SCOPE_CRITICAL
- Answer significantly impacts what gets built
- Multiple valid perspectives exist
- Single-agent recommendation would be biased

## Debate Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     DEBATE PROTOCOL                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ROUND 1: Independent Recommendations (parallel)             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Risk Judge   │  │ Value Judge  │  │ Effort Judge │       │
│  │ (skeptical)  │  │ (optimistic) │  │ (pragmatic)  │       │
│  │              │  │              │  │              │       │
│  │ → Option A   │  │ → Option B   │  │ → Option A   │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│         │                 │                 │                │
│         └─────────────────┼─────────────────┘                │
│                           ▼                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              CONSENSUS CHECK                         │   │
│  │  2/3 agree on A? → CONSENSUS (skip round 2)          │   │
│  │  All different? → PROCEED TO ROUND 2                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                  │
│                    No consensus                              │
│                           ▼                                  │
│  ROUND 2: Adversarial Response                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Risk reads   │  │ Value reads  │  │ Effort reads │       │
│  │ other files  │  │ other files  │  │ other files  │       │
│  │              │  │              │  │              │       │
│  │ Challenges   │  │ Challenges   │  │ Challenges   │       │
│  │ Value & Effort│ │ Risk & Effort│  │ Risk & Value │       │
│  │              │  │              │  │              │       │
│  │ May revise   │  │ May revise   │  │ May revise   │       │
│  │ (document)   │  │ (document)   │  │ (document)   │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│         │                 │                 │                │
│         └─────────────────┼─────────────────┘                │
│                           ▼                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              FINAL CONSENSUS CHECK                   │   │
│  │  Consensus? → RECOMMENDED with perspectives          │   │
│  │  No consensus? → CONTESTED (user decides)            │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Protocol Steps

### Step 1: Prepare Debate Context

```yaml
debate_context:
  question_id: "{id}"
  question_text: "{full question}"
  options:
    - id: "A"
      label: "{option A name}"
      description: "{option A details}"
    - id: "B"
      label: "{option B name}"
      description: "{option B details}"
    - id: "C"
      label: "{option C name}"
      description: "{option C details}"

  spec_context: |
    {relevant excerpt from specification}

  feature_name: "{name}"
  feature_dir: "{dir}"
```

### Step 2: Round 1 - Independent Recommendations

Launch all three judges in parallel:

```typescript
// All judges run independently without seeing each other's output
Task(
  description: "Risk Judge evaluation",
  prompt: `
    You are the Risk Judge with SKEPTICAL stance.

    Question: {question_text}
    Options: {options}
    Context: {spec_context}

    Evaluate each option for risks.
    Recommend the option that MINIMIZES RISK.
    Write to: {feature_dir}/sadd/debate-{question_id}-risk.md
  `,
  subagent_type: "general-purpose",
  model: "sonnet"
)

Task(
  description: "Value Judge evaluation",
  prompt: `
    You are the Value Judge with OPTIMISTIC stance.

    Question: {question_text}
    Options: {options}
    Context: {spec_context}

    Evaluate each option for user value.
    Recommend the option that MAXIMIZES VALUE.
    Write to: {feature_dir}/sadd/debate-{question_id}-value.md
  `,
  subagent_type: "general-purpose",
  model: "sonnet"
)

Task(
  description: "Effort Judge evaluation",
  prompt: `
    You are the Effort Judge with PRAGMATIC stance.

    Question: {question_text}
    Options: {options}
    Context: {spec_context}

    Evaluate each option for ROI.
    Recommend the option that OPTIMIZES ROI.
    Write to: {feature_dir}/sadd/debate-{question_id}-effort.md
  `,
  subagent_type: "general-purpose",
  model: "sonnet"
)
```

### Step 3: Check Round 1 Consensus

After Round 1 completes:

```typescript
// Read all judge outputs
const riskOutput = Read(file_path: `${featureDir}/sadd/debate-${questionId}-risk.md`);
const valueOutput = Read(file_path: `${featureDir}/sadd/debate-${questionId}-value.md`);
const effortOutput = Read(file_path: `${featureDir}/sadd/debate-${questionId}-effort.md`);

// Extract recommendations
const recommendations = [
  { judge: "risk", option: extractOption(riskOutput) },
  { judge: "value", option: extractOption(valueOutput) },
  { judge: "effort", option: extractOption(effortOutput) }
];

// Check consensus
const consensus = checkConsensus(recommendations, threshold: 0.67);
```

### Step 4: Round 2 (If Needed)

If no consensus in Round 1:

```typescript
// Each judge reads others' files and responds
Task(
  description: "Risk Judge round 2",
  prompt: `
    You are the Risk Judge continuing the debate.

    YOUR PREVIOUS RECOMMENDATION:
    ${riskOutput}

    OTHER JUDGES' POSITIONS:
    Value Judge: ${valueOutput}
    Effort Judge: ${effortOutput}

    Instructions:
    1. Read and understand other judges' reasoning
    2. Challenge their positions with specific counter-arguments
    3. Defend your position OR revise if genuinely convinced
    4. If you change your recommendation, document EXACTLY what convinced you

    Write to: {feature_dir}/sadd/debate-{question_id}-risk-r2.md
  `,
  subagent_type: "general-purpose",
  model: "sonnet"
)

// ... similar for value and effort judges
```

### Step 5: Final Consensus Check

```typescript
const finalConsensus = checkConsensus(round2Recommendations, threshold: 0.67);

if (finalConsensus.hasConsensus) {
  return {
    consensus: true,
    recommended_option: finalConsensus.majorityOption,
    confidence: "HIGH",
    perspectives: gatherPerspectives()
  };
} else {
  return {
    consensus: false,
    outcome: "CONTESTED",
    confidence: "REQUIRES_INPUT",
    perspectives: gatherAllPerspectives(),
    message: "Judges disagree. Review perspectives below."
  };
}
```

## Output Formats

### Consensus Result

```yaml
debate_result:
  question_id: "{id}"
  consensus: true
  recommended_option: "A"
  confidence: "HIGH"

  perspectives:
    risk: "Option A - minimizes technical debt risk"
    value: "Option A - delivers core user value (changed from B)"
    effort: "Option A - best ROI given timeline"

  change_log:
    - judge: "value"
      round: 2
      from: "B"
      to: "A"
      reason: "Convinced by effort judge's ROI analysis"
```

### Contested Result

```yaml
debate_result:
  question_id: "{id}"
  consensus: false
  outcome: "CONTESTED"
  confidence: "REQUIRES_INPUT"

  distribution:
    "A": ["risk"]
    "B": ["value"]
    "C": ["effort"]

  perspectives:
    risk_favors: |
      Option A - "Offline sync has high complexity risk.
      Sync bugs only appear after weeks of real usage."

    value_favors: |
      Option B - "Full offline is our competitive advantage.
      Field workers (40% revenue) NEED this."

    effort_favors: |
      Option C - "Limited offline gives 80% value for 20% effort.
      Ship now, expand later based on data."

  user_prompt: |
    ⚠️ Judges disagreed on this question. Review perspectives above.

    Which option would you like to proceed with?
    [A] {option A description}
    [B] {option B description}
    [C] {option C description}
```

## Anti-Sycophancy Mechanisms

### 1. Assigned Stances

Each judge has a hardcoded stance that they MUST maintain:
- Risk: Always challenge optimism
- Value: Always push for more
- Effort: Always ground in reality

### 2. File-Based Isolation

In Round 1, judges cannot see each other's work. They write to separate files.

### 3. Challenge Requirement

In Round 2, judges MUST challenge other positions, not just agree.

### 4. Change Documentation

If a judge changes position, they MUST document what specifically convinced them.

### 5. Contested Acceptance

It's OK to not reach consensus. Contested outcomes are valid and get escalated to user.

## Error Handling

### Judge Timeout

```yaml
on_judge_timeout:
  action: "continue_without"
  log: true
  note_in_result: "Risk judge timed out - only 2 perspectives available"
```

### Parse Failure

```yaml
on_parse_failure:
  action: "request_clarification"
  fallback: "treat_as_no_recommendation"
```

## Configuration

```yaml
debate_config:
  max_rounds: 2
  consensus_threshold: 0.67  # 2/3 agreement
  timeout_per_judge: 120
  require_stance_maintenance: true
  require_change_documentation: true
```
