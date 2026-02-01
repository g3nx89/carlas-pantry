# File Coordinator Protocol

## Purpose

Manage file-based communication between agents in the SADD workflow. This protocol ensures agents can write outputs that other agents can read, maintains consistent directory structure, and handles cleanup.

## When to Use

Use file coordinator when:
- Setting up SADD output directories
- Collecting outputs from multiple agents
- Cleaning up temporary files
- Validating agent outputs exist

## Directory Structure

```
{FEATURE_DIR}/
└── sadd/
    ├── advocates/                    # Stakeholder advocate outputs
    │   ├── advocate-user.md
    │   ├── advocate-business.md
    │   ├── advocate-ops.md
    │   └── advocate-security.md
    │
    ├── stakeholder-synthesis.md      # Merged advocate findings
    │
    ├── gates/                        # Gate evaluation outputs
    │   ├── gate-1-evaluation.md
    │   └── gate-2-evaluation.md
    │
    ├── questions/                    # Question discovery outputs
    │   ├── questions-ux.md
    │   ├── questions-business.md
    │   ├── questions-technical.md
    │   └── questions-synthesized.md
    │
    ├── debates/                      # Judge debate outputs
    │   ├── debate-Q001-risk.md
    │   ├── debate-Q001-value.md
    │   ├── debate-Q001-effort.md
    │   └── debate-Q001-round2.md     # If needed
    │
    └── pal-analysis/                 # Tier 2: PAL rejection analysis
        ├── pal-validity-analysis.md
        ├── pal-actionability-analysis.md
        └── pal-root-cause-analysis.md
```

## Actions

### Action: Setup

Create the SADD directory structure for a feature.

**Input:**
```yaml
action: "setup"
feature_dir: "/path/to/specs/001-feature"
```

**Process:**
```bash
mkdir -p {feature_dir}/sadd/advocates
mkdir -p {feature_dir}/sadd/gates
mkdir -p {feature_dir}/sadd/questions
mkdir -p {feature_dir}/sadd/debates
mkdir -p {feature_dir}/sadd/pal-analysis
```

**Output:**
```yaml
setup_result:
  success: true
  created_directories:
    - "{feature_dir}/sadd/"
    - "{feature_dir}/sadd/advocates/"
    - "{feature_dir}/sadd/gates/"
    - "{feature_dir}/sadd/questions/"
    - "{feature_dir}/sadd/debates/"
    - "{feature_dir}/sadd/pal-analysis/"
```

### Action: Collect

Gather all agent outputs matching a pattern.

**Input:**
```yaml
action: "collect"
feature_dir: "/path/to/specs/001-feature"
pattern: "advocates/advocate-*.md"
```

**Process:**
```typescript
// Find all matching files
const files = Glob(pattern: `${featureDir}/sadd/${pattern}`);

// Read and validate each file
const results = [];
for (const file of files) {
  const content = Read(file_path: file);
  results.push({
    path: file,
    exists: true,
    size_bytes: content.length,
    has_required_sections: validateSections(content)
  });
}
```

**Output:**
```yaml
collect_result:
  success: true
  pattern: "advocates/advocate-*.md"
  files_found: 4

  files:
    - path: "sadd/advocates/advocate-user.md"
      exists: true
      size_bytes: 4523
      valid: true

    - path: "sadd/advocates/advocate-business.md"
      exists: true
      size_bytes: 3891
      valid: true

    - path: "sadd/advocates/advocate-ops.md"
      exists: true
      size_bytes: 4102
      valid: true

    - path: "sadd/advocates/advocate-security.md"
      exists: true
      size_bytes: 5234
      valid: true
```

### Action: Validate

Check that expected outputs exist and are valid.

**Input:**
```yaml
action: "validate"
feature_dir: "/path/to/specs/001-feature"
expected_files:
  - path: "sadd/advocates/advocate-user.md"
    required_sections:
      - "## Summary"
      - "## Gaps Identified"

  - path: "sadd/advocates/advocate-business.md"
    required_sections:
      - "## Summary"
      - "## Gaps Identified"
```

