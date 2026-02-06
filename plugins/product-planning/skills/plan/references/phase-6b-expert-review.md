---
phase: "6b"
phase_name: "Expert Review"
checkpoint: "EXPERT_REVIEW"
delegation: "coordinator"
modes: [complete, advanced]
prior_summaries:
  - ".phase-summaries/phase-6-summary.md"
artifacts_read:
  - "design.md"
  - "plan.md"
artifacts_written:
  - "analysis/expert-review.md"
agents:
  - "product-planning:security-analyst"
  - "product-planning:simplicity-reviewer"
mcp_tools: []
feature_flags:
  - "a4_expert_review"
additional_references: []
---

# Phase 6b: Expert Review (A4)

> **COORDINATOR INSTRUCTIONS**
> You are a phase coordinator dispatched by the lean orchestrator.
> 1. Read this file completely for your phase instructions.
> 2. Read the prior phase summaries listed in `prior_summaries` frontmatter from `{FEATURE_DIR}/.phase-summaries/`.
> 3. Read the artifacts listed in `artifacts_read` frontmatter from `{FEATURE_DIR}/`.
> 4. Execute ALL steps below for the current `analysis_mode`.
> 5. Write your output artifacts to `{FEATURE_DIR}/`.
> 6. Write your phase summary to `{FEATURE_DIR}/.phase-summaries/phase-6b-summary.md` using the template at `$CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md`.
> 7. You MUST NOT interact with the user directly. If user input is needed, set `status: needs-user-input` in your summary with `block_reason` explaining what is needed and what options are available.
> 8. If a sub-agent (Task) fails, retry once. If it fails again, continue with partial results and set `flags.degraded: true` in your summary.

**Purpose:** Qualitative expert review of architecture and plan.

**Prerequisite:** Feature flag `a4_expert_review` must be enabled AND analysis_mode in {advanced, complete}.

## Step 6b.1: Launch Expert Review Agents

Launch both agents in parallel:

```
# Security Review (blocking on CRITICAL/HIGH)
Task(
  subagent_type: "product-planning:security-analyst",
  prompt: """
    Review architecture for security vulnerabilities.

    Artifacts:
    - {FEATURE_DIR}/design.md
    - {FEATURE_DIR}/plan.md

    Apply STRIDE methodology.
    Flag CRITICAL/HIGH findings as blocking.
  """,
  description: "Security review"
)

# Simplicity Review (advisory)
Task(
  subagent_type: "product-planning:simplicity-reviewer",
  prompt: """
    Review plan for unnecessary complexity.

    Artifacts:
    - {FEATURE_DIR}/design.md
    - {FEATURE_DIR}/plan.md

    Identify over-engineering opportunities.
    All findings are advisory.
  """,
  description: "Simplicity review"
)
```

## Step 6b.2: Consolidate Findings

```
security_findings = parse security-analyst output
simplicity_findings = parse simplicity-reviewer output
```

## Step 6b.3: Handle Blocking Findings

```
IF any security_findings.severity in {CRITICAL, HIGH}:
  SET status: needs-user-input
  SET block_reason: """
    BLOCKING SECURITY FINDINGS:
    {list of CRITICAL/HIGH findings}

    User must acknowledge these security risks to proceed.
    Options:
    1. Acknowledge risks and proceed
    2. Return to Phase 4 with security constraints
    3. Abort planning
  """
```

## Step 6b.4: Report Advisory Findings

Include simplicity opportunities in the summary's "Context for Next Phase" section so the orchestrator can present them to the user.

## Step 6b.5: Write Expert Review Report

```
OUTPUT:
  Write {FEATURE_DIR}/analysis/expert-review.md with:
  - Security findings (severity, description, recommendation)
  - Simplicity opportunities (description, effort, impact)
  - Combined assessment

UPDATE state:
  expert_review = {
    security: {status, findings_count, blocking_count},
    simplicity: {opportunities_count, applied}
  }
```

**Checkpoint: EXPERT_REVIEW** (only if A4 enabled)
