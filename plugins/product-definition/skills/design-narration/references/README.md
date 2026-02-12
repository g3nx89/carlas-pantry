# Reference Files Index

## Reference File Usage

| File | Read When... |
|------|--------------|
| `setup-protocol.md` | Stage 1 execution — Figma MCP check, context doc, lock acquisition, state init/resume, screen selection (interactive or batch) |
| `screen-processing.md` | Stage 2 execution (interactive) — per-screen analysis dispatch, Q&A mediation, sign-off, pattern accumulation |
| `batch-processing.md` | Stage 2-BATCH execution (batch mode) — sequential analysis, question consolidation, batch Q&A cycles, convergence |
| `coherence-protocol.md` | Stage 3 execution — cross-screen auditor dispatch, inconsistency handling, mermaid diagram generation |
| `validation-protocol.md` | Stage 4 execution — MPA parallel dispatch, PAL Consensus, synthesis, findings presentation |
| `critique-rubric.md` | Stage 2/2-BATCH dispatch context — 5-dimension self-critique rubric passed to screen analyzer agent |
| `output-assembly.md` | Stage 5 execution — final UX-NARRATIVE.md assembly (single-file or multi-file mode) from screens, patterns, validation |
| `state-schema.md` | State creation and crash recovery — YAML schema (v2), initialization template, batch mode section, append-only decision trail |
| `recovery-protocol.md` | Skill re-invocation — crash detection and recovery when state is incomplete (including batch mode statuses) |
| `error-handling.md` | All stages — error taxonomy, logging format, per-stage error tables, escalation paths |
| `checkpoint-protocol.md` | All stages — state update sequence, lock refresh, decision append, integrity verification |
| `implementability-rubric.md` | Stage 4 — shared rubric for developer-implementability evaluation (consumed by agent file and clink prompt) |
| `auto-resolve-protocol.md` | All question-presenting stages — auto-resolution gate that filters questions answerable from prior answers, context documents, or accumulated patterns |

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| `setup-protocol.md` | ~340 | Stage 1: Config validation (v1.5.0 keys + batch keys + result_handoff keys + clink keys + clink_implementability keys + **clink model keys + auto_resolve keys**), Figma check, context doc, lock (with race condition note), state init/resume, screen selection (interactive: single screen, batch: page frames + descriptions matching) |
| `screen-processing.md` | ~410 | Per-screen loop (interactive): analysis dispatch (with token budgets), **auto-resolve gate before Q&A mediation**, Q&A mediation, stall detection, refinement (with variable sourcing), decision revision, sign-off, context management, session resume |
| `batch-processing.md` | ~620 | Batch cycle (batch mode): sequential analysis with pattern accumulation, question consolidation dispatch, **auto-resolve gate before BATCH-QUESTIONS (Step 2B.2b)**, BATCH-QUESTIONS doc assembly, user pause/resume, **parallel refinement with file-based result handoff** (3-phase: dispatch/completion/collection with defensive parsing, auto-retry, and partial timeout handling), convergence check with stall detection |
| `coherence-protocol.md` | ~490 | **Clink pathway (Gemini CLI for large screen sets, with explicit model + reasoning preamble, few-shot output example)**, digest-first fallback, cross-screen auditor dispatch (with ST instruction), **auto-resolve gate for inconsistencies**, inconsistency handling, mermaid diagrams (with validation checklist), pattern extraction |
| `validation-protocol.md` | ~630 | **Clink/Codex pathway for implementability (with explicit model hint + reasoning preamble, Task fallback with ST instruction)**, MPA parallel dispatch (3 agents) with constraints and failure handling, post-MPA conflict verification, PAL Consensus multi-step workflow (config-referenced models with stance steering, continuation_id chaining), synthesis (with randomized read order, conflict table), **auto-resolve gate for critical findings**, validation gate |
| `critique-rubric.md` | ~280 | 5-dimension rubric, CoT reasoning protocol, calibration examples, failure modes, dimension-to-category mapping, self-consistency check |
| `output-assembly.md` | ~420 | Stage 5: completeness assessment (DRAFT/FINAL status), pre-validation gate (Required/Expected/Optional), **output mode determination (Step 5.0c)**, compile patterns, PATHWAY A (single-file: order screens, append appendices including auto-resolved questions), PATHWAY B (**multi-file: enhance screen files in-place with nav headers, build screen inventory, extract decision log, render index template, verify relative links**) |
| `state-schema.md` | ~275 | State file YAML schema v3: workflow_mode, per-screen source field, batch_mode section with convergence tracking, **auto_resolved_questions (v3)**, **output.mode (v1.8.0)**, status transitions (interactive + batch), initialization template, v1→v2→v3 migration |
| `recovery-protocol.md` | ~295 | Crash detection per stage (including Stage 2-BATCH and Stage 5), batch status recovery (analyzing/consolidating/waiting/refining with **per-screen file verification for parallel dispatch**), **Stage 5 multi-file recovery (nav headers, decision-log.md, lock cleanup)**, partial Q&A recovery, summary reconstruction, state cleanup |
| `error-handling.md` | ~180 | Error taxonomy (FATAL/BLOCKING/DEGRADED/WARNING), cross-stage plugin integrity errors, logging format, per-stage error tables (with v1.4.0 features), **Stage 2-BATCH file-based handoff errors**, **Stage 3 clink errors (all DEGRADED with digest-first fallback)**, **Stage 4 clink/Codex implementability errors (DEGRADED with Task fallback)**, PAL multi-step failure format + PAL-skipped format |
| `checkpoint-protocol.md` | ~140 | State update sequence, lock refresh, decision append, conditional patterns update, integrity verification, checkpoint triggers (**including parallel refinement batch trigger and auto-resolve gate trigger**) |
| `implementability-rubric.md` | ~95 | Shared 5-dimension implementability evaluation rubric (Component Specification, Interaction Completeness, Data Requirements, Layout Precision, Platform Specifics), scoring format, "Would Need to Ask" classification, output YAML schema — consumed by both `agents/narration-developer-implementability.md` and `validation-protocol.md` clink prompt |
| `auto-resolve-protocol.md` | ~155 | Auto-resolution gate logic: source priority (prior_answers > context_document > accumulated_patterns), confidence matching, registry file format, exclusion rules (subjective, conflict, revision questions), post-gate actions (state append, registry write, user notification) |

