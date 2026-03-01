# CLI Dispatch Patterns

> Parameterized execution patterns for tri-CLI dispatch integration points in the Feature Specify workflow.
> Referenced by Stage 2 (Challenge), Stage 4 (EdgeCases, Triangulation), Stage 5 (Evaluation).
>
> Replaces: `thinkdeep-patterns.md` (PAL MCP ThinkDeep).
> Script: `$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh`
> Config: `$CLAUDE_PLUGIN_ROOT/config/cli_dispatch` in `specify-config.yaml`

---

## Pattern: Tri-CLI Parallel Dispatch

This pattern is used at 4 integration points. Each follows the same structure but with different parameters.

### Execution Template

```
FOR EACH cli IN integration.models:
    WRITE prompt file:
        Path: specs/{FEATURE_DIR}/analysis/cli-prompts/{INTEGRATION}-{CLI}.md
        Content:
            "# {INTEGRATION_NAME} Analysis\n\n"
            "{ANALYSIS_PROMPT}\n\n"
            "## Spec Content\n\n{SPEC_CONTENT}"

    RUN via Bash():
        $CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
          --cli {cli.name} \
          --role {cli.role} \
          --prompt-file specs/{FEATURE_DIR}/analysis/cli-prompts/{INTEGRATION}-{CLI}.md \
          --output-file specs/{FEATURE_DIR}/analysis/cli-outputs/{INTEGRATION}-{CLI}.md \
          --timeout {integration.timeout_seconds} \
          --expected-fields "{expected_fields}"

    EXIT CODES:
        0 = success
        1 = CLI failure (retry up to max_attempts)
        2 = timeout (retry up to max_attempts)
        3 = CLI not found (no retry — CLI unavailable)
        4 = parse failure (content captured, but no structured output)

    CAPTURE: output = read specs/{FEATURE_DIR}/analysis/cli-outputs/{INTEGRATION}-{CLI}.md

SYNTHESIZE:
    CALL Task(subagent_type="general-purpose", model="sonnet") with:
        inputs: [all captured outputs from CLIs that succeeded]
        strategy: union_with_dedup (for analysis) or weighted_score (for evaluation)
        dedup_scheme: DUPLICATE/RELATED/UNIQUE (see Semantic Deduplication below)
        read_order: shortest output first (Least-to-Most protocol)
        Output: merged findings written to specs/{FEATURE_DIR}/analysis/{output_file}

    POST-SYNTHESIS VALIDATION:
        Count findings in merged output
        IF finding_count == 0 AND any CLI succeeded: flag as synthesis error, re-run
        IF finding_count > (sum of input findings): flag as hallucination, re-run

    NOTE: Integration 3 (Triangulation) uses model="haiku" — its synthesis is simpler
    (question dedup only, no severity analysis). All other integrations use sonnet.
```

### Least-to-Most Synthesis Protocol

When synthesizing CLI outputs, read shortest output first to build a baseline, then layer unique findings from each subsequent output. This prevents anchoring on the first-read model's framing.

### Semantic Deduplication Scheme

Replace numeric similarity thresholds with a categorical classification:

| Classification | Criteria | Action |
|---------------|----------|--------|
| **DUPLICATE** | Same finding, same recommendation, different wording | Merge: keep the more detailed version |
| **RELATED** | Same topic area but different aspects or recommendations | Keep both, group under shared heading |
| **UNIQUE** | No counterpart in other CLI outputs | Keep as-is |

Apply this scheme in all synthesis steps. The synthesis agent classifies each pair, then merges DUPLICATEs and groups RELATEDs.

### CLI Failure Handling

