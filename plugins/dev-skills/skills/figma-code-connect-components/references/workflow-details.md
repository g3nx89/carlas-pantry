# Code Connect Workflow Details

Detailed workflow steps, examples, and troubleshooting for connecting Figma components to code.

## Step-by-Step Workflow

### Step 1: Get Node ID and Extract Metadata

#### Option A: Parse from Figma URL

When the user provides a Figma URL with file key and node ID, first run `get_metadata` to fetch the node structure and identify all Figma components.

**IMPORTANT:** When extracting the node ID from a Figma URL, convert the format:

- URL format uses hyphens: `node-id=1-2`
- Tool expects colons: `nodeId=1:2`

**Parse the Figma URL:**

- URL format: `https://figma.com/design/:fileKey/:fileName?node-id=1-2`
- Extract file key: `:fileKey` (segment after `/design/`)
- Extract node ID: `1-2` from URL, then convert to `1:2` for the tool

**Note:** When using the local desktop MCP (`figma-desktop`), `fileKey` is not passed as a parameter. The server automatically uses the currently open file, so only `nodeId` is needed.

#### Option B: Use Current Selection (figma-desktop MCP only)

When using the `figma-desktop` MCP and the user has NOT provided a URL, the tools automatically use the currently selected node from the open Figma file in the desktop app.

**Note:** Selection-based prompting only works with the `figma-desktop` MCP server. The remote server requires a link to a frame or layer. The user must have the Figma desktop app open with a node selected.

### Step 2: Check Existing Code Connect Mappings

For each Figma component identified (nodes with type `<symbol>`), check if it's already code connected using `get_code_connect_map`.

```
get_code_connect_map(fileKey=":fileKey", nodeId="1:2")
```

**If already connected:** Skip to the next component, inform the user.
**If not connected:** Proceed to Step 3.

### Step 3: Get Design Context for Un-Connected Components

For components not yet code connected, run `get_design_context`:

```
get_design_context(fileKey=":fileKey", nodeId="1:2")
```

Returns:
- Component structure and hierarchy
- Layout properties and styling
- Text content and variants
- Design properties that map to code props

### Step 4: Scan Codebase for Matching Component

**What to look for:**
- Component names matching the Figma component name
- Component structure aligning with Figma hierarchy
- Props corresponding to Figma properties (variants, text, styles)
- Files in typical component directories (`src/components/`, `components/`, `ui/`)

**Search strategy:**
1. Search for component files with matching names
2. Read candidate files to check structure and props
3. Compare code component's props with Figma design properties
4. Detect programming language (TypeScript, JavaScript) and framework (React, Vue, etc.)
5. Identify best match based on structural similarity

### Step 5: Offer Code Connect Mapping

Present findings to the user:
- Which code component matches the Figma component
- File path and component name
- Language and framework detected

**If no exact match found:**
- Show the 2 closest candidates
- Explain differences
- Ask user to confirm or provide correct path

### Step 6: Create the Code Connect Mapping

Run `add_code_connect_map`:

```
add_code_connect_map(
  nodeId="1:2",
  source="src/components/Button.tsx",
  componentName="Button",
  clientLanguages="typescript,javascript",
  clientFrameworks="react"
)
```

**Key parameters:**
- `nodeId`: Figma node ID (colon format: `1:2`)
- `source`: Path to code component file (relative to project root)
- `componentName`: Name of the component to connect
- `clientLanguages`: Comma-separated list (e.g., "typescript,javascript")
- `clientFrameworks`: Framework used (e.g., "react", "vue", "svelte")
- `label`: Valid values include:
  - Web: 'React', 'Web Components', 'Vue', 'Svelte', 'Storybook', 'Javascript'
  - iOS: 'Swift UIKit', 'Objective-C UIKit', 'SwiftUI'
  - Android: 'Compose', 'Java', 'Kotlin', 'Android XML Layout'
  - Cross-platform: 'Flutter'

### Step 7: Repeat for All Un-Connected Components

After connecting one component, return to Step 2 for remaining components.

Provide a summary:
- Total components found
- Components successfully connected
- Components skipped (already connected)
- Components that could not be connected (with reasons)

---

## Examples

### Example 1: Connecting a Button Component

User: "Connect this Figma button: https://figma.com/design/kL9xQn2VwM8pYrTb4ZcHjF/DesignSystem?node-id=42-15"

**Actions:**
1. Parse URL: fileKey=`kL9xQn2VwM8pYrTb4ZcHjF`, nodeId=`42-15` → convert to `42:15`
2. Run `get_metadata(fileKey="...", nodeId="42:15")` to get node structure
3. Metadata shows: Node type `<symbol>`, name "Button"
4. Run `get_code_connect_map(...)` - No existing mapping
5. Run `get_design_context(...)` - Button with `variant` and `size` properties
6. Search codebase → Find `src/components/Button.tsx`
7. Confirm props match
8. Offer mapping → User confirms
9. Run `add_code_connect_map(nodeId="42:15", source="src/components/Button.tsx", componentName="Button", clientLanguages="typescript,javascript", clientFrameworks="react")`

**Result:** Figma button connected to code Button component.

### Example 2: Multiple Candidates

User: "Connect this card: https://figma.com/design/pR8mNv5KqXzGwY2JtCfL4D/Components?node-id=10-50"

**Actions:**
1-6. Same as above
7. Search finds two candidates:
   - `src/components/Card.tsx` (basic card)
   - `src/components/ProductCard.tsx` (card with image and CTA)
8. Present both to user with differences
9. User selects "ProductCard.tsx"
10. Run `add_code_connect_map(...)` with ProductCard

### Example 3: Component Not Found

User: "Connect this icon: https://figma.com/design/8yJDMeWDyBz71EnMOSuUiw/Icons?node-id=5-20"

**Actions:**
1-6. Same as above
7. Search finds no CheckIcon component
8. Find `src/icons/` directory with other icons
9. Report: "No CheckIcon found, but found icons directory. Would you like to:
   - Create a new CheckIcon.tsx first
   - Connect to a different icon
   - Provide the path if it exists elsewhere"
10. User provides path → Complete mapping

---

## Troubleshooting

### "Failed to map node to Code Connect"

**Cause:** Component not published to team library. Code Connect only works with published components.

**Solution:**
1. In Figma, select the component
2. Right-click → "Publish to library"
3. Retry the mapping

### No matching component found

**Cause:** Codebase search didn't find matching name/structure.

**Solution:** Ask user if component exists under different name or location. May need to create component first.

### Creation fails with "component not found"

**Cause:** Incorrect source path or componentName doesn't match export.

**Solution:** Verify path is correct relative to project root. Check component is exported with exact componentName.

### Wrong language/framework detected

**Cause:** clientLanguages or clientFrameworks don't match implementation.

**Solution:** Inspect file to verify language/framework. For TypeScript React: `clientLanguages="typescript,javascript"`, `clientFrameworks="react"`.

### URL errors

**Cause:** Figma URL format incorrect or missing `node-id` parameter.

**Solution:** URL must be: `https://figma.com/design/:fileKey/:fileName?node-id=1-2`. Convert `1-2` to `1:2` for tools.
