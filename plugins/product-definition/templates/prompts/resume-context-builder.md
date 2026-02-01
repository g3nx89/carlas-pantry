# Resume Context Builder Template

## Purpose

This template defines how to construct the RESUME_CONTEXT variable when resuming
or re-running a specification workflow. The context is injected into all subsequent
Task prompts to `business-analyst` and other agents.

---

## Base Structure

```markdown
<resume_context>
## RESUMED WORKFLOW - MANDATORY COMPLIANCE REQUIRED

**YOU MUST comply with these rules:**
1. **SKIP** all completed phases listed below - do NOT re-execute them
2. **NEVER** re-ask questions from "User Decisions" - these are IMMUTABLE
3. **START** execution from the indicated resume phase
4. **READ** existing artifacts (spec.md, checklist.md) to understand current state

### Session State
| Field | Value |
|-------|-------|
| Resume Phase | {current_phase} |
| Phase Status | {phase_status} |
| Feature | {feature_name} |
| State File | {STATE_FILE} |

### Completed Phases
{for each phase in phases.* where status == "completed":}
- {phase_name} ({timestamp})

### User Decisions (IMMUTABLE - NEVER RE-ASK THESE)
{if user_decisions.platform_choice is set:}
- **Platform**: {platform_choice}
{if user_decisions.figma_enabled is set:}
- **Figma Enabled**: {figma_enabled}
{if figma_enabled == true:}
- **Figma Connection**: {figma_connection} (desktop | online)
- **Figma Capture Mode**: {figma_capture_mode} (selected | page)
{for each item in user_decisions.clarifications:}
- **{question}** -> {answer} [phase: {phase}, iteration: {iteration}]

### Phase-Specific Context
{include content based on current_phase}

</resume_context>
```

---

## Phase-Specific Context Rules

### For RESUME from Phase 2+ (SPEC_DRAFT)

```markdown
#### SPEC_DRAFT Context
- Spec file exists: {yes/no}
- If exists, line count: {count}
- User stories identified: {count or "pending"}
- @FigmaRef annotations: {count}
```

### For RESUME from Phase 4+ (CHECKLIST_VALIDATION)

```markdown
#### Previous Progress
[Include Phase 2 context above]

#### CHECKLIST_VALIDATION Context
- spec.md created: YES
- User stories: {count}
- Acceptance criteria: {count}
- Checklist file: {exists yes/no}
- Last validation score: {score}/100 ({status})
```

### For RESUME from Phase 4.5 (CLARIFICATION - mid-process)

```markdown
#### Previous Progress
[Include Phase 4 context above]

#### CLARIFICATION Context
- Total questions identified: {total}
- Questions answered: {answered}
- Questions remaining: {remaining}
- Batches completed: {batches_done}/{total_batches}

#### Already Answered (DO NOT RE-ASK)
{for each answered question:}
| Question | Answer | BA Recommended | Matched |
|----------|--------|----------------|---------|
| {q1} | {a1} | {rec1} | {yes/no} |
```

### For RESUME from Phase 5+ (PAL_GATE)

```markdown
#### Previous Progress
[Include Phase 4.5 context above]

#### PAL_GATE Context
- Checklist score: {score}/100
- All clarifications resolved: YES
- PAL Consensus status: {PENDING | APPROVED | CONDITIONAL | REJECTED}
- PAL Score (if executed): {score}/20
- PAL Iteration: {N}
```

### For RESUME from Phase 5.5 (DESIGN_FEEDBACK)

```markdown
#### Previous Progress
[Include Phase 5 context above]

#### DESIGN_FEEDBACK Context
- PAL Decision: {decision}
- Design Feedback Mode: {design_brief | gap_analysis | skipped}
- Figma Context: {exists yes/no}
- Gaps identified: {count}
```

### For RERUN_CLARIFY

```markdown
#### RERUN_CLARIFY Context
- Previous clarification iterations: {count}
- Previous checklist score: {score}
- Target improvement: +10 points minimum
- Existing answers: PRESERVED (only asking NEW questions)

#### Previously Answered (DO NOT RE-ASK)
{full list of all previous answers}

#### Focus Areas for New Questions
- Checklist items still uncovered: {list}
- Remaining markers in spec: {count}
```

### For RERUN_PAL

```markdown
#### RERUN_PAL Context
- Previous PAL attempts: {count}
- Previous scores: {list}
- Previous decision: {decision}
- Reason for re-run: {user requested | spec updated | automatic retry}

#### Changes Since Last PAL Run
{if spec was modified:}
- Sections updated: {list}
- New requirements added: {count}
- Clarifications integrated: {count}
```

---

## Usage Instructions

### Building the Context

1. Parse STATE_FILE YAML frontmatter
2. Determine which phase-specific context to include
3. Substitute all `{variables}` with actual values
4. Wrap in `<resume_context>` tags
5. Store in RESUME_CONTEXT variable

### Injecting into Prompts

Include at the START of every Task prompt:

```markdown
{RESUME_CONTEXT}

## Your Task
[Rest of prompt...]
```

### Validation

Before using the context:
- Verify all variables are substituted (no `{...}` remaining)
- Confirm completed phases list matches state file
- Ensure user decisions are complete for answered questions
