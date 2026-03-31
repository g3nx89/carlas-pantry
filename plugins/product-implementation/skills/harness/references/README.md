# Harness Skill — Reference Index

| File | Lines | Size | Purpose |
|------|-------|------|---------|
| `harness-components.md` | ~515 | 18K | Templates for all 6 harness categories + project adaptation |
| `evaluation-loop.md` | ~467 | 18K | Eval loop: UAT, judging, feedback, stop gate, project adaptations |
| `feature-list-schema.md` | ~108 | 4K | JSON schema, tasks.md→JSON conversion, immutability rules |
| `hooks-catalog.md` | ~168 | 5K | Hook catalog with events, use cases, remediation pattern |
| `cli-agents.md` | ~513 | 19K | External CLI agent dispatch: Codex Plugin, review, UAT, stop gate |

## Cross-References

- `harness-components.md` Section 2c references `evaluation-loop.md` Section 4a for evaluator prompt template
- `harness-components.md` Section 2c references `evaluation-loop.md` Section 8 for project adaptations
- `harness-components.md` Section 2d has the unified session-startup template (single source of truth)
- `harness-components.md` Section 2f has the unified sprint contract template (single source of truth)
- `harness-components.md` Section 2f references `evaluation-loop.md` Section 3 for negotiation protocol
- `evaluation-loop.md` Section 3 references `harness-components.md` Section 2f for sprint contract template
- `evaluation-loop.md` Section 4c references `cli-agents.md` Section 3 for CLI evaluator dispatch
- `cli-agents.md` Section 3 references `evaluation-loop.md` Section 4c for native vs CLI comparison
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
- **Session startup checklist** → `harness-components.md` Section 2d (not cli-agents.md or evaluation-loop.md)
- **Evaluator prompt template** → `evaluation-loop.md` Section 4a (not harness-components.md)
