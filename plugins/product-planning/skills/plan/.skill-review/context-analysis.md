---
lens: "Context Engineering Efficiency"
lens_id: "context"
skill_reference: "customaize-agent:context-engineering"
fallback_used: true
skill_analyzed: "feature-planning"
skill_path: "plugins/product-planning/skills/plan/SKILL.md"
skill_version: "3.0.0"
date: "2026-03-01"
total_findings: 8
severity_counts:
  critical: 0
  high: 2
  medium: 3
  low: 2
  info: 1
strengths: 3
---

# Context Engineering Efficiency Analysis: feature-planning

## Executive Summary

The feature-planning skill demonstrates a well-architected progressive loading strategy with a lean orchestrator pattern that explicitly separates always-loaded content (SKILL.md) from on-demand reference files loaded by coordinator subagents. The SKILL.md is slightly over the target word count at ~2,082 words (target: 1,500-2,000), and the mandatory early read of `orchestrator-loop.md` (~1,797 words) effectively doubles the always-loaded context. Several opportunities exist to reduce token waste through deduplication and restructuring of attention-critical content.

---

## Strengths

### S1: Excellent Hub-Spoke Reference Architecture

The skill uses a clean hub-spoke model where SKILL.md serves as a dispatch table (~293 lines) and 28 reference files contain detailed per-phase instructions. Coordinators are dispatched via `Task(subagent_type="general-purpose")` and each reads only its own phase file plus prior summaries — never the full reference corpus. This means only 1 of 11 phase files is loaded per coordinator dispatch, achieving massive context savings.

**Evidence:** The Phase Dispatch Table (SKILL.md lines 129-141) maps each phase to a single file, and the orchestrator-loop.md `DISPATCH_COORDINATOR` function constructs prompts pointing coordinators to exactly one phase file.

### S2: Well-Designed Progressive Disclosure via README.md

The `references/README.md` provides a structured "Read When..." index with file sizes, enabling both human developers and the orchestrator to selectively load only relevant references. The file includes cross-references, a "By Task" section for task-oriented navigation, and explicit line/word counts for budget estimation. This is a textbook example of progressive disclosure metadata.

**Evidence:** README.md organizes files by task context ("Understanding the Delegation Architecture", "Debugging Quality Gates", "Working on Test Planning") rather than just listing them alphabetically.

### S3: Summary-Only Inter-Phase Communication

