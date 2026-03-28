# CLI Dispatch Patterns

> Parameterized execution patterns for dual-CLI parallel dispatch via ntm (Named Tmux Manager).
> Referenced by Phase 5 (ThinkDeep), Phase 6 (Validation), Phase 6b (Expert Review), Phase 7 (Test Strategy), Phase 8 (Coverage), Phase 9 (Completion).
>
> **Script version:** v2.0 (robot mode) — uses `--robot-spawn`, `--robot-ack`, `--robot-metrics` for structured interaction.
> Script: `$CLAUDE_PLUGIN_ROOT/scripts/dispatch-via-ntm.sh`
> Config: CLI integration definitions in `$CLAUDE_PLUGIN_ROOT/config/planning-config.yaml`
>
> **This file is the single source of truth** for CLI operational constants (timeouts, retry logic, exit codes). `planning-config.yaml` mirrors these values for audit visibility only — coordinators NEVER read constants from there.

> **ANTI-PATTERN — DO NOT USE `ask` OR DIRECT CLI INVOCATION:**
> The `ask` command (CCB async dispatch) has no phase/integration scoping — stale results
> from a previous phase may be returned. Direct CLI invocation via `Bash()` bypasses
> ntm session management (no parallel execution, no output capture, no metrics).
> ALWAYS use `dispatch-via-ntm.sh` which manages the full ntm lifecycle.

---

## CLI Critical Rules

These rules apply to ALL CLI dispatch points in the workflow (Phases 5, 6, 6b, 7, 8, 9). They are the authoritative source — phase files reference this section rather than duplicating.

1. **Evaluation Minimum**: Consensus scoring (Phases 6, 8) requires **minimum 2 substantive responses**. If < 2 → signal `needs-user-input` (NEVER self-assess).
2. **No CLI Substitution**: If a CLI dispatch fails, **DO NOT** substitute with another CLI. Dual-CLI dispatch is for variety — substituting defeats the purpose.
3. **Plan Content Inline**: ALWAYS embed plan content inline in prompt files. External CLIs process the prompt text directly — they do not read local file paths.
4. **User Notification MANDATORY**: When ANY CLI fails or is unavailable, **ALWAYS** notify user via summary context.
5. **ntm Availability Check**: Before dispatching, verify `ntm` is in PATH and both CLI binaries (`codex`, `gemini`) are available. Phase 1 records this in `state.cli.dispatch_infrastructure.ntm_available` and per-CLI availability flags.
6. **Fallback Behavior**: If ntm or all CLIs are unavailable, fall back to `dispatch-cli-agent.sh` legacy script. If that also fails, skip CLI steps and proceed with internal reasoning (see Legacy Fallback section below).

---

## Pattern: Dual-CLI Parallel Dispatch via ntm

This pattern is used at 6 integration points (one per role). Each follows the same structure but with different parameters. Both CLIs run in parallel within a single ntm tmux session.

### Execution Template

