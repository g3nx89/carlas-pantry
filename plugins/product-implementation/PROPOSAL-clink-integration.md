# Proposal: Clink Integration for product-implementation

> **Version**: 1.1.1
> **Date**: 2026-02-12
> **Status**: Draft
> **Compatibility**: PAL MCP v9.8.x, product-implementation v2.1.0, `research_mcp` integration (f31b3a1)

## Executive Summary

This proposal introduces PAL clink (CLI-to-CLI bridge) integration into the `implement` skill, enabling multi-model delegation for code generation, testing, validation, and code review. Ten custom clink roles across nine integration options are defined, each with a specific purpose, integration point, and fallback strategy.

**Design philosophy**: Every clink integration is opt-in (`enabled: false` by default), has a fallback to native behavior, and is orchestrator-transparent (coordinators manage clink dispatch internally; the orchestrator never sees clink).

**Key constraint**: Clink agents return plain text. Coordinators remain the normalization point: they receive text from clink, parse it, and convert it to the YAML summary format expected by the orchestrator.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
   - [MCP Tool Parity](#mcp-tool-parity)
   - [Clink Tool Interface](#clink-tool-interface)
   - [Shared Clink Dispatch Procedure](#shared-clink-dispatch-procedure)
   - [Shared Severity & Output Conventions](#shared-severity--output-conventions)
   - [CLI Availability Detection (Stage 1)](#cli-availability-detection-stage-1)
   - [Relationship with Native Research MCP](#relationship-with-native-research-mcp)
2. [Project Structure](#2-project-structure)
3. [Option Catalog](#3-option-catalog)
   - [A: Phase Developer](#option-a----phase_developer)
   - [B: API Researcher](#option-b----api_researcher)
   - [C: Spec Validator](#option-c----spec_validator)
   - [D: Multi-Model Code Review](#option-d----multi-model-code-review)
   - [E: Security Reviewer](#option-e----security_reviewer)
   - [F: Fix Engineer](#option-f----fix_engineer)
   - [G: Doc Researcher](#option-g----doc_researcher)
   - [H: Test Author](#option-h----test_author)
   - [I: Test Augmenter](#option-i----test_augmenter)
4. [Unified Configuration](#4-unified-configuration)
5. [CLI Client Definitions](#5-cli-client-definitions)
6. [Impact Analysis](#6-impact-analysis)
7. [Prioritized Recommendation](#7-prioritized-recommendation)

---

## 1. Architecture Overview

### Current Hierarchy

```
Orchestrator (SKILL.md)
  |
  +-- Stage 1 (inline)
  |
  +-- Stage 2 Coordinator (Task general-purpose)
  |     +-- Developer Agent (Task product-implementation:developer) x1 per phase
  |
  +-- Stage 3 Coordinator
  |     +-- Developer Agent x1
  |
  +-- Stage 4 Coordinator
  |     +-- Developer Agent x3+ (parallel, different focus areas)
  |
  +-- Stage 5 Coordinator
        +-- Developer Agent x1
        +-- Tech-Writer Agent x1
```

### Proposed Hierarchy (with Clink)

```
Orchestrator (SKILL.md) -- unchanged
  |
  +-- Stage 1 (inline) -- unchanged
  |
  +-- Stage 2 Coordinator
  |     +-- [B] clink(gemini, api_researcher)         -- pre-research (optional)
  |     +-- [H] clink(codex, test_author)             -- test-first per phase (optional)
  |     +-- [A] clink(codex, phase_developer)          -- OR native developer agent
  |     +-- [I] clink(gemini, test_augmenter)          -- post-implementation edge cases (optional)
  |
  +-- Stage 3 Coordinator
  |     +-- Native developer agent                     -- validation (always)
  |     +-- [C] clink(gemini, spec_validator)          -- cross-model validation (parallel, optional)
  |
  +-- Stage 4 Coordinator
  |     +-- [D] clink(gemini, simplicity_reviewer)     -- OR native developer agent
  |     +-- [D] clink(codex, correctness_reviewer)     -- OR native developer agent
  |     +-- Native developer agent (conventions)       -- always native (needs codebase context)
  |     +-- [E] clink(codex, security_reviewer)        -- conditional reviewer (optional)
  |     +-- [F] clink(codex, fix_engineer)             -- on "Fix Now" (optional)
  |
  +-- Stage 5 Coordinator
        +-- [G] clink(gemini, doc_researcher)          -- pre-research (optional)
        +-- Native tech-writer agent                   -- documentation (always)
```

### Design Principles

1. **Orchestrator-transparent**: The orchestrator never invokes clink. Coordinators handle all clink dispatch internally. Summary files remain the only inter-stage communication.
2. **Opt-in with graceful degradation**: Every clink feature defaults to `enabled: false`. If clink fails or times out, the coordinator falls back to native agent behavior. The workflow never blocks on a clink failure.
3. **Output normalization**: Each clink role defines a structured output format with a `<SUMMARY>` block and parseable fields. Coordinators extract structured data; if parsing fails, raw text is included as "Unstructured Findings".
4. **CLI selection rationale**: All clink agents share the same MCP tool access as native Claude (see MCP Tool Parity below). CLI selection is based on model reasoning strengths, not tool availability:
   - **Gemini**: Large context window (1M tokens) for holistic analysis across full codebases; strong pattern recognition across large inputs
   - **Codex**: Strong code generation and editing capabilities; strict protocol following for structured output
   - **Native Claude**: Accumulated session context and codebase familiarity; strongest tool orchestration; direct access to Claude Code's Edit/Grep/Read tools

### MCP Tool Parity

All clink agents (Codex, Gemini) share the **same MCP servers** as native Claude agents. This is a consequence of the PAL MCP architecture: MCP servers are configured at the host level, not per-CLI.

**Shared MCP servers:**
- **Ref** — Documentation search and reading (session-deduplicated)
- **Context7** — Library-specific code examples and API reference
- **Tavily** — Web search, content extraction, and deep research
- **Sequential Thinking** — Structured multi-step reasoning chains
- **Figma** (desktop + API) — Design context, screenshots, metadata

**Consequence**: CLI selection is based entirely on model reasoning strengths — not tool availability. A Gemini clink agent can search Ref just as Claude can; a Codex agent can use Sequential Thinking for data flow analysis. MCP tools are additive to each CLI's native capabilities (e.g., Codex's own file tools, Gemini's native web grounding).

**Implication for role prompts**: Each role prompt includes an `## Available MCP Tools` section listing the specific MCP tools relevant to that role. Clink agents are instructed to use these tools directly rather than relying solely on their native capabilities for research and reasoning tasks.

### Clink Tool Interface

The `clink` function is a PAL MCP tool that dispatches prompts to external CLI agents. The formal interface:

```
Tool: clink (PAL MCP)

Parameters:
  prompt:              string   — Full prompt text (role prompt + injected variables)
  cli_name:            string   — CLI identifier matching a key in config/cli_clients/*.json
  role:                string   — Role name matching a key in the CLI's "roles" object
  absolute_file_paths: string[] — (Optional) Directories/files the CLI agent can access

Returns:
  stdout:  string — Raw text output from the CLI agent
  stderr:  string — Error output (non-empty indicates failure)
  exit_code: int  — 0 = success, non-zero = failure

Errors:
  - CLI not found:     exit_code 127, stderr contains "command not found"
  - API key missing:   exit_code 1, stderr contains "authentication" or "API key"
  - Timeout exceeded:  exit_code 124, stderr contains "timeout"
  - Process crash:     exit_code > 1, stderr contains stack trace or signal info
```

Coordinators call `clink()` via PAL MCP and handle the response. All error conditions are caught by the Shared Clink Dispatch Procedure (below).

### Shared Clink Dispatch Procedure

> **DRY extraction**: The dispatch + timeout + parse + fallback pattern is used by 7+ integration points. This shared procedure is parameterized to avoid duplication. It should be implemented as `references/clink-dispatch-procedure.md`.

```
FUNCTION CLINK_DISPATCH(params):
  INPUT:
    prompt:              string    — Full prompt with variables injected
    cli_name:            string    — CLI identifier (e.g., "codex", "gemini")
    role:                string    — Role name (e.g., "phase_developer")
    file_paths:          string[]  — Directories/files for the CLI agent
    timeout_ms:          int       — From config clink_dispatch.timeout_ms (default: 300000)
    fallback_behavior:   string    — "native" | "skip" | "error"
    fallback_agent:      string?   — Agent subagent_type for native fallback (null if skip)
    fallback_prompt:     string?   — Prompt for native fallback agent (null if skip)
    expected_fields:     string[]  — Fields to extract from <SUMMARY> block

  PROCEDURE:
    1. DISPATCH clink(prompt, cli_name, role, absolute_file_paths=file_paths)
       with timeout = timeout_ms

    2. IF exit_code != 0 OR timeout exceeded:
       LOG warning: "Clink dispatch failed: {cli_name}/{role} — {stderr or 'timeout'}"
       GOTO FALLBACK

    3. PARSE stdout for <SUMMARY>...</SUMMARY> block:
       - Extract text between delimiters
       - Parse as markdown with key-value pairs (format_version, then named fields)
       - For each field in expected_fields: extract value or set to null

    4. IF parsing fails (no <SUMMARY> block found OR required fields missing):
       LOG warning: "Clink output parsing failed for {cli_name}/{role}"
       SET parsed_summary = { raw_text: stdout, parsing_failed: true }
       Include raw text as "Unstructured Findings" in coordinator output
       CONTINUE (do not fallback for parse-only failures)

    5. RETURN { success: true, summary: parsed_summary, raw_output: stdout }

  FALLBACK:
    IF fallback_behavior == "native" AND fallback_agent != null:
      LOG: "Falling back to native agent: {fallback_agent}"
      result = Task(subagent_type=fallback_agent, prompt=fallback_prompt)
      RETURN { success: true, summary: parse_native_output(result), fallback: true }
    ELIF fallback_behavior == "skip":
      LOG: "Skipping clink dispatch — continuing without {role} output"
      RETURN { success: false, skipped: true }
    ELIF fallback_behavior == "error":
      SET status = "needs-user-input"
      SET block_reason = "Clink dispatch failed for {cli_name}/{role}: {error_details}"
      RETURN { success: false, error: true }
```

Coordinators invoke this procedure instead of calling clink directly. Each option's Integration Point section specifies the parameter values.

### Shared Severity & Output Conventions

All clink role prompts share these conventions. They are extracted here to avoid duplication across 10 prompt files. Each role prompt file should include `## Shared Conventions\nSee config/cli_clients/shared/severity-output-conventions.md` and the full text is injected at dispatch time by the coordinator.

#### Severity Classification (Canonical)

Sourced from `config/implementation-config.yaml` — identical to native agent severity:

- **Critical**: Breaks functionality, security vulnerability, data loss risk
- **High**: Likely to cause bugs, significant code quality issue. **ESCALATE** a finding to High (not Medium) if ANY of these apply: user-visible data corruption, implicit ordering dependency that silently produces wrong results, UI state contradiction (displayed state differs from actual state), singleton or shared-state leak across scopes, race condition with user-visible effect
- **Medium**: Code smell, maintainability concern, minor pattern violation
- **Low**: Style preference, minor optimization opportunity

#### Output Format Convention

All clink role prompts MUST include a `<SUMMARY>` block as their final output section:

```
<SUMMARY>
format_version: 1
## {Role-Specific Summary Title}
- **{Field 1}**: {value}
- **{Field 2}**: {value}
...
</SUMMARY>
```

The `format_version: 1` field enables future format evolution without breaking parsers.

#### Quality Rules (Universal)

These rules apply to ALL clink role prompts:
- Every finding must include file:line location and a specific recommendation
- Never mix opinions with verifiable facts — label each clearly
- If a behavior cannot be verified, state the limitation explicitly
- Report in severity order: Critical → High → Medium → Low

#### Available MCP Tools (Universal)

All clink agents have access to the following MCP tools. Each role prompt specifies which subset is relevant, but the full set is always available:

| Tool | Primary Use | Usage Guidance |
|------|------------|----------------|
| **Ref** (`ref_search_documentation`, `ref_read_url`) | Search and read library/framework documentation | Primary research tool. Use `ref_search_documentation` to find docs, `ref_read_url` to read specific pages. Supports private docs via `ref_src=private`. |
| **Context7** (`resolve-library-id`, `query-docs`) | Library-specific code examples and API reference | Always call `resolve-library-id` first to get library ID, then `query-docs`. Best for version-specific API signatures and code patterns. |
| **Tavily** (`tavily_search`, `tavily_extract`, `tavily_research`) | Web search, content extraction, deep research | Use `tavily_search` for quick lookups (CVEs, known bugs, current versions). Use `tavily_research` for comprehensive multi-source research. Last resort after Ref and Context7. |
| **Sequential Thinking** (`sequentialthinking`) | Structured multi-step reasoning | Use for complex data flow analysis, multi-requirement validation, systematic checklists. Supports branching and revision. |
| **Figma** (`get_design_context`, `get_screenshot`, `get_metadata`) | Design context and visual reference | Use when implementation involves UI components. Extract design tokens, layout specs, and component structure. *(Not currently referenced by any clink role prompt — available for future UI-focused roles.)* |

**Budget constraints**: Coordinators inject per-dispatch MCP tool budgets from `clink_dispatch.mcp_tool_budgets` into clink agent prompts. These budgets are **advisory** — they are guidance embedded in the prompt text, not programmatically enforced hard caps. Clink agents should use MCP tools judiciously — prefer cached/local knowledge first, escalate to MCP tools for verification or when stuck. Coordinators can verify compliance post-dispatch by counting MCP tool references in the agent's output.

### CLI Availability Detection (Stage 1)

Stage 1 setup gains a new check (Section 1.7a in `stage-1-setup.md`):

```
AFTER domain detection (Section 1.6), BEFORE writing Stage 1 summary:

1. Read clink_dispatch section from config/implementation-config.yaml
2. Collect all unique cli_name values from enabled options
3. For each cli_name:
   a. Read config/cli_clients/{cli_name}.json
   b. Run healthcheck command: {healthcheck_command} (e.g., "codex --version")
   c. If command fails or not found: set cli_available[cli_name] = false
   d. If command succeeds: set cli_available[cli_name] = true
4. Write cli_available map to Stage 1 summary YAML frontmatter:
   cli_availability:
     codex: true
     gemini: false
5. Downstream coordinators check cli_availability before dispatching clink.
   If a CLI is unavailable, skip that option (fallback behavior applies).
```

This check runs only when at least one clink option is enabled in config.

### Relationship with Native Research MCP

The `implement` skill already integrates Ref, Context7, and Tavily natively via the `research_mcp` configuration (commit f31b3a1). This raises the question: are clink research options (B: api_researcher, G: doc_researcher) redundant?

**They are complementary, not redundant.** The key differences:

| Dimension | Native `research_mcp` | Clink Research (Options B, G) |
|-----------|----------------------|-------------------------------|
| **Model** | Claude (same model as orchestrator/coordinator) | Gemini (different model, different reasoning) |
| **MCP tools** | Ref (primary), Context7 (secondary), Tavily (tertiary) | Same Ref, Context7, Tavily tools — identical access |
| **Integration** | Coordinator builds `{research_context}` block, injects into agent prompts | Clink agent performs research independently, returns structured findings |
| **Reasoning** | Claude's interpretation of documentation | Gemini's interpretation of the same documentation |
| **Value** | Baseline research coverage for all stages | Model-diverse research perspective — different model reasoning over the same sources catches different gaps |

**Why model diversity matters for research**: Two models reading the same API documentation may extract different insights. Claude might focus on the recommended patterns while Gemini notices a deprecation warning in a sidebar. This is the same principle that makes multi-model code review (Option D) valuable — independent analysis by independent models.

**Recommended interaction**:
- Native `research_mcp` provides the baseline research context for ALL stages (always active when configured)
- Clink research (B, G) provides a second, independent research pass by a different model (opt-in, additive)
- When both are enabled, coordinators merge findings (native research in `{research_context}`, clink research appended as supplementary context)
- Clink research is most valuable when the native research_mcp returns low-confidence results or when working with rapidly-evolving frameworks where model training data diverges

---

## 2. Project Structure

```
product-implementation/
+-- config/
|   +-- cli_clients/
|   |   +-- shared/
|   |   |   +-- severity-output-conventions.md  # Shared severity defs & output format (Section 1.7)
|   |   +-- gemini.json                      # Gemini CLI role definitions
|   |   +-- codex.json                       # Codex CLI role definitions
|   |   +-- gemini_api_researcher.txt        # Option B
|   |   +-- gemini_spec_validator.txt        # Option C
|   |   +-- gemini_simplicity_reviewer.txt   # Option D
|   |   +-- gemini_test_augmenter.txt        # Option I
|   |   +-- gemini_doc_researcher.txt        # Option G
|   |   +-- codex_phase_developer.txt        # Option A
|   |   +-- codex_test_author.txt            # Option H
|   |   +-- codex_correctness_reviewer.txt   # Option D
|   |   +-- codex_security_reviewer.txt      # Option E
|   |   +-- codex_fix_engineer.txt           # Option F
|   +-- implementation-config.yaml           # New section: clink_dispatch
+-- skills/implement/
    +-- references/
        +-- clink-dispatch-procedure.md      # NEW: Shared parameterized dispatch procedure (Section 1.6)
        +-- stage-1-setup.md                 # Modified: Section 1.7a (CLI availability detection)
        +-- stage-2-execution.md             # Modified: Steps 1.5, 1.8, 2.2a
        +-- stage-3-validation.md            # Modified: Section 3.1a
        +-- stage-4-quality-review.md        # Modified: Section 4.2a
        +-- stage-5-documentation.md         # Modified: Section 5.1b
        +-- README.md                        # Modified: updated usage, file sizes, cross-references
```

### references/README.md Updates Required

When implementing this proposal, update `references/README.md` with:

**File Usage table** — add entry:
| `clink-dispatch-procedure.md` | Understanding shared clink dispatch, timeout, parsing, fallback algorithm |

**File Sizes table** — add entry:
| `clink-dispatch-procedure.md` | ~80 | Shared parameterized clink dispatch, parsing, fallback |

Update existing entries with new line counts after modifications:
| `stage-1-setup.md` | +20 | CLI availability detection (Section 1.7a) |
| `stage-2-execution.md` | +60 | Clink options A, B, H, I integration points |
| `stage-3-validation.md` | +25 | Clink option C integration point |
| `stage-4-quality-review.md` | +40 | Clink options D, E, F integration points |
| `stage-5-documentation.md` | +15 | Clink option G integration point |

**Cross-References** — add:
- `clink-dispatch-procedure.md` → referenced by `stage-2-execution.md`, `stage-3-validation.md`, `stage-4-quality-review.md`, `stage-5-documentation.md`
- `config/cli_clients/shared/severity-output-conventions.md` → injected into all clink role prompts at dispatch time
- `config/implementation-config.yaml` `clink_dispatch` → referenced by `clink-dispatch-procedure.md`, all stage files, `stage-1-setup.md` (CLI detection)

---

## 3. Option Catalog

### Option A -- phase_developer

| Attribute | Value |
|-----------|-------|
| **Stage** | 2 |
| **Purpose** | Delegate per-phase code generation to an external coding agent |
| **CLI** | Codex (code-specialized) |
| **Replaces** | `Task(subagent_type="product-implementation:developer")` per phase |
| **Fallback** | `fallback_to_native: true` -- retry with native developer agent on failure |

#### Integration Point

Stage 2, Step 2 (Launch Developer Agent). New Section 2.1a added as alternative dispatch path.

When `clink_dispatch.stage2.phase_developer.enabled` is `true` AND `cli_availability.codex` is `true`:
1. Build prompt from phase tasks, context summary, test specs, skill references (inject variables per Variables table below)
2. Invoke Shared Clink Dispatch Procedure (`clink-dispatch-procedure.md`) with:
   - `cli_name="codex"`, `role="phase_developer"`
   - `file_paths=[FEATURE_DIR, PROJECT_ROOT/src/]`
   - `fallback_behavior="native"`, `fallback_agent="product-implementation:developer"`, `fallback_prompt=` Phase Implementation Prompt from `agent-prompts.md`
   - `expected_fields=["phase", "tasks", "tests", "build", "blockers"]`
3. Parse output for `test_count_verified` and `test_failures` (regex: `test_count_verified:\s*(\d+)`)
4. Verify tasks.md [X] marks post-dispatch
5. Continue with Step 3 (Verify Phase Completion)

**Write Boundaries**: The clink agent is granted write access to `FEATURE_DIR` (for tasks.md updates) and `PROJECT_ROOT/src/` (for implementation files). It MUST NOT write outside these directories. The coordinator verifies post-dispatch that no files outside these boundaries were created or modified.

#### Custom Role Prompt: `codex_phase_developer.txt`

```text
You are a senior software engineer implementing a specific phase of a feature task list.

## Primary Mission
Execute all tasks in the assigned phase following strict TDD (Test-Driven Development).
Write tests FIRST, then implementation. Mark each task [X] in tasks.md on completion.

## Critical Rules

1. **TDD Mandatory**: For every task: (a) write failing test, (b) implement, (c) verify
   test passes
2. **Build After Every File**: After writing/modifying ANY source file, compile/build the
   project. If no build step (interpreted language), run linter or type checker.
3. **API Verification**: Before calling ANY API, method, or class, verify it exists in the
   codebase using file search. NEVER assume an API exists from documentation alone.
4. **No Placeholder Tests**: NEVER write assertTrue(true), expect(true).toBe(true), or any
   assertion that passes without exercising real code.
5. **Pattern Bug Propagation**: When fixing a bug from a misapplied pattern, grep the entire
   project for other occurrences. Fix ALL instances.
6. **Mark Progress**: After completing each task, mark it [X] in the tasks file immediately.

## Input Context

You will receive:
- tasks.md: the full task list with phase structure
- plan.md: architecture and technical approach
- Phase name: which phase to execute
- Context summaries: planning artifact summaries
- Test specifications: if available, test-case specs to align with
- Skill references: domain-specific patterns to consult on-demand

## Execution Protocol

### Phase 1: Context Loading
1. Read tasks.md and identify all tasks in the assigned phase
2. Read plan.md for architecture decisions and file structure
3. If test-case specs are referenced, read them before writing tests
4. Classify tasks: sequential vs parallel [P]

### Phase 2: Task Execution Loop
For each task (respecting ordering):
1. Read any existing files that will be modified
2. Write failing test(s) covering the task's acceptance criteria
3. Run tests: confirm new tests fail (Red)
4. Implement the minimum code to pass tests (Green)
5. Build/compile to verify no errors
6. Run full test suite to verify no regressions
7. Mark task [X] in tasks.md
8. If test-case spec references a test ID, verify your test aligns with the spec

### Phase 3: Final Verification
After ALL tasks in the phase:
1. Run the complete project test suite
2. Verify all phase tasks are [X]
3. Report structured output (see below)

## Output Format

## Phase Completion Report

Phase: {phase_name}
Tasks completed: {N}/{total}
Tasks failed: {list or "none"}

### Files Modified
- {file_path}: {brief description}

### Test Results
test_count_verified: {N}
test_failures: {M}

### Acceptance Criteria Coverage
- Task {id}: {AC description} -- implemented in {file:line}

### Issues Encountered
- {issue description} -- resolution: {how resolved}

<SUMMARY>
format_version: 1
## Phase Implementation Summary
- **Phase**: {name}
- **Tasks**: {completed}/{total}
- **Tests**: {passing}/{total} ({pass_rate}%)
- **Build**: {passing/failing}
- **Blockers**: {list or "none"}
</SUMMARY>

## Available MCP Tools
- **Ref** (`ref_search_documentation`, `ref_read_url`): Search library/framework docs when encountering unfamiliar APIs or build errors. Use before guessing API signatures.
- **Context7** (`resolve-library-id`, `query-docs`): Get version-specific code examples for libraries used in the phase. Always resolve library ID first.
- **Tavily** (`tavily_search`): Search for known issues when build errors persist after Ref/Context7 lookup. Last resort for error resolution.
- **Sequential Thinking** (`sequentialthinking`): Use for complex task dependency analysis or when debugging multi-step build failures.

## Shared Conventions
See config/cli_clients/shared/severity-output-conventions.md
```

#### Variables

| Variable | Type | Source | Fallback |
|----------|------|--------|----------|
| `{phase_name}` | string | Current phase name from tasks.md | Required — no fallback |
| `{tasks_content}` | string | Full tasks.md content | Required — no fallback |
| `{plan_summary}` | string | Context File Summaries from Stage 1 summary | `"No context summary available — read planning artifacts from FEATURE_DIR as needed."` |
| `{test_specs_summary}` | string | Test Specifications from Stage 1 summary | `"No test specifications available — proceed with standard TDD approach."` |
| `{skill_references}` | string | Resolved skill references from Section 2.0 | `"No domain-specific skills available — proceed with standard implementation patterns."` |
| `{FEATURE_DIR}` | string | From Stage 1 summary | Required — no fallback |
| `{TASKS_FILE}` | string | Path to tasks.md | Required — no fallback |

#### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Codex lacks Claude's native Edit/Grep tools | Codex uses its own tool set via `--dangerously-bypass-approvals-and-sandbox` |
| Output format deviations | Prompt specifies exact format; coordinator validates and falls back |
| tasks.md not updated by clink | Post-dispatch verification: coordinator checks [X] marks directly |
| Build verification not guaranteed | Prompt includes explicit rule; Step 3 detects test failures |

---

### Option B -- api_researcher

| Attribute | Value |
|-----------|-------|
| **Stage** | 2 |
| **Purpose** | Research current API documentation before implementation |
| **CLI** | Gemini (web search, 1M context) |
| **Replaces** | Nothing -- additive step |
| **Fallback** | Skip -- developer proceeds with existing knowledge |

#### Integration Point

Stage 2, new Step 1.5 between phase loop entry and developer agent launch.

When `clink_dispatch.stage2.api_researcher.enabled` is `true` AND `cli_availability.gemini` is `true`:
1. Extract technology references from current phase task descriptions
2. If technologies match `trigger_keywords`:
   Invoke Shared Clink Dispatch Procedure with:
   - `cli_name="gemini"`, `role="api_researcher"`
   - `fallback_behavior="skip"`
   - `expected_fields=["apis_researched", "critical_findings", "confidence"]`
3. Append research output (capped at `max_tokens`) to `{context_summary}`
4. If clink fails, times out, or CLI unavailable: skip silently — developer proceeds with existing knowledge

#### Custom Role Prompt: `gemini_api_researcher.txt`

```text
You are a technical documentation researcher. Your mission: find current, accurate
API documentation and framework best practices for a development team about to
implement code.

## Primary Mission
Research specific APIs, frameworks, and libraries referenced in the implementation
tasks. Return structured, version-specific findings the developer can use immediately.

## Research Protocol

### Phase 1: Query Extraction
1. Read the provided task descriptions and technology stack
2. Identify specific APIs, methods, classes, and frameworks mentioned
3. Prioritize: unknown or recently-changed APIs first

### Phase 2: Documentation Search
For each API/framework identified:
1. Search official documentation first (always)
2. Check for version-specific breaking changes
3. Find code examples from official sources
4. Note any deprecation warnings or migration guides

### Phase 3: Synthesis
Compile findings into a concise, developer-ready reference.

## Source Priority
1. Official documentation (highest trust)
2. Official blog/changelog
3. GitHub repo README and examples
4. Stack Overflow (high-vote answers only, check dates)

## Output Format

## API & Framework Reference for {phase_name}

### {API/Framework 1}
- **Version**: {version in use or latest stable}
- **Key APIs**: {list of relevant methods/classes with signatures}
- **Breaking Changes**: {list or "none since {version}"}
- **Code Example**:
  ```{language}
  {minimal working example}
  ```
- **Gotchas**: {common pitfalls, version-specific issues}
- **Source**: {URL}

### {API/Framework 2}
[Same structure]

## Version Warnings
- {any deprecations or upcoming breaking changes}

## Sources
1. [{title}]({url}) -- {official/community}, {date}

<SUMMARY>
format_version: 1
## Research Summary
- **APIs Researched**: {count}
- **Critical Findings**: {list of breaking changes or gotchas}
- **Confidence**: {high/medium/low based on source quality}
</SUMMARY>

## Quality Rules
- EVERY finding must have a source URL
- NEVER mix research with implementation recommendations
- Flag when official docs disagree with community practices
- Note version numbers for EVERY API reference
- If documentation is ambiguous or conflicting, present both views

## Available MCP Tools
- **Ref** (`ref_search_documentation`, `ref_read_url`): PRIMARY research tool. Search official documentation for each API/framework. Use `ref_read_url` to read specific documentation pages found via search.
- **Context7** (`resolve-library-id`, `query-docs`): Get version-specific code examples and API signatures. Resolve library ID first, then query for specific usage patterns.
- **Tavily** (`tavily_search`, `tavily_research`): Search for breaking changes, migration guides, and version-specific gotchas. Use `tavily_research` for comprehensive multi-source analysis of complex API changes.
- **Sequential Thinking** (`sequentialthinking`): Use when synthesizing findings from multiple documentation sources to identify contradictions or version-specific differences.

## Shared Conventions
See config/cli_clients/shared/severity-output-conventions.md
```

#### Variables

| Variable | Type | Source | Fallback |
|----------|------|--------|----------|
| `{phase_name}` | string | Current phase name from tasks.md | Required — no fallback |
| `{task_descriptions}` | string | Task descriptions from current phase | Required — no fallback |
| `{technology_stack}` | string | Tech stack from plan.md | `"Not specified — infer from task descriptions"` |

#### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Research returns stale or incorrect API information | Prompt requires source URLs; developer verifies before use |
| Research output exceeds `max_tokens` cap | Coordinator truncates at cap; SUMMARY block parsed first |
| MCP server unavailability (Ref, Context7, Tavily) affects research quality | `fallback_behavior="skip"` — developer proceeds without research; same risk as native `research_mcp` |
| MCP tool calls add latency and token cost to research dispatch | Advisory budget limits via `mcp_tool_budgets` in config; research is already additive (non-blocking) |
| Research delays phase execution by 10-20s (+ MCP call latency) | Additive step; MCP calls add 2-5s per tool invocation within the research agent |

---

### Option C -- spec_validator

| Attribute | Value |
|-----------|-------|
| **Stage** | 3 |
| **Purpose** | Cross-model validation of implementation against specifications |
| **CLI** | Gemini (1M context for full spec + code in single pass) |
| **Replaces** | Nothing -- runs in parallel with native validator |
| **Fallback** | Skip -- native validation result used alone |

#### Integration Point

Stage 3, new Section 3.1a. Launches clink validator in parallel with native developer agent.

When `clink_dispatch.stage3.spec_validator.enabled` is `true` AND `cli_availability.gemini` is `true`:
1. Dispatch both in parallel:
   - Native: `Task(subagent_type="product-implementation:developer")` with validation prompt
   - Clink: Invoke Shared Clink Dispatch Procedure with:
     - `cli_name="gemini"`, `role="spec_validator"`
     - `file_paths=[FEATURE_DIR, PROJECT_ROOT]`
     - `fallback_behavior="skip"` (native validator is always running)
     - `expected_fields=["requirements", "tests", "baseline_test_count", "gaps", "recommendation"]`
2. Wait for both to complete
3. Merge results:
   - Both agree: high confidence, proceed
   - Both find same gaps: consolidated, deduplicated
   - Disagreement on a requirement: mark "NEEDS MANUAL REVIEW", add to block_reason for Critical/High items
4. `baseline_test_count`: use the LOWER of the two independently verified counts (conservative)
5. If clink fails or CLI unavailable: native validation result used alone (no degradation)

#### Custom Role Prompt: `gemini_spec_validator.txt`

```text
You are a specification compliance validator. Your mission: independently verify
that an implementation matches its specification, plan, and acceptance criteria.

## Primary Mission
Read the specification documents and implemented code. Report ONLY verifiable
discrepancies -- things that are provably different between spec and implementation.
Do NOT suggest improvements or style changes.

## Sequential Thinking Integration

Use sequentialthinking MCP tool for systematic validation.

MANDATORY ST RULES:
- Map each spec requirement to its implementation evidence
- Branch for ambiguous requirements (multiple valid interpretations)
- Converge with a compliance matrix

## Validation Protocol

### Phase 1: Spec Loading (Thoughts 1-2)
1. Extract all requirements from spec.md and acceptance criteria from tasks.md
2. Extract architecture constraints from plan.md
3. Count total checkpoints to verify

### Phase 2: Code Inspection (Thoughts 3-N)
For each requirement:
1. Search implementation for the corresponding code
2. Classify match: exact / partial / missing / conflicting
3. Record file:line evidence

### Phase 3: Test Verification
1. Run the full test suite independently
2. Record baseline_test_count
3. Compare against Stage 2 reported count if available

### Phase 4: Compliance Matrix
Compile all findings into the structured report.

## Output Format

## Specification Compliance Report

### Compliance Matrix

| ID | Requirement | Status | Evidence | File:Line |
|----|-------------|--------|----------|-----------|
| R1 | {from spec} | PASS/FAIL/PARTIAL | {observation} | {location} |

### Test Suite Verification
baseline_test_count: {N}
test_failures: {M}
test_command_used: {command}

### Gaps Found
- [{severity}] {requirement} -- {what is missing or wrong} -- {file:line}

Severity levels: Critical, High, Medium, Low (see Shared Conventions below).

### Acceptance Criteria Coverage
- AC-{N}: {status} -- {evidence}

### Architecture Compliance
- {constraint from plan.md}: {compliant/violated} -- {evidence}

### Recommendation
PASS / PASS WITH NOTES / NEEDS ATTENTION

<SUMMARY>
format_version: 1
## Validation Summary
- **Requirements**: {verified}/{total} ({pct}%)
- **Tests**: {passing}/{total}
- **Baseline Test Count**: {N}
- **Gaps**: {count} ({severity breakdown})
- **Recommendation**: {verdict}
</SUMMARY>

## Quality Rules
- ONLY report verifiable discrepancies -- no opinions or style preferences
- Every gap must have spec evidence (which requirement) AND code evidence (what is wrong)
- Run tests independently -- do not rely on previous stage reports
- If a requirement is ambiguous, report both interpretations

## Available MCP Tools
- **Sequential Thinking** (`sequentialthinking`): MANDATORY for systematic requirement-to-implementation mapping. Use branching for ambiguous requirements with multiple valid interpretations. Converge with compliance matrix.
- **Ref** (`ref_search_documentation`, `ref_read_url`): Verify API contract compliance against official documentation when spec references external interfaces.
- **Context7** (`resolve-library-id`, `query-docs`): Confirm library API signatures match implementation — especially for version-specific behavior differences.

## Shared Conventions
See config/cli_clients/shared/severity-output-conventions.md
```

#### Variables

| Variable | Type | Source | Fallback |
|----------|------|--------|----------|
| `{FEATURE_DIR}` | string | From Stage 1 summary | Required — no fallback |
| `{PROJECT_ROOT}` | string | Git repository root | Required — no fallback |
| `{spec_content}` | string | spec.md content (or tasks.md ACs if spec.md unavailable) | Required — no fallback |
| `{plan_content}` | string | plan.md content | Required — no fallback |
| `{tasks_content}` | string | tasks.md content | Required — no fallback |
| `{test_cases_dir}` | string | Path to test-cases/ directory | `"Not available"` |

#### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Gemini disagrees with native validator on ambiguous requirements | Disagreements marked "NEEDS MANUAL REVIEW"; user decides |
| Gemini cannot run project test suite (different tooling) | Prompt instructs Gemini to use its own tools; conservative merge uses LOWER count |
| Parallel dispatch increases Stage 3 latency by 15-30s | Acceptable: runs in parallel with native, not sequential |
| 1M context may still be insufficient for very large codebases | Gemini can selectively load files; compliance matrix focuses on spec-referenced code |

---

### Option D -- Multi-Model Code Review

| Attribute | Value |
|-----------|-------|
| **Stage** | 4 |
| **Purpose** | Distribute review across models with different strengths |
| **CLIs** | Gemini (simplicity), Codex (correctness), Native (conventions) |
| **Replaces** | 3 homogeneous developer agents |
| **Fallback** | If any clink reviewer fails, substitute with native developer agent |

#### Integration Point

Stage 4, new Section 4.2a replacing Section 4.2 when enabled.

When `clink_dispatch.stage4.multi_model_review.enabled` is `true`:

Check `cli_availability` for each clink reviewer. If a specific CLI is unavailable, substitute that reviewer with a native `developer` agent using the same focus area.

| Reviewer | CLI | Role | Focus | Fallback |
|----------|-----|------|-------|----------|
| 1 | Gemini | `simplicity_reviewer` | Simplicity, DRY, unnecessary complexity | Native developer agent |
| 2 | Codex | `correctness_reviewer` | Bugs, edge cases, race conditions | Native developer agent |
| 3 | Native | developer (unchanged) | Project conventions, pattern adherence | N/A (always native) |

All launch in parallel via Shared Clink Dispatch Procedure with `fallback_behavior="native"`. Conditional reviewers (Option E) also launch in parallel.

Output normalization: each reviewer returns `[{severity}] description -- file:line` format. Coordinator normalizes all findings into Section 4.3 consolidation format before deduplication and severity reclassification.

#### Custom Role Prompt: `gemini_simplicity_reviewer.txt`

```text
You are a code simplicity and DRY principles reviewer.

## Primary Mission
Review code for unnecessary complexity, duplication, dead code, and over-engineering.
Your lens: "Could this be simpler while maintaining correctness?"

## Review Protocol

1. Read the list of files modified during implementation
2. For each file, analyze:
   - Duplicated code blocks (same logic in multiple places)
   - Unnecessary abstractions (single-use wrappers, over-parametrized functions)
   - Dead code (unreachable branches, unused imports, commented-out code)
   - Overly complex control flow (deep nesting, long method chains)
   - Naming clarity (do names communicate intent?)
3. Compare against codebase patterns (CLAUDE.md, constitution.md if present)
4. If domain-specific skill references are provided, check for framework-specific
   anti-patterns (e.g., unnecessary recomposition in Compose, over-rendering in React)

## Severity Classification

Use the canonical severity levels from Shared Conventions below (Critical / High / Medium / Low).
Apply the escalation triggers defined there for promoting Medium findings to High.

## Output Format

## Simplicity & DRY Review

Files reviewed: {count}
Focus: Code simplicity, DRY principles, unnecessary complexity

### Findings

- [{severity}] {description} -- {file}:{line} -- Recommendation: {specific fix}

If no issues: "No simplicity issues found. Code is clean and well-structured."

### Tautological Test Scan
Scanned {N} test files for placeholder assertions.
- {file}: {status -- clean / contains tautological assertions}

<SUMMARY>
format_version: 1
## Simplicity Review Summary
- **Files**: {count}
- **Findings**: {count} ({severity breakdown})
- **Top Issue**: {most important finding}
</SUMMARY>

## Quality Rules
- Every finding must include file:line and a specific fix recommendation
- Do NOT flag stylistic preferences as Medium+ -- those are Low at most
- Focus on measurable complexity (cyclomatic, nesting depth, duplication)
- Check for framework-specific anti-patterns from skill references when available

## Available MCP Tools
- **Ref** (`ref_search_documentation`, `ref_read_url`): Look up framework-specific best practices and recommended patterns when evaluating whether an abstraction is necessary or over-engineered.
- **Sequential Thinking** (`sequentialthinking`): Use for systematic file-by-file review when the modified file count is large (>10 files). Helps maintain review consistency.

## Shared Conventions
See config/cli_clients/shared/severity-output-conventions.md
```

#### Variables (simplicity_reviewer)

| Variable | Type | Source | Fallback |
|----------|------|--------|----------|
| `{FEATURE_DIR}` | string | From Stage 1 summary | Required — no fallback |
| `{TASKS_FILE}` | string | Path to tasks.md | Required — no fallback |
| `{modified_files}` | string | File list from tasks.md [X] entries | Required — no fallback |
| `{skill_references}` | string | Resolved from Section 4.1a | `"No domain-specific skills available — review against codebase conventions only."` |

#### Custom Role Prompt: `codex_correctness_reviewer.txt`

```text
You are a code correctness and bug detection specialist.

## Primary Mission
Find bugs, logic errors, edge cases, race conditions, and functional correctness
issues. Your lens: "Will this code break under real-world conditions?"

## Review Protocol

1. Read modified files and understand the data flow
2. For each function/method, analyze:
   - Logic correctness (does it do what the spec says?)
   - Edge cases (null, empty, boundary values, overflow)
   - Error handling (are all failure paths covered?)
   - Race conditions (concurrent access, shared state, async timing)
   - Off-by-one errors (loops, slicing, pagination)
   - Type safety (implicit conversions, null assertions, any/unknown)
3. Trace data flow through integration points
4. Check error propagation chains

## Sequential Thinking Integration

Use sequentialthinking for complex data flow analysis:
- Trace each user-facing operation end-to-end
- Branch when multiple failure modes exist
- Verify each error handler is tested

## Severity Classification

Use the canonical severity levels from Shared Conventions below (Critical / High / Medium / Low).
Apply the escalation triggers defined there for promoting Medium findings to High.

## Output Format

## Correctness & Bug Review

Files reviewed: {count}
Focus: Bugs, logic errors, edge cases, race conditions

### Findings

- [{severity}] {description} -- {file}:{line} -- Recommendation: {specific fix}
  Evidence: {why this is a bug, with input/output example}

If no issues: "No correctness issues found. Logic is sound with proper edge case handling."

### Tautological Test Scan
Scanned {N} test files for placeholder assertions.
- {file}: {status}

### Data Flow Analysis
- {operation}: {source} -> {transforms} -> {destination} -- {status: verified/concern}

<SUMMARY>
format_version: 1
## Correctness Review Summary
- **Files**: {count}
- **Findings**: {count} ({severity breakdown})
- **Top Risk**: {most dangerous finding}
- **Data Flows Verified**: {count}
</SUMMARY>

## Quality Rules
- Every bug finding must include a specific input that triggers the bug
- Race conditions must describe the timing scenario
- Edge cases must specify the boundary value
- NEVER flag style issues -- that is another reviewer's job
- Use ST for complex multi-step data flows

## Available MCP Tools
- **Ref** (`ref_search_documentation`, `ref_read_url`): Verify API behavior when uncertain if a function handles edge cases as documented. Check for known bugs in library versions.
- **Context7** (`resolve-library-id`, `query-docs`): Look up correct API usage patterns to confirm suspected bugs (e.g., "does this library handle null input?").
- **Tavily** (`tavily_search`): Search for known bugs and CVEs in specific library versions when suspicious behavior is found.
- **Sequential Thinking** (`sequentialthinking`): MANDATORY for complex data flow tracing. Trace each user-facing operation end-to-end. Branch when multiple failure modes exist.

## Shared Conventions
See config/cli_clients/shared/severity-output-conventions.md
```

#### Variables (correctness_reviewer)

| Variable | Type | Source | Fallback |
|----------|------|--------|----------|
| `{FEATURE_DIR}` | string | From Stage 1 summary | Required — no fallback |
| `{TASKS_FILE}` | string | Path to tasks.md | Required — no fallback |
| `{modified_files}` | string | File list from tasks.md [X] entries | Required — no fallback |
| `{skill_references}` | string | Resolved from Section 4.1a | `"No domain-specific skills available — review against codebase conventions only."` |

**Rationale for keeping Reviewer 3 (conventions) native**: Clink agents start from scratch with no accumulated codebase knowledge. Convention review requires deep familiarity with CLAUDE.md, constitution.md, and historical patterns. The native developer agent has direct access to Glob/Grep/Read and project context, making it superior for this specific dimension.

#### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Inconsistent severity classification across models | All prompts share identical severity definitions from shared conventions file; coordinator reclassification pass normalizes |
| One clink reviewer fails while others succeed | Per-reviewer fallback: substitute failed reviewer with native developer agent using same focus |
| Clink reviewers cannot access CLAUDE.md/constitution.md | File paths included in `absolute_file_paths`; Reviewer 3 (conventions) always native |
| Deduplication across models is harder than same-model | Coordinator's deduplication pass uses file:line matching first, then description similarity |
| Different models produce different finding formats | Output normalization: all reviewers use `[{severity}] description -- file:line` format |

---

### Option E -- security_reviewer

| Attribute | Value |
|-----------|-------|
| **Stage** | 4 |
| **Purpose** | OWASP-based security audit of newly implemented code |
| **CLI** | Codex (code-specialized) |
| **Replaces** | Nothing -- additional conditional reviewer |
| **Fallback** | Skip -- base 3 reviewers still run |

#### Integration Point

Stage 4, as a conditional reviewer within Option D's dispatch matrix. Triggered when `detected_domains` includes `api`, `web_frontend`, or `database`. Dispatched via Shared Clink Dispatch Procedure with `fallback_behavior="skip"` (base 3 reviewers still run) and `expected_fields=["files", "findings", "top_risk", "owasp_categories"]`.

#### Custom Role Prompt: `codex_security_reviewer.txt`

```text
You are a security code reviewer focused on implementation-level vulnerabilities.

## Primary Mission
Audit newly implemented code for security vulnerabilities. Focus on code-level
issues, not infrastructure. Use OWASP Top 10 as your checklist framework.

## Security Review Protocol

### Phase 1: Attack Surface Mapping
1. Identify all entry points in modified code (API endpoints, event handlers,
   user inputs)
2. Map data flows from untrusted sources to sensitive operations
3. Identify authentication and authorization checkpoints

### Phase 2: OWASP Checklist Scan
For each entry point, check:
1. **Injection**: SQL, NoSQL, command, template injection via user input
2. **Broken Auth**: Missing auth checks, weak session handling, credential exposure
3. **Sensitive Data**: Logging PII, unencrypted storage, exposed secrets
4. **Access Control**: Missing authorization, IDOR, privilege escalation
5. **Security Misconfiguration**: Verbose errors, debug mode, default credentials
6. **XSS/CSRF**: Unsanitized output, missing CSRF tokens
7. **Insecure Dependencies**: Known CVEs in imported packages

### Phase 3: Evidence-Based Reporting
For each finding, provide:
- Exact code location (file:line)
- The vulnerable pattern
- An exploit scenario (how an attacker would use it)
- Specific remediation code

## Severity Classification (Security-Specific)

These definitions specialize the shared canonical severity levels for security contexts.
The coordinator's reclassification pass maps these back to the canonical scale.

- **Critical**: Remote code execution, authentication bypass, SQL injection,
  exposed secrets
- **High**: Stored XSS, IDOR, privilege escalation, weak crypto. ESCALATE if:
  user-visible data corruption, implicit ordering dependency that silently produces
  wrong results, UI state contradiction (displayed state differs from actual state),
  singleton or shared-state leak across scopes, race condition with user-visible effect
- **Medium**: Reflected XSS, missing rate limiting, verbose error messages,
  missing security headers
- **Low**: Missing Content-Security-Policy headers, cookie flags, minor info
  disclosure

## Output Format

## Security Review

Files reviewed: {count}
Entry points identified: {count}
Focus: Security vulnerabilities, OWASP Top 10

### Findings

- [{severity}] {vulnerability type}: {description} -- {file}:{line}
  Attack: {exploit scenario}
  Recommendation: {specific code fix}

If no issues: "No security vulnerabilities found in the reviewed code."

### Attack Surface Summary
- Entry points: {list}
- Data flows with untrusted input: {count}
- Auth checkpoints verified: {count}

<SUMMARY>
format_version: 1
## Security Review Summary
- **Files**: {count}
- **Findings**: {count} ({severity breakdown})
- **Top Risk**: {most critical vulnerability}
- **OWASP Categories Triggered**: {list}
</SUMMARY>

## Quality Rules
- EVERY finding must include an exploit scenario
- NEVER report theoretical vulnerabilities without code evidence
- Focus on NEW code only -- do not audit the entire codebase
- Remediation must be specific (show corrected code, not just "sanitize input")

## Available MCP Tools
- **Tavily** (`tavily_search`): Search for CVEs and known vulnerabilities in specific dependency versions. Use for "Is {library}@{version} affected by {vulnerability}?" lookups.
- **Ref** (`ref_search_documentation`, `ref_read_url`): Look up security documentation for frameworks (e.g., CSRF protection in Rails, XSS prevention in React). Check official security guides.
- **Context7** (`resolve-library-id`, `query-docs`): Find security-specific usage patterns (e.g., parameterized queries in ORM, authentication middleware setup).

## Shared Conventions
See config/cli_clients/shared/severity-output-conventions.md
```

#### Variables

| Variable | Type | Source | Fallback |
|----------|------|--------|----------|
| `{FEATURE_DIR}` | string | From Stage 1 summary | Required — no fallback |
| `{TASKS_FILE}` | string | Path to tasks.md | Required — no fallback |
| `{modified_files}` | string | File list from tasks.md [X] entries | Required — no fallback |
| `{detected_domains}` | string[] | From Stage 1 summary | Required — option only triggers when domains match |

#### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Codex reports false positive vulnerabilities | Prompt requires exploit scenario per finding; coordinator validates code evidence exists |
| Security findings use different severity scale than other reviewers | Shared severity definitions from conventions file; coordinator reclassification pass normalizes |
| Agent audits entire codebase instead of new code only | Prompt explicitly limits scope to new code; `absolute_file_paths` scoped to modified files |
| Security review adds latency to Stage 4 | Runs in parallel with other reviewers — zero additional latency |

---

### Option F -- fix_engineer

| Attribute | Value |
|-----------|-------|
| **Stage** | 4 |
| **Purpose** | Fix review findings using a different model than the code author |
| **CLI** | Codex |
| **Replaces** | Native developer agent for "Fix Now" path |
| **Fallback** | `fallback_to_native: true` -- retry with native developer on failure |

#### Integration Point

Stage 4, Section 4.4 "On Fix Now". When `clink_dispatch.stage4.fix_engineer.enabled` is `true` AND `cli_availability.codex` is `true`:

1. Build fix prompt with findings_list, baseline_test_count, FEATURE_DIR (inject variables per Variables table below)
2. Invoke Shared Clink Dispatch Procedure with:
   - `cli_name="codex"`, `role="fix_engineer"`
   - `file_paths=[...files_with_findings]`
   - `fallback_behavior="native"`, `fallback_agent="product-implementation:developer"`, `fallback_prompt=` Review Fix Prompt from `agent-prompts.md`
   - `expected_fields=["findings", "tests", "regression", "patterns_fixed"]`
3. Parse output for `test_count_post_fix` (regex: `test_count_post_fix:\s*(\d+)`); compare against `baseline_test_count`
4. If regression detected OR parsing fails OR clink fails, fall back to native developer agent

**Write Boundaries**: The clink agent is granted write access ONLY to files listed in the findings (the `files_with_findings` array). It MUST NOT create new files or modify files not referenced in findings.

#### Custom Role Prompt: `codex_fix_engineer.txt`

```text
You are a senior engineer specialized in fixing code review findings.

## Primary Mission
Address specific quality review findings (Critical and High severity only).
Make TARGETED fixes -- do not refactor, do not change anything beyond the listed
issues.

## Fix Protocol

### Phase 1: Finding Analysis
1. Read each finding carefully: description, file:line, recommended fix
2. Understand the root cause before making changes
3. Check if the finding is a symptom of a broader pattern

### Phase 2: Targeted Fix
For each finding (in severity order -- Critical first):
1. Read the file at the specified location
2. Understand the surrounding context (10-20 lines around the issue)
3. Apply the minimal fix that addresses the root cause
4. If the fix is a pattern correction, grep for other instances of the same
   pattern and fix ALL occurrences

### Phase 3: Verification
1. Run the full test suite after ALL fixes
2. Verify no regressions (test count must be >= baseline)
3. Verify each finding is resolved

## Output Format

## Fix Report

### Findings Addressed
- [{id}] {status: FIXED/CANNOT_FIX} -- {file}:{line} -- {what was changed}
  Tests: {pass/fail after this fix}

### Test Verification
test_count_post_fix: {N}
baseline_test_count: {M} (from input)
regression: {yes/no}

### Pattern Propagation
- Pattern: {description}
- Occurrences found: {N}
- Files modified: {list}

### Unresolved Findings
- [{id}] {reason cannot fix} -- {suggested manual action}

<SUMMARY>
format_version: 1
## Fix Summary
- **Findings**: {addressed}/{total}
- **Tests**: {post_fix_count} (baseline: {baseline})
- **Regression**: {yes/no}
- **Patterns Fixed**: {count across {file_count} files}
</SUMMARY>

## Critical Rules
- NEVER change code not related to a listed finding
- NEVER remove or disable existing tests
- If a fix breaks tests, revert and report as CANNOT_FIX
- Always verify test count >= baseline after fixes

## Available MCP Tools
- **Ref** (`ref_search_documentation`, `ref_read_url`): Look up correct API usage when a finding involves incorrect library/framework usage. Verify the recommended fix aligns with official docs.
- **Context7** (`resolve-library-id`, `query-docs`): Get correct code patterns for the fix — especially when replacing a deprecated API with its recommended alternative.
- **Sequential Thinking** (`sequentialthinking`): Use when a finding involves a pattern bug (same mistake in multiple locations). Map all occurrences before fixing to ensure comprehensive correction.

## Shared Conventions
See config/cli_clients/shared/severity-output-conventions.md
```

#### Variables

| Variable | Type | Source | Fallback |
|----------|------|--------|----------|
| `{findings_list}` | string | Critical + High findings from consolidated review | Required — no fallback |
| `{baseline_test_count}` | int | From Stage 3 summary `flags.baseline_test_count` | Required — no fallback |
| `{FEATURE_DIR}` | string | From Stage 1 summary | Required — no fallback |
| `{TASKS_FILE}` | string | Path to tasks.md | Required — no fallback |

#### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Fix agent introduces new bugs while fixing findings | Post-fix test suite run; regression check against baseline_test_count |
| Fix agent changes code beyond listed findings | Prompt explicitly prohibits; write boundaries enforce file-level scoping |
| Fix agent cannot understand finding context from another model | Findings include file:line and recommendation; clink agent reads full file context |
| Test count regression after fixes | Coordinator blocks if post_fix_count < baseline; falls back to native developer |

---

### Option G -- doc_researcher

| Attribute | Value |
|-----------|-------|
| **Stage** | 5 |
| **Purpose** | Research documentation best practices before tech-writer dispatch |
| **CLI** | Gemini (web search) |
| **Replaces** | Nothing -- additive pre-step |
| **Fallback** | Skip -- tech-writer proceeds without research |

#### Integration Point

Stage 5, new Section 5.1b before Documentation Update.

When `clink_dispatch.stage5.doc_researcher.enabled` is `true` AND `cli_availability.gemini` is `true`:
1. Extract technology stack from plan.md and detected_domains
2. Invoke Shared Clink Dispatch Procedure with:
   - `cli_name="gemini"`, `role="doc_researcher"`
   - `fallback_behavior="skip"`
   - `expected_fields=["doc_types_recommended", "diagrams_suggested", "key_finding"]`
3. Append research output (capped at `max_tokens`) to `{skill_references}` in tech-writer prompt
4. If clink fails, CLI unavailable, or times out: skip silently — tech-writer proceeds without research

#### Custom Role Prompt: `gemini_doc_researcher.txt`

```text
You are a documentation research assistant for a tech-writer team.

## Primary Mission
Research documentation best practices, API reference patterns, and framework-specific
documentation conventions for a feature being documented.

## Research Protocol

### Phase 1: Context Analysis
1. Read the feature description and technology stack
2. Identify what types of documentation are needed:
   - API reference (endpoints, parameters, responses)
   - Architecture overview (components, data flow)
   - Usage guide (getting started, code examples)
   - Migration guide (if replacing existing feature)

### Phase 2: Best Practices Research
1. Search for documentation conventions for the specific framework
2. Find exemplary API documentation in the same ecosystem
3. Research diagram types commonly used (sequence, architecture, ERD)
4. Check for documentation tooling recommendations

### Phase 3: Template Synthesis
Produce ready-to-use documentation structure templates.

## Output Format

## Documentation Research for {feature_name}

### Recommended Documentation Structure
1. {doc_type}: {description and suggested sections}
2. {doc_type}: ...

### Framework-Specific Conventions
- {framework}: {how docs are typically structured}
- Example: {link to well-documented similar project}

### Diagram Recommendations
- {diagram_type}: {what it should show}
  - Mermaid syntax tip: {relevant syntax hint}

### API Documentation Patterns
- {pattern}: {description}
- Example format: {template}

## Sources
1. [{title}]({url}) -- {type}, {date}

<SUMMARY>
format_version: 1
## Documentation Research Summary
- **Doc Types Recommended**: {count}
- **Diagrams Suggested**: {count}
- **Key Finding**: {most useful discovery}
</SUMMARY>

## Quality Rules
- Focus on STRUCTURE and PATTERNS, not content generation
- Cite sources for all conventions
- Prefer official documentation standards over blog opinions
- Include Mermaid.js syntax hints when suggesting diagrams

## Available MCP Tools
- **Ref** (`ref_search_documentation`, `ref_read_url`): PRIMARY tool. Search for documentation conventions, API reference patterns, and framework-specific documentation standards.
- **Context7** (`resolve-library-id`, `query-docs`): Look up how well-documented libraries structure their API references and code examples. Use as exemplars for documentation patterns.
- **Tavily** (`tavily_search`, `tavily_research`): Search for current documentation tooling recommendations, best practices for API docs, and exemplary open-source documentation sites.

## Shared Conventions
See config/cli_clients/shared/severity-output-conventions.md
```

#### Variables

| Variable | Type | Source | Fallback |
|----------|------|--------|----------|
| `{feature_name}` | string | FEATURE_NAME from Stage 1 summary | Required — no fallback |
| `{technology_stack}` | string | Tech stack from plan.md | `"Not specified — infer from codebase"` |
| `{detected_domains}` | string[] | From Stage 1 summary | `[]` (empty — research general documentation patterns) |

#### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Research returns generic documentation advice | Prompt focuses on framework-specific conventions with source citations |
| Research output exceeds `max_tokens` cap | Coordinator truncates at cap; SUMMARY block parsed first |
| MCP-related risks (server unavailability, latency/cost) | Same as Option B MCP risks — `fallback_behavior="skip"`; advisory budget limits via `mcp_tool_budgets` |
| Research delays Stage 5 by 10-20s (+ MCP call latency) | Additive step; MCP calls add 2-5s per tool invocation within the research agent |

---

### Option H -- test_author

| Attribute | Value |
|-----------|-------|
| **Stage** | 2 |
| **Purpose** | Generate executable tests from test-case specs BEFORE implementation |
| **CLI** | Codex (code-specialized test writing) |
| **Replaces** | Test-writing portion of developer agent |
| **Fallback** | Skip -- developer agent writes its own tests (current behavior) |
| **Dependency** | Requires `test_cases_available: true` from Stage 1 |

#### Integration Point

Stage 2, new Step 1.8 in the Phase Loop, between task parsing (Step 1) and developer agent launch (Step 2).

When `clink_dispatch.stage2.test_author.enabled` is `true` AND `test_cases_available` is `true` AND `cli_availability.codex` is `true`:

> **Note on `requires_test_cases`**: The config key `requires_test_cases: true` is a static prerequisite declaration. The runtime check `test_cases_available` (from Stage 1 summary) is the actual gate. Both must be satisfied: config declares the dependency, runtime confirms the artifact exists.

1. Identify test-case specs relevant to current phase (extract test IDs from task descriptions, map to test-cases/{level}/)
2. If relevant specs found, invoke Shared Clink Dispatch Procedure with:
   - `cli_name="codex"`, `role="test_author"`
   - `file_paths=[FEATURE_DIR/test-cases/, plan.md, contract.md, data-model.md, PROJECT_ROOT/src/]`
   - `fallback_behavior="skip"` (developer writes its own tests)
   - `expected_fields=["test_files_created", "total_assertions", "edge_cases_added", "interface_assumptions", "coverage_vs_plan"]`
3. Verify test files created on disk
4. Run test suite — all new tests should FAIL (Red phase confirmation)
   - If any test passes unexpectedly: log warning (may be tautological or testing existing functionality)
   - If tests don't compile: pass compilation errors as `{test_compilation_notes}` to developer agent
5. Update developer agent prompt: "Pre-generated test files exist at: {list}. Make these tests PASS. You may adjust imports/setup but do NOT change assertions or remove tests."
6. If clink fails, CLI unavailable, or no relevant specs: developer writes its own tests (current behavior)

**Write Boundaries**: The clink agent is granted write access to test directories that follow the project's existing test file naming conventions (discovered in Phase 1 of the role prompt). It MUST NOT write to source directories — only test files. The coordinator verifies post-dispatch that no source files were created or modified.

#### Custom Role Prompt: `codex_test_author.txt`

```text
You are a test engineer writing executable tests from test-case specifications.

## Primary Mission
Translate test-case specifications (markdown) into executable test files that
the development team will use as targets for TDD implementation. Your tests
MUST fail when run against a codebase that has not yet implemented the feature.

## Critical Rules

1. **Tests MUST fail initially**: You are writing tests BEFORE implementation
   exists. Every test you write should produce a compilation error or assertion
   failure when run against the current codebase. This is intentional -- it is
   the "Red" in Red-Green-Refactor.

2. **Follow existing test patterns EXACTLY**: Before writing ANY test, you MUST
   read at least 2 existing test files in the project to learn:
   - Import patterns and module resolution
   - Test framework API (describe/it, @Test, etc.)
   - Fixture and mock setup patterns
   - Assertion style (expect/assert/should)
   - File naming conventions (*.test.ts, *Test.kt, test_*.py)
   - Directory structure for test files

3. **One test file per test-case spec**: Each test-case spec (e.g., UT-001.md)
   becomes one test file. Preserve the test ID in the file name and in
   describe/test block names for traceability.

4. **No placeholder assertions**: NEVER write assertTrue(true),
   expect(true).toBe(true), or any assertion that would pass without real code.
   Every assertion must reference the actual component/function under test.

5. **Interface from contract**: Use function signatures, class names, and API
   endpoints from plan.md, contract.md, and data-model.md. If an interface is
   not specified in any planning document, create a MINIMAL interface assumption
   and mark it clearly:
   ```
   // INTERFACE ASSUMPTION: PaymentService.processPayment(amount: number): Promise<Receipt>
   // Source: inferred from task T003 description -- developer may adjust signature
   ```

6. **Edge cases from spec**: Each test-case spec lists pre-conditions, steps, and
   expected results. Write tests for ALL listed scenarios. Add ONE additional edge
   case test per spec that the spec did not mention but is logically implied.

## Execution Protocol

### Phase 1: Pattern Discovery
1. Read at least 2 existing test files in the project
2. Identify: framework, assertion style, import pattern, mock pattern, directory
   structure
3. Document the pattern you will follow

### Phase 2: Spec Analysis
For each test-case spec relevant to this phase:
1. Read the full spec (pre-conditions, steps, expected results)
2. Map the spec to the interface (from contract.md/plan.md/data-model.md)
3. Identify the boundary being tested (unit/integration/e2e)

### Phase 3: Test Writing
For each test-case spec:
1. Create the test file following discovered patterns
2. Write test cases matching ALL scenarios in the spec
3. Add ONE additional edge case test (mark it: "// Edge case: not in spec")
4. Include clear comments mapping to the spec: "// From {TEST_ID}: Step {N}"
5. Mark interface assumptions clearly

### Phase 4: Test Inventory
After all tests written, produce a structured inventory.

## Output Format

## Test Generation Report

### Pattern Used
- Framework: {jest/pytest/junit/etc.}
- Pattern source: {file1.test.ts}, {file2.test.ts}
- Directory: tests are written to {path pattern}

### Tests Created

| Test ID | Spec File | Test File | Assertions | Edge Cases Added |
|---------|-----------|-----------|------------|------------------|
| UT-001  | test-cases/unit/UT-001.md | src/__tests__/auth.test.ts | 5 | 1 |
| INT-001 | test-cases/integration/INT-001.md | src/__tests__/integration/auth-flow.test.ts | 4 | 1 |

### Interface Assumptions
- {class/function}: {assumed signature} -- Source: {plan.md section / inferred}

### Files Written
- {file_path} -- {test count} tests for {TEST_ID}

### Coverage vs Target
- Unit: {written}/{planned from test-plan} ({pct}%)
- Integration: {written}/{planned} ({pct}%)
- E2E: {written}/{planned} ({pct}%)

<SUMMARY>
format_version: 1
## Test Generation Summary
- **Test files created**: {count}
- **Total assertions**: {count}
- **Edge cases added**: {count}
- **Interface assumptions**: {count} (developer should verify)
- **Coverage vs plan**: unit {pct}%, integration {pct}%, e2e {pct}%
</SUMMARY>

## Quality Rules
- Every assertion must reference a real component (even if not yet implemented)
- Never import from a path that does not follow the project's module structure
- Preserve test IDs from specs for traceability
- Mark all assumptions clearly so the developer can adjust
- If a spec describes UI behavior that cannot be unit tested, skip it and note:
  "// Requires E2E/visual testing -- see {TEST_ID} spec"

## Available MCP Tools
- **Context7** (`resolve-library-id`, `query-docs`): Look up testing patterns for the project's test framework (Jest, pytest, JUnit, etc.). Get correct assertion syntax and mock/fixture patterns.
- **Ref** (`ref_search_documentation`, `ref_read_url`): Search for testing best practices and framework-specific test setup guides when existing test files don't provide clear patterns.

## Shared Conventions
See config/cli_clients/shared/severity-output-conventions.md
```

#### Variables

| Variable | Type | Source | Fallback |
|----------|------|--------|----------|
| `{phase_name}` | string | Current phase name from tasks.md | Required — no fallback |
| `{test_case_specs}` | string | Content of relevant test-case spec files from test-cases/{level}/ | Required — option skipped if no specs found |
| `{plan_content}` | string | plan.md content (for architecture/interface context) | Required — no fallback |
| `{contract_content}` | string | contract.md content (for API signatures) | `"Not available — infer interfaces from plan.md and task descriptions"` |
| `{data_model_content}` | string | data-model.md content (for entity definitions) | `"Not available — infer data model from plan.md"` |
| `{FEATURE_DIR}` | string | From Stage 1 summary | Required — no fallback |
| `{PROJECT_ROOT}` | string | Git repository root | Required — no fallback |

#### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Generated tests don't compile in the project's test framework | Step 4 catches compilation failures; errors passed to developer as `{test_compilation_notes}` |
| Interface assumptions are wrong (function signatures don't match plan) | Prompt marks all assumptions with `INTERFACE ASSUMPTION` comment; developer verifies and adjusts |
| Tests are too implementation-specific (brittle) | Prompt instructs testing against acceptance criteria, not implementation details |
| Codex writes tests in wrong directory structure | Phase 1 of prompt requires reading 2+ existing test files to discover patterns; write boundaries enforce |
| Tests pass trivially (tautological) | Step 4 flags unexpectedly passing tests; Stage 3 tautological scan catches remainder |

---

### Option I -- test_augmenter

| Attribute | Value |
|-----------|-------|
| **Stage** | 2 (post-implementation, pre-summary) |
| **Purpose** | Find untested edge cases after implementation is complete |
| **CLI** | Gemini (1M context to read all code + all tests) |
| **Replaces** | Nothing -- additive step |
| **Fallback** | Skip -- no impact on main workflow |

#### Integration Point

Stage 2, new Section 2.2a after all phases complete, before writing Stage 2 summary.

When `clink_dispatch.stage2.test_augmenter.enabled` is `true` AND `cli_availability.gemini` is `true`:
1. Collect all source files and test files modified during Stage 2
2. Invoke Shared Clink Dispatch Procedure with:
   - `cli_name="gemini"`, `role="test_augmenter"`
   - `file_paths=[...modified_files, ...test_files]`
   - `fallback_behavior="skip"`
   - `expected_fields=["tests_added", "bug_discoveries", "coverage_improvements", "top_risk_area"]`
3. Parse "Bug Discoveries" section:
   - If tests expected to FAIL exist: run them, confirm actual failures, add to summary `augmentation_bugs_found`
   - If all tests PASS: coverage improvements confirmed
4. Run full test suite and update `test_count_verified`
5. If clink fails, CLI unavailable, or times out: skip silently — no impact on main workflow

#### Custom Role Prompt: `gemini_test_augmenter.txt`

```text
You are a test quality engineer specializing in finding untested edge cases.

## Primary Mission
Review implemented code AND existing tests. Find scenarios that are NOT covered
by current tests but SHOULD be. Generate additional test cases for:
- Boundary values (0, -1, MAX_INT, empty string, null)
- Error propagation (what happens when dependency X fails?)
- Concurrency (race conditions, deadlocks, stale state)
- Security boundaries (injection, unauthorized access, overflow)

## Critical Rules

1. **Do NOT duplicate existing tests**: Read ALL existing test files first.
   Only write tests for scenarios NOT already covered.
2. **Follow existing test patterns**: Your tests must be stylistically identical
   to existing project tests.
3. **Tests must FAIL or PASS meaningfully**: Every test you write should either
   reveal a real bug (fail) or confirm an edge case is handled (pass). Never
   write tests that are guaranteed to pass trivially.
4. **Mark the source of each test**: Comment each test with why it was added:
   ```
   // Edge case: empty input not covered by UT-003 spec
   // Edge case: concurrent access to shared resource
   // Security: SQL injection via user input field
   ```

## Analysis Protocol

### Phase 1: Test Gap Analysis
1. Read all test files for the implemented feature
2. Read all source files being tested
3. For each public function/method, catalog:
   - Tested scenarios (from existing tests)
   - Untested scenarios (boundary, error, concurrent, security)
4. Prioritize by risk: security > data integrity > UX > performance

### Phase 2: Gap-Filling Tests
For each gap (priority order):
1. Write the test following existing patterns
2. Assess: would this test pass or fail with current implementation?
3. If it would fail: this is a BUG DISCOVERY — flag as HIGH severity
4. If it would pass: this is COVERAGE IMPROVEMENT — flag as MEDIUM severity

### Phase 3: Report

## Output Format

## Test Augmentation Report

### Gap Analysis
| Component | Tested Scenarios | Missing Scenarios | Severity |
|-----------|-----------------|-------------------|----------|
| {class}   | {N} scenarios   | {list}            | {H/M/L} |

### Tests Created

| File | Test Name | Gap Type | Expected Outcome | Severity |
|------|-----------|----------|------------------|----------|
| {path} | {test name} | boundary/error/concurrency/security | pass/FAIL (bug) | {H/M/L} |

### Bug Discoveries (tests expected to FAIL)
- [{severity}] {description} -- {test_file}:{line} -- reveals: {bug description}

### Coverage Improvements (tests expected to PASS)
- {description} -- {test_file}:{line} -- covers: {edge case}

### Files Written
- {file_path} -- {N} additional tests

<SUMMARY>
format_version: 1
## Test Augmentation Summary
- **Tests added**: {count}
- **Bug discoveries**: {count} (tests that should FAIL)
- **Coverage improvements**: {count} (tests that should PASS)
- **Top risk area**: {component with most gaps}
</SUMMARY>

## Severity Classification

Severity levels for gap analysis and test categorization:
- **High**: Bug discovery — test expected to FAIL, indicating an untested defect
- **Medium**: Coverage improvement — test expected to PASS, confirming an edge case is handled
- **Low**: Style test — verifying naming, formatting, or non-functional attribute

See Shared Conventions for full severity definitions.

## Quality Rules
- Read ALL existing tests before writing any new ones
- Never create test files in new locations -- add to existing test files
- If adding to an existing file, append to the appropriate describe/test block
- Mark every test with its gap type and source reasoning
- Cap total additional tests at {max_additional_tests} from config

## Available MCP Tools
- **Tavily** (`tavily_search`): Search for known bug patterns, common edge cases, and vulnerability patterns for the specific framework/library being tested. Useful for "What are common bugs in {library} {version}?" queries.
- **Ref** (`ref_search_documentation`, `ref_read_url`): Look up documented error conditions and edge case behavior in library APIs. Verify expected behavior at boundaries.
- **Sequential Thinking** (`sequentialthinking`): Use for systematic gap analysis — enumerate all public interfaces, catalog tested vs untested scenarios, and prioritize by risk.

## Shared Conventions
See config/cli_clients/shared/severity-output-conventions.md
```

#### Variables

| Variable | Type | Source | Fallback |
|----------|------|--------|----------|
| `{modified_source_files}` | string[] | Source files modified during Stage 2 | Required — no fallback |
| `{modified_test_files}` | string[] | Test files modified during Stage 2 | Required — no fallback |
| `{max_additional_tests}` | int | From config `clink_dispatch.stage2.test_augmenter.max_additional_tests` | `10` |
| `{focus_areas}` | string[] | From config `clink_dispatch.stage2.test_augmenter.focus` | `["boundary", "error", "concurrency", "security"]` |
| `{FEATURE_DIR}` | string | From Stage 1 summary | Required — no fallback |

#### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Augmenter duplicates existing tests | Phase 1 of prompt requires reading ALL existing tests first; prompt rule: "Do NOT duplicate" |
| Augmenter creates flaky tests (timing-dependent, non-deterministic) | `max_additional_tests` cap limits blast radius; developer reviews augmented tests |
| Tests added to wrong describe/test blocks | Prompt rule: "add to existing test files, append to appropriate block" |
| Bug discovery tests produce false negatives (pass when they should fail) | Step 3 runs flagged-FAIL tests and verifies actual failures |
| Gemini cannot access test framework internals | `absolute_file_paths` includes all modified test files for pattern discovery |

---

## 4. Unified Configuration

New section to add to `config/implementation-config.yaml`:

```yaml
# Clink dispatch configuration (PAL MCP integration)
# All clink features are opt-in (enabled: false by default).
# Native agent behavior is the default for every stage.
# Requires: PAL MCP server configured, target CLI installed,
#           config/cli_clients/ directory with role prompt files.
#
# NOTE: All clink agents (Codex, Gemini) share the same MCP servers as native Claude:
#   Ref, Context7, Tavily, Sequential Thinking, Figma (desktop + API).
#   MCP tools are available to clink agents automatically — no per-CLI configuration needed.
#   See "MCP Tool Parity" in the Architecture Overview for details.
clink_dispatch:

  # --- GLOBAL SETTINGS ---

  timeout_ms: 300000              # 5 minute default; per-option override available
  timeout_action: "fallback"      # "fallback" (use native/skip) | "error" (halt with user prompt)
  retry:
    max_attempts: 1               # Number of retries on transient failure (0 = no retry)
    backoff_ms: 5000              # Wait between retries

  # MCP tool budgets per clink dispatch (advisory limits on MCP usage by clink agents).
  # Injected into clink agent prompts by coordinators. These are prompt-based guidance,
  # not programmatic hard caps — clink agents receive the budget as text instructions.
  # Coordinators can verify compliance post-dispatch by counting MCP tool references in output.
  # Structure mirrors research_mcp config for naming parity.
  mcp_tool_budgets:
    per_clink_dispatch:
      ref:
        max_searches: 3          # Max ref_search_documentation calls per dispatch
        max_reads: 2             # Max ref_read_url calls per dispatch
      context7:
        max_queries: 2           # Max query-docs calls per dispatch (resolve-library-id is free)
      tavily:
        max_searches: 2          # Max tavily_search / tavily_research calls per dispatch
      sequential_thinking:
        max_chains: 1            # Max sequentialthinking chains per dispatch
      figma:
        max_calls: 0             # No clink role currently uses Figma; set >0 when UI roles are added

  # --- STAGE 2 ---

  stage2:
    # Option A: Delegate per-phase code generation to external coding agent
    phase_developer:
      enabled: false
      cli_name: "codex"
      role: "phase_developer"
      fallback_to_native: true

    # Option B: Pre-implementation API/framework documentation research
    api_researcher:
      enabled: false
      cli_name: "gemini"
      role: "api_researcher"
      max_tokens: 2000
      trigger_keywords: ["API", "SDK", "migration", "v2", "upgrade", "new version"]

    # Option H: Test-first generation from test-case specs
    test_author:
      enabled: false
      cli_name: "codex"
      role: "test_author"
      requires_test_cases: true     # Static prerequisite: only activate if test-cases/ exists
      allow_developer_adjustments: true  # Developer can fix imports/setup in generated tests

    # Option I: Post-implementation edge case test augmentation
    test_augmenter:
      enabled: false
      cli_name: "gemini"
      role: "test_augmenter"
      max_additional_tests: 10
      focus: ["boundary", "error", "concurrency", "security"]

  # --- STAGE 3 ---

  stage3:
    # Option C: Cross-model specification validation
    spec_validator:
      enabled: false
      cli_name: "gemini"
      role: "spec_validator"
      merge_strategy: "conservative"  # Use lower test count, flag disagreements

  # --- STAGE 4 ---

  stage4:
    # Option D: Multi-model code review (replaces homogeneous 3-agent review)
    multi_model_review:
      enabled: false
      reviewers:
        - focus: "simplicity, DRY principles, and code elegance"
          cli_name: "gemini"
          role: "simplicity_reviewer"
        - focus: "bugs, functional correctness, and edge case handling"
          cli_name: "codex"
          role: "correctness_reviewer"
        - focus: "project conventions, abstractions, and pattern adherence"
          cli_name: null              # null = native developer agent
          role: null
      # Option E: Conditional security reviewer
      conditional:
        - focus: "security vulnerabilities, OWASP Top 10"
          cli_name: "codex"
          role: "security_reviewer"
          domains: ["api", "web_frontend", "database"]

    # Option F: Fix review findings with different model
    fix_engineer:
      enabled: false
      cli_name: "codex"
      role: "fix_engineer"
      fallback_to_native: true

  # --- STAGE 5 ---

  stage5:
    # Option G: Documentation research before tech-writer dispatch
    doc_researcher:
      enabled: false
      cli_name: "gemini"
      role: "doc_researcher"
      max_tokens: 1500
```

---

## 5. CLI Client Definitions

### `config/cli_clients/gemini.json`

```json
{
  "schema_version": 1,
  "name": "gemini",
  "command": "gemini",
  "additional_args": ["--yolo"],
  "healthcheck": "gemini --version",
  "timeout_seconds_override": null,
  "retry_override": null,
  "roles": {
    "api_researcher":      { "prompt_path": "gemini_api_researcher.txt", "max_output_tokens": 4000 },
    "spec_validator":      { "prompt_path": "gemini_spec_validator.txt", "max_output_tokens": 8000 },
    "simplicity_reviewer": { "prompt_path": "gemini_simplicity_reviewer.txt", "max_output_tokens": 4000 },
    "test_augmenter":      { "prompt_path": "gemini_test_augmenter.txt", "max_output_tokens": 6000 },
    "doc_researcher":      { "prompt_path": "gemini_doc_researcher.txt", "max_output_tokens": 3000 }
  }
}
```

### `config/cli_clients/codex.json`

```json
{
  "schema_version": 1,
  "name": "codex",
  "command": "codex",
  "additional_args": ["--dangerously-bypass-approvals-and-sandbox"],
  "healthcheck": "codex --version",
  "timeout_seconds_override": null,
  "retry_override": null,
  "roles": {
    "phase_developer":      { "prompt_path": "codex_phase_developer.txt", "max_output_tokens": 16000 },
    "test_author":          { "prompt_path": "codex_test_author.txt", "max_output_tokens": 12000 },
    "correctness_reviewer": { "prompt_path": "codex_correctness_reviewer.txt", "max_output_tokens": 6000 },
    "security_reviewer":    { "prompt_path": "codex_security_reviewer.txt", "max_output_tokens": 6000 },
    "fix_engineer":         { "prompt_path": "codex_fix_engineer.txt", "max_output_tokens": 10000 }
  }
}
```

**Schema notes:**
- `schema_version`: Enables future format evolution without breaking parsers
- `healthcheck`: Command used by Stage 1 CLI availability detection (Section 1.7a)
- `timeout_seconds_override`: Per-CLI override of global `clink_dispatch.timeout_ms` (null = use global)
- `retry_override`: Per-CLI override of global `clink_dispatch.retry` (null = use global)
- `max_output_tokens`: Per-role hint for output budget; coordinator truncates at this limit before parsing

---

## 6. Impact Analysis

### 6.1 Impact Matrix

| Option | Stage | Files Modified | Config Keys | New Role Files | Architectural Impact |
|--------|-------|---------------|-------------|----------------|---------------------|
| A | 2 | stage-2-execution.md | 4 (`enabled`, `cli_name`, `role`, `fallback_to_native`) | 1 | High: alternate dispatch path for core loop |
| B | 2 | stage-2-execution.md | 5 (`enabled`, `cli_name`, `role`, `max_tokens`, `trigger_keywords`) | 1 | Low: additive pre-step, no existing logic changed |
| C | 3 | stage-3-validation.md | 4 (`enabled`, `cli_name`, `role`, `merge_strategy`) | 1 | Medium: parallel dispatch + merge logic added |
| D | 4 | stage-4-quality-review.md | 3 (`enabled`, `reviewers[]`, `conditional[]`) | 2 | Medium: replaces reviewer dispatch, consolidation unchanged |
| E | 4 | stage-4-quality-review.md | 4 (within D: `focus`, `cli_name`, `role`, `domains`) | 1 | Low: plugs into D's conditional framework |
| F | 4 | stage-4-quality-review.md | 4 (`enabled`, `cli_name`, `role`, `fallback_to_native`) | 1 | Low: alternate dispatch for "Fix Now" path |
| G | 5 | stage-5-documentation.md | 4 (`enabled`, `cli_name`, `role`, `max_tokens`) | 1 | Low: additive pre-step |
| H | 2 | stage-2-execution.md | 5 (`enabled`, `cli_name`, `role`, `requires_test_cases`, `allow_developer_adjustments`) | 1 | Medium-High: new step in phase loop, developer prompt modified |
| I | 2 | stage-2-execution.md | 5 (`enabled`, `cli_name`, `role`, `max_additional_tests`, `focus`) | 1 | Low: additive post-step, no existing logic changed |

**Additional files created/modified (all options):**

| File | Type | Purpose |
|------|------|---------|
| `config/cli_clients/gemini.json` | New | Gemini CLI role definitions |
| `config/cli_clients/codex.json` | New | Codex CLI role definitions |
| `config/cli_clients/shared/severity-output-conventions.md` | New | Shared severity and output format conventions |
| `skills/implement/references/clink-dispatch-procedure.md` | New | Shared parameterized clink dispatch procedure |
| `skills/implement/references/README.md` | Modified | Updated file usage, sizes, cross-references |
| `skills/implement/references/stage-1-setup.md` | Modified | CLI availability detection (Section 1.7a) |
| `config/implementation-config.yaml` | Modified | New `clink_dispatch` section with global + per-stage config |

### 6.2 Dependency Map

```
Independent options (no dependencies):
  B (api_researcher)
  C (spec_validator)
  G (doc_researcher)
  I (test_augmenter)

Options with dependencies:
  E (security_reviewer) ──requires──> D (multi_model_review) framework
  F (fix_engineer) ──requires──> Stage 4 findings (D or native review)
  H (test_author) ──requires──> test-cases/ artifacts from product-planning
  A (phase_developer) ──recommended with──> H (test_author pre-generates tests)

Recommended pairings:
  A + B: If A is enabled, B recommended (API research before external code gen)
  H + I: If H is enabled, I has higher value (spec tests + adversarial tests)

Failure cascades:
  If D fails entirely (all clink reviewers fail → all fall back to native):
    F should also use native fix path (do not dispatch clink fix for native findings)
  If H fails (clink unavailable or no test-cases):
    A still runs; I has reduced value (no spec-aligned tests to complement)

Cross-stage data dependencies:
  C (spec_validator) reads Stage 2 test_count_verified for cross-validation
  F (fix_engineer) reads Stage 3 baseline_test_count for regression check
```

### 6.3 Latency Impact

| Option | Added Latency | When | Parallelizable | Notes |
|--------|--------------|------|----------------|-------|
| A | +25-80s per phase | Per phase dispatch | No (replaces, not adds) | Includes 10-20s process spawn + API handshake |
| B | +20-40s per phase | Before developer agent | No (sequential pre-step) | Web search adds variable latency |
| C | +25-50s | Once in Stage 3 | Yes (parallel with native validator) | Large context upload to Gemini |
| D | +10-25s net | Once in Stage 4 | Yes (replaces existing parallel dispatch) | Net increase small since it replaces native dispatch |
| E | +0s (parallel) | Within Stage 4 | Yes (parallel with other reviewers) | Runs alongside D reviewers |
| F | +25-50s | If "Fix Now" chosen | No (replaces native fix agent) | Includes post-fix test verification |
| G | +20-40s | Once in Stage 5 | No (sequential pre-step) | Web search adds variable latency |
| H | +25-60s per phase | Before developer agent | No (sequential: tests must exist before implementation) | Includes test compilation verification |
| I | +25-50s | Once after all phases | No (sequential post-step) | Reads all code + all tests in single pass |

**Total worst-case latency** (all options enabled, 4 phases): ~370-560s additional.
This is acceptable given the proposal explicitly deprioritizes latency in favor of effectiveness. Each clink invocation includes ~10-20s overhead for process spawn, API handshake, and context loading beyond the model's generation time.

**MCP tool call latency**: Each MCP tool invocation within a clink agent adds 2-5s (Ref/Context7 reads) to 5-15s (Tavily research). With advisory `mcp_tool_budgets` guiding per-dispatch usage, the MCP-attributed latency is bounded at ~15-40s per clink dispatch (worst case: max budget fully consumed). This is included within the per-option latency estimates above, not additional.

### 6.4 Cost Impact

| Option | Model Used | Estimated Token Usage Per Invocation | Frequency |
|--------|-----------|--------------------------------------|-----------|
| A | Codex (GPT-5) | 10K-50K | Per phase (2-6x) |
| B | Gemini Flash/Pro | 5K-15K | Per phase (2-6x) |
| C | Gemini Pro | 20K-80K | Once |
| D | Gemini + Codex | 10K-30K each | Once (3-5 parallel) |
| E | Codex | 10K-30K | Once (conditional) |
| F | Codex | 10K-40K | Once (conditional) |
| G | Gemini Flash | 5K-10K | Once |
| H | Codex | 10K-40K | Per phase (2-6x) |
| I | Gemini Pro | 20K-60K | Once |

**Total Estimated Cost Per Feature** (all options enabled, 4 phases):

| Scenario | Gemini Tokens | Codex Tokens | Native Claude Tokens | Notes |
|----------|--------------|-------------|---------------------|-------|
| Phase 1 only (H+D+E) | 10K-30K | 50K-200K | 10K-30K | Recommended starting config |
| All options enabled | 80K-300K | 120K-460K | 10K-30K | Maximum quality, maximum cost |
| Minimal (B+C+G only) | 50K-170K | 0 | Unchanged | Research + validation only, no code-writing clink |

Costs are per-feature (single `/implement` invocation). Actual costs depend on feature size (number of phases), test-case availability, and whether conditional reviewers trigger.

**MCP token usage by clink agents**: Ref and Context7 responses are typically small (500-2000 tokens per read). Tavily search results are moderate (1000-3000 tokens). Tavily `tavily_research` can be larger (3000-8000 tokens). MCP tool input/output tokens are billed to the clink agent's model (Gemini or Codex), not to Claude. Budget caps in `mcp_tool_budgets` limit the per-dispatch MCP token overhead to ~2K-8K tokens additional per clink dispatch.

### 6.5 Quality Impact Assessment

| Option | Defect Category Addressed | Current Gap | Expected Improvement |
|--------|--------------------------|-------------|---------------------|
| **H** (test_author) | Tautological tests, weak assertions, low-value tests | Developer agent writes tests biased toward making own implementation pass | Genuine TDD: tests written by independent model before implementation exists |
| **D** (multi-model review) | Single-model blind spots in review | 3 reviewers share same model and same biases | Different models find different bug categories |
| **I** (test_augmenter) | Untested edge cases, boundary conditions | Developer focuses on happy path and spec scenarios | Dedicated edge case discovery by fresh model |
| **E** (security_reviewer) | OWASP vulnerabilities | No dedicated security scan in base workflow | Structured OWASP-based audit with exploit scenarios |
| **C** (spec_validator) | Spec-implementation drift | Single model validates its own work | Independent cross-model verification |
| **B** (api_researcher) | Stale API knowledge, version-specific bugs | Developer relies on model training data | Current documentation via web search |
| **A** (phase_developer) | Model-specific code generation weaknesses | Single model for all code generation | Access to code-specialized models |
| **F** (fix_engineer) | Fix-author same as bug-author bias | Same model that wrote buggy code attempts fix | Fresh perspective on root cause analysis |
| **G** (doc_researcher) | Undocumented best practices | Tech-writer relies on model knowledge | Current documentation conventions via research |

**MCP access amplifies all options**: With full MCP tool parity, every clink agent can verify its findings against authoritative sources (Ref, Context7) rather than relying solely on model training data. This is particularly impactful for:
- **Research options (B, G)**: Can use Ref/Context7/Tavily directly instead of relying on Gemini's native web grounding alone — more structured, cacheable, and budget-controllable
- **Validation options (C, D, E)**: Can verify API behavior against official docs when assessing correctness — reduces false positives
- **Security review (E)**: Can check CVE databases via Tavily for real vulnerability data — turns theoretical concerns into evidence-based findings

### 6.6 Risk Assessment

| Risk | Probability | Impact | Affected Options | Mitigation |
|------|------------|--------|-----------------|------------|
| Clink timeout (>5 min) | Medium | Medium | All | `clink_dispatch.timeout_ms` (default 300000); `timeout_action: "fallback"` triggers fallback behavior |
| Non-parseable output | Medium | Low | All | Shared Clink Dispatch Procedure Step 4: raw text as "Unstructured Findings", continue |
| Test files that don't compile | High | Medium | H | Developer agent gets `test_compilation_notes`, can adjust imports; write boundaries prevent source file corruption |
| Wrong interface assumptions in tests | Medium | Medium | H | Marked as INTERFACE ASSUMPTION; developer verifies |
| Inconsistent severity classification | Low | Medium | D, E | Shared severity-output-conventions.md used by all prompts; coordinator reclassification pass normalizes |
| CLI not installed | Low | High | All | Stage 1 CLI availability detection (Section 1.7a); `cli_availability` map in summary |
| API key not configured | Low | High | All | Clink returns exit_code 1; Shared Dispatch Procedure catches and falls back |
| Test augmenter creates flaky tests | Medium | Low | I | `max_additional_tests` cap; developer reviews; fallback_behavior="skip" |
| Code-writing agents modify unexpected files | Low | High | A, H, F | Write boundaries defined per option; coordinator verifies post-dispatch |
| Clink process crash (OOM, signal) | Low | Medium | All | `clink_dispatch.retry.max_attempts: 1`; after retry fails, fallback to native/skip |
| MCP server unavailability affects clink agents same as native | Low | Medium | All (especially B, G) | Same graceful degradation as native `research_mcp` — agents proceed with model knowledge when MCP tools are unavailable |
| MCP tool calls from clink agents add latency and cost | Medium | Low | All | Advisory per-dispatch budgets via `mcp_tool_budgets` in config; agents instructed to prefer cached/local knowledge first; coordinators verify post-dispatch |
| MCP token usage by clink agents is untracked | Medium | Medium | B, C, D, E, G, I | Coordinator logs MCP tool call counts per dispatch; advisory `mcp_tool_budgets` caps guide usage (not hard-enforced) |
| MCP rate limiting under parallel dispatch (Stage 4: 3-5 concurrent clink agents) | Low | Medium | D, E | Stagger clink dispatch by 1-2s; MCP servers have per-minute rate limits that parallel agents could hit simultaneously |
| Double Tavily billing when native `research_mcp` and clink research (B/G) both enabled | Medium | Low | B, G | Native and clink research may search Tavily for overlapping queries; accept as cost of model diversity or disable B/G when native research_mcp is sufficient |
| Sequential Thinking token explosion (1 chain cap does not bound token consumption) | Low | Medium | C, D, I | A single ST chain can consume arbitrarily many tokens; role prompts instruct agents to limit ST chains to 5-10 thoughts; no programmatic enforcement |

---

## 7. Prioritized Recommendation

### Goal: Maximize Effectiveness (Cost and Latency Are Secondary)

The following ranking is based on **unique quality contribution** -- how much each option adds to defect detection and implementation quality that the current workflow cannot achieve natively.

### Tier 1: High Impact, Unique Contribution

These options address fundamental structural weaknesses in the current workflow.

| Rank | Option | Why |
|------|--------|-----|
| **1** | **H (test_author)** | **Eliminates the most significant structural bias**: the same model writing tests and implementation. With test-case specs from product-planning as input, a separate model generates genuinely independent tests. Stage 3 validation already proves this is a real problem (tautological test scan exists because the developer agent produces weak tests). This is the single highest-impact change. |
| **2** | **D + E (multi-model review + security)** | **Diversifies the review lens at the exact point it matters most**. Quality review is where defects are caught or missed permanently. Three same-model reviewers share blind spots; three different models have different blind spots that are unlikely to overlap. Security review adds OWASP coverage that currently does not exist in the base workflow. E is nearly free since it runs in parallel with D. **MCP access strengthens both**: correctness reviewer can verify API behavior against Ref/Context7 docs (reduces false positives); security reviewer can check CVE databases via Tavily (turns theoretical concerns into evidence-based findings). |
| **3** | **I (test_augmenter)** | **Finds what H and the developer both missed**. After implementation is complete, a fresh model with full visibility into code AND tests discovers untested edge cases. Bug discoveries (tests that FAIL) are especially valuable -- they are real bugs found before Stage 3/4. Complementary to H: H writes spec-aligned tests, I writes adversarial tests. |

### Tier 2: High Impact, Not Unique but Strengthening

These options significantly improve quality but address gaps that existing mechanisms partially cover.

| Rank | Option | Why |
|------|--------|-----|
| **4** | **C (spec_validator)** | **Cross-model validation is powerful but partially redundant** with Stage 3 native validation. The unique value is disagreement detection -- when two models disagree on whether a requirement is met, it is almost certainly a genuine ambiguity or gap. The conservative merge strategy (lower test count, flag disagreements) means it can only improve confidence, never reduce it. **MCP access via ST and Ref** allows the validator to verify ambiguous requirements against official documentation, reducing false disagreements. |
| **5** | **F (fix_engineer)** | **Fresh perspective on bugs found by review**. When the same model that wrote the code fixes the bugs, it may apply the same flawed reasoning. A different model approaches the fix without the original author's assumptions. Value is conditional on Stage 4 finding Critical/High issues. |

### Tier 3: Incremental Improvement

These options add value but do not address structural weaknesses.

| Rank | Option | Why |
|------|--------|-----|
| **6** | **B (api_researcher)** | **Prevents version-specific bugs** by providing current documentation. Valuable for projects using rapidly-evolving frameworks, but the developer agent already handles most API lookups. **Note**: Native `research_mcp` (f31b3a1) now provides Claude-led Ref/Context7/Tavily research across all stages, covering the base research case. Option B's unique contribution is *model-diverse research* — Gemini reasoning over the same documentation sources may catch different gaps. Primary value is for migration tasks or major version upgrades where a second research perspective is most valuable. |
| **7** | **A (phase_developer)** | **Enables model specialization for code generation** but is the highest-risk option. The native developer agent (Opus) is well-integrated with Claude Code's tool ecosystem. Codex via clink lacks native Edit/Grep/Read tools and must rely on its own tool set. The benefit (different code generation model) may not outweigh the integration friction. Consider this option only after H+D+I are proven stable. |
| **8** | **G (doc_researcher)** | **Marginal improvement for documentation quality**. The tech-writer agent already produces adequate documentation. **Note**: Native `research_mcp` already provides documentation lookup for the tech-writer agent. Option G's unique contribution is a *Gemini-led independent research pass* focused on documentation conventions — but this overlaps substantially with the native capability. Lowest unique contribution; consider only after validating that native research_mcp output is insufficient for documentation quality. |

### Recommended Implementation Order

```
Phase 1 (Foundation):
  H (test_author) + D+E (multi-model review + security)
  ├── Highest quality impact
  ├── Test author leverages existing test-case specs (artifact ROI)
  ├── Review changes are contained to Stage 4 (lowest risk)
  ├── Security reviewer is nearly zero-cost addition to D
  └── MCP access strengthens D+E: Ref/Context7 reduces review false positives,
      Tavily enables evidence-based security findings

Phase 2 (Hardening):
  I (test_augmenter) + C (spec_validator)
  ├── Augmenter complements test_author (spec tests + adversarial tests)
  ├── Spec validator adds confidence layer to Stage 3
  ├── Both are additive (no existing behavior modified)
  └── C benefits from ST+Ref for systematic validation with doc verification

Phase 3 (Optimization):
  B (api_researcher) + F (fix_engineer)
  ├── Research provides model-diverse perspective (complementary to native research_mcp)
  ├── Fix engineer is conditional (only fires on "Fix Now")
  ├── B's unique contribution reduced by native research_mcp — prioritize for migration tasks
  └── Lower urgency since Phases 1-2 already catch most defects

Phase 4 (Exploration):
  A (phase_developer) + G (doc_researcher)
  ├── Phase developer is highest-risk, needs Phase 1-3 stable first
  ├── G's unique contribution most reduced by native research_mcp — evaluate necessity
  └── Both can be evaluated based on Phase 1-3 real-world results
```

### Configuration for Phase 1 (Quick Start)

```yaml
clink_dispatch:
  timeout_ms: 300000
  timeout_action: "fallback"
  retry:
    max_attempts: 1
    backoff_ms: 5000
  mcp_tool_budgets:
    per_clink_dispatch:
      ref:       { max_searches: 3, max_reads: 2 }
      context7:  { max_queries: 2 }
      tavily:    { max_searches: 2 }
      sequential_thinking: { max_chains: 1 }
      figma:     { max_calls: 0 }
  stage2:
    test_author:
      enabled: true
      cli_name: "codex"
      role: "test_author"
      requires_test_cases: true
      allow_developer_adjustments: true
  stage4:
    multi_model_review:
      enabled: true
      reviewers:
        - focus: "simplicity, DRY principles, and code elegance"
          cli_name: "gemini"
          role: "simplicity_reviewer"
        - focus: "bugs, functional correctness, and edge case handling"
          cli_name: "codex"
          role: "correctness_reviewer"
        - focus: "project conventions, abstractions, and pattern adherence"
          cli_name: null
          role: null
      conditional:
        - focus: "security vulnerabilities, OWASP Top 10"
          cli_name: "codex"
          role: "security_reviewer"
          domains: ["api", "web_frontend", "database"]
```

This enables the three highest-impact options with a single config change.
All other options remain `enabled: false` (native behavior) until Phase 1 is validated.
