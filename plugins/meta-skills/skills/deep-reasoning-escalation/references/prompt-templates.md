# Deep Reasoning Model Prompt Templates

Reference templates for manual submission to deep reasoning models (GPT-5 Pro, Google Deep Think, etc.). Load this file when generating prompts for user escalation.

## Context Handoff Format

Use this structure when transferring context from Claude to a deep reasoning model:

```xml
<prior_context>
## Project Background
- [1-2 sentence project description]
- Tech stack: [languages, frameworks, dependencies]

## Decisions Made
1. [Decision]: [Rationale]
2. [Decision]: [Rationale]

## Current State
- Files modified: [list]
- Last action taken: [description]
- Known issues: [list]

## Claude's Attempts
- Attempt 1: [what Claude tried] → [result]
- Attempt 2: [what Claude tried] → [result]
</prior_context>

<current_request>
[Specific question for the deep reasoning model]
</current_request>
```

---

## Template 1: Mathematical Proof Request

For: Formal proofs in Lean, Coq, or competition mathematics (IMO, Putnam level)

```xml
<task>
Construct a formal proof for the following mathematical statement.
Think hard about this—take your time to verify each step.
</task>

<problem>
[Statement to prove]
</problem>

<context>
Claude's previous attempt: [summary of Claude's approach]
Issue with Claude's approach: [where it failed]
</context>

<output_format>
1. Proof strategy overview (2-3 sentences)
2. Formal proof with numbered steps
3. Verification that each step follows logically
4. Alternative approaches considered
</output_format>
```

---

## Template 2: Security Vulnerability Deep Analysis

For: CVE-level vulnerability detection, penetration testing context

```xml
<security_audit>
<code>
[Paste code to analyze]
</code>

<threat_model>
- User roles: [list]
- Trust boundaries: [where untrusted input enters]
- Sensitive data: [what needs protection]
</threat_model>

<scope>
Focus on: OWASP Top 10, authentication bypasses, injection vulnerabilities
</scope>

<output_format>
For each vulnerability:
- CWE ID (if applicable)
- Severity: Critical/High/Medium/Low
- Affected location: [file:line]
- Proof of concept: [how to exploit]
- Remediation: [specific fix with code]
</output_format>
</security_audit>
```

---

## Template 3: Abstract Reasoning Problem

For: Novel algorithm design, state machine design, game theory, pattern recognition in unfamiliar domains

```xml
<reasoning_task>
<problem>
[Clear problem statement]
</problem>

<constraints>
[Any constraints or rules]
</constraints>

<self_reflection>
Create an internal rubric for solving this type of problem.
Verify your reasoning at each step before proceeding.
Show only the final, verified solution.
</self_reflection>

<output_format>
1. Problem analysis (what makes this challenging)
2. Solution approach with rationale
3. Step-by-step solution with verification
4. Confidence level and potential edge cases
</output_format>
</reasoning_task>
```

---

## Template 4: Second-Opinion Architectural Review

For: Validating Claude's analysis on high-stakes decisions

```xml
<review_request>
<context>
I've received analysis from another AI system and need a fresh perspective.
</context>

<system_design>
[Paste architecture description or diagram]
</system_design>

<previous_analysis>
[Summary of Claude's recommendations]
</previous_analysis>

<review_focus>
1. Do you agree with this analysis? Why or why not?
2. What issues might the previous review have missed?
3. What alternative approaches should be considered?
</review_focus>

<output_format>
- Agreement/disagreement with rationale
- Additional issues found (if any)
- Alternative recommendations
- Confidence level for each finding
</output_format>
</review_request>
```

---

## Template 5: Formal Verification (Lean 4 / Coq)

For: Proof assistant tasks where Claude's compilation or semantic accuracy is insufficient

```xml
<formal_verification>
<task>
Write a formally verified proof in [Lean 4 / Coq] for the following theorem.
Think deeply about this. Ensure the proof compiles and is semantically correct.
</task>

<theorem>
[Theorem statement in natural language]
</theorem>

<existing_definitions>
[Any relevant type definitions, lemmas, or imports]
</existing_definitions>

<claude_attempt>
[Claude's attempted proof code]
Compilation result: [error message or "compiles but incorrect"]
Issue: [what went wrong]
</claude_attempt>

<output_format>
1. Complete proof code that compiles
2. Explanation of proof strategy
3. Key lemmas used
4. Verification steps
</output_format>
</formal_verification>
```

---

## Template 6: Scientific Domain Expertise

For: PhD-level questions in physics, chemistry, biology

```xml
<domain_expertise>
<question>
[Specific scientific question]
</question>

<context>
- Field: [physics/chemistry/biology/etc.]
- Level: Graduate/PhD
- Application: [how this knowledge will be used]
</context>

<claude_response>
[What Claude said, if hedging or uncertain]
</claude_response>

<self_reflection>
Provide an authoritative answer drawing on deep domain expertise.
Include nuances that a domain expert would consider important.
Cite relevant theoretical frameworks or empirical findings.
</self_reflection>

<output_format>
1. Direct answer
2. Theoretical foundation
3. Important caveats or edge cases
4. Recommended further reading (if applicable)
</output_format>
</domain_expertise>
```

---

## Reasoning Activation Phrases

Append these to any template to trigger extended reasoning:

| Phrase | Effect |
|--------|--------|
| "Think hard about this" | Triggers extended reasoning mode |
| "Think deeply" | Alternative trigger |
| "Take your time to verify each step" | Encourages thorough verification |

