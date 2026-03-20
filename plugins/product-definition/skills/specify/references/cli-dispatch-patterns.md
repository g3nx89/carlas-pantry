# CLI Dispatch Patterns

> Parameterized execution patterns for dual-CLI parallel dispatch via ntm (Named Tmux Manager).
> Referenced by Stage 2 (Challenge), Stage 4A (EdgeCases), Stage 4B (Triangulation), Stage 5 (Evaluation).
>
> Replaces: `dispatch-cli-agent.sh` (synchronous one-shot Bash dispatch).
> Script: `$CLAUDE_PLUGIN_ROOT/scripts/dispatch-via-ntm.sh`
> Config: CLI integration definitions and operational constants in `$CLAUDE_PLUGIN_ROOT/config/specify-profile-definitions.yaml`

> **ANTI-PATTERN — DO NOT USE `ask` OR DIRECT CLI INVOCATION:**
> The `ask` command (CCB async dispatch) has no stage/integration scoping — stale results
> from a previous stage may be returned. Direct CLI invocation via `Bash()` bypasses
> ntm session management (no parallel execution, no output capture, no metrics).
> ALWAYS use `dispatch-via-ntm.sh` which manages the full ntm lifecycle.

---

## CLI Critical Rules

These rules apply to ALL CLI dispatch points in the workflow (Stages 2, 4A, 4B, 5). They are the authoritative source — stage files reference this section rather than duplicating.

1. **Evaluation Minimum**: Evaluation (Integration 4, Stage 5) requires **minimum 2 substantive responses**. If < 2 → signal `needs-user-input` (NEVER self-assess).
2. **No CLI Substitution**: If a CLI dispatch fails, **DO NOT** substitute with another CLI. Dual-CLI dispatch is for variety — substituting defeats the purpose.
3. **Spec Content Inline**: ALWAYS embed spec content inline in prompt files. External CLIs process the prompt text directly — they do not read local file paths.
4. **User Notification MANDATORY**: When ANY CLI fails or is unavailable, **ALWAYS** notify user via summary context.
5. **ntm Availability Check**: Before dispatching, verify `ntm` is in PATH and at least one CLI binary (`codex`, `gemini`) is available. Stage 1 records this in `NTM_AVAILABLE` and per-CLI availability flags.
6. **Fallback Behavior**: If ntm or all CLIs are unavailable, skip Challenge, EdgeCases, Triangulation, and Evaluation steps — proceed with internal reasoning (see `error-handling.md` → Graceful Degradation).

---

## Pattern: Dual-CLI Parallel Dispatch via ntm

This pattern is used at 4 integration points. Each follows the same structure but with different parameters. Both CLIs run in parallel within a single ntm tmux session.

### Execution Template

