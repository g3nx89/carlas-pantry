---
phase: "8b"
phase_name: "Asset Consolidation & Preparation"
checkpoint: "ASSET_CONSOLIDATION"
delegation: "coordinator"
modes: [complete, advanced, standard, rapid]
prior_summaries:
  - ".phase-summaries/phase-8-summary.md"
artifacts_read:
  - "spec.md"
  - "design.md"
  - "plan.md"
  - "test-plan.md"
  - "research.md"
  - "analysis/expert-review.md"
artifacts_written:
  - "asset-manifest.md"
agents: []
mcp_tools: []
feature_flags: []
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/templates/asset-manifest-template.md"
---

# Phase 8b: Asset Consolidation & Preparation

> **COORDINATOR INSTRUCTIONS**
> You are a phase coordinator dispatched by the lean orchestrator.
> 1. Read this file completely for your phase instructions.
> 2. Read the prior phase summaries listed in `prior_summaries` frontmatter from `{FEATURE_DIR}/.phase-summaries/`.
> 3. Read the artifacts listed in `artifacts_read` frontmatter from `{FEATURE_DIR}/`.
> 4. Execute ALL steps below for the current `analysis_mode`.
> 5. Write your output artifacts to `{FEATURE_DIR}/`.
> 6. Write your phase summary to `{FEATURE_DIR}/.phase-summaries/phase-8b-summary.md` using the template at `$CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md`.
> 7. You MUST NOT interact with the user directly. If user input is needed, set `status: needs-user-input` in your summary with `block_reason` explaining what is needed and what options are available.
> 8. If a sub-agent (Task) fails, retry once. If it fails again, continue with partial results and set `flags.degraded: true` in your summary.

## Purpose

Identify all non-code assets required for feature implementation — images, icons, UI copy, audio, video, fonts, configuration files, data fixtures, design tokens, and security certificates. Generate a structured manifest so Phase 9 can include asset preparation as the first implementation phase (Phase 0 in tasks.md).

**Why this phase exists:** During real executions, development was blocked because prerequisite static assets had not been identified or prepared. Code referencing missing images, strings, or configs cannot compile or function. This phase ensures all assets are cataloged and validated by the user before task generation.

## Step 8b.1: Asset Discovery

**All modes.**

```
1. READ planning artifacts by mode:
   - Rapid: spec.md only
   - Standard: spec.md, design.md
   - Complete/Advanced: spec.md, design.md, plan.md, test-plan.md, research.md, analysis/expert-review.md

2. SCAN for asset references using two detection strategies:

   a. EXPLICIT references — direct mentions of assets:
      - "upload icon", "hero image", "notification sound"
      - File path references: "/public/images/...", "/assets/..."
      - Format mentions: "PNG", "SVG", "MP3", "WOFF2"

   b. IMPLICIT requirements — UI elements that need assets:
      - Pages/screens → likely need images, icons, strings
      - Forms → validation messages, placeholder text, labels
      - Notifications → sounds, message strings
      - Auth flows → OAuth configs, certificates
      - Database → seed data, fixture files
      - Themes → design tokens, color palettes
      - Deployment → environment configs, API key placeholders

3. USE detection heuristics from config:
   READ config.asset_consolidation.detection for keyword lists per category.
   Match keywords against artifact content to identify assets.

4. CATEGORIZE each detected asset into one of 10 categories:
   Images (IMG-), Icons (ICN-), Strings/UI Copy (STR-),
   Audio (AUD-), Video (VID-), Fonts (FNT-),
   Configuration (CFG-), Data Fixtures (DAT-),
   Design Tokens (TKN-), Certificates/Security (SEC-)
```

## Step 8b.2: Manifest Generation

**All modes.**

```
1. READ manifest template from:
   $CLAUDE_PLUGIN_ROOT/templates/asset-manifest-template.md

2. FOR each detected asset, populate:
   - ID: {CATEGORY_PREFIX}-{NNN} (e.g., IMG-001, STR-001)
   - Name: descriptive name
   - Category: one of the 10 categories
   - Format: file format requirements (infer from context or use sensible defaults)
   - Dimensions/Specs: size, duration, weight counts — IF inferrable from spec or design
   - Source: Create | Acquire | Existing (whether asset needs to be created, purchased/downloaded, or already exists)
   - Readiness: "Needs preparation" (default for all discovered assets)
   - Notes: responsive variants, i18n needs, accessibility (alt text), environment specifics

3. POPULATE the summary table with counts per category.

4. FOR Standard/Rapid modes:
   - Omit format/dimension columns where not inferrable
   - Use simplified single-table layout if total assets < 10

5. WRITE manifest to {FEATURE_DIR}/asset-manifest.md
   SET manifest status to "draft"
```