For maximum quality on complex tasks, include the self-reflection block:

```xml
<self_reflection>
First, create an internal rubric for what defines a 'world-class' answer.
Use 5-7 evaluation categories. Iterate internally until your response
hits top marks across all categories. Show only the final output.
</self_reflection>
```

---

## Context Length Quick Reference

| Task Type | Optimal Context | Max Useful |
|-----------|----------------|------------|
| Mathematical proof | 2-8K tokens | 16K |
| Security audit | 32-64K tokens | 128K |
| Architecture review | 16-32K tokens | 64K |
| Abstract reasoning | 4-16K tokens | 32K |
| Complex debugging | 8-16K tokens | 32K |
| Scientific questions | 4-8K tokens | 16K |

**Note:** Most deep reasoning models support large contexts (100K-400K tokens) but diminishing returns occur well before those limits. Focus on clean, relevant context over volume.

---

## Developer-Specific Templates

### Template 7: Complex Debugging

For: Subtle bugs, memory leaks, race conditions, edge cases Claude missed

```
**Context:** We are encountering [brief description of bug] in [system/software context].

**Code/Logs:**
```[language]
[code or log snippet]
```

**What's been tried:** [explain steps already taken and results].

**Task:** Identify the root cause of the bug and suggest a fix. Provide your reasoning step-by-step, considering the provided code and any relevant scenarios.
```

**Key:** Include description of unexpected behavior, relevant code, reproduction steps, and any hypothesis. Highlight error messages in bold or quote blocks.

---

### Template 8: Architecture/System Design Review

For: Comprehensive critique of system designs, identifying blind spots

```
**System Overview:** [summary of system architecture].

**Requirements/Goals:** [list of key requirements, e.g. scalability, security, etc.].

**Known Implementations:** [technologies/choices made].

**Task:** As an expert architect, critically review the above design.
1. Identify any potential weaknesses or bottlenecks (with respect to requirements).
2. Highlight any missing considerations or components.
3. Provide suggestions to improve the design or mitigate identified risks.
```

**Key:** Enumerate review criteria explicitly. Deep reasoning models will structure answers by those points.

---

### Template 9: Technical Trade-off Analysis

For: Comparing options (SQL vs NoSQL, library X vs Y, approach A vs B)

```
**Decision Point:** Choosing between [Option A] and [Option B] for [context/use-case].

**Option A:** [brief description and any known pros/cons].
**Option B:** [brief description].

**Criteria:** [list of what matters, e.g. performance, ease of use, cost, scalability].

**Task:** Compare Option A and Option B against the criteria. Provide a pros/cons list for each option and then give a recommendation on which option is more suitable and why.
```

**Key:** Deep reasoning models will produce structured comparison (table/bullets) then conclusion.

---

### Template 10: Development Plan Review

For: Finding missing requirements, risks, edge cases in project plans

```
**Project Plan Summary:** [short summary of the plan's goal and scope].

**Plan Details:** [key points like timeline, team, features – can be in bullet form].

**Task:** Review this development plan.
- Are there any requirements or use-cases missing from the plan?
- Are there any risks or assumptions that need attention?
- Suggest any additional test cases or edge conditions we should include.

Provide the answer in respective sections (Missing items, Risks, Edge cases).
```

**Key:** Deep reasoning models will methodically enumerate gaps by category.

---

## Context Handoff Best Practices

### Summarizing Prior Conversation

When handing off from Claude, provide a concise summary answering:
- What are we trying to do?
- What has been done?
- What were the results?

**Example:**
> "We are debugging a memory leak in module X. So far: Claude identified a possible cause in function Y and suggested a fix, which we tried. Result: the leak reduced but not fully. We also ruled out Z as a cause."

**Tips:**
- Convert dialogue to narrative: "We considered X but then tried Y" instead of raw turns
- Omit tangents and failed brainstorming that led nowhere
- Explicitly mark what's been decided: "We will focus on approach B"
- Include user constraints: "we cannot upgrade library Q"

### Formatting for Deep Reasoning Models

Deep reasoning models mirror prompt formatting in responses:
- Use markdown code blocks with language tags: ```python
- Use bullet points/numbered lists for enumeration
- Use markdown headings/separators to organize
- If expecting specific output format (table, JSON), show example or ask explicitly

**Note:** Most deep reasoning models cannot generate images. For diagrams, ask for text descriptions or ASCII art.

### Framing Second-Opinion Requests

Frame as fresh review, not validation:

**Bad:** "Claude suggested X, is it right?"
**Good:** "Here is the problem and the solution we attempted. Please evaluate this solution and point out any issues or improvements."

Explicitly instruct: "If you find any mistakes or missed points in the above solution, explain them."

To focus on significant issues: "Review the above for any **major** errors or omissions."

Use neutral framing: "You are an impartial code reviewer" instead of "Claude's answer is probably wrong"

### Recommended Context by Developer Task

| Task | Optimal Context | What to Include |
|------|-----------------|-----------------|
| Debugging specific bug | 8-16K | Relevant code, error, reproduction steps |
| Security audit | 32-64K | All auth/input validation code, threat model |
| Architecture review | 16-32K | Design doc, requirements, diagrams (text) |
| Trade-off analysis | 4-8K | Options, criteria, constraints |
| Plan review | 10-20K | Full plan, timeline, features |

**Rule:** Use enough context to cover the problem, but not so much that core issue is buried. Summarize repetitive sections before sending.