```
STEP 1 — Write prompt files:
    FOR EACH cli IN integration.models:
        WRITE prompt file:
            Path: specs/{FEATURE_DIR}/analysis/cli-prompts/{INTEGRATION}-{CLI}.md
            Content:
                "# {INTEGRATION_NAME} Analysis\n\n"
                "{ROLE_SYSTEM_PROMPT}\n\n"
                "{ANALYSIS_PROMPT}\n\n"
                "## Spec Content\n\n{SPEC_CONTENT}"

        NOTE: Role system prompts are in $CLAUDE_PLUGIN_ROOT/config/cli_clients/{CLI}_{ROLE}.txt
        Read the role prompt file and prepend it to the analysis prompt.

STEP 2 — Dispatch via ntm (SINGLE Bash() call):
    RUN via Bash():
        $CLAUDE_PLUGIN_ROOT/scripts/dispatch-via-ntm.sh \
          --session "specify-{FEATURE_ID}-{INTEGRATION}" \
          --dispatch "codex:{CODEX_ROLE}:specs/{FEATURE_DIR}/analysis/cli-prompts/{INTEGRATION}-codex.md:specs/{FEATURE_DIR}/analysis/cli-outputs/{INTEGRATION}-codex.md" \
          --dispatch "gemini:{GEMINI_ROLE}:specs/{FEATURE_DIR}/analysis/cli-prompts/{INTEGRATION}-gemini.md:specs/{FEATURE_DIR}/analysis/cli-outputs/{INTEGRATION}-gemini.md" \
          --timeout {integration.timeout_seconds * CLI_TIMEOUT_MULTIPLIER}

    EXIT CODES:
        0 = all CLIs produced SUMMARY output
        1 = partial failure (some CLIs produced no output)
        2 = timeout (polling expired before all SUMMARY blocks detected)
        3 = ntm not found or prerequisite failure (no retry)
        4 = invalid arguments
        5 = ntm spawn failed (session could not be created)

    CAPTURE:
        codex_output = read specs/{FEATURE_DIR}/analysis/cli-outputs/{INTEGRATION}-codex.md
        gemini_output = read specs/{FEATURE_DIR}/analysis/cli-outputs/{INTEGRATION}-gemini.md

STEP 3 — Synthesize:
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

### Key Differences from Legacy Script

| Aspect | Legacy (`dispatch-cli-agent.sh`) | ntm (`dispatch-via-ntm.sh`) |
|--------|----------------------------------|----------------------------|
| Parallelism | Sequential (1 Bash() per CLI) | True parallel (1 Bash() for all CLIs) |
| Output capture | stdout pipe + 4-tier extraction | ntm pane copy + SUMMARY block extraction |
| Visibility | None (silent file capture) | `ntm attach` / `ntm dashboard` |
| Process management | setsid + timeout --kill-after | ntm tmux session lifecycle |
| Completion detection | Exit code only | SUMMARY block polling + timeout |

### Least-to-Most Synthesis Protocol

When synthesizing CLI outputs, read shortest output first to build a baseline, then layer unique findings from each subsequent output. This prevents anchoring on the first-read model's framing.

### Semantic Deduplication Scheme

| Classification | Criteria | Action |
|---------------|----------|--------|
| **DUPLICATE** | Same finding, same recommendation, different wording | Merge: keep the more detailed version |
| **RELATED** | Same topic area but different aspects or recommendations | Keep both, group under shared heading |
| **UNIQUE** | No counterpart in other CLI outputs | Keep as-is |

Apply this scheme in all synthesis steps. The synthesis agent classifies each pair, then merges DUPLICATEs and groups RELATEDs.

### CLI Failure Handling

```
IF exit_code == 3 (ntm not found):
    LOG to model_failures: {integration, exit_code: 3, action: "skipped — ntm not in PATH"}
    DO NOT retry
    SKIP this integration point
    PROCEED with internal reasoning

IF exit_code == 1 (partial failure):
    READ output files — some CLIs may have produced valid output
    INCLUDE valid outputs in synthesis (best-effort with available data)
    LOG failed CLIs to model_failures

IF exit_code == 2 (timeout):
    READ output files — CLIs may have produced partial output before timeout
    IF any output file has SUMMARY block content: include in synthesis
    IF no usable output: treat as all-fail (see below)

IF exit_code == 4 (bad arguments):
    LOG as coordinator error — check prompt file paths and session naming
    DO NOT retry (fix the coordinator logic)

IF exit_code == 5 (spawn failed):
    LOG to model_failures: {integration, exit_code: 5, action: "ntm session creation failed"}
    RETRY up to 1 attempt (transient tmux issue)
    IF still failing: SKIP this integration point, proceed with internal reasoning

IF all CLIs fail (no usable output):
    IF circuit_breaker.skip_on_all_fail (true):
        SKIP this integration point
        PROCEED with internal reasoning
        LOG: "CLI dispatch skipped — all CLIs failed"
    ELSE:
        SET status = needs-user-input
```

### Retry Protocol

The ntm dispatch script does NOT retry internally. If the coordinator needs a retry:

```
IF exit_code IN [1, 2] AND retry_count < 2:
    INCREMENT retry_count
    RE-RUN dispatch-via-ntm.sh with same parameters
    (ntm defensive cleanup kills stale sessions automatically)
```

---

## Integration 1: Challenge (Stage 2)

**Config path:** `cli_integrations.challenge` in `specify-profile-definitions.yaml`
**Trigger:** After BA spec draft, before Gate 1
**Purpose:** Challenge problem framing assumptions from 2 independent perspectives

### CLI Assignments

| CLI | Role | Focus |
|-----|------|-------|
| codex | `spec_root_cause` | Root cause vs symptoms, logical flaws in problem framing |
| gemini | `spec_alt_framing` | Alternative interpretations, adjacent problems, cross-domain patterns |

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

### Dispatch Example

```bash
$CLAUDE_PLUGIN_ROOT/scripts/dispatch-via-ntm.sh \
  --session "specify-{FEATURE_ID}-challenge" \
  --dispatch "codex:spec_root_cause:specs/{FD}/analysis/cli-prompts/challenge-codex.md:specs/{FD}/analysis/cli-outputs/challenge-codex.md" \
  --dispatch "gemini:spec_alt_framing:specs/{FD}/analysis/cli-prompts/challenge-gemini.md:specs/{FD}/analysis/cli-outputs/challenge-gemini.md" \
  --timeout 120
