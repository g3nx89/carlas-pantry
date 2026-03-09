---
description: "Start autonomous implementation via Ralph Loop"
argument-hint: "FEATURE_DIR [--profile quick|standard|thorough]"
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-implement.sh:*)
  - Read
  - Glob
  - Skill
---

# Ralph Implement Command

Execute the entire implementation plan autonomously via a Ralph loop. The implement skill's
checkpoint-based resume mechanism ensures progress is preserved across loop iterations.

## Procedure

1. **Run the setup script** to validate preconditions and calculate the iteration budget:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-implement.sh" $ARGUMENTS
```

2. **Read the generated prompt** from the setup script output. The script outputs the
   calculated max iterations and the prompt text ready for ralph-loop.

3. **Invoke the Ralph loop** with the generated prompt:
   Use `/ralph-loop:ralph-loop` passing the generated prompt and `--max-iterations` and
   `--completion-promise` from the script output.

## Requirements

- The `ralph-loop` plugin must be installed and enabled
- `tasks.md` and `plan.md` must exist in the feature directory
- For fully autonomous execution, set `ralph.default_profile` in config (default: "standard")
  - Profile controls all feature flags, autonomy is always "auto" in ralph mode
