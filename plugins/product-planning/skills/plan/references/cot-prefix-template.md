# Chain-of-Thought Prefix Template (S2)

Standard Zero-Shot Chain-of-Thought reasoning section for all agents. Based on Kojima et al. (2022).

## Template for Agent Prompts

Copy this section into agent prompts after "Core Mission" and before detailed process/approach sections:

```markdown
## Reasoning Approach

Before taking any action, think through the problem systematically using these explicit reasoning steps:

### Step 1: Understand the Request
"Let me first understand what is being asked..."
- What is the core objective?
- What are the explicit requirements?
- What constraints apply?
- What does success look like?

### Step 2: Break Down the Problem
"Let me break this down into concrete steps..."
- What are the major components or phases?
- What order should I tackle them?
- What dependencies exist between steps?
- Which parts are independent (can be done in parallel)?

### Step 3: Anticipate Issues
"Let me consider what could go wrong..."
- What assumptions am I making?
- What edge cases might exist?
- What could fail or produce unexpected results?
- What information might be missing?

### Step 4: Verify Before Acting
"Let me verify my approach before proceeding..."
- Does my plan address all requirements?
- Is there a simpler approach I'm missing?
- Am I over-engineering the solution?
- Have I considered the constraints?

**Use these phrases explicitly in your reasoning to activate systematic thinking.**
```

## Integration Notes

1. **Placement**: After "Core Mission", before detailed methodology sections
2. **Token Impact**: ~5% increase per agent
3. **Verification**: Check agent outputs include reasoning phrases ("Let me...")

## Verification Markers

Agent outputs should demonstrate explicit reasoning. Check for:

```bash
# Minimum 2 occurrences of "Let me" reasoning phrases
grep -c "Let me" agent_output.md  # Should be >= 2

# At least 3 of 4 reasoning sections present
grep -E "(understand|break.*(down|this)|consider|verify)" agent_output.md
```

## Agent-Specific Variations

### Research-Heavy Agents (code-explorer, researcher)

Add this additional step after Step 4:

```markdown
### Step 5: Plan Information Gathering
"Let me plan what information I need to gather..."
- What sources should I consult first?
- How will I verify information accuracy?
- What's my fallback if primary sources are unavailable?
```

### Design-Heavy Agents (software-architect, tech-lead)

Add this additional step after Step 4:

```markdown
### Step 5: Consider Alternatives
"Let me consider alternative approaches..."
- What are at least 2 different ways to solve this?
- What are the trade-offs between approaches?
- Which approach best fits the constraints?
```

### Evaluation Agents (qa-strategist, judges)

Add this additional step after Step 4:

```markdown
### Step 5: Define Evaluation Criteria
"Let me define how I will evaluate this..."
- What specific criteria will I use?
- How will I weight different factors?
- What evidence will support each assessment?
```

## Example Integration

Before:
```markdown
# Expert Code Explorer Agent

You are an expert code analyst...

## Core Mission

Provide a complete understanding of how a specific feature works...

## Analysis Approach (ReAct Pattern)

### 1. Feature Discovery
...
```

After:
```markdown
# Expert Code Explorer Agent

You are an expert code analyst...

## Core Mission

Provide a complete understanding of how a specific feature works...

## Reasoning Approach

Before taking any action, think through the problem systematically:

### Step 1: Understand the Request
"Let me first understand what is being asked..."
[... full template ...]

## Analysis Approach (ReAct Pattern)

### 1. Feature Discovery
...
```

## Research Background

Zero-Shot Chain-of-Thought prompting (Kojima et al., 2022) improves reasoning by 20-60% on complex tasks by:

1. **Activating latent reasoning capabilities** through explicit prompts
2. **Reducing skip-step errors** by requiring step-by-step thinking
3. **Improving plan coherence** through structured decomposition
4. **Catching errors earlier** through pre-action verification

The key phrases ("Let me think step by step...", "Let me break this down...") serve as reasoning triggers that activate more thorough processing.
