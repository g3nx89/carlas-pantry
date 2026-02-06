# Figma API Quick Reference

> Project-specific API patterns and troubleshooting for figma-design-toolkit scripts.

## Authentication Setup

```bash
# Set Figma access token (required for all scripts)
export FIGMA_ACCESS_TOKEN="your_token_here"

# Token generation: Figma → Settings → Account → Personal Access Tokens
```

## File Key Extraction

Extract from Figma URL: `https://www.figma.com/file/ABC123/File-Name`
- **File key**: `ABC123` (segment after `/file/`)
- **Node ID**: From URL param `?node-id=1:2` → use `1:2` format (replace `-` with `:`)

## Rate Limit Handling

| Endpoint Type | Limit | Recovery Strategy |
|---------------|-------|-------------------|
| General API | 1000/min | Exponential backoff |
| Image exports | 100/min | Batch requests, queue processing |

### Backoff Implementation

```python
import time

def exponential_backoff(attempt):
    delay = min(2 ** attempt, 60)  # Max 60 seconds
    time.sleep(delay)
```

## Common Error Resolution

| Error | Cause | Solution |
|-------|-------|----------|
| 401 Unauthorized | Invalid/expired token | Regenerate FIGMA_ACCESS_TOKEN |
| 403 Forbidden | No file access | Request file sharing from owner |
| 404 Not Found | Wrong file key | Verify URL and extract key correctly |
| 429 Rate Limited | Too many requests | Implement backoff, batch operations |
| Empty response | Node IDs incorrect | Use `:` format (e.g., `1:2` not `1-2`) |

## Script-Specific Tips

### figma_client.py

```bash
# Successful file fetch
python scripts/figma_client.py get-file "ABC123"

# Common issues:
# - "Error: No token" → Set FIGMA_ACCESS_TOKEN
# - "Error: File not found" → Check file key extraction
```

### export_manager.py

```bash
# Batch export with rate limit awareness
python scripts/export_manager.py export-frames "ABC123" --formats png,svg

# For large files (100+ frames):
# Use --batch-size 50 to avoid rate limits
```

### style_auditor.py

```bash
# Generate HTML report
python scripts/style_auditor.py audit-file "ABC123" --generate-html

# Output: audit_report.html with color/typography inconsistencies
```

## Troubleshooting Checklist

- [ ] FIGMA_ACCESS_TOKEN environment variable set?
- [ ] Token has read access to target file?
- [ ] File key extracted correctly (not full URL)?
- [ ] Node IDs use `:` separator (not `-`)?
- [ ] Rate limits not exceeded?

## Resources

- [Figma REST API Reference](https://www.figma.com/developers/api)
- [Generate Access Token](https://www.figma.com/developers/api#access-tokens)
