---
stage: validation
artifacts_written:
  - design-narration/validation/mpa-implementability.md
  - design-narration/validation/mpa-ux-completeness.md
  - design-narration/validation/mpa-edge-cases.md
  - design-narration/validation/synthesis.md
  - design-narration/.narration-state.local.md (updated)
---

# Validation Protocol (Stage 4)

> Orchestrator dispatches MPA agents in parallel + PAL Consensus for quality validation.
> Synthesis agent merges findings. Critical issues presented to user.

## CRITICAL RULES (must follow)

1. **MPA agents run in parallel**: Dispatch all 3 via Task in a SINGLE message (parallel execution).
2. **PAL Consensus requires minimum 2 models**: If fewer than 2 respond, mark as PARTIAL and notify user.
3. **Graceful degradation**: If PAL unavailable, skip consensus (MPA results only). NOTIFY user.
4. **User sees critical findings**: CRITICAL findings are presented via AskUserQuestion. IMPORTANT/MINOR are applied automatically.

---

## Step 4.1: MPA Agent Dispatch (Parallel)

Dispatch all 3 agents in a SINGLE message for parallel execution:

```
# Agent 1: Developer Implementability
Task(subagent_type="general-purpose", prompt="""
Read and follow: @$CLAUDE_PLUGIN_ROOT/agents/narration-developer-implementability.md

## Input
- Screens directory: design-narration/screens/
- Screen files: {LIST_OF_SCREEN_FILES}
- Figma directory: design-narration/figma/

## Output
Write to: design-narration/validation/mpa-implementability.md
""")

# Agent 2: UX Completeness
Task(subagent_type="general-purpose", prompt="""
Read and follow: @$CLAUDE_PLUGIN_ROOT/agents/narration-ux-completeness.md

## Input
- Screens directory: design-narration/screens/
- Screen files: {LIST_OF_SCREEN_FILES}
- Coherence report: design-narration/coherence-report.md

## Output
Write to: design-narration/validation/mpa-ux-completeness.md
""")

# Agent 3: Edge Case Auditor
Task(subagent_type="general-purpose", prompt="""
Read and follow: @$CLAUDE_PLUGIN_ROOT/agents/narration-edge-case-auditor.md

## Input
- Screens directory: design-narration/screens/
- Screen files: {LIST_OF_SCREEN_FILES}

## Output
Write to: design-narration/validation/mpa-edge-cases.md
""")
```

---

## Step 4.2: PAL Consensus

After MPA agents complete, invoke PAL Consensus:

```
IF PAL_AVAILABLE:
    mcp__pal__consensus(
        question: "Review the following UX narrative document for completeness and implementability.
        Is this narrative sufficient for a coding agent to implement each screen
        without additional questions?

        [Include: list of screen names + per-screen critique scores + coherence check result]

        Rate overall readiness: READY / NEEDS_REVISION / NOT_READY
        List any specific gaps or ambiguities found.",

        models: ["openai/chatgpt-5.2", "google/gemini-3-pro", "x-ai/grok-4"],
        format: "structured"
    )

    IF fewer than 2 models respond:
        NOTIFY user: "PAL Consensus partial — only {N} model(s) responded."
        MARK validation.pal_status: "partial"

ELSE:
    NOTIFY user: "PAL tools unavailable. Validation based on MPA results only."
    MARK validation.pal_status: "skipped"
```

---

## Step 4.3: Synthesis

Dispatch the synthesis agent:

```
Task(subagent_type="general-purpose", prompt="""
Read and follow: @$CLAUDE_PLUGIN_ROOT/agents/narration-validation-synthesis.md

## Input
- MPA Implementability: design-narration/validation/mpa-implementability.md
- MPA UX Completeness: design-narration/validation/mpa-ux-completeness.md
- MPA Edge Cases: design-narration/validation/mpa-edge-cases.md
- PAL Consensus: {PAL_RESPONSE or "PAL skipped"}

## Output
Write to: design-narration/validation/synthesis.md
""")
```

### Synthesis Output Format

```yaml
---
quality_score: [0-100]
recommendation: ready | needs-revision
critical_findings: {N}
important_findings: {N}
minor_findings: {N}
---
```

Followed by:

```markdown
## Critical Findings (Must Fix)
| # | Screen | Finding | Suggested Fix |
[Blocking implementation — present to user]

## Important Findings (Should Fix)
| # | Screen | Finding | Suggested Fix |
[Apply automatically — notify user]

## Minor Findings (Optional)
| # | Screen | Finding | Suggested Fix |
[Apply if straightforward — no notification needed]
```

---

## Orchestrator: Handle Findings

```
READ synthesis.md

IF critical_findings > 0:
    FOR each critical finding (batch of up to 4):
        PRESENT via AskUserQuestion:
            question: "[CRITICAL] {FINDING_DESCRIPTION}
            Screen: {SCREEN_NAME}
            Impact: {WHY_THIS_BLOCKS_IMPLEMENTATION}"

            options:
              - "Fix as suggested: {SUGGESTED_FIX} (Recommended)"
              - "Skip this — I'll handle it manually"
              - "Let's discuss this"

        IF user approves fix:
            UPDATE affected screen narrative file
            ADD to decision audit trail

FOR important_findings:
    APPLY suggested fixes to screen narratives
    NOTIFY user: "Applied {N} important improvements to screen narratives."

FOR minor_findings:
    APPLY if straightforward (no structural changes)
    No notification needed

UPDATE state:
    validation.status: completed
    validation.quality_score: {score}
    validation.recommendation: {recommendation}
    validation.pal_status: {completed|partial|skipped}
```

---

## Orchestrator: Validation Gate

```
IF recommendation == "ready":
    ADVANCE to Stage 5

IF recommendation == "needs-revision" AND critical_findings were all addressed:
    ADVANCE to Stage 5 (user acknowledged gaps)

IF recommendation == "needs-revision" AND critical_findings remain:
    PRESENT via AskUserQuestion:
        question: "Validation found unresolved critical issues.
        Proceed to generate UX-NARRATIVE.md anyway?"

        options:
          - "Yes, generate with known gaps noted"
          - "No, let me address these first"

    IF "No": EXIT workflow (user will re-invoke after fixes)
    IF "Yes": ADVANCE to Stage 5 with gaps noted in output
```

---

## Self-Verification

Before advancing to Stage 5:

1. `design-narration/validation/` directory exists with all MPA output files
2. Synthesis file has populated YAML frontmatter (no null scores)
3. All critical findings presented to user (none silently skipped)
4. State file validation section updated
5. PAL status recorded (completed/partial/skipped)

## CRITICAL RULES REMINDER

1. MPA agents run in parallel (single message, 3 Task calls)
2. PAL Consensus minimum 2 models
3. Graceful degradation if PAL unavailable
4. Critical findings always go through user
