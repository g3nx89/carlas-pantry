---
stage: "1"
section: "1.5b"
section_name: "Project Setup Analysis"
delegation: "subagent-delegated"
prior_sections: ["1.1", "1.2", "1.3", "1.4", "1.5"]
artifacts_read:
  - "plan.md (already loaded)"
  - "tasks.md (already loaded)"
  - "PROJECT_ROOT build files, .claude/, CLAUDE.md, .mcp.json"
artifacts_written:
  - "{FEATURE_DIR}/.project-setup-analysis.local.md"
  - "{FEATURE_DIR}/.project-setup-proposal.local.md (conditional)"
  - ".claude/hooks/*.sh (conditional)"
  - ".claude/settings.json (conditional, merged)"
  - "CLAUDE.md (conditional, appended)"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml"
---

# Stage 1 Section 1.5b: Project Setup Analysis

> **Purpose:** Analyze the target project's structure, existing Claude configuration, and implementation plan to propose and apply configuration improvements that enhance implementation quality.

> **Pattern:** Subagent-Delegated Context Injection — throwaway subagents read project files and write compact analysis; the orchestrator reads only the compact output.

## CRITICAL RULES

1. **APPEND-ONLY** — NEVER overwrite existing configuration files (hooks, CLAUDE.md, .mcp.json, settings.json). Only ADD new entries.
2. **BACKUP FIRST** — Before modifying `.claude/settings.json`, create `.claude/settings.json.bak` (if `project_setup.backup_settings_json` is `true` in config).
3. **POSIX-COMPATIBLE** — Generated hook scripts must work on macOS and Linux. Avoid GNU-specific flags. Use `#!/usr/bin/env bash`.
4. **EXISTING HOOKS PRESERVED** — If a hook script with the same name already exists, do NOT overwrite it. Skip and log.
5. **USER DECIDES** — The orchestrator presents all recommendations; the user selects which categories to apply. Never auto-apply.

---

## Section A — Analysis Checklist

The analysis subagent scans PROJECT_ROOT for the following. Cap at `project_setup.analysis_budget.max_files_to_scan` files total (default: 50).

### A.1 Build System Detection

Scan PROJECT_ROOT (depth 0-2) for build system markers:

| Marker File | Build System | Build Command (default) | Test Command (default) |
|-------------|-------------|------------------------|----------------------|
| `build.gradle.kts` or `build.gradle` | Gradle (Kotlin DSL / Groovy) | `./gradlew assembleDebug` or `./gradlew build` | `./gradlew test` |
| `package.json` | npm/yarn/pnpm/bun | `npm run build` | `npm test` |
| `Cargo.toml` | Cargo (Rust) | `cargo build` | `cargo test` |
| `pyproject.toml` or `setup.py` | Python (Poetry/pip/setuptools) | `poetry build` or `pip install -e .` | `pytest` or `python -m pytest` |
| `pom.xml` | Maven | `mvn package` | `mvn test` |
| `CMakeLists.txt` | CMake | `cmake --build .` | `ctest` |
| `Makefile` | Make | `make` | `make test` |
| `go.mod` | Go modules | `go build ./...` | `go test ./...` |
| `*.sln` or `*.csproj` | .NET | `dotnet build` | `dotnet test` |

If multiple build systems found (e.g., Gradle + npm in a monorepo), record ALL and note the primary (the one at depth 0).

### A.2 Language Detection

Count file extensions in source directories (`src/`, `app/`, `lib/`, `cmd/`, `pkg/`, `internal/`). Report top 3 languages by file count.

| Extension(s) | Language |
|--------------|----------|
| `.kt`, `.kts` | Kotlin |
| `.java` | Java |
| `.ts`, `.tsx` | TypeScript |
| `.js`, `.jsx` | JavaScript |
| `.py` | Python |
| `.rs` | Rust |
| `.go` | Go |
| `.swift` | Swift |
| `.cs` | C# |
| `.rb` | Ruby |
| `.dart` | Dart |

### A.3 Framework Detection

Scan for framework-specific markers:

| Framework | Markers |
|-----------|---------|
| Jetpack Compose | `@Composable` in `.kt` files, `compose` in build dependencies |
| Hilt/Dagger | `@HiltAndroidApp`, `@Inject`, `hilt` in build dependencies |
| Room | `@Database`, `@Dao`, `room` in build dependencies |
| React | `react` in `package.json` dependencies, `.tsx` files |
| Next.js | `next.config.js` or `next.config.ts` |
| Vue | `vue` in `package.json` dependencies, `.vue` files |
| Svelte | `svelte.config.js`, `.svelte` files |
| Angular | `angular.json` |
| Django | `manage.py`, `django` in requirements |
| Flask | `flask` in requirements |
| FastAPI | `fastapi` in requirements |
| Rails | `Gemfile` with `rails`, `config/routes.rb` |
| Spring | `@SpringBootApplication`, `spring` in build dependencies |

