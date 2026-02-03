---
name: figma-design-toolkit
description: This skill should be used when the user asks to "export Figma assets", "audit design system", "check accessibility", "extract design tokens", "generate CSS variables", "create client package", "analyze Figma file", or needs bulk export and analysis capabilities via Figma REST API. Complementary to MCP-based figma skills.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Figma Design Toolkit

Professional-grade Figma REST API integration for bulk export, design system analysis, and accessibility auditing.

## Content Map

| File | When to Read |
|------|--------------|
| **[references/api-reference.md](references/api-reference.md)** | API endpoints, authentication, rate limits |
| **[references/export-formats.md](references/export-formats.md)** | Format specifications, platform requirements |
| **[references/design-patterns.md](references/design-patterns.md)** | Component architecture, layout patterns |
| **[references/accessibility-guidelines.md](references/accessibility-guidelines.md)** | WCAG compliance, testing methods |

## When to Use This Skill

Use this **REST API skill** for:
- Bulk asset export (multiple formats/scales)
- Design system auditing and analysis
- Accessibility compliance checking
- Design token extraction
- Client deliverable packages

Use **MCP skills** (`figma-implement-design`) for:
- Real-time design-to-code implementation
- Interactive design context fetching
- Screenshot-based validation

## Prerequisites

```bash
# Set Figma access token
export FIGMA_ACCESS_TOKEN="your-token-here"

# Install dependencies
pip install -r scripts/requirements.txt
```

Generate token: Figma → Settings → Account → Personal Access Tokens

## Quick Workflow

| Script | Purpose | Command |
|--------|---------|---------|
| `figma_client.py` | API wrapper | `python scripts/figma_client.py get-file "file-key"` |
| `export_manager.py` | Batch export | `python scripts/export_manager.py export-frames "file-key"` |
| `style_auditor.py` | Design audit | `python scripts/style_auditor.py audit-file "file-key"` |
| `accessibility_checker.py` | WCAG check | `python scripts/accessibility_checker.py "file-key"` |

## Detailed Workflows

### 1. Bulk Asset Export

```bash
# Export all frames as PNG and SVG
python scripts/export_manager.py export-frames "file-key" --formats png,svg

# Export with multiple scales for mobile
python scripts/export_manager.py export-components "file-key" --scales 1.0,2.0,3.0

# Export specific nodes
python scripts/export_manager.py export-nodes "file-key" "node-id-1,node-id-2"
```

### 2. Design Token Extraction

```bash
# Export as CSS custom properties
python scripts/export_manager.py export-tokens "file-key" --token-format css

# Export as SCSS variables
python scripts/export_manager.py export-tokens "file-key" --token-format scss

# Export as JavaScript module
python scripts/export_manager.py export-tokens "file-key" --token-format js
```

### 3. Design System Analysis

```bash
# Extract all colors
python scripts/figma_client.py extract-colors "file-key"

# Extract typography styles
python scripts/figma_client.py extract-typography "file-key"

# Audit style consistency
python scripts/style_auditor.py audit-file "file-key" --generate-html
```

### 4. Client Package Creation

```bash
# Complete deliverable with all assets + documentation
python scripts/export_manager.py client-package "file-key" --package-name "project-assets"
```

## File Key Extraction

From Figma URL: `https://www.figma.com/file/ABC123/File-Name`
- File key: `ABC123` (segment after `/file/`)

## Export Format Guide

| Format | Best For | Transparency | Scalable |
|--------|----------|--------------|----------|
| **PNG** | UI elements, icons | Yes | No |
| **SVG** | Icons, simple graphics | Yes | Yes |
| **JPG** | Photos, complex images | No | No |
| **PDF** | Print, documentation | Partial | Yes |

## Platform-Specific Scales

| Platform | Scales Needed |
|----------|---------------|
| **iOS** | 1x, 2x, 3x |
| **Android** | 1x (mdpi), 1.5x (hdpi), 2x (xhdpi), 3x (xxhdpi) |
| **Web** | 1x, 2x (Retina) |

## Limitations

| Can Do | Cannot Do |
|--------|-----------|
| Extract data, styles, components | Modify existing files |
| Export assets in multiple formats | Create new designs |
| Analyze and audit files | Batch update files |
| Generate reports | Real-time collaboration |

This is **read-only** API access. For file modifications, use Figma Plugin API.

## Decision Checklist

- [ ] Set `FIGMA_ACCESS_TOKEN` environment variable?
- [ ] Identified file key from Figma URL?
- [ ] Chosen appropriate export formats?
- [ ] Selected correct scales for target platform?
- [ ] Defined output directory structure?

## Anti-Patterns

| DON'T | DO |
|-------|-----|
| Hardcode access tokens | Use environment variables |
| Export at maximum scale always | Choose appropriate scale for use case |
| Ignore rate limits | Implement backoff for 429 errors |
| Export all formats always | Select formats based on need |

## Related Figma Skills

| Need | Skill |
|------|-------|
| Implement designs | `figma-implement-design` |
| Connect Figma to code | `figma-code-connect-components` |
| Set up design rules | `figma-create-design-system-rules` |

## Resources

- [Figma REST API Documentation](https://www.figma.com/developers/api)
- [Figma Plugin API](https://www.figma.com/plugin-docs/)
