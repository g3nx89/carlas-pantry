# ThinkDeep Templates

> Templates for PAL ThinkDeep calls in Stage 3 Part A.
> Load when: Starting ThinkDeep execution in `stage-3-analysis-questions.md` Step 3A.2.

---

## PROBLEM_CONTEXT_TEMPLATE (Use for All Perspectives)

```
IMPORTANT: This is a BUSINESS/PRD ANALYSIS, not code analysis.
We are evaluating market viability for a new product concept.
No source code exists yet - this is the requirements gathering phase.
Please analyze from a product strategy perspective, not engineering.

PRODUCT SUMMARY:
{Extract from draft: Vision, Problem, Target Users, Value Prop - 5-10 lines}
```

---

## Step Content Templates

### COMPETITIVE

```
I'm analyzing the competitive landscape for {PRODUCT_NAME}.

MY CURRENT ANALYSIS:
{List 3-5 existing alternatives with assessment}

MY INITIAL THINKING:
- {Hypothesis about market gaps}
- {Hypothesis about positioning}

EXTEND MY ANALYSIS:
1. Identify competitors I may have missed
2. Analyze if existing players could easily add this feature
3. Evaluate the strength of the proposed positioning
4. Identify positioning opportunities and risks
```

### RISK

```
I'm analyzing BUSINESS RISKS for {PRODUCT_NAME}.

MY CURRENT RISK ASSESSMENT:
{Identified risks from draft}

MY INITIAL THINKING:
- {Hypothesis about highest-impact risks}
- {Hypothesis about weakest assumptions}

EXTEND MY RISK ANALYSIS:
1. What critical business risks am I missing?
2. Which assumptions are most likely WRONG?
3. What could cause complete failure?
4. How should risks be prioritized?
```

### CONTRARIAN

```
I need you to be a DEVIL'S ADVOCATE for {PRODUCT_NAME}.

THE CURRENT PROPOSAL:
{Brief summary of vision, problem, solution}

ASSUMPTIONS BEING MADE:
{List from draft}

CHALLENGE EVERYTHING:
1. Why might this problem NOT be worth solving?
2. Why might target users NOT pay?
3. What fundamental flaw might doom this?
4. What are we refusing to see?
5. Is there a simpler solution?
```

---

## Findings Templates

Use these as the `findings` parameter for the initial ThinkDeep call (step 1) of each perspective:

- **COMPETITIVE:** "Initial assessment: {Summary from draft}. Existing solutions are {characterization}."
- **RISK:** "Initial risk inventory: {N} major categories. Draft acknowledges doubts about {X}."
- **CONTRARIAN:** "The proposal assumes {list}. Strongest point: {X}. Weakest point: {Y}."
