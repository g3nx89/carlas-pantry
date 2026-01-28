# Product Draft: {PRODUCT_NAME}

> **Version:** 0.1 (Draft)
> **Date:** {DATE}
> **Author:** {AUTHOR}

---

## How to Use This Template

This template guides you in writing the initial draft to generate a complete PRD.

### Golden Rules

1. **Describe what the user SEES and DOES**, not how the system works internally
2. **It's okay not to know everything** - the "Doubts and Uncertainties" section is valuable
3. **Better brief and honest** than long and vague
4. **No need to prioritize** - priorities will emerge from the questions

### Structure

| Part | Sections | Required? | Time |
|------|----------|-----------|------|
| **1. Essential** | 3 | ✅ Yes | ~5 min |
| **2. Definition** | 3 | 🔶 Recommended | ~10 min |
| **3. Details** | 6 | ⚪ Optional | ~15 min |

**Minimum to start:** Complete only Part 1 (~5 minutes)

---

# PART 1: ESSENTIAL

> ✅ **Required** - Without this information we cannot generate useful questions.

---

## 1.1 Vision Statement

**What to write:** In 1-2 sentences, what does this product do? What is the core idea?

**Good example:**
> "A mobile app that helps people track daily expenses and understand where their money goes."

**Example to avoid:**
> ❌ "A cross-platform application developed in React Native with serverless backend that uses machine learning to categorize transactions."

---

**Your Vision Statement:**

<!-- Write 1-2 sentences describing the product here -->



---

## 1.2 Problem to Solve

**What to write:** What real problem does this product solve? Why does this problem exist? Who suffers from it?

**Good example:**
> "People lose track of small daily expenses (coffee, lunches, subscriptions). At the end of the month they don't understand where the money went. This causes financial stress and inability to save."

**Example to avoid:**
> ❌ "The problem is that there is no unified API to aggregate banking data with latency under 100ms."

---

**The problem you solve:**

<!-- Describe the problem from the user's point of view, not technical -->



---

## 1.3 Who Uses It (and Who Doesn't)

**What to write:** Who is the primary user? And equally important: who is NOT the target?

### Target User (Who YES)

**Good example:**
> "Young professionals (25-40 years old) who have a salary but struggle to save. They use their smartphone daily and are open to digital tools for managing finances."

---

**Your target user:**

<!-- Who will use this product? Be specific. -->



---

### Anti-Target (Who NOT)

**Good example:**
> "NOT for: finance experts who already use advanced Excel, people without smartphones, companies (it's B2C only), those seeking professional financial advice."

---

**Who is NOT the target:**

<!-- Who explicitly should NOT use this product? -->



---

# PART 2: DEFINITION

> 🔶 **Strongly recommended** - Significantly improves the quality of generated questions.

---

## 2.1 What It Is / What It Is NOT

**What to write:** Define the product boundaries. What does it include? What does it explicitly exclude?

| What It Is | What It Is NOT |
|------------|----------------|
| *Example: App for tracking personal expenses* | *Example: NOT enterprise accounting software* |
| *Example: Tool for financial awareness* | *Example: NOT an automated financial advisor* |
| *Example: Mobile-first* | *Example: NOT a desktop app* |

---

**Your Is/Is Not table:**

| What It Is | What It Is NOT |
|------------|----------------|
| | |
| | |
| | |
| | |

---

## 2.2 Value Proposition

**What to write:** Why would someone use this product instead of alternatives? What makes it unique or better?

**Good example:**
> "Unlike banking apps that only show transactions, we automatically categorize expenses and show weekly trends with actionable suggestions. It's like having a friend who tells you 'hey, you spent 40% more on restaurants this month'."

**Example to avoid:**
> ❌ "We use more advanced ML algorithms than competitors with a scalable microservices architecture."

---

**Your value proposition:**

<!-- Why would a user choose you? What differentiates you? -->



---

## 2.3 Doubts and Uncertainties

> ⭐ **Most valuable section!** Here you explicitly state what you DON'T know yet. This guides the questions.

**What to write:** What are your doubts? What assumptions are you making that might be wrong? What would you like to validate?

**Good example:**
> "I'm not sure if:
> - Users will prefer entering expenses manually or connecting their bank account
> - The freemium model will work or if direct subscription is needed
> - I should support shared expenses (e.g., roommates) or only personal
> - The target is Italy only or other EU countries too (different GDPR implications)
>
> Assumptions I'm making:
> - Users are willing to spend 5 min/day tracking expenses
> - Automatic categorization will be at least 80% accurate"

---

**Your doubts and uncertainties:**

<!-- Be honest: what DON'T you know? What are your assumptions? -->



---

# PART 3: DETAILS

> ⚪ **Optional** - For more mature drafts or when you already have clearer ideas.

---

## 3.1 Main Workflows

