---
stage: recovery
artifacts_written:
  - design-narration/.narration-state.local.md (repaired)
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

# Stage 5: Incomplete output assembly
IF current_stage == 5:
    CHECK: Does design-narration/UX-NARRATIVE.md exist?
    CHECK: Is design-narration/.narration-lock still present?
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

IF design-narration/.qa-digest.md exists:
    VERIFY screens listed in digest match screens with status "signed_off" in state
    IF mismatch (digest references screens not in state, or missing signed-off screens):
        DELETE .qa-digest.md (will be regenerated on next compaction threshold)
```

### Stage 2 Recovery: Partial Q&A State

```
FOR each screen WHERE status in ["questions_asked", "critiqued", "refined"]:
    # Screen had Q&A in progress when session crashed
    READ decisions_audit_trail entries WHERE screen == this screen
    EXTRACT answered_question_ids from audit trail entries

    READ summary file (screens/{nodeId}-{name}-summary.md)
    EXTRACT questions list from summary

    COMPUTE unanswered_questions = summary.questions WHERE id NOT IN answered_question_ids

    IF unanswered_questions is empty:
        # All questions were answered but refinement (2B) didn't run
        SET screen.status = "questions_asked"
        RESUME Stage 2 at 2B dispatch (refinement) with recorded answers from audit trail

    IF unanswered_questions is non-empty:
        # Partial Q&A — some answers already recorded
        SET screen.status = "questions_asked"
        RESUME Stage 2 Q&A mediation with ONLY unanswered_questions
        NOTIFY user: "Recovered {ANSWERED_COUNT} prior answer(s) for '{SCREEN_NAME}'. Continuing with {REMAINING_COUNT} remaining question(s)."
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

### Stage 5 Recovery: Incomplete Output Assembly

```
IF current_stage == 5:
    CHECK: Does design-narration/UX-NARRATIVE.md exist?

    IF UX-NARRATIVE.md missing:
        # Assembly never started or crashed mid-write
        SET current_stage = 5
        RE-RUN output assembly (per references/output-assembly.md)

    IF UX-NARRATIVE.md exists BUT lock file still present:
        # Assembly completed writing but crashed before cleanup
        READ UX-NARRATIVE.md
        VERIFY: contains at least 1 screen narrative section AND validation summary
        IF valid:
            REMOVE lock file
            UPDATE state: current_stage = 5, mark workflow complete
            NOTIFY user: "Recovered: UX-NARRATIVE.md was already assembled. Cleaned up lock file."
        IF invalid (empty or truncated):
            DELETE incomplete UX-NARRATIVE.md
            RE-RUN output assembly (per references/output-assembly.md)
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

---

## Self-Verification

After recovery completes:

1. State file `current_stage` matches actual artifact state on disk
2. No orphan screen entries (entries without corresponding files)
3. Lock file still present (recovery does not release the lock)
4. User notified of recovery action taken

## CRITICAL RULES REMINDER

1. Never discard completed work
2. Reconstruct minimal summaries from artifact frontmatter
3. Reset to last safe checkpoint