**Process:**
```typescript
const results = [];
for (const expected of expectedFiles) {
  const fullPath = `${featureDir}/${expected.path}`;

  try {
    const content = Read(file_path: fullPath);
    const missingSections = [];

    for (const section of expected.required_sections) {
      if (!content.includes(section)) {
        missingSections.push(section);
      }
    }

    results.push({
      path: expected.path,
      exists: true,
      valid: missingSections.length === 0,
      missing_sections: missingSections
    });
  } catch {
    results.push({
      path: expected.path,
      exists: false,
      valid: false,
      error: "File not found"
    });
  }
}
```

**Output:**
```yaml
validate_result:
  success: true
  total_files: 2
  valid_files: 2
  invalid_files: 0

  results:
    - path: "sadd/advocates/advocate-user.md"
      exists: true
      valid: true
      missing_sections: []

    - path: "sadd/advocates/advocate-business.md"
      exists: true
      valid: true
      missing_sections: []
```

### Action: Cleanup

Remove SADD temporary files (optional, disabled by default).

**Input:**
```yaml
action: "cleanup"
feature_dir: "/path/to/specs/001-feature"
preserve:
  - "stakeholder-synthesis.md"
  - "questions-synthesized.md"
cleanup_patterns:
  - "advocates/*.md"
  - "debates/*-r2.md"
```

**Process:**
```bash
# Only cleanup if explicitly requested
# Preserve key synthesis files
# Remove intermediate agent outputs
```

**Output:**
```yaml
cleanup_result:
  success: true
  removed_files: 6
  preserved_files: 2

  removed:
    - "sadd/advocates/advocate-user.md"
    - "sadd/advocates/advocate-business.md"
    - "sadd/advocates/advocate-ops.md"
    - "sadd/advocates/advocate-security.md"
    - "sadd/debates/debate-Q001-risk.md"
    - "sadd/debates/debate-Q001-value.md"

  preserved:
    - "sadd/stakeholder-synthesis.md"
    - "sadd/questions-synthesized.md"
```

## File Naming Conventions

### Advocates

```
advocate-{perspective}.md

Examples:
- advocate-user.md
- advocate-business.md
- advocate-ops.md
- advocate-security.md
```

### Questions

```
questions-{perspective}.md
questions-synthesized.md

Examples:
- questions-ux.md
- questions-business.md
- questions-technical.md
- questions-synthesized.md
```

### Debates

```
debate-{question_id}-{judge}.md
debate-{question_id}-round2.md  # If debate continues

Examples:
- debate-Q001-risk.md
- debate-Q001-value.md
- debate-Q001-effort.md
- debate-Q001-round2.md
```

### Gates

```
gate-{gate_number}-evaluation.md

Examples:
- gate-1-evaluation.md
- gate-2-evaluation.md
```

## Error Handling

### Directory Creation Failure

```yaml
on_mkdir_failure:
  retry: true
  max_retries: 3
  fallback: "Use feature_dir root if sadd/ can't be created"
```

### File Not Found

```yaml
on_file_not_found:
  action: "report_missing"
  continue: true
  note: "Agent may have failed to produce output"
```

### Validation Failure

```yaml
on_validation_failure:
  action: "report_invalid"
  continue: true
  note: "File exists but missing required sections"
```

## Configuration

```yaml
file_coordination:
  base_dir: "sadd/"
  cleanup_on_complete: false  # Keep files for debugging
  validate_outputs: true
  required_sections:
    advocates:
      - "## Summary"
      - "## Gaps Identified"
    questions:
      - "## Summary"
      - "## Questions"
    debates:
      - "## My Recommendation"
```

## Integration Example

```typescript
// Full file coordination flow
async function coordinateSADDFiles(featureDir: string) {
  // Step 1: Setup directories
  await fileCoordinator({
    action: "setup",
    feature_dir: featureDir
  });

  // Step 2: After agents complete, collect outputs
  const advocateFiles = await fileCoordinator({
    action: "collect",
    feature_dir: featureDir,
    pattern: "advocates/advocate-*.md"
  });

  // Step 3: Validate outputs
  const validation = await fileCoordinator({
    action: "validate",
    feature_dir: featureDir,
    expected_files: [
      { path: "sadd/advocates/advocate-user.md", required_sections: ["## Summary"] },
      // ...
    ]
  });

  // Step 4: Report any issues
  if (!validation.success) {
    console.log("Missing or invalid outputs:", validation.results);
  }

  return {
    files: advocateFiles,
    validation: validation
  };
}
```
