---
phase: "6b"
phase_name: "Expert Review"
checkpoint: "EXPERT_REVIEW"
delegation: "coordinator"
modes: [complete, advanced]
prior_summaries:
  - ".phase-summaries/phase-6-summary.md"
artifacts_read:
  - "spec.md"          # requirements context: data types, compliance requirements, user-facing operations
  - "design.md"
  - "plan.md"
artifacts_written:
  - "analysis/expert-review.md"
  - "analysis/cli-security-report.md"  # conditional: CLI dispatch enabled
  - ".phase-summaries/phase-6b-skill-context.md"  # conditional: dev_skills_integration enabled
agents:
  - "product-planning:security-analyst"
  - "product-planning:simplicity-reviewer"
mcp_tools: []
feature_flags:
  - "a4_expert_review"
  - "cli_context_isolation"
  - "cli_custom_roles"
  - "dev_skills_integration"
  - "deep_reasoning_escalation"
  - "s13_confidence_gated_review"  # orchestrator may offer security deep dive after this phase
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/skill-loader-pattern.md"
---

<!-- Mode Applicability -->
| Step | Rapid | Standard | Advanced | Complete | Notes |
|------|-------|----------|----------|----------|-------|
| 6b.1 | —     | —        | ✓        | ✓        | `(dev_skills_integration)` |
| 6b.2 | —     | —        | ✓        | ✓        | `(a4_expert_review)` |
| 6b.3 | —     | —        | ✓        | ✓        | CLI security audit |
| 6b.4 | —     | —        | ✓        | ✓        | `(s13_confidence_gated_review)` for filtering |
| 6b.5 | —     | —        | ✓        | ✓        | `(s13_confidence_gated_review)` for tri-state |
| 6b.6 | —     | —        | ✓        | ✓        | `(deep_reasoning_escalation)` |
| 6b.7 | —     | —        | ✓        | ✓        | — |
| 6b.8 | —     | —        | ✓        | ✓        | — |

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

## Decision Protocol
When `a6_context_protocol` is enabled (check feature flags):
1. **RESPECT** all prior key decisions — do not contradict HIGH-confidence decisions without explicit justification.
2. **CHECK** open questions — if your analysis resolves any, include the resolution in your `key_decisions`.
3. **CONTRIBUTE** your findings as `key_decisions`, `open_questions`, and `risks_identified` in your phase summary YAML.

**Purpose:** Qualitative expert review of architecture and plan.

**Prerequisite:** Feature flag `a4_expert_review` must be enabled AND analysis_mode in {advanced, complete}.

## Step 6b.1: Dev-Skills Context Loading [IF dev_skills_integration]

**Purpose:** Load clean-code principles and API security patterns before launching expert review agents.

**Reference:** `$CLAUDE_PLUGIN_ROOT/skills/plan/references/skill-loader-pattern.md`

```
IF state.dev_skills.available AND analysis_mode != "rapid":

  DISPATCH Task(subagent_type="general-purpose", prompt="""
    You are a skill context loader for Phase 6b (Expert Review).

    Detected domains: {state.dev_skills.detected_domains}
    Technology markers: {state.dev_skills.technology_markers}

    Load the following skills and extract ONLY the specified sections:

    1. Skill("dev-skills:clean-code") → extract:
       - Core principles (SRP, DRY, KISS, YAGNI)
       - Anti-patterns table with fixes
       - Function rules (max lines, arguments)
       LIMIT: 1000 tokens

    2. IF feature has API components (check technology_markers for api, rest, graphql):
       Skill("dev-skills:api-patterns") → extract:
         - OWASP API Top 10 security testing section
       LIMIT: 800 tokens

    WRITE condensed output to: {FEATURE_DIR}/.phase-summaries/phase-6b-skill-context.md
    FORMAT: YAML frontmatter + markdown sections per skill
    TOTAL BUDGET: 2000 tokens max
    IF any Skill() call fails → log in skills_failed, continue with remaining
  """)

  READ {FEATURE_DIR}/.phase-summaries/phase-6b-skill-context.md
  IF file exists AND not empty:
    INJECT clean-code section into simplicity-reviewer prompt (Step 6b.2)
    INJECT api-security section into security-analyst prompt (Step 6b.2)
```

