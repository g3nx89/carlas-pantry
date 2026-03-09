---
stage: "1b"
stage_name: "Setup Probes & Configuration"
checkpoint: "SETUP_PROBES"
delegation: "coordinator"
prior_summaries:
  - "stage-1a-partial.md"
artifacts_read:
  - "stage-1a-partial.md (partial summary from Stage 1a)"
  - "$CLAUDE_PLUGIN_ROOT/config/profile-definitions.yaml"
artifacts_written:
  - "{FEATURE_DIR}/.project-setup-analysis.local.md (conditional — Section 1.5b)"
  - "{FEATURE_DIR}/.project-setup-proposal.local.md (conditional — Section 1.5b)"
  - ".claude/hooks/*.sh (conditional — Section 1.5b)"
  - ".claude/settings.json (conditional, merged — Section 1.5b)"
  - "CLAUDE.md (conditional, appended — Section 1.5b)"
  - "{PROJECT_ROOT}/AGENTS.md (conditional, created/appended/updated — Section 1.7c)"
  - "{PROJECT_ROOT}/GEMINI.md (conditional, created/appended/updated — Section 1.7c)"
  - "{FEATURE_DIR}/.stage-summaries/stage-1-summary.md"
agents: []
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/stage-1-project-setup.md"
  - "$CLAUDE_PLUGIN_ROOT/config/profile-definitions.yaml"
---

# Stage 1b: Setup Probes & Configuration

> **COORDINATOR STAGE:** This stage is dispatched as a coordinator subagent by the orchestrator
> after Stage 1a completes inline. It reads the partial summary from Stage 1a and executes all
> probe, detection, and configuration sections. After completion, it writes the FULL Stage 1
> summary to `{FEATURE_DIR}/.stage-summaries/stage-1-summary.md`.

## Input: Stage 1a Partial Summary

Read `{FEATURE_DIR}/.stage-summaries/stage-1a-partial.md` to obtain:
- `PROJECT_ROOT`, `FEATURE_NAME`, `FEATURE_DIR`, `TASKS_FILE`
- Phase list and task count
- `test_cases_available` and test cases summary
- `ralph_mode` and `operational_learnings`
- Required/optional/expected file summaries
- User input (arguments)

All variables from Stage 1a are available via the partial summary. Do NOT re-read planning artifacts — use the context summaries from Stage 1a.

> **Note:** In this coordinator context, `SAFE_ASK_USER` is not directly available (coordinators cannot
> interact with users). For Sections 1.9, 1.5b, and 1.6ea: if required values are null and require user input,
> set `status: needs-user-input` with `block_reason` explaining what is needed. The orchestrator will
> mediate the user prompt. In ralph mode, all user questions are auto-resolved by the orchestrator
> guard before reaching this coordinator.
>
> **Execution order:** Run Section 1.9 (Profile Resolution) FIRST, then Sections 1.5b, 1.6, 1.6a–1.6g,
> 1.7a–1.7c in order. Section 1.9 writes the `features.*` flags that all subsequent sections gate on.

## 1.5b Project Setup Analysis [Cost: 1-2 subagent dispatches, ~30-60s]

> **Prerequisite:** Section 1.9 (Profile Resolution) MUST be executed before this section.
> The `features.project_setup` flag is resolved in Section 1.9 and is required here.
>
> Conditional: Only when `features.project_setup` is `true` (resolved from profile in Section 1.9).
> If false, set `project_setup` status to `"disabled"` in the Stage 1 summary and skip to Section 1.6.

### Skip Conditions

Skip this section entirely (set status to `"skipped"`) if ANY of:
- `features.project_setup` is `false` (resolved from profile in Section 1.9)
- State file exists AND `user_decisions.project_setup_applied` is `true` (resume case — already applied)
- `{FEATURE_DIR}/.project-setup-analysis.local.md` already exists (re-run case — analysis persists; skip_if_analyzed is always true)

### Procedure

1. **Dispatch analysis subagent** (throwaway `Task(subagent_type="general-purpose")`):
   - Prompt: Use the **Project Analysis Prompt** from `agent-prompts.md`
   - Fill variables: `{PROJECT_ROOT}`, `{FEATURE_DIR}`, `{plan_tech_stack}` (from plan.md tech stack section loaded in 1.4), `{plan_architecture}` (from plan.md architecture section), `{plan_test_strategy}` (from test-plan.md or plan.md test approach)
   - The subagent reads `$CLAUDE_PLUGIN_ROOT/skills/implement/references/stage-1-project-setup.md` Sections A-D for analysis instructions
   - The subagent scans PROJECT_ROOT for build files, `.claude/`, `CLAUDE.md`, `.mcp.json`
   - The subagent writes `{FEATURE_DIR}/.project-setup-analysis.local.md`

2. **Read analysis file** — read the compact analysis output (<3K tokens). If the subagent failed to produce the file, log warning and skip to Section 1.6.

3. **Filter categories** — For each category (claude_md, hooks, mcp_servers, code_quality):
   - If the analysis has zero recommendations for that category → skip
   - Collect categories with recommendations

4. **If no recommendations remain** → log "Project setup analysis found no improvements needed", set status to `"skipped"`, skip to Section 1.6.