```

### Synthesis Output

```markdown
## MPA-Challenge Synthesis

### Cross-Model Agreement
| Finding | Codex | Gemini | Risk Level |
|---------|-------|--------|------------|
| {finding} | {agree/disagree} | ... | {GREEN/YELLOW/RED} |

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

**Config path:** `cli_integrations.edge_cases` in `specify-profile-definitions.yaml`
**Trigger:** After checklist validation, before clarification
**Purpose:** Mine edge cases across technical quality and UX coverage dimensions

### CLI Assignments

| CLI | Role | Focus |
|-----|------|-------|
| codex | `edge_technical_quality` | Security vulnerabilities, performance bottlenecks, data integrity, boundary conditions, scalability degradation (10x load behavior, p95/p99 latency, rate limits), external dependency failures, deployment rollback scenarios, compliance & privacy (GDPR/CCPA, PII) |
| gemini | `edge_ux_coverage` | Missing UI states, incomplete flows, user error recovery, multi-context gaps; accessibility (a11y), i18n/l10n, adversarial use, non-standard users; UX manifestations of infrastructure failures (error messages, degraded-mode UI, fallback experiences) |

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

**Config path:** `cli_integrations.triangulation` in `specify-profile-definitions.yaml`
**Trigger:** After BA clarification questions generated, before user answers
**Purpose:** Generate additional questions from 2 independent cross-cutting perspectives

### CLI Assignments

| CLI | Role | Focus |
|-----|------|-------|
| codex | `spec_q_technical` | Technical product gaps, integration/dependency questions |
| gemini | `spec_q_coverage` | Missing requirements, underrepresented stakeholders, NFR gaps, premise challenges, scope challenges |

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
    Both CLIs agree (BA + both CLIs) → CRITICAL
    1 CLI only → HIGH
```

### Report Output

Write to: `specs/{FEATURE_DIR}/analysis/mpa-triangulation.md`

---

## Integration 4: Evaluation (Stage 5)

**Config path:** `cli_integrations.evaluation` in `specify-profile-definitions.yaml`
**Trigger:** After spec is finalized (post-clarification), before design artifact generation
**Purpose:** Dual-stance evaluation of spec quality

### CLI Assignments

| CLI | Role | Stance | Purpose |
|-----|------|--------|---------|
| gemini | `spec_evaluator_neutral` | neutral | Objective evidence-based assessment |
| codex | `spec_evaluator_for` | advocate | Articulate genuine strengths (forced stance) |

### Dispatch (Single Bash() Call)

Both evaluations run in parallel within one ntm session:

```bash
$CLAUDE_PLUGIN_ROOT/scripts/dispatch-via-ntm.sh \
  --session "specify-{FEATURE_ID}-evaluation" \
  --dispatch "gemini:spec_evaluator_neutral:specs/{FD}/analysis/cli-prompts/evaluation-gemini.md:specs/{FD}/analysis/cli-outputs/evaluation-gemini.md" \
  --dispatch "codex:spec_evaluator_for:specs/{FD}/analysis/cli-prompts/evaluation-codex.md:specs/{FD}/analysis/cli-outputs/evaluation-codex.md" \
  --timeout 120
```

### Content Delivery (CRITICAL)

Spec content MUST be embedded inline in the prompt file.

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
## Specification Evaluation — Dual-Stance Assessment

### Aggregated Dimension Scores
| Dimension | Gemini (Neutral) | Codex (Advocate) | Avg |
|-----------|-----------------|------------------|-----|
| Business value clarity | {X}/4 | {X}/4 | {X}/4 |
| Requirements completeness | {X}/4 | {X}/4 | {X}/4 |
| Scope boundaries | {X}/4 | {X}/4 | {X}/4 |
| Stakeholder coverage | {X}/4 | {X}/4 | {X}/4 |
| Technology agnosticism | {X}/4 | {X}/4 | {X}/4 |
| **TOTAL** | **{X}/20** | **{X}/20** | **{X}/20** |

### Decision: {APPROVED | CONDITIONAL | REJECTED}
**Aggregate score:** {X}/20

### Key Findings
**Strengths (from Advocate):** {top 3}
**Neutral assessment:** {1 paragraph}
```

### Report Output

Write to: `specs/{FEATURE_DIR}/analysis/mpa-evaluation.md`
