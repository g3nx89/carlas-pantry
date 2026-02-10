# Reference Files Index

## Reference File Usage

| File | Read When... |
|------|--------------|
| `screen-processing.md` | Stage 2 execution — per-screen analysis dispatch, Q&A mediation, sign-off, pattern accumulation |
| `coherence-protocol.md` | Stage 3 execution — cross-screen auditor dispatch, inconsistency handling, mermaid diagram generation |
| `validation-protocol.md` | Stage 4 execution — MPA parallel dispatch, PAL Consensus, synthesis, findings presentation |
| `critique-rubric.md` | Stage 2 dispatch context — 5-dimension self-critique rubric passed to screen analyzer agent |
| `output-assembly.md` | Stage 5 execution — final UX-NARRATIVE.md assembly from screens, patterns, validation |
| `recovery-protocol.md` | Skill re-invocation — crash detection and recovery when state is incomplete |

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| `screen-processing.md` | ~315 | Per-screen loop: analysis dispatch, Q&A mediation, refinement, decision revision, sign-off, session resume |
| `coherence-protocol.md` | ~214 | Cross-screen auditor dispatch, inconsistency handling, mermaid diagrams, pattern extraction |
| `validation-protocol.md` | ~228 | MPA parallel dispatch (3 agents), PAL Consensus, synthesis, validation gate |
| `critique-rubric.md` | ~185 | 5-dimension rubric (4-point scale), evidence lists, failure modes, remediation |
| `output-assembly.md` | ~80 | Stage 5 assembly: compile patterns, order screens, append appendices, write output |
| `recovery-protocol.md` | ~85 | Crash detection per stage, summary reconstruction, state cleanup |

## Cross-References

### Reference Files -> Config

- All reference files read thresholds and parameters from `$CLAUDE_PLUGIN_ROOT/config/narration-config.yaml`
- `critique-rubric.md` dimensions map 1:1 with `narration-config.yaml` -> `self_critique.dimensions`
- `validation-protocol.md` PAL models sourced from `narration-config.yaml` -> `validation.pal_consensus.models`
- `coherence-protocol.md` checks sourced from `narration-config.yaml` -> `coherence_checks`

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

### Data Flow Between Stages

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
