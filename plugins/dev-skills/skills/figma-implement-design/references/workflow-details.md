# Implement Design Workflow Details

Detailed workflow, examples, and troubleshooting for translating Figma designs to production code.

## URL Parsing

```
URL: https://figma.com/design/:fileKey/:fileName?node-id=1-2
                              ^^^^^^^^                 ^^^
                              fileKey                  nodeId
```

**Example:**
- URL: `https://figma.com/design/kL9xQn2VwM8pYrTb4ZcHjF/DesignSystem?node-id=42-15`
- File key: `kL9xQn2VwM8pYrTb4ZcHjF`
- Node ID: `42-15`

**Note:** `figma-desktop` MCP doesn't need fileKey - uses currently open file with selected node.

---

## Detailed Workflow

### Step 1: Get Node ID

**Option A: Parse from URL**
Extract fileKey and nodeId from the Figma URL.

**Option B: Desktop Selection**
When using `figma-desktop` MCP without URL, tools use currently selected node in Figma desktop app.

### Step 2: Fetch Design Context

```
get_design_context(fileKey=":fileKey", nodeId="1-2")
```

Returns:
- Layout properties (Auto Layout, constraints, sizing)
- Typography specifications
- Color values and design tokens
- Component structure and variants
- Spacing and padding values

**If response too large or truncated:**
1. Run `get_metadata(fileKey, nodeId)` to get high-level node map
2. Identify specific child nodes from metadata
3. Fetch individual child nodes with `get_design_context`

### Step 3: Capture Visual Reference

```
get_screenshot(fileKey=":fileKey", nodeId="1-2")
```

This screenshot is the source of truth for visual validation. Keep it accessible throughout implementation.

### Step 4: Download Required Assets

Download images, icons, SVGs returned by Figma MCP server.

**IMPORTANT Asset Rules:**
- If Figma returns `localhost` source for image/SVG, use it directly
- DO NOT import new icon packages - all assets come from Figma payload
- DO NOT create placeholders if localhost source provided
- Assets served through Figma MCP server's built-in assets endpoint

### Step 5: Translate to Project Conventions

**Key principles:**
- Treat Figma MCP output (typically React + Tailwind) as design representation, not final code
- Replace Tailwind utilities with project's preferred utilities or design tokens
- Reuse existing components (buttons, inputs, typography, icons) instead of duplicating
- Use project's color system, typography scale, and spacing tokens consistently
- Respect existing routing, state management, and data-fetch patterns

### Step 6: Achieve 1:1 Visual Parity

**Guidelines:**
- Prioritize Figma fidelity to match designs exactly
- Avoid hardcoded values - use design tokens where available
- When conflicts arise between design system tokens and Figma specs, prefer design system tokens but adjust spacing/sizes minimally
- Follow WCAG requirements for accessibility
- Add component documentation as needed

### Step 7: Validate Against Figma

**Validation checklist:**
- [ ] Layout matches (spacing, alignment, sizing)
- [ ] Typography matches (font, size, weight, line height)
- [ ] Colors match exactly
- [ ] Interactive states work as designed (hover, active, disabled)
- [ ] Responsive behavior follows Figma constraints
- [ ] Assets render correctly
- [ ] Accessibility standards met

---

## Implementation Rules

### Component Organization

- Place UI components in project's designated design system directory
- Follow project's component naming conventions
- Avoid inline styles unless truly necessary for dynamic values

### Design System Integration

- ALWAYS use components from project's design system when possible
- Map Figma design tokens to project design tokens
- When matching component exists, extend it rather than create new
- Document any new components added to design system

### Code Quality

- Avoid hardcoded values - extract to constants or design tokens
- Keep components composable and reusable
- Add TypeScript types for component props
- Include JSDoc comments for exported components

---

## Examples

### Example 1: Implementing a Button Component

User: "Implement this button: https://figma.com/design/kL9xQn2VwM8pYrTb4ZcHjF/DesignSystem?node-id=42-15"

**Actions:**
1. Parse URL: fileKey=`kL9xQn2VwM8pYrTb4ZcHjF`, nodeId=`42-15`
2. Run `get_design_context(...)` - Get button structure, variants, styling
3. Run `get_screenshot(...)` - Visual reference
4. Download button icons from assets endpoint
5. Check if project has existing button component
6. If yes, extend with new variant; if no, create using project conventions
7. Map Figma colors to project design tokens (`primary-500`, `primary-hover`)
8. Validate against screenshot (padding, border radius, typography)

**Result:** Button component matching Figma design, integrated with project design system.

### Example 2: Building a Dashboard Layout

User: "Build this dashboard: https://figma.com/design/pR8mNv5KqXzGwY2JtCfL4D/Dashboard?node-id=10-5"

**Actions:**
1. Parse URL: fileKey=`pR8mNv5KqXzGwY2JtCfL4D`, nodeId=`10-5`
2. Run `get_metadata(...)` - Understand page structure
3. Identify main sections (header, sidebar, content area, cards) and child node IDs
4. Run `get_design_context(...)` for each major section
5. Run `get_screenshot(...)` for full page
6. Download all assets (logos, icons, charts)
7. Build layout using project's layout primitives
8. Implement each section using existing components where possible
9. Validate responsive behavior against Figma constraints

**Result:** Complete dashboard matching Figma design with responsive layout.

### Example 3: Complex Card Component

User: "Implement this product card: https://figma.com/design/xyz/Cards?node-id=5-10"

**Actions:**
1. Parse URL, fetch design context and screenshot
2. Analyze card structure: image, title, price, CTA button, rating
3. Check existing components:
   - Image component? Use it
   - Button component? Use it
   - Rating component? Create if missing
4. Map spacing values to project's spacing scale
5. Ensure image uses proper aspect ratio from Figma
6. Handle loading and error states for image
7. Validate all variants (with/without discount, out of stock, etc.)

---

## Troubleshooting

### Figma output is truncated

**Cause:** Design too complex or too many nested layers.

**Solution:** Use `get_metadata` to get node structure, then fetch specific nodes individually with `get_design_context`.

### Design doesn't match after implementation

**Cause:** Visual discrepancies between implemented code and Figma.

**Solution:** Compare side-by-side with screenshot from Step 3. Check spacing, colors, and typography values in design context data.

### Assets not loading

**Cause:** Figma MCP server's assets endpoint not accessible or URLs modified.

**Solution:** Verify assets endpoint is accessible. Server serves assets at `localhost` URLs. Use directly without modification.

### Design token values differ from Figma

**Cause:** Project design tokens have different values than Figma specs.

**Solution:** Prefer project tokens for consistency, but adjust spacing/sizing to maintain visual fidelity.

### Interactive states don't match

**Cause:** Hover, focus, active states not matching Figma.

**Solution:**
1. Check if Figma has separate frames for each state
2. Fetch design context for each state variant
3. Implement all state styles explicitly
