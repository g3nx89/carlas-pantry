---
lens: "Structure & Progressive Disclosure"
lens_id: structure
skill_reference: "plugin-dev:skill-development"
target: feature-refinement
target_path: "plugins/product-definition/skills/refinement"
fallback_used: false
findings_count: 7
critical_count: 0
high_count: 2
medium_count: 3
low_count: 1
info_count: 1
---

# Structure & Progressive Disclosure Analysis

**Skill:** feature-refinement v3.0.0
**Path:** `plugins/product-definition/skills/refinement/`
**Lens:** Structure & Progressive Disclosure
**Date:** 2026-03-01

---

## Summary

The feature-refinement skill demonstrates strong structural organization with a lean SKILL.md (~1,980 words) that delegates detailed procedural content to 15 reference files. The Reference Map table is thorough, all referenced files exist on disk, and the README.md in `references/` provides a well-structured cross-reference index. Two high-severity findings relate to the frontmatter description (missing third-person voice and trigger phrases) and a minor second-person usage. The directory layout follows the standard `SKILL.md + references/` pattern without unnecessary directories. Overall, the progressive disclosure design is exemplary for a skill of this complexity.

---

## Findings

### 1. Frontmatter description lacks third-person voice and trigger phrases

**Severity:** HIGH
**Category:** Frontmatter quality
**File:** `SKILL.md`

**Current state:**
```yaml
description: Transform rough product drafts into finalized PRDs through iterative Q&A
```

This is a bare imperative phrase. The skill-development lens requires third-person voice ("This skill should be used when...") with specific trigger phrases that users would actually say. The current description contains no trigger phrases, making auto-discovery unreliable -- Claude must infer relevance from the name alone rather than matching against concrete user utterances.

**Recommendation:** Rewrite the description to third-person with explicit trigger phrases:
```yaml
description: >-
  This skill should be used when the user asks to "refine requirements",
  "generate a PRD", "create product requirements", "turn my draft into a PRD",
  "run requirements refinement", or "iterate on product definition".
  Transforms rough product drafts into finalized, non-technical PRDs through
  iterative file-based Q&A with multi-perspective analysis.
```

---

### 2. Second-person "You" usage in SKILL.md body

**Severity:** HIGH
**Category:** Writing style
**File:** `SKILL.md` (line 78)

**Current state:**
```markdown
You **MUST** consider the user input before proceeding (if not empty).
```

The skill-development lens mandates imperative/infinitive form throughout the skill body. Second-person ("You") should not appear in SKILL.md. While this is a single instance, it sits in a prominent location (the User Input section) and sets a precedent counter to the style requirement.

**Recommendation:** Rewrite in imperative form:
```markdown
**MUST** consider the user input before proceeding (if not empty).
```
Or more naturally:
```markdown
Consider the user input before proceeding. This is MANDATORY when input is non-empty.
```

---

### 3. references/README.md not listed in SKILL.md Reference Map

**Severity:** MEDIUM
**Category:** Reference file wiring
**File:** `SKILL.md`

**Current state:** The Reference Map table in SKILL.md lists 15 reference files. However, `references/README.md` (7,146 bytes, containing the file usage table, file sizes, cross-references, and structural patterns) exists on disk but is absent from the Reference Map. Per the project's CLAUDE.md quality checklist: "All reference files listed in skill's Reference Map table AND `references/README.md`."

**Recommendation:** Add a row to the Reference Map table:
```markdown
| `references/README.md` | Reference index: file usage, sizes, cross-references, structural patterns | On-demand orientation |
```

---

### 4. No examples/ or scripts/ directories -- deliberate but undocumented

**Severity:** MEDIUM
**Category:** Directory layout
**File:** `SKILL.md`

**Current state:** The skill directory contains only `SKILL.md` and `references/`. There are no `examples/` or `scripts/` directories. For a skill of this complexity (6-stage workflow with dynamic panel composition, state management, crash recovery), the absence of examples is notable. There is no explicit note in SKILL.md explaining why examples are omitted.

The skill-development lens recommends the "Standard Skill" layout (`SKILL.md + references/ + examples/`) for most plugin skills. While the absence may be a deliberate choice (the skill orchestrates agents rather than producing code artifacts), documenting this decision prevents future contributors from assuming examples were accidentally omitted.

**Recommendation:** Either (a) add an `examples/` directory with a sample state file, sample QUESTIONS file, and sample panel config to illustrate the expected formats, or (b) add a brief note in SKILL.md explaining that examples are not included because the skill generates all working files at runtime. Option (a) would improve onboarding for contributors and debugging.

---

### 5. Summary Contract section is substantial inline content

**Severity:** MEDIUM
**Category:** Progressive disclosure
**File:** `SKILL.md` (lines 166-248)

