---
description: "Shared protocol compliance checklist for stage coordinators (v3.5.0)"
used_by:
  - "stage-2-execution.md (Section 2.2a)"
  - "stage-3-validation.md (Section 3.4a)"
  - "stage-4-quality-review.md (Section 4.4a)"
  - "stage-5-documentation.md (Section 5.3a)"
  - "orchestrator-loop.md (VERIFY_STAGE_PROTOCOL remediation)"
---

# Protocol Compliance Checklist

Before writing ANY stage summary (Stages 2-5), the coordinator MUST complete the applicable checklist below and record results in the `protocol_evidence` map. Every item must be TRUE or have an explicit exception logged.

## Universal Checks (All Stages)

1. **All prompt templates sourced from agent-prompts.md**: No ad-hoc agent instructions were written inline. Cross-reference `prompt-registry.yaml` for required variables per template.
2. **No direct agent dispatches from orchestrator**: All agents dispatched through this coordinator (not by the orchestrator directly)
3. **protocol_evidence populated**: The `protocol_evidence` map in the summary is populated with actual dispatch records (agent types, template names, sequential confirmation)

## Stage 2: Phase-by-Phase Execution

4. **Sequential phase execution**: Each phase executed sequentially (not in parallel or background)
5. **test-writer dispatched**: For each phase where `features.output_verifier` is `true` (from Stage 1 summary) and `test_cases_available` is `true` and CLI test author did NOT run — test-writer agent was dispatched (Step 1.9). **This step is NOT OPTIONAL. Skipping this step is a protocol violation.**
6. **developer dispatched with template**: Developer agent dispatched for each phase using the Phase Implementation Prompt template from `agent-prompts.md`
7. **output-verifier dispatched**: For each phase where `features.output_verifier` is `true` (from Stage 1 summary) — output-verifier agent was dispatched (Step 2.5). **This step is NOT OPTIONAL. Skipping this step is a protocol violation.**
8. **code-simplifier dispatched if enabled**: When `features.code_simplification` is `true` (from Stage 1 summary) — code-simplifier was dispatched for each eligible phase (Step 3.5)

### Stage 2 protocol_evidence Example

```yaml
protocol_evidence:
  agents_dispatched:
    - {type: "test-writer", template_used: "Test Writing Prompt", phase: "Phase 1: Setup"}
    - {type: "developer", template_used: "Phase Implementation Prompt", phase: "Phase 1: Setup"}
    - {type: "output-verifier", template_used: "Output Verification Prompt", phase: "Phase 1: Setup"}
  prompt_templates_used: ["Test Writing Prompt", "Phase Implementation Prompt", "Output Verification Prompt", "Code Simplification Prompt"]
  phases_executed_sequentially: true
  per_phase_steps_completed:
    "Phase 1: Setup": ["1.9", "2", "2.5", "3", "3.5"]
    "Phase 2: Core": ["1.9", "2", "2.5", "3", "3.5"]
```

## Stage 3: Completion Validation

4. **developer agent dispatched with template**: Developer agent dispatched using the Completion Validation Prompt template from `agent-prompts.md`
5. **All test suites executed**: Test suite was actually run (not just reported from memory or assumed from Stage 2)
6. **Build verification attempted**: Build command (`./gradlew assembleDebug` or project-equivalent from Stage 1 summary `project_setup.build_command`) was attempted — not skipped
7. **Vertical slice wiring verified**: Navigation routes connect, services are bound, database initialization works, dependency injection graph resolves — verify the components actually wire together, not just that the code exists (Check 15)
8. **No N/A for checks with available tooling**: Every validation check (1-14) that has the required tooling available was actually executed — N/A is only valid when the tooling or prerequisite is genuinely absent

### Stage 3 protocol_evidence Example

```yaml
protocol_evidence:
  agents_dispatched:
    - {type: "developer", template_used: "Completion Validation Prompt", phase: "Phase 1: Setup"}
  prompt_templates_used: ["Completion Validation Prompt"]
  phases_executed_sequentially: true
  per_phase_steps_completed:
    "validation": ["3.1", "3.2", "3.3", "3.4", "check_15_wiring"]
```

## Stage 4: Quality Review

4. **3+ distinct reviewers dispatched**: At least 3 separate `developer` agent dispatches for Tier A review (not 1 reviewer relabeled or reused)
5. **Each reviewer has distinct focus area**: Focus areas match `quality_review.focus_areas` from config — Simplicity/DRY, Bugs/Correctness, Conventions/Patterns
6. **Reviewer prompts used Quality Review Prompt template**: All reviewer dispatches used the template from `agent-prompts.md` with proper `{focus_area}` and `{reviewer_stance}` variables
7. **Protocol violations from prior stages escalated**: If `protocol_evidence` from Stage 2 or Stage 3 summaries shows missing agents, parallel execution, or missing template usage — escalate as a **Critical** finding: "Protocol violation detected in Stage {N}: {description}"

### Stage 4 protocol_evidence Example

```yaml
protocol_evidence:
  agents_dispatched:
    - {type: "developer", template_used: "Quality Review Prompt", phase: "review", focus: "Simplicity/DRY"}
    - {type: "developer", template_used: "Quality Review Prompt", phase: "review", focus: "Bugs/Correctness"}
    - {type: "developer", template_used: "Quality Review Prompt", phase: "review", focus: "Conventions/Patterns"}
  prompt_templates_used: ["Quality Review Prompt"]
  phases_executed_sequentially: true
  per_phase_steps_completed:
    "review": ["4.1a", "4.1b", "4.2", "4.3a", "4.3", "4.3b", "4.4"]
```

## Stage 5: Feature Documentation

4. **tech-writer agent dispatched with template**: Tech-writer agent dispatched using the Documentation Update Prompt template from `agent-prompts.md`
5. **doc-judge dispatched if enabled**: When `doc_judge.enabled` is `true` AND Phase Scope is present — doc-judge agent was dispatched for documentation accuracy verification (Section 5.2b)
6. **Documentation references actual code**: Generated documentation references actual function/class names verified against the codebase — not invented or assumed names

### Stage 5 protocol_evidence Example

```yaml
protocol_evidence:
  agents_dispatched:
    - {type: "tech-writer", template_used: "Documentation Update Prompt", phase: "Phase 1: Setup"}
    - {type: "doc-judge", template_used: "Documentation Verification Prompt", phase: "Phase 1: Setup"}
  prompt_templates_used: ["Documentation Update Prompt", "Documentation Verification Prompt"]
  phases_executed_sequentially: true
  per_phase_steps_completed:
    "documentation": ["5.1", "5.1a", "5.2", "5.2b"]
```