## Step 6b.2: Launch Expert Review Agents [PARALLEL]

Launch both agents in parallel:

```
# Prefer requirements-anchor.md (consolidates spec + user clarifications from Phase 3)
# Fall back to raw spec.md if anchor not available or empty
IF file_exists({FEATURE_DIR}/requirements-anchor.md) AND not_empty({FEATURE_DIR}/requirements-anchor.md):
  requirements_file = "{FEATURE_DIR}/requirements-anchor.md"
  LOG: "Requirements context: using requirements-anchor.md (enriched)"
ELSE:
  requirements_file = "{FEATURE_DIR}/spec.md"
  LOG: "Requirements context: using spec.md (raw)"

# Security Review (blocking on CRITICAL/HIGH)
Task(
  subagent_type: "product-planning:security-analyst",
  prompt: """
    Review architecture for security vulnerabilities.

    Artifacts:
    - {requirements_file}  (requirements: data types processed, compliance needs, user-facing operations)
    - {FEATURE_DIR}/design.md
    - {FEATURE_DIR}/plan.md

    Apply STRIDE methodology.
    Use requirements to identify: what data is processed (PII, financial, health),
    what compliance requirements exist (GDPR, HIPAA, SOC2), and what user-facing
    operations need protection (auth, payments, data export).
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
    - {requirements_file}  (requirements: acceptance criteria, scope boundaries)
    - {FEATURE_DIR}/design.md
    - {FEATURE_DIR}/plan.md

    Use requirements to assess whether architectural complexity is justified
    by actual acceptance criteria. Flag components that exceed what the
    requirements demand.
    Identify over-engineering opportunities.
    All findings are advisory.
  """,
  description: "Simplicity review"
)
```

## Step 6b.3: CLI Security Audit [IF cli_context_isolation]

**Purpose:** Supplement standard security review with CLI multi-CLI security analysis. Standard agents STILL run in parallel — CLI dispatch adds breadth.

Follow the **CLI Multi-CLI Dispatch Pattern** from `$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md` with these parameters:

| Parameter | Value |
|-----------|-------|
| ROLE | `securityauditor` |
| PHASE_STEP | `6b.3` |
| MODE_CHECK | `analysis_mode in {complete, advanced}` |
| GEMINI_PROMPT | `Architectural security and supply chain review for feature: {FEATURE_NAME}. Spec: {FEATURE_DIR}/spec.md. Design: {FEATURE_DIR}/design.md. Plan: {FEATURE_DIR}/plan.md. Focus: Supply chain security, trust boundaries, compliance patterns. Cross-check against compliance requirements in spec.md.` |
| CODEX_PROMPT | `OWASP code-level security audit for feature: {FEATURE_NAME}. Spec: {FEATURE_DIR}/spec.md. Design: {FEATURE_DIR}/design.md. Plan: {FEATURE_DIR}/plan.md. Focus: Injection points, hardcoded secrets, auth implementation flaws. Check data types from spec.md for sensitive data handling.` |
| OPENCODE_PROMPT | `Privacy and security UX review for feature: {FEATURE_NAME}. Spec: {FEATURE_DIR}/spec.md. Design: {FEATURE_DIR}/design.md. Plan: {FEATURE_DIR}/plan.md. Focus: Consent flows, PII handling, auth flow usability, error message information leakage, data rights (access/deletion). Validate against user stories in spec.md.` |
| FILE_PATHS | `["{FEATURE_DIR}/spec.md", "{FEATURE_DIR}/design.md", "{FEATURE_DIR}/plan.md"]` |
| REPORT_FILE | `analysis/cli-security-report.md` |
| PREFERRED_SINGLE_CLI | `codex` |
| POST_WRITE | `Merge CLI security findings with standard agent findings in Step 6b.4` |

## Step 6b.4: Consolidate Findings