The `Summary-Only Context` rule (Critical Rule #9) explicitly prohibits the orchestrator from reading raw artifacts or full phase files between phases. Only the standardized summary files (30-80 lines each) flow between phases. This is a key context engineering win — it prevents the orchestrator's context from growing linearly with the number of completed phases.

**Evidence:** SKILL.md line 52: "Between phases, read ONLY summary files from `{FEATURE_DIR}/.phase-summaries/`. Never read full phase instruction files or raw artifacts in orchestrator context."

---

## Findings

### F1: orchestrator-loop.md Is Effectively Always-Loaded Content

**Severity:** HIGH
**Category:** Token Management / Progressive Loading Strategy
**File:** `SKILL.md` (line 147), `references/orchestrator-loop.md`

**Current state:** SKILL.md line 147 states: `Read and follow: $CLAUDE_PLUGIN_ROOT/skills/plan/references/orchestrator-loop.md`. This is an unconditional directive that the orchestrator must read at startup. The orchestrator-loop.md file is 403 lines / ~1,797 words. Combined with SKILL.md's own 293 lines / ~2,082 words, the effective always-loaded context is ~3,879 words (~5,200 tokens) before the orchestrator processes its first phase.

**Recommendation:** Inline the critical dispatch loop pseudocode (the ~30-line `DISPATCH_COORDINATOR` function and the ~20-line main loop skeleton) directly into SKILL.md, and relegate the crash recovery, circuit breaker, v1-to-v2 migration, ADR, and deep reasoning escalation logic to orchestrator-loop.md as true on-demand content. The main loop and coordinator dispatch are needed every run; crash recovery and migration are needed only on edge cases. This would reduce the mandatory read from ~1,797 words to ~400 words while keeping SKILL.md under 2,500 words total.

---

### F2: SKILL.md Exceeds Target Word Count

**Severity:** MEDIUM
**Category:** Token Management
**File:** `SKILL.md`

**Current state:** SKILL.md is 2,082 words. The target for always-loaded content is 1,500-2,000 words. While only slightly over, this is compounded by F1 (the mandatory orchestrator-loop.md read), making the effective always-loaded payload significantly above target.

**Recommendation:** Move the following sections out of SKILL.md into a dedicated reference file (e.g., `references/additional-resources-index.md`) since they are consulted on-demand rather than every run:
- "Additional Resources" section (lines 226-265, ~500 words) — this is essentially a reference index that duplicates much of what README.md already provides
- "Test Execution Order (V-Model)" section (lines 284-293, ~80 words) — this describes post-planning behavior, not orchestrator instructions

This would bring SKILL.md to ~1,500 words, well within target.

---

### F3: Duplicate Reference Index Between SKILL.md and README.md

**Severity:** HIGH
**Category:** Redundancy / Token Waste
**File:** `SKILL.md` (lines 226-265), `references/README.md`

**Current state:** The "Additional Resources" section in SKILL.md (lines 226-265) lists 22 reference files with brief descriptions. The `references/README.md` lists the same 28 files with more detailed "Read When..." descriptions, file sizes, cross-references, and task-oriented navigation. Both are loaded — SKILL.md always, README.md when coordinators or developers need reference navigation.

The overlap wastes ~500 tokens in SKILL.md on information that is more thoroughly covered in README.md. Since the orchestrator never needs to browse references (it uses the Phase Dispatch Table to determine which file to tell a coordinator to read), this section serves no runtime purpose in SKILL.md.

**Recommendation:** Replace the "Additional Resources" section in SKILL.md with a single line:
```markdown
## Additional Resources
See `$CLAUDE_PLUGIN_ROOT/skills/plan/references/README.md` for the full reference index.
```
This saves ~480 words from SKILL.md while preserving discoverability.

---

### F4: Critical Rules Not Positioned for Maximum LLM Attention

**Severity:** MEDIUM
**Category:** Attention Placement
**File:** `SKILL.md`

**Current state:** The "Critical Rules" section (lines 42-54) is well-positioned near the top of the file, which is good for LLM attention. However, the 11 rules are presented as a flat numbered list with no visual hierarchy to distinguish the most important rules from less critical ones. Rules 9 ("Summary-Only Context") and 10 ("No User Interaction from Coordinators") are the two most consequential for correct orchestration behavior, yet they appear at positions 9 and 10 in a list of 11 — the tail end where attention naturally decays.

**Recommendation:** Restructure the Critical Rules section into two tiers:
- **Tier 1 (top, bolded):** Rules 9, 10, 8, 3 — the rules that, if violated, cause architectural failure (wrong context loaded, user interaction leaks, inline execution of delegated phases)
- **Tier 2 (below):** Rules 1, 2, 4, 5, 6, 7, 11 — important but less likely to cause catastrophic failure if partially followed

Alternatively, pull the top 3-4 rules into a prominent callout block immediately after the skill title, before the descriptive paragraph.

---

### F5: Deep Reasoning Escalation Logic Bloats orchestrator-loop.md

**Severity:** MEDIUM
**Category:** Progressive Loading Strategy
**File:** `references/orchestrator-loop.md` (lines 76-167)

**Current state:** The deep reasoning escalation handling in orchestrator-loop.md spans ~90 lines (lines 76-167) of the 403-line file. This logic is gated behind multiple feature flags (`circular_failure_recovery`, `architecture_wall_breaker`, `security_deep_dive`, `abstract_algorithm_detection`) that are all disabled by default. Despite being rarely triggered, this logic is loaded every time the orchestrator reads orchestrator-loop.md.

Additionally, the pending deep reasoning resume check (lines 16-35) adds another ~20 lines of rarely-needed logic at the very top of the dispatch loop — prime attention real estate consumed by an edge-case handler.

**Recommendation:** Extract the deep reasoning escalation logic into its own reference file (it already has `deep-reasoning-dispatch-pattern.md` as a companion). The orchestrator-loop.md should contain only a 3-line stub:
```
IF gate RED after 2 retries AND deep reasoning enabled:
  Follow $PLUGIN/references/deep-reasoning-dispatch-pattern.md
ELSE: ASK user retry/skip/abort
```
Similarly, move the pending escalation resume check to a conditional read: only load the resume logic if `state.deep_reasoning.pending_escalation` is truthy. This would reduce orchestrator-loop.md by ~110 lines (~500 words).

---

### F6: Phase 4 Reference File Lists 10 Feature Flags

**Severity:** LOW
**Category:** Context Degradation Risk
**File:** `references/phase-4-architecture.md` (frontmatter lines 30-39)

**Current state:** Phase 4's frontmatter lists 10 feature flags: `s5_tot_architecture`, `s4_adaptive_strategy`, `s3_judge_gates`, `st_fork_join_architecture`, `st_tao_loops`, `dev_skills_integration`, `deep_reasoning_escalation`, `s7_mpa_deliberation`, `s8_convergence_detection`, `s10_team_presets`. Additionally, it references 4 additional reference files. When all flags are enabled (Complete mode), the coordinator must conditionally load and process content for each flag, potentially pulling in `tot-workflow.md` (352 lines), `adaptive-strategy-logic.md` (284 lines), `skill-loader-pattern.md` (114 lines), and `mpa-synthesis-pattern.md` (130 lines) on top of the 527-line phase file itself.

In the worst case, the Phase 4 coordinator context could reach ~1,400+ lines (~5,400 words) of instruction content alone, before adding artifacts, summaries, and agent outputs. This approaches context pressure territory where late-file instructions may receive diminished attention.

**Recommendation:** This is a deliberate design choice for Complete mode, which is documented as the highest-cost tier. However, consider adding explicit guidance in the phase file about load order priority — e.g., "If context pressure is detected, load `tot-workflow.md` and `adaptive-strategy-logic.md` only; skip `mpa-synthesis-pattern.md` and `skill-loader-pattern.md` as they provide incremental improvements." This gives the coordinator a graceful degradation path within the phase.

---

### F7: MPA Agents Section Could Use Selective Loading Hints

**Severity:** LOW
**Category:** Selective Reference Loading
**File:** `SKILL.md` (lines 179-203)

**Current state:** The MPA Agents section (lines 179-203) lists all agents across all phases in a flat structure. The orchestrator does not need this full listing at runtime — it constructs coordinator prompts using the Phase Dispatch Table, and each phase file's frontmatter specifies its own agents. This section primarily serves as documentation for skill developers.

**Recommendation:** Add a brief note at the top of the section: `> For developer reference only. At runtime, agent assignments come from per-phase frontmatter.` This signals to the LLM that this section can be deprioritized during execution, reducing the risk of the model over-attending to agent names when it should be focused on dispatch logic.

---

### F8: Sequential Thinking Template Loading Guidance Is Well-Placed

**Severity:** INFO
**Category:** Selective Reference Loading
**File:** `SKILL.md` (lines 253-255)

**Current state:** SKILL.md lines 253-255 provide explicit selective loading guidance:
> `Load selectively: coordinators should load only the relevant template group per the phase_mapping in config/planning-config.yaml, NOT the entire file (~4K tokens). E.g., Phase 4 loads architecture_design + architecture_fork_join + risk_assessment + agent_analysis groups only.`

This is an excellent example of context-aware loading instruction — it tells coordinators exactly which subset to load and warns against loading the full file with a concrete token cost (~4K tokens).

**Recommendation:** No action needed. This pattern should be replicated for other large reference files (particularly `tot-workflow.md` at 352 lines and `debate-protocol.md` at 425 lines) where partial loading might be beneficial.

---

## Summary Table

| ID | Severity | Category | Title | File |
|----|----------|----------|-------|------|
| F1 | HIGH | Token Management | orchestrator-loop.md is effectively always-loaded | SKILL.md, orchestrator-loop.md |
| F2 | MEDIUM | Token Management | SKILL.md exceeds target word count | SKILL.md |
| F3 | HIGH | Redundancy | Duplicate reference index between SKILL.md and README.md | SKILL.md, README.md |
| F4 | MEDIUM | Attention Placement | Critical rules not prioritized for LLM attention decay | SKILL.md |
| F5 | MEDIUM | Progressive Loading | Deep reasoning escalation bloats orchestrator-loop.md | orchestrator-loop.md |
| F6 | LOW | Context Degradation | Phase 4 worst-case context load is high | phase-4-architecture.md |
| F7 | LOW | Selective Loading | MPA Agents section lacks runtime/reference distinction | SKILL.md |
| F8 | INFO | Selective Loading | ST template loading guidance is exemplary | SKILL.md |

## Recommended Priority

1. **F3** (HIGH) — Remove duplicate reference index from SKILL.md. Immediate ~500 word savings with zero functionality loss.
2. **F1** (HIGH) — Inline core dispatch loop into SKILL.md, make rest of orchestrator-loop.md on-demand. Reduces mandatory context by ~1,400 words.
3. **F5** (MEDIUM) — Extract deep reasoning escalation from orchestrator-loop.md. Further reduces mandatory context by ~500 words.
4. **F4** (MEDIUM) — Restructure Critical Rules for attention priority. Low effort, high impact on rule adherence.
5. **F2** (MEDIUM) — Addressed as a side effect of F3 + F1 changes. Verify word count after those changes.
6. **F6, F7** (LOW) — Address during next Phase 4 or SKILL.md revision cycle.

## Net Impact Estimate

If F1, F3, and F5 are implemented:
- **SKILL.md**: ~1,500 words (down from 2,082) — within target
- **Mandatory orchestrator-loop.md read**: ~800 words (down from 1,797) — or eliminated if inlined
- **Total always-loaded content**: ~2,300 words (down from ~3,879) — a **41% reduction**
- **orchestrator-loop.md on-demand content**: ~1,000 words (crash recovery, migration, circuit breaker, ADR)