```
STEP 1 — Write prompt files:
    FOR EACH cli IN [codex, gemini]:
        WRITE prompt file:
            Path: {FEATURE_DIR}/analysis/cli-prompts/{ROLE}-{CLI}.md
            Content:
                "# {ROLE} Analysis\n\n"
                "{ROLE_SYSTEM_PROMPT}\n\n"
                "## Analysis Task\n\n{ANALYSIS_PROMPT}\n\n"
                "## Plan Context\n\n{PLAN_CONTENT}"

        NOTE: Role system prompts are in $CLAUDE_PLUGIN_ROOT/config/cli_clients/{CLI}_{ROLE}.txt
        Read the role prompt file and prepend it to the analysis prompt.
        CRITICAL: Embed all content inline — external CLIs cannot read file paths.

STEP 2 — Dispatch via ntm robot mode (SINGLE Bash() call):
    RUN via Bash():
        $CLAUDE_PLUGIN_ROOT/scripts/dispatch-via-ntm.sh \
          --session "planning-{FEATURE_ID}-{ROLE}" \
          --dispatch "codex:{ROLE}:{FEATURE_DIR}/analysis/cli-prompts/{ROLE}-codex.md:{FEATURE_DIR}/analysis/cli-outputs/{ROLE}-codex.md" \
          --dispatch "gemini:{ROLE}:{FEATURE_DIR}/analysis/cli-prompts/{ROLE}-gemini.md:{FEATURE_DIR}/analysis/cli-outputs/{ROLE}-gemini.md" \
          --timeout {TIMEOUT}

    INTERNALS (handled by script — coordinator does NOT call these directly):
        - --robot-spawn creates session with JSON validation
        - --robot-status verifies agents reach WAITING state before sending
        - --robot-ack blocks until all agents return to WAITING (idle) or timeout
        - --robot-metrics captures native ntm metrics (tokens, velocities, durations)
        - ntm send delivers prompts (NOT --robot-send — deliberate: ntm send uses tmux
          terminal input, proven for large payloads up to 200KB; --robot-send --msg= has
          the same shell argument limit with no additional benefit for this use case)
        - ntm copy captures output post-ack for SUMMARY block extraction

    EXIT CODES:
        0 = all CLIs produced SUMMARY output
        1 = partial failure (some CLIs produced no output)
        2 = timeout (robot-ack expired before all agents idle)
        3 = ntm not found or prerequisite failure (no retry — fall back to legacy)
        4 = invalid arguments
        5 = ntm spawn failed (session could not be created)

    CAPTURE:
        codex_output = read {FEATURE_DIR}/analysis/cli-outputs/{ROLE}-codex.md
        gemini_output = read {FEATURE_DIR}/analysis/cli-outputs/{ROLE}-gemini.md

    METRICS:
        Consolidated dispatch metrics (including ntm native metrics) written to:
        {FEATURE_DIR}/analysis/cli-metrics/dispatch-{UUID}.json

STEP 3 — Synthesize:
    CALL Task(subagent_type="general-purpose", model="sonnet") with:
        inputs: [all captured outputs from CLIs that succeeded]
        strategy: union_with_dedup (for analysis) or weighted_score (for consensus)
        dedup_scheme: DUPLICATE/RELATED/UNIQUE (see Semantic Deduplication below)
        read_order: shortest output first (Least-to-Most protocol)
        Output: merged findings written to {FEATURE_DIR}/analysis/{REPORT_FILE}

    POST-SYNTHESIS VALIDATION:
        Count findings in merged output
        IF finding_count == 0 AND any CLI succeeded: flag as synthesis error, re-run
        IF finding_count > (sum of input findings): flag as hallucination, re-run
```

---

## Team-Based Follow-Up Protocol (when Agent Teams enabled)

When `AGENT_TEAMS_ENABLED == true`, each CLI integration point can optionally run a 2-agent perspective-critic team debate AFTER CLI outputs are captured. This replaces the Task-based sonnet synthesis with a richer cross-examination.

```
STEP 3 becomes (when teams available):
    IF AGENT_TEAMS_ENABLED:
        TeamCreate("planning-{FEATURE_ID}-{ROLE}")
        Spawn 2 perspective-critic agents:
            Read agent: @$CLAUDE_PLUGIN_ROOT/agents/perspective-critic.md
            - critic-a: {ROLE_A} with {LENS_A}
            - critic-b: {ROLE_B} with {LENS_B}
        Both read CLI outputs + plan artifacts
        Exchange findings via SendMessage (cross-examination)
        Team lead synthesizes from debate
        TeamDelete()
    ELSE:
        [existing Task-based synthesis with sonnet agent]
```

**Per-Role Team Assignments:**

| Role | Critic A Role | Critic A Lens | Critic B Role | Critic B Lens |
|------|--------------|---------------|--------------|---------------|
| deepthinker | architecture-challenger | Performance risks, scalability limits | design-advocate | Architectural elegance, pattern fit |
| consensus | gap-detector | Missing requirements, untested paths | feasibility-assessor | Implementation realism, effort accuracy |
| planreviewer | risk-assessor | Security, reliability, failure modes | scope-guardian | Over-engineering, unnecessary complexity |
| teststrategist | coverage-auditor | Untested paths, missing edge cases | pragmatist | Test ROI, maintenance cost |
| securityauditor | attack-modeler | STRIDE threat modeling, exploit paths | compliance-reviewer | Privacy, regulatory, data protection |
| taskauditor | dependency-validator | Task ordering, missing prerequisites | completeness-checker | Missing tasks, definition of done gaps |