**Current state:** The Summary Contract section spans approximately 80 lines (~500 words) including the YAML schema, a filled example, and the Interactive Pause Schema. This is detailed procedural reference content that coordinators consume, not core orchestrator logic. It contributes meaningfully to the SKILL.md word count and represents the kind of "detailed content" the lens recommends moving to references.

While the current SKILL.md word count (~1,980) is within the recommended 1,500-2,000 range, it sits at the upper boundary. Moving the Summary Contract (with its example and pause schema) to a dedicated reference file would free approximately 500 words of headroom, keeping SKILL.md comfortably lean and creating space for future additions without exceeding the threshold.

**Recommendation:** Extract the Summary Contract section (lines 166-248) to `references/summary-contract.md`. Replace the inline content with a concise pointer:
```markdown
## Summary Contract

All coordinator summaries follow a standard YAML frontmatter convention.

**Full schema and examples:** `references/summary-contract.md`

**Key fields:** `stage`, `status` (completed|needs-user-input|failed), `checkpoint`, `artifacts_written`, `flags.next_action`.
```
Update the Reference Map and `references/README.md` accordingly.

---

### 6. Second-person "You" in orchestrator-loop.md dispatch template is acceptable

**Severity:** LOW
**Category:** Writing style
**File:** `references/orchestrator-loop.md` (lines 56, 97-103)

**Current state:** The dispatch template in `orchestrator-loop.md` contains multiple "You" references:
```
You are a coordinator for the Requirements Refinement workflow.
...
- You MUST NOT interact with users directly.
- You MUST write a summary file...
- You MUST update the state file...
- You MUST run self-verification checks...
```

These occur inside a prompt template (the text within `Task(...)` that will be sent to a coordinator subagent). In this context, "You" addresses the subagent being dispatched, not the reader of the reference file. This is standard practice for prompt templates.

**Recommendation:** This is a borderline case. The "You" usage is within a quoted prompt template, not in the instructional prose of the reference file. No change is strictly required, but for maximal consistency, the template could be rewritten in imperative form:
```
Role: coordinator for the Requirements Refinement workflow.
...
- MUST NOT interact with users directly.
- MUST write a summary file...
```
Classify as LOW because the current usage is contextually appropriate.

---

### 7. State Management section placement

**Severity:** INFO
**Category:** Progressive disclosure
**File:** `SKILL.md` (lines 250-305)

**Current state:** The State Management section (~55 lines, ~350 words) appears inline in SKILL.md. It documents the full state schema including nested `rounds` and `phases` YAML structures. This is reference-grade content that coordinators need but the orchestrator only reads via the state file itself.

However, keeping it in SKILL.md has a pragmatic benefit: it serves as the canonical schema definition visible at the same level as the Summary Contract and Configuration Reference sections. Since SKILL.md is already at ~1,980 words (within bounds), extraction is not urgent.

**Recommendation:** No immediate action required. If SKILL.md grows beyond 2,000 words from future additions, the State Management section is the next candidate for extraction to `references/state-schema.md`. Note this as a future optimization.

---

## Strengths

### 1. Exemplary progressive disclosure architecture

The SKILL.md body is tightly controlled at ~1,980 words while governing a complex 6-stage workflow with 15 reference files totaling ~150KB of detailed procedural content. The Reference Map table provides clear "Load When" guidance for each reference file, enabling context-efficient on-demand loading. The `references/README.md` adds a second layer of discoverability with file sizes, cross-references, and structural patterns. This is a textbook implementation of the three-level loading system (metadata -> SKILL.md body -> references).

### 2. Comprehensive reference file wiring with cross-reference index

Every reference file listed in SKILL.md's Reference Map exists on disk (15/15 verified). The `references/README.md` provides a detailed cross-reference matrix showing which stage files reference which shared references, the data flow for REFLECTION_CONTEXT between stages, and external references to agents and config files. The step numbering convention documentation and structural patterns section in README.md further aid navigation. This level of wiring discipline is rare and significantly reduces the risk of orphaned or undiscoverable reference files.

### 3. Clean hub-spoke SKILL.md structure

SKILL.md functions as a lean dispatch table: Critical Rules, Configuration Reference (summary), Analysis Modes (table), Workflow Stages (ASCII diagram), Stage Dispatch Table, and Reference Map. No procedural detail leaks into SKILL.md -- all execution logic lives in the stage reference files and orchestrator-loop.md. The ASCII workflow diagram provides an at-a-glance overview that no amount of prose could match. The CRITICAL RULES bookend pattern (repeated at start and end) leverages attention positioning for the most important constraints.

### 4. Well-organized reference directory

The 15 reference files follow a clear naming convention: `stage-{N}-*.md` for stage-specific procedures, descriptive names for shared protocols (`checkpoint-protocol.md`, `error-handling.md`, `consensus-call-pattern.md`), and a separate `README.md` index. File sizes range from ~1KB (checkpoint-protocol) to ~20KB (stage-3-analysis-questions), demonstrating appropriate granularity -- small focused files for simple protocols, larger files for complex multi-step procedures.