```
IF exit_code == 3 (CLI not found):
    LOG to model_failures: {cli, exit_code: 3, action: "skipped — CLI not in PATH"}
    DO NOT retry
    CONTINUE with remaining CLIs

IF exit_code IN [1, 2] (CLI failure or timeout):
    RETRY up to max_attempts (from config cli_dispatch.retry.max_attempts)
    IF still failing after retries:
        LOG to model_failures: {cli, exit_code, action: "skipped after retry"}
        CONTINUE with remaining CLIs

IF exit_code == 4 (parse failure):
    LOG to model_failures: {cli, exit_code: 4, note: "raw output captured"}
    INCLUDE raw output in synthesis (best-effort)
    CONTINUE

IF all CLIs fail:
    IF circuit_breaker.skip_on_all_fail (true):
        SKIP this integration point
        PROCEED with internal reasoning
        LOG: "CLI dispatch skipped — all CLIs failed"
    ELSE:
        SET status = needs-user-input
```

---

## Integration 1: Challenge (Stage 2)

**Config path:** `cli_dispatch.integrations.challenge`
**Trigger:** After BA spec draft, before Gate 1
**Purpose:** Challenge problem framing assumptions from 3 independent perspectives

### CLI Assignments

| CLI | Role | Focus |
|-----|------|-------|
| codex | `spec_root_cause` | Root cause vs symptoms, logical flaws in problem framing |
| gemini | `spec_alt_framing` | Alternative interpretations, adjacent problems, cross-domain patterns |
| opencode | `spec_assumption_probe` | Challenges user behavior assumptions, devil's advocate case |

### Analysis Prompt Template

```
Analyze this feature specification for problem framing quality:

1. Are the stated assumptions valid? Challenge each one.
2. Is the problem statement addressing root cause or symptoms?
3. Are there alternative interpretations of the user need?
4. What implicit assumptions might be wrong?
5. What market/competitive factors could invalidate this approach?

Feature: {FEATURE_NAME}
User Input: {USER_INPUT}
Spec sections: Problem Statement, True Need, JTBD
```

Append full spec content after the prompt (inline, no file paths).

### Synthesis Output

```markdown
## MPA-Challenge Synthesis

### Cross-Model Agreement
| Finding | Codex | Gemini | OpenCode | Risk Level |
|---------|-------|--------|----------|------------|
| {finding} | {agree/disagree} | ... | ... | {GREEN/YELLOW/RED} |

### Risk Assessment
- Overall Risk: {GREEN | YELLOW | RED}
- Assumptions challenged: {N}
- Alternative interpretations: {N}
- Critical findings (require user review): {N}

### Findings by CLI
#### Codex (GPT-4o) — Root Cause Analysis
{findings}
#### Gemini (Gemini Pro) — Alternative Framings
{findings}
#### OpenCode (Grok) — Assumption Probe
{findings}
```

### RED Flag Workflow

If overall risk is RED:
- Coordinator signals `needs-user-input`
- Present challenge findings with options:
  - "Revise problem framing" → re-invoke BA with findings
  - "Acknowledge and proceed" → proceed with noted risks
  - "Reject findings" → proceed without changes

### Report Output

Write to: `specs/{FEATURE_DIR}/analysis/mpa-challenge-parallel.md`

---

## Integration 2: Edge Cases (Stage 4)

**Config path:** `cli_dispatch.integrations.edge_cases`
**Trigger:** After checklist validation, before clarification
**Purpose:** Mine edge cases across security/performance, UX, and accessibility dimensions

### CLI Assignments

| CLI | Role | Focus |
|-----|------|-------|
| codex | `edge_technical_quality` | Security vulnerabilities, performance bottlenecks, data integrity, boundary conditions, scalability degradation (10x load behavior, p95/p99 latency, rate limits), external dependency failures |
| gemini | `edge_ux_coverage` | Missing UI states, incomplete flows, user error recovery, multi-context gaps; UX manifestations of infrastructure failures (error messages, degraded-mode UI, fallback experiences during outages or rollbacks) |
| opencode | `edge_ops_compliance` | Accessibility (a11y), i18n/l10n, adversarial use, non-standard users, deployment rollback scenarios (schema reversibility, blast radius), compliance & privacy obligations (GDPR/CCPA, PII classification, audit trail) |

