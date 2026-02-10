# Reference Files Index

## Reference File Usage

| File | Read When... |
|------|--------------|
| `setup-protocol.md` | Stage 1 execution — Figma MCP check, context doc, lock acquisition, state init/resume, first screen selection |
| `screen-processing.md` | Stage 2 execution — per-screen analysis dispatch, Q&A mediation, sign-off, pattern accumulation |
| `coherence-protocol.md` | Stage 3 execution — cross-screen auditor dispatch, inconsistency handling, mermaid diagram generation |
| `validation-protocol.md` | Stage 4 execution — MPA parallel dispatch, PAL Consensus, synthesis, findings presentation |
| `critique-rubric.md` | Stage 2 dispatch context — 5-dimension self-critique rubric passed to screen analyzer agent |
| `output-assembly.md` | Stage 5 execution — final UX-NARRATIVE.md assembly from screens, patterns, validation |
| `state-schema.md` | State creation and crash recovery — YAML schema, initialization template, append-only decision trail |
| `recovery-protocol.md` | Skill re-invocation — crash detection and recovery when state is incomplete |
| `error-handling.md` | All stages — error taxonomy, logging format, per-stage error tables, escalation paths |
| `checkpoint-protocol.md` | All stages — state update sequence, lock refresh, decision append, integrity verification |

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| `setup-protocol.md` | ~183 | Stage 1: Config validation (v1.4.0 keys + cross-key validations), Figma check, context doc, lock (with race condition note), state init/resume, first screen selection |
| `screen-processing.md` | ~400 | Per-screen loop: analysis dispatch (with token budgets), Q&A mediation, stall detection, refinement (with variable sourcing), decision revision, sign-off, context management, session resume |
| `coherence-protocol.md` | ~265 | Large screen set handling (digest-first), cross-screen auditor dispatch, inconsistency handling, mermaid diagrams (with validation checklist), pattern extraction |
| `validation-protocol.md` | ~430 | MPA parallel dispatch (3 agents) with constraints and failure handling, post-MPA conflict verification, PAL Consensus multi-step workflow (config-referenced models with stance steering, continuation_id chaining), synthesis (with randomized read order, conflict table), validation gate |
| `critique-rubric.md` | ~280 | 5-dimension rubric, CoT reasoning protocol, calibration examples, failure modes, dimension-to-category mapping, self-consistency check |
| `output-assembly.md` | ~135 | Stage 5: completeness assessment (DRAFT/FINAL status), pre-validation gate (Required/Expected/Optional), compile patterns, order screens, append appendices, write output |
| `state-schema.md` | ~190 | State file YAML schema, per-screen structure (with refinement_rounds, flag_reason), status transitions, decision audit trail, initialization template, schema migration stub |
| `recovery-protocol.md` | ~185 | Crash detection per stage (including Stage 5), partial Q&A recovery (v1.4.0), summary reconstruction, .qa-digest.md verification, state cleanup |
| `error-handling.md` | ~159 | Error taxonomy (FATAL/BLOCKING/DEGRADED/WARNING), cross-stage plugin integrity errors, logging format, per-stage error tables (with v1.4.0 features), PAL multi-step failure format + PAL-skipped format |
| `checkpoint-protocol.md` | ~130 | State update sequence, lock refresh, decision append, conditional patterns update, integrity verification, checkpoint triggers |

## Cross-References

### Reference Files -> Config

- All reference files read thresholds and parameters from `$CLAUDE_PLUGIN_ROOT/config/narration-config.yaml`
- `critique-rubric.md` dimensions map 1:1 with `narration-config.yaml` -> `self_critique.dimensions`
- `validation-protocol.md` PAL model aliases and stances sourced from `narration-config.yaml` -> `validation.pal_consensus.models[].model`, `validation.pal_consensus.models[].stance`
- `coherence-protocol.md` checks sourced from `narration-config.yaml` -> `coherence_checks`
- `setup-protocol.md` lock timeout from `narration-config.yaml` -> `state.lock_stale_timeout_minutes`
- `state-schema.md` schema version from `narration-config.yaml` -> `state.schema_version`

### Reference Files -> Agents

- `screen-processing.md` dispatches `agents/narration-screen-analyzer.md` (both 2A analysis and 2B refinement)
- `coherence-protocol.md` dispatches `agents/narration-coherence-auditor.md`
- `validation-protocol.md` dispatches 3 MPA agents in parallel:
  - `agents/narration-developer-implementability.md`
  - `agents/narration-ux-completeness.md`
  - `agents/narration-edge-case-auditor.md`
- `validation-protocol.md` dispatches synthesis via `agents/narration-validation-synthesis.md`

### Reference Files -> Templates

- `screen-processing.md` references `$CLAUDE_PLUGIN_ROOT/templates/screen-narrative-template.md` (passed to screen analyzer)
- `output-assembly.md` references `$CLAUDE_PLUGIN_ROOT/templates/ux-narrative-template.md` (final assembly)

### Reference Files -> Reference Files

- `setup-protocol.md` references `state-schema.md` (for initialization template)
- `setup-protocol.md` references `recovery-protocol.md` (for crash detection on resume)
- `screen-processing.md` references `critique-rubric.md` (passed to screen analyzer agent)
- `critique-rubric.md` is loaded directly by `agents/narration-screen-analyzer.md` (self-critique integration, self-consistency check)
- `recovery-protocol.md` references `state-schema.md` (for state repair and field validation)
- `output-assembly.md` references `coherence-protocol.md` (for mermaid diagrams and patterns)
- `output-assembly.md` references `state-schema.md` (for decision audit trail extraction)
- `validation-protocol.md` references `screen-processing.md` (for screen file list sourcing)

### Reference Files -> Shared Protocols

- `error-handling.md` referenced by all stage files for error severity classification and logging format
- `checkpoint-protocol.md` referenced by `screen-processing.md` (Rule 3: "checkpoint after every screen") and all stage transitions
- `error-handling.md` references `recovery-protocol.md` for crash recovery procedures
- `checkpoint-protocol.md` follows the field structure defined in `state-schema.md` (implicit — uses same YAML fields for state updates and decision audit trail)

### Data Flow Between Stages

- Stage 1 (`setup-protocol.md`) produces state file + directories + lock -> consumed by all subsequent stages
- Stage 2 (`screen-processing.md`) produces per-screen narrative files + accumulated patterns -> consumed by Stage 3
- Stage 3 (`coherence-protocol.md`) produces coherence report + mermaid diagrams + resolved patterns -> consumed by Stages 4 and 5
- Stage 4 (`validation-protocol.md`) produces synthesis with scores and findings -> consumed by Stage 5 (`output-assembly.md`)
- `recovery-protocol.md` reads state file and per-stage artifacts to detect and recover from crashes

### External References

- All reference files reference agents at `$CLAUDE_PLUGIN_ROOT/agents/narration-*.md`
- All reference files reference config at `$CLAUDE_PLUGIN_ROOT/config/narration-config.yaml`
- `screen-processing.md` references critique rubric at `$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/critique-rubric.md`

## Structural Patterns

All reference files follow this structure:
1. YAML frontmatter with `stage` name and `artifacts_written` list
2. **CRITICAL RULES** section at top (attention-favored position)
3. Numbered steps for execution
4. Output format / summary contract
5. **Self-Verification** checklist (mandatory before advancing)
6. **CRITICAL RULES REMINDER** at bottom (attention-favored position)

**Max-rules guidance:** Keep CRITICAL RULES sections to **3-5 rules maximum** per reference file.