### A.4 Test Infrastructure Detection

| Indicator | Test Framework |
|-----------|---------------|
| JUnit 5 imports (`org.junit.jupiter`) | JUnit 5 |
| JUnit 4 imports (`org.junit.Test`) | JUnit 4 |
| `jest.config.*` or `jest` in package.json | Jest |
| `vitest.config.*` | Vitest |
| `pytest.ini` or `pyproject.toml [tool.pytest]` | Pytest |
| `mocha` in package.json | Mocha |
| `src/test/` or `tests/` directory | Test directory present |
| `src/androidTest/` | Android instrumented tests |
| MockK, Mockito imports | Mocking framework |
| Turbine imports | Flow testing (Kotlin) |

Note: Also check for test runner plugins (e.g., `testOptions` in build.gradle.kts).

### A.5 Code Quality Tool Detection

| Indicator | Tool | Category |
|-----------|------|----------|
| `detekt.yml` or `detekt` in build plugins | Detekt | Kotlin linter |
| `.eslintrc*` or `eslint.config.*` | ESLint | JS/TS linter |
| `biome.json` | Biome | JS/TS linter+formatter |
| `.prettierrc*` | Prettier | JS/TS formatter |
| `ruff.toml` or `[tool.ruff]` in pyproject.toml | Ruff | Python linter |
| `clippy` in Cargo config | Clippy | Rust linter |
| `rustfmt.toml` | rustfmt | Rust formatter |
| `.editorconfig` | EditorConfig | Cross-language editor config |
| `ktfmt` or `ktlint` in build config | ktfmt/ktlint | Kotlin formatter |
| `lint.xml` or `lintOptions` in build.gradle | Android Lint | Android linter |
| `.commitlintrc*` | commitlint | Commit message linter |

### A.6 Claude Configuration Audit

Read and evaluate:

| File | What to Check |
|------|--------------|
| `CLAUDE.md` | Exists? Sections present (build commands, architecture, conventions, patterns, MCP notes)? Completeness score (0-5 sections). |
| `.claude/settings.json` | Exists? Hooks configured? Count by type (PreToolUse, PostToolUse, SessionStart). List hook script names. |
| `.claude/settings.local.json` | Exists? MCP overrides? |
| `.mcp.json` | Exists? Servers configured? List server names. |
| `constitution.md` or equivalent | Exists? Lists architectural gates or principles? |

---

## Section B — Hook Pattern Catalog

For each hook category below, the generator creates a shell script ONLY if:
1. The category is enabled in `project_setup.hooks.{category}` config
2. No script with the same name already exists in `.claude/hooks/`
3. The recommendation conditions are met (based on analysis)

### B.1 Spec Protection (`protect-specs.sh`)

- **Event:** PreToolUse — Edit, Write
- **When:** Always recommended during implementation
- **Purpose:** Prevent modification of planning artifacts (spec.md, design.md, plan.md, test-plan.md, tasks.md, test-cases/)
- **Variables:** `FEATURE_DIR` (from plan context)
- **Template pattern:**
  ```bash
  #!/usr/bin/env bash
  # protect-specs.sh — Prevent modification of planning artifacts
  # Generated by implement skill project setup (Section 1.5b)
  set -euo pipefail
  INPUT=$(cat)
  FILE_PATH=$(echo "$INPUT" | jq -r '.file_path // empty')
  if [ -z "$FILE_PATH" ]; then exit 0; fi
  # Protected paths (customize as needed)
  PROTECTED=("spec.md" "design.md" "plan.md" "test-plan.md" "test-cases/")
  for p in "${PROTECTED[@]}"; do
    if [[ "$FILE_PATH" == *"$p"* ]]; then
      echo "BLOCKED: $FILE_PATH is a planning artifact. Do not modify during implementation."
      exit 2
    fi
  done
  ```

### B.2 Language Enforcement (`enforce-language.sh`)

- **Event:** PreToolUse — Write, Edit
- **When:** Project uses a single primary language (e.g., Kotlin-only, TypeScript-only)
- **Purpose:** Block creation of files in non-primary languages
- **Variables:** `ALLOWED_EXTENSIONS`, `FORBIDDEN_EXTENSIONS`, `FORBIDDEN_DIRS`
- **Example (Kotlin-only):** Block `.java` files in `src/main/`, block `res/layout/` XML files