### Analysis Prompt Template

```
Analyze this specification for edge cases and failure modes:

1. What happens when things go wrong? (error states, timeouts, failures)
2. What boundary conditions exist? (limits, extremes, empty states)
3. What security vulnerabilities could exist?
4. What performance bottlenecks are likely?
5. What accessibility issues might arise?
6. What i18n/l10n considerations are missing?
7. What concurrency or race conditions could occur?
8. What happens when load increases 10x? Where do p95/p99 latencies degrade first?
9. What external dependencies could fail? How does the system behave when each is unavailable or slow?
10. Is the deployment reversible? What breaks if a rollback is needed mid-migration?
11. What PII or sensitive data is involved? Which compliance obligations (GDPR, CCPA) apply?

Feature: {FEATURE_NAME}
Spec: {SPEC_CONTENT_SUMMARY}
Checklist gaps: {GAPS_FROM_STAGE_3}
```

### Severity Boost Protocol

Cross-CLI agreement boosts severity:
- 2 CLIs agree on same edge case: MEDIUM → HIGH
- 3 CLIs agree: HIGH → CRITICAL

### Auto-Injection to Clarification

CRITICAL and HIGH severity edge cases are automatically converted to clarification questions:

```
FOR EACH edge_case WHERE severity IN [CRITICAL, HIGH]:
    CREATE clarification question:
        question: "How should the system handle: {edge_case.description}?"
        context: "Identified by {N} models as {severity} severity"
        source: "MPA-EdgeCases"
```

### Report Output

Write to: `specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md`

---

## Integration 3: Triangulation (Stage 4)

**Config path:** `cli_dispatch.integrations.triangulation`
**Trigger:** After BA clarification questions generated, before user answers
**Purpose:** Generate additional questions from 3 independent cross-cutting perspectives

### CLI Assignments

| CLI | Role | Focus |
|-----|------|-------|
| codex | `spec_q_technical` | Technical product gaps, integration/dependency questions |
| gemini | `spec_q_coverage` | Missing requirements, underrepresented stakeholders, NFR gaps |
| opencode | `spec_q_contrarian` | Premise challenges, scope challenges, uncomfortable questions |

### Analysis Prompt Template

```
Review this specification and existing clarification questions.
Generate 2-4 ADDITIONAL questions that are NOT covered by existing ones:

Existing questions: {EXISTING_QUESTION_LIST}
Spec: {SPEC_CONTENT_SUMMARY}
Edge cases found: {EDGE_CASE_SUMMARY}

Focus on questions that:
- Challenge scope boundaries
- Probe undefined behavior
- Question implicit requirements
- Explore cross-cutting concerns
```

### Semantic Deduplication

Apply the DUPLICATE/RELATED/UNIQUE classification scheme (see Execution Template above):

```
FOR EACH new_question FROM CLIs:
    CLASSIFY against existing_questions:
        DUPLICATE → discard (same question, different wording)
        RELATED  → keep (same topic but probes a different aspect)
        UNIQUE   → keep (no counterpart in existing questions)

PRIORITY BOOST:
    All 3 CLIs agree (BA + all CLIs) → CRITICAL
    2 CLIs agree → HIGH
    1 CLI only → MEDIUM
```

### Report Output

Write to: `specs/{FEATURE_DIR}/analysis/mpa-triangulation.md`

---

## Integration 4: Evaluation (Stage 5)

**Config path:** `cli_dispatch.integrations.evaluation`
**Trigger:** After spec is finalized (post-clarification), before design artifact generation
**Purpose:** Multi-stance evaluation of spec quality

### CLI Assignments

| CLI | Role | Stance | Purpose |
|-----|------|--------|---------|
| gemini | `spec_evaluator_neutral` | neutral | Objective evidence-based assessment |
| codex | `spec_evaluator_for` | advocate | Articulate genuine strengths (forced stance) |
| opencode | `spec_evaluator_against` | challenger | Surface every weakness and gap |

