# Integrations Overview

> Extracted from SKILL.md to keep the orchestrator lean. Read this file when you need
> to understand integration architecture — not during normal stage execution.

## Dev-Skills Integration

When the `dev-skills` plugin is installed alongside `product-implementation`, agents receive conditional, domain-specific skill references that enhance implementation quality. This integration is:

- **Zero-cost when disabled** — if `dev-skills` plugin is not installed, all skill injection is silently skipped
- **Orchestrator-transparent** — the orchestrator never reads or references dev-skills; all resolution happens inside coordinator subagents
- **Capped** — at most `max_skills_per_dispatch` skills (default: 3) are injected per agent dispatch to avoid context bloat

**Domain detection** runs in Stage 1 (Section 1.6) by scanning task file paths and plan.md for technology indicators. The `detected_domains` list flows through the Stage 1 summary to all downstream coordinators.

**Injection points:**
- Stage 2 coordinators inject skills into developer agent prompts (implementation patterns)
- Stage 4 coordinators add conditional review dimensions (e.g., accessibility) and inject skills into reviewer prompts
- Stage 5 coordinators inject diagram and documentation skills into tech-writer prompts

Configuration: Domain mapping and vertical agent selection in `config/profile-definitions.yaml`.

## Research MCP Integration

When MCP tools (Ref, Context7, Tavily) are available, agents receive documentation-backed context that improves implementation accuracy, build error diagnosis, and documentation quality. This integration is:

- **Zero-cost when disabled** — if `features.research_mcp` is `false` (from profile), all research steps are skipped; no MCP calls occur
- **Orchestrator-transparent** — the orchestrator never calls MCP tools; Stage 1 (inline) probes availability, coordinators build `{research_context}` blocks, agents make on-demand calls
- **Ref-primary** — Ref is the primary lookup tool, exploiting session deduplication (Dropout) for ~87% token savings across sequential stages; Context7 is secondary for library-specific queries; Tavily is last-resort for known-issues only
- **Budget-controlled** — per-stage caps on searches, reads, and total context tokens are defined in config

**MCP availability detection** runs in Stage 1 (Sections 1.6a-1.6c): lightweight probe calls determine which tools are reachable, with results stored in `mcp_availability` in the Stage 1 summary.

**Injection points:**
- Stage 2 coordinators build `{research_context}` from pre-read URLs and resolved libraries, inject into developer agent prompts. Agents also use MCP on-demand for build error diagnosis (ref_first → Context7 → Tavily escalation).
- Stage 4 coordinators re-read `research_urls_discovered` from Stage 2 summary for documentation-backed review context.
- Stage 5 coordinators re-read accumulated URLs for documentation enrichment and link generation.

**Session accumulation:** Stage 2 writes `research_urls_discovered` to its summary flags. Stages 4 and 5 re-read these URLs via Ref (cache serves faster on re-reads, maximum Dropout benefit by Stage 5).

Configuration: Budgets inlined in stage reference files. Feature gate: `features.research_mcp` in Stage 1 summary.

## CLI Dispatch

When external CLI agents (Codex, Gemini) are installed, coordinators can delegate specific tasks via Bash process-group dispatch (`scripts/dispatch-cli-agent.sh`) for multi-model code generation, testing, validation, and review. This integration is:

- **Zero-cost when disabled** — when `features.external_models` is `false` (from profile), no CLI dispatch occurs and no CLI availability checks run
- **Orchestrator-transparent** — the orchestrator never invokes CLI dispatch or reads CLI config; all dispatch happens inside coordinator subagents and Stage 1 (inline)
- **Opt-in per option** — each integration point (test author, multi-model review, spec validator, etc.) is independently toggleable
- **Graceful degradation** — every CLI dispatch has a fallback: native agent substitution or silent skip. CLI unavailability is detected in Stage 1 and propagated to all downstream stages
- **Process-group-safe** — dispatches use `setsid` + `timeout --kill-after` (Linux) or equivalent macOS fallbacks to prevent orphaned CLI processes
- **4-tier output parsing** — Tier 1 (JSON envelope via jq) → Tier 2 (partial recovery via python3) → Tier 3 (raw SUMMARY scan) → Tier 4 (diagnostic capture)

**CLI availability detection** runs in Stage 1 (Section 1.7a): dispatch script smoke tests verify which CLIs are installed, with results stored in `cli_availability` in the Stage 1 summary.

**Injection points:**
- Stage 2: Test Augmenter Primary (Option H — Codex discovers untested edge cases from specs), Test Augmenter Secondary (Option I — Gemini provides a second pass on untested scenarios), UAT Mobile Tester (Option J — Gemini runs per-phase behavioral acceptance testing and Figma visual verification on Genymotion emulator via mobile-mcp), UX Test Reviewer (Option K — Gemini reviews test coverage for UX scenarios, conditional on UI domains)
- Stage 3: Spec Validator (Option C — Gemini cross-validates implementation against specs in parallel with native validator)
- Stage 4: Three-tier review (Tier A: native always, Tier B: plugin when installed, Tier C: CLI multi-model). Tier C includes correctness reviewer (Codex), security reviewer (Codex, conditional), android domain reviewer (Gemini, conditional), codebase pattern reviewer (Gemini, Phase 2 sequential).
- Stage 5: Doc Reviewer (Option L — Gemini reviews documentation quality for accuracy and completeness)

**Shared procedure:** All CLI dispatches use the parameterized procedure in `references/cli-dispatch-procedure.md` for dispatch, timeout, 4-tier output parsing, metrics sidecar, and fallback handling.

Configuration: CLI feature mapping in `config/profile-definitions.yaml`. CLI role definitions: `config/cli_clients/`. Shared conventions: `config/cli_clients/shared/severity-output-conventions.md`. Operational constants (timeout, retry, circuit breaker) inlined in `references/cli-dispatch-procedure.md`.

## Profile & Autonomy

Controls implementation quality depth, feature flags, and how the system resolves findings, failures, and incomplete tasks — reducing or eliminating user interruptions during execution.

**Profile selection:** At Stage 1 startup (Section 1.9b), the user picks a named profile. Stage 1b reads `config/profile-definitions.yaml` to resolve the profile into concrete settings (`features.*`, `autonomy`, `uat_strategy`, `codex_model`, `codex_effort`). These resolved fields flow through the Stage 1 summary to all downstream stages — no coordinator re-reads `profile-definitions.yaml` directly.

**Autonomy levels** (derived from profile, overridable per-project in config):

| Level | Label | Findings Behavior | Incomplete Tasks | Infrastructure Failures |
|-------|-------|-------------------|------------------|------------------------|
| `auto` | Auto | Fix C/H/M, accept L | Auto-fix | Retry → continue |
| `interactive` | Interactive | Fix C/H, defer M, accept L | Auto-fix | Retry → continue |

**Auto-resolution logging:** All auto-resolved decisions are logged with prefix `[AUTO-{autonomy}]` in stage logs for full traceability.

**Escalation fallback:** If auto-resolution fails (e.g., fix agent can't resolve the issue), the system falls through to the standard `needs-user-input` escalation — the user is never silently blocked.

Configuration: `config/profile-definitions.yaml` (profile catalog) and `config/implementation-config.yaml` under `autonomy` (per-project override).
