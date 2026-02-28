# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Plugin Overview

This is a Claude Code plugin that transforms rough product drafts into finalized, non-technical PRDs through iterative file-based Q&A. Users place drafts in `requirements/draft/`, run `/product-definition:requirements`, answer questions in generated markdown files, and iterate until a complete PRD is produced.

## Plugin Testing

```bash
# Install locally for testing
claude plugins add /path/to/product-definition
claude plugins enable product-definition

# Run the main workflow
/product-definition:requirements
```

## Architecture

### Multi-Phase Workflow

The skill `skills/refinement/SKILL.md` (invoked via `commands/requirements.md`) orchestrates a 6-stage workflow:

1. **Stage 1: Setup** — Initialize workspace, detect state, select analysis mode
2. **Stage 2: Research** — Optional market/user research agenda generation
3. **Stage 3: Analysis & Questions** — Deep analysis (if MCP available), then MPA question generation
4. **Stage 4: Response & Gaps** — User responses, gap analysis
5. **Stage 5: Validation & PRD** — PRD readiness validation, PRD generation/extension
6. **Stage 6: Completion** — Lock release, report, next steps

### Dynamic Panel (MPA) Pattern

Question generation uses a **dynamic panel** of 2-5 specialist agents composed at runtime:
- `requirements-panel-builder` - Analyzes draft, detects domain, proposes panel composition
- `requirements-panel-member` (template) - Parametric agent dispatched once per panel member with variables from panel config
- Panel config persisted in `requirements/.panel-config.local.md`

Presets: `product-focused` (default), `consumer`, `marketplace`, `enterprise`, `custom`.
Available perspectives defined in `config/requirements-config.yaml` -> `panel.available_perspectives`.

These run in parallel via the Task tool, then `requirements-question-synthesis` merges and deduplicates their output.

### Analysis Mode Hierarchy

| Mode | Description | MCP Required |
|------|-------------|--------------|
| Complete | MPA + PAL ThinkDeep (9 calls) + Sequential Thinking | Yes |
| Advanced | MPA + PAL ThinkDeep (6 calls) | Yes |
| Standard | MPA only | No |
| Rapid | Single agent | No |

The plugin gracefully degrades when MCP tools are unavailable—Complete/Advanced modes fall back to Standard.

### State Management

State is persisted in `requirements/.requirements-state.local.md` (YAML frontmatter + markdown). The workflow is resumable—user decisions in `user_decisions` are immutable and never re-asked.

### File-Based Q&A Pattern

Questions are written to `requirements/working/QUESTIONS-NNN.md` with structured format:
- Multi-perspective analysis section
- 3+ options per question with pros/cons and star ratings
- Checkbox format for user selection (`[x]` marks choice)

Users answer offline, then re-run the command to continue.

## Key Design Patterns

### PRD EXTEND Mode

When `PRD.md` exists, the workflow analyzes sections for completeness and extends rather than recreates. Never overwrite existing decisions.

### No Artificial Limits

Configuration explicitly sets `max_questions_total: null`—generate ALL questions necessary for PRD completeness. Users must answer 100% of questions (no skipping).

### Non-Technical Focus

PRDs must NOT contain technical implementation details (APIs, architecture, databases). The config includes `technical_keywords_forbidden` validation.

### PAL/ThinkDeep Integration

Stage 3 runs multi-model ThinkDeep analysis (gpt-5.2, gemini-3-pro-preview, grok-4) across perspectives (competitive, risk, contrarian). These insights inform MPA agent option generation.

## File Naming Conventions

- Agents: `agents/{domain}-{role}.md` (e.g., `requirements-panel-member.md`)
- Skill references: `skills/{name}/references/{stage-or-protocol}.md`
- Templates: `templates/{purpose}-template.md`
- User workspace files: `requirements/working/QUESTIONS-{NNN}.md`
- State: `requirements/.requirements-state.local.md`

## Plugin Path Variable

Use `$CLAUDE_PLUGIN_ROOT` to reference plugin-relative paths in commands and agents. This resolves to the plugin installation directory.

---

## Learnings from Development

### V-Model Test Strategy Integration (v1.3.0)

The `/specify` command now includes Phase 5.7 for V-Model test strategy generation. Key architectural decisions:

