---
name: narrate
description: "[DEPRECATED — use /handoff instead] Transform Figma mockups into a detailed UX/interaction narrative document"
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(mkdir:*)", "Bash(rm:*)", "Task", "mcp__figma-desktop__get_metadata", "mcp__figma-desktop__get_screenshot", "mcp__figma-desktop__get_design_context", "mcp__pal__consensus"]
---

> **DEPRECATED:** This command has been superseded by `/handoff`, which produces more compact output (HANDOFF-SUPPLEMENT.md) and prepares the Figma file directly for coding agent consumption. Use `/handoff` instead.
>
> If you want to proceed with the legacy design-narration workflow, confirm by saying "continue with /narrate".

Load and follow the skill: `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/SKILL.md`

## User Input

```text
$ARGUMENTS
```