**Fallback:** If TeamCreate fails at any integration point, fall back to existing Task-based synthesis. This is per-integration — a team failure at deepthinker doesn't prevent team attempts at planreviewer.

**Timeout:** 120 seconds per team debate (covers both initial findings + cross-examination).

---

## Planning-Specific Roles

Six CLI roles, each dispatched as dual-CLI (Codex + Gemini) at specific phases.

### deepthinker (Phase 5)

**Purpose:** Deep architecture analysis from 2 independent technical perspectives.
**Modes:** complete, advanced

| CLI | Role File | Focus |
|-----|-----------|-------|
| codex | `codex_deepthinker.txt` | Import chain analysis, coupling assessment, complexity hotspots |
| gemini | `gemini_deepthinker.txt` | Broad architecture exploration, tech stack, pattern conflicts |

**Session:** `planning-{FEATURE_ID}-deepthinker`
**Timeout:** 180s (audit mirror: source planning-config.yaml → timeout.per_role.deepthinker)

### consensus (Phases 6, 8)

**Purpose:** Dual-stance dimensional scoring — one advocate, one challenger.
**Modes:** complete, advanced

| CLI | Role File | Stance | Focus |
|-----|-----------|--------|-------|
| codex | `codex_consensus.txt` | challenger | Code-level feasibility, dependency checking, file:line evidence |
| gemini | `gemini_consensus.txt` | advocate | Strategic plan/coverage assessment, broad codebase exploration |

**Session:** `planning-{FEATURE_ID}-consensus`
**Timeout:** 120s (audit mirror: source planning-config.yaml → timeout.per_role.consensus)

### planreviewer (Phase 6)

**Purpose:** Risk-focused plan review from strategic and technical perspectives.
**Modes:** complete, advanced

| CLI | Role File | Focus |
|-----|-----------|-------|
| codex | `codex_planreviewer.txt` | Technical feasibility, code structure support, dependency compatibility |
| gemini | `gemini_planreviewer.txt` | Strategic risks, scope assessment, Red Team/Blue Team |

**Session:** `planning-{FEATURE_ID}-planreviewer`
**Timeout:** 120s (audit mirror: source planning-config.yaml → timeout.per_role.planreviewer)

### teststrategist (Phase 7)

**Purpose:** Test strategy quality from code-pattern and infra-discovery perspectives.
**Modes:** complete

| CLI | Role File | Focus |
|-----|-----------|-------|
| codex | `codex_teststrategist.txt` | Test code patterns, assertion quality, mock patterns, test isolation |
| gemini | `gemini_teststrategist.txt` | Test infra discovery, framework patterns, coverage gaps, ThinkDeep reconciliation |

**Session:** `planning-{FEATURE_ID}-teststrategist`
**Timeout:** 150s (audit mirror: source planning-config.yaml → timeout.per_role.teststrategist)

### securityauditor (Phase 6b)

**Purpose:** Security review from vulnerability-scan and compliance perspectives.
**Modes:** complete, advanced

| CLI | Role File | Focus |
|-----|-----------|-------|
| codex | `codex_securityauditor.txt` | OWASP code-level vulnerabilities, injection points, hardcoded secrets |
| gemini | `gemini_securityauditor.txt` | Supply chain security, architectural attack surface, compliance |

**Session:** `planning-{FEATURE_ID}-securityauditor`
**Timeout:** 150s (audit mirror: source planning-config.yaml → timeout.per_role.securityauditor)

### taskauditor (Phase 9)

**Purpose:** Task list validation from requirements-mapping and code-structure perspectives.
**Modes:** complete, advanced

| CLI | Role File | Focus |
|-----|-----------|-------|
| codex | `codex_taskauditor.txt` | File path verification, dependency ordering, code structure alignment |
| gemini | `gemini_taskauditor.txt` | Requirements mapping, missing infrastructure, scope coverage |

**Session:** `planning-{FEATURE_ID}-taskauditor`
**Timeout:** 120s (audit mirror: source planning-config.yaml → timeout.per_role.taskauditor)

---

## Synthesis Pattern (Dual-CLI)

