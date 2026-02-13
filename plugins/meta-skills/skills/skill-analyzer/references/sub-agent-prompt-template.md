# Lens Sub-Agent Prompt Template

This file contains the parameterized prompt template dispatched to each lens sub-agent via `Task(subagent_type="general-purpose")`. The orchestrator fills all variables before dispatch.

## Variable Table

| Variable | Type | Description | Source |
|----------|------|-------------|--------|
| `{LENS_ID}` | string | Short identifier (e.g., `structure`) | lens-config.md |
| `{LENS_SKILL_REF}` | string | Skill tool reference (e.g., `plugin-dev:skill-development`) | lens-config.md |
| `{LENS_NAME}` | string | Display name (e.g., `Structure & Progressive Disclosure`) | lens-config.md |
| `{LENS_FOCUS}` | string | Focus areas description (bullet list) | lens-config.md |
| `{LENS_FALLBACK_CRITERIA}` | string | Fallback analysis questions (numbered list) | lens-config.md |
| `{TARGET_SKILL_PATH}` | string | Absolute path to target skill directory | User input / resolved |
| `{TARGET_SKILL_NAME}` | string | Name from target frontmatter `name:` field | Parsed from target SKILL.md |
| `{TARGET_SKILL_FILES}` | string | File listing with sizes (one per line) | Inventory step |
| `{OUTPUT_PATH}` | string | Absolute path for analysis output file | Derived: `{TARGET_SKILL_PATH}/.skill-review/{LENS_ID}-analysis.md` |

All variables are **required**. No variable may be left unfilled — if a value is unavailable, use `"Not available"` as fallback text.

## Prompt Template

````
## Role

Skill quality analyst specializing in {LENS_NAME}.

## Objective

Analyze the target skill "{TARGET_SKILL_NAME}" from the perspective of {LENS_NAME}.
Produce a structured analysis with severity-classified findings and actionable recommendations.

## Step 1: Load Evaluation Criteria

Load the lens skill to obtain evaluation criteria:

Invoke `Skill("{LENS_SKILL_REF}")` tool.

If the Skill tool invocation fails (plugin not installed or skill not found),
proceed with these fallback criteria instead:

{LENS_FALLBACK_CRITERIA}

Note whether fallback criteria were used — this affects the `fallback_used` field in the output.

## Step 2: Read Target Skill

Read the target skill files at `{TARGET_SKILL_PATH}`:

1. **MUST read**: `{TARGET_SKILL_PATH}/SKILL.md` — the primary file under review.
2. **Selectively read** up to 3 reference files, prioritizing by relevance to {LENS_NAME}:
{TARGET_SKILL_FILES}

Do NOT read every file. Select the 3 most relevant to the focus areas below.

## Step 3: Analyze

Evaluate the target skill against the loaded lens criteria.
Focus specifically on:

{LENS_FOCUS}

For each finding, produce:
1. **Title** — concise description of the issue or observation
2. **Severity** — classify as: CRITICAL | HIGH | MEDIUM | LOW | INFO
3. **Category** — which focus area this falls under
4. **Current state** — quote or describe the relevant section of the target skill
5. **Recommendation** — specific, actionable change (not vague advice)
6. **File** — which file contains the issue (e.g., `SKILL.md`, `references/workflows.md`)

### Severity Definitions

- **CRITICAL**: Fundamentally broken — skill will not function correctly or violates core requirements
- **HIGH**: Significant quality issue — degrades skill effectiveness substantially
- **MEDIUM**: Notable improvement opportunity — enhances quality when addressed
- **LOW**: Minor polish — nice-to-have improvement
- **INFO**: Positive observation or stylistic note — no action required

Also identify **Strengths** — aspects the skill handles well from this lens perspective.
Aim for at least 2 strengths alongside the findings.

## Step 4: Write Analysis

Create the output directory if needed, then write the analysis to:
`{OUTPUT_PATH}`

Use this exact structure:

---

```yaml
---
lens: "{LENS_NAME}"
lens_id: "{LENS_ID}"
skill_reference: "{LENS_SKILL_REF}"
target: "{TARGET_SKILL_NAME}"
target_path: "{TARGET_SKILL_PATH}"
fallback_used: true|false
findings_count: N
critical_count: N
high_count: N
medium_count: N
low_count: N
info_count: N
---
```

```markdown
# {LENS_NAME} Analysis: {TARGET_SKILL_NAME}

## Summary

{2-3 sentence executive summary of findings from this lens perspective.
Include the most important finding and the strongest aspect.}

## Findings

### 1. {Finding Title}
- **Severity**: CRITICAL|HIGH|MEDIUM|LOW|INFO
- **Category**: {focus area category}
- **File**: {file path relative to skill directory}
- **Current**: {quote or description of current state}
- **Recommendation**: {specific actionable change}

### 2. {Finding Title}
...

{Continue for all findings. Order by severity (CRITICAL first).}

## Strengths

1. **{Strength title}** — {description of what the skill does well}
2. **{Strength title}** — {description}

{Minimum 2 strengths.}
```

---

## Important Rules

- Do NOT interact with the user. Write only to the output file.
- Do NOT modify any target skill files. This is a read-only analysis.
- If a finding is ambiguous (could be an issue or a deliberate choice), classify as LOW and note the ambiguity.
- If the target skill has no reference files, analyze SKILL.md alone — do not report "missing references" as CRITICAL unless the SKILL.md exceeds the `skill_too_large_words` threshold (see config) with no references.
- Keep the analysis focused on the lens perspective. Do not stray into areas covered by other lenses.
````
