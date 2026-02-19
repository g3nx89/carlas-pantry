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
  - "deep_reasoning_escalation"  # orchestrator may offer security deep dive after this phase
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/skill-loader-pattern.md"
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

## Step 6b.0a: Dev-Skills Context Loading (Subagent)

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
    INJECT clean-code section into simplicity-reviewer prompt (Step 6b.1)
    INJECT api-security section into security-analyst prompt (Step 6b.1)
```

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

## Step 6b.1b: CLI Security Audit (Supplement)

**Purpose:** Supplement standard security review with CLI dual-CLI security analysis. Standard agents STILL run in parallel — CLI dispatch adds breadth.

Follow the **CLI Dual-CLI Dispatch Pattern** from `$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md` with these parameters:

| Parameter | Value |
|-----------|-------|
| ROLE | `securityauditor` |
| PHASE_STEP | `6b.1b` |
| MODE_CHECK | `analysis_mode in {complete, advanced}` |
| GEMINI_PROMPT | `Architectural security and supply chain review for feature: {FEATURE_NAME}. Design: {FEATURE_DIR}/design.md. Plan: {FEATURE_DIR}/plan.md. Focus: Supply chain security, trust boundaries, compliance patterns.` |
| CODEX_PROMPT | `OWASP code-level security audit for feature: {FEATURE_NAME}. Design: {FEATURE_DIR}/design.md. Plan: {FEATURE_DIR}/plan.md. Focus: Injection points, hardcoded secrets, auth implementation flaws.` |
| FILE_PATHS | `["{FEATURE_DIR}/design.md", "{FEATURE_DIR}/plan.md"]` |
| REPORT_FILE | `analysis/cli-security-report.md` |
| PREFERRED_SINGLE_CLI | `codex` |
| POST_WRITE | `Merge CLI security findings with standard agent findings in Step 6b.2` |

## Step 6b.2: Consolidate Findings

```
security_findings = parse security-analyst output
simplicity_findings = parse simplicity-reviewer output

# Merge CLI security findings if available
IF {FEATURE_DIR}/analysis/cli-security-report.md exists:
  cli_security = parse cli-security-report.md
  MERGE cli_security into security_findings (deduplicate by finding description)
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

## Step 6b.3b: Flag Critical Count for Deep Reasoning Check

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