### Confidence Categories

| Category | Condition | Confidence | Action |
|----------|-----------|------------|--------|
| **Convergent** | Both CLIs agree on the same finding | HIGH | Accept finding directly |
| **Divergent** | CLIs disagree on the same topic | FLAG | Escalate for user decision |
| **Unique** | Only one CLI raised the finding | VERIFY | Cross-check against existing plan analysis |

### Synthesis Algorithm

```
all_findings = []
FOR EACH cli_result IN [codex_result, gemini_result]:
    IF cli_result exists AND cli_result is not empty:
        EXTRACT findings list from cli_result
        TAG each finding with source_cli = cli_name
        APPEND to all_findings

available_cli_count = COUNT(non-empty results)

IF available_cli_count == 0:
    SKIP synthesis — no CLI data available
    RETURN empty with flags.degraded = true

finding_groups = GROUP(all_findings) by topic + recommendation direction

FOR EACH group IN finding_groups:
    sources = UNIQUE(cli names in group)

    IF LEN(sources) == 2:
        category = "convergent"
        confidence = "HIGH"
        merged_finding = MERGE(group findings, keep strongest evidence)
    ELSE:
        other_cli = CLI not in sources
        IF other_cli raised a DIFFERENT finding on same topic:
            category = "divergent"
            confidence = "FLAG"
            merged_finding = LIST(both positions separately)
        ELSE:
            category = "unique"
            confidence = "VERIFY"
            merged_finding = group findings[0]
            merged_finding.note = "Only raised by {sources[0]} — verify against existing analysis"

    EMIT merged_finding with category, confidence

SORT findings: convergent first, then unique, then divergent
```

### Score Synthesis (for Consensus Role)

For dimensional scoring in Phases 6 and 8:

```
FOR EACH scoring_dimension:
    scores = COLLECT(score from each CLI for this dimension)

    IF LEN(scores) == 2:
        delta = MAX(scores) - MIN(scores)
        averaged = MEAN(scores)

        IF delta <= 1.0:                         # audit mirror: 1.0 (source: planning-config.yaml → divergence.low)
            USE averaged score → HIGH confidence
        ELSE IF delta > 4.0:                     # audit mirror: 4.0 (source: planning-config.yaml → divergence.high)
            FLAG for user review
            INCLUDE per-CLI score breakdown in report
        ELSE:
            USE averaged score
            NOTE disagreement in report
    ELSE:
        USE single available score
        MARK as "single-CLI score"
```

---

## Least-to-Most Synthesis Protocol

When synthesizing CLI outputs, read shortest output first to build a baseline, then layer unique findings from each subsequent output. This prevents anchoring on the first-read model's framing.

```
outputs = SORT(cli_outputs, by=word_count, ascending=true)
baseline = outputs[0]
FOR EACH subsequent_output IN outputs[1:]:
    DIFF against baseline findings
    ADD only RELATED or UNIQUE findings (skip DUPLICATEs)
    UPDATE baseline with merged result
RETURN baseline as final synthesis
```

---

## Semantic Deduplication Scheme

| Classification | Criteria | Action |
|---------------|----------|--------|
| **DUPLICATE** | Same finding, same recommendation, different wording | Merge: keep the more detailed version |
| **RELATED** | Same topic area but different aspects or recommendations | Keep both, group under shared heading |
| **UNIQUE** | No counterpart in other CLI outputs | Keep as-is |

Apply this scheme in all synthesis steps. The synthesis agent classifies each pair, then merges DUPLICATEs and groups RELATEDs.

---

## Chain-of-Verification (CoVe) Self-Critique

Run CoVe in a separate Task to avoid coordinator context pollution.

```
validated = Task(
    subagent_type: "general-purpose",
    model: "sonnet",
    prompt: """
        Apply Chain-of-Verification (CoVe) to these CLI {ROLE} findings:

        {synthesized_findings}

        Process:
        1. Generate 3-5 verification questions targeting the highest-risk findings
        2. Answer each question against the evidence provided
        3. Revise or remove findings where verification fails
        4. Return ONLY validated findings in the original output format

        Quality gate: At least 3 verification questions must pass for submission.
    """,
    description: "CoVe self-critique for CLI {ROLE}"
)
```