### B.3 TDD Reminder (`tdd-reminder.sh`)

- **Event:** PreToolUse — Write, Edit
- **When:** Always recommended (TDD is a Critical Rule)
- **Purpose:** Warn when creating/editing implementation files that lack corresponding test files
- **Variables:** `IMPL_PATTERNS` (e.g., `ViewModel`, `UseCase`, `Repository`), `TEST_SUFFIX` (e.g., `Test.kt`)

### B.4 Safety Guards (`safe-bash.sh`)

- **Event:** PreToolUse — Bash
- **When:** Always recommended
- **Purpose:** Block destructive operations (rm -rf /, force push to main, git reset --hard)
- **Near-universal template** — language/framework agnostic

### B.5 Commit Format (`conventional-commits.sh`)

- **Event:** PreToolUse — Bash (on `git commit`)
- **When:** Project uses conventional commits (detected via `.commitlintrc` or existing commit history pattern)
- **Purpose:** Validate commit message format: `<type>(<scope>): <description>`
- **Variables:** `TYPES` (feat, fix, docs, style, refactor, perf, test, chore, ci, build, revert)

### B.6 Code Formatting (`auto-format.sh`)

- **Event:** PostToolUse — Write, Edit
- **When:** Formatter detected in project (ktfmt, prettier, black, rustfmt, etc.)
- **Purpose:** Auto-format modified files after Claude writes them
- **Variables:** `FORMATTER_CMD`, `FILE_GLOB`, `STYLE_ARGS`, `EXCLUDE_DIRS`
- **Example (Kotlin):** `ktfmt --kotlinlang-style {file}`
- **Example (TypeScript):** `npx prettier --write {file}`

### B.7 Architecture Boundaries (`check-architecture.sh`)

- **Event:** PostToolUse — Write, Edit
- **When:** Plan describes layered architecture (Clean Architecture, hexagonal, etc.)
- **Purpose:** Validate import/dependency directions between layers
- **Variables:** `LAYER_RULES` (e.g., `domain → cannot import data, presentation`)
- **Highly project-specific** — generator reads plan.md architecture section to derive rules

### B.8 Build Output Analysis (`gradle-output-analysis.sh` / `build-output-analysis.sh`)

- **Event:** PostToolUse — Bash (on build/test commands)
- **When:** Build system detected
- **Purpose:** Scan build output for deprecations, failures, warnings, lint issues
- **Variables:** `BUILD_TOOL`, `WARNING_PATTERNS`

### B.9 Session Context (`session-context.sh`)

- **Event:** SessionStart — CONTEXT type
- **When:** Project has a constitution, progress tracking file, or multi-phase plan
- **Purpose:** Inject current implementation progress, key principles, and patterns at session start
- **Variables:** `FEATURE_DIR`, `CONSTITUTION_PATH`, `KEY_PATTERNS`

---

## Section C — CLAUDE.md Completeness Rubric

Score the existing CLAUDE.md (or absence) against these sections. Each missing section is a recommendation.

| Section | What It Should Contain | Priority |
|---------|----------------------|----------|
| **Build & Test Commands** | How to build, test, lint the project. Both CLI and MCP commands if applicable. | HIGH |
| **Project Architecture** | Module structure, layers, key patterns (e.g., Clean Architecture, MVVM) | HIGH |
| **Key Conventions** | Naming, formatting, import ordering, package structure | MEDIUM |
| **Common Patterns & Anti-Patterns** | Framework-specific guidance (e.g., Compose recomposition, coroutine scoping) | MEDIUM |
| **MCP Server Usage** | Which MCP servers are available and when to use them | LOW (only if MCP servers exist) |
| **Test Strategy** | Test framework, test directory structure, what to test and how | MEDIUM |

**Scoring:**
- 0-1 sections present: "CLAUDE.md needs significant improvement"
- 2-3 sections present: "CLAUDE.md has gaps that may reduce implementation quality"
- 4-5 sections present: "CLAUDE.md is well-configured"
- 6 sections present: "CLAUDE.md is comprehensive"

When generating additions, the generator writes ONLY the missing sections, clearly delimited:

```markdown
<!-- BEGIN: implement-skill-setup (generated {ISO_DATE}) -->
## [Section Title]
[Content derived from plan.md and project analysis]
<!-- END: implement-skill-setup -->
```

