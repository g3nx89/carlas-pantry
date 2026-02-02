---
name: deep-reasoning-escalation
description: This skill should be used when the user asks "should I use GPT-5 Pro?", "Claude keeps failing", "need deep reasoning help", "generate escalation prompt", "when to escalate to GPT-5", or when considering whether to recommend escalation to external deep reasoning models (GPT-5 Pro, Google Deep Think, or similar). Also applies when Claude has failed 2+ times on verifiable reasoning tasks like math proofs, security audits, or abstract reasoning problems. Provides decision framework, anti-patterns, and prompt templates for cost-effective escalation.
version: 0.1.0
---

# Deep Reasoning Escalation

> **Compatibility**: Primary reference is GPT-5.2 Pro (December 2025). Principles apply to other deep reasoning models (Google Deep Think, future releases).

## Overview

External deep reasoning models offer decisive advantages in abstract reasoning, mathematical proofs, and security vulnerability detection—but significant limitations in creative tasks, real-time applications, and reliability make them unsuitable for most routine work. This skill provides the decision framework for **when** to recommend escalation and **how** to craft effective prompts for manual submission.

**Core principle:** High selectivity. Recommend escalation only for verifiable reasoning tasks where extended thinking time provides measurable advantage.

**Workflow constraint:** Deep reasoning models cannot be called directly by the agent. The user must copy the prompt to the model's web interface (ChatGPT Pro, Google AI Studio, etc.) and return the result.

## Supported Models

| Model | Interface | Best For | Latency |
|-------|-----------|----------|---------|
| GPT-5 Pro / GPT-5.2 Pro | chat.openai.com (Pro subscription) | Math proofs, security audits, abstract reasoning | 3-15 min |
| Google Deep Think | AI Studio / Gemini Advanced | Scientific reasoning, multimodal analysis | 2-10 min |
| Future models | Varies | Apply same decision framework | Varies |

> **Note:** Benchmark data in this skill primarily references GPT-5 Pro. Adjust expectations for other models based on their documented capabilities.

## When NOT to Use This Skill

Stay with Claude (do not escalate) for:
- **Creative tasks**: Brainstorming, writing, documentation requiring warmth
- **Agentic workflows**: Multi-step tool use, file operations, sustained coding sessions
- **Real-time needs**: Anything requiring sub-minute response times
- **CLI/terminal operations**: Claude significantly outperforms deep reasoning models on terminal tasks
- **Standard debugging**: Most bugs don't require deep reasoning escalation
- **Translation tasks**: Deep reasoning mode interferes with translation quality

This skill is designed for **selective, high-value escalation**—not routine second opinions.

## When to Recommend Escalation

### High-Confidence Triggers (Recommend)

| Trigger | Evidence | Action |
|---------|----------|--------|
| Mathematical proof construction | 100% AIME 2025 vs ~92.8% Claude; 11% Lean 4 proofs | Recommend after Claude fails twice |
| Abstract reasoning with novel patterns | 54.2% ARC-AGI-2 vs 37.6% Claude (44% advantage) | Recommend when no established algorithm exists |
| Security vulnerability deep analysis | 87% CVE-Bench; discovered real CVEs | Recommend for CVE-level audit |
| Claude fails 2+ times on same task | Deep reasoning models break through where Claude loops | Escalate to avoid circular attempts |
| Very large context (>100K tokens) | GPT-5 Pro: 400K context, near-perfect at 256K | Escalate when Claude's context insufficient |
| High-stakes verification | ~6x fewer hallucinations than o3 | Escalate for security/finance critical review |

### Moderate-Confidence Triggers (Suggest as Option)

- Scientific domain expertise requiring PhD-level knowledge
- Second-opinion requests on high-stakes architectural decisions
- User explicitly requests validation of Claude's analysis
- Complex dependency planning (multi-month roadmaps, interrelated components)
- User expresses dissatisfaction: "need more insight", "doesn't fully answer"

### Anti-Patterns (NEVER Recommend)

| Category | Reason |
|----------|--------|
| Creative writing/brainstorming | Deep reasoning models tend toward flat, sterile responses |
| Real-time/urgent tasks | 3-15 minute latency; counterproductive for deadlines |
| Long-running agentic tasks | Claude achieves 80.9% SWE-bench; 30+ hours sustained operation |
| Terminal/CLI operations | Claude significantly outperforms on Terminal-Bench 2.0 |
| Translation tasks | Reasoning mode interferes; echoes source text |
| Multi-file refactoring | Claude maintains superior context management |
| Customer-facing documentation | Claude provides collaborative warmth |
| Chess/spatial reasoning | Known failure mode for deep reasoning models |
| Simple Q&A/basic debugging | Overkill; may overcomplicate or confuse |
| Vague/unformed queries | May produce irrelevant detail; clarify first |
| Claude already answered well | Use for insufficiency, not routine second-step |
| Quick iterations needed | Claude: 10 attempts in time of 1 deep reasoning response |

## Decision Flowchart

```
Is this a VERIFIABLE reasoning task?
├─ NO → Stay with Claude
└─ YES → Does Claude have clear advantages? (agentic, creative, CLI)
         ├─ YES → Stay with Claude
         └─ NO → Has Claude failed 2+ times?
                 ├─ NO → Try Claude once more
                 └─ YES → Is it math proof, abstract reasoning, or security audit?
                          ├─ YES → RECOMMEND escalation
                          └─ NO → SUGGEST as option
```

## Prompt Generation

### The CTCO Pattern (Optimal for Deep Reasoning Models)

