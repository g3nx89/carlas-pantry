---
stage: "3"
section: "3.2a"
section_name: "Full-Sweep UAT Validation"
delegation: "coordinator-inline"
condition: "final_pass AND uat_execution.enabled AND mobile_mcp_available"
artifacts_read:
  - "test-cases/uat/ (all UAT specs)"
  - ".stage-summaries/stage-1-summary.md (engine_strategy, figma_refs)"
  - ".stage-summaries/stage-2-summary.md (per-phase UAT results)"
artifacts_written:
  - ".uat-evidence/full-sweep/ (screenshots)"
  - "Stage 3 summary UAT results"
---

# Stage 3 — Section 3.2a: Full-Sweep UAT Validation

> Runs ONLY in the final Stage 3 pass (after all phases complete).
> Not run during per-phase Stage 3 passes.

## Purpose

After all phases are implemented and individually validated, run a comprehensive
UAT covering ALL affected user stories to catch cross-phase interaction bugs
that per-phase testing cannot detect.

## Prerequisites

1. `uat_execution.enabled` is `true`
2. `mobile_mcp_available` is `true`
3. This is the FINAL Stage 3 pass (not a per-phase pass)
4. At least one phase had UAT-relevant tasks

If any prerequisite fails, skip with log and proceed to next Stage 3 section.

## Collect All UAT Specs

Scan ALL phases from tasks.md. Collect:
- All UAT-* test IDs across all phases → deduplicate
- Map to `test-cases/uat/` spec files
- Build list of all test group IDs (e.g., US-001, US-002, ...)

If no UAT specs found across any phase, skip with log: `"No UAT specs found across any phase — skipping full-sweep UAT"` and proceed.

## Engine Selection

Read `engine_strategy` from Stage 1 summary:
- If full_sweep engine is `"cli"` → dispatch via `run-uat.sh` with ALL groups
- If full_sweep engine is `"subagent"` → dispatch Claude subagent with ALL specs
- Fallback chain applies (cli → subagent if `fallback_to_subagent` is `true`)

## APK Build (Final)

Build a fresh APK from the final state of the codebase (all phases applied).
This is the definitive build for the feature.

1. Read build config from `uat_execution.gradle_build`
2. Run `Bash("{gradle_build.command}")` with timeout `gradle_build.timeout_ms`
3. If build fails: log warning, skip full-sweep UAT. Do NOT block Stage 3.
4. Locate APK via `Glob("{gradle_build.apk_search_pattern}")`
5. If no APK found: log warning, skip full-sweep UAT

## APK Install

1. If `uat_execution.apk_install.reinstall` is `true`:
   - Call `mobile_terminate_app` (ignore errors)
   - Call `mobile_uninstall_app` (ignore errors)
2. Call `mobile_install_app` with the located APK path
3. If install fails: log warning, skip full-sweep UAT
4. If `launch_after_install` is `true`:
   - Call `mobile_launch_app`
   - Wait 3-5 seconds for initialization

## Dispatch: Claude Subagent Path

1. Build prompt from UAT Tester Prompt Template (`agent-prompts.md`)
2. Prefill variables: `{uat_specs}` (ALL specs), `{apk_path}`, `{evidence_dir}` (`.uat-evidence/full-sweep/`), `{figma_refs_dir}`, `{package_name}`, `{device_name}`, `{phase_name}` = `"full-sweep"`, `{platform}`, `{emulator_type}`
3. Dispatch: `Task(subagent_type="product-implementation:uat-tester")`
4. Parse `<SUMMARY>` block from agent output
5. Process results (severity gating → autonomy policy)

## Dispatch: CLI Script Path

1. Determine CLI engine from Stage 1 summary (`codex` or `gemini`)
2. Build CLI command:
   ```
   $CLAUDE_PLUGIN_ROOT/scripts/uat/run-uat.sh \
     --{engine} \
     --apk {apk_path} \
     --specs {uat_specs_file} \
     --package {package_name} \
     --report-dir {evidence_dir}/full-sweep \
     --figma-refs {figma_refs_dir} \
     [--model {codex_model}] \
     [--effort {codex_effort}] \
     {all_test_group_ids}
   ```
3. Execute via Bash with timeout from config (`uat_execution.timeout_ms`)
4. Parse consolidated report for `<SUMMARY>` block
5. Process results (severity gating → autonomy policy)

## Result Processing

Severity gating applies per `uat_execution.severity_gating`:

- **PASS / PASS_WITH_NOTES** with no Critical/High → log success, proceed
- **Medium/Low only** → log warning, proceed
- **Critical/High findings** → apply autonomy policy:
  - `auto`: attempt fix + rebuild + re-run for all severities (one retry)
  - `interactive`: fix critical/high, defer medium to user
  - Manual escalation: `status: needs-user-input`

If recommendation is FAIL and severity_gating blocks → Stage 3 validation reports the failure.

## Integration with Stage 3 Summary

Full-sweep UAT results added to Stage 3 summary:

```yaml
uat_sweep_results:
  total_scenarios: N
  passed: N
  failed: N
  blocked: N
  visual_mismatches: N
  recommendation: PASS|FAIL|BLOCKED
  engine_used: "subagent|codex|gemini"
```

## Evidence Directory

```
mkdir -p {FEATURE_DIR}/{evidence_dir}/full-sweep/
```

## Write Boundaries

UAT agent writes ONLY screenshot files to the evidence directory. Coordinator verifies no files outside the evidence directory were created or modified.

## Latency Impact

~5-15 minutes depending on number of user story groups and engine. Runs once (not per-phase), so total impact is bounded.
