# Proposal: Multi-Agent Collaboration Improvements for Planning Skill

> **Status:** Draft v2 (consolidated with myclaude-master patterns)
> **Date:** 2026-02-20
> **Sources:** (1) `plugins/context/multi-agent-collaboration-patterns.md` — CCB v5.2.5, Mysti, Owlex; (2) `plugins/context/myclaude-master` — BMAD, DO, OMO, SPARV workflows + codeagent-wrapper
> **Scope:** `plugins/product-planning/skills/plan/` — all phases, config, orchestrator loop
> **Glossary:** CCB = Claude Code Bridge, Mysti = VSCode extension (7 providers), Owlex = MCP server (deliberation council), BMAD = Build Manage Architect Deploy (6-phase pipeline with 100-pt gates), SPARV = Specify Plan Act Review Vault (10-pt gate workflow), OMO = routing-first multi-agent orchestration, DO = 5-phase parallel-first development workflow

---

## Table of Contents

1. [Current State Assessment](#1-current-state-assessment)
2. [Strategy 1: Two-Round MPA Deliberation](#2-strategy-1-two-round-mpa-deliberation)
3. [Strategy 2: Convergence Detection for MPA Synthesis](#3-strategy-2-convergence-detection-for-mpa-synthesis)
4. [Strategy 3: Multi-Strategy Collaboration Selection](#4-strategy-3-multi-strategy-collaboration-selection)
5. [Strategy 4: Parallel Phase Dispatch](#5-strategy-4-parallel-phase-dispatch)
6. [Strategy 5: Team Presets for Agent Composition](#6-strategy-5-team-presets-for-agent-composition)
7. [Strategy 6: Inter-Phase Context Protocol](#7-strategy-6-inter-phase-context-protocol)
8. [Strategy 7: Proactive Risk & Mode Routing](#8-strategy-7-proactive-risk--mode-routing)
9. [Strategy 8: Specify Gate with Iterative Refinement](#9-strategy-8-specify-gate-with-iterative-refinement)
10. [Strategy 9: Confidence-Gated Expert Review](#10-strategy-9-confidence-gated-expert-review)
11. [Cross-Cutting: Circuit Breaker Pattern](#11-cross-cutting-circuit-breaker-pattern)
12. [Summary Matrix and Implementation Order](#12-summary-matrix-and-implementation-order)
13. [Consolidated Config Changes](#13-consolidated-config-changes)
14. [State File Impact](#14-state-file-impact)
15. [Appendix: Quick Reference Card](#appendix-quick-reference-card)

---

## 1. Current State Assessment

### Terminology

Three distinct levels of agent operate in this proposal:

- **Orchestrator** — The SKILL.md main loop that dispatches phases sequentially, reads phase summaries, and mediates all user interaction via `AskUserQuestion`
- **Coordinator** — A phase-level subagent dispatched via `Task(general-purpose)` that reads a self-contained phase instruction file, manages intra-phase agent dispatch, and writes a phase summary
- **Agent** — A specialist subagent dispatched by a coordinator for a specific analytical task (e.g., `software-architect`, `qa-security`). Agents produce outputs consumed by the coordinator, never by the orchestrator directly

### What the Planning Skill Already Implements

The skill already covers several patterns identified in the multi-agent collaboration report:

| Report Pattern | Current Implementation | Source Project |
|---|---|---|
| Scored Review Gate | Phase 6 (PAL Consensus) + Phase 8 (Coverage Validation) with GREEN/YELLOW/RED thresholds and retry loop | CCB Pattern 5 |
| Multi-Judge Debate | `debate-protocol.md` — 3-round debate with consensus checks (Complete mode, Phase 6) | Mysti Pattern 1 (Debate) |
| Role-Based Delegation | Abstract role table in CLAUDE.md (`designer`, `reviewer`, `inspiration`, `executor`) | CCB Pattern 4 |
| Fan-Out Parallel Execution | MPA agents dispatched in parallel within phases (Phase 4: 3 architects, Phase 7: 3 QA) | Mysti Pattern 2 / Owlex Pattern 1 |
| Crash Recovery | `orchestrator-loop.md` CRASH_RECOVERY function reconstructs summaries from artifacts | — |
| Async Fire-and-Forget | CLI dual-dispatch uses `setsid` + background Bash dispatch | CCB Pattern 1 |
| Session Resume | State file v2 with checkpoint-based resume, v1-to-v2 auto-migration | Owlex Pattern 3 |
| Persona/Skill Injection | Dev-skills integration loads domain expertise via subagent delegation into coordinator prompts (Phases 2, 4, 6b, 7, 9) | Mysti Pattern 6 (partial) |
| Sub-Agent Retry + Partial Results | Coordinator instructions: "If a sub-agent fails, retry once. Continue with partial results and set `flags.degraded: true`" | Mysti Resilience |
| Inspiration + Filter | CCB role table assigns `inspiration` (Gemini) with "unreliable" label. `all-plan` skill uses Adopt/Adapt/Discard filtering | CCB Pattern 7 |
| Behavioral Guardrails | CLAUDE.md rules enforce orchestrator behavior (summary-only context, no user interaction from coordinators, immutable decisions) | CCB Pattern (CLAUDE.md) |

### Key Gaps

Five structural gaps emerge from the combined analysis:

1. **Blind agents within a phase** — MPA agents in Phases 4 and 7 never see each other's outputs. They work independently and the coordinator synthesizes. No cross-review, no revision, no challenge. (Note: the debate protocol in Phase 6 already implements cross-review, but Phase 4/7 MPA agents do not.)

2. **One-size-fits-all collaboration** — Every MPA phase uses the same structure (parallel → synthesize). Different analytical needs (architecture exploration vs. security review vs. consensus building) get the same treatment.

3. **No convergence signal** — Synthesis relies on fixed priority weights. There is no measurement of whether agents agree or disagree, and no adaptive behavior based on agreement level.

4. **No quality gate on Phase 3 (Clarification)** — Phase 3 asks clarifying questions and proceeds. There is no scoring of requirement completeness, no targeting of the weakest dimension, and no threshold to determine when clarification is "sufficient." SPARV's 10-point Specify Gate and BMAD's 100-point PRD scoring both demonstrate that iterative refinement with targeted questions on the lowest-scoring dimension produces significantly better input quality for downstream phases. *(Source: myclaude-master — SPARV, BMAD)*

5. **Unstructured expert review output** — Phase 6b agents produce findings as free-form markdown. There is no confidence scoring to filter noise, no severity-based routing (BLOCKING vs MINOR), and no tri-state outcome (Pass / Pass-with-Risk / Fail) to determine whether to iterate, proceed with awareness, or halt. DO's confidence-gated review (≥80 threshold) and BMAD's tri-state output both reduce false positives and clarify the action path. *(Source: myclaude-master — DO, BMAD)*

---

## 2. Strategy 1: Two-Round MPA Deliberation

**Source:** Owlex Pattern 1 — Two-Round Deliberation Council

### Problem

MPA agents in Phases 4 and 7 produce independent outputs. The minimal-change architect may identify a critical constraint that the clean-architecture architect ignores. The coordinator must catch this during synthesis — a single point of failure.

### Proposal

Add an optional Round 2 where each MPA agent receives all other agents' Round 1 outputs and writes a revision. Two implementation variants are offered:

```
FULL VARIANT (3 additional agent dispatches):

  Agent A ──┐            Agent A' ──┐
  Agent B ──┤──→ Share ──→ Agent B' ──┤──→ Coordinator synthesizes
  Agent C ──┘            Agent C' ──┘
           R1                       R2

LIGHT VARIANT (coordinator self-analysis, 0 additional dispatches):

  Agent A ──┐
  Agent B ──┤──→ Coordinator: "Contradictions & Gaps" step ──→ Synthesis
  Agent C ──┘
```

The **light variant** is a simpler alternative where the coordinator itself reads all R1 outputs and writes an explicit "Contradictions and Gaps" analysis before synthesis. This catches cross-agent contradictions (the core benefit of R2) without additional agent round-trips. Recommended as the default; the full variant is available for Complete mode when deeper cross-pollination is worth the latency cost.

**Structured synthesis methodology (both variants):** Inspired by myclaude-master's UltraThink methodology (used in BMAD Orchestrator and Debug agents), the coordinator applies a 3-step structured synthesis after collecting all agent outputs instead of free-form merging:

1. **Insight Integration** — Combine overlapping findings, deduplicate shared conclusions, identify reinforcing evidence
2. **Hypothesis Refinement** — Distill multiple approaches into 1-2 most viable options with explicit trade-off comparison (not open-ended "here are 3 options")
3. **Gap Analysis** — Identify remaining unknowns that no agent addressed, flag for downstream phases via `open_questions` in the phase summary

This 3-step protocol replaces the current implicit "read all outputs and write a synthesis" instruction. It produces more structured coordinator output and surfaces gaps that would otherwise be silently ignored.

### Design (Full Variant)

**Round 2 prompt template** (adapted from Owlex `build_deliberation_prompt_with_role()`):

```markdown
## Round 2: Cross-Informed Revision

You previously produced your analysis in Round 1.

### Other Agents' Round 1 Outputs
---
### [{Agent A name}] output
{Agent A Round 1 content}
---
### [{Agent B name}] output
{Agent B Round 1 content}
---

### Your Task
Consider the other agents' perspectives and revise your analysis:
1. Where do you AGREE? Strengthen shared points with additional evidence.
2. Where do you DISAGREE? Explain why your approach handles the concern better.
3. What did you MISS that another agent caught? Incorporate it.
4. Update your output with revisions clearly marked.
```

**Two R2 modes** (configurable per phase):
- **Revise** (default for Phase 4): "Consider others' perspectives and update your design"
- **Critique** (default for Phase 7 QA): "Act as senior reviewer. Find flaws in others' test strategies"

**Dispatch model:** R2 is always a fresh `Task()` dispatch with R1 output embedded in the prompt. The `Task()` subagent model is ephemeral — there is no resumable session context. (Owlex's session resume pattern does not apply here.)

### Affected Phases

| Phase | R2 Mode | Agents in R2 |
|---|---|---|
| 4 (Architecture) | Revise | software-architect (minimal), software-architect (clean), software-architect (pragmatic) |
| 7 (Test Strategy) | Critique | qa-strategist, qa-security, qa-performance |

### Config Changes

```yaml
# In planning-config.yaml → mpa section (merges under existing mpa: key)
mpa:
  deliberation:
    variant: light                # light | full
    round_2_mode: revise          # revise | critique (full variant only)
    per_phase_override:
      phase_4: revise
      phase_7: critique
    modes: [complete, advanced]   # Skip for standard/rapid
    cost_impact: "Light: negligible. Full: +$0.05-0.15 per MPA phase (3 additional agent dispatches)"
    latency_impact: "Light: +5s. Full: +15-45s per MPA phase"
```

### Feature Flag

```yaml
feature_flags:
  s7_mpa_deliberation:
    enabled: true
    description: "Cross-informed Round 2 for MPA agents before coordinator synthesis"
    rollback: "Set false to use single-round MPA (current behavior)"
    modes: [complete, advanced]
    requires: []
```

### Graceful Degradation

- If R2 agent dispatch fails: coordinator proceeds with R1 outputs only, sets `flags.degraded: true`
- If R1 outputs exceed coordinator context budget (~2400 tokens for 3 agents): fall back to light variant automatically
- If flag enabled mid-session: applies only to phases not yet completed (no re-run of completed phases)

### Files to Modify

- `skills/plan/references/phase-4-architecture.md` — Add R2 dispatch step (full) or contradiction analysis step (light) after R1 agents complete
- `skills/plan/references/phase-7-test-strategy.md` — Same
- `config/planning-config.yaml` — Add `mpa.deliberation` section + feature flag
- `agents/software-architect.md` — Add "Round 2 Awareness" section (single file — the minimal/clean/pragmatic variants in S5 team presets are prompt-level invocation variants, not separate agent files)
- `agents/qa-strategist.md`, `qa-security.md`, `qa-performance.md` — Add "Round 2 Awareness" section

**Round 2 Awareness section template** (add to each affected agent file, per CLAUDE.md "Agent Awareness Hints" pattern):

```markdown
## Round 2 Cross-Review

Your prompt may include a `## Round 2: Cross-Informed Revision` section containing
other agents' Round 1 outputs. When present:
- Identify points of agreement — strengthen with additional evidence
- Identify points of disagreement — defend your approach with specific rationale
- Incorporate valid points you initially missed, marking them as revisions

If this section is absent, this is a Round 1 invocation — proceed with independent analysis.
```

### Effort

Medium-High. Core change is adding a dispatch loop (full) or analysis step (light) in two phase files + R2 prompt template + UltraThink 3-step synthesis protocol. Agent files need awareness hints (template above). The light variant alone is Medium; the full variant with structured synthesis raises it to Medium-High.

### Expected Benefit

Higher-quality synthesis. Agents self-correct and cross-pollinate before the coordinator attempts to merge. The light variant achieves most of this benefit at near-zero cost.

---

## 3. Strategy 2: Convergence Detection for MPA Synthesis

**Source:** Mysti Pattern 2 — Convergence Detection (`BrainstormManager._assessConvergence()`)

### Problem

MPA synthesis applies fixed priority weights regardless of whether agents agree or fundamentally disagree. A synthesis where all three architects converge on "use PostgreSQL" should be handled differently from one where two say PostgreSQL and one says MongoDB.

### Proposal

After MPA agents produce outputs (and after R2 if Strategy 1 is active), compute a convergence score before synthesis.

### Standalone Limitation

When used without Strategy 1 (two-round deliberation), convergence detection has reduced effectiveness. Round 1 independent outputs contain zero cross-references, so `agree_count` and `disagree_count` are both near zero — the algorithm defaults to 0.5 (neutral). The Jaccard similarity component still provides a signal (high lexical overlap suggests similar conclusions), but it also reflects shared prompt instructions. **Convergence detection is most meaningful after R2 when agents explicitly respond to each other.** Enable alongside `s7_mpa_deliberation` for best results; standalone mode provides only Jaccard-based stability measurement.

### Algorithm

Adapted from Mysti's heuristic text analysis:

```
FUNCTION assess_convergence(agent_outputs: list[str]) -> ConvergenceResult:
  # 1. Agreement signal keywords
  agree_keywords = [agree, concur, confirms, aligns, supports, consistent,
                    similarly, same conclusion, reinforces, validates]
  disagree_keywords = [disagree, however, alternatively, contradicts, unlike,
                       conflicts, instead, opposing, challenge, reject]

  agree_count = count_occurrences(agent_outputs, agree_keywords)
  disagree_count = count_occurrences(agent_outputs, disagree_keywords)

  IF (agree_count + disagree_count) > 0:
    agreement_ratio = agree_count / (agree_count + disagree_count)
  ELSE:
    agreement_ratio = 0.5  # Neutral — independent outputs with no cross-reference

  # 2. Position stability (pairwise Jaccard word overlap)
  pairs = all_pairs(agent_outputs)
  similarities = [jaccard_word_overlap(a, b) for a, b in pairs]
  avg_stability = mean(similarities)

  # 3. Composite score
  composite = 0.6 * agreement_ratio + 0.4 * avg_stability

  RETURN ConvergenceResult(
    score=composite,
    agreement_ratio=agreement_ratio,
    stability=avg_stability,
    level=classify(composite)
  )

FUNCTION classify(score) -> str:
  IF score >= 0.7: return "high"      # Strong agreement → quick synthesis
  IF score >= 0.4: return "medium"    # Partial agreement → standard synthesis
  return "low"                         # Significant divergence → flag for user
```

### Synthesis Behavior Based on Convergence

| Level | Score | Synthesis Behavior |
|---|---|---|
| **High** (≥ 0.7) | Agents largely agree | Quick synthesis: prioritize shared findings, minimize deliberation |
| **Medium** (0.4–0.7) | Partial agreement | Standard synthesis: weighted merge with convergent/divergent sections |
| **Low** (< 0.4) | Significant divergence | Extended synthesis: present explicit "Areas of Agreement / Areas of Disagreement" table, set `status: needs-user-input` in summary with divergent items as `block_reason` |

**Note on Low convergence:** The coordinator does not ask the user directly. Per the lean orchestrator protocol, it sets `status: needs-user-input` in the phase summary with the divergence details as `block_reason`. The orchestrator mediates the user prompt via `AskUserQuestion`.

### Output Format (in synthesis artifact)

```markdown
## Agent Convergence Analysis
- **Convergence score:** 0.45 (Medium)
- **Agreement ratio:** 0.38
- **Position stability:** 0.55

### Areas of Agreement
- All agents recommend PostgreSQL for the data layer
- All agents identify the notification service as the highest-risk component

### Areas of Disagreement
- **Caching strategy:** Agent A recommends Redis; Agent B recommends in-memory; Agent C recommends CDN-level
- **API style:** Agent A (REST) vs Agent C (GraphQL)
```

### Config Changes

```yaml
# In planning-config.yaml → mpa section (merges under existing mpa: key)
mpa:
  convergence_detection:
    enabled: true
    # score >= 0.7: high convergence → quick synthesis
    threshold_high: 0.7
    # score >= 0.4 AND < 0.7: medium → standard synthesis
    # score < 0.4: low convergence → flag divergence for user
    threshold_low: 0.4
    agreement_weight: 0.6    # Weight of keyword-based agreement ratio
    stability_weight: 0.4    # Weight of Jaccard text similarity
    modes: [complete, advanced, standard]
    output_section: true     # Include convergence analysis in synthesis artifact
```

### Feature Flag

```yaml
feature_flags:
  s8_convergence_detection:
    enabled: true
    description: "Heuristic convergence measurement before MPA synthesis. Most effective when paired with s7_mpa_deliberation (R2 outputs contain explicit agreement/disagreement language); standalone mode provides Jaccard-only stability signal."
    rollback: "Set false to use fixed-weight synthesis (current behavior)"
    modes: [complete, advanced, standard]
    requires: []
    cost_impact: "Negligible — text analysis only, no additional agent calls"
```

### Graceful Degradation

- If all agent outputs are empty: skip convergence detection, proceed with standard synthesis, set `flags.degraded: true`
- If only 1 agent output available (others failed): convergence score is undefined, skip detection
- If agreement/disagreement keyword counts are both 0 (no cross-references): report `agreement_ratio: N/A (independent outputs)`, rely on Jaccard stability only

### Files to Modify

- `skills/plan/references/phase-4-architecture.md` — Add convergence step before synthesis
- `skills/plan/references/phase-7-test-strategy.md` — Add convergence step before synthesis
- `config/planning-config.yaml` — Add `mpa.convergence_detection` section + feature flag

### Effort

Low-Medium. The convergence algorithm is heuristic text analysis performed by the coordinator — no new agents or MCP calls needed.

### Synergy with Strategy 1

If two-round deliberation (Strategy 1) is enabled, convergence detection runs after Round 2. This provides a quality signal: if convergence is still low after R2, the issue is genuinely contentious and the user should decide.

---

## 4. Strategy 3: Multi-Strategy Collaboration Selection

**Source:** Mysti Pattern 1 — Brainstorm Mode with 5 Strategies

### Problem

Every MPA phase uses the same collaboration structure: parallel independent analysis → coordinator synthesis. But Phase 4 (architecture exploration) has different needs than Phase 6b (security review).

### Proposal

Introduce a strategy selector that maps each phase to the most appropriate collaboration pattern. Adapted from Mysti's 5 strategies, reduced to 3 (Delphi strategy dropped — redundant with PAL Consensus which already provides numeric gating for Phases 6 and 8):

| Strategy | Structure | Rounds | Best For |
|---|---|---|---|
| **Quick** | Parallel → Direct synthesis | 1 | Low-risk, time-sensitive (Rapid/Standard mode) |
| **Perspectives** | Complementary lenses → Cross-review → Synthesis | 2 | Multi-faceted exploration (Phase 4, Phase 7) |
| **Red-Team** | Proposer → Challenger → Defender | 3 | Adversarial analysis (Phase 6b, Phase 7 security) |

**Why Delphi was dropped:** Phases 6 and 8 already use PAL Consensus scoring with GREEN/YELLOW/RED thresholds and retry loops. Adding Delphi-style convergence iteration on top creates double-gating (Delphi convergence loop → PAL Consensus scoring). Delphi's variable rounds (up to 12 subagent dispatches) also add unpredictable latency for phases that already have a numeric quality gate.

### Strategy-to-Phase Mapping

```yaml
mpa:
  strategy_per_phase:
    phase_2:
      default: quick
      complete: perspectives
    phase_4:
      rapid: quick
      standard: quick
      advanced: perspectives
      complete: perspectives   # Already uses 3 complementary lenses
    phase_6b:
      default: red_team        # Adversarial security review
    phase_7:
      rapid: quick
      standard: quick
      advanced: perspectives
      complete: red_team       # QA agents challenge each other
```

### Signal-Based Dynamic Override *(from myclaude-master — OMO)*

The static strategy-per-phase mapping above serves as the default. An optional signal-based override allows the coordinator to escalate or de-escalate the strategy based on task characteristics detected during earlier phases. Inspired by OMO's routing-first pattern, which selects agents based on risk signals rather than fixed pipelines.

**Override signals** (detected by the orchestrator from Phase 2/3 summaries):

| Signal | Override | Rationale |
|---|---|---|
| ≥2 security keywords in research findings (auth, encryption, GDPR, payment) | Phase 4 → `red_team` (even in Advanced mode) | Security-sensitive architectures benefit from adversarial review |
| ≤3 files affected + no open questions after Phase 3 | Phase 4 → `quick` (even in Complete mode) | Low-complexity features don't need multi-round deliberation |
| Phase 3 `specify_score` < 7 (see Strategy 8) | Phase 4 → `perspectives` minimum | Unclear requirements need multiple architectural lenses |

**Rule:** Signal overrides are logged in the phase summary (`flags.strategy_override: "escalated to red_team due to 3 security keywords"`). The user is NOT prompted for override decisions — the orchestrator applies them silently and logs the rationale. This keeps signal-based routing low-friction, unlike preset selection (Strategy 5) which is user-facing.

### Strategy Definitions

#### Quick Strategy
```
1. Dispatch all agents in parallel
2. Coordinator reads all outputs
3. Direct synthesis (no cross-review)
```
This is the current behavior. No changes needed for phases mapped to Quick.

#### Perspectives Strategy
```
1. Dispatch agents with COMPLEMENTARY lenses (each focuses on different aspects)
2. Share all R1 outputs (per Strategy 1)
3. Each agent cross-reviews from their lens perspective
4. Coordinator synthesizes with convergence analysis (per Strategy 2)
```
Subsumes Strategy 1 (two-round deliberation). The distinction is that agents have explicitly different analytical perspectives rather than the same general prompt.

#### Red-Team Strategy
```
1. PROPOSER agent produces the primary analysis
2. CHALLENGER agent receives proposer's output + instruction to find flaws
   - Rates findings as CRITICAL / MAJOR / MINOR (from Mysti's Red-Team strategy)
3. DEFENDER agent receives both outputs + instruction to concede or defend
4. Coordinator synthesizes the debate outcome
```

Adapted from Mysti's Red-Team strategy. The proposer/challenger/defender roles map naturally to existing agents:

| Phase | Proposer | Challenger | Defender |
|---|---|---|---|
| 6b | simplicity-reviewer | security-analyst | coordinator synthesizes (no third agent recall needed) |
| 7 (security) | qa-strategist | qa-security | qa-strategist (revision round) |

### Config Changes

```yaml
# In planning-config.yaml → mpa section (merges under existing mpa: key)
mpa:
  strategies:
    quick:
      rounds: 1
      cross_review: false
    perspectives:
      rounds: 2
      cross_review: true
    red_team:
      rounds: 3  # propose → challenge → defend
      cross_review: sequential  # Each round reads previous
      severity_levels: [CRITICAL, MAJOR, MINOR]
```

### Feature Flag

```yaml
feature_flags:
  s9_multi_strategy:
    enabled: true
    description: "Phase-specific collaboration strategy selection (Quick, Perspectives, Red-Team)"
    rollback: "Set false to use Quick strategy (current behavior) for all phases"
    modes: [complete, advanced]
    requires: [s7_mpa_deliberation, s8_convergence_detection]  # Perspectives needs R2 + convergence
```

### Graceful Degradation

- If `s7_mpa_deliberation` is disabled: Perspectives strategy falls back to Quick (no cross-review available)
- If `s8_convergence_detection` is disabled: Perspectives strategy still runs R2 but skips convergence-adaptive synthesis behavior
- If Red-Team challenger agent fails: coordinator proceeds with proposer output only, sets `flags.degraded: true`
- If flag disabled: all phases use Quick strategy (current behavior)

### Files to Modify

- `skills/plan/references/phase-4-architecture.md` — Add strategy dispatch logic
- `skills/plan/references/phase-6b-expert-review.md` — Red-Team mode
- `skills/plan/references/phase-7-test-strategy.md` — Red-Team or Perspectives mode
- `config/planning-config.yaml` — Strategy definitions
- New file: `skills/plan/references/mpa-strategies.md` — Canonical strategy templates (shared across phases)

### Effort

Medium. Reduced from original proposal by dropping Delphi (eliminates variable-round iteration logic and Phase 6/8 changes). The remaining strategies (Quick = current, Perspectives = S1+S2, Red-Team = new sequential dispatch) are well-scoped.

### Incremental Path

1. Implement Strategy 2 (convergence detection) first
2. Implement Strategy 1 (two-round deliberation) as the "Perspectives" strategy
3. Add Red-Team as a second strategy for Phase 6b
4. Wire the strategy selector

---

## 5. Strategy 4: Parallel Phase Dispatch

**Source:** Owlex Pattern 1 — `asyncio.wait(return_when=ALL_COMPLETED)` for parallel agent execution

### Problem

The orchestrator loop dispatches phases strictly sequentially. Some phases may have no data dependency between them, leading to unnecessary wall-clock time.

### Dependency Analysis

```
Phase 1 (Setup) ─────→ Phase 2 (Research) ────→ Phase 3 (Clarification)
                                                         │
                                                         ↓
                                                  Phase 4 (Architecture)
                                                         │
                                                         ↓
                                                  Phase 5 (ThinkDeep)
                                                         │
                                                         ↓
                                                  Phase 6 (Validation)
                                                         │
                                                         ↓
                                                  Phase 6b (Expert Review)
                                                         │
                                                         ↓
                                                  Phase 7 (Test Strategy)
                                                         │
                                                    ┌────┴────┐
                                                    ↓         ↓
                                              Phase 8     Phase 8b    ← PARALLEL CANDIDATE
                                              (Coverage)  (Asset Consol.)
                                                    │         │
                                                    └────┬────┘
                                                         ↓
                                                  Phase 9 (Completion)
```

### Phase 5 ∥ Phase 6b — DEFERRED (Dependency Error)

The original proposal identified Phase 5 and Phase 6b as parallelizable. **This was incorrect.** Phase 6b's frontmatter explicitly reads `prior_summaries: [".phase-summaries/phase-6-summary.md"]`. Parallelizing Phase 5 and Phase 6b would require:

1. Removing Phase 6b's dependency on Phase 6's validation summary
2. Having Phase 6 read Phase 6b's summary (new reverse dependency)
3. Phase 6's PAL Consensus rubric was not designed to incorporate security findings — rubric rework required

This is a DAG restructuring, not a simple dependency removal. The time saving (~30-60s in a 10-20 minute workflow) does not justify the risk. **Deferred until the phase dependency graph is independently audited.**

### Phase 8 ∥ Phase 8b — Candidate (With Caveats)

Phase 8b's frontmatter reads `prior_summaries: [".phase-summaries/phase-8-summary.md"]`. However, Phase 8b (Asset Consolidation) scans planning artifacts (`spec.md`, `design.md`, `plan.md`, `test-plan.md`) for asset references — it does not use Phase 8's coverage validation scores. The dependency on `phase-8-summary.md` may be informational rather than functional.

**Required verification before implementation:** Read Phase 8b's full instructions and confirm that no step depends on Phase 8's coverage validation results. If the dependency is purely informational (e.g., phase-8-summary provides context about test infrastructure that hints at fixture assets), it can be replaced by reading `test-plan.md` directly.

### Implementation (if Phase 8 ∥ Phase 8b verified safe)

In the orchestrator loop, dispatch both coordinators in a single turn:

```
IF s11_parallel_dispatch.enabled AND phase == "8":
  # Dispatch both coordinators in the same orchestrator turn
  task_8 = Task(subagent_type="general-purpose", prompt=build_prompt("8"))
  task_8b = Task(subagent_type="general-purpose", prompt=build_prompt("8b"))
  # Both run concurrently; orchestrator reads both summaries after return

  summary_8 = READ("{FEATURE_DIR}/.phase-summaries/phase-8-summary.md")
  summary_8b = READ("{FEATURE_DIR}/.phase-summaries/phase-8b-summary.md")

  VALIDATE(summary_8)
  VALIDATE(summary_8b)

  ADD "8", "8b" to state.completed_phases
  SKIP "8b" in main loop
```

### Config Changes

```yaml
# In planning-config.yaml → new section
orchestrator:
  parallel_dispatch:
    enabled: false  # Disabled until Phase 8b dependency verified
    modes: [complete, advanced]
    pairs:
      # Phase 5 || 6b: DEFERRED — Phase 6b depends on Phase 6 summary
      - phases: ["8", "8b"]
        shared_input: [".phase-summaries/phase-7-summary.md", "test-plan.md"]
        note: "Requires verification that Phase 8b does not functionally depend on Phase 8 coverage scores"
        status: "pending_verification"
```

### Feature Flag

```yaml
feature_flags:
  s11_parallel_dispatch:
    enabled: false  # Disabled by default until dependency verification complete
    description: "Dispatch Phase 8 and Phase 8b concurrently. Phase 5||6b deferred (dependency error)."
    rollback: "Set false to use sequential dispatch (current behavior)"
    modes: [complete, advanced]
    requires: []
    cost_impact: "No additional cost — same work, less wall-clock time"
    latency_impact: "Saves ~10-20s for Phase 8||8b pair"
```

### Graceful Degradation

- If one parallel task fails: the other still completes. Failed task enters CRASH_RECOVERY. Orchestrator validates each summary independently.
- If both fail: sequential retry for each, then standard crash recovery flow
- If flag enabled mid-session and Phase 8 already completed: Phase 8b runs sequentially as normal

### Files to Modify

- `skills/plan/references/orchestrator-loop.md` — Add parallel dispatch logic for verified pairs only
- `skills/plan/references/phase-8b-asset-consolidation.md` — Change `prior_summaries` from `phase-8` to `phase-7` (after verification)
- `config/planning-config.yaml` — Add `orchestrator.parallel_dispatch` section + feature flag
- `skills/plan/SKILL.md` — Update Phase Dispatch Table to note parallel candidate

### Effort

Medium. Reduced scope (one pair instead of two) lowers risk. Main work is orchestrator loop modification for parallel dispatch and the Phase 8b dependency verification.

### Expected Benefit

~10-20s wall-clock reduction for Phase 8 || Phase 8b. Modest but essentially free once verified.

---

## 6. Strategy 5: Team Presets for Agent Composition

**Source:** Owlex Pattern 2 — Specialist "Hats" System with Team Presets

### Problem

Agent composition is mode-locked. Complete mode always uses the same 6 agents. A security-focused feature and a performance-focused feature get the same agent lineup despite very different analytical needs.

### Proposal

Introduce user-selectable team presets that customize agent composition per phase.

### Available Presets (Ship Now)

| Preset | Phase 4 Agents | Phase 7 Agents | Phase 6b Agents | Best For |
|---|---|---|---|---|
| `balanced` (default) | minimal + clean + pragmatic | strategist + security + perf | security-analyst + simplicity-reviewer | General features |
| `rapid_prototype` | pragmatic only | strategist only | (skip) | Spike, PoC |

These two presets work immediately with existing agents — zero new agent files required.

### Future Presets (Deferred — Requires New Agent Variants)

The following presets are planned but require new specialist agent files. They are NOT included in the initial config to avoid "ghost features" (visible but non-functional presets):

| Preset | New Agents Required | Best For | Target |
|---|---|---|---|
| `security_focused` | `software-architect-security.md`, `qa-security-penetration.md`, `security-analyst-compliance.md` | Auth, payment, compliance | Phase B+ |
| `performance_focused` | `software-architect-caching.md`, `qa-performance-load.md` | High-traffic, real-time | Phase B+ |
| `mobile_focused` | Platform-specific architect + device-testing QA | Mobile apps | Phase C+ |

### Integration with Mode Auto-Suggestion

The existing mode auto-suggestion (`mode_suggestion` in config) can recommend a preset alongside the mode. Currently limited to `balanced` vs `rapid_prototype`:

```
Detected: 4 high-risk keywords (authentication, payment, GDPR, encryption)
Estimated: 12 files affected
Recommended: Complete mode (~$1.10-2.00)
```

Once `security_focused` preset ships, the suggestion would include: `"with security_focused preset"`.

### Config Changes

**Agent naming note:** The preset agent names below (e.g., `software-architect-minimal`) are **prompt-level invocation variants** of the single `agents/software-architect.md` file, not separate agent files. The coordinator passes a different `approach` parameter (minimal/clean/pragmatic) when dispatching the same base agent.

```yaml
# In planning-config.yaml → mpa section (merges under existing mpa: key)
mpa:
  team_presets:
    balanced:
      description: "Default balanced analysis across all dimensions"
      phase_4_agents: [software-architect-minimal, software-architect-clean, software-architect-pragmatic]
      phase_7_agents: [qa-strategist, qa-security, qa-performance]
      phase_6b_agents: [security-analyst, simplicity-reviewer]

    rapid_prototype:
      description: "Minimal agent set for quick prototyping"
      phase_4_agents: [software-architect-pragmatic]
      phase_7_agents: [qa-strategist]
      phase_6b_agents: []  # Phase 6b skipped when a4_expert_review flag also disabled

    # Future presets added here after agent variants are written and tested

  preset_suggestion:
    default: balanced
```

### Feature Flag

```yaml
feature_flags:
  s10_team_presets:
    enabled: true
    description: "User-selectable team presets for agent composition"
    rollback: "Set false to use mode-locked agent composition (current behavior)"
    modes: [complete, advanced, standard]
    requires: []
    cost_impact: "Varies by preset — rapid_prototype reduces cost; future specialized presets may add agents"
```

### Graceful Degradation

- If selected preset references a non-existent agent file: fall back to `balanced` preset, log warning
- If `rapid_prototype` sets `phase_6b_agents: []` but `a4_expert_review` flag is enabled: Phase 6b dispatches with the `balanced` preset's agents (feature flag takes precedence over empty preset list)
- If preset not recognized: fall back to `balanced`

### Files to Modify

- `config/planning-config.yaml` — Add `mpa.team_presets` section + feature flag
- `skills/plan/references/phase-1-setup.md` — Add preset selection step after mode selection
- `skills/plan/references/phase-4-architecture.md` — Read preset from state, dispatch configured agents
- `skills/plan/references/phase-7-test-strategy.md` — Read preset from state, dispatch configured agents

### Effort

Low. Config-driven, two presets with existing agents. No new agent files for initial ship.

---

## 7. Strategy 6: Inter-Phase Context Protocol

**Source:** §8 Gap Analysis — Shared Memory / Blackboard (adapted to lean orchestrator constraints) + myclaude-master OMO Context Pack Contract

### Problem

Two related issues weaken inter-phase communication:

1. **Decision loss across phases** — Key information discovered in Phase 2 (e.g., "the codebase uses a custom ORM") may be buried in `research.md` and missed by Phase 7's test strategy coordinator. Summary files (30-80 lines each) are the only inter-phase channel.

2. **Unstandardized coordinator inputs** — Each coordinator receives a prompt built ad-hoc by the orchestrator. There is no mandatory format ensuring the original user request, accumulated decisions, and acceptance criteria are always present. myclaude-master's OMO skill solves this with a mandatory "Context Pack" — a standardized 4-section format that every agent invocation must include. This prevents context loss and ensures chain of custody for the user's original intent.

### Original Approach (Blackboard) — Rejected

The original proposal introduced a shared mutable blackboard file (`{FEATURE_DIR}/.blackboard.md`). This was **rejected after critique** for the following reasons:

1. **Violates lean orchestrator principle** — shared mutable state across independent coordinators introduces coordination concerns (write ordering, conflict detection) that the lean orchestrator was designed to avoid
2. **Append-only conflicts with revisions** — if Phase 4 decides "Use PostgreSQL" and Phase 6 RED triggers a Phase 4 revision to "Use MongoDB", both entries coexist with no supersession mechanism
3. **Violates "Summary-Only Context" rule** — the orchestrator would need to read both summaries and the blackboard, doubling inter-phase context
4. **No locking mechanism** — the existing lock only covers the state file, not a shared blackboard

### Revised Approach: Extended Phase Summaries

Instead of a new shared artifact, extend the existing summary template with a structured "Key Decisions" section. The orchestrator accumulates decisions from prior phase summaries and injects them into coordinator prompts.

### Design

**Phase summary template addition:**

```yaml
# Added to templates/phase-summary-template.md YAML frontmatter
key_decisions:
  - id: "DB-001"
    decision: "Use PostgreSQL with Prisma ORM"
    rationale: "Team familiarity, existing infrastructure"
    confidence: HIGH

  - id: "AUTH-001"
    decision: "Use NextAuth.js with JWT strategy"
    rationale: "Existing auth infrastructure"
    confidence: HIGH

open_questions:
  - id: "OQ-001"
    question: "How should mobile clients authenticate?"
    priority: HIGH
    candidates: ["OAuth2 PKCE", "API keys", "session tokens"]

risks_identified:
  - id: "R-001"
    risk: "Database migration complexity"
    severity: HIGH
    mitigation: "Prisma auto-migration + rollback scripts"
```

**Orchestrator accumulation:** When building a coordinator prompt, the orchestrator reads all prior phase summaries and concatenates the `key_decisions`, `open_questions`, and `risks_identified` arrays:

```
## Accumulated Context from Prior Phases

### Key Decisions
- DB-001 (Phase 4): Use PostgreSQL with Prisma ORM [HIGH confidence]
- AUTH-001 (Phase 4): Use NextAuth.js with JWT strategy [HIGH confidence]

### Open Questions
- OQ-001 (Phase 3, HIGH): How should mobile clients authenticate?

### Risk Register
- R-001 (Phase 2, HIGH): Database migration complexity → Mitigated by Prisma auto-migration
```

**Coordinator instructions addition:**

```markdown
## Decision Protocol

1. **RESPECT** all prior key decisions — do not contradict HIGH-confidence decisions.
2. **CHECK** open questions — if your analysis resolves any, include the resolution in your key_decisions.
3. **CONTRIBUTE** your findings in the key_decisions, open_questions, and risks_identified sections of your summary YAML.
```

### Part B: Mandatory Context Pack Format *(from myclaude-master — OMO)*

In addition to extending the summary output format (Part A above), standardize the coordinator **input** format. Every coordinator prompt built by the orchestrator MUST contain these 4 sections:

```markdown
## Original User Request
<verbatim feature request from the user — never paraphrased>

## Accumulated Context
### Key Decisions
- DB-001 (Phase 4): Use PostgreSQL with Prisma ORM [HIGH confidence]
### Open Questions
- OQ-001 (Phase 3, HIGH): How should mobile clients authenticate?
### Risk Register
- R-001 (Phase 2, HIGH): Database migration complexity

## Current Task
<phase-specific instruction — e.g., "Design V-Model test strategy for this feature">

## Acceptance Criteria
<checkable completion conditions — e.g., "UAT scripts in Given-When-Then, test IDs mapped to requirements">
```

**Rules:**
- **Original User Request** is immutable — copied verbatim from Phase 1, never paraphrased by the orchestrator
- **Accumulated Context** is built from prior phase summaries (Part A's `key_decisions`, `open_questions`, `risks_identified`)
- **Current Task** is phase-specific, sourced from the phase reference file
- **Acceptance Criteria** are phase-specific, sourced from the phase reference file's `artifacts_written` frontmatter

**Why both Part A and Part B:** Part A standardizes coordinator *output* (what coordinators write into summaries). Part B standardizes coordinator *input* (what the orchestrator feeds into coordinator prompts). Together they form a bidirectional inter-phase protocol where decisions flow forward through the Context Pack and results flow back through extended summaries.

### Config Changes

```yaml
# In planning-config.yaml → state section
state:
  context_protocol:
    decision_propagation:
      enabled: true
      accumulate_from_summaries: [key_decisions, open_questions, risks_identified]
      inject_into_coordinator_prompt: true
      max_accumulated_tokens: 500  # Budget for accumulated context per coordinator
    context_pack:
      enabled: true
      mandatory_sections: [original_request, accumulated_context, current_task, acceptance_criteria]
      original_request_source: "state.feature_description"  # Set in Phase 1
```

### Feature Flag

```yaml
feature_flags:
  a6_context_protocol:
    enabled: true
    description: "Bidirectional inter-phase context: extended summaries (output) + mandatory Context Pack (input)"
    rollback: "Set false to use ad-hoc coordinator prompts and standard summary format"
    modes: [complete, advanced, standard]
    requires: []
    cost_impact: "Negligible — adds ~10-20 lines to coordinator read context"
```

### Graceful Degradation

- If prior summaries lack the new YAML fields (e.g., v1-era summaries or degraded summaries): skip accumulation, proceed normally
- If accumulated context exceeds `max_accumulated_tokens`: truncate oldest entries first (Phase 2 decisions before Phase 6 decisions)
- If flag disabled: summaries still use standard format, no accumulation

### Files to Modify

- `templates/phase-summary-template.md` — Add `key_decisions`, `open_questions`, `risks_identified` to YAML frontmatter
- `skills/plan/references/orchestrator-loop.md` — Add accumulation logic in DISPATCH_COORDINATOR function
- All phase reference files — Add "Decision Protocol" section to coordinator instructions
- `config/planning-config.yaml` — Add `state.decision_propagation` section + feature flag

### Effort

Low-Medium. Extends the existing summary template (no new files). The orchestrator accumulation logic is 10-15 lines in the dispatch function. Phase reference files each need a ~5-line protocol addition.

### Expected Benefit

Decisions compound across phases without a shared mutable artifact. Phase 7 automatically knows about Phase 4's technology choices. Open questions carry forward until resolved. Architecturally consistent with the lean orchestrator's summary-based communication.

---

## 8. Strategy 7: Proactive Risk & Mode Routing

**Source:** Owlex Pattern 7 — Hook-Based Proactive Routing Suggestions + myclaude-master SPARV EHRB Risk Detection

### Problem

Two routing gaps exist before and during the workflow:

1. **No pre-skill mode nudge** — Users must wait until Phase 1 (mode selection) to learn which mode is appropriate. The skill's mode auto-suggestion runs after the skill starts. There is no pre-skill nudge based on the user's prompt.

2. **No automated risk detection** — The planning workflow does not scan for risk signals (production systems, sensitive data, security-critical code, billing APIs) that should influence mode selection and Phase 6b behavior. SPARV's EHRB (Extremely High-Risk Behavior) detection demonstrates that simple regex-based scanning of the user's prompt can surface risk categories early. *(Source: myclaude-master — SPARV)*

### Proposal

Add a Claude Code hook that inspects the user's initial prompt and injects mode suggestions when planning-related keywords are detected.

### Hook Installation

Claude Code hooks are configured in `.claude/settings.json` at the project level or `~/.claude/settings.json` globally — **not in a plugin-level `hooks/` directory**. The hook script lives in the plugin but must be referenced from the user's settings.

**Installation instruction (in plugin README):**

```json
// Add to .claude/settings.json → hooks
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "(?i)(plan|planning|feature plan|design the|break down|decompose)",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PLUGIN_ROOT/scripts/planning-hint.sh"
          }
        ]
      }
    ]
  }
}
```

**Key design:** The `matcher` regex ensures the hook only fires for planning-related prompts, avoiding false positives on unrelated messages containing "auth" or "security."

### Hook Script

File: `scripts/planning-hint.sh`

```bash
#!/bin/bash
# Proactive mode + risk suggestion based on user prompt keywords
# Sources: Owlex Pattern 7 (passive advisory) + SPARV EHRB (risk detection)
# Only fires when matcher detects planning-related keywords

PROMPT=$(cat)
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# --- EHRB Risk Detection (from SPARV) ---
RISK_FLAGS=()

# Production/infrastructure access
echo "$PROMPT_LOWER" | grep -Eiq '(prod(uction)?|live|staging|deploy|kubeconfig|terraform|helm)' \
  && RISK_FLAGS+=("production-access")

# Sensitive data handling
echo "$PROMPT_LOWER" | grep -Eiq '(pii|phi|hipaa|ssn|password|secret|token|api.?key|gdpr)' \
  && RISK_FLAGS+=("sensitive-data")

# Security-critical changes
echo "$PROMPT_LOWER" | grep -Eiq '(auth|authentication|authorization|oauth|jwt|sso|encryption|crypto)' \
  && RISK_FLAGS+=("security-critical")

# Billing / external API
echo "$PROMPT_LOWER" | grep -Eiq '(stripe|paypal|billing|charge|invoice|subscription|payment)' \
  && RISK_FLAGS+=("billing-external-api")

# Destructive operations
echo "$PROMPT_LOWER" | grep -Eiq '(migrat|drop.?table|delete.?from|truncate|breaking.?change)' \
  && RISK_FLAGS+=("destructive-ops")

RISK_COUNT=${#RISK_FLAGS[@]}

# --- Mode Suggestion ---
if [ "$RISK_COUNT" -ge 2 ]; then
  FLAGS_STR=$(IFS=', '; echo "${RISK_FLAGS[*]}")
  echo "RISK: Detected $RISK_COUNT risk categories [$FLAGS_STR]. Consider Complete mode with security_focused preset."
elif [ "$RISK_COUNT" -eq 1 ]; then
  echo "RISK: Detected risk category [${RISK_FLAGS[0]}]. Consider Advanced mode minimum."
elif echo "$PROMPT_LOWER" | grep -qE '(quick|prototype|spike|fast|simple|poc)'; then
  echo "SUGGESTION: This looks like a quick task. Consider Rapid mode for faster results."
fi
```

### Design Principles (from Owlex)

- **Passive advisory** — does not block the skill from starting
- **Lightweight** — runs in <2 seconds, simple keyword matching
- **Non-intrusive** — only fires when both (a) planning keywords match in the `matcher` regex AND (b) risk/speed keywords are detected in the script
- **No preset recommendations** — mode-only suggestions until Strategy 5's specialized presets ship

### Files to Create

- `scripts/planning-hint.sh` — Hook script
- Documentation note in README about hook installation

### Effort

Low. Single shell script + README update.

### Expected Benefit

Faster mode selection, reduced user friction. Users with security-heavy features get an immediate nudge toward Complete mode before the skill even starts. EHRB risk flags are also available to Phase 1's mode auto-suggestion logic and to Strategy 3's signal-based dynamic override.

---

## 9. Strategy 8: Specify Gate with Iterative Refinement

**Source:** myclaude-master — SPARV 10-point Specify Gate + BMAD 100-point PRD scoring with iterative refinement

### Problem

Phase 3 (Clarifying Questions) has no quality gate. The coordinator asks questions, the user answers, and the workflow proceeds to Phase 4. There is no measurement of whether the requirements are sufficiently clear to produce a good architecture. Poor Phase 3 output cascades: ambiguous requirements → divergent architecture options → contentious synthesis → user frustration.

### Proposal

Add a **Specify Score** to Phase 3 that measures requirement completeness across 5 dimensions. The coordinator iterates (asking targeted questions on the weakest dimension) until the score meets the threshold. Adapted from SPARV's 10-point gate and BMAD's dimensional scoring with targeted question routing.

### Scoring Rubric (10-point scale)

Each dimension scores 0 / 1 / 2:

| Dimension | 0 (Missing) | 1 (Partial) | 2 (Complete) |
|---|---|---|---|
| **Value** | No clear problem statement or success metrics | Problem stated but metrics vague | Clear problem + measurable success criteria |
| **Scope** | No boundaries, open-ended | Some boundaries but MVP undefined | MVP defined + explicit out-of-scope list |
| **Acceptance** | No testable criteria | Some criteria but untestable or vague | Testable acceptance criteria for all core flows |
| **Constraints** | No technical/business constraints | Some constraints identified | Performance, security, compatibility, integration constraints documented |
| **Risk** | No risks identified | Some risks but no mitigation | Key risks identified with mitigation strategies or flagged as open questions |

**Threshold:** `score >= 8` to proceed to Phase 4. (More lenient than SPARV's 9/10 because Phase 3 feeds into MPA exploration, not direct implementation.)

### Targeted Question Routing

When `score < 8`, the coordinator identifies the lowest-scoring dimension and asks 2-3 targeted questions from that dimension's question bank:

```markdown
## Question Banks (per dimension)

### Value (if < 2)
- "What specific problem are we solving for the user?"
- "How will we measure whether this feature is successful?"
- "What happens if we don't build this?"

### Scope (if < 2)
- "What is the minimum viable version of this feature?"
- "What is explicitly OUT of scope for this iteration?"
- "Are there related features we should NOT touch?"

### Acceptance (if < 2)
- "Can you walk me through the main user flow step by step?"
- "What should happen when [edge case identified in research]?"
- "How should the system behave when [error condition]?"

### Constraints (if < 2)
- "Are there performance requirements (latency, throughput)?"
- "Are there security or compliance requirements (auth, encryption, GDPR)?"
- "What existing systems must this integrate with?"

### Risk (if < 2)
- "What could go wrong with this approach?"
- "Are there dependencies on other teams or services?"
- "What technical unknowns remain after research?"
```

**Iteration protocol** (from BMAD pattern):
1. Coordinator scores initial requirement completeness
2. If `score < 8`: identify lowest dimension, ask 2-3 targeted questions via `status: needs-user-input`
3. Orchestrator mediates user prompt via `AskUserQuestion`
4. Coordinator receives answer, updates score, shows progress: *"Scope improved from 0 → 2. New score: 7/10."*
5. Repeat until `score >= 8` or `max_iterations` reached
6. If `max_iterations` exhausted and `score < 6`: set `flags.low_specify_score: true` — downstream phases should use `perspectives` strategy minimum (feeds into Strategy 3's signal-based override)

### Config Changes

```yaml
# In planning-config.yaml → new section
specify_gate:
  enabled: true
  threshold: 8                 # Score >= 8 to proceed to Phase 4
  max_iterations: 3            # Max question rounds before proceeding anyway
  low_score_threshold: 6       # Below this, flag for downstream strategy escalation
  dimensions: [value, scope, acceptance, constraints, risk]
  points_per_dimension: 2
  modes: [complete, advanced, standard]  # Rapid mode skips the gate
```

### Feature Flag

```yaml
feature_flags:
  s12_specify_gate:
    enabled: true
    description: "10-point requirement completeness gate for Phase 3 with iterative refinement"
    rollback: "Set false to use Phase 3 without quality gate (current behavior)"
    modes: [complete, advanced, standard]
    requires: []
    cost_impact: "Negligible — scoring is coordinator self-analysis, questions use existing AskUserQuestion"
    latency_impact: "0-3 additional user interaction rounds (typically 1)"
```

### Graceful Degradation

- If `max_iterations` reached without meeting threshold: proceed with warning flag, do NOT block the workflow
- In Rapid mode: skip gate entirely (score is informational only)
- If Phase 2 research was degraded (MCP failures): relax threshold to 6 (less information available to score against)

### Synergy with Other Strategies

- **Strategy 3 (Multi-Strategy):** Low specify score triggers strategy escalation (quick → perspectives)
- **Strategy 6 (Context Protocol):** Specify score and dimension breakdown are included in Phase 3's `key_decisions` for downstream visibility
- **Strategy 7 (Risk Routing):** EHRB risk flags detected pre-skill feed into the Risk dimension scoring

### Files to Modify

- `skills/plan/references/phase-3-clarification.md` — Add scoring rubric, question banks, iteration logic
- `config/planning-config.yaml` — Add `specify_gate` section + feature flag
- `templates/phase-summary-template.md` — Add `specify_score` and `specify_dimensions` to YAML frontmatter

### Effort

Low-Medium. The scoring rubric and question banks are coordinator instructions (prose, not code). The iteration loop uses the existing `status: needs-user-input` → orchestrator mediation pattern. No new agents or MCP calls.

### Expected Benefit

Higher-quality input to Phase 4. Targeted questions eliminate the "ask random questions" anti-pattern. The dimensional scoring provides a measurable quality signal that feeds into downstream strategy selection.

---

## 10. Strategy 9: Confidence-Gated Expert Review

**Source:** myclaude-master — DO confidence scoring (0-100 scale, ≥80 threshold) + BMAD tri-state review output (Pass / Pass-with-Risk / Fail) + BMAD review iteration limit (max 3 rounds)

### Problem

Phase 6b (Expert Review) agents produce findings as free-form markdown. The coordinator must synthesize all findings and decide whether to block. Two failure modes:

1. **False positive noise** — reviewers surface minor style issues alongside critical security vulnerabilities. The coordinator must distinguish signal from noise without explicit confidence guidance.
2. **Binary outcome** — the current gate is pass/fail (GREEN/RED). There is no "proceed with awareness" middle ground. This forces either blocking the workflow for minor concerns or silently passing issues that deserve attention.

### Proposal

Add two mechanisms to Phase 6b:

**Part A: Confidence Scoring** — Each reviewer agent rates every finding on a 0-100 confidence scale. Only findings with confidence ≥80 are included in the coordinator's synthesis. Adapted from DO's code-reviewer pattern.

**Part B: Tri-State Output** — The coordinator produces a structured verdict: Pass / Pass-with-Risk / Fail. Adapted from BMAD's review agent pattern, with an iteration limit.

### Confidence Scale (for reviewer agents)

```markdown
## Confidence Scoring Guide

Rate each finding on a 0-100 scale:

- **0-25**: Low confidence. Might be a false positive or a pre-existing issue.
- **26-50**: Moderate confidence. Real issue but may be a nitpick or unlikely in practice.
- **51-75**: High confidence. Verified issue that will likely be encountered.
- **76-100**: Very high confidence. Confirmed issue with direct evidence from the codebase.

**Only report findings with confidence >= 80.** Focus on issues that truly matter.
```

**Severity classification** (for findings that pass the ≥80 confidence threshold):

| Severity | Definition | Action |
|---|---|---|
| **CRITICAL** | Security vulnerability, data loss risk, or compliance violation | Blocks workflow — must resolve before Phase 7 |
| **MAJOR** | Significant design flaw, performance risk, or maintainability concern | Noted in Pass-with-Risk — should address during implementation |
| **MINOR** | Style issue, minor optimization opportunity, or low-probability edge case | Auto-accepted — logged for reference, no action required |

### Tri-State Outcome

| Outcome | Condition | Workflow Action |
|---|---|---|
| **Pass** | Zero CRITICAL + zero MAJOR findings (≥80 confidence) | Proceed to Phase 7 |
| **Pass-with-Risk** | Zero CRITICAL + 1+ MAJOR findings | Proceed to Phase 7 with MAJOR findings carried in `risks_identified` (Strategy 6). Phase 9 tasks include risk mitigation steps. |
| **Fail** | 1+ CRITICAL findings | Block workflow. Coordinator sets `status: needs-user-input` with CRITICAL findings as `block_reason`. Options: (a) return to Phase 4 to redesign, (b) user acknowledges risk and overrides to Pass-with-Risk. |

### Iteration Protocol (from BMAD review cycle)

```
IF outcome == Fail AND iteration < max_review_iterations:
  1. Coordinator outputs CRITICAL findings with evidence
  2. Orchestrator presents to user via AskUserQuestion:
     - "Redesign (return to Phase 4)"
     - "Override (acknowledge risk, proceed)"
     - "Provide additional context"
  3. If "Provide additional context": user input → re-run Phase 6b with context
  4. If "Override": set outcome = Pass-with-Risk, add override flag

IF iteration == max_review_iterations AND outcome == Fail:
  Escalate: present all CRITICAL findings to user, require explicit decision
```

### Config Changes

```yaml
# In planning-config.yaml → new section
expert_review:
  confidence_threshold: 80       # Only include findings with confidence >= 80
  severity_levels: [CRITICAL, MAJOR, MINOR]
  tri_state:
    pass: { max_critical: 0, max_major: 0 }
    pass_with_risk: { max_critical: 0 }  # Any number of MAJOR allowed
    fail: {}  # 1+ CRITICAL triggers Fail
  max_review_iterations: 2       # Max rounds before forced user decision
  modes: [complete, advanced, standard]
```

### Feature Flag

```yaml
feature_flags:
  s13_confidence_gated_review:
    enabled: true
    description: "Confidence scoring (>=80 threshold) + tri-state review output for Phase 6b"
    rollback: "Set false to use unstructured expert review (current behavior)"
    modes: [complete, advanced, standard]
    requires: []
    cost_impact: "Negligible — scoring is agent self-assessment, no additional dispatches"
```

### Graceful Degradation

- If reviewer agent fails to include confidence scores: coordinator treats all findings as confidence 80 (include all, no filtering)
- If only 1 reviewer agent produces output (other failed): tri-state is computed from available findings, set `flags.degraded: true`
- In Rapid mode: Phase 6b is already skipped, so this strategy has no effect

### Files to Modify

- `agents/reviewers/simplicity-reviewer.md` — Add confidence scoring guide and output format
- `agents/reviewers/security-analyst.md` — Add confidence scoring guide and output format
- `skills/plan/references/phase-6b-expert-review.md` — Add tri-state synthesis, iteration protocol
- `config/planning-config.yaml` — Add `expert_review` section + feature flag

### Effort

Low-Medium. Confidence scoring is added to agent prompt instructions (no new tools). Tri-state synthesis is coordinator logic. Iteration protocol uses existing `status: needs-user-input` pattern.

### Expected Benefit

Fewer false positives in expert review. Clear action path for each outcome level. Users are not blocked by minor issues (Pass-with-Risk) while genuine security risks halt the workflow (Fail with CRITICAL findings). The confidence threshold (≥80) is calibrated from DO's code-reviewer, which reports this threshold effectively filters ~40% of initial findings as noise.

---

## 11. Cross-Cutting: Circuit Breaker Pattern

**Source:** myclaude-master — SPARV 3-Failure Protocol + BMAD Review 3-iteration limit

### Problem

Multiple strategies include retry logic (Strategy 1 R2 retries, Strategy 4 parallel task failure, Strategy 8 specify gate iterations, Strategy 9 review iterations). Each defines its own retry limits independently. There is no shared pattern for consecutive failure tracking, escalation, and counter reset.

### Proposal

Define a shared circuit breaker pattern that all strategies reference. This is not a separate feature flag — it is a behavioral specification embedded in coordinator instructions and orchestrator logic.

### Pattern Definition

```
CIRCUIT_BREAKER(context, max_consecutive_failures, escalation_action):
  IF context.consecutive_failures >= max_consecutive_failures:
    LOG "Circuit breaker tripped: {context.name} failed {max_consecutive_failures} consecutive times"
    EXECUTE escalation_action  # e.g., "set status: needs-user-input", "skip phase", "fall back to Quick strategy"
    RETURN ESCALATED

  TRY:
    result = EXECUTE(context.action)
    context.consecutive_failures = 0  # Reset on success
    RETURN result
  CATCH:
    context.consecutive_failures += 1
    IF context.consecutive_failures < max_consecutive_failures:
      LOG "Failure {context.consecutive_failures}/{max_consecutive_failures} in {context.name}"
      RETURN RETRY
    ELSE:
      EXECUTE escalation_action
      RETURN ESCALATED
```

### Application Across Strategies

| Strategy | Context | Max Failures | Escalation Action |
|---|---|---|---|
| S1 (MPA Deliberation) | R2 agent dispatch | 2 | Fall back to Light variant (coordinator self-analysis) |
| S3 (Multi-Strategy) | Red-Team challenger/defender dispatch | 2 | Fall back to Quick strategy |
| S4 (Parallel Dispatch) | Parallel coordinator failure | 1 | Sequential retry, then crash recovery |
| S8 (Specify Gate) | User interaction rounds | 3 | Proceed with warning flag + strategy escalation |
| S9 (Expert Review) | Review iteration rounds | 2 | Force user decision |
| PAL Consensus (Phase 6) | PAL MCP call failure | 2 | Skip validation, set `flags.consensus_skipped: true` |
| PAL ThinkDeep (Phase 5) | PAL MCP call failure | 2 | Skip ThinkDeep, proceed with MPA-only results |

### Config Changes

```yaml
# In planning-config.yaml → new section
circuit_breaker:
  defaults:
    max_consecutive_failures: 2
    reset_on_success: true
  overrides:
    specify_gate: { max_consecutive_failures: 3 }  # More patient with user interaction
    parallel_dispatch: { max_consecutive_failures: 1 }  # Fail fast for parallel tasks
```

### Files to Modify

- `skills/plan/references/orchestrator-loop.md` — Add CIRCUIT_BREAKER function definition
- `config/planning-config.yaml` — Add `circuit_breaker` section
- All phase reference files that include retry logic — Reference the shared pattern instead of ad-hoc retry instructions

### Effort

Low. Defining the pattern is the main work. Individual strategies already have retry logic — this unifies them under a single specification.

---

## 12. Summary Matrix and Implementation Order

### Impact vs. Effort Matrix

| # | Strategy | Flag Name | Source | Phases | Effort | Impact | Prerequisites |
|---|---|---|---|---|---|---|---|
| 1 | Two-Round MPA Deliberation | `s7_mpa_deliberation` | Owlex P1 | 4, 7 | Medium-High | High | — |
| 2 | Convergence Detection | `s8_convergence_detection` | Mysti P2 | 4, 7 | Low-Med | High | — (best with S1) |
| 3 | Multi-Strategy Collaboration | `s9_multi_strategy` | Mysti P1 + OMO | 4, 6b, 7 | Medium | High | S1 + S2 |
| 4 | Parallel Phase Dispatch | `s11_parallel_dispatch` | Owlex P1 | 8∥8b | Medium | Low-Med | Dependency verification |
| 5 | Team Presets | `s10_team_presets` | Owlex P2 | 4, 7 | Low | Medium | — |
| 6 | Inter-Phase Context Protocol | `a6_context_protocol` | §8 Gap + OMO | All | Low-Med | High | — |
| 7 | Proactive Risk & Mode Routing | (no flag) | Owlex P7 + SPARV | Pre-skill | Low | Low-Med | — |
| **8** | **Specify Gate** | `s12_specify_gate` | **SPARV + BMAD** | **3** | **Low-Med** | **High** | **—** |
| **9** | **Confidence-Gated Expert Review** | `s13_confidence_gated_review` | **DO + BMAD** | **6b** | **Low-Med** | **High** | **—** |
| — | Circuit Breaker (cross-cutting) | (no flag) | SPARV + BMAD | All | Low | Medium | — |

### Recommended Implementation Order

```
Phase A (Quick Wins — ship first):
  S7  Proactive Risk & Mode Routing ──── Low effort, immediate UX win + EHRB risk detection
  S8  Specify Gate ────────────────────── High impact on Phase 3 quality, no new agents
  S2  Convergence Detection ───────────── Highest analytical value per effort
  S6  Inter-Phase Context Protocol ────── Low effort, enriches all phases (Context Pack + Decision Propagation)
  CB  Circuit Breaker Pattern ─────────── Cross-cutting, unifies retry logic

Phase B (Core Improvements):
  S9  Confidence-Gated Expert Review ──── Structures Phase 6b output, reduces false positives
  S1  Two-Round MPA Deliberation ──────── Light variant first, full variant for Complete mode
  S5  Team Presets ────────────────────── balanced + rapid_prototype only

Phase C (Framework — after A+B stable):
  S3  Multi-Strategy Collaboration ────── Builds on S1+S2, adds Red-Team + signal-based override

Phase D (Optimization — after dependency audit):
  S4  Parallel Phase Dispatch ─────────── Phase 8||8b only, after verification
```

### Strategy Dependency Graph

```
              S7 (Routing Hooks)          S8 (Specify Gate)
                    │                           │
              [risk flags]              [specify_score signal]
                    │                           │
                    ▼                           ▼
S2 (Convergence) ──────────────── S1 (MPA Deliberation)
        │                                │
        └──────────┬─────────────────────┘
                   ▼
         S3 (Multi-Strategy)     S5 (Team Presets)
                   │                    │
                   └────────┬───────────┘
                            ▼
                   S9 (Expert Review)
                            │
                            ▼
                   S4 (Parallel Dispatch)

  S6 (Context Protocol) ──── feeds all strategies (cross-cutting)
  CB (Circuit Breaker) ────── unifies retry logic (cross-cutting)
```

**Reading the graph:** Arrows show data/config dependencies. S3 requires S1+S2 (hard dependency via `requires` flag). Other connections are soft dependencies (signal propagation, not blocking).

### Master File Change Log

When implementing a strategy with prerequisites, review the cumulative changes to shared files:

| File | Strategies | Cumulative Changes |
|---|---|---|
| `skills/plan/references/phase-4-architecture.md` | S1, S2, S3, S5 | (1) R2 dispatch or contradiction step, (2) convergence detection, (3) strategy selector, (4) preset-based agent dispatch |
| `skills/plan/references/phase-7-test-strategy.md` | S1, S2, S3, S5 | Same as phase-4 |
| `skills/plan/references/phase-6b-expert-review.md` | S3, S9 | (1) Red-Team strategy mode, (2) confidence scoring + tri-state output |
| `skills/plan/references/phase-3-clarification.md` | S8 | Scoring rubric, question banks, iteration logic |
| `skills/plan/references/orchestrator-loop.md` | S4, S6, CB | (1) Parallel dispatch, (2) Context Pack builder + decision accumulation, (3) circuit breaker function |
| `config/planning-config.yaml` | All | See consolidated Section 13 |
| `templates/phase-summary-template.md` | S6, S8 | (1) key_decisions/open_questions/risks_identified, (2) specify_score/specify_dimensions |
| `agents/software-architect.md` | S1 | Round 2 Awareness section |
| `agents/qa-strategist.md`, `qa-security.md`, `qa-performance.md` | S1 | Round 2 Awareness section |
| `agents/reviewers/simplicity-reviewer.md`, `security-analyst.md` | S9 | Confidence scoring guide + output format |
| `scripts/planning-hint.sh` | S7 | New file (hook script) |
| `skills/plan/references/mpa-strategies.md` | S3 | New file (shared strategy templates) |

### Why S8 and S9 are High Priority

The two new strategies from myclaude-master address gaps that compound across the workflow:

- **S8 (Specify Gate)** improves input quality to Phase 4. Better Phase 3 output means less divergence in MPA agents (reducing the need for expensive R2 deliberation), fewer open questions carrying into Phase 5, and more focused test strategies in Phase 7. It also feeds the signal-based override in S3.

- **S9 (Confidence-Gated Review)** improves Phase 6b signal-to-noise ratio. The tri-state output (Pass/Risk/Fail) eliminates the current binary gate that either blocks unnecessarily or passes silently. It also structures the expert review findings for propagation via S6's Context Protocol.

### Patterns Explicitly NOT Proposed

The following patterns were considered but rejected for the planning skill:

| Pattern | Source | Why Not |
|---|---|---|
| Terminal pane injection | CCB P1 | Planning skill runs within Claude Code, not across terminal panes |
| Sentinel-based response demarcation | CCB P2 | Already handled by `Task()` subagent protocol |
| Three-tier agent loading | Mysti P6 | Planning agents are loaded once per phase, not progressively; overhead is minimal |
| Context compaction | Mysti P7 | Coordinator subagents have fresh context per dispatch; orchestrator context is kept lean by design |
| Safety classifier chain | Mysti P4 | Planning skill does not perform autonomous actions that need safety classification |
| MCP permission intercept | Mysti P5 | Not applicable — no VSCode extension involved |
| Typed message contracts | §8 Gap | Contradicts the "operational simplicity" philosophy of this plugin ecosystem |
| Hierarchical agent teams | §8 Gap | Current flat coordination is sufficient; nesting adds complexity without clear benefit for planning |
| MCP progress notifications | Owlex P8 | Coordinators run as `Task()` subagents with no MCP progress channel back to the orchestrator. Claude Code does not surface MCP progress from subagents. Could be revisited if `Task()` adds progress callbacks. |
| Dynamic supervisor routing | §8 Gap | Strategy 3 (multi-strategy selection) and Strategy 5 (team presets) address this need through config-driven routing rather than runtime capability discovery. A full dynamic router adds complexity without clear benefit over static per-phase strategy mapping. |
| Delphi strategy | Mysti P1 | Redundant with PAL Consensus which already provides numeric gating for Phases 6 and 8. Variable rounds (up to 12 dispatches) add unpredictable latency. |
| Tool-sharing across agents | §8 Gap | Each agent uses `Task()` with its own tool permissions. Cross-agent tool delegation adds security surface without clear planning benefit. |
| codeagent-wrapper (Go binary) | myclaude | Planning skill delegates via `Task()` subagents, not external CLI binaries. The wrapper's topological sort for parallel tasks is elegant but `Task()` already handles concurrent dispatch. The backend abstraction registry (codex/claude/gemini/opencode) is interesting but we already have CLI dual-dispatch via Bash. |
| Git worktree isolation | myclaude DO | Planning is read-only — no code changes to isolate. Applicable to product-implementation but not product-planning. |
| 2-action auto-save hooks | myclaude SPARV | Planning state is persisted per-phase via summary files, not per-tool-call. The overhead of hook-based saves every 2 actions would add latency without proportional recovery benefit — phases are the natural checkpoint granularity. |
| 100-point scoring (BMAD) | myclaude BMAD | Adopted the 10-point scale (SPARV) instead. 100-point scales require fine-grained dimension weighting that LLM self-assessment cannot reliably distinguish (is this 82 or 87?). The 0/1/2 per dimension approach is more robust for LLM-based scoring. |
| Persona names for agents | myclaude BMAD | BMAD gives agents personas (Sarah the PO, Winston the Architect). This adds flavor but no analytical value. Our agents are role-defined, not persona-defined. |
| First-principles reasoning chain | myclaude memorys | Mandatory 5-step reasoning protocol for every non-trivial problem. Interesting but heavyweight — adds ~200 tokens of reasoning scaffolding per agent invocation. The UltraThink 3-step synthesis (adopted in Strategy 1) captures the useful core (insight integration + refinement + gap analysis) without the full protocol. |

---

## 13. Consolidated Config Changes

All proposed config changes merge under the existing YAML structure. This section shows the complete addition to prevent duplicate-key errors when applying snippets.

**Feature flag naming convention:**
- `s{N}_` prefix — **Strategy** flags that toggle a specific collaboration improvement (e.g., `s7_mpa_deliberation`, `s12_specify_gate`)
- `a{N}_` prefix — **Architectural** flags that change inter-phase communication or structural behavior (e.g., `a6_context_protocol`)
- Some strategies have **no runtime flag** (S7 Proactive Routing is a pre-skill hook script; Circuit Breaker is a behavioral spec with config-level thresholds). These are "always on" once deployed.
- Flag numbers are **not sequential with strategy numbers** — `s7_` through `s13_` were allocated to avoid collisions with existing plugin flags `s1_`–`s5_` and `a4_` (from the base planning-config.yaml).

**Cost/latency metadata:** The `cost_impact` and `latency_impact` fields are documented in each strategy's Feature Flag section (Sections 2-11) and are intentionally omitted from the YAML below for brevity. The YAML contains runtime configuration only.

```yaml
# =============================================================================
# MULTI-AGENT COLLABORATION IMPROVEMENTS (Proposal additions)
# =============================================================================
# All keys below merge into existing top-level sections.
# Do NOT create duplicate top-level keys — merge under existing ones.

# --- Merges under existing feature_flags: ---
feature_flags:
  # Strategy 1: Two-Round MPA Deliberation
  s7_mpa_deliberation:
    enabled: true
    description: "Cross-informed Round 2 for MPA agents before coordinator synthesis"
    rollback: "Set false to use single-round MPA (current behavior)"
    modes: [complete, advanced]
    requires: []

  # Strategy 2: Convergence Detection
  s8_convergence_detection:
    enabled: true
    description: "Heuristic convergence measurement before MPA synthesis. Most effective with s7_mpa_deliberation."
    rollback: "Set false to use fixed-weight synthesis (current behavior)"
    modes: [complete, advanced, standard]
    requires: []
    cost_impact: "Negligible — text analysis only"

  # Strategy 3: Multi-Strategy Collaboration
  s9_multi_strategy:
    enabled: true
    description: "Phase-specific collaboration strategy selection (Quick, Perspectives, Red-Team)"
    rollback: "Set false to use Quick strategy for all phases"
    modes: [complete, advanced]
    requires: [s7_mpa_deliberation, s8_convergence_detection]

  # Strategy 5: Team Presets
  s10_team_presets:
    enabled: true
    description: "User-selectable team presets for agent composition"
    rollback: "Set false to use mode-locked agent composition"
    modes: [complete, advanced, standard]
    requires: []

  # Strategy 4: Parallel Phase Dispatch
  s11_parallel_dispatch:
    enabled: false  # Disabled until Phase 8b dependency verified
    description: "Dispatch Phase 8 and Phase 8b concurrently"
    rollback: "Set false to use sequential dispatch"
    modes: [complete, advanced]
    requires: []

  # Strategy 6: Inter-Phase Context Protocol
  a6_context_protocol:
    enabled: true
    description: "Bidirectional inter-phase context: extended summaries (output) + mandatory Context Pack (input)"
    rollback: "Set false for ad-hoc coordinator prompts and standard summary format"
    modes: [complete, advanced, standard]
    requires: []

  # Strategy 8: Specify Gate
  s12_specify_gate:
    enabled: true
    description: "10-point requirement completeness gate for Phase 3 with iterative refinement"
    rollback: "Set false to use Phase 3 without quality gate"
    modes: [complete, advanced, standard]
    requires: []

  # Strategy 9: Confidence-Gated Expert Review
  s13_confidence_gated_review:
    enabled: true
    description: "Confidence scoring (>=80) + tri-state review output for Phase 6b"
    rollback: "Set false to use unstructured expert review"
    modes: [complete, advanced, standard]
    requires: []

# --- Merges under existing mpa: ---
mpa:
  deliberation:
    variant: light                # light | full
    round_2_mode: revise          # revise | critique (full variant only)
    per_phase_override:
      phase_4: revise
      phase_7: critique
    modes: [complete, advanced]

  convergence_detection:
    enabled: true
    # score >= 0.7: high convergence → quick synthesis
    threshold_high: 0.7
    # score >= 0.4 AND < 0.7: medium → standard synthesis
    # score < 0.4: low convergence → flag divergence for user
    threshold_low: 0.4
    agreement_weight: 0.6
    stability_weight: 0.4
    modes: [complete, advanced, standard]
    output_section: true

  strategies:
    quick:
      rounds: 1
      cross_review: false
    perspectives:
      rounds: 2
      cross_review: true
    red_team:
      rounds: 3
      cross_review: sequential
      severity_levels: [CRITICAL, MAJOR, MINOR]

  strategy_per_phase:
    phase_2: { default: quick, complete: perspectives }
    phase_4: { rapid: quick, standard: quick, advanced: perspectives, complete: perspectives }
    phase_6b: { default: red_team }
    phase_7: { rapid: quick, standard: quick, advanced: perspectives, complete: red_team }

  team_presets:
    balanced:
      description: "Default balanced analysis"
      phase_4_agents: [software-architect-minimal, software-architect-clean, software-architect-pragmatic]
      phase_7_agents: [qa-strategist, qa-security, qa-performance]
      phase_6b_agents: [security-analyst, simplicity-reviewer]
    rapid_prototype:
      description: "Minimal agent set"
      phase_4_agents: [software-architect-pragmatic]
      phase_7_agents: [qa-strategist]
      phase_6b_agents: []

  preset_suggestion:
    default: balanced

# --- Merges under existing state: ---
state:
  context_protocol:
    decision_propagation:
      enabled: true
      accumulate_from_summaries: [key_decisions, open_questions, risks_identified]
      inject_into_coordinator_prompt: true
      max_accumulated_tokens: 500
    context_pack:
      enabled: true
      mandatory_sections: [original_request, accumulated_context, current_task, acceptance_criteria]
      original_request_source: "state.feature_description"

# --- New top-level sections ---
orchestrator:
  parallel_dispatch:
    enabled: false
    modes: [complete, advanced]
    pairs:
      - phases: ["8", "8b"]
        shared_input: [".phase-summaries/phase-7-summary.md", "test-plan.md"]
        status: "pending_verification"

# Strategy 8: Specify Gate (from SPARV + BMAD)
specify_gate:
  enabled: true
  threshold: 8                 # Score >= 8 to proceed to Phase 4
  max_iterations: 3            # Max question rounds before proceeding
  low_score_threshold: 6       # Below this, flag for strategy escalation
  dimensions: [value, scope, acceptance, constraints, risk]
  points_per_dimension: 2
  modes: [complete, advanced, standard]

# Strategy 9: Confidence-Gated Expert Review (from DO + BMAD)
expert_review:
  confidence_threshold: 80
  severity_levels: [CRITICAL, MAJOR, MINOR]
  tri_state:
    pass: { max_critical: 0, max_major: 0 }
    pass_with_risk: { max_critical: 0 }
    fail: {}
  max_review_iterations: 2
  modes: [complete, advanced, standard]

# Cross-Cutting: Circuit Breaker (from SPARV + BMAD)
circuit_breaker:
  defaults:
    max_consecutive_failures: 2
    reset_on_success: true
  overrides:
    specify_gate: { max_consecutive_failures: 3 }
    parallel_dispatch: { max_consecutive_failures: 1 }
```

---

## 14. State File Impact

### Does Any Strategy Require State File v3 Migration?

**No.** None of the proposed strategies modify the state file schema. All new data flows through:

- **Config** (new YAML keys in `planning-config.yaml`) — read-only at runtime
- **Phase summaries** (extended with `key_decisions`, `open_questions`, `risks_identified`) — these are output artifacts, not part of the state file
- **Feature flags** (new `s7_`–`s13_`, `a6_`, and cross-cutting flags) — stored in config, not state

The state file's `version: 2` schema remains unchanged. The only state-level additions are:

- `state.preset` (string) — the selected team preset name, stored alongside `state.analysis_mode`
- `state.orchestrator.parallel_pairs_completed` (array) — tracking which parallel pairs finished, for resume
- `state.specify_score` (integer, 0-10) — Phase 3 specify gate score (Strategy 8)
- `state.specify_dimensions` (object) — Per-dimension scores from Phase 3 (Strategy 8)
- `state.expert_review_outcome` (string: pass/pass_with_risk/fail) — Phase 6b tri-state result (Strategy 9)
- `state.risk_flags` (array) — EHRB risk categories detected pre-skill (Strategy 7)

These are additive fields that do not break v2 compatibility. The existing v1→v2 migration logic handles missing fields gracefully (defaults to null). A v2→v3 migration is NOT required — new fields use the same graceful-default pattern.

### Mid-Session Flag Enablement

If a user enables a feature flag mid-session (e.g., enables `s7_mpa_deliberation` after Phase 4 already completed):

- **Completed phases are not re-run.** The flag applies only to phases not yet started.
- This may create asymmetric behavior (Phase 4 without R2, Phase 7 with R2). This is acceptable — the alternative (re-running completed phases) would discard approved user decisions.

---

## Appendix: Quick Reference Card

| # | Strategy | Flag | Config Key | Key Files | Prerequisites | Effort | Phase |
|---|---|---|---|---|---|---|---|
| S1 | Two-Round MPA Deliberation | `s7_mpa_deliberation` | `mpa.deliberation` | phase-4, phase-7, software-architect, qa-* | — | Med-High | B |
| S2 | Convergence Detection | `s8_convergence_detection` | `mpa.convergence_detection` | phase-4, phase-7 | — (best w/ S1) | Low-Med | A |
| S3 | Multi-Strategy Collaboration | `s9_multi_strategy` | `mpa.strategies`, `mpa.strategy_per_phase` | phase-4, phase-6b, phase-7, mpa-strategies.md (new) | S1 + S2 | Medium | C |
| S4 | Parallel Phase Dispatch | `s11_parallel_dispatch` | `orchestrator.parallel_dispatch` | orchestrator-loop, phase-8b | Dependency audit | Medium | D |
| S5 | Team Presets | `s10_team_presets` | `mpa.team_presets` | phase-1, phase-4, phase-7 | — | Low | B |
| S6 | Inter-Phase Context Protocol | `a6_context_protocol` | `state.context_protocol` | orchestrator-loop, summary template, all phase refs | — | Low-Med | A |
| S7 | Proactive Risk & Mode Routing | (no flag) | — | scripts/planning-hint.sh (new) | — | Low | A |
| S8 | Specify Gate | `s12_specify_gate` | `specify_gate` | phase-3, summary template | — | Low-Med | A |
| S9 | Confidence-Gated Expert Review | `s13_confidence_gated_review` | `expert_review` | phase-6b, reviewers/* | — | Low-Med | B |
| CB | Circuit Breaker | (no flag) | `circuit_breaker` | orchestrator-loop | — | Low | A |

---

*End of proposal. Last updated: 2026-02-20 (v2 — consolidated with myclaude-master patterns: SPARV, BMAD, DO, OMO).*
