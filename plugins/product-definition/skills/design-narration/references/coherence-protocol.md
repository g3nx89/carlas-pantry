---
stage: coherence-check
artifacts_written:
  - design-narration/coherence-report.md
  - design-narration/.narration-state.local.md (updated)
---

# Coherence Check Protocol (Stage 3)

> Orchestrator dispatches the `narration-coherence-auditor` agent to perform cross-screen consistency analysis.
> The auditor reads ALL completed screen narratives and returns structured findings.

## CRITICAL RULES (must follow)

1. **Dispatch to dedicated agent**: Use `narration-coherence-auditor` — do NOT run inline (context-heavy with multiple files).
2. **All inconsistencies go through user**: Never auto-fix inconsistencies. Present each to user for confirmation.
3. **Generate mermaid diagrams**: Navigation map + user journey flows + state machine diagrams are MANDATORY outputs.

---

## Large Screen Set Handling

When screen count exceeds `coherence.max_screens_per_dispatch` (from config) and `coherence.large_set_strategy` (from config) is `"digest-first"`, the auditor cannot process all full narrative files in a single context:

```
IF screen_count > coherence.max_screens_per_dispatch AND coherence.large_set_strategy == "digest-first":
    # Digest-first strategy
    COMPILE per-screen digest (coherence.per_screen_digest_lines per screen):
        "{SCREEN_NAME} | Score: {TOTAL}/20 | Patterns: {top 3 patterns} | Nav: {entry→exit}"

    DISPATCH coherence auditor with DIGEST instead of full screen files
    INCLUDE instruction: "Read full narrative file ONLY for screens you flag for inconsistency"

    # Auditor returns which screens need full-file comparison
    FOR each flagged screen pair:
        VERIFY auditor read the full files before finalizing the inconsistency finding

ELSE:
    DISPATCH with full screen files (standard path below)
```

---

## Dispatch Template

```
Task(subagent_type="general-purpose", prompt="""
You are a coordinator for Design Narration, Stage 3 (Coherence Check).
You MUST NOT interact with users directly. Write all output to files.
You MUST write the coherence report upon completion.

Read and execute the instructions in @$CLAUDE_PLUGIN_ROOT/agents/narration-coherence-auditor.md

## Input
- Screens directory: design-narration/screens/
- Screen files: {LIST_OF_SCREEN_FILES}
- Accumulated patterns: {PATTERNS_YAML}
- State file: design-narration/.narration-state.local.md

## Output
Write findings to: design-narration/coherence-report.md
""")
```

---

## Auditor Output Format

The coherence auditor writes `design-narration/coherence-report.md`:

```yaml
---
status: completed
inconsistencies_found: {N}
patterns_extracted:
  shared_components: {N}
  interaction_conventions: {N}
  naming_patterns: {N}
mermaid_diagrams_generated: {N}
---
```

Followed by markdown body with:

### Section 1: Inconsistencies

```markdown
## Inconsistencies

| # | Check | Screen A | Screen B | Issue | Suggested Fix |
|---|-------|----------|----------|-------|---------------|
| 1 | naming | Login | Home | "Header" vs "Top Bar" | Standardize to "Header Bar" |
| 2 | state_parity | Search | Orders | Orders missing loading state | Add loading state |
```

### Section 2: Extracted Patterns

Shared components table, interaction conventions table, naming patterns.

### Section 3: Mermaid Diagrams

#### Navigation Map

<details>
<summary>Navigation Map mermaid example (skip if familiar)</summary>

## Navigation Map

```mermaid
graph LR
    Splash --> Login
    Login -->|"Sign In"| Home
    Login -->|"Sign Up"| Registration
    Login -->|"Forgot Password"| PasswordReset
    Home --> Search
    Home --> Cart
    Home --> Profile
    Search -->|"Tap item"| ProductDetail
    ProductDetail -->|"Add to Cart"| Cart
```

</details>

#### User Journey Flows

One mermaid diagram per key user task identified from navigation tables.

