# listmodels - Model Discovery

## Purpose

List all configured AI models with their aliases and capabilities.

## When to Use

- At session start to confirm available models
- After configuration changes
- To verify API key setup
- When unsure which models are configured

## Parameters

None required.

## Example Usage

```
listmodels()
```

## Output Structure

```
Available Models:
- auto (intelligent routing)
- pro → gemini-3.0-pro
- flash → gemini-3.0-flash
- o3 → openai-o3
- o4-mini → openai-o4-mini
- gpt5 → gpt-5.2-pro
- gpt5-codex → gpt-5.2-codex
...
```

## Model Aliases

| Alias | Maps To | Best For |
|-------|---------|----------|
| `auto` | Intelligent routing | Most tasks (let Claude choose) |
| `pro` | gemini-3.0-pro | Complex analysis, large context |
| `flash` | gemini-3.0-flash | Fast iterations, lower cost |
| `o3` | openai-o3 | Maximum reasoning depth |
| `o4-mini` | openai-o4-mini | Quick reasoning, lower cost |
| `gpt5` | gpt-5.2-pro | General tasks |
| `gpt5-codex` | gpt-5.2-codex | Code generation |

## Best Practices

1. **Run at session start** to confirm available models
2. **Verify after config changes** to ensure changes took effect
3. **Check when tool fails** - might be missing API key

## Common Issues

| Symptom | Likely Cause |
|---------|--------------|
| Model not listed | API key not configured |
| Fewer models than expected | Some providers not set up |
| Empty list | No API keys configured |
