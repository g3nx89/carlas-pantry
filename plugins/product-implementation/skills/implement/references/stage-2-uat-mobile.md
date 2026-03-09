# Stage 2 — Step 3.7: UAT Mobile Testing

> Extracted from `stage-2-execution.md` Step 3.7 for readability.
> Supports 3 engines: Claude subagent, Codex CLI, Gemini CLI.

## Gate Check (3 gates — all must pass)

1. `uat_execution.enabled` is `true` (master switch from config)
2. `mobile_mcp_available` is `true` (emulator + mobile-mcp running — from Stage 1 summary)
3. Phase has mapped UAT specs OR touches UI files (relevance check below)

No engine-specific gates — Claude subagent is always available as fallback.

When any gate fails, log a structured warning identifying the specific gate:

| Gate | Fail Condition | Warning Message |
|------|---------------|-----------------|
| 1 | `uat_execution.enabled` is `false` | `[WARNING] UAT mobile testing SKIPPED for phase {phase_name}: master switch disabled. Fix: set uat_execution.enabled: true in config.` |
| 2 | `mobile_mcp_available` is `false` | `[WARNING] UAT mobile testing SKIPPED for phase {phase_name}: mobile-mcp not reachable. Fix: start emulator and verify mobile-mcp MCP server is running.` |
| 3 | Phase not relevant | `[WARNING] UAT mobile testing SKIPPED for phase {phase_name}: no UAT specs or UI files detected. Fix: add UAT-* test IDs to phase tasks or ensure file paths match UI domain indicators.` |

### Non-Skippable Gate Check

Before skipping UAT, check if `"stage2.uat"` appears in `cli_dispatch.non_skippable_gates` from config. If it does:

- **Gate 1 false** (master switch disabled): Skip silently — the user explicitly disabled this dispatch.
- **Gate 2 false** (emulator/mobile-mcp unavailable): Log a structured gate failure: `"[GATE_BLOCKED] Non-skippable gate 'stage2.uat' cannot execute: {reason}. Prerequisites: mobile_mcp={mobile_mcp_available}."` Record in Stage 2 summary for KPI tracking. Do NOT silently skip.
- **Gate 3 false** (phase not relevant): Skip silently — irrelevant phases are not a gate failure.

If `"stage2.uat"` is NOT in `non_skippable_gates`, skip to Step 4 (Update Progress, in `stage-2-execution.md`) with a standard warning log.

## Phase Relevance Check

Determine if the current phase warrants UAT testing:

1. **UAT test ID check** (if `uat_execution.phase_relevance.check_uat_test_ids` is `true`):
   - Extract test IDs from current phase task descriptions
   - Filter for `UAT-*` pattern (from `handoff.test_cases.test_id_patterns`)
   - Map each `UAT-{ID}` to `{FEATURE_DIR}/test-cases/uat/UAT-{ID}.md`
   - If at least one UAT spec file exists for this phase → `uat_relevant = true`

2. **UI file path check** (if `uat_execution.phase_relevance.check_ui_file_paths` is `true`):
   - Collect file paths from current phase task descriptions
   - Check against domain indicators for domains listed in `uat_execution.phase_relevance.ui_domains` (resolved via `dev_skills.domain_mapping` in config)
   - If any file path matches a UI domain indicator → `uat_relevant = true`

3. If neither check matches → skip to Step 4, log: `"Phase '{phase_name}' has no UAT specs or UI files — skipping UAT"`

## Engine Selection

Read `engine_strategy` from Stage 1 summary:
- If per_phase engine is `"subagent"` → dispatch Claude subagent (Path A)
- If per_phase engine is `"cli"` → dispatch via `run-uat.sh` (Path B)
- If CLI dispatch fails → fallback to subagent (if `uat_execution.fallback_to_subagent` is `true`)

## Path A: Claude Subagent Dispatch

