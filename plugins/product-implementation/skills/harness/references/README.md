# Harness Skill — Reference Index

| File | Lines | Size | Purpose |
|------|-------|------|---------|
| `harness-components.md` | ~665 | 24K | Templates for all 6 harness categories + quality score + entropy management |
| `evaluation-loop.md` | ~467 | 18K | Eval loop: UAT, judging, feedback, stop gate, project adaptations |
| `feature-list-schema.md` | ~108 | 4K | JSON schema, tasks.md→JSON conversion, immutability rules |
| `hooks-catalog.md` | ~394 | 14K | Hook catalog: essential, architecture guards, entropy management, custom |
| `cli-agents.md` | ~513 | 19K | External CLI agent dispatch: Codex Plugin, review, UAT, stop gate |

## Cross-References

- `harness-components.md` Section 2c references `evaluation-loop.md` Section 4a for evaluator prompt template
- `harness-components.md` Section 2c references `evaluation-loop.md` Section 8 for project adaptations
- `harness-components.md` Section 2d has the unified session-startup template (single source of truth)
- `harness-components.md` Section 2d has quality-score.json and last-cleanup.json templates
- `harness-components.md` Section 2f has the unified sprint contract template (single source of truth)
- `harness-components.md` Section 2f has the cleanup sprint contract template
- `harness-components.md` Section 2f references `evaluation-loop.md` Section 3 for negotiation protocol
- `harness-components.md` Section 2f references `hooks-catalog.md` "Entropy Management" for hook details
- `evaluation-loop.md` Section 3 references `harness-components.md` Section 2f for sprint contract template
- `evaluation-loop.md` Section 4c references `cli-agents.md` Section 3 for CLI evaluator dispatch
- `cli-agents.md` Section 3 references `evaluation-loop.md` Section 4c for native vs CLI comparison
- `hooks-catalog.md` "Architecture Guards" references `SKILL.md` Stage 1b for boundary detection
- `hooks-catalog.md` "Entropy Management" references `harness-components.md` Section 2d for last-cleanup.json
- Both `harness-components.md` and `hooks-catalog.md` reference `.claude/settings.json` format

## Read Order

1. Start with `SKILL.md` (always loaded) — provides the workflow and decision framework
2. Read `harness-components.md` section-by-section as you configure each category
3. Read `evaluation-loop.md` when configuring interactive UAT evaluation (Stage 2c)
   — Read ONLY the platform subsection matching your project (Section 2)
4. Read `feature-list-schema.md` when converting tasks.md in Stage 2d
5. Read `hooks-catalog.md` when choosing hooks in Stage 2b
6. Read `cli-agents.md` when Codex or Gemini CLI is available (Stage 2c/2e)

## Deduplication Notes

These artifacts have a SINGLE canonical location:
- **Sprint contract template** → `harness-components.md` Section 2f (not evaluation-loop.md)
- **Cleanup sprint contract** → `harness-components.md` Section 2f
- **Session startup checklist** → `harness-components.md` Section 2d (not cli-agents.md or evaluation-loop.md)
- **Evaluator prompt template** → `evaluation-loop.md` Section 4a (not harness-components.md)
- **Quality score template** → `harness-components.md` Section 2d
- **Last cleanup template** → `harness-components.md` Section 2d
- **Entropy check hook** → `hooks-catalog.md` "Entropy Management" (workflow in harness-components.md 2f)
- **Architecture guard hooks** → `hooks-catalog.md` "Architecture Guards"
