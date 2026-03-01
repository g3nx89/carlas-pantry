# Option Generation Reference

> This reference explains HOW questions, options, pros/cons, and recommendations are generated
> in the Requirements Refinement workflow (Stage 3).
>
> **Sections are ordered by runtime priority:** Scoring and merging logic first (used during execution),
> pipeline overview last (design documentation).

## 1. How Options Are Generated

Each MPA agent generates options using this process:

```
For each identified question:

1. OPTION GENERATION (minimum 3 options):
   +-------------------------------------------------------------+
   | Option A: Mainstream/Conservative approach                   |
   |   -> Most common industry practice                           |
   |   -> Lower risk, proven patterns                             |
   |                                                              |
   | Option B: Alternative/Balanced approach                      |
   |   -> Different trade-off balance                             |
   |   -> Middle ground between extremes                          |
   |                                                              |
   | Option C: Innovative/Aggressive approach                     |
   |   -> More ambitious or unconventional                        |
   |   -> Higher risk, potentially higher reward                  |
   |                                                              |
   | Option D: "Other (custom answer)" (always present)           |
   |   -> User provides custom answer                             |
   +-------------------------------------------------------------+

2. PROS/CONS ANALYSIS (for each option):
   +-------------------------------------------------------------+
   | PRO: Specific, measurable benefits                           |
   |   - "Reduces time-to-market by 30%"                          |
   |   - "Compatible with existing infrastructure"                |
   |   - "Low customer acquisition cost"                          |
   |                                                              |
   | CON: Specific, measurable drawbacks                          |
   |   - "Requires third-party partnerships"                      |
   |   - "Lower margins in short term"                            |
   |   - "Steeper learning curve"                                 |
   +-------------------------------------------------------------+

3. RECOMMENDATION (star rating):
   +-------------------------------------------------------------+
   | 5 stars (Recommended) = Best fit for:                        |
   |   - PRD completeness                                         |
   |   - Risk/reward balance                                      |
   |   - Industry best practices                                  |
   |   - ThinkDeep convergent insights                            |
   |                                                              |
   | 4 stars = Strong alternative                                 |
   | 3 stars = Viable but with trade-offs                         |
   | 2 stars = Risky or niche                                     |
   | 1 star  = Not recommended (but valid choice)                 |
   +-------------------------------------------------------------+
```

## 2. Recommendation Scoring -- Behavioral Anchors

Use behavioral anchors to assign star ratings. Assess each option holistically rather than summing sub-scores.

| Stars | Behavioral Anchor |
|-------|-------------------|
| 5 | Convergent ThinkDeep insight + industry best practice. Clear PRD content. Low risk. In Standard/Rapid mode (no ThinkDeep): industry best practice with strong PRD coverage and low risk. |
| 4 | Strong approach with one known trade-off. Addresses most panel concerns. |
| 3 | Viable with 2+ trade-offs. Acceptable if context-specific. |
| 2 | Significant gaps in PRD coverage. Notable risks. |
| 1 | Does not address the question's uncertainty. |

**Rule:** Exactly ONE option per question gets "(Recommended)" label.

**ThinkDeep integration rules:**
- If ThinkDeep CONVERGENT (all 3 models agree on a risk): option that mitigates it gets +1 star bonus; option that ignores it gets -1 star penalty
- If ThinkDeep DIVERGENT (models disagree): generate options representing each model's perspective; let user decide based on their context

## 3. Synthesis Merging Logic

When the synthesis agent merges questions from N panel member agents:

```
DEDUPLICATION RULES:
-----------------------------------------------------------------
If 2+ agents ask semantically similar questions:
  1. Keep the CLEAREST framing (most actionable)
  2. MERGE all unique options from all sources
  3. COMBINE pros/cons (avoid duplicates)
  4. RECALCULATE recommendation based on merged data
  5. ADD multi-perspective insight section

EXAMPLE MERGE:
-----------------------------------------------------------------
Product Strategy asks: "What's our primary revenue model?"
  Options: A) SaaS subscription, B) One-time purchase, C) Freemium

Business Ops asks: "How will the product generate revenue?"
  Options: A) Monthly subscription, B) Annual license, C) Usage-based

MERGED QUESTION: "What is the primary revenue model?"
  Options:
    A) SaaS subscription (monthly/annual) - from PS + BO
    B) One-time purchase/perpetual license - from PS + BO
    C) Freemium with premium tiers - from PS
    D) Usage-based pricing - from BO
    E) Other (custom answer)

MULTI-PERSPECTIVE CONTEXT (dynamic -- one line per panel member):
  [target] Product Strategy: "Recurring revenue enables predictable growth"
  [user] User Experience: "Subscription fatigue is real - consider value perception"
  [magnifier] Functional Analysis: "Usage-based requires metering workflows"
```

## 4. ThinkDeep -> Question Priority

```
PRIORITY ASSIGNMENT FROM THINKDEEP:
-----------------------------------------------------------------

CRITICAL Priority (all 3 perspectives + all 3 models flagged):
  -> Question MUST be answered for valid PRD
  -> Example: "Is the target market B2B or B2C?"
    (Competitive: defines competitors)
    (Risk: different risk profiles)
    (Contrarian: challenges both assumptions)

HIGH Priority (2+ perspectives OR model divergence):
  -> Question significantly impacts PRD quality
  -> Example: "What's the MVP scope boundary?"
    (Competitive: defines launch timing)
    (Contrarian: questions if MVP is viable)

MEDIUM Priority (1 perspective OR refinement):
  -> Question improves PRD completeness
  -> Example: "What's the secondary persona?"
    (UX: expands user understanding)
```