### Dispatch Order (Fully Parallel)

All 3 CLI evaluations run in parallel. The Least-to-Most synthesis protocol (reading shortest output first) prevents anchoring bias during synthesis.

```bash
# Run all 3 evaluators in parallel
$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
  --cli gemini --role spec_evaluator_neutral \
  --prompt-file specs/{FEATURE_DIR}/analysis/cli-prompts/evaluation-gemini.md \
  --output-file specs/{FEATURE_DIR}/analysis/cli-outputs/evaluation-gemini.md \
  --timeout 120 &

$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
  --cli codex --role spec_evaluator_for \
  --prompt-file specs/{FEATURE_DIR}/analysis/cli-prompts/evaluation-codex.md \
  --output-file specs/{FEATURE_DIR}/analysis/cli-outputs/evaluation-codex.md \
  --timeout 120 &

$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
  --cli opencode --role spec_evaluator_against \
  --prompt-file specs/{FEATURE_DIR}/analysis/cli-prompts/evaluation-opencode.md \
  --output-file specs/{FEATURE_DIR}/analysis/cli-outputs/evaluation-opencode.md \
  --timeout 120 &

wait  # collect all results
```

### Content Delivery (CRITICAL)

External CLIs cannot access local files. Spec content MUST be embedded inline in the prompt file.

```
READ specs/{FEATURE_DIR}/spec.md
COUNT words

IF word_count <= 4000:
    SET eval_content = full spec content
ELSE:
    GENERATE structured summary:
        - Problem statement (full)
        - User stories with acceptance criteria (full)
        - NFRs (full)
        - Scope boundaries (full)
        - Technical constraints (summarized)
        - Appendices (omitted, note: "Detailed appendices omitted for brevity")
    SET eval_content = structured summary
```

### Scoring

Each CLI evaluates 5 dimensions (4 pts each, 20 total):
1. Business value clarity
2. Requirements completeness
3. Scope boundaries
4. Stakeholder coverage
5. Technology agnosticism

**Aggregate score** = average of substantive responses (excluding non-substantive ones).

| Score | Decision | Action |
|-------|----------|--------|
| >= 16/20 | APPROVED | Proceed to design artifacts |
| 12-15/20 | CONDITIONAL | Proceed with warnings noted |
| < 12/20 | REJECTED | Retry loop (max 2) |

**If < 2 substantive responses:** Signal `needs-user-input` (NEVER self-assess).

### Substantive Response Validation

Exclude responses that match these patterns:
- Response length < 50 words
- All 5 dimension scores are identical
- Contains "cannot access" / "file not found" / "unable to read" / "no file provided"

### Synthesis Output

```markdown
## Specification Evaluation — Multi-Stance Assessment

### Aggregated Dimension Scores
| Dimension | Gemini (Neutral) | Codex (Advocate) | OpenCode (Challenger) | Avg |
|-----------|-----------------|------------------|----------------------|-----|
| Business value clarity | {X}/4 | {X}/4 | {X}/4 | {X}/4 |
| Requirements completeness | {X}/4 | {X}/4 | {X}/4 | {X}/4 |
| Scope boundaries | {X}/4 | {X}/4 | {X}/4 | {X}/4 |
| Stakeholder coverage | {X}/4 | {X}/4 | {X}/4 | {X}/4 |
| Technology agnosticism | {X}/4 | {X}/4 | {X}/4 | {X}/4 |
| **TOTAL** | **{X}/20** | **{X}/20** | **{X}/20** | **{X}/20** |

### Decision: {APPROVED | CONDITIONAL | REJECTED}
**Aggregate score:** {X}/20

### Key Findings
**Strengths (from Advocate):** {top 3}
**Weaknesses (from Challenger):** {top 3}
**Neutral assessment:** {1 paragraph}
```

### Report Output

Write to: `specs/{FEATURE_DIR}/analysis/mpa-evaluation.md`
