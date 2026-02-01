# Agent Response Schema (P6)

> Standard response format for all agents in the `/sdd:01-specify` workflow.
> Version: 1.0 | Reference: `specs/config/specify-config.yaml`

---

## Purpose

This schema ensures consistent, parseable responses from all agents in the specification workflow. It eliminates ambiguity in orchestrator-agent communication and enables reliable error handling.

---

## Response Format

All agents MUST return a response in this YAML format at the END of their output:

```yaml
---
# AGENT RESPONSE
response:
  status: success | partial | error

  outputs:
    - file: "path/to/file.md"
      action: created | updated | deleted
      lines: 245  # optional
    - file: "path/to/another.md"
      action: updated

  metrics:
    # Phase-specific metrics (examples)
    self_critique_score: 17
    user_stories_count: 8
    requirements_count: 15
    coverage_percentage: 85
    gaps_identified: 3

  warnings:
    - "NFR-003 has vague acceptance criteria"
    - "US-005 may need splitting (multiple When clauses)"

  errors:  # Only if status != success
    - "Failed to read figma_context.md: file not found"

  next_step: "Proceed to checklist validation (Phase 4)"

  user_decisions_needed:  # Optional, for clarification requests
    - question: "How should offline mode behave?"
      marker: "NEEDS_CLARIFICATION_001"
---
```

---

## Field Definitions

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `status` | enum | `success`, `partial`, or `error` |
| `outputs` | list | Files created/modified by the agent |
| `next_step` | string | Human-readable description of recommended next action |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `metrics` | object | Numeric metrics specific to the phase |
| `warnings` | list | Non-blocking issues that should be noted |
| `errors` | list | Error messages (required if status != success) |
| `user_decisions_needed` | list | Questions requiring user input |

---

## Status Values

| Status | Meaning | Orchestrator Action |
|--------|---------|---------------------|
| `success` | All tasks completed | Proceed to next phase |
| `partial` | Some tasks completed | Review warnings, may proceed |
| `error` | Critical failure | Handle error, may retry or abort |

---

## Output Actions

| Action | Meaning |
|--------|---------|
| `created` | New file was created |
| `updated` | Existing file was modified |
| `deleted` | File was removed |

---

## Agent-Specific Metrics

### Business Analyst Agent (Phase 2)

```yaml
metrics:
  self_critique_score: 17        # /20
  user_stories_count: 8
  functional_requirements: 12
  non_functional_requirements: 5
  acceptance_criteria_count: 24
  needs_clarification_markers: 2
```

### Gap Analyzer Agent (Phase 5.5)

```yaml
metrics:
  correlation_percentage: 85
  high_confidence_mappings: 10
  medium_confidence_mappings: 3
  low_confidence_mappings: 1
  orphan_screens: 0
  missing_states: 4
  p1_gaps: 1
  p2_gaps: 3
```

### Design Brief Generator Agent (Phase 5.5)

```yaml
metrics:
  screens_identified: 8
  states_per_screen_avg: 3.5
  user_journeys: 3
  open_questions: 5
```

---

## Example Responses

### Success Response

```yaml
---
response:
  status: success

  outputs:
    - file: "specs/001-user-auth/spec.md"
      action: created
      lines: 312

  metrics:
    self_critique_score: 18
    user_stories_count: 6
    functional_requirements: 10
    non_functional_requirements: 4

  warnings:
    - "Consider adding offline behavior for login screen"

  next_step: "Proceed to checklist validation (Phase 4)"
---
```

### Partial Response

```yaml
---
response:
  status: partial

  outputs:
    - file: "specs/001-user-auth/spec.md"
      action: created
      lines: 245

  metrics:
    self_critique_score: 14
    user_stories_count: 6
    needs_clarification_markers: 3

  warnings:
    - "Self-critique score below threshold (14 < 16)"
    - "3 clarification markers need resolution"

  user_decisions_needed:
    - question: "What authentication methods should be supported?"
      marker: "NEEDS_CLARIFICATION_001"
    - question: "Should session persist across app restarts?"
      marker: "NEEDS_CLARIFICATION_002"

  next_step: "Address clarification markers before proceeding"
---
```

### Error Response

```yaml
---
response:
  status: error

  outputs: []

  errors:
    - "Template file not found: specs/templates/spec-template.md"
    - "Cannot proceed without specification template"

  next_step: "Fix missing template and retry"
---
```

---

## Orchestrator Parsing

The orchestrator parses agent responses using this pattern:

```python
# Pseudocode for response parsing
def parse_agent_response(output: str) -> AgentResponse:
    # Find YAML block at end of output
    yaml_match = re.search(r'---\nresponse:.*?---', output, re.DOTALL)

    if not yaml_match:
        return AgentResponse(
            status="error",
            errors=["Agent did not return structured response"]
        )

    response = yaml.safe_load(yaml_match.group())
    return AgentResponse(**response['response'])
```

---

## Migration Notes

### From Unstructured Responses

**Before (deprecated):**
```markdown
## Summary

I have completed the specification. The spec.md file has been created with 8 user stories and 12 functional requirements. The self-critique score is 17/20.

Next, you should run the checklist validation.
```

**After (required):**
```markdown
## Summary

I have completed the specification with 8 user stories and 12 functional requirements.

---
response:
  status: success
  outputs:
    - file: "specs/001-feature/spec.md"
      action: created
  metrics:
    self_critique_score: 17
    user_stories_count: 8
    functional_requirements: 12
  next_step: "Proceed to checklist validation (Phase 4)"
---
```

---

## Validation

Agents should self-validate their response before returning:

```
CHECKLIST:
[ ] status is one of: success, partial, error
[ ] outputs list includes all files modified
[ ] metrics includes all relevant phase metrics
[ ] next_step is actionable and specific
[ ] if status == error, errors list is populated
[ ] YAML is valid and parseable
```
