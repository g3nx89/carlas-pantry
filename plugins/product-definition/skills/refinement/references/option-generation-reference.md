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

## 2. Recommendation Scoring Algorithm

```
RECOMMENDATION SCORING (per option):

1. PRD_COMPLETENESS_SCORE (0-25 points)
   - Does this option provide clear PRD content? (+5)
   - Does it resolve ambiguity in the draft? (+5)
   - Does it define clear boundaries (is/is not)? (+5)
   - Does it enable measurable success criteria? (+5)
   - Does it avoid technical implementation details? (+5)

2. THINKDEEP_ALIGNMENT_SCORE (0-25 points)
   +------------------------------------------------------------+
   | MPA agents have ThinkDeep insights when scoring options:    |
   |                                                             |
   | - Competitive: Does it address market gaps identified by    |
   |   ThinkDeep? (+8)                                           |
   |                                                             |
   | - Risk: Does it mitigate risks flagged by all 3 models? (+8)|
   |                                                             |
   | - Contrarian: Does it survive devil's advocate challenges   |
   |   raised in ThinkDeep? (+9)                                 |
   +------------------------------------------------------------+

3. MULTI_PERSPECTIVE_SCORE (0-25 points)
   - Product Strategy alignment (+8)
   - User Experience alignment (+8)
   - Business Operations alignment (+9)

4. INDUSTRY_PRACTICE_SCORE (0-25 points)
   - Follows established patterns? (+10)
   - Proven in similar products? (+10)
   - Sustainable long-term? (+5)

TOTAL SCORE -> STAR RATING:
   See config -> scoring.star_rating.*

   90-100: 5 stars (Recommended)
   75-89:  4 stars
   60-74:  3 stars
   40-59:  2 stars
   0-39:   1 star

RULE: Exactly ONE option per question gets "(Recommended)" label

THINKDEEP INTEGRATION RULES:
-----------------------------------------------------------------
- If ThinkDeep CONVERGENT (all 3 models agree on a risk):
  -> Option that mitigates it gets +5 bonus
  -> Option that ignores it gets -5 penalty

- If ThinkDeep DIVERGENT (models disagree):
  -> Generate options representing EACH model's perspective
  -> Let user decide based on their context
```

## 3. Synthesis Merging Logic

When the synthesis agent merges questions from 3 MPA agents:

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

MULTI-PERSPECTIVE CONTEXT:
  [target] Product Strategy: "Recurring revenue enables predictable growth"
  [user] User Experience: "Subscription fatigue is real - consider value perception"
  [briefcase] Business Ops: "Usage-based requires metering infrastructure"
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

> This section is design documentation — not needed during execution.
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
|  Stage 3 Part B: MPA Agents (3 parallel) - WITH ThinkDeep Insights          |
|  =========================================================================  |
|                                                                             |
|  +-----------------+  +-----------------+  +-----------------------------+  |
|  | Product Strategy|  | User Experience |  | Business Operations         |  |
|  | Agent           |  | Agent           |  | Agent                       |  |
|  |                 |  |                 |  |                             |  |
|  | INPUT:          |  | INPUT:          |  | INPUT:                      |  |
|  | - Draft         |  | - Draft         |  | - Draft                     |  |
|  | - Research      |  | - Research      |  | - Research                  |  |
|  | - ThinkDeep <---+--+-----------------+--+-- INSIGHTS INFORM OPTIONS   |  |
|  |                 |  |                 |  |                             |  |
|  | Questions focus:|  | Questions focus:|  | Questions focus:            |  |
|  | - Vision        |  | - Personas      |  | - Constraints               |  |
|  | - Market        |  | - Pain points   |  | - Compliance                |  |
|  | - Business model|  | - Journeys      |  | - Operations                |  |
|  +--------+--------+  +--------+--------+  +-----------------+-----------+  |
|           |                    |                             |              |
+-----------+--------------------+-----------------------------+--------------+
            |                    |                             |
            +--------------------+-----------------------------+
                                 |
                                 v
              +-------------------------------+
              | Question Synthesis Agent      |
              | (Sequential Thinking)         |
              |                               |
              | - Deduplicates questions      |
              | - Merges options from all     |
              | - Recalculates recommendations|
              | - Adds multi-perspective ctx  |
              +---------------+---------------+
                              |
                              v
              +-------------------------------+
              | QUESTIONS-{NNN}.md            |
              | (12-18 deduplicated questions)|
              | WITH THINKDEEP-INFORMED       |
              | OPTIONS AND PRIORITIES        |
              +-------------------------------+
```