1. **Single Agent vs MPA**: Test strategy uses a single `qa-strategist` agent rather than MPA. Unlike question generation (where diverse perspectives reduce blind spots), test strategy benefits from unified traceability—one agent maintains consistent AC→Test mapping across all test levels.

2. **Phase Placement**: Test strategy (5.7) follows Design Feedback (5.5) because:
   - Requires completed spec.md with acceptance criteria
   - Requires design-brief.md for visual oracles
   - Optionally uses figma_context.md for pixel-perfect baselines

3. **Inner/Outer Loop Classification**:
   - Inner Loop (CI-automated): Unit tests, Integration tests
   - Outer Loop (Agentic): E2E tests, Visual regression tests

### Modular Reference Pattern

**Problem**: Large Sequential Thinking templates bloated agent context on every invocation.

**Solution**: Extract reusable templates to `agents/{domain}-references/` subdirectories:
```
agents/
├── qa-strategist.md              # Core agent (~400 lines)
└── qa-references/
    └── sequential-thinking-templates.md  # Detailed templates (~300 lines)
```

**Benefits**:
- Agent loads lean; templates loaded on-demand
- Same pattern used by `ba-references/` for specification templates
- Reduces token usage for simple invocations

**Implementation**: Add "Reference Files" section to agent with `Load When` guidance:
```markdown
## Reference Files

| Reference | Purpose | Load When |
|-----------|---------|-----------|
| `@$CLAUDE_PLUGIN_ROOT/agents/qa-references/...` | Templates | Starting generation |
```

### Pre-validation Gates Pattern

**Problem**: Agents fail mid-execution when required inputs are missing.

**Solution**: Add mandatory validation steps before launching agents:
```markdown
### Step X.Y: Validate Required Inputs (MANDATORY CHECK)

**BEFORE launching {Agent}, verify required files exist:**

```bash
test -f {path}/required-file.md || echo "BLOCKER: file not found"
```

**If BLOCKER found**: Skip this phase, document gap, continue to next phase.
```

**Applied to**: Phase 5.7 requires both spec.md AND design-brief.md before qa-strategist launch.

### Agent Definition Consistency

When creating new agents, follow the established pattern:

1. **Frontmatter** (lines 1-7):
   ```yaml
   ---
   name: agent-name
   description: One-line purpose
   model: sonnet|opus|haiku
   color: green|blue|yellow
   tools: [list of required tools]
   ---
   ```

2. **CRITICAL RULES** bookends:
   ```markdown
   **CRITICAL RULES (High Attention Zone - Start)**
   [numbered rules]

   ... agent body ...

   **CRITICAL RULES (High Attention Zone - End)**
   [repeated numbered rules]
   ```

3. **Model Assignment**: Add agent to appropriate tier in `config/specify-config.yaml`:
   ```yaml
   model_assignments:
     sonnet:
       - "qa-strategist"  # Add with comment explaining purpose
   ```

### Template Variable Conventions

Use consistent `UPPERCASE_WITH_UNDERSCORES` for template variables:
- `{FEATURE_NAME}` not `{Feature Name}` or `{feature_name}`
- `{FEATURE_ID}` not `{feature_id}`
- `{SPEC_VERSION}` not `{spec_version}`

Exception: Test IDs use format `{XX-NNN}` where XX is level prefix (UT, INT, E2E, VIS).

### Checklist Enhancement Pattern

When adding new capability (like V-Model testing), update BOTH checklists:
- `templates/spec-checklist.md` - General specifications
- `templates/spec-checklist-mobile.md` - Mobile-specific with platform nuances

Add items in logical groups with clear headers. Verify item counts after changes.

### Design Narration v1.4.0 Patterns

Three patterns introduced in the design-narration skill (v1.4.0) that are reusable across other skills:

#### N/A Applicability Assessment

**Problem**: Edge case auditing applied all categories to every screen, generating false positives (e.g., flagging "Network: Offline state" on a static settings screen with no network calls).

**Solution**: Add an Applicability Assessment table to the agent that maps each audit category to a condition (e.g., "Network → applies when screen loads/submits data"). Categories that don't apply get `N/A` instead of `0/0`, and N/A categories are excluded from coverage percentage denominators.

**Benefit**: Eliminates noise findings that waste user time during revision rounds. Coverage percentages reflect genuine gaps rather than inapplicable categories.

