# Self-Critique Template (S1)

Standard self-critique section for all agents. Based on Constitutional AI Self-Critique (Bai et al., 2022) and Chain-of-Verification (Dhuliawala et al., 2023).

## Question Count Guidelines

Different agent types have intentionally different verification question counts based on their responsibility level and cost profile.

| Agent Type | Questions | Pass Threshold | Rationale |
|------------|-----------|----------------|-----------|
| Architect agents (software-architect) | 6 | 5/6 | Higher stakes decisions, architecture choices have long-term impact |
| Standard agents (code-explorer, researcher, tech-lead) | 5 | 4/5 | Balanced thoroughness for core analysis work |
| Lightweight agents (learnings-researcher, haiku models) | 4 | 3/4 | Cost-conscious, simpler scope |
| Judge agents (phase-gate-judge, debate-judge) | 4-5 | varies | Calibration focus rather than discovery |

**Mode-Specific Overrides:**

| Mode | Override | Rationale |
|------|----------|-----------|
| Rapid | All agents use 3 questions, 2 pass | Speed over thoroughness |
| Complete | Architect agents may use 7+ questions | Maximum verification for critical features |

This variance is intentional, not a bug. When creating new agents, select the question count based on the agent's decision impact level.

## Template for Agent Prompts

Copy this section into agent prompts after "Output Format" and before "Anti-Patterns":

```markdown
## Self-Critique Loop (MANDATORY)

**YOU MUST complete this self-critique before submitting your output.**

Before completing, verify your work through this structured process:

### 1. Generate 5 Verification Questions

Ask yourself task-specific questions. These should be relevant to YOUR specific task:

| # | Question Type | Example |
|---|---------------|---------|
| 1 | Completeness | "Have I addressed all requirements from the spec?" |
| 2 | Edge Cases | "Have I considered error conditions and unusual inputs?" |
| 3 | Evidence | "Is every recommendation backed by specific evidence?" |
| 4 | Risks | "Have I identified risks and stated my assumptions?" |
| 5 | Actionability | "Is my output specific and immediately actionable?" |

**Write out your 5 questions explicitly before answering them.**

### 2. Answer Each Question with Evidence

For each question, provide:
- **Answer**: YES / NO / PARTIAL
- **Evidence**: Specific references (file paths, code snippets, documentation links)
- **Gap** (if NO/PARTIAL): What is missing and how critical is it?

Example:
```
Q1: Have I addressed all acceptance criteria?
A1: PARTIAL
Evidence: Addressed AC-1, AC-2, AC-3. Missing AC-4 (error handling).
Gap: AC-4 not addressed - CRITICAL, must fix before submission.
```

### 3. Revise If Needed

If ANY question reveals a gap:

1. **STOP** - Do not submit incomplete work
2. **FIX** - Address the specific gap with concrete changes
3. **RE-VERIFY** - Confirm the fix addresses the gap
4. **DOCUMENT** - Note what was changed and why

### 4. Output Self-Critique Summary

Include this block in your final output:

```yaml
self_critique:
  questions_passed: X/5
  revisions_made: N
  revision_summary: "Brief description of changes made"
  confidence: "HIGH|MEDIUM|LOW"
  limitations: ["Any known limitations or caveats"]
```

### Mode-Specific Thresholds

| Mode | Min Questions | Pass Threshold | Evidence Required |
|------|---------------|----------------|-------------------|
| Rapid | 3 | 2/3 | Optional |
| Standard | 5 | 4/5 | Yes |
| Advanced | 5 | 4/5 | Yes (detailed) |
| Complete | 5 | 5/5 | Yes (comprehensive) |

**If you cannot meet the threshold, document why and flag for human review.**
```

## Integration Notes

1. **Placement**: After output format, before anti-patterns
2. **Token Impact**: ~10-15% increase per agent
3. **Verification**: Check agent outputs include `self_critique:` YAML block

## Example Verification Questions by Agent Type

### Code Explorer
1. Have I traced ALL execution paths from entry to output?
2. Do ALL code references include specific file:line locations?
3. Have I correctly identified the design patterns used?
4. Have I mapped ALL dependencies (internal and external)?
5. Does my architecture understanding match actual code boundaries?

### Researcher
1. Have I cited official documentation and primary sources?
2. Are my sources current (check publication dates)?
3. Have I explored at least 3 viable alternatives?
4. Are my recommendations immediately actionable?
5. Is there strong evidence behind each recommendation?

### Software Architect
1. Do all options address the stated requirements?
2. Have I documented trade-offs for each approach?
3. Are risks identified with mitigation strategies?
4. Is the recommended option consistent with codebase patterns?
5. Are component interfaces clearly defined?

### QA Strategist
1. Does every acceptance criterion have at least one test?
2. Does every Critical/High risk have test coverage?
3. Are UAT scripts understandable by non-technical users?
4. Is the coverage matrix complete (no empty rows)?
5. Are tests independent and not duplicating coverage?