## Step 8b.3: Self-Critique (Complete/Advanced/Standard)

**Skip for Rapid mode.**

```
IF analysis_mode in {Complete, Advanced, Standard}:

  ANSWER these 3 verification questions against the manifest:

  Q1: "Did I cover all UI screens and pages mentioned in spec.md for visual assets
       (images, icons, backgrounds)?"
     → IF NO: scan spec.md screen/page list, add missing visual assets

  Q2: "Did I include infrastructure assets (configs, certificates, fixtures,
       design tokens) — not just visual ones?"
     → IF NO: re-scan design.md for infrastructure requirements

  Q3: "Are format and dimension requirements specified where the spec or design
       document provides them?"
     → IF NO: re-read spec.md and design.md for explicit format/size mentions

  REQUIRED: At least config.asset_consolidation.self_critique.min_pass (default: 2)
  out of 3 questions must pass.

  IF revisions needed: UPDATE the manifest with newly discovered assets.
```

## Step 8b.4: User Validation Gate

**All modes.**

```
IF asset_count == 0:
  # No assets detected — skip phase entirely
  SET status to "skipped"
  WRITE phase summary with:
    status: "skipped"
    summary: "No non-code assets detected for this feature."
    flags:
      asset_count: 0
      skipped: true
  RETURN (phase complete)

IF asset_count > 0:
  SET status to "needs-user-input"
  SET block_reason to formatted manifest presentation:

  """
  ## Asset Manifest Review

  Phase 8b identified {asset_count} assets across {category_count} categories
  that should be prepared before development begins.

  ### Summary
  {summary_table from manifest}

  ### Full Manifest
  Saved to: {FEATURE_DIR}/asset-manifest.md

  ### Actions Available
  1. **Confirm** — Accept the manifest as-is. All assets will become Phase 0 tasks.
  2. **Edit** — Add missing assets, remove unnecessary ones, or update details.
     Provide your changes and I will update the manifest.
  3. **Skip** — Skip asset preparation entirely. No Phase 0 will be generated.
     (Assets can still be prepared ad-hoc during development.)

  Please review and choose an action.
  """

  SET flags:
    asset_count: {count}
    asset_categories: [{list of non-empty categories}]
    requires_validation: true
```

## Step 8b.5: Manifest Finalization

**All modes. Executes after orchestrator relays user response.**

```
The orchestrator will re-dispatch this phase with user_response context after
mediating the user interaction from Step 8b.4.

IF user_response == "Confirm":
  UPDATE manifest status from "draft" to "validated"
  MARK all assets as "validated"

ELSE IF user_response == "Edit":
  APPLY user's changes to manifest:
    - Add new assets with next sequential IDs
    - Remove assets the user flagged
    - Update details (format, source, notes) as specified
  UPDATE manifest status to "validated"
  UPDATE summary table counts

ELSE IF user_response == "Skip":
  SET manifest status to "skipped"
  SET status to "skipped"
  WRITE phase summary with:
    status: "skipped"
    summary: "User chose to skip asset preparation."
    flags:
      asset_count: {count}
      skipped: true
      skip_reason: "user_choice"
  RETURN (phase complete)

WRITE final asset-manifest.md to {FEATURE_DIR}/

WRITE phase summary with:
  status: "completed"
  checkpoint: "ASSET_CONSOLIDATION"
  artifacts_written:
    - "asset-manifest.md"
  summary: "Asset manifest validated with {asset_count} assets across {category_count} categories."
  flags:
    asset_count: {count}
    asset_categories: [{list}]
    validated: true
    skipped: false
```

## Mode-Specific Behavior Summary

| Step | Complete | Advanced | Standard | Rapid |
|------|----------|----------|----------|-------|
| 8b.1 Discovery | All 6 artifacts | All 6 artifacts | spec + design only | spec only |
| 8b.2 Generation | Full manifest, all columns | Full manifest, all columns | Full manifest, all columns | Simplified flat list if <10 assets |
| 8b.3 Self-Critique | 3 questions, min 2 pass | 3 questions, min 2 pass | 3 questions, min 2 pass | Skip |
| 8b.4 Validation | User gate | User gate | User gate | User gate |
| 8b.5 Finalization | Full | Full | Full | Full |

**Checkpoint: ASSET_CONSOLIDATION**
