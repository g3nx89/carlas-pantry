# PAL ThinkDeep Perspective Prompts

Detailed prompts for each ThinkDeep perspective used in Phase 5.

## Problem Context Template

```
IMPORTANT: This is ARCHITECTURE PLANNING, not code review.
We are designing the implementation approach for a feature.
Please analyze from an architecture perspective.

FEATURE SUMMARY:
{feature_summary}

CODEBASE CONTEXT:
{codebase_patterns}
```

---

## PERFORMANCE Perspective

### Focus Areas
- Scalability
- Latency
- Resource efficiency
- Bottlenecks

### Prompt Template

```
Analyze this architecture plan from a PERFORMANCE perspective.

MY CURRENT ANALYSIS:
{current_analysis}

EXTEND MY ANALYSIS - Focus on:
1. Scalability bottlenecks and horizontal/vertical scaling implications
2. Latency-sensitive paths and potential optimizations
3. Resource efficiency (memory, CPU, I/O patterns)
4. Caching strategies and data locality
5. Async patterns and parallelization opportunities

What performance risks do you see? What optimizations would you recommend?
```

### Expected Output Structure

```markdown
## Performance Analysis

### Scalability Assessment
- Horizontal scaling: [analysis]
- Vertical scaling: [analysis]
- Bottlenecks identified: [list]

### Latency Analysis
- Critical paths: [list]
- Optimization opportunities: [list]

### Resource Efficiency
- Memory patterns: [analysis]
- CPU considerations: [analysis]
- I/O patterns: [analysis]

### Recommendations
1. [Specific recommendation]
2. [Specific recommendation]

### Risks
- [Risk with severity and mitigation]
```

---

## MAINTAINABILITY Perspective

### Focus Areas
- Code quality
- Extensibility
- Technical debt
- Modularity

### Prompt Template

```
Analyze this architecture plan from a MAINTAINABILITY perspective.

MY CURRENT ANALYSIS:
{current_analysis}

EXTEND MY ANALYSIS - Focus on:
1. Coupling and cohesion of proposed components
2. Extensibility for future requirements
3. Technical debt introduced vs. avoided
4. Testing strategy and testability
5. Code patterns that aid or hinder maintainability

What maintainability concerns do you see? How would you improve the design?
```

### Expected Output Structure

```markdown
## Maintainability Analysis

### Coupling & Cohesion
- Component relationships: [analysis]
- Areas of concern: [list]

### Extensibility
- Future requirement handling: [analysis]
- Extension points: [list]

### Technical Debt
- Debt introduced: [list]
- Debt avoided: [list]
- Net assessment: [summary]

### Testability
- Unit testing: [analysis]
- Integration testing: [analysis]
- Mocking requirements: [list]

### Recommendations
1. [Specific recommendation]
2. [Specific recommendation]

### Concerns
- [Concern with impact assessment]
```

---

## SECURITY Perspective

### Focus Areas
- Threat modeling
- Compliance
- Vulnerabilities
- Data protection

### Prompt Template

```
Analyze this architecture plan from a SECURITY perspective.

MY CURRENT ANALYSIS:
{current_analysis}

EXTEND MY ANALYSIS - Focus on:
1. Threat modeling (STRIDE categories)
2. Authentication and authorization patterns
3. Data protection (at rest, in transit)
4. Input validation and injection prevention
5. Compliance considerations (GDPR, SOC2, etc.)

What security vulnerabilities do you see? What mitigations would you recommend?
```

### Expected Output Structure

```markdown
## Security Analysis

### Threat Model (STRIDE)
- Spoofing: [assessment]
- Tampering: [assessment]
- Repudiation: [assessment]
- Information Disclosure: [assessment]
- Denial of Service: [assessment]
- Elevation of Privilege: [assessment]

### Authentication & Authorization
- Auth mechanisms: [analysis]
- Authorization patterns: [analysis]
- Gaps identified: [list]

### Data Protection
- At rest: [analysis]
- In transit: [analysis]
- PII handling: [analysis]

### Input Validation
- Entry points: [list]
- Validation approach: [analysis]
- Injection vectors: [list]

### Compliance
- GDPR considerations: [list]
- SOC2 considerations: [list]
- Other: [list]

### Vulnerabilities
1. [Vulnerability] - Severity: [High/Medium/Low] - Mitigation: [action]

### Recommendations
1. [Specific recommendation]
2. [Specific recommendation]
```

---

## ThinkDeep Call Template

```javascript
mcp__pal__thinkdeep({
  step: "{PERSPECTIVE_PROMPT_WITH_FILLED_VALUES}",
  step_number: 1,
  total_steps: 1,
  next_step_required: false,
  model: "{MODEL}",  // gpt-5.2, gemini-3-pro-preview, or x-ai/grok-4
  thinking_mode: "high",
  focus_areas: "{PERSPECTIVE_FOCUS_AREAS}",
  findings: "{INITIAL_FINDINGS_FROM_ARCHITECTURE}",
  problem_context: "{PROBLEM_CONTEXT_TEMPLATE}",
  relevant_files: ["{ABSOLUTE_PATH_TO_DESIGN_FILE}"]
})
```

---

## Synthesis Output Template

```markdown
# ThinkDeep Architecture Analysis

> Generated: {TIMESTAMP}
> Analysis Mode: {analysis_mode}
> Total Calls: {completed}/{expected}

## PERFORMANCE PERSPECTIVE

### gpt-5.2 Analysis
{findings}

### gemini-3-pro-preview Analysis
{findings}

### grok-4 Analysis
{findings}

**Convergent Insights (All Models Agree):**
- {insight 1} → CRITICAL priority
- {insight 2} → CRITICAL priority

**Divergent Insights (Models Disagree):**
- {topic}: gpt says X, gemini says Y → FLAG for decision

## MAINTAINABILITY PERSPECTIVE
{same structure - Complete mode only}

## SECURITY PERSPECTIVE
{same structure}

## CROSS-PERSPECTIVE SYNTHESIS

### High-Priority Findings (Convergent)
| Finding | Perspectives | Models | Priority | Action |
|---------|--------------|--------|----------|--------|
| {finding} | PERF, SEC | All 3 | CRITICAL | {recommended action} |

### Decision Points (Divergent)
| Topic | Perspectives | Issue | Options |
|-------|--------------|-------|---------|
| {topic} | {list} | {models disagree} | A: {opt}, B: {opt} |

### Recommended Architecture Updates
1. {specific change based on findings}
2. {specific change}
```

---

## Mode Matrix

| Mode | Perspectives | Models/Perspective | Total Calls |
|------|--------------|-------------------|-------------|
| Complete | PERFORMANCE, MAINTAINABILITY, SECURITY | 3 | 9 |
| Advanced | PERFORMANCE, SECURITY | 3 | 6 |
| Standard | N/A (skipped) | 0 | 0 |
| Rapid | N/A (skipped) | 0 | 0 |

---

## Error Handling

If a model call fails:
1. Log failure to state: `thinkdeep.failures.append({model, perspective})`
2. Display warning: "PAL model {model} failed for {perspective}"
3. Continue with remaining models (do NOT substitute)
4. Mark synthesis as partial if >1 model failed for same perspective