## 5. Example Question Format

This is the complete format for questions in `QUESTIONS-{NNN}.md`:

```markdown
## Q-003: What is the primary revenue model? [CRITICAL]

**ThinkDeep Insights:**
- [red] COMPETITIVE: All 3 models agree subscription fatigue is a market risk
- [yellow] RISK: gpt-5.2 and gemini flag cash flow concerns with one-time purchases
- [green] CONTRARIAN: grok-4 challenges whether any revenue model works without scale

**Multi-Perspective Context:**
- [target] Product Strategy: "Recurring revenue enables predictable growth"
- [user] User Experience: "Consider subscription fatigue"
- [briefcase] Business Ops: "Usage-based requires metering infrastructure"

### Options:

- [ ] **A) SaaS subscription (monthly/annual)** 5-stars (Recommended)
  - PRO: Predictable revenue, customer retention focus
  - CON: Subscription fatigue (flagged by ThinkDeep)
  - [target] Addresses: Market gap for flexible pricing
  - [warning] Mitigates: Cash flow risk

- [ ] **B) One-time purchase** 3-stars
  - PRO: No commitment barrier, simpler billing
  - CON: Cash flow unpredictability (ThinkDeep RISK flag)
  - [warning] Does NOT mitigate cash flow risk

- [ ] **C) Freemium with premium tiers** 4-stars
  - PRO: Low barrier to entry, upsell potential
  - CON: Requires scale for conversion rates
  - [target] Addresses: Market entry concerns

- [ ] **D) Other (custom answer)**
  ```
  [Your custom answer here]
  ```

### Notes:
[Add any context or reasoning for your choice]
```

## 6. Question Generation Pipeline (Design Overview)

> This section is design documentation -- not needed during execution.
> Included for understanding the end-to-end flow.

```
+-----------------------------------------------------------------------------+
|                    ANSWER & RECOMMENDATION CREATION FLOW                     |
+-----------------------------------------------------------------------------+

                              DRAFT.md
                                 |
                                 v
+-----------------------------------------------------------------------------+
|  Stage 3 Part A: PAL ThinkDeep (27 calls, 3 steps each) - RUNS FIRST       |
|  =========================================================================  |
|                                                                             |
|  +-----------------+  +-----------------+  +-----------------+              |
|  |  COMPETITIVE    |  |     RISK        |  |   CONTRARIAN    |              |
|  |  x 3 models     |  |   x 3 models    |  |   x 3 models    |              |
|  |  (gpt-5.2,      |  |   (gpt-5.2,     |  |   (gpt-5.2,     |              |
|  |  gemini, grok)  |  |   gemini, grok) |  |   gemini, grok) |              |
|  +--------+--------+  +--------+--------+  +--------+--------+              |
|           |                    |                    |                        |
|           +--------------------+--------------------+                        |
|                                |                                             |
|                                v                                             |
|                   thinkdeep-insights.md                                      |
|                   - Convergent findings (high confidence)                    |
|                   - Divergent findings (need questions)                      |
|                   - Priority assignments                                     |
+---------------------------------+-------------------------------------------+
                                  |
                    ==============+==============
                    ||   CHECKPOINT (Stage 3A) ||
                    ==============+==============
                                  |
                                  v
+-----------------------------------------------------------------------------+
|  Stage 3 Part B: Dynamic Panel Dispatch - WITH ThinkDeep Insights           |
|  =========================================================================  |
|                                                                             |
|  Panel members loaded from requirements/.panel-config.local.md              |
|  Each member uses the parametric template: requirements-panel-member.md     |
|                                                                             |
|  +-------------------+  +-------------------+      +-------------------+   |
|  | Panel Member 1    |  | Panel Member 2    | ...  | Panel Member N    |   |
|  | (e.g. Product     |  | (e.g. UX          |      | (e.g. Domain      |   |
|  |  Strategist)      |  |  Researcher)      |      |  Expert)          |   |
|  |                   |  |                   |      |                   |   |
|  | INPUT:            |  | INPUT:            |      | INPUT:            |   |
|  | - Draft           |  | - Draft           |      | - Draft           |   |
|  | - Research        |  | - Research        |      | - Research        |   |
|  | - ThinkDeep <-----+--+-------------------+------+- INSIGHTS         |   |
|  | - Domain Guidance |  | - Domain Guidance |      | - Domain Guidance |   |
|  | - Custom Steps    |  | - Custom Steps    |      | - Custom Steps    |   |
|  +--------+----------+  +--------+----------+      +--------+----------+   |
|           |                      |                           |             |
+-----------+----------------------+---------------------------+-------------+
            |                      |                           |
            +----------------------+---------------------------+
                                   |
                                   v
              +-------------------------------+
              | Question Synthesis Agent      |
              | (Sequential Thinking)         |
              |                               |
              | - Reads N input files         |
              | - Deduplicates questions      |
              | - Merges options from all     |
              | - Recalculates recommendations|
              | - Adds multi-perspective ctx  |
              +---------------+---------------+
                              |
                              v
              +-------------------------------+
              | QUESTIONS-{NNN}.md            |
              | (deduplicated questions)      |
              | WITH THINKDEEP-INFORMED       |
              | OPTIONS AND PRIORITIES        |
              +-------------------------------+
```
