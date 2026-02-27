# GUI Walkthrough Instructions

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)

Step-by-step GUI instructions for Figma Desktop operations that have no MCP tool or CLI equivalent. The coding agent should read this file when a connection or setup issue requires the user to interact with the Figma Desktop application directly.

> **Cross-references:** For connection error recovery, see `anti-patterns.md`. For tool selection and workflows, see `tool-playbook.md`.

## When to Use This File

Read this file when a task requires one of the following GUI-only operations. Relay the numbered steps directly to the user — these operations cannot be automated via figma-console-mcp tools.

---

## Initial Setup: Installing the Desktop Bridge Plugin

**Prerequisite**: Figma Desktop app installed and running.

1. Open any Figma file in the Desktop app
2. Go to **Plugins** menu (top menu bar)
3. Select **Development** > **Import plugin from manifest...**
4. Navigate to the `figma-console-mcp` package directory and select the `manifest.json` file
5. The Desktop Bridge Plugin appears in the Development plugins list

**Verification**: After import, call `figma_get_status` — transport should show connected.

---

## Per-Session: Running the Desktop Bridge Plugin

**Prerequisite**: Desktop Bridge Plugin installed (see above), target file open in Figma Desktop.

1. Open the target Figma file
2. Go to **Plugins** > **Development**
3. Click **Desktop Bridge** to run the plugin
4. A small plugin UI window appears — keep it open (minimizing is OK)

**Verification**: Call `figma_get_status` — transport should show `"connected"` on WebSocket port 9223-9232.

**Note**: The plugin runs per-file. When switching to a different file, run the plugin again in that file. Multi-instance support (v1.10.0+) allows running the plugin in multiple files simultaneously on ports 9223-9232.

---

## Post-Update: Re-importing the Desktop Bridge Plugin

After updating the `figma-console-mcp` npm package, re-import the plugin to pick up changes.

1. Close any running instance of the Desktop Bridge Plugin
2. Go to **Plugins** > **Development** > **Import plugin from manifest...**
3. Re-select the `manifest.json` from the updated package directory
4. Run the plugin again in the target file (see Per-Session section above)

---

## Alternative Transport: Launching Figma with CDP

**When needed**: WebSocket transport (Desktop Bridge) is unavailable or debugging requires CDP access.

**macOS:**
```bash
/Applications/Figma.app/Contents/MacOS/Figma --remote-debugging-port=9222
```

**Windows:**
```cmd
"C:\Users\<user>\AppData\Local\Figma\Figma.exe" --remote-debugging-port=9222
```

**Linux:**
```bash
figma --remote-debugging-port=9222
```

**Important**: Quit Figma completely before relaunching with the flag. Both CDP (port 9222) and WebSocket (Desktop Bridge, ports 9223-9232) transports can be active simultaneously.

---

## Cache Refresh: Closing and Reopening the Plugin

**When needed**: `figma_get_variables` returns empty or stale data.

1. In the Figma file, locate the Desktop Bridge Plugin UI window
2. Close it (click the X or press Escape)
3. Go to **Plugins** > **Development** > **Desktop Bridge** to reopen
4. Wait 2-3 seconds for the cache to repopulate
5. Retry the variable query

---

## Selecting Nodes for Audit or Inspection

**When needed**: Before calling `figma_get_selection` or `figma_get_file_for_plugin({ selectionOnly: true })`.

1. In the Figma canvas, click on the target frame, component, or page section
2. To select multiple nodes, hold **Shift** and click additional nodes
3. To select a deeply nested node, double-click to drill into groups/frames
4. Confirm selection in the right panel (Properties panel shows the selected node's name and type)

**Partial MCP alternative**: When the target node ID is already known (e.g., returned from a previous `figma_execute` call), selection can be set programmatically instead:
```javascript
const node = await figma.getNodeByIdAsync("1:23")
figma.currentPage.selection = [node]
```

---

## Opening the Correct File

**When needed**: `figma_list_open_files` shows the target file is not connected.

1. In Figma Desktop, use **File** > **Open** or the Recent Files list to open the target file
2. Run the Desktop Bridge Plugin in the newly opened file (see Per-Session section above)
3. Call `figma_get_status` to verify connection to the correct file

**Note**: `figma_navigate` can open a file by URL in CDP transport mode. In WebSocket-only mode, it returns file info without navigating — guide the user to open the file manually.

---

## Enabling MCP Apps

**When needed**: Token Browser or Design System Dashboard features are required.

1. Locate the MCP server configuration (Claude Desktop `claude_desktop_config.json`, Cursor settings, etc.)
2. Add the environment variable `ENABLE_MCP_APPS=true` to the figma-console-mcp server entry
3. Restart the MCP client (Claude Desktop, Cursor, etc.) to apply the change
4. Verify by calling `figma_browse_tokens` or triggering the Design System Dashboard

**Example configuration** (Claude Desktop):
```json
{
  "mcpServers": {
    "figma-console": {
      "command": "npx",
      "args": ["-y", "figma-console-mcp"],
      "env": {
        "ENABLE_MCP_APPS": "true"
      }
    }
  }
}
```