```
security_findings = parse security-analyst output
simplicity_findings = parse simplicity-reviewer output

# Merge CLI security findings if available
IF {FEATURE_DIR}/analysis/cli-security-report.md exists:
  cli_security = parse cli-security-report.md
  MERGE cli_security into security_findings (deduplicate by finding description)

# S9: Confidence filtering (s13_confidence_gated_review)
IF feature_flags.s13_confidence_gated_review.enabled:
  threshold = config.expert_review.confidence_threshold  # default 80
  high_confidence_findings = FILTER(security_findings, f => f.confidence >= threshold)
  low_confidence_findings = FILTER(security_findings, f => f.confidence < threshold)
  LOG: "{len(high_confidence_findings)} findings above confidence threshold, {len(low_confidence_findings)} below"

  # Low-confidence findings become advisory regardless of severity
  FOR EACH finding IN low_confidence_findings:
    finding.original_severity = finding.severity
    finding.severity = "LOW"  # Demoted to advisory
    finding.note = "Confidence {finding.confidence} < threshold {threshold} — demoted to advisory"
```

## Step 6b.5: Handle Blocking Findings (Tri-State Outcome) [USER]

```
# S9: Tri-state outcome with iteration (s13_confidence_gated_review)
IF feature_flags.s13_confidence_gated_review.enabled:

  blocking_count = COUNT(security_findings WHERE severity IN {CRITICAL, HIGH} AND confidence >= threshold)

  IF blocking_count == 0:
    outcome = "pass"
    LOG: "Expert review: PASS — no high-confidence blocking findings"

  ELSE IF blocking_count > 0 AND all findings have mitigations:
    outcome = "pass_with_risk"
    LOG: "Expert review: PASS WITH RISK — {blocking_count} findings with mitigations documented"

  ELSE:
    outcome = "fail"
    LOG: "Expert review: FAIL — {blocking_count} unmitigated blocking findings"

    # Iteration protocol (max 2 rounds via circuit breaker)
    iteration = 1
    max_iterations = config.circuit_breaker.expert_review.max_iterations  # 2

    WHILE outcome == "fail" AND iteration <= max_iterations:
      SET status: needs-user-input
      SET block_reason: """
        BLOCKING SECURITY FINDINGS (iteration {iteration}/{max_iterations}):
        {list of CRITICAL/HIGH findings with confidence scores}

        Options:
        1. Redesign — return to Phase 4 with security constraints
        2. Override — acknowledge risks and proceed (recorded as immutable decision)
        3. Provide context — supply additional information to re-evaluate findings
      """

      ON re-dispatch with user response:
        IF user chose "Provide context":
          RE-EVALUATE findings with new context
          RE-SCORE confidence for affected findings
          RECOMPUTE blocking_count
          IF blocking_count == 0: outcome = "pass_with_risk"
        ELIF user chose "Override":
          outcome = "pass_with_risk"
          RECORD override decision as immutable
        ELIF user chose "Redesign":
          outcome = "redesign"
          # Orchestrator will loop back to Phase 4

      iteration += 1

    IF iteration > max_iterations AND outcome == "fail":
      # Circuit breaker: present final findings to user with override option
      LOG: "Expert review circuit breaker: max iterations reached"
      SET status: needs-user-input with forced Override/Redesign choice

ELSE:
  # Legacy behavior (s13 disabled)
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

## Step 6b.6: Flag Critical Count for Deep Reasoning Check

Always include the critical finding count in the phase summary, regardless of blocking status. The orchestrator uses `critical_security_count` to determine if a deep reasoning security audit should be offered (threshold: 2+ CRITICAL findings when `security_deep_dive` flag is enabled).

```
# In the phase summary YAML flags section, always write:
flags:
  critical_security_count: {count of CRITICAL severity findings from security_findings}
  high_security_count: {count of HIGH severity findings from security_findings}
  # ... existing flags (requires_user_input, block_reason, degraded, etc.)
```

> **Note:** The coordinator does NOT offer deep reasoning escalation. The orchestrator reads
> `critical_security_count` from this summary and follows the `deep-reasoning-dispatch-pattern.md`
> if the threshold is met and the `security_deep_dive` flag is enabled.

## Step 6b.7: Report Advisory Findings

Include simplicity opportunities in the summary's "Context for Next Phase" section so the orchestrator can present them to the user.

## Step 6b.8: Write Expert Review Report

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