5. **Present to user** via `SAFE_ASK_USER` (see `orchestrator-loop.md`):
   - Question: "I've analyzed your project setup. Which improvements should I apply?"
   - Header: "Setup"
   - multiSelect: `true`
   - Options: Only categories with recommendations (max 4). Each option's description includes the count and list of recommendations from the analysis.

6. **If user selects categories** → Dispatch generator subagent (throwaway `Task(subagent_type="general-purpose")`):
   - Prompt: Use the **Project Setup Generator Prompt** from `agent-prompts.md`
   - Fill variables: `{PROJECT_ROOT}`, `{FEATURE_DIR}`, `{analysis_content}` (full analysis file content), `{selected_categories}` (user's choices), `{plan_context}` (1-line summary of plan.md tech stack and architecture)
   - The subagent reads `$CLAUDE_PLUGIN_ROOT/skills/implement/references/stage-1-project-setup.md` Sections B, E, and F for hook templates and generator instructions
   - The subagent creates hook scripts, appends CLAUDE.md, updates settings.json
   - The subagent writes `{FEATURE_DIR}/.project-setup-proposal.local.md`

7. **If user selects "Other" or no categories** → set status to `"skipped"`, log "User skipped project setup", skip to Section 1.6.

8. **Record decisions** in state file (immutable). Note: If the state file does not yet exist (initial run), these decisions are recorded when the state file is created in Section 1.8:
   - `user_decisions.project_setup_applied: true`
   - `user_decisions.project_setup_categories: [{selected list}]`

9. **Merge into domain context** — The analysis provides ground-truth language/framework detection from actual project files. Pass `languages` and `frameworks` from the analysis to enrich Section 1.6 domain detection. If a domain is detected with `high` confidence in the analysis but only `tentative` in Section 1.6's text-matching, upgrade it to confident.

### Output

Store in Stage 1 summary YAML frontmatter (see Section 1.10):

```yaml
project_setup:
  status: "applied"                     # "applied" | "skipped" | "disabled"
  categories_applied: ["claude_md", "hooks"]
  categories_skipped: ["mcp_servers", "code_quality"]
  build_system: "gradle_kts"
  build_command: "./gradlew assembleDebug"
  test_command: "./gradlew testDebugUnitTest"
  formatter: "ktfmt --kotlinlang-style"  # or null
  active_hooks: ["protect-specs", "tdd-reminder", "safe-bash"]
  architecture_pattern: "clean_architecture"  # or null
  detected_languages: ["kotlin"]
  detected_frameworks: ["compose", "hilt", "room"]
```

## 1.6 Domain Detection [Cost: zero file reads, zero dispatches — pure text matching]

Detect technology domains present in the feature to enable conditional skill injection by downstream coordinators. This step uses artifacts ALREADY loaded in Sections 1.4-1.5.

### Detection Procedure

1. **Scan task file paths** in `tasks.md`: extract all file path fragments from task descriptions (e.g., `src/routes/auth.ts`, `app/build.gradle.kts`)
2. **Scan plan.md content**: check tech stack, architecture decisions, and file structure sections
3. **Match against domain indicators** defined in `$CLAUDE_PLUGIN_ROOT/config/profile-definitions.yaml` under `domain_mapping`

For each domain in the mapping, check if ANY of its `indicators` appear (case-sensitive) in the combined text of task file paths + plan.md content. If a match is found, add the domain key to `detected_domains`. Count the number of distinct indicator matches per domain.

### Output

Store the result as `detected_domains` in the Stage 1 summary YAML frontmatter (top-level field, not under `flags`; see Section 1.10). Flag domains with only a single indicator match as `tentative` — downstream stages may treat tentative domains with lower priority.

> **Note**: `detected_domains` is used by Section 1.9 for **vertical agent selection** (android-developer, frontend-developer, backend-developer, or generic developer) and by Stage 4 for conditional quality reviewer resolution. Skills are baked into agent .md files — no runtime skill injection is performed.

```yaml
detected_domains: ["kotlin", "compose", "android", "api"]
domain_confidence:
  kotlin: 5        # 5 indicator matches — confident
  compose: 3       # 3 indicator matches — confident
  android: 1       # 1 indicator match — tentative
  api: 2           # 2 indicator matches — confident
```

Domain detection always runs — profile feature flags control what downstream stages do with the results.

## 1.6a MCP Availability Check

Probe available MCP tools to determine which research capabilities are reachable. This step runs ONCE during Stage 1 and stores results for all downstream stages.

### Procedure

1. Read `features.research_mcp` from Stage 1 summary (resolved in Section 1.9)
2. If `features.research_mcp` is `false`, set all availability flags to `false`, skip Sections 1.6b-1.6d, and proceed to Section 1.7.
3. **Probe Ref**: Call `ref_search_documentation` with a minimal query derived from plan.md tech stack (e.g., the primary framework name). If the call succeeds (returns results or empty results without error), set `ref_available: true`. If it errors or times out, set `ref_available: false`.
4. **Probe Context7**: Call `resolve-library-id` with the primary framework name from plan.md. If the call succeeds, set `context7_available: true`. If it errors, set `context7_available: false`.
5. **Probe Tavily**: Call `tavily_search` with a minimal query (e.g., `"{primary_framework} documentation"`). If the call succeeds, set `tavily_available: true`. If it errors, set `tavily_available: false`.

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
mcp_availability:
  ref: true       # or false
  context7: true   # or false
  tavily: true     # or false
```

### Cost

3 lightweight probe calls (~1-3s total). Skipped entirely when `features.research_mcp` is `false`.

## 1.6b URL Extraction from Planning Artifacts [Cost: zero MCP calls — regex on loaded content]

Extract documentation URLs from already-loaded planning artifacts for pre-reading in Stage 2.

### Procedure

1. If `features.research_mcp` is `false` OR `ref_available` is `false` → skip, set `extracted_urls: []`
2. Scan the text content of `plan.md`, `design.md`, and `research.md` (already loaded in Section 1.4) for URLs matching patterns: `https?://[^\s"'<>]+` (standard http/https URLs)
3. Filter out URLs matching ignore patterns: `localhost`, `127.0.0.1`, `example.com`, `placeholder`
4. Deduplicate by exact URL string
5. Cap at 5 URLs (keep earliest-appearing)

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
extracted_urls:
  - "https://docs.example.com/api/v2"
  - "https://framework.dev/migration-guide"
```

## 1.6c Library ID Pre-Resolution (Context7)

Pre-resolve Context7 library IDs so downstream coordinators can skip the resolve step and query docs directly.

### Procedure

1. If `features.research_mcp` is `false` OR `context7_available` is `false` → skip, set `resolved_libraries: []`
2. Extract library/framework names from `plan.md` tech stack section (e.g., "React", "Express", "Prisma")
3. For each library name (up to 5):
   - Call `resolve-library-id` with `libraryName` = the library name and `query` = a brief description of how it's used in the project
   - If successful, record `{name, library_id}` pair
   - If the call fails, skip that library (do not halt)

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
resolved_libraries:
  - name: "React"
    library_id: "/facebook/react"
  - name: "Express"
    library_id: "/expressjs/express"
```

### Cost

Up to 5 `resolve-library-id` calls (~2-5s total). Skipped when `features.research_mcp` is false or Context7 unavailable.

## 1.6d Private Documentation Discovery [Cost: 1 Ref call, skipped when disabled]

Discover private documentation sources via Ref for use in downstream stages.

### Procedure

1. If `features.research_mcp` is `false` OR `ref_available` is `false` → skip, set `private_doc_urls: []`
2. Call `ref_search_documentation` with query: `"{primary_framework} {feature_description} ref_src=private"` (use plan.md tech stack and feature name)
3. Extract up to 3 result URLs

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
private_doc_urls:
  - "https://internal.docs.company.com/api-guide"
```

## 1.6e Mobile Device Availability Check [Cost: 1 MCP probe ~1-2s, skipped when UAT disabled]

Probe mobile-mcp to determine if a mobile testing emulator is available for UAT execution. This step runs ONCE during Stage 1 and stores results for all downstream stages.

### Procedure

1. Read `features.uat_execution` from Stage 1 summary (resolved in Section 1.9)
2. If `features.uat_execution` is `true`, proceed with probe below. Otherwise, set `mobile_mcp_available: false`, `mobile_device_name: null`, skip to Section 1.6ea.
3. **Probe mobile-mcp**: Call `mobile_list_available_devices`
   - If call succeeds AND returns at least one device: set `mobile_mcp_available: true`, store `mobile_device_name` from the first available emulator device (prefer emulator over physical device for UAT reproducibility)
   - If call fails, times out, or returns empty device list: set `mobile_mcp_available: false`, `mobile_device_name: null`, log warning: `"Mobile MCP not available or no emulator running — UAT mobile testing will be skipped for all phases"`

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
mobile_mcp_available: true    # or false
mobile_device_name: "emulator-5554"  # or null
```

## 1.6ea UAT Engine Strategy & Figma Reference Export [Cost: conditional — 0-30s Figma export]

Determine UAT engine strategy and pre-export Figma reference screenshots.

### Engine Strategy

1. Read `uat_strategy` from Stage 1 summary (resolved in Section 1.9). If already resolved, skip steps 2-3.
2. If not resolved AND NOT ralph mode:
   - Ask user via `status: needs-user-input` with options (read `uat_engine_strategies` keys from `$CLAUDE_PLUGIN_ROOT/config/profile-definitions.yaml`): `"hybrid (recommended)"`, `"subagent_only"`, `"cli_only"`
3. If not resolved AND ralph mode: auto-resolve to `"subagent_only"`
4. Resolve per_phase/full_sweep engines from `uat_engine_strategies[{strategy}]` in `profile-definitions.yaml`

### Figma Reference Export

1. If `features.figma_parity` is `false` OR `figma_references.file_key` is `null` (from `implementation-config.yaml`): skip
2. If output dir already has PNGs: skip (force_refresh is always false unless explicitly set)
3. Run: `Bash("$CLAUDE_PLUGIN_ROOT/scripts/uat/capture-figma-refs.sh {file_key} {output_dir} --page {page_name} --scale {scale}")`
4. If export fails: log warning, set `figma_refs_available: false` — UAT proceeds without visual parity

### Emulator Type Detection

1. If `mobile_mcp_available` is `true`:
   - Check `mobile_device_name` — if contains "genymotion" → `emulator_type: "genymotion"`, else `"avd"`
2. If `mobile_mcp_available` is `false`: `emulator_type: null`

### Output

Store in Stage 1 summary:

```yaml
# uat_strategy, uat_engine_per_phase, uat_engine_full_sweep are set by Section 1.9 — do not repeat here
figma_refs_dir: "figma-references"   # or null if Figma reference export skipped/failed
emulator_type: "genymotion"          # or "avd" or null (null if mobile_mcp_available is false)
```

## 1.6f Plugin Availability Check [Cost: zero MCP calls — skill listing check]

Probe available plugins to determine which optional skill-based capabilities are reachable. This step runs ONCE during Stage 1 and stores results for downstream coordinators.

### Procedure

1. Check if the `code-review:review-local-changes` skill is listed in available skills (query the Skill tool listing)
2. If listed: set `plugin_availability.code_review: true`
3. If not listed: set `plugin_availability.code_review: false`

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
plugin_availability:
  code_review: true    # or false
```

## 1.6g Figma Availability Check [Cost: 1 MCP probe ~1-2s, skipped when no UI domains detected]

Probe figma-console to determine if Figma Desktop Bridge is connected. This enables developer agents to extract structured design specs and verify implementation parity.

### Procedure

1. Read `detected_domains` from Section 1.6 output
2. If no UI-related domains are detected (`compose`, `android`, `web_frontend` are absent from `detected_domains`) → set `figma_available: false`, skip to Section 1.7a
3. Read `features.figma_parity` from Stage 1 summary (resolved in Section 1.9)
4. If `features.figma_parity` is `false` → set `figma_available: false`, skip to Section 1.7a
5. **Probe Figma**: Call `figma_get_status`
   - If call succeeds AND returns a connected status → set `figma_available: true`
   - If call fails, times out, or returns disconnected → set `figma_available: false`, log warning: `"Figma Desktop Bridge not available — developer agents will implement from planning artifacts only (no structured design data)"`

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
figma_available: true    # or false
```

## 1.7a CLI Availability Detection (CLI)

Detect which external CLI tools are available for CLI dispatch. This step runs ONCE during Stage 1 and stores results for all downstream coordinators. It only executes when at least one CLI option is enabled in config.

### Procedure

1. Read `features.external_models` from Stage 1 summary (resolved in Section 1.9)
2. If `features.external_models` is `false` → set `cli_availability: {}` and skip to Section 1.7b
3. Read `cli_feature_mapping` from `$CLAUDE_PLUGIN_ROOT/config/profile-definitions.yaml` to get the list of CLIs to probe (e.g., `codex`, `gemini`)
4. Read `cli.codex_model` and `cli.codex_effort` from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml` (user-configurable overrides)
5. **Verify dispatch infrastructure** — check that the dispatch script and parsing tools are available:
   a. Check `$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh` exists and is executable
   b. Check `jq --version` via Bash (required for Tier 1 JSON parsing)
   c. Check `python3 --version` via Bash (required for Tier 2 partial recovery)
   d. If dispatch script is missing → set all `cli_availability` values to `false`, log error: `"dispatch-cli-agent.sh not found — all CLI dispatches disabled"`, skip to Section 1.7b
   e. If `jq` missing → log warning: `"jq not found — Tier 1 JSON parsing unavailable, Tier 2+ fallback will be used"`
   f. If `python3` missing → log warning: `"python3 not found — Tier 2 partial recovery unavailable"`
6. For each CLI name from the `cli_feature_mapping` list:
   a. Read `$CLAUDE_PLUGIN_ROOT/config/cli_clients/{cli_name}.json`
   b. Extract the `command` field (e.g., `"codex"`)
   c. Run a smoke test: `$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh --cli {command} --role smoke_test --prompt-file /dev/null --output-file /tmp/cli-smoke-{cli_name}.txt --timeout 30`
   d. If exit code is 0 or 1 (CLI found, dispatch works): set `cli_availability[cli_name] = true`
   e. If exit code is 3 (CLI not found): set `cli_availability[cli_name] = false`, log warning: `"CLI '{cli_name}' not available — CLI options using this CLI will fall back to native behavior"`
   f. If exit code is 2 (timeout) on a smoke test: set `cli_availability[cli_name] = true` (CLI exists but was slow), log note

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
cli_availability:
  codex: true
  gemini: false
dispatch_infrastructure:
  script_available: true
  jq_available: true
  python3_available: true
```

### Cost

1 dispatch script smoke test per CLI in `cli_feature_mapping` (~3-5s total). Skipped entirely when `features.external_models` is `false`.

## 1.7b CLI Circuit Breaker Initialization

> Conditional: Only when `features.circuit_breaker` is `true` (resolved from profile in Section 1.9).
> If false, set `cli_circuit_state: null` in the summary and skip.

Initialize the circuit breaker state for all detected CLIs:

```yaml
cli_circuit_state:
  codex: {consecutive_failures: 0, status: "closed"}
  gemini: {consecutive_failures: 0, status: "closed"}
```

Only include CLIs where `cli_availability.{cli_name}` is `true`. Omit unavailable CLIs.

## 1.7c CLI Instruction File Management

> Conditional: Only when `features.external_models` is `true` (resolved from profile in Section 1.9).
> If false, set `agents_md_status: "disabled"` and `gemini_md_status: "disabled"` in summary, skip to Section 1.9.

Manage AGENTS.md and GEMINI.md files at PROJECT_ROOT. These files carry shared behavioral standards that Codex CLI and Gemini CLI natively load on every invocation.

File definitions (inlined — no config read needed):
- **agents_md**: target=`AGENTS.md`, marker_prefix=`pi-codex`, shared_content=`config/cli_clients/shared/cli-instruction-shared.md`, cli_specific=`config/cli_clients/shared/codex-instruction-extra.md`
- **gemini_md**: target=`GEMINI.md`, marker_prefix=`pi-gemini`, shared_content=`config/cli_clients/shared/cli-instruction-shared.md`, cli_specific=`config/cli_clients/shared/gemini-instruction-extra.md`

### Procedure

For each instruction file (agents_md, gemini_md) using the definitions above:

1. **Read source content**: Read `$CLAUDE_PLUGIN_ROOT/{shared_content}` and `$CLAUDE_PLUGIN_ROOT/{cli_specific}` (using the inlined definitions above)
2. **Build expected content**: Concatenate shared + CLI-specific content, wrapped in markers:
   ```
   <!-- {marker_prefix}-begin -->
   ## CLI Agent Standards (managed by product-implementation)

   {shared_content}

   {cli_specific_content}
   <!-- {marker_prefix}-end -->
   ```
3. **Read target file**: Read `{PROJECT_ROOT}/{target}` (AGENTS.md or GEMINI.md)
4. **Apply lifecycle logic**:
   - **File doesn't exist** → Create with managed section only → Status: `"created"`
   - **File exists, marker NOT found** → Append managed section at end of file → Status: `"appended"`
   - **File exists, marker found** → Compare content between markers with expected:
     - If different → Replace in-place (preserve content outside markers) → Status: `"updated"`
     - If same → Status: `"unchanged"`
5. **Log result**: `"[{timestamp}] {target}: {status}"`

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
agents_md_status: "created"      # "created" | "appended" | "updated" | "unchanged" | "disabled"
gemini_md_status: "created"      # "created" | "appended" | "updated" | "unchanged" | "disabled"
```

### Cost

2 file reads + 0-2 file writes (~1s total). Skipped entirely when `features.external_models` is `false`.

## 1.9 Profile Resolution

> **EXECUTE FIRST:** This section must run before Sections 1.5b, 1.6a, 1.6e, 1.6g, 1.7a, 1.7b, and 1.7c.
> It resolves all feature flags from the selected profile and writes them to the summary so downstream
> sections can gate on `features.*` instead of reading config directly.

Resolve profile, autonomy, vertical agent type, and all feature flags from `profile-definitions.yaml`. This replaces the former `quality_preset` + `external_models` + `autonomy_policy` three-question flow with a single profile-driven resolution.

### Procedure

**Step 1 — Read inputs:**
- Read `profile` and `autonomy` from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`
- Read all profile definitions from `$CLAUDE_PLUGIN_ROOT/config/profile-definitions.yaml`

**Step 2 — Profile Resolution:**
- If `ralph_mode` is `true` AND `profile` is `null`: use `ralph.default_profile` from `profile-definitions.yaml` (typically `"standard"`)
- If `profile` is `null` (and not ralph mode):
  - Set `status: needs-user-input`, `block_reason`: "What quality profile should I use?"
  - Options: `"Standard (Recommended)"`, `"Thorough"`, `"Quick"`
  - Map: Standard → `standard`, Thorough → `thorough`, Quick → `quick`
- Validate `profile` matches a key in `profile-definitions.yaml`; if not, log warning and default to `standard`
- Look up the validated profile → extract its full `features` map and `cli_features` list

**Step 3 — Autonomy Resolution:**
- If `autonomy` is `null`: use the profile's `default_autonomy` from `profile-definitions.yaml`
- If `ralph_mode` is `true`: override to `"auto"` (regardless of config or profile default)
- Validate `autonomy` is one of: `"auto"`, `"interactive"`
- Log: `"Autonomy: {value} ({source: config / profile default / ralph override})"`

**Step 4 — Vertical Agent Resolution:**
- Read `detected_domains` (written by Section 1.6; if 1.6 hasn't run yet, use `[]`)
- Read `vertical_agents` priority-order list from `profile-definitions.yaml`
- Apply first-match wins:
  - If any of `android`, `compose`, `kotlin`, `kotlin_async`, `gradle` in `detected_domains` → `android-developer`
  - Else if `web_frontend` in `detected_domains` → `frontend-developer`
  - Else if any of `api`, `database` in `detected_domains` → `backend-developer`
  - Else → `developer`
- Store as `vertical_agent_type`

**Step 5 — CLI Features Resolution:**
- Read `cli_features` list from the selected profile definition
- If `features.external_models` is `false` (from profile) → `cli_features_enabled: []`
- Otherwise → `cli_features_enabled: [{profile's cli_features list}]`

**Step 6 — UAT Strategy Resolution** (when `features.uat_execution` is `true`):
- Read `uat_engine_strategies` from `profile-definitions.yaml`
- If `ralph_mode` is `true`: use `"subagent_only"` (no user interaction)
- If no strategy configured: set `status: needs-user-input` with engine options
- Resolve `uat_engine_per_phase` and `uat_engine_full_sweep` from selected strategy definition
- Store as `uat_strategy`, `uat_engine_per_phase`, `uat_engine_full_sweep`

**Step 7 — Log resolved configuration:**
`"Profile: {profile} | Autonomy: {autonomy} | External models: {features.external_models} | Vertical agent: {vertical_agent_type} | CLI features: {cli_features_enabled}"`

### Output

Write the following fields to the Stage 1 summary YAML frontmatter (see Section 1.10). These fields are the authoritative source for all downstream stages and coordinators — never read individual config booleans after this point.

```yaml
profile: "standard"
autonomy: "interactive"
vertical_agent_type: "android-developer"
features:
  per_phase_review: true
  output_verifier: true
  code_simplification: true
  uat_execution: true
  figma_parity: true
  research_mcp: true
  project_setup: true
  stances: true
  convergence: true
  cove: true
  context_protocol: true
  circuit_breaker: true
  external_models: true
  doc_judge: true
  stage5_docs: true
  stage6_retro: true
  app_launch_gate: true
cli_features_enabled: ["test_augmenter_secondary", "spec_validator", "ux_test_reviewer"]
codex_model: null        # from implementation-config.yaml cli.codex_model (null = use CLI default)
codex_effort: "medium"   # from implementation-config.yaml cli.codex_effort
uat_strategy: "hybrid"
uat_engine_per_phase: "subagent"
uat_engine_full_sweep: "cli"
```

### Impact

- `features.*` replaces all individual config boolean reads in Sections 1.5b, 1.6a-1.6g, 1.7a-1.7c
- `autonomy` replaces `autonomy_policy` throughout all downstream stages
- `vertical_agent_type` is used by Stage 2 coordinator for agent selection (Section 2.0)
- `cli_features_enabled` is the authoritative list of CLI features active for this run
- When `features.external_models` is `false`, Sections 1.7a and 1.7c are skipped entirely

## 1.9c Pre-Summary Verification Checklist

Before writing the Stage 1 summary (Section 1.10), verify that all probe sections were executed. This checklist prevents silent gate bypass caused by LLM compliance degradation on long instruction files.

**Mandatory:** Review each row. If a section was NOT executed and is not skipped by a valid condition, GO BACK and execute it before proceeding.

| Section | Field Written | Valid Skip Condition | Executed? |
|---------|--------------|---------------------|-----------|
| 1.9 Profile Resolution | `profile`, `autonomy`, `features.*`, `vertical_agent_type` | *(no valid skip — always execute first)* | ☐ |
| 1.5b Project Setup | `project_setup.status` | `features.project_setup: false` OR `ralph_mode: true` OR already analyzed | ☐ |
| 1.6 Domain Detection | `detected_domains` | *(no valid skip — always execute)* | ☐ |
| 1.6a MCP Availability | `mcp_availability` | `features.research_mcp: false` | ☐ |
| 1.6b URL Extraction | `extracted_urls` | `features.research_mcp: false` OR `ref_available: false` | ☐ |
| 1.6c Library Pre-Resolution | `resolved_libraries` | `features.research_mcp: false` OR `context7_available: false` | ☐ |
| 1.6d Private Doc Discovery | `private_doc_urls` | `features.research_mcp: false` OR `ref_available: false` | ☐ |
| 1.6e Mobile Device Check | `mobile_mcp_available` | `features.uat_execution: false` | ☐ |
| 1.6f Plugin Availability | `plugin_availability` | *(no valid skip — always execute)* | ☐ |
| 1.6g Figma Availability | `figma_available` | No UI domains detected OR `features.figma_parity: false` | ☐ |
| 1.7a CLI Availability | `cli_availability` | `features.external_models: false` | ☐ |
| 1.7b Circuit Breaker Init | `cli_circuit_state` | `features.circuit_breaker: false` | ☐ |
| 1.7c CLI Instruction Files | `agents_md_status`, `gemini_md_status` | `features.external_models: false` | ☐ |

**RULE:** If ANY row with "no valid skip" is unchecked, HALT and execute the missing section. For rows with valid skip conditions, verify the skip condition actually applies before marking as skipped.

## 1.10 Write Stage 1 Summary

After completing all setup steps, write the summary to `{FEATURE_DIR}/.stage-summaries/stage-1-summary.md`:

```yaml
---
stage: "1"
stage_name: "Setup & Context Loading"
checkpoint: "SETUP"
status: "completed"
artifacts_written: []
summary: |
  Loaded context for {FEATURE_NAME}. Found {N} phases with {M} tasks.
  Required files: tasks.md, plan.md. Optional files loaded: {list}.
  Expected files missing: {list or "none"}.
  Test cases: {available with N specs / not available}.
  Project setup: {applied (N categories) / skipped / disabled}.
  {Resume status if applicable}.
flags:
  block_reason: null
  test_cases_available: {true/false}
detected_domains: [{list of matched domain keys, e.g., "kotlin", "api"}]  # from Section 1.6
cli_availability:              # from Section 1.7a (empty {} if no CLI options enabled)
  codex: {true/false}
  gemini: {true/false}
mcp_availability:           # from Section 1.6a (all false if features.research_mcp is false)
  ref: {true/false}
  context7: {true/false}
  tavily: {true/false}
extracted_urls: [{list of doc URLs from planning artifacts}]  # from Section 1.6b
resolved_libraries:         # from Section 1.6c
  - name: "{library_name}"
    library_id: "{context7_library_id}"
private_doc_urls: [{list of private doc URLs}]  # from Section 1.6d
figma_available: {true/false}  # from Section 1.6g (false if no UI domains, disabled, or Desktop Bridge not connected)
mobile_mcp_available: {true/false}  # from Section 1.6e (false if UAT config disabled or no emulator)
mobile_device_name: "{name or null}"  # from Section 1.6e (first available emulator device)
plugin_availability:             # from Section 1.6f
  code_review: {true/false}
project_setup:                  # from Section 1.5b (all null/disabled if features.project_setup is false)
  status: "{applied/skipped/disabled}"
  categories_applied: [{list or empty}]
  categories_skipped: [{list or empty}]
  build_system: "{type or null}"
  build_command: "{command or null}"
  test_command: "{command or null}"
  formatter: "{command or null}"
  active_hooks: [{list of hook names, existing + new}]
  architecture_pattern: "{pattern or null}"
  detected_languages: [{list}]
  detected_frameworks: [{list}]
ralph_mode: {true/false}  # from Section 1.0b (true if .claude/ralph-loop.local.md exists)
profile: "{standard/thorough/quick}"  # from Section 1.9 (user-selected or ralph default)
autonomy: "{auto/interactive}"         # from Section 1.9 (from profile default or ralph override)
vertical_agent_type: "{android-developer/frontend-developer/backend-developer/developer}"  # from Section 1.9
features:                  # from Section 1.9 (authoritative — do NOT read individual config booleans after this)
  per_phase_review: {true/false}
  output_verifier: {true/false}
  code_simplification: {true/false}
  uat_execution: {true/false}
  figma_parity: {true/false}
  research_mcp: {true/false}
  project_setup: {true/false}
  stances: {true/false}
  convergence: {true/false}
  cove: {true/false}
  context_protocol: {true/false}
  circuit_breaker: {true/false}
  external_models: {true/false}
  doc_judge: {true/false}
  stage5_docs: {true/false}
  stage6_retro: {true/false}
  app_launch_gate: {true/false}
cli_features_enabled: [{list of enabled CLI feature keys}]  # from Section 1.9
codex_model: {null or "model-name"}   # from implementation-config.yaml cli.codex_model
codex_effort: "{medium/high/low}"     # from implementation-config.yaml cli.codex_effort
uat_strategy: "{hybrid/subagent_only/cli_only or null}"  # from Section 1.9
uat_engine_per_phase: "{subagent/cli or null}"           # from Section 1.9
uat_engine_full_sweep: "{subagent/cli or null}"          # from Section 1.9
cli_circuit_state: null   # from Section 1.7b (null if features.circuit_breaker is false)
agents_md_status: "{created/appended/updated/unchanged/disabled}"  # from Section 1.7c
gemini_md_status: "{created/appended/updated/unchanged/disabled}"  # from Section 1.7c
# IF features.context_protocol is true:
context_contributions:
  key_decisions:
    - text: "Profile: {profile} | Autonomy: {autonomy}"
      confidence: "HIGH"
    - text: "Planning artifacts: {count} loaded ({list})"
      confidence: "HIGH"
  open_issues: []
  risk_signals:
    # Populate from expected-file warnings (e.g., "design.md missing")
# ELSE:
# context_contributions: null
---
## Context for Next Stage

- PROJECT_ROOT: {PROJECT_ROOT}
- FEATURE_NAME: {FEATURE_NAME}
- FEATURE_DIR: {FEATURE_DIR}
- TASKS_FILE: {TASKS_FILE}
- Total phases: {N}
- Total tasks: {M}
- Phases remaining: {list}
- Resume from: {phase_name or "beginning"}
- Ralph mode: {true (autonomous — no user interaction) / false (interactive)}
- Profile: {profile} | Autonomy: {autonomy} | Vertical agent: {vertical_agent_type}
- Features enabled: {comma-separated list of true features from features.*}
- CLI features: {cli_features_enabled list or "none"}
- Project setup: {status} — build={build_system}, languages={list}, frameworks={list}, hooks={N active} (or "disabled")
- Detected domains: {list, e.g., ["kotlin", "compose", "api"]}
- CLI availability: {map, e.g., codex=true, gemini=false or "skipped — external_models disabled"}
- MCP availability: ref={true/false}, context7={true/false}, tavily={true/false} (or "all disabled — research_mcp feature off")
- Extracted URLs: {count} documentation URLs from planning artifacts (or "disabled")
- Resolved libraries: {count} Context7 library IDs pre-resolved (or "disabled")
- Private doc URLs: {count} private documentation sources (or "disabled")
- Figma: {available / not available} (or "no UI domains" or "feature disabled")
- Mobile MCP: {available with device "{name}" / not available} (or "UAT feature disabled")
- UAT strategy: {uat_strategy} — per-phase={uat_engine_per_phase}, full-sweep={uat_engine_full_sweep} (or "N/A")
- Plugin availability: code-review={true/false}
- CLI circuit breaker: {initialized for N CLIs / disabled}
- CLI instruction files: AGENTS.md={status}, GEMINI.md={status} (or "disabled")
- Context protocol: {enabled with initial contributions / disabled}

## Planning Artifacts Summary

| File | Status | Key Content |
|------|--------|-------------|
| `tasks.md` | Required — loaded | {N} phases, {M} tasks |
| `plan.md` | Required — loaded | Tech stack: {stack}, {N} files planned |
| `design.md` | {Loaded / Missing (expected)} | {1-line summary or "N/A"} |
| `test-plan.md` | {Loaded / Missing (expected)} | {1-line summary or "N/A"} |
| `test-strategy.md` | {Loaded / Not found} | {1-line summary or "N/A"} |
| `spec.md` | {Loaded / Not found} | {1-line summary or "N/A"} |
| `contract.md` | {Loaded / Not found} | {1-line summary or "N/A"} |
| `data-model.md` | {Loaded / Not found} | {1-line summary or "N/A"} |
| `research.md` | {Loaded / Not found} | {1-line summary or "N/A"} |
| `test-cases/` | {Available ({N} specs) / Not found} | {Level breakdown or "N/A"} |
| `analysis/task-test-traceability.md` | {Loaded / Not found} | {1-line summary or "N/A"} |

## Context File Summaries

For each loaded optional/expected file, provide a 1-line summary of its key content to give downstream coordinators and agents quick context without re-reading full files:

- **spec.md**: {1-line summary, e.g., "3 user stories covering registration, login, and password reset"}
- **design.md**: {1-line summary, e.g., "Clean architecture with 4 layers, PostgreSQL + Redis stack"}
- **contract.md**: {1-line summary, e.g., "5 REST endpoints, JWT auth, OpenAPI 3.0 format"}
- **data-model.md**: {1-line summary, e.g., "4 entities: User, Session, Token, AuditLog with relations"}
- **research.md**: {1-line summary, e.g., "Chose bcrypt over argon2 for password hashing, Redis for sessions"}
- **test-plan.md**: {1-line summary, e.g., "V-Model strategy: 12 e2e, 25 integration, 40 unit tests planned"}
- **test-strategy.md**: {1-line summary, e.g., "Specify's strategic analysis: 5 risks, 12 testable ACs, 3 critical journeys"}
- *(Omit lines for files that were not found)*

## Test Specifications

*(This section is only present if `test_cases_available: true`)*

- **Test cases directory**: `{FEATURE_DIR}/test-cases/`
- **Specs by level**:
  - E2E: {count} specs
  - Integration: {count} specs
  - Unit: {count} specs
  - UAT: {count} specs
- **Total test IDs discovered**: {count}
- **Traceability file**: {Loaded / Not found} (`analysis/task-test-traceability.md`)
- **Cross-validation**: {All test IDs in tasks.md have matching specs / {N} orphaned references}

## Operational Learnings

*(This section is only present if `ralph_mode: true` AND learnings file exists with entries)*

Learnings from previous ralph iterations (fail→succeed patterns). Coordinators should
consider these when encountering similar situations.

{operational_learnings — up to 10 most recent entries from .implementation-learnings.local.md}

## Stage Log

Use ISO 8601 timestamps with seconds precision per `config/implementation-config.yaml` `timestamps` section (e.g., `2026-02-10T14:30:45Z`). Never round to hours or minutes.

- [{timestamp}] Ralph mode: {true — autonomous execution / false — interactive} (from Section 1.0b)
- [{timestamp}] Branch parsed: {branch_name}
- [{timestamp}] Context loaded: {N} phases, {M} tasks
- [{timestamp}] Expected file warnings: {list or "none"}
- [{timestamp}] Test cases: {discovered N specs / not available}
- [{timestamp}] Project setup: {status} ({N categories applied, M skipped} or "disabled" or "skipped — already applied")
- [{timestamp}] Profile resolved: {profile} | Autonomy: {autonomy} | Vertical agent: {vertical_agent_type}
- [{timestamp}] Features: {N} enabled ({comma-separated list}) | CLI features: {cli_features_enabled}
- [{timestamp}] Domain detection: {detected_domains list}
- [{timestamp}] CLI availability: {map, e.g., codex=true, gemini=false or "skipped — external_models disabled"}
- [{timestamp}] MCP availability: ref={bool}, context7={bool}, tavily={bool} (or "skipped — research_mcp feature off")
- [{timestamp}] URL extraction: {N} URLs extracted from planning artifacts (or "skipped")
- [{timestamp}] Library pre-resolution: {N} libraries resolved via Context7 (or "skipped")
- [{timestamp}] Private docs: {N} private doc URLs discovered (or "skipped")
- [{timestamp}] Figma probe: {available / not available / no UI domains / feature disabled}
- [{timestamp}] Mobile MCP probe: {available with device "{name}" / not available / UAT feature disabled}
- [{timestamp}] Plugin availability: code-review={true/false}
- [{timestamp}] Circuit breaker: {initialized for N CLIs / feature disabled}
- [{timestamp}] CLI instruction files: AGENTS.md={status}, GEMINI.md={status} (or "skipped — external_models disabled")
- [{timestamp}] Context protocol: {enabled / disabled}
- [{timestamp}] Lock acquired
- [{timestamp}] State initialized / resumed from Stage {S}
```