---

## Section D — Analysis Output Format

The analysis subagent writes `{FEATURE_DIR}/.project-setup-analysis.local.md` in this format:

```yaml
---
analysis_version: 1
analyzed_at: "{ISO_TIMESTAMP}"
project_root: "{PROJECT_ROOT}"
feature_dir: "{FEATURE_DIR}"

# Build system
build_system:
  type: "gradle_kts"              # gradle_kts | gradle_groovy | npm | yarn | pnpm | bun | cargo | poetry | pip | maven | cmake | make | go | dotnet | unknown
  version: "AGP 9.0.0"           # If detectable from config
  build_command: "./gradlew assembleDebug"
  test_command: "./gradlew testDebugUnitTest"
  config_files: ["build.gradle.kts", "settings.gradle.kts", "gradle/libs.versions.toml"]

# Languages (top 3 by file count)
languages:
  - name: "kotlin"
    file_count: 85
    extensions: [".kt", ".kts"]
  - name: "xml"
    file_count: 12
    extensions: [".xml"]

# Frameworks detected
frameworks:
  - name: "compose"
    confidence: "high"    # high (3+ markers) | medium (1-2 markers) | low (1 ambiguous marker)
    markers_found: ["@Composable", "Compose BOM", "Material3"]
  - name: "hilt"
    confidence: "high"
    markers_found: ["@HiltAndroidApp", "@Inject", "hilt dependency"]

# Test infrastructure
test_infra:
  framework: "junit5"
  mocking: "mockk"
  additional: ["turbine", "coroutines-test"]
  test_dirs: ["src/test/", "src/androidTest/"]
  test_count_estimate: 94        # From file count or CLAUDE.md if available

# Code quality tools
code_quality:
  linters: ["detekt", "android-lint"]
  formatters: ["ktfmt"]
  editor_config: true
  ci_cd: null                    # github_actions | gitlab_ci | jenkins | null

# Existing Claude configuration
claude_config:
  claude_md:
    exists: true
    sections_present: ["build_commands", "architecture", "conventions"]
    sections_missing: ["patterns", "mcp_notes", "test_strategy"]
    completeness_score: 3        # out of 6
  hooks:
    exists: true
    count: 12
    by_type:
      PreToolUse: ["protect-specs", "enforce-kotlin-compose", "tdd-reminder", "safe-bash", "conventional-commits"]
      PostToolUse: ["ktfmt-format", "check-architecture", "compose-quality", "hilt-check", "gradle-output-analysis"]
      SessionStart: ["session-context", "compact-context"]
  mcp_servers:
    exists: true
    servers: ["gradle-mcp-server", "mobile-mcp", "sequential-thinking", "Ref"]
  constitution:
    exists: true
    path: "specs/constitution.md"
    gates_count: 10
---

## Recommendations

### CLAUDE.md Improvements (3 gaps found)

1. **[MEDIUM] Add Common Patterns section** — Plan mentions Clean Architecture, Compose patterns, and coroutine scoping. These should be documented as patterns/anti-patterns.
2. **[LOW] Add MCP Server Usage notes** — 4 MCP servers configured but CLAUDE.md doesn't document when to use each.
3. **[MEDIUM] Add Test Strategy section** — 94 tests exist with JUnit5+MockK but CLAUDE.md doesn't describe the testing approach.

### Hook Recommendations (N new hooks)

1. **[hook_name]** — [reason based on project analysis and plan]. Priority: [HIGH/MEDIUM/LOW].

*(Only list hooks NOT already present. For a well-configured project like TestRunes3-old, this may be empty.)*

### MCP Server Recommendations (N new servers)

1. **[server_name]** — [reason]. Install: `[command]`.

### Code Quality Recommendations (N new tools)

1. **[tool_name]** — [reason]. Config: `[file to create]`.
```

---

## Section E — Generator Instructions

The generator subagent receives the analysis file content and the user's selected categories. It generates configuration for ONLY the selected categories.

### E.1 Pre-Generation Checklist

1. Read `.project-setup-analysis.local.md` for project context
2. Verify `{selected_categories}` — only generate for selected categories
3. If `project_setup.backup_settings_json` is `true` and `.claude/settings.json` exists:
   - Copy `.claude/settings.json` to `.claude/settings.json.bak`
4. Create `.claude/hooks/` directory if it does not exist

### E.2 Hook Generation Rules

For each recommended hook in the selected "hooks" category:

