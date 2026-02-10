---
stage: recovery
artifacts_written: []
---

# Crash Recovery Protocol

> Used by the orchestrator when re-invoking the skill and detecting incomplete state.
> Identifies the last fully completed stage and resumes from there.

## CRITICAL RULES (must follow)

1. **Never discard completed work**: If a screen narrative exists, preserve it even if the summary is missing.
2. **Reconstruct minimal summaries**: If an agent wrote artifacts but no summary, build a minimal summary from artifact YAML frontmatter.
3. **Reset to last safe checkpoint**: Set `current_stage` to the last stage where ALL expected artifacts exist.

---

## Crash Detection

On skill re-invocation, check for inconsistent state:

```
READ state file

# Stage 2: Screen in_progress with no summary
FOR each screen WHERE status == "in_progress":
    CHECK: Does screens/{nodeId}-{name}-summary.md exist?
    CHECK: Does screens/{nodeId}-{name}.md exist?

# Stage 3: Coherence started but no report
IF current_stage == 3 AND coherence.status != "completed":
    CHECK: Does design-narration/coherence-report.md exist?

# Stage 4: Partial MPA outputs
IF current_stage == 4 AND validation.status != "completed":
    CHECK: Which of these exist?
      - design-narration/validation/mpa-implementability.md
      - design-narration/validation/mpa-ux-completeness.md
      - design-narration/validation/mpa-edge-cases.md
      - design-narration/validation/synthesis.md
```

---

## Recovery Procedures

### Stage 2 Recovery: Incomplete Screen

```
IF screen narrative exists BUT no summary:
    RECONSTRUCT minimal summary from narrative YAML frontmatter:
        status: needs-user-input
        narrative_file: {path}
        critique_scores: {from frontmatter or null}
        questions: []
    WRITE summary file
    SET screen.status = "described" in state
    RESUME Stage 2 Q&A mediation for this screen

IF no narrative AND no summary:
    SET screen.status = "pending" in state
    RESUME Stage 2 from dispatch 2A for this screen
```

### Stage 3 Recovery: Incomplete Coherence

```
IF coherence-report.md missing:
    SET coherence.status = "pending"
    SET current_stage = 3
    RE-DISPATCH coherence auditor

IF coherence-report.md exists but coherence.status != "completed":
    READ report, verify YAML frontmatter populated
    IF valid: SET coherence.status = "completed", advance
    IF invalid: RE-DISPATCH coherence auditor
```

### Stage 4 Recovery: Partial MPA Outputs

```
IDENTIFY which MPA output files are missing
RE-DISPATCH only the missing agents (do NOT re-run completed agents)

IF synthesis.md missing but all 3 MPA outputs exist:
    DISPATCH synthesis agent only

IF synthesis.md exists but validation.status != "completed":
    READ synthesis, verify YAML frontmatter populated
    IF valid: SET validation.status = "completed", advance
    IF invalid: RE-DISPATCH synthesis agent
```

---

## State Cleanup

After recovery:

```
UPDATE state file:
    current_stage: {last fully completed stage + 1}
    Remove any orphan screen entries with no artifacts
NOTIFY user: "Recovered from interrupted session. Resuming from Stage {N}."
```
