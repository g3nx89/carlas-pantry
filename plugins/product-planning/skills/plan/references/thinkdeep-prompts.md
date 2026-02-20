# Deep Analysis Perspective Prompts

Detailed prompts for each deep analysis perspective used in Phase 5 via CLI dispatch.

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

## CLI Dispatch Template

Each perspective is dispatched via `dispatch-cli-agent.sh` using the CLI Multi-CLI Dispatch Pattern from `cli-dispatch-pattern.md`:

```
Follow CLI Multi-CLI Dispatch Pattern with:

| Parameter | Value |
|-----------|-------|
| ROLE | `deepthinker` |
| PHASE_STEP | `5.3.{perspective}` |
| MODE_CHECK | `analysis_mode in {complete, advanced}` |
| GEMINI_PROMPT | "{PROBLEM_CONTEXT_TEMPLATE}\n\n{PERSPECTIVE_PROMPT_WITH_FILLED_VALUES}" |
| CODEX_PROMPT | "{PROBLEM_CONTEXT_TEMPLATE}\n\n{PERSPECTIVE_PROMPT_WITH_FILLED_VALUES}" |
| OPENCODE_PROMPT | "{PROBLEM_CONTEXT_TEMPLATE}\n\n{PERSPECTIVE_PROMPT_WITH_FILLED_VALUES}" |
| FILE_PATHS | ["{FEATURE_DIR}/design.md"] |
| REPORT_FILE | "analysis/cli-deepthinker-{perspective}-report.md" |
| PREFERRED_SINGLE_CLI | `gemini` |
```

---

## Synthesis Output Template

```markdown
# Deep Analysis Architecture Report

> Generated: {TIMESTAMP}
> Analysis Mode: {analysis_mode}
> Total Dispatches: {completed}/{expected}

## PERFORMANCE PERSPECTIVE

### Gemini CLI Analysis (Broad Exploration)
{findings}

### Codex CLI Analysis (Code-Level)
{findings}

### OpenCode CLI Analysis (UX/Product)
{findings}

**Unanimous Insights (All CLIs Agree):**
- {insight 1} → CRITICAL priority (VERY HIGH confidence)
- {insight 2} → CRITICAL priority (VERY HIGH confidence)

**Majority Insights (2 of 3 CLIs Agree):**
- {insight}: {agreeing CLIs} agree, {dissenting CLI} differs → HIGH confidence

**Divergent Insights (All CLIs Disagree):**
- {topic}: Gemini says X, Codex says Y, OpenCode says Z → FLAG for decision

## MAINTAINABILITY PERSPECTIVE
{same structure - Complete mode only}

## SECURITY PERSPECTIVE
{same structure}

## CROSS-PERSPECTIVE SYNTHESIS

### High-Priority Findings (Unanimous)
| Finding | Perspectives | CLIs | Confidence | Action |
|---------|--------------|------|------------|--------|
| {finding} | PERF, SEC | All 3 | VERY HIGH | {recommended action} |

### Majority Findings
| Finding | Perspectives | Agree | Dissent | Confidence | Action |
|---------|--------------|-------|---------|------------|--------|
| {finding} | {list} | {2 CLIs} | {1 CLI} | HIGH | {action} |

### Decision Points (Divergent)
| Topic | Perspectives | Issue | Options |
|-------|--------------|-------|---------|
| {topic} | {list} | {All CLIs disagree} | A: {opt}, B: {opt}, C: {opt} |

### Recommended Architecture Updates
1. {specific change based on findings}
2. {specific change}
```

---

## Mode Matrix

| Mode | Perspectives | CLIs/Perspective | Total Dispatches |
|------|--------------|-----------------|------------------|
| Complete | PERFORMANCE, MAINTAINABILITY, SECURITY | 3 | 9 |
| Advanced | PERFORMANCE, SECURITY | 3 | 6 |
| Standard | N/A (skipped) | 0 | 0 |
| Rapid | N/A (skipped) | 0 | 0 |

---

## Error Handling

If a CLI dispatch fails:
1. Log failure to state: `thinkdeep.failures.append({cli, perspective})`
2. Display warning: "CLI dispatch failed for {perspective}"
3. Continue with remaining CLI (do NOT substitute)
4. Mark synthesis as partial if both CLIs failed for same perspective