1. Build prompt from UAT Tester Prompt Template (`agent-prompts.md`)
2. Prefill variables: `{uat_specs}`, `{apk_path}`, `{evidence_dir}`, `{figma_refs_dir}`, `{package_name}`, `{device_name}`, `{phase_name}`, `{platform}`, `{emulator_type}`
3. Dispatch: `Task(subagent_type="product-implementation:uat-tester")`
4. Parse `<SUMMARY>` block from agent output
5. Process results (severity gating → autonomy policy)

## Path B: CLI Script Dispatch

1. Determine CLI engine from Stage 1 summary (`codex` or `gemini`)
2. Build CLI command:
   ```
   $CLAUDE_PLUGIN_ROOT/scripts/uat/run-uat.sh \
     --{engine} \
     --apk {apk_path} \
     --specs {uat_specs_dir} \
     --package {package_name} \
     --report-dir {evidence_dir}/{phase_name} \
     --figma-refs {figma_refs_dir} \
     [--model {codex_model}] \
     [--effort {codex_effort}] \
     {test_group_ids}
   ```
3. Execute via Bash with timeout from `uat_execution.timeout_ms` (default: 600000)
4. Parse consolidated report for `<SUMMARY>` block
5. Process results (severity gating → autonomy policy)

## APK Build

1. Read build config from `uat_execution.gradle_build`
2. Run `Bash("{gradle_build.command}")` with timeout `gradle_build.timeout_ms` (default: 180000 = 3 minutes)
3. If build fails: log warning `"Gradle build failed — skipping UAT for phase '{phase_name}'"`, skip to Step 4
4. Locate APK via `Glob("{gradle_build.apk_search_pattern}")`
5. If no APK found: log warning, skip to Step 4
6. Store `apk_path` for injection into dispatch prompt

## APK Install

1. Read install config from `uat_execution.apk_install`
2. If `reinstall` is `true`:
   - Call `mobile_terminate_app` (ignore errors)
   - Call `mobile_uninstall_app` (ignore errors)
3. Call `mobile_install_app` with the located APK path
4. If install fails: log warning, skip to Step 4
5. If `launch_after_install` is `true`:
   - Determine `app_package` from config or auto-detect from APK
   - Call `mobile_launch_app`
   - Wait 3-5 seconds for initialization

## Evidence Directory Setup

```
mkdir -p {FEATURE_DIR}/{evidence_dir}/{phase_name_sanitized}/
```

Where `phase_name_sanitized` converts the phase name to a safe directory name (lowercase, non-alphanumeric replaced with hyphens).

## Result Processing

1. **Parse `<SUMMARY>` block**: Extract scenario counts and recommendation.

2. **Severity gating** (from `uat_execution.severity_gating`):
   - `"PASS"` or `"PASS_WITH_NOTES"` with no Critical/High → log success, proceed to Step 4
   - Medium/Low only → log warning, proceed to Step 4
   - Critical/High findings → apply autonomy policy check via `autonomy-policy-procedure.md`:
     - `finding_severity_map` = `{critical: [...], high: [...]}`
     - `context_label` = `"UAT phase '{phase_name}'"`
     - `fix_agent_config` = developer agent, re-build and re-run UAT (one retry)
     - `defer_artifact_path` = `{FEATURE_DIR}/review-findings.md` under `## UAT Findings — {phase_name}`
     - After processing → proceed to Step 4

3. **Dispatch failure/timeout**: If CLI fails and `fallback_to_subagent` is `true`, retry with Path A. Otherwise follow `"skip"` behavior, log warning.

4. **Track metrics**: Record in phase-level tracking:
   - `uat_ran`, `uat_engine`, `uat_scenarios`, `uat_passed`, `uat_failed`, `uat_blocked`, `uat_visual_mismatches`, `uat_recommendation`

## Write Boundaries

The UAT agent writes ONLY screenshot files to the evidence directory. It MUST NOT write to source, test, or spec directories. The coordinator verifies post-dispatch that no files outside the evidence directory were created or modified.

## Latency Impact

- Claude subagent: ~2-5 min per relevant phase (direct mobile-mcp, no process spawn)
- CLI (Codex): ~5-8 min per relevant phase (process spawn + model inference)
- CLI (Gemini): ~6-10 min per relevant phase
