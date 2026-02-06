# Stage 5: Feature Documentation

## 5.1 Implementation Verification

Before documenting, verify that the implementation is complete enough to document.

### Verification Steps

1. Read `tasks.md` and check task completion status:
   - Count tasks marked `[X]` vs total tasks
   - Identify any incomplete or partially implemented tasks
   - Review codebase for any missing or incomplete functionality referenced in tasks

2. **If all tasks are complete**: Proceed to Section 5.2 (Documentation Update)

3. **If incomplete tasks exist**: Present findings to user via `AskUserQuestion`:

   **Question:** "{N} tasks are incomplete in tasks.md. How would you like to proceed?"

   **Options:**
   1. **Fix now** — Launch `developer` agent to address incomplete tasks before documenting
   2. **Document as-is** — Proceed with documentation noting incomplete areas
   3. **Stop here** — Halt and return to implementation

### On "Fix Now"

1. Launch `developer` agent with the incomplete task fix prompt from `agent-prompts.md` (Section: Incomplete Task Fix Prompt)
2. After fixes, re-verify task completion
3. If still incomplete, present to user again (loop until resolved or user chooses to proceed)
4. Store decision in state file: `user_decisions.documentation_verification: "fixed"`

### On "Document As-Is"

1. Store decision: `user_decisions.documentation_verification: "accepted_incomplete"`
2. Note incomplete tasks for the tech-writer agent to document as known limitations
3. Proceed to Section 5.2

## 5.2 Documentation Update

Launch `tech-writer` agent to create and update project documentation based on the implementation.

### Agent Dispatch

```
Task(subagent_type="product-implementation:tech-writer")
```

Use the documentation prompt template from `agent-prompts.md` (Section: Documentation Update Prompt).

### Documentation Scope

The tech-writer agent should:

1. **Load context** from FEATURE_DIR (the tech-writer agent operates in a separate context and must load these files independently from Stage 1):
   - Read spec.md for feature requirements
   - Read plan.md for architecture and file structure
   - Read tasks.md for what was implemented
   - Read contracts.md for API specifications
   - Read data-model.md for entity definitions

2. **Review implementation**:
   - Identify all files modified during implementation (from tasks.md file paths)
   - Review what was built and how it works
   - Note any implementation challenges and solutions

3. **Update project documentation**:
   - Document feature in `docs/` folder (API guides, usage examples, architecture updates)
   - Add or update README.md files in folders affected by implementation
   - Include development specifics and module summaries for LLM navigation

4. **Ensure documentation completeness**:
   - Cover all implemented features with usage examples
   - Document API changes or additions
   - Include troubleshooting guidance for common issues
   - Maintain proper Markdown formatting

## 5.3 Documentation Summary

After the tech-writer agent completes, present output to user:

```text
## Documentation Update Summary

Feature: {FEATURE_NAME}

### Files Updated
- {file1} — {brief description of changes}
- {file2} — {brief description of changes}

### Major Changes
- {change 1}
- {change 2}

### New Documentation Added
- {doc 1}
- {doc 2}

### Status
Documentation complete / Documentation complete with noted gaps
```

## 5.4 State Update and Lock Release

After documentation completes:

1. Update state file:
   - Set `current_stage: 5`
   - Store `user_decisions.documentation_outcome: "completed"`
   - Update `last_checkpoint`
   - Append to Implementation Log: "Stage 5: Documentation — completed"

2. Release lock:
   - Set `lock.acquired: false`

3. Report final status to user with the complete implementation journey summary.