1. **Check existence:** If `.claude/hooks/{hook_name}.sh` already exists → skip, log "Skipped: {hook_name} already exists"
2. **Generate script:** Write the hook script using the template from Section B, filling in project-specific variables from the analysis
3. **Make executable:** The script must have `#!/usr/bin/env bash` shebang
4. **Register in settings.json:**
   - Read current `.claude/settings.json` (or create minimal `{"hooks": {}}` if absent)
   - Parse JSON, find or create the appropriate event array (e.g., `hooks.PreToolUse`)
   - Append new hook entry: `{"matcher": "...", "hooks": [{"type": "command", "command": ".claude/hooks/{hook_name}.sh"}]}`
   - Write updated JSON back (preserve existing entries)

### E.3 CLAUDE.md Generation Rules

1. If CLAUDE.md does not exist → create it with all recommended sections
2. If CLAUDE.md exists → append ONLY missing sections at the end, wrapped in markers:
   ```
   <!-- BEGIN: implement-skill-setup (generated {ISO_DATE}) -->
   ...
   <!-- END: implement-skill-setup -->
   ```
3. Content for each section is derived from:
   - **Build & Test Commands:** From `build_system.build_command` and `build_system.test_command` in analysis
   - **Architecture:** From `plan.md` architecture section
   - **Conventions:** From detected formatters, linters, and `.editorconfig`
   - **Patterns:** From plan.md tech stack + known framework patterns
   - **MCP Notes:** From `.mcp.json` server list
   - **Test Strategy:** From `test_infra` in analysis + plan.md test approach

### E.4 MCP Server Recommendations

MCP servers are NOT auto-installed. The generator writes recommendations to the proposal file with installation commands. The user installs them manually.

### E.5 Code Quality Tool Recommendations

Similar to MCP — write recommendations with config file templates to the proposal file. The generator MAY create config files (e.g., `.editorconfig`) if they don't exist, but NEVER overwrites existing ones.

### E.6 Proposal File

After all generation, write `{FEATURE_DIR}/.project-setup-proposal.local.md` summarizing what was done:

```markdown
# Project Setup Proposal

Generated: {ISO_TIMESTAMP}

## Applied Changes

### Hooks Created
- `.claude/hooks/protect-specs.sh` — Protects planning artifacts
- `.claude/hooks/tdd-reminder.sh` — TDD enforcement

### CLAUDE.md Additions
- Added "Common Patterns" section
- Added "Test Strategy" section

### settings.json Updated
- Added 2 PreToolUse hooks
- Backup saved to `.claude/settings.json.bak`

## Manual Actions Required

### MCP Servers (not auto-installed)
- `gradle-mcp-server`: `npx @anthropic/mcp-gradle` — Gradle build integration
- Install and add to `.mcp.json`

### Code Quality Tools
- Consider adding `.editorconfig` with [suggested content]

## Rollback Instructions

To undo all changes:
1. Delete generated hook scripts: `rm .claude/hooks/{generated_hooks}`
2. Restore settings: `cp .claude/settings.json.bak .claude/settings.json`
3. Remove CLAUDE.md additions: delete content between `<!-- BEGIN/END: implement-skill-setup -->` markers
```

---

## Section F — User Interaction Protocol

The orchestrator (NOT the subagent) handles all user interaction.

### F.1 Category Presentation

After reading the analysis file, present findings via `AskUserQuestion`:

```
Question: "I've analyzed your project setup. Which improvements should I apply?"
Header: "Setup"
multiSelect: true
Options:
  1. "CLAUDE.md improvements" — "{N} gaps found: {list of missing sections}"
  2. "Hook configuration" — "{N} new hooks recommended: {list}"
  3. "MCP server setup" — "{N} servers recommended (manual install)"
  4. "Code quality tools" — "{N} tools recommended"
```

**Option filtering:** Only show categories that have recommendations. If the analysis finds no gaps for a category, omit it from the options. If ALL categories are empty (project is fully configured), skip the question entirely and log: "Project setup analysis found no improvements needed."

### F.2 Post-Generation Summary

After the generator completes, present a brief summary to the user (in the stage log, not a question):

```
Project setup complete: {N} hooks created, CLAUDE.md updated ({M} sections added).
See {FEATURE_DIR}/.project-setup-proposal.local.md for details and rollback instructions.
```

### F.3 Resume Behavior

On resume (state file exists with `project_setup_applied: true`):
- Skip the entire Section 1.5b
- The analysis and proposal files persist in FEATURE_DIR for reference
- Hooks and CLAUDE.md changes persist in the project (they are project-level, not feature-level)
