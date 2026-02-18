---
name: claude-nano-banana
description: This skill should be used when the user asks to "generate an image", "create a thumbnail", "make an icon", "draw a diagram", "edit this photo", "restore an old photo", "create a pattern", "make a banner", or mentions image generation, visual assets, or the Gemini CLI nanobanana extension.
allowed-tools: Bash(gemini:*)
version: 1.0.0
---

# Nano Banana - Image Generation via Gemini CLI

Generate and edit professional images using the Gemini CLI's nanobanana extension. Supports text-to-image generation, photo editing, icon creation, diagrams, patterns, and sequential storytelling.

## When to Use

- Image, graphic, illustration, or visual asset generation
- Thumbnail, featured image, or banner creation
- Icon, diagram, or pattern generation
- Photo editing, modification, or restoration

## When NOT to Use

- **Text-based diagrams** (Mermaid, PlantUML) → Use `mermaid-diagrams` skill
- **Architecture documentation** (C4, system context) → Use `c4-architecture` skill
- **UI component design** (Figma, CSS) → Use `figma-design-toolkit` or `frontend-design` skill

## Prerequisites

Verify before first use:

```bash
gemini extensions list | grep nanobanana
```

If missing, install:

```bash
gemini extensions install https://github.com/gemini-cli-extensions/nanobanana
```

Verify API key:

```bash
[ -n "$GEMINI_API_KEY" ] && echo "API key configured" || echo "Missing GEMINI_API_KEY"
```

## Workflow

1. **Verify prerequisites** - Ensure Gemini CLI and nanobanana extension are installed (see above)
2. **Select command** - Match the request to a command using the Quick Reference below
3. **Compose prompt** - Include style, mood, colors, composition; add "no text" if needed
4. **Execute** - Run via `gemini --yolo "/command 'prompt' [options]"`
5. **Present** - List `./nanobanana-output/` contents and show generated files
6. **Iterate** - Refine based on feedback (adjust prompt, use `/edit`, add `--count=3`)

## Quick Reference

| User Request | Command | Use Case |
|--------------|---------|----------|
| "make me a blog header" | `/generate` | Text-to-image generation |
| "create an app icon" | `/icon` | App icons, favicons, UI elements |
| "draw a flowchart of..." | `/diagram` | Flowcharts, architecture diagrams |
| "fix this old photo" | `/restore` | Repair damaged photos |
| "remove the background" | `/edit` | Modify existing images |
| "create a repeating texture" | `/pattern` | Seamless textures and patterns |
| "make a comic strip" | `/story` | Sequential/narrative images |
| "describe what to generate" | `/nanobanana` | Natural language interface |

> Always include the `--yolo` flag to auto-approve tool actions.

## Command Syntax

```bash
gemini --yolo "/generate 'prompt' [options]"
gemini --yolo "/edit file.png 'instruction'"
gemini --yolo "/restore old_photo.jpg 'fix scratches'"
gemini --yolo "/icon 'description' --sizes='64,128,256,512' --type='app-icon'"
gemini --yolo "/diagram 'description' --type='flowchart' --style='modern'"
gemini --yolo "/pattern 'description'"
gemini --yolo "/story 'description'"
```

## Common Options

| Option | Description |
|--------|-------------|
| `--yolo` | **Required.** Auto-approve all tool actions |
| `--count=N` | Generate N variations (1-8) |
| `--preview` | Auto-open generated images |
| `--styles="style1,style2"` | Apply artistic styles |
| `--format={grid,separate}` | Output arrangement |
| `--aspect=W:H` | Aspect ratio (e.g., `16:9`, `9:16`, `1:1`) |

## Common Sizes

| Use Case | Dimensions | Flag |
|----------|------------|------|
| YouTube thumbnail | 1280x720 | `--aspect=16:9` |
| Blog featured image | 1200x630 | Social preview friendly |
| Square social | 1080x1080 | Instagram, LinkedIn |
| Twitter/X header | 1500x500 | Wide banner |
| Vertical story | 1080x1920 | `--aspect=9:16` |

## Model Selection

Default: `gemini-2.5-flash-image` (~$0.04/image)

Upgrade for higher quality (4K, better reasoning):

```bash
export NANOBANANA_MODEL=gemini-3-pro-image-preview
```

## Output and Presentation

All generated images save to `./nanobanana-output/` in the current directory.

After generation:
1. List contents of `./nanobanana-output/` to find generated files
2. Present the most recent generated image(s)
3. Offer to regenerate with variations if needed

## Iteration Patterns

| User Says | Action |
|-----------|--------|
| "try again" / "give me options" | Regenerate with `--count=3` |
| "make it more [adjective]" | Adjust prompt descriptors and regenerate |
| "edit this one" | Use `/edit nanobanana-output/filename.png 'adjustment'` |
| "different style" | Add `--styles="requested_style"` |

## Prompt Tips

1. **Be specific** - Include style, mood, colors, composition details
2. **Add "no text"** - Prevent unwanted text rendered in the image
3. **Reference styles** - "editorial photography", "flat illustration", "3D render", "watercolor"
4. **Specify aspect** - "wide banner", "square thumbnail", "vertical story"

## Anti-Patterns

| ❌ Avoid | ✅ Instead |
|----------|-----------|
| Vague prompts ("make an image") | Specific prompts with style, mood, composition |
| Omitting `--yolo` flag | Always include `--yolo` to prevent interactive prompts |
| Generating without size context | Specify dimensions or aspect ratio for the target use case |
| Single attempt for hero images | Use `--count=3` and present all variants for selection |
| Editing without showing original | Present the original image before applying edits |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `GEMINI_API_KEY` not set | `export GEMINI_API_KEY="<api-key>"` |
| Extension not found | Run install command from Prerequisites |
| Quota exceeded | Wait for reset or switch to flash model |
| Image generation failed | Check prompt for policy violations, simplify request |
| Output directory missing | Created automatically on first run |