---

## CLI Failure Handling

```
IF exit_code == 0 (all CLIs produced output):
    PROCEED to synthesis (Step 3)

IF exit_code == 1 (partial failure):
    READ output files — some CLIs may have produced valid output
    INCLUDE valid outputs in synthesis (best-effort with available data)
    LOG failed CLIs to model_failures
    IF retry_count < max_retries:
        max_retries = config.cli_integration.retry.max_retries  # audit mirror: 1 (source: planning-config.yaml)
        INCREMENT retry_count
        RE-RUN dispatch-via-ntm.sh with same parameters
    ELSE:
        SYNTHESIZE with partial results

IF exit_code == 2 (robot-ack timeout):
    READ output files — robot-ack timed out but agents may have produced output
    before returning to idle. The script captures whatever is in the pane buffer.
    IF any output file has SUMMARY block content: include in synthesis
    IF no usable output: treat as all-fail
    RETRY up to max_retries attempts, then synthesize partial

IF exit_code == 3 (ntm not found):
    LOG to model_failures: {role, exit_code: 3, action: "ntm not in PATH — falling back to legacy"}
    DO NOT retry via ntm
    FALL BACK to dispatch-cli-agent.sh (see Legacy Fallback below)

IF exit_code == 4 (bad arguments):
    LOG as coordinator error — check prompt file paths and session naming
    DO NOT retry (fix the coordinator logic)

IF exit_code == 5 (spawn failed):
    LOG to model_failures: {role, exit_code: 5, action: "ntm robot-spawn failed"}
    RETRY up to 1 attempt (transient tmux issue)
    IF still failing: FALL BACK to dispatch-cli-agent.sh

IF all CLIs fail (no usable output after retries):
    IF circuit_breaker.skip_on_all_fail:
        SKIP this integration point
        PROCEED with internal reasoning
        LOG: "CLI dispatch skipped — all CLIs failed"
    ELSE:
        SET status = needs-user-input
```

### Error Notification Format

When a CLI dispatch fails, the coordinator MUST include a WARNING box in the phase summary:

```markdown
> [!WARNING]
> **CLI Dispatch Degraded — {ROLE} (Phase {N})**
> Exit code: {CODE} — {MEANING}
> CLIs attempted: codex, gemini
> CLIs succeeded: {LIST or "none"}
> Action taken: {synthesized partial | fell back to legacy | skipped}
> Impact: {description of reduced coverage}
```

---

## Retry Protocol

The ntm dispatch script does NOT retry internally. If the coordinator needs a retry:

```
max_retries = config.cli_integration.retry.max_retries  # audit mirror: 1 (source: planning-config.yaml)

IF exit_code IN [1, 2] AND retry_count < max_retries:
    INCREMENT retry_count
    RE-RUN dispatch-via-ntm.sh with same parameters
    (ntm defensive cleanup kills stale sessions automatically via --robot-spawn)

IF exit_code == 5 AND retry_count < 1:
    INCREMENT retry_count
    RE-RUN dispatch-via-ntm.sh with same parameters

circuit_breaker_threshold = 2  # audit mirror: 2 (source: planning-config.yaml → retry.circuit_breaker_threshold)
IF state.cli.consecutive_failures >= circuit_breaker_threshold:
    LOG: "Circuit breaker triggered — disabling CLI dispatch for remainder of session"
    SET state.cli.mode = "disabled"
    SKIP remaining CLI steps
```

---

## Legacy Fallback (when ntm unavailable)

When `dispatch-via-ntm.sh` returns exit code 3 (ntm not found) or exit code 5 (spawn failed after retry), fall back to the legacy `dispatch-cli-agent.sh` script which uses sequential Bash process-group dispatch.

