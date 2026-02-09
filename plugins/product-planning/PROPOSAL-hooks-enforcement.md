# Proposal: Hook-Based Enforcement Layer for Product Planning Plugin

> **Version:** 1.1.0
> **Date:** 2026-02-05
> **Status:** PROPOSAL - No files modified
> **Scope:** Plugin-level hooks for the `/product-planning:plan` 9-phase workflow

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Architecture](#3-architecture)
4. [Hook Catalog](#4-hook-catalog)
5. [Complete hooks.json](#5-complete-hooksjson)
6. [Output Contracts](#6-output-contracts)
7. [Shell Script Specifications](#7-shell-script-specifications)
8. [Failure Mode Table](#8-failure-mode-table)
9. [Hook Interaction Matrix](#9-hook-interaction-matrix)
10. [Testing Strategy](#10-testing-strategy)
11. [Logging Strategy](#11-logging-strategy)
12. [Circuit Breaker Pattern](#12-circuit-breaker-pattern)
13. [Development Mode](#13-development-mode)
14. [Priority & Implementation Plan](#14-priority--implementation-plan)
15. [Feature Flags (Config Additions)](#15-feature-flags-config-additions)
16. [Acceptance Criteria](#16-acceptance-criteria)
17. [Appendix A: Resolved Critique Items (v1.0)](#appendix-a-resolved-critique-items-v10)
18. [Appendix B: Resolved Critique Items (v1.1)](#appendix-b-resolved-critique-items-v11)

---

## 1. Executive Summary

The product-planning plugin orchestrates a 9-phase workflow launching 16 subagents across architecture design, test planning, and task generation. Currently **all enforcement** (immutable decisions, lock protocol, budget limits, output quality, completeness checks) is purely prompt-based, relying on the LLM to follow markdown instructions.

This proposal introduces a **hook-based enforcement layer** with 14 hooks across 7 event types, adding deterministic safety nets without modifying existing skill or agent files. Hooks act as guardrails: the skill handles orchestration (happy path), hooks guarantee invariants (safety net).

**Key metrics:**
- 14 hooks total (11 command, 3 prompt)
- 7 event types covered (PreToolUse, PostToolUse, Stop, SubagentStop, UserPromptSubmit, SessionStart, PreCompact)
- 11 shell scripts + 3 prompt definitions
- Estimated overhead: ~2s average per command hook, ~10-15s per prompt hook

**Prerequisites:**
- `jq` (required) - JSON parsing in all command hooks
- `yq` v4+ (mikefarah/yq, recommended) - YAML parsing; grep/sed fallback if missing
- `git` (recommended) - Branch detection for feature directory

---

## 2. Problem Statement

### Current State

| Enforcement | Mechanism | Reliability |
|-------------|-----------|-------------|
| Immutable decisions | SKILL.md instruction: "NEVER re-ask" | Prompt-dependent, fails on context loss |
| Lock protocol | SKILL.md Step 1.4 | LLM may skip, no prevention |
| Research budget | Config value, no runtime enforcement | Budget can be exceeded silently |
| Agent output quality | S1 self-critique (prompt-based) | Agent may skip critique |
| Workflow completeness | Manual checkpoint in SKILL.md | LLM may stop mid-workflow |
| Context preservation | None | Lost during compaction |
| Spec immutability | Convention only | Spec can be edited mid-planning |

### Target State

Each enforcement above maps to a deterministic hook that cannot be bypassed by the LLM, because hooks execute at the Claude Code runtime level before/after tool calls.

---

## 3. Architecture

### Design Principles

1. **Skill = Orchestration, Hooks = Enforcement** - Hooks never duplicate workflow logic; they enforce invariants the skill assumes
2. **Prefer Command over Prompt** - Command hooks are deterministic, cheaper (no LLM call), and faster. Use prompt hooks only when contextual reasoning is required
3. **Fail-Safe Defaults** - Each hook declares whether it fails open (allow) or closed (deny) when the hook itself errors
4. **Config-Driven** - All thresholds read from `config/planning-config.yaml` at runtime; no hardcoded values in scripts
5. **Observable** - Every hook decision is logged to an audit file for debugging

### Hook Lifecycle

```
Session Start
  ├─ H13: setup-planning-env.sh → sets env vars
  │
User Prompt Submitted
  ├─ H06: inject-planning-context.sh → adds state to systemMessage
  │
Tool Call (PreToolUse)
  ├─ H01: guard-immutable-decisions.sh → blocks re-asked questions
  ├─ H02: enforce-planning-lock.sh → blocks writes without lock
  ├─ H03: research-budget-tracker.sh → blocks over-budget MCP calls
  ├─ H04: protect-spec-immutability.sh → blocks spec.md edits mid-planning
  │
Tool Result (PostToolUse)
  ├─ H05: checkpoint-logger.sh → logs state transitions
  │
Subagent Stops (SubagentStop)
  ├─ H07: validate-tech-lead-output.sh → TDD structure + sections check
  ├─ H08: validate-architect-output (prompt) → blueprint completeness
  ├─ H09: validate-qa-strategist-output.sh → UAT format + test IDs
  ├─ H10: validate-agent-generic.sh (command) → minimal section check
  │
Main Agent Stops (Stop)
  ├─ H11a: check-required-artifacts.sh → file existence check
  ├─ H11b: check-workflow-completeness (prompt) → logical completeness
  │
Before Context Compaction (PreCompact)
  ├─ H12: preserve-planning-context.sh → injects critical state
```

### Agents Coverage

| Agent | SubagentStop Hook | Validation |
|-------|-------------------|------------|
| `product-planning:tech-lead` | H07 (command) | TDD structure, test refs, checklist format |
| `product-planning:software-architect` | H08 (prompt) | Component design, data flow, file paths |
| `product-planning:qa-strategist` | H09 (command) | UAT Given-When-Then, test IDs (UT/INT/E2E/UAT) |
| `product-planning:code-explorer` | H10 (command) | Architecture layers, integration points |
| `product-planning:qa-security` | H10 (command) | STRIDE categories, threat assessment |
| `product-planning:qa-performance` | H10 (command) | Load targets, latency requirements |
| `product-planning:researcher` | H10 (command) | Technology decisions, risk assessment |
| `product-planning:flow-analyzer` | H10 (command) | Entry/exit points, decision tree |
| `product-planning:learnings-researcher` | H10 (command) | Relevance scoring, pattern matches |
| `product-planning:phase-gate-judge` | H10 (command) | Score, verdict, retry feedback |
| `product-planning:security-analyst` | H10 (command) | STRIDE analysis, severity ratings |
| `product-planning:simplicity-reviewer` | H10 (command) | Over-engineering findings |
| `product-planning:wildcard-architect` | H10 (command) | Unconstrained approaches |
| `product-planning:debate-judge` | H10 (command) | Round verdicts, consensus |
| `product-planning:architecture-pruning-judge` | H10 (command) | Ranked scores, pruning rationale |
| `product-planning:tech-writer` | H10 (command) | Documentation completeness |

---

## 4. Hook Catalog

### H01: Guard Immutable Decisions

| Field | Value |
|-------|-------|
| **Event** | PreToolUse |
| **Matcher** | `AskUserQuestion` |
| **Type** | Command |
| **Script** | `hooks/guard-immutable-decisions.sh` |
| **Timeout** | 5s |
| **Fail-Safe** | Fail-open (allow) |
| **Problem** | LLM may re-ask questions whose answers are already saved as immutable `user_decisions` in `.planning-state.local.md`, especially after context compaction or resume |
| **Mechanism** | Script parses YAML frontmatter from state file, extracts `user_decisions` keys, performs normalized keyword matching against the question text in `$TOOL_INPUT`. If overlap score exceeds threshold, denies with the cached answer in `systemMessage` |

**Matching Algorithm (resolves critique item):**

The script uses **normalized keyword extraction**, not exact string match:

```
1. EXTRACT question text from $TOOL_INPUT (the "question" field)
2. NORMALIZE: lowercase, strip punctuation, remove stopwords (the, a, should, we, etc.)
3. TOKENIZE into keyword set: {"redis", "caching", "session", "store"}
4. FOR EACH decision_key IN user_decisions:
     NORMALIZE decision_key into keyword set
     overlap = |question_keywords ∩ decision_keywords| / |decision_keywords|
     IF overlap >= 0.6:
       DENY with cached answer
5. IF no match found: ALLOW
```

**Example:**
- Saved decision: `"Should we use Redis for session caching?" → "Yes, use Redis"`
- New question: `"What caching strategy for sessions?"`
- Keywords: `{caching, strategy, sessions}` vs `{redis, session, caching}`
- Overlap: `{caching, session}` / `{redis, session, caching}` = 2/3 = 0.67 >= 0.6
- Result: **DENY** with systemMessage: `"Decision already made: 'Yes, use Redis'"`

---

### H02: Enforce Planning Lock

| Field | Value |
|-------|-------|
| **Event** | PreToolUse |
| **Matcher** | `Write\|Edit` |
| **Type** | Command |
| **Script** | `hooks/enforce-planning-lock.sh` |
| **Timeout** | 3s |
| **Fail-Safe** | Fail-open (allow) |
| **Problem** | Concurrent planning sessions or writes outside the lock protocol could corrupt state files |
| **Mechanism** | Checks if the target file path is under `$FEATURE_DIR/`. If yes, verifies `.planning.lock` exists and belongs to the current session (matching `session_id` from hook input). If lock missing or owned by another session, denies |

**Scope:** Only applies to writes under `$FEATURE_DIR/` (the planning workspace). Writes to other paths are always allowed.

---

### H03: Research Budget Tracker

| Field | Value |
|-------|-------|
| **Event** | PreToolUse |
| **Matcher** | `mcp__context7__.*\|mcp__Ref__.*\|mcp__tavily__.*` |
| **Type** | Command |
| **Script** | `hooks/research-budget-tracker.sh` |
| **Timeout** | 3s |
| **Fail-Safe** | Fail-open (allow) |
| **Problem** | Research MCP calls have costs. Config defines `total_calls_per_session: 25` and `total_calls_per_phase: 10` but enforcement is prompt-based only |

**Budget Scope (resolves critique item):**

The tracker enforces a **hierarchical** budget with two independent counters:

```
COUNTER FILE: /tmp/planning-research-budget-{session_id}.json

Schema:
{
  "session_total": 0,        # Increments per call, resets per session
  "phase_total": 0,          # Increments per call, resets per phase checkpoint
  "current_phase": "RESEARCH",
  "per_server": {
    "context7": 0,
    "ref": 0,
    "tavily": 0
  }
}

READ limits from $CLAUDE_PLUGIN_ROOT/config/planning-config.yaml:
  session_limit = research_mcp.budget.total_calls_per_session  # 25
  phase_limit = research_mcp.budget.total_calls_per_phase      # 10
  warn_pct = research_mcp.budget.warn_at_percentage            # 80

DECISION LOGIC:
  IF session_total >= session_limit → DENY "Session budget exhausted (25/25)"
  IF phase_total >= phase_limit → DENY "Phase budget exhausted (10/10)"
  IF session_total >= session_limit * warn_pct/100 → ALLOW + WARN in systemMessage
  IF phase_total >= phase_limit * warn_pct/100 → ALLOW + WARN in systemMessage
  ELSE → ALLOW

PHASE RESET:
  When checkpoint-logger.sh (H05) detects a phase transition,
  it writes "phase_total: 0" to the budget file.
```

**Idempotency:** Each call is tracked by a hash of `tool_name + JSON.stringify(tool_input)`. Retries with identical input don't increment the counter.

---

### H04: Protect Spec Immutability

| Field | Value |
|-------|-------|
| **Event** | PreToolUse |
| **Matcher** | `Write\|Edit` |
| **Type** | Command |
| **Script** | `hooks/protect-spec-immutability.sh` |
| **Timeout** | 3s |
| **Fail-Safe** | Fail-open (allow) |
| **Problem** | `spec.md` is the source of truth for requirements. Modifying it mid-planning invalidates all downstream artifacts (architecture, tests, tasks) |
| **Mechanism** | If the target file ends with `/spec.md` AND `.planning-state.local.md` exists with `phase` past SETUP, denies the write. Before SETUP or if no state file, allows (spec is still being drafted) |

**Scope:** Only protects `spec.md` after planning has started. Does not protect `constitution.md` (assumed immutable by convention).

---

### H05: Checkpoint Logger

| Field | Value |
|-------|-------|
| **Event** | PostToolUse |
| **Matcher** | `Write` |
| **Type** | Command |
| **Script** | `hooks/checkpoint-logger.sh` |
| **Timeout** | 3s |
| **Fail-Safe** | Fail-open (allow; logging failure is non-blocking) |
| **Problem** | No audit trail for state transitions. Difficult to debug when a phase was entered, what decisions were made, or whether checkpoints were properly saved |
| **Mechanism** | If the written file is `.planning-state.local.md`, extracts the `phase` field from YAML frontmatter and appends a timestamped entry to `{FEATURE_DIR}/.planning-audit.log`. Also resets the phase budget counter in H03's budget file |

**Audit Log Format:**
```
[2026-02-04T14:23:15Z] CHECKPOINT: RESEARCH → CLARIFICATION | session=abc123 | mode=complete
[2026-02-04T14:25:01Z] CHECKPOINT: CLARIFICATION → ARCHITECTURE | session=abc123 | mode=complete
```

---

### H06: Context Injection

| Field | Value |
|-------|-------|
| **Event** | UserPromptSubmit |
| **Matcher** | `*` |
| **Type** | Command |
| **Script** | `hooks/inject-planning-context.sh` |
| **Timeout** | 5s |
| **Fail-Safe** | Fail-open (allow without context; log warning) |
| **Problem** | After resume or context compaction, the LLM may lack awareness of current phase, immutable decisions, and generated artifacts |
| **Mechanism** | Reads `.planning-state.local.md` and emits a structured `systemMessage` with current state summary |

**Injected systemMessage Format:**
```
<planning-state>
phase: ARCHITECTURE
mode: complete
decisions_count: 8
immutable_decisions:
  - "Use Redis for caching"
  - "PostgreSQL as primary DB"
  - "Next.js App Router"
artifacts_generated:
  - research.md (RESEARCH)
  - design.minimal.md (ARCHITECTURE)
  - design.clean.md (ARCHITECTURE)
  - design.pragmatic.md (ARCHITECTURE)
gate_results:
  - gate_1: PASS (4.2/5.0)
lock_active: true
lock_session: abc123
</planning-state>
```

**Conditional Activation:** Only activates when `.planning-state.local.md` exists. If no state file, the hook does nothing (planning hasn't started).

---

### H07: Validate Tech-Lead Output

| Field | Value |
|-------|-------|
| **Event** | SubagentStop |
| **Matcher** | `product-planning:tech-lead` |
| **Type** | Command |
| **Script** | `hooks/validate-tech-lead-output.sh` |
| **Timeout** | 10s |
| **Fail-Safe** | Fail-open (allow; validation failure shouldn't block permanently) |
| **Problem** | Tech-lead agent may produce tasks.md without TDD structure, missing test references, or wrong checklist format. Currently caught only in Step 9.5 (late, expensive retry) |

**Validation Checks:**
```
1. FILE EXISTS: {FEATURE_DIR}/tasks.md is non-empty

2. CHECKLIST FORMAT: Count lines matching `^- \[ \] \[T\d{3}\]`
   IF count < 5 → BLOCK "Too few tasks generated (found {count})"

3. TDD REFERENCES: Count tasks containing "UT-|INT-|E2E-|UAT-"
   tdd_pct = tasks_with_refs / total_tasks * 100
   IF tdd_pct < 80 → BLOCK "Insufficient TDD integration: {tdd_pct}% (need >=80%)"

4. PHASE MARKERS: Check for "## Phase" section headers
   IF count < 2 → BLOCK "Missing phase structure in tasks.md"

5. SELF-CRITIQUE: Check for "self_critique" or "Self-Critique" section
   IF missing AND s1_self_critique enabled → BLOCK "Missing self-critique section"
```

**Why Command Hook (not Prompt):** These checks are pattern-matching on file content - deterministic grep/awk operations, no reasoning needed.

---

### H08: Validate Architect Output

| Field | Value |
|-------|-------|
| **Event** | SubagentStop |
| **Matcher** | `product-planning:software-architect` |
| **Type** | Prompt |
| **Timeout** | 20s |
| **Fail-Safe** | Fail-open (allow) |
| **Problem** | Architecture blueprints may be vague (missing file paths, undefined interfaces, no data flow). This causes downstream failures in Phase 9 task generation |

**Prompt:**
```
Verify the software-architect subagent produced a complete blueprint. Check:

1. COMPONENT DESIGN: Does output contain specific component names with file paths (e.g., "src/models/user.ts")?
2. DATA FLOW: Does output describe how data moves between components?
3. INTERFACES: Are component interfaces defined (function signatures, props, API contracts)?
4. FILES TO CREATE/MODIFY: Is there an explicit list of files?
5. BUILD SEQUENCE: Is there an order for implementation?

Read the architect's output and evaluate. If fewer than 3 of these 5 elements are present, return:
{"decision": "block", "reason": "Blueprint incomplete: missing [list]", "systemMessage": "Architect output lacks: [specific missing elements]. Re-run with more specific requirements."}

If 3+ present, return:
{"decision": "approve", "reason": "Blueprint sufficiently complete", "systemMessage": ""}
```

**Why Prompt Hook (not Command):** Evaluating architectural completeness requires contextual understanding (e.g., "data flow" could be described narratively, as a diagram, or as a sequence). Pattern matching alone would miss valid outputs.

---

### H09: Validate QA Strategist Output

| Field | Value |
|-------|-------|
| **Event** | SubagentStop |
| **Matcher** | `product-planning:qa-strategist` |
| **Type** | Command |
| **Script** | `hooks/validate-qa-strategist-output.sh` |
| **Timeout** | 10s |
| **Fail-Safe** | Fail-open (allow) |
| **Problem** | QA strategist produces user-facing artifacts (UAT scripts). Missing test IDs or incorrect format cascades into Phase 8 coverage validation failure and Phase 9 TDD integration gaps |

**Validation Checks:**
```
1. TEST IDS PRESENT:
   unit_ids = grep -c "^##\? UT-\d" test-cases/unit/*.md
   int_ids = grep -c "^##\? INT-\d" test-cases/integration/*.md
   e2e_ids = grep -c "^##\? E2E-\d" test-cases/e2e/*.md
   uat_ids = grep -c "^##\? UAT-\d" test-cases/uat/*.md

   IF unit_ids == 0 → BLOCK "No unit test IDs (UT-xxx) found"
   IF uat_ids == 0 → BLOCK "No UAT script IDs (UAT-xxx) found"

2. UAT FORMAT: For each UAT file, check Given-When-Then structure:
   gwt_count = grep -c "Given:\|When:\|Then:" test-cases/uat/*.md
   IF gwt_count < uat_ids * 3 → BLOCK "UAT scripts missing Given-When-Then structure"

3. COVERAGE MATRIX: Check test-plan.md contains a coverage table
   IF NOT grep -q "Coverage Matrix\|coverage matrix" test-plan.md → BLOCK "Missing coverage matrix"
```

---

### H10: Validate Agent Generic

| Field | Value |
|-------|-------|
| **Event** | SubagentStop |
| **Matcher** | `*` |
| **Type** | Command |
| **Script** | `hooks/validate-agent-generic.sh` |
| **Timeout** | 10s |
| **Fail-Safe** | Fail-open (allow) |
| **Problem** | Agents other than tech-lead, software-architect, and qa-strategist also need basic output validation |

**Validation Checks (deterministic, no prompt):**
```
1. AGENT NAME FILTER (resolves V2 critique — deterministic, not prompt-based):
   Read subagent identifier from hook input (matched against SubagentStop matcher).
   DEDICATED_AGENTS=("product-planning:tech-lead" "product-planning:software-architect" "product-planning:qa-strategist")
   IF agent_name IN DEDICATED_AGENTS → APPROVE immediately (dedicated hook handles it)

2. OUTPUT LENGTH: Read agent reason/output from hook input.
   word_count = wc -w on the output text
   IF word_count < 100 → BLOCK "Agent produced insufficient output (<100 words)"

3. STRUCTURE CHECK: grep for section markers in output text.
   has_headers = grep -c '^##\|^###' output_text
   has_lists = grep -c '^- \|^[0-9]\.' output_text
   has_tables = grep -c '|.*|' output_text
   IF has_headers + has_lists + has_tables == 0 → BLOCK "No structured sections found"

4. DEFAULT → APPROVE
```

**Why Command Hook (converted from prompt in v1.1):** The v1.0 proposal used a prompt hook with the instruction "For agents with dedicated hooks, ALWAYS approve here." This re-introduced prompt-based enforcement for the agent-name filtering — exactly the problem hooks aim to solve. The deterministic command hook eliminates this: a hardcoded agent-name array guarantees dedicated agents are always approved, regardless of LLM behavior.

**Conflict Resolution with H07/H08/H09 (resolves critique item):**

When both H10 (wildcard) and a specific hook (H07/H08/H09) fire for the same agent, both run in parallel. The resolution strategy is:

```
H10 (generic): Deterministic agent-name check ALWAYS approves agents with dedicated hooks
                (hardcoded array: tech-lead, software-architect, qa-strategist)
H07/H08/H09:   Performs the actual validation

Result: Only the dedicated hook's decision matters for those agents.
        H10 only actively validates agents WITHOUT a dedicated hook.
```

This is implemented via a hardcoded array check in `validate-agent-generic.sh`, not via prompt instruction.

---

### H11a: Check Required Artifacts

| Field | Value |
|-------|-------|
| **Event** | Stop |
| **Matcher** | `*` |
| **Type** | Command |
| **Script** | `hooks/check-required-artifacts.sh` |
| **Timeout** | 5s |
| **Fail-Safe** | Fail-open (allow; user may intentionally stop early) |
| **Problem** | LLM may attempt to stop before generating all required artifacts |

**Split Rationale (resolves critique item):** The original H5 checked (1) artifact existence, (2) phase completeness, (3) RED status - violating single responsibility. Now split into H11a (deterministic file check) and H11b (contextual completeness).

**Validation:**
```
IF .planning-state.local.md exists:
  READ current phase from YAML frontmatter

  REQUIRED_FOR_COMPLETION = [
    "{FEATURE_DIR}/design.md",
    "{FEATURE_DIR}/plan.md",
    "{FEATURE_DIR}/tasks.md",
    "{FEATURE_DIR}/test-plan.md"
  ]

  missing = []
  FOR artifact IN REQUIRED_FOR_COMPLETION:
    IF NOT exists(artifact) OR file_size(artifact) == 0:
      missing.append(artifact)

  IF missing is not empty AND phase != "COMPLETION":
    BLOCK with: "Missing artifacts: {missing}. Planning not complete."
  ELSE:
    ALLOW

ELSE (no state file):
  ALLOW (planning hasn't started, nothing to guard)
```

---

### H11b: Check Workflow Completeness

| Field | Value |
|-------|-------|
| **Event** | Stop |
| **Matcher** | `*` |
| **Type** | Prompt |
| **Timeout** | 15s |
| **Fail-Safe** | Fail-open (allow) |
| **Problem** | Artifacts may exist but be incomplete, or validation may have failed (RED status) |

**Prompt:**
```
Check if the planning workflow should be allowed to stop. Read .planning-state.local.md and evaluate:

1. Is the current phase "COMPLETION"? If not, the workflow is incomplete.
2. Are there any gate_results with status "RED"? RED means revision needed.
3. Did the user explicitly request to stop? (Check if the last user message contains "stop", "quit", "abort", or "exit")

Decision rules:
- If phase == COMPLETION and no RED statuses → approve
- If user explicitly requested stop → approve (user override)
- If phase != COMPLETION → block with: "Workflow at phase {phase}, not complete. Missing phases: {list}"
- If RED status exists → block with: "Validation failed (RED) at {phase}. Needs revision before stopping."

Return JSON: {"decision": "approve|block", "reason": "...", "systemMessage": "..."}
```

---

### H12: Preserve Planning Context

| Field | Value |
|-------|-------|
| **Event** | PreCompact |
| **Matcher** | `*` |
| **Type** | Command |
| **Script** | `hooks/preserve-planning-context.sh` |
| **Timeout** | 5s |
| **Fail-Safe** | Fail-open (allow compaction without context; log error) |
| **Problem** | Context compaction discards conversation history. In a 9-phase workflow, this loses critical state: current phase, immutable decisions, gate results, artifact inventory |
| **Mechanism** | Reads `.planning-state.local.md` and emits the same structured summary as H06, ensuring post-compaction context includes all critical planning state |

**systemMessage:** Same format as H06's `<planning-state>` block.

---

### H13: Planning Environment Setup

| Field | Value |
|-------|-------|
| **Event** | SessionStart |
| **Matcher** | `*` |
| **Type** | Command |
| **Script** | `hooks/setup-planning-env.sh` |
| **Timeout** | 10s |
| **Fail-Safe** | Fail-open (allow; planning can still work without env vars) |
| **Problem** | Phase 1 (Setup) relies on LLM to detect branch, find feature directory, check prerequisites. This is deterministic work that a script can do faster and more reliably |

**Actions:**
```
1. DETECT git branch:
   branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

2. EXTRACT feature directory:
   IF branch matches "feature/<name>":
     feature_dir="specs/${branch#feature/}"
   ELSE:
     feature_dir=""  # Will need user input

3. CHECK prerequisites:
   spec_exists = test -f "${feature_dir}/spec.md"
   constitution_exists = test -f "specs/constitution.md"

4. CHECK existing state:
   state_exists = test -f "${feature_dir}/.planning-state.local.md"
   IF state_exists:
     current_phase = yq '.phase' "${feature_dir}/.planning-state.local.md"
     current_mode = yq '.mode' "${feature_dir}/.planning-state.local.md"

5. WRITE to $CLAUDE_ENV_FILE:
   echo "export PLANNING_BRANCH=${branch}" >> "$CLAUDE_ENV_FILE"
   echo "export PLANNING_FEATURE_DIR=${feature_dir}" >> "$CLAUDE_ENV_FILE"
   echo "export PLANNING_SPEC_EXISTS=${spec_exists}" >> "$CLAUDE_ENV_FILE"
   echo "export PLANNING_STATE_EXISTS=${state_exists}" >> "$CLAUDE_ENV_FILE"
   echo "export PLANNING_CURRENT_PHASE=${current_phase}" >> "$CLAUDE_ENV_FILE"
   echo "export PLANNING_CURRENT_MODE=${current_mode}" >> "$CLAUDE_ENV_FILE"

6. EMIT systemMessage:
   "Planning environment detected: branch={branch}, feature_dir={feature_dir},
    state={state_exists}, phase={current_phase}, spec={spec_exists}"
```

---

## 5. Complete hooks.json

This is the production-ready `hooks/hooks.json` file in the **plugin wrapper format**.

```json
{
  "description": "Enforcement hooks for product-planning workflow. Provides deterministic safety nets for state integrity, budget limits, output quality, and workflow completeness.",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/setup-planning-env.sh",
            "timeout": 10
          }
        ]
      }
    ],

    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/inject-planning-context.sh",
            "timeout": 5
          }
        ]
      }
    ],

    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/guard-immutable-decisions.sh",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/enforce-planning-lock.sh",
            "timeout": 3
          },
          {
            "type": "command",
            "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/protect-spec-immutability.sh",
            "timeout": 3
          }
        ]
      },
      {
        "matcher": "mcp__context7__.*|mcp__Ref__.*|mcp__tavily__.*",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/research-budget-tracker.sh",
            "timeout": 3
          }
        ]
      }
    ],

    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/checkpoint-logger.sh",
            "timeout": 3
          }
        ]
      }
    ],

    "SubagentStop": [
      {
        "matcher": "product-planning:tech-lead",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/validate-tech-lead-output.sh",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "product-planning:software-architect",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Verify the software-architect subagent produced a complete blueprint. Check: (1) Component names with file paths like 'src/models/user.ts', (2) Data flow description between components, (3) Component interfaces (function signatures, props, API contracts), (4) Explicit list of files to create/modify, (5) Build sequence/implementation order. If fewer than 3 of 5 present, return {\"decision\": \"block\", \"reason\": \"Blueprint incomplete: missing [list]\", \"systemMessage\": \"Architect output lacks: [specific]. Re-run with more specific requirements.\"}. If 3+ present, return {\"decision\": \"approve\", \"reason\": \"Blueprint complete\", \"systemMessage\": \"\"}.",
            "timeout": 20
          }
        ]
      },
      {
        "matcher": "product-planning:qa-strategist",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/validate-qa-strategist-output.sh",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/validate-agent-generic.sh",
            "timeout": 10
          }
        ]
      }
    ],

    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/check-required-artifacts.sh",
            "timeout": 5
          },
          {
            "type": "prompt",
            "prompt": "Check planning workflow completeness. Read .planning-state.local.md: (1) Is phase 'COMPLETION'? (2) Any gate_results with RED status? (3) Did user explicitly request stop (last message contains 'stop'/'quit'/'abort'/'exit')? Rules: phase==COMPLETION and no RED → approve. User explicit stop → approve. phase!=COMPLETION → block with missing phases. RED exists → block with revision needed. Return {\"decision\": \"approve|block\", \"reason\": \"...\", \"systemMessage\": \"...\"}.",
            "timeout": 15
          }
        ]
      }
    ],

    "PreCompact": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/preserve-planning-context.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

---

## 6. Output Contracts

Every hook must produce output conforming to these contracts.

### 6.1 PreToolUse Command Hooks (H01, H02, H03, H04)

**Exit Code 0 (Allow):**
```json
{
  "hookSpecificOutput": {
    "permissionDecision": "allow"
  }
}
```
Printed to **stdout**.

**Exit Code 0 (Allow with Warning):**
```json
{
  "hookSpecificOutput": {
    "permissionDecision": "allow"
  },
  "systemMessage": "WARNING: Research budget at 82% (21/25 session calls used)"
}
```
Printed to **stdout**.

**Exit Code 2 (Deny):**
```json
{
  "hookSpecificOutput": {
    "permissionDecision": "deny"
  },
  "systemMessage": "DENIED: Decision already made for this topic. Cached answer: 'Use Redis for session caching'. Do not re-ask."
}
```
Printed to **stderr**.

### 6.2 PostToolUse Command Hooks (H05)

**Exit Code 0 (Success, informational):**
```
CHECKPOINT: RESEARCH → CLARIFICATION | session=abc123
```
Printed to **stdout** (appears in transcript).

**Exit Code 2 (Error feedback):**
```json
{
  "systemMessage": "ERROR: State file write detected but YAML frontmatter is malformed. Phase field missing."
}
```
Printed to **stderr** (fed back to Claude).

### 6.3 Stop Command Hooks (H11a)

**stdout JSON:**
```json
{
  "decision": "block",
  "reason": "Missing required artifacts: tasks.md, test-plan.md",
  "systemMessage": "Planning incomplete. Missing: tasks.md, test-plan.md. Continue workflow to generate these artifacts."
}
```

### 6.4 SubagentStop Command Hooks (H07, H09, H10)

**stdout JSON:**
```json
{
  "decision": "block",
  "reason": "TDD integration at 45% (need >=80%)",
  "systemMessage": "Tech-lead output has insufficient test references. Only 45% of tasks reference test IDs (UT-/INT-/E2E-/UAT-). Required: >=80%. Please add test references to task Definition of Done sections."
}
```

### 6.5 Prompt Hook Output (H08, H11b)

Prompt hooks return their decision directly. The prompt text explicitly instructs the LLM to return the correct JSON structure (see each hook's prompt definition).

### 6.6 SessionStart / UserPromptSubmit / PreCompact Command Hooks

**Exit Code 0:** stdout content becomes `systemMessage` in the transcript.

**Standard output structure:**
```json
{
  "systemMessage": "<planning-state>\nphase: ARCHITECTURE\nmode: complete\n...</planning-state>"
}
```

---

## 7. Shell Script Specifications

### 7.1 Common Library (`hooks/lib/common.sh`)

All scripts source this shared library rather than duplicating the preamble. Each hook script begins with:
```bash
#!/bin/bash
set -euo pipefail
source "$(dirname "$(dirname "$0")")/lib/common.sh"
```

**Library contents:**

```bash
#!/bin/bash
# hooks/lib/common.sh — Shared library for all hook scripts
# Sourced by each hook, not executed directly.

# ─── Prerequisites ──────────────────────────────────────────────────
# jq is REQUIRED for all hooks. Fail fast if missing.
if ! command -v jq &>/dev/null; then
  echo '{"hookSpecificOutput":{"permissionDecision":"allow"},"systemMessage":"Hook infrastructure error: jq not found. Install jq to enable hook enforcement."}' >&2
  exit 0  # Fail-open: allow without enforcement
fi

# ─── Platform Detection ─────────────────────────────────────────────
# macOS (BSD) vs Linux (GNU) tool differences
OS_TYPE="$(uname -s)"

# Portable md5 hash — macOS has md5, Linux has md5sum
portable_md5() {
  if command -v md5sum &>/dev/null; then
    md5sum | cut -d' ' -f1
  elif command -v md5 &>/dev/null; then
    md5 -q
  else
    # Fallback: use cksum (always available)
    cksum | cut -d' ' -f1
  fi
}

# Portable realpath — not always available on macOS
portable_realpath() {
  if command -v realpath &>/dev/null; then
    realpath "$1" 2>/dev/null || echo "$1"
  elif command -v python3 &>/dev/null; then
    python3 -c "import os; print(os.path.realpath('$1'))" 2>/dev/null || echo "$1"
  else
    echo "$1"
  fi
}

# ─── Input ───────────────────────────────────────────────────────────
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')
hook_event=$(echo "$input" | jq -r '.hook_event_name // empty')

# ─── Config ──────────────────────────────────────────────────────────
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")")")}"
CONFIG_FILE="${PLUGIN_ROOT}/config/planning-config.yaml"

# ─── Feature Dir Detection ──────────────────────────────────────────
# Try env var first (set by H13), then detect from git branch
FEATURE_DIR="${PLANNING_FEATURE_DIR:-}"
if [ -z "$FEATURE_DIR" ]; then
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ "$branch" == feature/* ]]; then
    FEATURE_DIR="${cwd}/specs/${branch#feature/}"
  fi
fi

STATE_FILE="${FEATURE_DIR:+${FEATURE_DIR}/.planning-state.local.md}"
LOCK_FILE="${FEATURE_DIR:+${FEATURE_DIR}/.planning.lock}"
AUDIT_LOG="${FEATURE_DIR:+${FEATURE_DIR}/.planning-audit.log}"
BUDGET_FILE="/tmp/planning-research-budget-${session_id}.json"

# ─── Development Mode ───────────────────────────────────────────────
if [ -f "${PLUGIN_ROOT}/hooks/.dev-mode" ]; then
  log_hook "${HOOK_NAME:-UNKNOWN}" "DEV_SKIP" "Development mode active"
  emit_allow
  exit 0
fi

# ─── JSON Output Helpers ────────────────────────────────────────────
# Use jq for safe JSON construction — prevents injection from shell variables

emit_allow() {
  echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
}

emit_allow_with_message() {
  local msg="$1"
  jq -n --arg msg "$msg" '{"hookSpecificOutput":{"permissionDecision":"allow"},"systemMessage":$msg}'
}

emit_deny() {
  local msg="$1"
  jq -n --arg msg "$msg" '{"hookSpecificOutput":{"permissionDecision":"deny"},"systemMessage":$msg}' >&2
}

emit_stop_block() {
  local reason="$1" msg="$2"
  jq -n --arg reason "$reason" --arg msg "$msg" '{"decision":"block","reason":$reason,"systemMessage":$msg}' >&2
}

emit_stop_approve() {
  jq -n '{"decision":"approve","reason":"Checks passed","systemMessage":""}'
}

# ─── Circuit Breaker ─────────────────────────────────────────────────
# Only counts INFRASTRUCTURE errors (script crashes, tool missing, parse failures).
# Intentional denials (exit 2 from business logic) do NOT increment the counter.
BREAKER_FILE="/tmp/planning-hook-breaker-${session_id}.json"

check_circuit_breaker() {
  local hook_name="$1"
  if [ -f "$BREAKER_FILE" ]; then
    local failures
    failures=$(jq -r ".\"${hook_name}\" // 0" "$BREAKER_FILE" 2>/dev/null || echo 0)
    if [ "$failures" -ge 3 ]; then
      echo '{"hookSpecificOutput":{"permissionDecision":"allow"},"systemMessage":"Hook '"${hook_name}"' circuit breaker OPEN (3+ failures). Skipping validation."}'
      exit 0
    fi
  fi
}

record_hook_failure() {
  local hook_name="$1"
  if [ ! -f "$BREAKER_FILE" ]; then
    echo '{}' > "$BREAKER_FILE"
  fi
  local current
  current=$(jq -r ".\"${hook_name}\" // 0" "$BREAKER_FILE" 2>/dev/null || echo 0)
  jq ".\"${hook_name}\" = $((current + 1))" "$BREAKER_FILE" > "${BREAKER_FILE}.tmp" && mv "${BREAKER_FILE}.tmp" "$BREAKER_FILE"
}

reset_hook_failure() {
  local hook_name="$1"
  if [ -f "$BREAKER_FILE" ]; then
    jq ".\"${hook_name}\" = 0" "$BREAKER_FILE" > "${BREAKER_FILE}.tmp" && mv "${BREAKER_FILE}.tmp" "$BREAKER_FILE"
  fi
}

# ─── ERR Trap ────────────────────────────────────────────────────────
# Implements fail-open for unexpected errors AND wires up circuit breaker.
# Intentional denials use `deny_and_exit` (below) which bypasses this trap.
_hook_err_trap() {
  local exit_code=$?
  record_hook_failure "${HOOK_NAME:-UNKNOWN}"
  log_hook "${HOOK_NAME:-UNKNOWN}" "ERROR" "Unexpected error (exit ${exit_code}). Failing open."
  emit_allow_with_message "Hook ${HOOK_NAME:-UNKNOWN} encountered an unexpected error (exit ${exit_code}). Failing open."
  exit 0
}
trap _hook_err_trap ERR

# ─── Intentional Deny Helper ────────────────────────────────────────
# Use this instead of raw `exit 2` to bypass the ERR trap.
# Intentional denials are NOT circuit breaker failures.
deny_and_exit() {
  local msg="$1"
  log_hook "$HOOK_NAME" "DENY" "$msg"
  emit_deny "$msg"
  trap - ERR  # Disable ERR trap so exit 2 doesn't trigger it
  exit 2
}

deny_stop_and_exit() {
  local reason="$1" msg="$2"
  log_hook "$HOOK_NAME" "BLOCK" "$reason"
  emit_stop_block "$reason" "$msg"
  trap - ERR
  exit 2
}

# ─── Logging ─────────────────────────────────────────────────────────
HOOK_LOG="/tmp/planning-hooks-${session_id}.log"

log_hook() {
  local hook_name="$1" decision="$2" detail="${3:-}"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ${hook_name}: ${decision} | ${detail}" >> "$HOOK_LOG" 2>/dev/null || true
}

# ─── YAML Parsing Helper ────────────────────────────────────────────
# Uses yq if available, falls back to grep+sed
parse_yaml_field() {
  local file="$1" field="$2"
  if command -v yq &>/dev/null; then
    yq -r ".${field} // empty" "$file" 2>/dev/null
  else
    # Fallback: extract from YAML frontmatter between --- markers
    sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//"
  fi
}

# ─── Integer Safety Helper ──────────────────────────────────────────
# Ensures a value is a valid integer, defaulting to 0
safe_int() {
  local val="$1"
  val="${val//[!0-9]/}"
  echo "${val:-0}"
}
```

### 7.2 H01: guard-immutable-decisions.sh

```bash
#!/bin/bash
set -euo pipefail
HOOK_NAME="H01_immutable_guard"
source "$(dirname "$(dirname "$0")")/lib/common.sh"

check_circuit_breaker "$HOOK_NAME"

# ─── Skip if no state file ──────────────────────────────────────────
if [ -z "$STATE_FILE" ] || [ ! -f "$STATE_FILE" ]; then
  log_hook "$HOOK_NAME" "ALLOW" "No state file, planning not started"
  emit_allow
  exit 0
fi

# ─── Extract question text from tool input ───────────────────────────
question=$(echo "$input" | jq -r '.tool_input.questions[0].question // empty')
if [ -z "$question" ]; then
  log_hook "$HOOK_NAME" "ALLOW" "No question text found in tool input"
  emit_allow
  exit 0
fi

# ─── Extract user_decisions from state ───────────────────────────────
# yq is required here for extracting nested YAML mapping to JSON
if ! command -v yq &>/dev/null; then
  log_hook "$HOOK_NAME" "ALLOW" "yq not installed, cannot parse user_decisions"
  emit_allow
  exit 0
fi
decisions_json=$(yq -o=json '.user_decisions // {}' "$STATE_FILE" 2>/dev/null || echo '{}')
if [ "$decisions_json" = '{}' ] || [ "$decisions_json" = 'null' ]; then
  log_hook "$HOOK_NAME" "ALLOW" "No user_decisions in state"
  emit_allow
  exit 0
fi

# ─── Read overlap threshold from config ──────────────────────────────
# Reads from feature_flags.hooks_immutable_guard.keyword_overlap_threshold
OVERLAP_THRESHOLD_PCT=$(yq '.feature_flags.hooks_immutable_guard.keyword_overlap_threshold // 0.6' "$CONFIG_FILE" 2>/dev/null || echo "0.6")
# Convert to integer percentage for bash arithmetic (0.6 → 60)
OVERLAP_THRESHOLD_INT=$(echo "$OVERLAP_THRESHOLD_PCT" | awk '{printf "%d", $1 * 100}')
OVERLAP_THRESHOLD_INT=${OVERLAP_THRESHOLD_INT:-60}

# ─── Normalized keyword matching ─────────────────────────────────────
STOPWORDS="the a an is are was were should we do does will would can could use using for to in on of and or"

normalize() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:punct:]' | tr ' ' '\n' | \
    grep -vwF "$(echo "$STOPWORDS" | tr ' ' '\n')" 2>/dev/null || true | \
    sort -u | tr '\n' ' '
}

question_keywords=$(normalize "$question")

# ─── FIX (v1.1): Use process substitution instead of pipe ───────────
# Piped while-read loops run in a subshell. `exit 2` inside would only
# exit the subshell, not the parent script. Process substitution `< <(...)`
# keeps the loop in the parent process so deny_and_exit works correctly.
matched=false
matched_key=""
matched_value=""
matched_overlap=""
matched_total=""

while IFS=$'\t' read -r decision_key decision_value; do
  decision_keywords=$(normalize "$decision_key")

  # Count overlapping keywords
  overlap=0
  total=0
  for kw in $decision_keywords; do
    total=$((total + 1))
    if echo "$question_keywords" | grep -qw "$kw" 2>/dev/null; then
      overlap=$((overlap + 1))
    fi
  done

  if [ "$total" -gt 0 ]; then
    # Check if overlap ratio >= threshold (integer arithmetic: overlap*100/total >= threshold_pct)
    overlap_pct=$((overlap * 100 / total))
    if [ "$overlap_pct" -ge "$OVERLAP_THRESHOLD_INT" ] && [ "$overlap" -gt 0 ]; then
      matched=true
      matched_key="$decision_key"
      matched_value="$decision_value"
      matched_overlap="$overlap"
      matched_total="$total"
      break
    fi
  fi
done < <(echo "$decisions_json" | jq -r 'to_entries[] | "\(.key)\t\(.value)"')

if [ "$matched" = true ]; then
  deny_and_exit "DENIED: This question overlaps with an immutable decision already made. Previous decision: '${matched_key}' -> '${matched_value}'. Do not re-ask. Use the cached answer. (overlap ${matched_overlap}/${matched_total})"
fi

log_hook "$HOOK_NAME" "ALLOW" "No matching decisions found"
reset_hook_failure "$HOOK_NAME"
emit_allow
exit 0
```

### 7.3 H02: enforce-planning-lock.sh

```bash
#!/bin/bash
set -euo pipefail
HOOK_NAME="H02_lock_enforcement"
source "$(dirname "$(dirname "$0")")/lib/common.sh"

check_circuit_breaker "$HOOK_NAME"

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# ─── Only guard files under FEATURE_DIR ──────────────────────────────
if [ -z "$FEATURE_DIR" ] || [ -z "$file_path" ]; then
  emit_allow
  exit 0
fi

# Normalize paths for comparison (portable — see lib/common.sh)
real_feature=$(portable_realpath "$FEATURE_DIR")
real_file=$(portable_realpath "$(dirname "$file_path")")

if [[ "$real_file" != "$real_feature"* ]]; then
  log_hook "$HOOK_NAME" "ALLOW" "File outside FEATURE_DIR: ${file_path}"
  emit_allow
  exit 0
fi

# ─── Check lock ──────────────────────────────────────────────────────
if [ ! -f "$LOCK_FILE" ]; then
  deny_and_exit "DENIED: No planning lock acquired. Call Phase 1 setup first to acquire lock before writing to planning workspace."
fi

# Verify lock belongs to this session
lock_session=$(jq -r '.session_id // empty' "$LOCK_FILE" 2>/dev/null || echo "")
if [ -n "$lock_session" ] && [ "$lock_session" != "$session_id" ]; then
  deny_and_exit "DENIED: Planning lock owned by another session (${lock_session}). Wait for lock release or delete stale lock."
fi

log_hook "$HOOK_NAME" "ALLOW" "Lock valid for session ${session_id}"
reset_hook_failure "$HOOK_NAME"
emit_allow
exit 0
```

### 7.4 H03: research-budget-tracker.sh

```bash
#!/bin/bash
set -euo pipefail
HOOK_NAME="H03_research_budget"
source "$(dirname "$(dirname "$0")")/lib/common.sh"

check_circuit_breaker "$HOOK_NAME"

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
# FIX (v1.1): Use portable_md5 instead of md5sum (macOS compatibility)
tool_input_hash=$(echo "$input" | jq -r '.tool_input' | portable_md5)

# ─── Read limits from config ─────────────────────────────────────────
session_limit=$(safe_int "$(yq '.research_mcp.budget.total_calls_per_session' "$CONFIG_FILE" 2>/dev/null || echo 25)")
phase_limit=$(safe_int "$(yq '.research_mcp.budget.total_calls_per_phase' "$CONFIG_FILE" 2>/dev/null || echo 10)")
warn_pct=$(safe_int "$(yq '.research_mcp.budget.warn_at_percentage' "$CONFIG_FILE" 2>/dev/null || echo 80)")

# ─── Initialize or read budget file ──────────────────────────────────
if [ ! -f "$BUDGET_FILE" ]; then
  echo '{"session_total":0,"phase_total":0,"call_hashes":[],"per_server":{"context7":0,"ref":0,"tavily":0}}' > "$BUDGET_FILE"
fi

# ─── Idempotency: check if this exact call was already counted ────────
call_key="${tool_name}_${tool_input_hash}"
already_counted=$(jq -r ".call_hashes | index(\"${call_key}\") // empty" "$BUDGET_FILE")
if [ -n "$already_counted" ]; then
  log_hook "$HOOK_NAME" "ALLOW" "Duplicate call (retry), not incrementing"
  emit_allow
  exit 0
fi

# ─── Read current counts (with integer safety) ──────────────────────
session_total=$(safe_int "$(jq -r '.session_total // 0' "$BUDGET_FILE")")
phase_total=$(safe_int "$(jq -r '.phase_total // 0' "$BUDGET_FILE")")

# ─── Check limits ────────────────────────────────────────────────────
if [ "$session_total" -ge "$session_limit" ]; then
  deny_and_exit "DENIED: Research MCP session budget exhausted (${session_total}/${session_limit} calls). No more research calls allowed this session."
fi

if [ "$phase_total" -ge "$phase_limit" ]; then
  deny_and_exit "DENIED: Research MCP phase budget exhausted (${phase_total}/${phase_limit} calls). Proceed to next phase or consolidate existing research."
fi

# ─── Increment counters ──────────────────────────────────────────────
server="unknown"
[[ "$tool_name" == mcp__context7__* ]] && server="context7"
[[ "$tool_name" == mcp__Ref__* ]] && server="ref"
[[ "$tool_name" == mcp__tavily__* ]] && server="tavily"

# Use flock for atomic read-modify-write (prevents race conditions)
(
  flock -n 200 || { log_hook "$HOOK_NAME" "ALLOW" "Lock contention on budget file"; emit_allow; exit 0; }
  jq --arg key "$call_key" --arg srv "$server" \
    '.session_total += 1 | .phase_total += 1 | .per_server[$srv] += 1 | .call_hashes += [$key]' \
    "$BUDGET_FILE" > "${BUDGET_FILE}.tmp" && mv "${BUDGET_FILE}.tmp" "$BUDGET_FILE"
) 200>"${BUDGET_FILE}.lock"

new_session=$((session_total + 1))
new_phase=$((phase_total + 1))

# ─── Warn at threshold ───────────────────────────────────────────────
session_warn=$((session_limit * warn_pct / 100))
phase_warn=$((phase_limit * warn_pct / 100))

warning=""
if [ "$new_session" -ge "$session_warn" ]; then
  warning="WARNING: Session budget at ${new_session}/${session_limit} (${warn_pct}% threshold). "
fi
if [ "$new_phase" -ge "$phase_warn" ]; then
  warning="${warning}WARNING: Phase budget at ${new_phase}/${phase_limit}. "
fi

if [ -n "$warning" ]; then
  log_hook "$HOOK_NAME" "ALLOW+WARN" "${warning}"
  emit_allow_with_message "${warning}Consider consolidating research before making more calls."
else
  log_hook "$HOOK_NAME" "ALLOW" "Budget OK: session=${new_session}/${session_limit}, phase=${new_phase}/${phase_limit}"
  emit_allow
fi

reset_hook_failure "$HOOK_NAME"
exit 0
```

### 7.5 H04: protect-spec-immutability.sh

```bash
#!/bin/bash
set -euo pipefail
HOOK_NAME="H04_spec_protection"
source "$(dirname "$(dirname "$0")")/lib/common.sh"

check_circuit_breaker "$HOOK_NAME"

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# ─── Only guard spec.md ──────────────────────────────────────────────
if [[ "$file_path" != */spec.md ]]; then
  emit_allow
  exit 0
fi

# ─── Allow if no state file (planning not started) ───────────────────
if [ -z "$STATE_FILE" ] || [ ! -f "$STATE_FILE" ]; then
  log_hook "$HOOK_NAME" "ALLOW" "No state file, spec still editable"
  emit_allow
  exit 0
fi

# ─── Allow during SETUP phase (spec still being finalized) ───────────
current_phase=$(parse_yaml_field "$STATE_FILE" "phase")
if [ "$current_phase" = "SETUP" ] || [ -z "$current_phase" ]; then
  log_hook "$HOOK_NAME" "ALLOW" "Phase is SETUP, spec still editable"
  emit_allow
  exit 0
fi

# ─── Deny: planning active, spec is immutable ────────────────────────
deny_and_exit "DENIED: spec.md is immutable after planning has started (current phase: ${current_phase}). Modifying it would invalidate all downstream artifacts. If requirements changed, abort planning and restart."
```

### 7.6 H05: checkpoint-logger.sh

```bash
#!/bin/bash
set -euo pipefail
HOOK_NAME="H05_checkpoint_logger"
source "$(dirname "$(dirname "$0")")/lib/common.sh"

# ─── Only process writes to .planning-state.local.md ─────────────────
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_result.file_path // empty')

if [[ "$file_path" != */.planning-state.local.md ]]; then
  exit 0  # Not a state file write, nothing to log
fi

# ─── Extract phase from written content ──────────────────────────────
if [ -f "$file_path" ]; then
  new_phase=$(parse_yaml_field "$file_path" "phase")
  mode=$(parse_yaml_field "$file_path" "mode")

  # Read previous phase from audit log
  # FIX (v1.1): Replace grep -oP (Perl regex, unavailable on macOS BSD grep) with sed
  prev_phase="UNKNOWN"
  if [ -f "$AUDIT_LOG" ]; then
    prev_phase=$(tail -1 "$AUDIT_LOG" | sed -n 's/.*CHECKPOINT: \([A-Z_]*\) .*/\1/p')
    [ -z "$prev_phase" ] && prev_phase="UNKNOWN"
  fi

  # Log transition
  if [ -n "$new_phase" ] && [ "$new_phase" != "$prev_phase" ]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] CHECKPOINT: ${prev_phase} → ${new_phase} | session=${session_id} | mode=${mode}" >> "$AUDIT_LOG" 2>/dev/null || true
    log_hook "$HOOK_NAME" "LOG" "Phase transition: ${prev_phase} → ${new_phase}"

    # Reset phase budget counter (H03 integration) — with flock for safety
    if [ -f "$BUDGET_FILE" ]; then
      (
        flock -n 200 || true
        jq '.phase_total = 0' "$BUDGET_FILE" > "${BUDGET_FILE}.tmp" && mv "${BUDGET_FILE}.tmp" "$BUDGET_FILE"
      ) 200>"${BUDGET_FILE}.lock"
    fi

    echo "CHECKPOINT: ${prev_phase} → ${new_phase} | mode=${mode}"
  fi
fi

exit 0
```

### 7.7 H06: inject-planning-context.sh

```bash
#!/bin/bash
set -euo pipefail
HOOK_NAME="H06_context_injection"
source "$(dirname "$(dirname "$0")")/lib/common.sh"

# ─── Skip if no state file ──────────────────────────────────────────
if [ -z "$STATE_FILE" ] || [ ! -f "$STATE_FILE" ]; then
  exit 0  # No planning context to inject
fi

# ─── Extract state summary ──────────────────────────────────────────
phase=$(parse_yaml_field "$STATE_FILE" "phase")
mode=$(parse_yaml_field "$STATE_FILE" "mode")
decisions_count=$(yq '.user_decisions | length' "$STATE_FILE" 2>/dev/null || echo 0)

# Extract decision summaries (first 50 chars each)
decisions=""
if command -v yq &>/dev/null; then
  decisions=$(yq -r '.user_decisions | to_entries[] | "  - " + (.key | .[0:50])' "$STATE_FILE" 2>/dev/null || echo "")
fi

# Check artifacts
artifacts=""
for artifact in design.md plan.md tasks.md test-plan.md research.md; do
  if [ -f "${FEATURE_DIR}/${artifact}" ]; then
    artifacts="${artifacts}  - ${artifact}\n"
  fi
done

# Check gate results
gates=""
if command -v yq &>/dev/null; then
  gates=$(yq -r '.gate_results[]? | "  - gate_" + (.phase | tostring) + ": " + .verdict + " (" + (.score | tostring) + ")"' "$STATE_FILE" 2>/dev/null || echo "")
fi

# Check lock
lock_active="false"
if [ -f "$LOCK_FILE" ]; then
  lock_active="true"
fi

# ─── Build systemMessage safely with jq ─────────────────────────────
# FIX (v1.1): Use jq for JSON construction instead of heredoc string interpolation.
# Shell variables containing newlines, quotes, or backslashes would produce
# malformed JSON with heredoc. jq --arg handles all escaping correctly.
planning_state="<planning-state>
phase: ${phase}
mode: ${mode}
decisions_count: ${decisions_count}
immutable_decisions:
${decisions}
artifacts_generated:
${artifacts}
gate_results:
${gates}
lock_active: ${lock_active}
</planning-state>"

jq -n --arg state "$planning_state" '{"systemMessage": $state}'

log_hook "$HOOK_NAME" "INJECT" "phase=${phase}, mode=${mode}, decisions=${decisions_count}"
exit 0
```

### 7.8 H07: validate-tech-lead-output.sh

```bash
#!/bin/bash
set -euo pipefail
HOOK_NAME="H07_tech_lead_validator"
source "$(dirname "$(dirname "$0")")/lib/common.sh"

check_circuit_breaker "$HOOK_NAME"

# ─── Locate tasks.md ─────────────────────────────────────────────
tasks_file="${FEATURE_DIR:+${FEATURE_DIR}/tasks.md}"

if [ -z "$tasks_file" ] || [ ! -f "$tasks_file" ]; then
  deny_stop_and_exit "tasks.md not found" "Tech-lead agent did not produce tasks.md in ${FEATURE_DIR:-UNKNOWN}. Re-run task generation."
fi

if [ ! -s "$tasks_file" ]; then
  deny_stop_and_exit "tasks.md is empty" "Tech-lead agent produced an empty tasks.md. Re-run task generation with more specific instructions."
fi

# ─── 1. Checklist Format ──────────────────────────────────────────
# Count lines matching task checklist pattern: - [ ] [T001] ...
task_count=$(grep -cE '^\- \[ \] \[T[0-9]{3}\]' "$tasks_file" 2>/dev/null || echo 0)
task_count=$(safe_int "$task_count")

if [ "$task_count" -lt 5 ]; then
  deny_stop_and_exit "Too few tasks (${task_count})" "Tech-lead output has only ${task_count} tasks with proper format (- [ ] [T###]). Minimum required: 5. Re-run with more detailed breakdown."
fi

# ─── 2. TDD References ───────────────────────────────────────────
# Count tasks that reference test IDs (UT-/INT-/E2E-/UAT-)
tasks_with_refs=$(grep -cE '\b(UT|INT|E2E|UAT)-[0-9]+' "$tasks_file" 2>/dev/null || echo 0)
tasks_with_refs=$(safe_int "$tasks_with_refs")

if [ "$task_count" -gt 0 ]; then
  tdd_pct=$((tasks_with_refs * 100 / task_count))
else
  tdd_pct=0
fi

# Read minimum TDD coverage from config
tdd_min=$(safe_int "$(yq '.feature_flags.hooks_agent_validation.tdd_min_coverage // 80' "$CONFIG_FILE" 2>/dev/null || echo 80)")

if [ "$tdd_pct" -lt "$tdd_min" ]; then
  deny_stop_and_exit "Insufficient TDD integration: ${tdd_pct}% (need >=${tdd_min}%)" "Tech-lead output has ${tasks_with_refs}/${task_count} tasks with test references (${tdd_pct}%). Required: >=${tdd_min}%. Add UT-/INT-/E2E-/UAT- references to task Definition of Done sections."
fi

# ─── 3. Phase Markers ────────────────────────────────────────────
phase_count=$(grep -cE '^##\s+Phase' "$tasks_file" 2>/dev/null || echo 0)
phase_count=$(safe_int "$phase_count")

if [ "$phase_count" -lt 2 ]; then
  deny_stop_and_exit "Missing phase structure" "tasks.md has only ${phase_count} '## Phase' headers. Expected at least 2 implementation phases. Re-structure tasks into phased delivery."
fi

# ─── 4. Self-Critique (optional, config-driven) ──────────────────
s1_enabled=$(yq '.feature_flags.s1_self_critique.enabled // false' "$CONFIG_FILE" 2>/dev/null || echo false)
if [ "$s1_enabled" = "true" ]; then
  has_critique=$(grep -ciE 'self.critique|self_critique' "$tasks_file" 2>/dev/null || echo 0)
  if [ "$has_critique" -eq 0 ]; then
    deny_stop_and_exit "Missing self-critique section" "s1_self_critique is enabled but tech-lead output has no self-critique section. Add self-assessment of task quality."
  fi
fi

# ─── All checks passed ───────────────────────────────────────────
log_hook "$HOOK_NAME" "APPROVE" "tasks=${task_count}, tdd=${tdd_pct}%, phases=${phase_count}"
reset_hook_failure "$HOOK_NAME"
emit_stop_approve
exit 0
```

### 7.9 H09: validate-qa-strategist-output.sh

```bash
#!/bin/bash
set -euo pipefail
HOOK_NAME="H09_qa_strategist_validator"
source "$(dirname "$(dirname "$0")")/lib/common.sh"

check_circuit_breaker "$HOOK_NAME"

# ─── Locate test artifacts ────────────────────────────────────────
test_base="${FEATURE_DIR:+${FEATURE_DIR}/test-cases}"
test_plan="${FEATURE_DIR:+${FEATURE_DIR}/test-plan.md}"

if [ -z "$FEATURE_DIR" ]; then
  log_hook "$HOOK_NAME" "APPROVE" "No FEATURE_DIR, cannot validate"
  emit_stop_approve
  exit 0
fi

# ─── 1. Test IDs Present ─────────────────────────────────────────
unit_ids=0
int_ids=0
e2e_ids=0
uat_ids=0

if [ -d "${test_base}/unit" ]; then
  unit_ids=$(grep -rcE '^##?\s*UT-[0-9]+' "${test_base}/unit/" 2>/dev/null | grep -c ':' 2>/dev/null || echo 0)
fi
if [ -d "${test_base}/integration" ]; then
  int_ids=$(grep -rcE '^##?\s*INT-[0-9]+' "${test_base}/integration/" 2>/dev/null | grep -c ':' 2>/dev/null || echo 0)
fi
if [ -d "${test_base}/e2e" ]; then
  e2e_ids=$(grep -rcE '^##?\s*E2E-[0-9]+' "${test_base}/e2e/" 2>/dev/null | grep -c ':' 2>/dev/null || echo 0)
fi
if [ -d "${test_base}/uat" ]; then
  uat_ids=$(grep -rcE '^##?\s*UAT-[0-9]+' "${test_base}/uat/" 2>/dev/null | grep -c ':' 2>/dev/null || echo 0)
fi

unit_ids=$(safe_int "$unit_ids")
int_ids=$(safe_int "$int_ids")
e2e_ids=$(safe_int "$e2e_ids")
uat_ids=$(safe_int "$uat_ids")

if [ "$unit_ids" -eq 0 ]; then
  deny_stop_and_exit "No unit test IDs" "QA strategist did not produce any unit test specifications (UT-xxx) in test-cases/unit/. Re-run QA agent."
fi

if [ "$uat_ids" -eq 0 ]; then
  deny_stop_and_exit "No UAT script IDs" "QA strategist did not produce any UAT scripts (UAT-xxx) in test-cases/uat/. Re-run QA agent."
fi

# ─── 2. UAT Format (Given-When-Then) ─────────────────────────────
if [ -d "${test_base}/uat" ]; then
  gwt_count=$(grep -rcE 'Given:|When:|Then:' "${test_base}/uat/" 2>/dev/null | grep -c ':' 2>/dev/null || echo 0)
  gwt_count=$(safe_int "$gwt_count")
  expected_gwt=$((uat_ids * 3))

  if [ "$gwt_count" -lt "$expected_gwt" ]; then
    deny_stop_and_exit "UAT scripts missing Given-When-Then" "Found ${gwt_count} GWT markers for ${uat_ids} UAT scripts (expected at least ${expected_gwt}). Ensure each UAT script has Given/When/Then sections."
  fi
fi

# ─── 3. Coverage Matrix ──────────────────────────────────────────
if [ -f "$test_plan" ]; then
  has_matrix=$(grep -ciE 'coverage.matrix|coverage matrix' "$test_plan" 2>/dev/null || echo 0)
  if [ "$has_matrix" -eq 0 ]; then
    deny_stop_and_exit "Missing coverage matrix" "test-plan.md does not contain a coverage matrix. Add a section mapping acceptance criteria to test cases."
  fi
else
  deny_stop_and_exit "test-plan.md not found" "QA strategist did not produce test-plan.md in ${FEATURE_DIR}. Re-run QA agent."
fi

# ─── All checks passed ───────────────────────────────────────────
log_hook "$HOOK_NAME" "APPROVE" "UT=${unit_ids}, INT=${int_ids}, E2E=${e2e_ids}, UAT=${uat_ids}"
reset_hook_failure "$HOOK_NAME"
emit_stop_approve
exit 0
```

### 7.10 H10: validate-agent-generic.sh

```bash
#!/bin/bash
set -euo pipefail
HOOK_NAME="H10_agent_generic_validator"
source "$(dirname "$(dirname "$0")")/lib/common.sh"

check_circuit_breaker "$HOOK_NAME"

# ─── 1. Agent Name Filter (deterministic, not prompt-based) ──────
# FIX (v1.1): Replaced prompt-based "ALWAYS approve" instruction
# with hardcoded array check. Prompt hooks can't guarantee approval;
# command hooks with an explicit array are deterministic.
agent_name=$(echo "$input" | jq -r '.tool_input.agent_name // .tool_name // empty')

DEDICATED_AGENTS=(
  "product-planning:tech-lead"
  "product-planning:software-architect"
  "product-planning:qa-strategist"
)

for dedicated in "${DEDICATED_AGENTS[@]}"; do
  if [ "$agent_name" = "$dedicated" ]; then
    log_hook "$HOOK_NAME" "APPROVE" "Dedicated hook handles ${agent_name}"
    emit_stop_approve
    exit 0
  fi
done

# ─── 2. Output Length ─────────────────────────────────────────────
# Read agent output from hook input (reason field for SubagentStop)
output_text=$(echo "$input" | jq -r '.reason // ""')

word_count=$(echo "$output_text" | wc -w | tr -d ' ')
word_count=$(safe_int "$word_count")

if [ "$word_count" -lt 100 ]; then
  deny_stop_and_exit "Insufficient output (${word_count} words)" "Agent ${agent_name:-unknown} produced only ${word_count} words. Minimum required: 100 words. Re-run with more specific instructions."
fi

# ─── 3. Structure Check ──────────────────────────────────────────
has_headers=$(echo "$output_text" | grep -cE '^#{2,3}\s' 2>/dev/null || echo 0)
has_lists=$(echo "$output_text" | grep -cE '^\s*[-*]\s|^[0-9]+\.\s' 2>/dev/null || echo 0)
has_tables=$(echo "$output_text" | grep -cE '\|.*\|' 2>/dev/null || echo 0)

has_headers=$(safe_int "$has_headers")
has_lists=$(safe_int "$has_lists")
has_tables=$(safe_int "$has_tables")

structure_score=$((has_headers + has_lists + has_tables))

if [ "$structure_score" -eq 0 ]; then
  deny_stop_and_exit "No structured sections found" "Agent ${agent_name:-unknown} output lacks structure (no headers, lists, or tables). Agent output should use markdown formatting for clarity."
fi

# ─── All checks passed ───────────────────────────────────────────
log_hook "$HOOK_NAME" "APPROVE" "agent=${agent_name:-unknown}, words=${word_count}, structure=${structure_score}"
reset_hook_failure "$HOOK_NAME"
emit_stop_approve
exit 0
```

### 7.11 H11a: check-required-artifacts.sh

```bash
#!/bin/bash
set -euo pipefail
HOOK_NAME="H11a_required_artifacts"
source "$(dirname "$(dirname "$0")")/lib/common.sh"

check_circuit_breaker "$HOOK_NAME"

# ─── Skip if no state file (planning hasn't started) ──────────────
if [ -z "$STATE_FILE" ] || [ ! -f "$STATE_FILE" ]; then
  log_hook "$HOOK_NAME" "APPROVE" "No state file, planning not started"
  emit_stop_approve
  exit 0
fi

if [ -z "$FEATURE_DIR" ]; then
  log_hook "$HOOK_NAME" "APPROVE" "No FEATURE_DIR detected"
  emit_stop_approve
  exit 0
fi

# ─── Read current phase ──────────────────────────────────────────
current_phase=$(parse_yaml_field "$STATE_FILE" "phase")

# If already at COMPLETION, artifacts should exist but allow regardless
if [ "$current_phase" = "COMPLETION" ]; then
  log_hook "$HOOK_NAME" "APPROVE" "Phase is COMPLETION"
  emit_stop_approve
  exit 0
fi

# ─── Check required artifacts ────────────────────────────────────
REQUIRED_ARTIFACTS=(
  "${FEATURE_DIR}/design.md"
  "${FEATURE_DIR}/plan.md"
  "${FEATURE_DIR}/tasks.md"
  "${FEATURE_DIR}/test-plan.md"
)

missing=()
for artifact in "${REQUIRED_ARTIFACTS[@]}"; do
  if [ ! -f "$artifact" ] || [ ! -s "$artifact" ]; then
    # Extract just the filename for display
    missing+=("$(basename "$artifact")")
  fi
done

if [ ${#missing[@]} -gt 0 ]; then
  missing_list=$(printf ", %s" "${missing[@]}")
  missing_list="${missing_list:2}"  # Remove leading ", "
  deny_stop_and_exit "Missing artifacts: ${missing_list}" "Planning incomplete (phase: ${current_phase}). Missing required artifacts: ${missing_list}. Continue workflow to generate these artifacts before stopping."
fi

# ─── All artifacts present ────────────────────────────────────────
log_hook "$HOOK_NAME" "APPROVE" "All required artifacts present, phase=${current_phase}"
reset_hook_failure "$HOOK_NAME"
emit_stop_approve
exit 0
```

### 7.12 H12: preserve-planning-context.sh

```bash
#!/bin/bash
set -euo pipefail
HOOK_NAME="H12_preserve_context"
source "$(dirname "$(dirname "$0")")/lib/common.sh"

# ─── Skip if no state file ──────────────────────────────────────
if [ -z "$STATE_FILE" ] || [ ! -f "$STATE_FILE" ]; then
  exit 0  # Nothing to preserve
fi

# ─── Build state summary (same format as H06) ───────────────────
# This ensures post-compaction context matches pre-compaction injection
phase=$(parse_yaml_field "$STATE_FILE" "phase")
mode=$(parse_yaml_field "$STATE_FILE" "mode")
decisions_count=$(yq '.user_decisions | length' "$STATE_FILE" 2>/dev/null || echo 0)

decisions=""
if command -v yq &>/dev/null; then
  decisions=$(yq -r '.user_decisions | to_entries[] | "  - " + (.key | .[0:50])' "$STATE_FILE" 2>/dev/null || echo "")
fi

artifacts=""
for artifact in design.md plan.md tasks.md test-plan.md research.md; do
  if [ -f "${FEATURE_DIR}/${artifact}" ]; then
    artifacts="${artifacts}  - ${artifact}\n"
  fi
done

gates=""
if command -v yq &>/dev/null; then
  gates=$(yq -r '.gate_results[]? | "  - gate_" + (.phase | tostring) + ": " + .verdict + " (" + (.score | tostring) + ")"' "$STATE_FILE" 2>/dev/null || echo "")
fi

lock_active="false"
if [ -f "$LOCK_FILE" ]; then
  lock_active="true"
fi

# ─── Emit systemMessage for post-compaction context ──────────────
planning_state="<planning-state>
phase: ${phase}
mode: ${mode}
decisions_count: ${decisions_count}
immutable_decisions:
${decisions}
artifacts_generated:
${artifacts}
gate_results:
${gates}
lock_active: ${lock_active}
</planning-state>"

jq -n --arg state "$planning_state" '{"systemMessage": $state}'

log_hook "$HOOK_NAME" "PRESERVE" "phase=${phase}, mode=${mode}, decisions=${decisions_count}"
exit 0
```

### 7.13 H13: setup-planning-env.sh

```bash
#!/bin/bash
set -euo pipefail
HOOK_NAME="H13_env_setup"
# NOTE: This hook runs at SessionStart. common.sh depends on some env vars
# that aren't set yet, so we source it but handle missing values gracefully.
source "$(dirname "$(dirname "$0")")/lib/common.sh"

# ─── 1. Detect git branch ────────────────────────────────────────
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# ─── 2. Extract feature directory ────────────────────────────────
feature_dir=""
if [[ "$branch" == feature/* ]]; then
  feature_dir="${cwd}/specs/${branch#feature/}"
fi

# ─── 3. Check prerequisites ──────────────────────────────────────
spec_exists="false"
constitution_exists="false"

if [ -n "$feature_dir" ] && [ -f "${feature_dir}/spec.md" ]; then
  spec_exists="true"
fi
if [ -f "${cwd}/specs/constitution.md" ]; then
  constitution_exists="true"
fi

# ─── 4. Check existing state ─────────────────────────────────────
state_exists="false"
current_phase=""
current_mode=""

if [ -n "$feature_dir" ] && [ -f "${feature_dir}/.planning-state.local.md" ]; then
  state_exists="true"
  current_phase=$(parse_yaml_field "${feature_dir}/.planning-state.local.md" "phase")
  current_mode=$(parse_yaml_field "${feature_dir}/.planning-state.local.md" "mode")
fi

# ─── 5. Write to CLAUDE_ENV_FILE ─────────────────────────────────
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export PLANNING_BRANCH=${branch}"
    echo "export PLANNING_FEATURE_DIR=${feature_dir}"
    echo "export PLANNING_SPEC_EXISTS=${spec_exists}"
    echo "export PLANNING_CONSTITUTION_EXISTS=${constitution_exists}"
    echo "export PLANNING_STATE_EXISTS=${state_exists}"
    echo "export PLANNING_CURRENT_PHASE=${current_phase}"
    echo "export PLANNING_CURRENT_MODE=${current_mode}"
  } >> "$CLAUDE_ENV_FILE"
fi

# ─── 6. Emit systemMessage ───────────────────────────────────────
summary="Planning environment detected: branch=${branch}, feature_dir=${feature_dir:-none}, state=${state_exists}, phase=${current_phase:-none}, spec=${spec_exists}, constitution=${constitution_exists}"

jq -n --arg msg "$summary" '{"systemMessage": $msg}'

log_hook "$HOOK_NAME" "SETUP" "$summary"
exit 0
```

---

## 8. Failure Mode Table

| Hook | Failure Scenario | Behavior | Rationale |
|------|-----------------|----------|-----------|
| H01 | State file missing | **Allow** | Planning not started, no decisions to protect |
| H01 | yq not installed | **Allow** + log warning | Fallback to grep-based parsing; non-blocking |
| H01 | State file corrupted YAML | **Allow** + log error | Cannot determine decisions; safer to allow than block all questions |
| H02 | FEATURE_DIR not detected | **Allow** | Cannot determine if file is in workspace |
| H02 | Lock file corrupted JSON | **Deny** | Safer to block writes than risk corruption |
| H03 | Config file missing | **Allow** + use hardcoded defaults (25/10/80) | Budget enforcement degrades to defaults |
| H03 | Budget file corrupted | **Allow** + reset budget file | Fresh counter, may over-count but won't block |
| H04 | State file missing | **Allow** | Spec editable before planning starts |
| H05 | Audit log directory missing | **Silent skip** | Logging failure is non-blocking |
| H05 | Cannot parse phase from state | **Silent skip** | Non-critical, just log |
| H06 | State file missing | **Silent exit** | No context to inject |
| H06 | yq not installed | **Partial inject** | Uses grep fallback, fewer fields |
| H07 | tasks.md not found | **Block** | Agent didn't produce required output |
| H07 | tasks.md empty | **Block** | Agent produced empty output |
| H07 | grep fails | **Allow** + log | Fail-open on tool failure |
| H08 | (prompt hook) LLM timeout | **Allow** | Fail-open; better to proceed than block permanently |
| H09 | test-cases/ directory missing | **Block** | Agent didn't create test directories |
| H09 | No test files found | **Block** | Agent didn't produce test specs |
| H10 | Agent name parsing fails | **Allow** | Falls through to default approve |
| H10 | Output text empty/missing | **Block** | Agent must produce substantive output |
| H11a | State file missing | **Allow** | Planning hasn't started |
| H11a | FEATURE_DIR not detected | **Allow** | Cannot check artifacts |
| H11b | (prompt hook) LLM timeout | **Allow** | User can manually verify |
| H12 | State file missing | **Silent exit** | Nothing to preserve |
| H13 | Not in git repo | **Silent continue** | Sets branch="unknown", FEATURE_DIR="" |
| H13 | yq not installed | **Partial setup** | Skips state file parsing |

**Prerequisite Failure Modes:**

| Prerequisite | Missing Behavior | Impact |
|-------------|------------------|--------|
| `jq` | All hooks emit allow + warning, exit 0 | Complete hook bypass; no enforcement |
| `yq` | H01: skip (cannot parse decisions), H06/H12: partial inject, H13: partial setup | Reduced enforcement on YAML-dependent hooks |
| `git` | H13: branch="unknown", FEATURE_DIR="" | Manual feature dir detection in Phase 1 |

**Fail-Safe Summary:**

| Default | Hooks | Rationale |
|---------|-------|-----------|
| **Fail-Open (Allow)** | H01, H02, H03, H04, H05, H06, H08, H10, H11a, H11b, H12, H13 | Planning should not be blocked by hook infrastructure failures |
| **Fail-Closed (Block)** | H07 (missing/empty tasks.md), H09 (missing test artifacts) | Agent not producing required output IS the failure - blocking is correct |

**Note:** H07 and H09 fail-closed specifically when their *target files are missing or empty* — this is an agent failure, not a hook infrastructure failure. If the hook script itself crashes (e.g., grep not found), the ERR trap in `common.sh` triggers fail-open behavior instead.

---

## 9. Hook Interaction Matrix

Hooks within the same event type run **in parallel**. This matrix documents concurrent execution scenarios.

### PreToolUse Concurrent Hooks

| Tool | H01 | H02 | H03 | H04 | Conflict? |
|------|-----|-----|-----|-----|-----------|
| `AskUserQuestion` | Runs | - | - | - | No conflict (single hook) |
| `Write` to spec.md | - | Runs | - | Runs | **Potential**: Both may deny for different reasons. Both denials are valid; Claude sees both systemMessages |
| `Write` to design.md | - | Runs | - | - | No conflict (single hook) |
| `Edit` to spec.md | - | Runs | - | Runs | Same as Write to spec.md |
| `mcp__context7__*` | - | - | Runs | - | No conflict (single hook) |

**Resolution for H02 + H04 co-denial:** Both hooks may deny a write to `spec.md`. This is correct behavior - both reasons are valid (no lock AND spec is immutable). Claude receives both `systemMessage` values. No special handling needed.

### SubagentStop Concurrent Hooks

| Agent | H07 | H08 | H09 | H10 | Conflict? |
|-------|-----|-----|-----|-----|-----------|
| `tech-lead` | Runs | - | - | Runs | **Resolved**: H10 auto-approves tech-lead (see Section 4, H10) |
| `software-architect` | - | Runs | - | Runs | **Resolved**: H10 auto-approves software-architect |
| `qa-strategist` | - | - | Runs | Runs | **Resolved**: H10 auto-approves qa-strategist |
| `code-explorer` | - | - | - | Runs | No conflict (single active hook) |
| `qa-security` | - | - | - | Runs | No conflict |
| `phase-gate-judge` | - | - | - | Runs | No conflict |

**Key Design Decision:** H10 (generic wildcard) explicitly delegates to dedicated hooks for tech-lead, software-architect, and qa-strategist. This eliminates the parallel conflict identified in the critique.

### Stop Concurrent Hooks

| Scenario | H11a | H11b | Result |
|----------|------|------|--------|
| All artifacts exist, phase=COMPLETION | Allow | Allow | **Allow** (unanimous) |
| Missing artifacts, phase=ARCHITECTURE | Block | Block | **Block** (unanimous, both reasons shown) |
| All artifacts exist, RED gate status | Allow | Block | **Block** (any block = block) |
| User says "stop" mid-workflow | Block | Allow (user override) | **Conflict** - depends on runtime behavior |

**H11a + H11b Conflict Resolution:** Claude Code's Stop hook semantics use `any block = block` (conservative). For the "user says stop" scenario, H11a blocks (missing artifacts) while H11b allows (user override). The net result is **block**. This is acceptable: the user will see both messages and can force-quit the session.

### Read-Write Coordination

| Hook | Reads | Writes | Risk |
|------|-------|--------|------|
| H01 | State file | - | None (read-only) |
| H02 | Lock file | - | None (read-only) |
| H03 | Budget file, Config | Budget file | **Low**: Only H03 writes to budget file. H05 also writes (phase reset) but on different event (PostToolUse vs PreToolUse) |
| H04 | State file | - | None (read-only) |
| H05 | State file | Audit log, Budget file | **None**: Only PostToolUse hook, no parallel |
| H06 | State file | - | None (read-only) |
| H12 | State file | - | None (read-only) |

**Conclusion:** No read-write conflicts exist because:
1. Budget file writes (H03 + H05) occur on different events (PreToolUse vs PostToolUse)
2. State file is read-only in all hooks (written by the skill, not hooks)
3. Audit log is append-only (H05 only writer)

---

## 10. Testing Strategy

### 10.1 Unit Tests for Command Hooks

Each command hook is testable by piping JSON input to the script.

**Test Template:**
```bash
#!/bin/bash
# test-hook.sh <hook_script> <test_input_file> <expected_exit_code> <expected_output_pattern>

HOOK_SCRIPT="$1"
TEST_INPUT="$2"
EXPECTED_EXIT="$3"
EXPECTED_PATTERN="$4"

output=$(cat "$TEST_INPUT" | bash "$HOOK_SCRIPT" 2>&1)
actual_exit=$?

if [ "$actual_exit" -ne "$EXPECTED_EXIT" ]; then
  echo "FAIL: Expected exit $EXPECTED_EXIT, got $actual_exit"
  echo "Output: $output"
  exit 1
fi

if [ -n "$EXPECTED_PATTERN" ] && ! echo "$output" | grep -q "$EXPECTED_PATTERN"; then
  echo "FAIL: Expected pattern '$EXPECTED_PATTERN' not found"
  echo "Output: $output"
  exit 1
fi

echo "PASS"
exit 0
```

### 10.2 Test Cases per Hook

#### H01: Guard Immutable Decisions

| Test | Input | Expected | Setup |
|------|-------|----------|-------|
| No state file | AskUserQuestion with question | Exit 0, allow | Remove state file |
| No decisions | AskUserQuestion with question | Exit 0, allow | State file with empty user_decisions |
| Matching question | "What caching to use?" | Exit 2, deny | State has "Use Redis for caching" |
| Non-matching question | "What color for the button?" | Exit 0, allow | State has "Use Redis for caching" |
| Exact repeat | "Should we use Redis for caching?" | Exit 2, deny | State has same question |
| Partial overlap below threshold | "Is Redis good?" | Exit 0, allow | State has "Use Redis for session caching in production" |

#### H02: Enforce Planning Lock

| Test | Input | Expected | Setup |
|------|-------|----------|-------|
| File outside FEATURE_DIR | Write to /tmp/test.md | Exit 0, allow | Any state |
| Lock exists, same session | Write to design.md | Exit 0, allow | Lock with matching session_id |
| Lock exists, different session | Write to design.md | Exit 2, deny | Lock with different session_id |
| No lock file | Write to design.md | Exit 2, deny | Remove lock file |
| No FEATURE_DIR detected | Write to anything | Exit 0, allow | No git branch info |

#### H03: Research Budget Tracker

| Test | Input | Expected | Setup |
|------|-------|----------|-------|
| First call | mcp__context7 | Exit 0, allow | No budget file |
| At 80% session | mcp__tavily (call 21/25) | Exit 0, allow + warn | Budget at 20 |
| At 100% session | mcp__ref (call 26/25) | Exit 2, deny | Budget at 25 |
| At phase limit | mcp__context7 (call 11/10) | Exit 2, deny | Phase budget at 10 |
| Retry (duplicate) | Same call as previous | Exit 0, allow (no increment) | Previous call hash exists |
| Phase reset | mcp__context7 after checkpoint | Exit 0, allow, phase=1 | Budget at 8, then H05 resets |

#### H04: Protect Spec Immutability

| Test | Input | Expected | Setup |
|------|-------|----------|-------|
| Write to spec.md, phase=SETUP | Write spec.md | Exit 0, allow | State phase=SETUP |
| Write to spec.md, phase=ARCHITECTURE | Write spec.md | Exit 2, deny | State phase=ARCHITECTURE |
| Write to other file | Write design.md | Exit 0, allow | Any state |
| No state file | Write spec.md | Exit 0, allow | No state |

#### H07: Validate Tech-Lead Output

| Test | Input | Expected | Setup |
|------|-------|----------|-------|
| Valid tasks.md | SubagentStop | Exit 0, allow | tasks.md with 20 tasks, 90% TDD |
| Missing tasks.md | SubagentStop | Exit 2, block | No tasks.md |
| Low TDD coverage | SubagentStop | Exit 2, block | tasks.md with 50% TDD refs |
| No phase headers | SubagentStop | Exit 2, block | tasks.md without "## Phase" |

#### H09: Validate QA Strategist Output

| Test | Input | Expected | Setup |
|------|-------|----------|-------|
| Valid test files | SubagentStop | Exit 0, allow | All test-cases dirs with IDs |
| Missing UAT IDs | SubagentStop | Exit 2, block | No UAT-xxx patterns |
| Missing Given-When-Then | SubagentStop | Exit 2, block | UAT files without GWT format |
| Missing coverage matrix | SubagentStop | Exit 2, block | test-plan.md without matrix |

#### H11a: Check Required Artifacts

| Test | Input | Expected | Setup |
|------|-------|----------|-------|
| All artifacts exist | Stop | Exit 0, allow | All 4 required files present |
| Missing tasks.md | Stop | Exit 2, block | 3 of 4 files |
| No state file | Stop | Exit 0, allow | No state |
| Empty design.md | Stop | Exit 2, block | 0-byte design.md |

### 10.3 Integration Tests for Prompt Hooks

Prompt hooks require end-to-end testing with Claude Code:

```bash
# Start Claude Code in debug mode
claude --debug

# Trigger SubagentStop for software-architect
# Observe H08 evaluation in debug log

# Trigger Stop with incomplete workflow
# Observe H11b evaluation in debug log
```

**Test Protocol:**
1. Start session with `claude --debug`
2. Run `/product-planning:plan` on a test feature
3. At each phase, verify hook execution in debug output
4. Check `.planning-audit.log` for checkpoint entries
5. Check `/tmp/planning-hooks-*.log` for hook decisions
6. Deliberately trigger denial scenarios (re-ask decided question, exceed budget)

---

## 11. Logging Strategy

### 11.1 Log Files

| File | Location | Purpose | Writer |
|------|----------|---------|--------|
| Hook decision log | `/tmp/planning-hooks-{session_id}.log` | All hook decisions | All hooks via `log_hook()` |
| Audit trail | `{FEATURE_DIR}/.planning-audit.log` | Phase transitions only | H05 checkpoint-logger |
| Budget tracker | `/tmp/planning-research-budget-{session_id}.json` | Research MCP call counts | H03, H05 |
| Circuit breaker | `/tmp/planning-hook-breaker-{session_id}.json` | Hook failure counts | All hooks via `record_hook_failure()` |

### 11.2 Log Format

**Hook Decision Log:**
```
[2026-02-04T14:23:15Z] H01_immutable_guard: ALLOW | No matching decisions found
[2026-02-04T14:23:16Z] H02_lock_enforcement: ALLOW | Lock valid for session abc123
[2026-02-04T14:23:17Z] H03_research_budget: ALLOW+WARN | WARNING: Session budget at 21/25
[2026-02-04T14:23:18Z] H05_checkpoint_logger: LOG | Phase transition: RESEARCH → CLARIFICATION
[2026-02-04T14:23:19Z] H01_immutable_guard: DENY | Matched decision: 'Use Redis for caching' (overlap 2/3)
```

### 11.3 Log Rotation

Session-scoped log files (`/tmp/planning-*-{session_id}.*`) are automatically cleaned up when the session ends (operating system temp file cleanup). The audit log (`{FEATURE_DIR}/.planning-audit.log`) persists across sessions and should be committed with planning artifacts.

### 11.4 Debug Mode

When running `claude --debug`, all hook stdout/stderr is visible. Additionally, each hook's `log_hook()` call provides granular decision trail in `/tmp/planning-hooks-*.log`.

---

## 12. Circuit Breaker Pattern

### Design

If a hook encounters 3 **infrastructure failures** (script crash, tool missing, parse error), the circuit breaker **opens** and the hook is bypassed for the remainder of the session.

**Critical distinction (v1.1):** Only *infrastructure errors* increment the breaker counter. Intentional denials (`exit 2` from business logic via `deny_and_exit`) are NOT failures — they are correct hook behavior. This prevents a hook that legitimately blocks 3+ requests from being permanently disabled.

```
CLOSED (normal) ──[3 infrastructure failures]──→ OPEN (bypassed)
     ↑                                                │
     └──────────[session restart]─────────────────────┘
```

**What counts as infrastructure failure:**
- Unexpected `set -e` exits (trapped by `_hook_err_trap` in common.sh)
- Missing prerequisite tools (jq, yq)
- Malformed input JSON that causes jq parse errors
- File system errors (permission denied, disk full)

**What does NOT count:**
- Intentional denials via `deny_and_exit` (business logic working correctly)
- Intentional blocks via `deny_stop_and_exit` (agent validation working correctly)
- Successful allow decisions

### Implementation

Integrated into the shared library (Section 7.1 `hooks/lib/common.sh`):
- `_hook_err_trap()` - ERR trap that records failure + emits fail-open allow
- `deny_and_exit()` - disables ERR trap before `exit 2`, bypassing breaker
- `check_circuit_breaker()` - called at hook start; if open, immediately allows
- `record_hook_failure()` - called only by ERR trap (infrastructure errors)
- `reset_hook_failure()` - called on successful execution (resets counter to 0)

### Circuit Breaker State

Stored in `/tmp/planning-hook-breaker-{session_id}.json`:
```json
{
  "H01_immutable_guard": 0,
  "H02_lock_enforcement": 0,
  "H03_research_budget": 2,
  "H07_tech_lead_validator": 3
}
```

When counter reaches 3, the hook auto-approves with a warning systemMessage:
```json
{
  "hookSpecificOutput": {"permissionDecision": "allow"},
  "systemMessage": "Hook H07_tech_lead_validator circuit breaker OPEN (3+ failures). Skipping validation."
}
```

### Recovery

Circuit breakers reset on session restart (new session_id = new breaker file). No mid-session reset is supported to prevent flapping.

---

## 13. Development Mode

### Disabling Individual Hooks

To disable a specific hook during development, change its matcher to a non-matching pattern:

```json
{
  "matcher": "DISABLED_AskUserQuestion",
  "hooks": [
    {
      "type": "command",
      "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/guard-immutable-decisions.sh",
      "timeout": 5
    }
  ]
}
```

Prefix the matcher with `DISABLED_` to clearly mark it as intentionally disabled.

### Disabling All Hooks

Create a flag file that all hooks check:

```bash
# In common preamble, after circuit breaker check:
if [ -f "${PLUGIN_ROOT}/hooks/.dev-mode" ]; then
  log_hook "$HOOK_NAME" "DEV_SKIP" "Development mode active"
  echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
  exit 0
fi
```

**Enable dev mode:**
```bash
touch $CLAUDE_PLUGIN_ROOT/hooks/.dev-mode
# Restart Claude Code session
```

**Disable dev mode:**
```bash
rm $CLAUDE_PLUGIN_ROOT/hooks/.dev-mode
# Restart Claude Code session
```

### Verbose Logging

Set environment variable for detailed logging:

```bash
export PLANNING_HOOKS_VERBOSE=true
```

When set, hooks log full input JSON and output JSON to the hook log file (caution: increases log size).

---

## 14. Priority & Implementation Plan

### Revised Priority (post-critique)

| Priority | Hook | Event | Type | Impact | Rationale |
|----------|------|-------|------|--------|-----------|
| **P0** | H06 | UserPromptSubmit | Command | HIGH | Context loss is unrecoverable in 9-phase workflow |
| **P0** | H12 | PreCompact | Command | HIGH | Preserves state during compaction (same mechanism as H06) |
| **P0** | H11a | Stop | Command | HIGH | Prevents premature stop (deterministic artifact check) |
| **P0** | H11b | Stop | Prompt | HIGH | Prevents premature stop (logical completeness) |
| **P1** | H01 | PreToolUse | Command | HIGH | Eliminates state corruption from re-asked decisions |
| **P1** | H07 | SubagentStop | Command | HIGH | Catches tech-lead quality issues early |
| **P1** | H09 | SubagentStop | Command | HIGH | Catches QA output format issues early |
| **P2** | H02 | PreToolUse | Command | MED-HIGH | Lock enforcement for concurrent safety |
| **P2** | H03 | PreToolUse | Command | MED | Budget enforcement prevents cost overrun |
| **P2** | H04 | PreToolUse | Command | MED | Spec immutability prevents cascade invalidation |
| **P2** | H08 | SubagentStop | Prompt | MED | Architecture blueprint completeness |
| **P3** | H10 | SubagentStop | Command | MED | Generic agent output validation |
| **P3** | H05 | PostToolUse | Command | MED | Checkpoint audit trail |
| **P3** | H13 | SessionStart | Command | MED | Environment detection convenience |

### Implementation Phases

**Phase 1: Foundation (P0 hooks + infrastructure)**
- Create `hooks/` directory structure
- Implement common preamble (Section 7.1)
- Implement H06 (context injection)
- Implement H12 (preserve context) - shares logic with H06
- Implement H11a + H11b (stop guards)
- Create `hooks.json` with P0 hooks only
- Test via `claude --debug`

**Phase 2: State Protection (P1 hooks)**
- Implement H01 (immutable decisions)
- Implement H07 (tech-lead validation)
- Implement H09 (QA strategist validation)
- Add to `hooks.json`
- Run integration tests

**Phase 3: Safety Net (P2 hooks)**
- Implement H02 (lock enforcement)
- Implement H03 (budget tracker)
- Implement H04 (spec protection)
- Implement H08 (architect validation)
- Add to `hooks.json`

**Phase 4: Observability (P3 hooks)**
- Implement H10 (generic agent validation)
- Implement H05 (checkpoint logger)
- Implement H13 (environment setup)
- Add to `hooks.json`
- Complete test suite

---

## 15. Feature Flags (Config Additions)

These entries would be added to `config/planning-config.yaml` under `feature_flags:` when implementing hooks.

```yaml
  # Hook Enforcement Layer
  hooks_enforcement:
    enabled: true
    description: "Hook-based enforcement layer for workflow invariants"
    rollback: "Set false or delete hooks/hooks.json to disable all hooks"
    dev_mode_file: "hooks/.dev-mode"
    circuit_breaker_threshold: 3
    log_location: "/tmp/planning-hooks-{session_id}.log"

  hooks_immutable_guard:
    enabled: true
    description: "H01: Prevent re-asking immutable decisions via keyword matching"
    rollback: "Disable matcher in hooks.json"
    keyword_overlap_threshold: 0.6
    requires: [hooks_enforcement]

  hooks_lock_enforcement:
    enabled: true
    description: "H02: Enforce planning lock on workspace writes"
    rollback: "Disable matcher in hooks.json"
    requires: [hooks_enforcement]

  hooks_budget_tracker:
    enabled: true
    description: "H03: Enforce research MCP budget limits from config"
    rollback: "Disable matcher in hooks.json"
    requires: [hooks_enforcement]
    reads_from: "research_mcp.budget"

  hooks_spec_protection:
    enabled: true
    description: "H04: Prevent spec.md edits after SETUP phase"
    rollback: "Disable matcher in hooks.json"
    requires: [hooks_enforcement]

  hooks_agent_validation:
    enabled: true
    description: "H07/H08/H09/H10: Validate subagent output completeness"
    rollback: "Disable SubagentStop matchers in hooks.json"
    requires: [hooks_enforcement]
    tdd_min_coverage: 80

  hooks_stop_guard:
    enabled: true
    description: "H11a/H11b: Prevent premature workflow stopping"
    rollback: "Disable Stop matchers in hooks.json"
    requires: [hooks_enforcement]

  hooks_context_preservation:
    enabled: true
    description: "H06/H12: Inject and preserve planning context"
    rollback: "Disable UserPromptSubmit and PreCompact matchers in hooks.json"
    requires: [hooks_enforcement]
```

---

## 16. Acceptance Criteria

### AC1: State Integrity

- [ ] After resume, immutable decisions are never re-asked (H01)
- [ ] Concurrent sessions cannot corrupt each other's state (H02)
- [ ] spec.md cannot be edited after SETUP phase (H04)
- [ ] Verify with test: answer question, resume, check denial

### AC2: Budget Enforcement

- [ ] Research MCP calls denied when session budget exhausted (H03)
- [ ] Research MCP calls denied when phase budget exhausted (H03)
- [ ] Warning emitted at 80% threshold (H03)
- [ ] Phase budget resets on checkpoint transition (H05 → H03)
- [ ] Retry calls don't double-count (H03 idempotency)

### AC3: Agent Output Quality

- [ ] Tech-lead output blocked if <80% TDD coverage (H07)
- [ ] QA strategist output blocked if missing test IDs or GWT format (H09)
- [ ] Architect output evaluated for blueprint completeness (H08)
- [ ] Generic agents checked for non-trivial output (H10)
- [ ] No conflict between H10 and dedicated hooks (H10 auto-approves)

### AC4: Workflow Completeness

- [ ] Workflow cannot stop without all required artifacts (H11a)
- [ ] Workflow cannot stop with RED gate status (H11b)
- [ ] User can force-stop by saying "stop/quit/abort/exit" (H11b)
- [ ] Verify with test: try stopping at Phase 4, check block message

### AC5: Context Preservation

- [ ] After context compaction, planning state is preserved (H12)
- [ ] Every user prompt gets current state injected (H06)
- [ ] State injection includes: phase, mode, decisions, artifacts, gates
- [ ] Verify: run long session, trigger compaction, check state awareness

### AC6: Observability

- [ ] All hook decisions logged to `/tmp/planning-hooks-*.log` (all hooks)
- [ ] Phase transitions logged to `.planning-audit.log` (H05)
- [ ] Circuit breaker activates after 3 hook failures (all hooks)
- [ ] Dev mode disables all hooks when flag file present
- [ ] `claude --debug` shows hook execution details

### AC7: No Regressions

- [ ] Planning workflow completes successfully with all hooks enabled
- [ ] Rapid mode (no MCP) works without hook errors
- [ ] Standard mode works with budget tracking
- [ ] Complete mode works with all validation hooks
- [ ] Task regeneration (Phase 9 only) works with hooks

### AC8: Environment Setup & Prerequisites

- [ ] H13 correctly detects git branch and feature directory (SessionStart)
- [ ] H13 writes environment variables to `$CLAUDE_ENV_FILE` (SessionStart)
- [ ] All hooks fail-open gracefully when `jq` is not installed
- [ ] H01/H06/H12/H13 degrade gracefully when `yq` is not installed
- [ ] H13 handles non-git directories without error (branch="unknown")
- [ ] Environment variables set by H13 are available to subsequent hooks
- [ ] Verify with test: start session in non-git dir, check env var fallbacks

---

## Appendix A: Resolved Critique Items (v1.0)

This appendix maps each v1.0 critique finding to its resolution in this proposal.

### Must Do Items

| # | Critique Item | Resolution | Section |
|---|---------------|------------|---------|
| 1 | Add complete hooks.json with proper wrapper format | Full hooks.json with `{"hooks": {...}}` wrapper | Section 5 |
| 2 | Specify output contracts per hook (JSON format, exit codes) | Complete contract table with stdout/stderr and exit codes | Section 6 |
| 3 | Resolve H7+H8 parallel conflict | H10 auto-approves agents with dedicated hooks; H07/H08/H09 handle validation | Section 4 (H10), Section 9 |
| 4 | Specify H1 matching algorithm | Normalized keyword extraction with 0.6 overlap threshold | Section 4 (H01) |
| 5 | Clarify H3 budget scope | Hierarchical: session (25) AND phase (10), read from config | Section 4 (H03) |
| 6 | Document fail-safe defaults per hook | Complete table with Allow/Block + rationale | Section 8 |
| 7 | Add failure mode table for all command hooks | 25+ failure scenarios documented | Section 8 |

### Should Do Items

| # | Critique Item | Resolution | Section |
|---|---------------|------------|---------|
| 8 | Add hook for qa-strategist SubagentStop | H09: validate UAT format + test IDs | Section 4 (H09) |
| 9 | Add hook for spec.md edit protection | H04: protect-spec-immutability.sh | Section 4 (H04) |
| 10 | Split H5 into command + prompt | H11a (command: artifact check) + H11b (prompt: logical completeness) | Section 4 (H11a, H11b) |
| 11 | Add testing strategy | Unit test template + per-hook test cases + integration protocol | Section 10 |
| 12 | Promote H6 to P0 priority | Done: H06 is P0 | Section 14 |
| 13 | Add hook execution logging strategy | Structured logging with log_hook(), audit trail, session logs | Section 11 |

### Could Do Items

| # | Critique Item | Resolution | Section |
|---|---------------|------------|---------|
| 14 | Complete shell script pseudo-code | Full bash implementations for H01-H06 (v1.0); extended to all scripts in v1.1 | Section 7 |
| 15 | Circuit breaker pattern | 3-failure threshold, auto-bypass, session-scoped | Section 12 |
| 16 | Hook interaction matrix | Per-event analysis with conflict resolution | Section 9 |
| 17 | Development mode disablement | `.dev-mode` flag file + DISABLED_ prefix + verbose env var | Section 13 |

### Additional Improvements (from Judge 2)

| # | Critique Item | Resolution | Section |
|---|---------------|------------|---------|
| 18 | Missing PreToolUse for spec.md protection | Added as H04 | Section 4 (H04) |
| 19 | Missing SubagentStop for qa-strategist | Added as H09 | Section 4 (H09) |
| 20 | Priority reordering (H6→P0, H2→P2, H10→P3) | Reflected in revised priority table | Section 14 |
| 21 | Hook count increased from 11 to 14 | H04 (spec protection), H09 (QA validation), H5 split into H11a+H11b | Full proposal |

---

## Proposed Directory Structure

```
hooks/
├── hooks.json                          # Hook configuration (Section 5)
├── .dev-mode                           # Touch to disable all hooks (Section 13)
├── lib/
│   └── common.sh                       # Shared library (Section 7.1)
├── guard-immutable-decisions.sh        # H01: PreToolUse AskUserQuestion
├── enforce-planning-lock.sh            # H02: PreToolUse Write|Edit
├── research-budget-tracker.sh          # H03: PreToolUse mcp__*
├── protect-spec-immutability.sh        # H04: PreToolUse Write|Edit (spec.md)
├── checkpoint-logger.sh                # H05: PostToolUse Write
├── inject-planning-context.sh          # H06: UserPromptSubmit *
├── validate-tech-lead-output.sh        # H07: SubagentStop tech-lead
├── validate-qa-strategist-output.sh    # H09: SubagentStop qa-strategist
├── validate-agent-generic.sh           # H10: SubagentStop * (command)
├── check-required-artifacts.sh         # H11a: Stop *
├── preserve-planning-context.sh        # H12: PreCompact *
└── setup-planning-env.sh              # H13: SessionStart *
```

**Prompt-only hooks (no script file):** H08 (architect validation), H11b (workflow completeness) - defined inline in hooks.json.

---

## Appendix B: Resolved Critique Items (v1.1)

This appendix maps each v1.1 critique finding (from the second `/reflexion:critique` round) to its resolution. The critique was conducted by three judges: Requirements Validator (9.5/10), Solution Architect (7.5/10), Code Quality Reviewer (6.0/10). Consensus: 7.7/10, "Needs improvements before shipping."

### Must Do Items

| # | ID | Critique Item | Resolution | Section |
|---|-----|---------------|------------|---------|
| 1 | CRITICAL-01 | H01 subshell bug: pipe `while read` creates subshell, `exit 2` doesn't propagate | Replaced pipe with process substitution `< <(...)`, added `matched` flag variable + `break` | Section 7.2 |
| 2 | CRITICAL-02 | `md5sum` unavailable on macOS | Added `portable_md5()` function in common.sh (md5sum → md5 → cksum fallback) | Section 7.1 |
| 3 | CRITICAL-03 | `grep -oP` (Perl regex) unavailable on macOS BSD grep | Replaced with portable `sed -n 's/.../\1/p'` | Section 7.6 |
| 4 | CRITICAL-04 | Circuit breaker counts intentional denials as failures (dead ERR trap) | Added `_hook_err_trap` for infrastructure errors only; `deny_and_exit` disables trap before `exit 2` | Section 7.1, 12 |
| 5 | HIGH-01 | No `trap ERR` handler — unexpected errors produce undefined behavior | `trap _hook_err_trap ERR` in common.sh implements fail-open for all unexpected errors | Section 7.1 |
| 6 | MEDIUM-02 | `normalize()` grep on stopwords can fail with empty pipeline | Added `|| true` guard after stopword grep | Section 7.2 |

### Should Do Items

| # | ID | Critique Item | Resolution | Section |
|---|-----|---------------|------------|---------|
| 7 | HIGH-02 | JSON output via heredoc/echo is injection-prone | All output helpers use `jq -n --arg` for safe JSON construction | Section 7.1 |
| 8 | HIGH-03 | H06 JSON newlines from state file variables | Build state as shell variable, pass through `jq -n --arg state` | Section 7.7 |
| 9 | MEDIUM-01 | Bash integer comparison with non-integer jq output | Added `safe_int()` helper that strips non-digits, defaults to 0 | Section 7.1, 7.4 |
| 10 | MEDIUM-03 | Race conditions on budget file read-modify-write | Added `flock` for atomic operations in H03 and H05 | Section 7.4, 7.6 |
| 11 | - | "6 event types" → "7 event types" in executive summary | Corrected to 7 (added PreCompact) | Section 1 |
| 12 | - | H07 listed in both fail-open and fail-closed in failure mode table | Clarified: H07 fail-closed for *missing file* (agent failure), fail-open for *script crash* (infrastructure) | Section 8 |
| 13 | - | Missing AC for H13 environment setup | Added AC8: env setup, prerequisites, graceful degradation | Section 16 |
| 14 | - | Missing `jq`/`yq` prerequisite documentation | Added prerequisites section in executive summary; prerequisite failure modes in Section 8 | Section 1, 8 |
| 15 | - | `keyword_overlap_threshold` hardcoded in H01 | Now reads from `feature_flags.hooks_immutable_guard.keyword_overlap_threshold` via yq | Section 7.2 |
| 16 | - | H10 was prompt-based, re-introducing LLM-dependent agent filtering | Converted H10 from prompt to command hook with deterministic agent-name array | Section 4, 5, 7.10 |

### Could Do Items

| # | ID | Critique Item | Resolution | Section |
|---|-----|---------------|------------|---------|
| 17 | - | Duplicated preamble across all hook scripts | Extracted to `hooks/lib/common.sh` shared library; all scripts source it | Section 7.1 |
| 18 | - | Platform detection helper for macOS/Linux differences | `OS_TYPE`, `portable_md5()`, `portable_realpath()` in common.sh | Section 7.1 |
| 19 | - | Remaining 6 hook scripts (H07, H09, H10, H11a, H12, H13) were deferred | Full bash implementations for all remaining scripts | Section 7.8–7.13 |
| 20 | - | Directory structure missing `lib/` directory | Added `lib/common.sh` to proposed directory structure | Directory Structure |
| 21 | - | H10 still labeled "(prompt)" in agents coverage table and architecture diagram | Updated all H10 references to "(command)" | Section 3, 3.1 |

### Traceability Matrix

| Critique Judge | Findings | Resolved in v1.1 |
|----------------|----------|-------------------|
| Requirements Validator (9.5/10) | No blocking issues | N/A — all items were already resolved in v1.0 |
| Solution Architect (7.5/10) | CRITICAL-01, CRITICAL-02, CRITICAL-03, CRITICAL-04, circuit breaker logic flaw | Items 1–4, 16, 17 |
| Code Quality Reviewer (6.0/10) | HIGH-01, HIGH-02, HIGH-03, MEDIUM-01, MEDIUM-02, MEDIUM-03 | Items 5–10, 14, 18, 19 |

**Post-fix estimated score:** The v1.1 changes address all 6 CRITICAL/HIGH findings and all 3 MEDIUM findings identified by the judges. The shared library (`common.sh`) eliminates the root cause of most code quality issues (duplicated, inconsistent error handling).

---

*Proposal v1.1 generated 2026-02-05. No existing files were modified. Changes from v1.0: fixed critical bash bugs, added shared library, completed all script implementations, improved macOS portability, updated circuit breaker design.*