```xml
<CONTEXT>
[Background state, project details, relevant code]
</CONTEXT>

<TASK>
[Single, atomic action required]
</TASK>

<CONSTRAINTS>
[What NOT to do; scope limits]
</CONSTRAINTS>

<OUTPUT>
[Specific output format requirements]
</OUTPUT>
```

### Forcing Deep Reasoning

**Key insight:** Modern deep reasoning models auto-detect complexity. Explicit "think step by step" has little effect.

**What works:** Force depth through task structure, not explicit requests:
- Pose problem in parts: "First analyze X, then derive Y, finally conclude Z"
- Require intermediate derivations or comparisons
- Ask for specific analytical output format (decision tree, pros/cons table)
- Specify clear scope and criteria to prevent superficial answers

**Optional phrases** (for maximum reasoning):
- "Think hard about this" - may trigger extended mode
- "Provide the answer, then verify each step is correct" - self-review

For maximum quality, add:

```xml
<self_reflection>
First, create an internal rubric for what defines a 'world-class' answer.
Use 5-7 evaluation categories. Iterate internally until your response
hits top marks across all categories. Show only the final output.
</self_reflection>
```

### Persona Prompting

Deep reasoning models follow personas/custom instructions reliably. Use role prompts to set tone and focus:
- "You are a senior security auditor..." → security-centric analysis
- "Act as a meticulous proof assistant..." → formal rigor
- "You are an impartial code reviewer..." → balanced critique

### Context Length Guidelines

> See `references/prompt-templates.md` for detailed context length recommendations by task type.

**Quick reference:** Mathematical proofs need minimal context (2-8K tokens), security audits need comprehensive context (32-64K tokens). Most deep reasoning models support large contexts (100K-400K) but diminishing returns occur well before those limits.

### Prompt Contradiction Warning

Deep reasoning models follow instructions with precision but fail on contradictions. Ensure prompts contain no conflicting requirements.

**Bad:** "Never schedule without consent" + "auto-assign earliest slot without contacting patient"
**Good:** "Auto-assign earliest slot after informing patient of your actions"

## Additional Resources

### Reference Files

- **`references/prompt-templates.md`** - 10 ready-to-use templates with CTCO pattern, context handoff format, reasoning activation phrases, and context length recommendations by task type

### Example Files

- **`examples/escalation-workflow-example.md`** - Complete end-to-end escalation demonstration for mathematical proof (shows all 8 phases of the workflow)

> **Progressive loading:** Load references only when generating prompts for user submission.

### Templates Available

Templates in `references/prompt-templates.md`:
- Mathematical proof requests
- Security vulnerability analysis
- Abstract reasoning problems
- Second-opinion architectural reviews
- Formal verification (Lean 4 / Coq)
- Scientific domain expertise
- Complex debugging
- Architecture/system design review
- Technical trade-off analysis
- Development plan review

## Escalation Workflow

1. **Recognize trigger** - Identify high-confidence or moderate-confidence scenario
2. **Verify anti-patterns** - Ensure task is not in "never recommend" list
3. **Prepare context** - Use context handoff template from references
4. **Generate prompt** - Apply CTCO pattern with appropriate template
5. **Instruct user** - Explain manual submission process and expected wait time (3-15 minutes)
6. **Process response** - Integrate deep reasoning model output into current workflow

## Integration Patterns

### The "Consultant" Pattern

Deep reasoning models are not chat models—they're asynchronous "consultants." Treat escalation as **job submission**, not conversation.

1. User works in Claude Code (fast, interactive)
2. Trigger detected (e.g., debugging loop, architectural wall)
3. Claude drafts handoff package, asks user to confirm
4. User submits to deep reasoning model's web interface
5. User continues other work while model "thinks" (3-15 min)
6. Model returns detailed analysis/plan
7. Claude helps implement the recommendation

### The "Maker-Checker" Pattern

For security-critical work:
1. **Maker (Deep reasoning model)**: Solve hard problem, optimize architecture, generate novel solution
2. **Checker (Claude)**: Security audit, compliance review, verify code compiles

Deep reasoning models' aggressive refactoring can introduce security regressions. Always verify.

### One-Shot Planning

Instead of 50 agentic iterations, send entire context to the deep reasoning model once:
- Ask for detailed 20-step execution plan
- Have Claude (or cheaper model) execute the plan step-by-step
- Keeps iterative loop cheap while accessing "deep brain" once

## Known Limitations

| Issue | Impact | Mitigation |
|-------|--------|------------|
| High latency | Multi-minute waits (3-15 min typical) | Use web interface, not API; set user expectations |
| Hallucination risk | Fake progress, invented APIs | Verify concrete claims |
| Creative regression | Flat, sterile responses | Never use for creative tasks |
| Spatial reasoning failures | Board games, visual puzzles | Avoid spatial reasoning problems |
| Knowledge cutoffs | Outdated info on recent tech | Check for recent changes |

## Cost Considerations

| Model | Subscription | API Cost |
|-------|--------------|----------|
| GPT-5 Pro | $200/month (ChatGPT Pro) | $21/1M input, $168/1M output |
| Google Deep Think | Gemini Advanced subscription | Varies |

- **Time cost:** Several minutes per complex request
- Recommend only when value justifies cost and delay

## Common Mistakes

| Mistake | Consequence | Prevention |
|---------|-------------|------------|
| Escalating creative tasks | Worse results than Claude | Check anti-pattern list first |
| Vague prompts | Wasted reasoning tokens | Use CTCO structure |
| Missing context handoff | Model lacks crucial info | Use context transfer template |
| Expecting fast responses | Frustration, timeout perception | Set user expectations: minutes, not seconds |
| Over-escalating | Unnecessary cost and delay | Reserve for genuine high-value scenarios |