```
SCRIPT_LEGACY = "$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh"

IF ntm_exit_code IN [3, 5]:
    LOG: "ntm unavailable — falling back to legacy dispatch-cli-agent.sh"

    FOR EACH cli IN [codex, gemini]:
        result = Bash(
            command: "{SCRIPT_LEGACY} --cli {cli} --role {ROLE} \
                --prompt-file {FEATURE_DIR}/analysis/cli-prompts/{ROLE}-{cli}.md \
                --output-file {FEATURE_DIR}/analysis/cli-outputs/{ROLE}-{cli}.md \
                --timeout {TIMEOUT}",
            run_in_background: true
        )

    # Wait for both, read outputs, proceed to Step 3 (synthesis)
    # Same synthesis logic applies — only the dispatch mechanism differs

    IF legacy dispatch also fails:
        LOG: "Both ntm and legacy dispatch failed — skipping CLI step"
        SKIP this integration point
        PROCEED with internal reasoning
```

### Evolution: Legacy → v2.0 (Robot Mode)

| Aspect | Legacy (`dispatch-cli-agent.sh`) | v2.0 (current, `dispatch-via-ntm.sh`) |
|--------|----------------------------------|----------------------------------------|
| Parallelism | N parallel `Bash(run_in_background)` | True parallel (1 Bash() call) |
| Session creation | N/A (no sessions) | `--robot-spawn` + JSON validation |
| Agent readiness | N/A | `--robot-status` polling (actual readiness) |
| Completion detection | Exit code only | `--robot-ack` (native, 1 line) |
| Output capture | stdout pipe + tiered extraction | `ntm copy` + SUMMARY block extraction |
| Metrics | Per-CLI sidecar JSON | Consolidated + `--robot-metrics` (native) |
| Visibility | None | `ntm attach` / `ntm dashboard` / `--robot-status --json` |
| Process management | setsid + timeout --kill-after | ntm tmux lifecycle |

---

## Dispatch Examples

### deepthinker (Phase 5)

```bash
$CLAUDE_PLUGIN_ROOT/scripts/dispatch-via-ntm.sh \
  --session "planning-{FEATURE_ID}-deepthinker" \
  --dispatch "codex:deepthinker:{FD}/analysis/cli-prompts/deepthinker-codex.md:{FD}/analysis/cli-outputs/deepthinker-codex.md" \
  --dispatch "gemini:deepthinker:{FD}/analysis/cli-prompts/deepthinker-gemini.md:{FD}/analysis/cli-outputs/deepthinker-gemini.md" \
  --timeout 180
```

### consensus (Phase 6)

```bash
$CLAUDE_PLUGIN_ROOT/scripts/dispatch-via-ntm.sh \
  --session "planning-{FEATURE_ID}-consensus" \
  --dispatch "codex:consensus:{FD}/analysis/cli-prompts/consensus-codex.md:{FD}/analysis/cli-outputs/consensus-codex.md" \
  --dispatch "gemini:consensus:{FD}/analysis/cli-prompts/consensus-gemini.md:{FD}/analysis/cli-outputs/consensus-gemini.md" \
  --timeout 120
```

### securityauditor (Phase 6b)

```bash
$CLAUDE_PLUGIN_ROOT/scripts/dispatch-via-ntm.sh \
  --session "planning-{FEATURE_ID}-securityauditor" \
  --dispatch "codex:securityauditor:{FD}/analysis/cli-prompts/securityauditor-codex.md:{FD}/analysis/cli-outputs/securityauditor-codex.md" \
  --dispatch "gemini:securityauditor:{FD}/analysis/cli-prompts/securityauditor-gemini.md:{FD}/analysis/cli-outputs/securityauditor-gemini.md" \
  --timeout 150
```

---

## Error Handling Summary

| Scenario | Behavior |
|----------|----------|
| Both CLIs succeed (exit 0) | Normal dual-CLI synthesis |
| One CLI fails, retry succeeds | Normal (delayed) |
| One CLI fails after retries | Proceed with single-CLI result (reduced synthesis) |
| Both CLIs fail after retries | Skip CLI step, log warning |
| Exit code 3 (ntm not found) | Fall back to legacy `dispatch-cli-agent.sh` |
| Exit code 4 (invalid args) | Log coordinator error, do not retry |
| Exit code 5 (spawn failed) | Retry once, then fall back to legacy |
| 2+ consecutive failures across phases | Circuit breaker: disable CLI dispatch for session |
| Self-critique Task fails | Use unsynthesized findings with `flags.degraded: true` |
| Team debate fails (AGENT_TEAMS_ENABLED) | Per-role fallback to Task-based synthesis |