#### Bias Mitigation via Randomized Read Order

**Problem**: When a synthesis agent reads MPA outputs in a fixed order, the first-read agent's framing anchors the synthesis — findings from agent #1 get elevated priority regardless of merit.

**Solution**: Instruct the synthesis coordinator to read MPA outputs in a randomized order per invocation. Pair with a `source_dominance_max_pct` config threshold (default 60%) that triggers re-examination when one agent contributes a disproportionate share of findings.

**Applied to**: `validation-protocol.md` Step 4.4 (synthesis dispatch) and `narration-validation-synthesis.md` (Source Dominance bias check).

#### Confidence Tagging Pattern

**Problem**: MPA agents produce findings at varying levels of certainty. A "possibly covered by a global handler" finding shouldn't carry the same weight as a "definitively missing — no mention anywhere" finding.

**Solution**: Each MPA agent tags every finding with a confidence level (high/medium/low). The synthesis agent uses confidence for: (1) deduplication — merged findings take the higher confidence, (2) PAL elevation — PAL corroboration bumps confidence one tier, (3) intra-severity sorting — high-confidence findings surface first within each priority tier. Confidence never overrides severity — a low-confidence CRITICAL finding remains CRITICAL.

**Applied to**: `narration-edge-case-auditor.md`, `narration-developer-implementability.md`, `narration-ux-completeness.md` (producers), and `narration-validation-synthesis.md` (consumer).

### Design Handoff v2.3.0 Patterns

Three patterns introduced in the design-handoff skill (v2.3.0) that evolved from design-narration lessons:

#### Figma-as-Source-of-Truth with Supplement-Only Gaps

**Problem**: design-narration produced ~4700-line UX-NARRATIVE files that described EVERYTHING including what's already visible in Figma (layouts, colors, spacing). This created unreadable output, SDD drift risk, and overhead for coding agents.

**Solution**: Two-track approach — (A) prepare the Figma file itself for coding agent consumption (naming, structure, components, tokens), and (B) generate a compact supplement covering ONLY what Figma cannot express (behaviors, transitions, states, animations, data requirements, edge cases). The supplement uses tables over prose; every word must earn its place.

**Key rule**: If there's a conflict between supplement and Figma, the Figma file wins (opposite of design-narration which said narrative takes precedence).

**Applied to**: `skills/design-handoff/SKILL.md` (core philosophy), `references/gap-analysis.md` (6-category gap detection), `references/output-assembly.md` (assembly rules).

#### LLM-as-Judge at Stage Boundaries (Replacing MPA+PAL)

**Problem**: design-narration used 3 MPA specialist agents + PAL Consensus + validation synthesis (8 total agents) for quality verification. This was slow, context-heavy, and the synthesis step often produced biased results (first-read anchoring).

**Solution**: Single reusable `handoff-judge` agent (opus) dispatched at 4 critical stage boundaries (2J, 3J, 3.5J, 5J), each with a checkpoint-specific rubric. The judge is a dedicated PHASE element, not an inline afterthought — dispatched between stages with its own verdict format (PASS/NEEDS_FIX/BLOCK).

**Benefit**: Simpler quality gates with clearer pass/fail criteria. ~46% reduction in total reference file lines. No synthesis bias issues since there's a single evaluator per checkpoint.

**Applied to**: `references/judge-protocol.md` (shared dispatch pattern + 4 rubrics), `agents/handoff-judge.md` (470 lines with per-checkpoint dimension scoring).

#### One-Screen-Per-Dispatch for Context-Heavy MCP

**Problem**: figma-console MCP returns large node trees, variable collections, and component metadata per call. Processing multiple screens in a single agent dispatch leads to context compaction, causing the agent to lose track of node IDs, skip checklist steps, or produce inaccurate visual diffs.

**Solution**: Orchestrator dispatches `handoff-figma-preparer` once per screen, sequentially. State file tracks step-level progress within each screen for crash recovery. Between dispatches, orchestrator reads state to determine outcome (prepared/blocked/error).

**Trade-off**: Higher dispatch latency (N dispatches instead of 1), accepted for dramatically better per-screen quality and reliable crash recovery.

**Applied to**: `references/figma-preparation.md` (dispatch loop + crash recovery), `agents/handoff-figma-preparer.md` (9-step checklist per screen).