<details>
<summary>User Journey mermaid examples (skip if familiar)</summary>

## User Journeys

### Purchase Flow

```mermaid
graph TD
    Home -->|"Browse"| Search
    Search -->|"Select"| ProductDetail
    ProductDetail -->|"Add to Cart"| Cart
    Cart -->|"Checkout"| Checkout
    Checkout -->|"Pay"| Confirmation
```

### Registration Flow

```mermaid
graph TD
    Login -->|"Sign Up"| Registration
    Registration -->|"Submit"| Verification
    Verification -->|"Confirm"| Home
```

</details>

#### State Machine Diagrams

For screens with 4+ states.

<details>
<summary>State Machine mermaid example (skip if familiar)</summary>

## State Machines

### Product Detail Screen

```mermaid
stateDiagram-v2
    [*] --> Loading
    Loading --> Loaded: data received
    Loading --> Error: network failure
    Error --> Loading: retry tap
    Loaded --> AddingToCart: add tap
    AddingToCart --> Loaded: success
    AddingToCart --> Error: failure
```

</details>

#### Mermaid Validation Checklist (MANDATORY)

Before finalizing any mermaid diagram, verify:

| Check | Rule |
|-------|------|
| Valid node IDs | No spaces or special characters in node identifiers (use `ProductDetail` not `Product Detail`) |
| Quoted edge labels | All edge labels wrapped in double quotes (`\|"label"\|`) |
| No orphan references | Every node referenced in an edge exists as a declared node |
| Consistent naming | Node IDs match screen names used in narrative files |
| Render test | Mentally trace the diagram — every path from entry reaches at least one exit |

---

## Orchestrator: Handle Inconsistencies

After receiving the coherence report:

```
READ coherence-report.md

IF inconsistencies_found == 0:
    NOTIFY user: "Cross-screen coherence check passed. No inconsistencies found."
    ADVANCE to Stage 4

IF inconsistencies_found > 0:
    FOR each inconsistency (batch of up to {maieutic_questions.max_per_batch} via AskUserQuestion):
        PRESENT:
            question: "[{CHECK_TYPE}] {ISSUE_DESCRIPTION}
            Screen A ({SCREEN_A}): {VALUE_A}
            Screen B ({SCREEN_B}): {VALUE_B}"

            options:
              - "{SUGGESTED_FIX} (Recommended)"
              - "Keep Screen A version"
              - "Keep Screen B version"
              - "Let's discuss this"

        RECORD answer
        UPDATE affected screen narrative files
        ADD to decision audit trail (with revision_reason: "coherence check")

    UPDATE state:
        coherence.status: completed
        coherence.inconsistencies_found: {N}
        coherence.inconsistencies_resolved: {resolved_count}
```

---

## Orchestrator: Extract Final Patterns

After coherence resolution:

1. Read shared components from coherence report → update state patterns
2. Read interaction conventions → update state patterns
3. These final patterns will be included in Global Patterns section of UX-NARRATIVE.md

---

## Orchestrator: Update Mermaid Diagrams

The mermaid diagrams from the coherence report are stored for inclusion in Stage 5 output:

1. Navigation map → Global Patterns section
2. User journey flows → Global Patterns section
3. State machine diagrams → State Machine Diagrams section (end of document)

If any screen narratives were updated during inconsistency resolution, verify that the navigation map still reflects the latest navigation tables.

---

## Self-Verification

Before advancing to Stage 4:

1. `design-narration/coherence-report.md` exists with populated YAML frontmatter
2. All inconsistencies presented to user (none silently skipped)
3. Updated screen files are consistent with user decisions
4. Mermaid diagrams generated (at least navigation map)
5. State file coherence section updated

**Error handling:** For error classification and logging format, see `references/error-handling.md`.

## CRITICAL RULES REMINDER

1. Dispatch to dedicated agent — do NOT run inline
2. All inconsistencies go through user
3. Mermaid diagrams are MANDATORY
