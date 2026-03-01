# Stage 2 — Step 3.7: UAT Mobile Testing

> Extracted from `stage-2-execution.md` Step 3.7 for readability.
> Referenced by: `stage-2-execution.md` (conditional dispatch after Step 3.6).

## Gate Check

> **Conditional**: Only runs when ALL five gates pass:
>   1. `uat_execution.enabled` is `true` (master switch from config)
>   2. `cli_dispatch.stage2.uat_mobile_tester.enabled` is `true`
>   3. `cli_availability.gemini` is `true` (from Stage 1 summary)
>   4. `mobile_mcp_available` is `true` (from Stage 1 summary)
>   5. Phase has mapped UAT specs OR touches UI files (see relevance check below)

All availability flags come from Stage 1 summary unless noted.

### Non-Skippable Gate Check

Before skipping UAT, check if `"stage2.uat_mobile_tester"` appears in `cli_dispatch.non_skippable_gates` from config. If it does:

- **Gates 1-2 false** (master switches disabled): Skip silently — the user explicitly disabled this dispatch.
- **Gates 3-4 false** (prerequisites unavailable): Log a structured gate failure: `"[GATE_BLOCKED] Non-skippable gate 'stage2.uat_mobile_tester' cannot execute: {reason}. Prerequisites: gemini={cli_availability.gemini}, mobile_mcp={mobile_mcp_available}."` Record in Stage 2 summary for KPI tracking. Do NOT silently skip.
- **Gate 5 false** (phase not relevant): Skip silently — irrelevant phases are not a gate failure.

If `"stage2.uat_mobile_tester"` is NOT in `non_skippable_gates`, skip to Step 4 (Update Progress, in `stage-2-execution.md`) with a standard warning log.

After code completion (and optional simplification), run behavioral acceptance testing and Figma visual verification against the running app on a Genymotion emulator. The coordinator handles APK build and install; the CLI agent handles testing.

## Phase Relevance Check

Determine if the current phase warrants UAT testing:

1. **UAT test ID check** (if `uat_mobile_tester.phase_relevance.check_uat_test_ids` is `true`):
   - Extract test IDs from current phase task descriptions
   - Filter for `UAT-*` pattern (from `handoff.test_cases.test_id_patterns`)
   - Map each `UAT-{ID}` to `{FEATURE_DIR}/test-cases/uat/UAT-{ID}.md`
   - If at least one UAT spec file exists for this phase → `uat_relevant = true`

2. **UI file path check** (if `uat_mobile_tester.phase_relevance.check_ui_file_paths` is `true`):
   - Collect file paths from current phase task descriptions
   - Check against domain indicators for domains listed in `uat_mobile_tester.phase_relevance.ui_domains` (resolved via `dev_skills.domain_mapping` in config)
   - If any file path matches a UI domain indicator → `uat_relevant = true`

3. If neither check matches → skip to Step 4, log: `"Phase '{phase_name}' has no UAT specs or UI files — skipping UAT"`

## APK Build

1. Read build config from `cli_dispatch.stage2.uat_mobile_tester.gradle_build`
2. Run `Bash("{gradle_build.command}")` with timeout `gradle_build.timeout_ms` (default: 180000 = 3 minutes)
3. If build fails: log warning `"Gradle build failed — skipping UAT for phase '{phase_name}'"`, skip to Step 4
4. Locate APK via `Glob("{gradle_build.apk_search_pattern}")`
5. If no APK found: log warning, skip to Step 4
6. Store `apk_path` for injection into CLI prompt

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
mkdir -p {FEATURE_DIR}/{uat_mobile_tester.evidence_dir}/{phase_name_sanitized}/
```

Where `phase_name_sanitized` converts the phase name to a safe directory name (lowercase, non-alphanumeric replaced with hyphens).

## CLI Dispatch

1. **Collect UAT specs**: Read matched UAT spec files for this phase. If no specific specs matched but phase was relevant via UI file paths, use all available UAT specs from `{FEATURE_DIR}/test-cases/uat/`.

2. **Build prompt**: Read role prompt from `$CLAUDE_PLUGIN_ROOT/config/cli_clients/gemini_uat_mobile_tester.txt`

3. **Dispatch** via Shared CLI Dispatch Procedure (`cli-dispatch-procedure.md`) with:
   - `cli_name="gemini"`, `role="uat_mobile_tester"`
   - `file_paths=[FEATURE_DIR/test-cases/uat/, FEATURE_DIR, PROJECT_ROOT]`
   - `timeout_ms` from `cli_dispatch.stage2.uat_mobile_tester.timeout_ms` (default: 600000)
   - `fallback_behavior` from config (default: `"skip"`)
   - `expected_fields=["total_scenarios", "passed", "failed", "blocked", "critical_issues", "visual_mismatches", "recommendation"]`

4. **Coordinator-Injected Context**: `{phase_name}`, `{FEATURE_DIR}`, `{PROJECT_ROOT}`, `{uat_spec_content}`, `{apk_path}`, `{evidence_dir}`, `{mobile_device_name}`, `{figma_default_url}`, `{app_package}`

5. **MCP Tool Budget** (advisory, from `cli_dispatch.mcp_tool_budgets.per_cli_dispatch`):
   - Mobile MCP: max screenshots, interactions, device queries
   - Figma: max calls
   - Sequential Thinking: max chains

## Result Processing

1. **Parse `<SUMMARY>` block**: Extract scenario counts and recommendation.

2. **Severity gating**:
   - `"PASS"` or `"PASS_WITH_NOTES"` with no Critical/High → log success, proceed to Step 4
   - Medium/Low only → log warning, proceed to Step 4
   - Critical/High findings → apply autonomy policy check via `autonomy-policy-procedure.md`:
     - `finding_severity_map` = `{critical: [...], high: [...]}`
     - `context_label` = `"UAT phase '{phase_name}'"`
     - `fix_agent_config` = developer agent, re-build and re-run UAT (one retry)
     - `defer_artifact_path` = `{FEATURE_DIR}/review-findings.md` under `## UAT Findings — {phase_name}`
     - After processing → proceed to Step 4

3. **CLI failure/timeout**: Follow `fallback_behavior` — default `"skip"`, log warning

4. **Track metrics**: Record in phase-level tracking:
   - `uat_ran`, `uat_scenarios`, `uat_passed`, `uat_failed`, `uat_blocked`, `uat_visual_mismatches`, `uat_recommendation`

## Write Boundaries

The CLI agent writes ONLY screenshot files to the evidence directory. It MUST NOT write to source, test, or spec directories. The coordinator verifies post-dispatch that no files outside the evidence directory were created or modified.

## Latency Impact

~30-60s Gradle build + ~10-30s APK install + ~120-600s UAT execution per phase. Total: ~3-10 minutes per relevant phase.