**What to write:** Describe the 2-3 most important user journeys. What does the user do step by step?

**Good example:**
> "**Workflow 1: Adding an expense**
> 1. User opens the app
> 2. Taps the '+' button
> 3. Enters amount (e.g., €4.50)
> 4. Selects or confirms suggested category (e.g., 'Coffee')
> 5. Optionally adds a note
> 6. Saves
> 7. Sees the expense added to the daily summary"

**Example to avoid:**
> ❌ "The user makes a POST request to the /expenses endpoint with JSON payload containing amount, category_id, and timestamp..."

---

**Your main workflows:**

<!-- Describe 2-3 key user journeys. What does the user DO? -->



---

## 3.2 Feature Ideas

**What to write:** Rough list of features you imagine. No need to prioritize now.

**Good example:**
> - Manual expense entry
> - Automatic categorization
> - Dashboard with weekly/monthly expenses
> - Charts by category
> - Monthly budget with alerts
> - Data export
> - Daily reminder to enter expenses
> - Dark mode
> - Multi-currency support (for travel)

---

**Your feature ideas:**

<!-- List everything that comes to mind - don't filter -->

-
-
-
-
-

---

## 3.3 Imagined Screens

**What to write:** Describe the main screens you imagine. What does the user SEE?

**Good example:**
> "**Home Screen:**
> - Top: total monthly balance and how much is left until budget
> - Center: list of last 5 expenses with category icon
> - Bottom: large '+' button to add expense
> - Tab bar with: Home, Statistics, Settings"

**Example to avoid:**
> ❌ "React component with state management via Redux, API call with React Query, styling with Tailwind..."

---

**Your imagined screens:**

<!-- Describe 2-4 key screens. What does the user SEE? -->



---

## 3.4 Business Context

**What to write:** How do you plan to monetize? Who pays? Do you have pricing ideas?

**Good example:**
> "I'm thinking of a freemium model:
> - FREE: basic tracking, max 50 expenses/month, 1 month history
> - PREMIUM ($2.99/month): unlimited, export, multiple budgets, device sync
>
> Target: 5% free→premium conversion
>
> Not ruling out bank partnerships for white-label version in future."

---

**Your business context:**

<!-- How do you monetize? Who pays? Pricing ideas? -->



---

## 3.5 Existing Alternatives

**What to write:** How do users solve this problem today? What competitors or alternatives exist?

**Good example:**
> "Today users:
> - Use Excel/Google Sheets (powerful but tedious)
> - Use their bank's app (only transactions, no insights)
> - Don't track at all (the majority)
>
> Direct competitors:
> - Mint (USA, not available in Italy)
> - Money Manager (dated UI, too many features)
> - Wallet by BudgetBakers (good but complex)
>
> Our differentiator: extreme simplicity, focus on actionable insights."

---

**Existing alternatives:**

<!-- How do they solve the problem today? Who are competitors? -->



---

## 3.6 Known Constraints

**What to write:** What constraints do you already know? Budget, timeline, team, legal requirements, known technical limitations?

**Good example:**
> "Constraints:
> - Budget: €50k for MVP
> - Timeline: beta launch within 6 months
> - Team: 2 developers, 1 part-time designer
> - Legal: GDPR compliance mandatory (sensitive financial data)
> - Tech: must work offline (users in subway without connection)
> - Business: no banking partnerships for MVP (too complex)"

---

**Your known constraints:**

<!-- Budget? Timeline? Team? Legal requirements? Limitations? -->



---

# Additional Notes

**Any other relevant information that doesn't fit in the sections above:**

<!-- Free space for notes, links, references, inspirations... -->



---

## Completion Checklist

Before saving, verify:

### Part 1 (Required)
- [ ] 1.1 Vision Statement completed
- [ ] 1.2 Problem to Solve completed
- [ ] 1.3 Target User AND Anti-Target completed

### Part 2 (Recommended)
- [ ] 2.1 Is/Is Not table with at least 3 rows
- [ ] 2.2 Clear Value Proposition
- [ ] 2.3 At least 3 doubts/uncertainties listed

### Part 3 (Optional)
- [ ] 3.1 At least 1 workflow described
- [ ] 3.2 At least 5 feature ideas
- [ ] 3.3 At least 2 screens described
- [ ] 3.4 Business model outlined
- [ ] 3.5 At least 2 alternatives/competitors
- [ ] 3.6 Main constraints listed

---

## Next Steps

1. **Save this file** to `requirements/draft/{product-name}-draft.md`
2. **Run** `/product-definition:requirements {product-name}-draft.md`
3. **Answer** the generated questions in `requirements/working/QUESTIONS-*.md`
4. **Iterate** until PRD is complete

---

> **Remember:** This draft is just the beginning. The system will generate questions to explore each area. You don't need to be perfect now - you need to be honest about what you know and what you don't know.