## Cross-References

### Reference Files -> Config

- All reference files read thresholds and parameters from `$CLAUDE_PLUGIN_ROOT/config/narration-config.yaml`
- `critique-rubric.md` dimensions map 1:1 with `narration-config.yaml` -> `self_critique.dimensions`
- `validation-protocol.md` PAL model aliases and stances sourced from `narration-config.yaml` -> `validation.pal_consensus.models[].model`, `validation.pal_consensus.models[].stance`
- `coherence-protocol.md` checks sourced from `narration-config.yaml` -> `coherence_checks`
- `coherence-protocol.md` clink config sourced from `narration-config.yaml` -> `coherence.clink_enabled`, `coherence.clink_threshold`, `coherence.clink_cli`, `coherence.clink_timeout_seconds`
- `validation-protocol.md` clink implementability config sourced from `narration-config.yaml` -> `validation.mpa.clink_implementability.enabled`, `validation.mpa.clink_implementability.cli_name`, `validation.mpa.clink_implementability.timeout_seconds`
- `batch-processing.md` result handoff config sourced from `narration-config.yaml` -> `batch_mode.result_handoff.*`
- `setup-protocol.md` lock timeout from `narration-config.yaml` -> `state.lock_stale_timeout_minutes`
- `state-schema.md` schema version from `narration-config.yaml` -> `state.schema_version`
- `coherence-protocol.md` clink model from `narration-config.yaml` -> `coherence.clink_model`, `coherence.clink_use_thinking`
- `validation-protocol.md` clink model hint from `narration-config.yaml` -> `validation.mpa.clink_implementability.model_hint`, `validation.mpa.clink_implementability.use_thinking`
- `auto-resolve-protocol.md` config sourced from `narration-config.yaml` -> `auto_resolve.*`
- `output-assembly.md` auto-resolve report flag from `narration-config.yaml` -> `auto_resolve.include_in_report`
- `output-assembly.md` progressive disclosure config from `narration-config.yaml` -> `output.progressive_disclosure.*`
- `recovery-protocol.md` progressive disclosure config from `narration-config.yaml` -> `output.progressive_disclosure.screen_nav_header`, `output.progressive_disclosure.decision_log_file`

### Reference Files -> Agents

- `setup-protocol.md` dispatches `agents/narration-figma-discovery.md` (interactive selection and batch page discovery)
- `screen-processing.md` dispatches `agents/narration-figma-discovery.md` (next screen detection in interactive loop)
- `screen-processing.md` dispatches `agents/narration-screen-analyzer.md` (both 2A analysis and 2B refinement)
- `batch-processing.md` dispatches `agents/narration-screen-analyzer.md` (batch_analysis and refinement entry types)
- `batch-processing.md` dispatches `agents/narration-question-consolidator.md` (question dedup, conflict detection, grouping)
- `coherence-protocol.md` dispatches `agents/narration-coherence-auditor.md`
- `validation-protocol.md` dispatches 3 MPA agents in parallel:
  - `agents/narration-developer-implementability.md`
  - `agents/narration-ux-completeness.md`
  - `agents/narration-edge-case-auditor.md`
- `validation-protocol.md` dispatches synthesis via `agents/narration-validation-synthesis.md`

### Reference Files -> Templates

- `screen-processing.md` references `$CLAUDE_PLUGIN_ROOT/templates/screen-narrative-template.md` (passed to screen analyzer)
- `batch-processing.md` references `$CLAUDE_PLUGIN_ROOT/templates/screen-narrative-template.md` (passed to screen analyzer in batch mode)
- `batch-processing.md` references `$CLAUDE_PLUGIN_ROOT/templates/batch-questions-template.md` (BATCH-QUESTIONS document structure)
- `setup-protocol.md` references `$CLAUDE_PLUGIN_ROOT/templates/screen-descriptions-template.md` (user-facing template for batch mode input)
- `output-assembly.md` references `$CLAUDE_PLUGIN_ROOT/templates/ux-narrative-template.md` (single-file assembly)
- `output-assembly.md` references `$CLAUDE_PLUGIN_ROOT/templates/ux-narrative-index-template.md` (multi-file index assembly)

