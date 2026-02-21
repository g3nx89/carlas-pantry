# Figma Capture Protocol

> Migrated from `specify-figma-capture` sub-skill (v1.0.0) on 2026-02-11.
> Loaded inline by `stage-1-setup.md` Step 1.9 when Figma capture is enabled.

### Expected Context

| Variable | Source | Description |
|----------|--------|-------------|
| `FEATURE_DIR` | Stage 1 (Step 1.7) | Path to feature directory (e.g., `1-add-login`) |
| `ARGUMENTS` | Orchestrator | Original command arguments (for `--figma`/`--no-figma` flag detection) |

---

## Connection Selection

### If called with --figma flag

Ask connection type only:

```json
{
  "questions": [{
    "question": "Which Figma connection do you want to use?",
    "header": "Figma",
    "multiSelect": false,
    "options": [
      {
        "label": "Desktop (Recommended)",
        "description": "Requires Figma Desktop app running with frames selected. Best for iterative design work."
      },
      {
        "label": "Online (URL-based)",
        "description": "Provide Figma URL with node-id. Works without local Figma app."
      }
    ]
  }]
}
```

### If called without flags

Ask full integration decision:

```json
{
  "questions": [{
    "question": "Would you like to integrate Figma designs into this specification?",
    "header": "Figma",
    "multiSelect": false,
    "options": [
      {
        "label": "Yes - Desktop",
        "description": "Capture from Figma Desktop app. Requires app running with frames selected."
      },
      {
        "label": "Yes - Online (URL)",
        "description": "Provide a Figma URL with node-id. Works without local Figma app."
      },
      {
        "label": "No - Skip Figma",
        "description": "Continue without design mocks. You can add them later with --figma flag."
      }
    ]
  }]
}
```

---

## Capture Mode Selection

After connection is determined:

```json
{
  "questions": [{
    "question": "How should Figma screens be captured?",
    "header": "Capture",
    "multiSelect": false,
    "options": [
      {
        "label": "Selected Frames Only (Recommended)",
        "description": "Capture only the frames you've explicitly selected. Best for focused features."
      },
      {
        "label": "Entire Page Hierarchy",
        "description": "Capture all frames on the current page. Use for comprehensive feature specs."
      }
    ]
  }]
}
```

---

## Error Handling Matrix

### Desktop Connection Errors

| Error | Detection | Recovery Message |
|-------|-----------|------------------|
| Figma Desktop not running | Connection error | "Start Figma Desktop, select frames, then retry" |
| No selection in Figma | `get_metadata` returns empty | "Select at least one frame in Figma before running" |
| Tool timeout (>30s) | No response | "Figma may be unresponsive. Try: (1) Restart Figma, (2) Select simpler frame" |
| Invalid nodeId format | Validation fails | "Ensure you're selecting a valid Figma frame (not a component instance)" |

### Online Connection Errors

| Error | Detection | Recovery Message |
|-------|-----------|------------------|
| Invalid URL format | URL parsing fails | "Provide a valid Figma URL (e.g., figma.com/design/ABC123/File?node-id=1:2)" |
| Missing node-id | URL has no node-id param | "Add ?node-id=X:Y to your Figma URL" |
| Access denied | 403 response | "Ensure the Figma file is accessible (check sharing settings)" |
| File not found | 404 response | "Verify the Figma URL is correct" |

### Error Recovery Dialog

```json
{
  "questions": [{
    "question": "Figma capture failed: {ERROR_MESSAGE}. How would you like to proceed?",
    "header": "Error",
    "multiSelect": false,
    "options": [
      {
        "label": "Retry Figma Capture",
        "description": "Try again after fixing the issue"
      },
      {
        "label": "Switch Connection Type",
        "description": "Try the other Figma connection method (desktop <-> online)"
      },
      {
        "label": "Skip Figma Integration",
        "description": "Continue without design mocks (you can add them later)"
      }
    ]
  }]
}
```

---

## Capture Process (ReAct Pattern)

### Desktop Path

1. **REASON**: What's selected in Figma Desktop?

2. **ACT**: `mcp__figma-desktop__get_metadata()` to get page structure

3. **OBSERVE**: Review returned frame list and hierarchy

4. **For each frame based on capture mode:**
   - **ACT**: `mcp__figma-desktop__get_screenshot(nodeId)` -> save to `{FEATURE_DIR}/figma/`
   - **ACT**: `mcp__figma-desktop__get_design_context(nodeId)` -> extract elements

### Online Path

1. **REASON**: Parse user-provided Figma URL

2. **ACT**: Extract `fileKey` and `nodeId` from URL
   - File key: `figma.com/design/<fileKey>/...` or `figma.com/file/<fileKey>/...`
   - Node ID: `?node-id=1-2` -> convert to `"1:2"` format

3. **OBSERVE**: Validate URL components

4. **For each frame based on capture mode:**
   - **ACT**: `mcp__figma__get_screenshot(fileKey, nodeId)` -> save to `{FEATURE_DIR}/figma/`
   - **ACT**: `mcp__figma__get_design_context(fileKey, nodeId)` -> extract elements

---

## Screenshot Naming Convention

**Format:** `{FEATURE_DIR}/figma/{sanitized_nodeId}-{sanitized_screen_name}.png`

### Sanitization Rules

| Component | Rule | Example |
|-----------|------|---------|
| nodeId | Replace ":" with "-" | "1:234" -> "1-234" |
| screen_name | Lowercase | "Login Screen" -> "login screen" |
| screen_name | Replace spaces with "-" | "login screen" -> "login-screen" |
| screen_name | Remove special characters | "Home / Dashboard" -> "home-dashboard" |
| screen_name | Max 50 chars | Truncate if longer |

### Examples

| Figma Node | Screen Name | Output File |
|------------|-------------|-------------|
| 1:234 | "Login Screen" | `figma/1-234-login-screen.png` |
| 5:678 | "Home / Dashboard" | `figma/5-678-home-dashboard.png` |
| 12:90 | "Very Long Screen Name That Exceeds Limit" | `figma/12-90-very-long-screen-name-that-exceeds-.png` |

### Directory Structure

```
specs/{feature-id}/
├── figma/
│   ├── 1-234-login-screen.png
│   ├── 1-235-registration-screen.png
│   └── 1-236-home-screen.png
└── figma_context.md (references these files)
```

---

## Output Generation

### Create figma_context.md

```bash
# Create figma directory
mkdir -p {FEATURE_DIR}/figma

# Copy template
cp $CLAUDE_PLUGIN_ROOT/templates/figma_context-template.md {FEATURE_DIR}/figma_context.md
```

### Populate figma_context.md

Include for each captured screen:
- Screen name and nodeId
- Screenshot path (relative)
- Extracted UI elements summary
- Component hierarchy
- Any @FigmaConnect mappings found

---

## State Checkpoint

**IMMEDIATELY** after user decisions, update STATE_FILE:

```yaml
user_decisions:
  figma_enabled: true|false
  figma_connection: "{desktop|online}"
  figma_capture_mode: "{selected|page}"

phases:
  figma_capture:
    status: completed
    timestamp: "{now}"
    screens_captured: {count}
    context_file: "{FIGMA_CONTEXT_FILE}"
```