### Reference Files -> Reference Files

- `setup-protocol.md` references `state-schema.md` (for initialization template)
- `setup-protocol.md` references `recovery-protocol.md` (for crash detection on resume)
- `screen-processing.md` references `critique-rubric.md` (passed to screen analyzer agent)
- `batch-processing.md` references `critique-rubric.md` (passed to screen analyzer agent in batch mode)
- `batch-processing.md` references `checkpoint-protocol.md` (state updates at 7 checkpoint triggers)
- `batch-processing.md` references `error-handling.md` (error classification for batch failures)
- `critique-rubric.md` is loaded directly by `agents/narration-screen-analyzer.md` (self-critique integration, self-consistency check)
- `recovery-protocol.md` references `state-schema.md` (for state repair and field validation)
- `output-assembly.md` references `coherence-protocol.md` (for mermaid diagrams and patterns)
- `output-assembly.md` references `state-schema.md` (for decision audit trail extraction and output.mode tracking)
- `validation-protocol.md` references `screen-processing.md` (for screen file list sourcing)
- `validation-protocol.md` clink prompt inlines content from `implementability-rubric.md` (SYNC NOTE in validation-protocol.md)
- `implementability-rubric.md` is loaded by `agents/narration-developer-implementability.md` (Task subagent pathway)
- `screen-processing.md` references `auto-resolve-protocol.md` (gate before AskUserQuestion in Q&A mediation)
- `batch-processing.md` references `auto-resolve-protocol.md` (gate before BATCH-QUESTIONS write in Step 2B.2b)
- `coherence-protocol.md` references `auto-resolve-protocol.md` (gate before presenting inconsistencies)
- `validation-protocol.md` references `auto-resolve-protocol.md` (gate before presenting critical findings)
- `output-assembly.md` references `auto-resolve-protocol.md` (auto-resolved questions appendix in Step 5.5b)
- `auto-resolve-protocol.md` references `checkpoint-protocol.md` (state checkpointing after auto-resolve)
- `auto-resolve-protocol.md` references `state-schema.md` (auto_resolved_questions field structure)

### Reference Files -> Shared Protocols

- `error-handling.md` referenced by all stage files for error severity classification and logging format
- `checkpoint-protocol.md` referenced by `screen-processing.md` (Rule 3: "checkpoint after every screen") and all stage transitions
- `error-handling.md` references `recovery-protocol.md` for crash recovery procedures
- `checkpoint-protocol.md` follows the field structure defined in `state-schema.md` (implicit — uses same YAML fields for state updates and decision audit trail)
- `auto-resolve-protocol.md` referenced by `screen-processing.md`, `batch-processing.md`, `coherence-protocol.md`, and `validation-protocol.md` as a pre-presentation gate for question filtering

### Data Flow Between Stages

- Stage 1 (`setup-protocol.md`) produces state file + directories + lock -> consumed by all subsequent stages
- Stage 1 (batch mode) additionally produces: matched screens list, screen descriptions parse, working/ directory -> consumed by Stage 2-BATCH
- Stage 2 (`screen-processing.md`, interactive) produces per-screen narrative files + accumulated patterns -> consumed by Stage 3
- Stage 2-BATCH (`batch-processing.md`) produces per-screen narrative files + accumulated patterns + BATCH-QUESTIONS docs + consolidation summaries -> consumed by Stage 3
- Stage 3 (`coherence-protocol.md`) produces coherence report + mermaid diagrams + resolved patterns -> consumed by Stages 4 and 5
- Stage 4 (`validation-protocol.md`) produces synthesis with scores and findings -> consumed by Stage 5 (`output-assembly.md`)
- `recovery-protocol.md` reads state file and per-stage artifacts to detect and recover from crashes (including batch mode statuses)

### External References

- All reference files reference agents at `$CLAUDE_PLUGIN_ROOT/agents/narration-*.md`
- All reference files reference config at `$CLAUDE_PLUGIN_ROOT/config/narration-config.yaml`
- `screen-processing.md` references critique rubric at `$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/critique-rubric.md`
- `coherence-protocol.md` references `mcp__pal__clink` tool for large screen set coherence via Gemini CLI

## Structural Patterns

All reference files follow this structure:
1. YAML frontmatter with `stage` name and `artifacts_written` list
2. **CRITICAL RULES** section at top (attention-favored position)
3. Numbered steps for execution
4. Output format / summary contract
5. **Self-Verification** checklist (mandatory before advancing)
6. **CRITICAL RULES REMINDER** at bottom (attention-favored position)

**Max-rules guidance:** Keep CRITICAL RULES sections to **3-5 rules maximum** per reference file.
