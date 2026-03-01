# Panel Builder Protocol

> Reference for the Panel Builder agent. Governs domain detection, preset selection,
> panel composition, domain guidance generation, and validation rules.

---

## 1. Domain Signal Detection

Scan the draft for keywords and patterns to classify the product domain.
Use the **first matching** signal category (ordered by specificity):

| Signal Category | Keywords / Patterns | Domain Classification |
|-----------------|--------------------|-----------------------|
| Marketplace | "marketplace", "two-sided", "buyer/seller", "supply and demand", "listing", "commission" | `marketplace` |
| Regulated / Enterprise | "compliance", "GDPR", "HIPAA", "audit", "enterprise", "B2B", "SaaS platform", "SOC 2" | `enterprise` |
| Consumer App | "app", "mobile", "consumer", "B2C", "download", "subscription", "freemium", "social" | `consumer` |
| E-commerce | "e-commerce", "shop", "cart", "checkout", "catalog", "inventory", "shipping" | `consumer` (with e-commerce domain expert) |
| Developer Tools | "SDK", "API", "developer", "integration", "plugin", "CLI", "documentation" | `enterprise` (with dev-tools domain expert) |
| Content / Media | "content", "creator", "media", "streaming", "publishing", "editorial" | `consumer` (with content domain expert) |
| HealthTech | "health", "patient", "clinical", "wellness", "telemedicine", "medical" | `enterprise` (with health domain expert) |
| FinTech | "payment", "banking", "finance", "wallet", "transaction", "lending" | `enterprise` (with fintech domain expert) |
| EdTech | "education", "learning", "course", "student", "teacher", "curriculum" | `consumer` (with edtech domain expert) |
| Food & Beverage | "food", "restaurant", "delivery", "menu", "kitchen", "recipe", "pantry" | `consumer` (with F&B domain expert) |
| General / Unclear | No strong signals | `product-focused` (default) |

**Rules:**
- If multiple categories match, prefer the more specific one (e.g., FinTech over Enterprise)
- If the draft explicitly mentions a domain, use that over keyword detection
- Record detected signals in the panel rationale section

---

## 2. Panel Presets

Each preset defines a default panel composition. The Panel Builder can customize
individual members within a preset (e.g., replacing `domain-expert` role/focus).

| Preset | Members | When to Use |
|--------|---------|-------------|
| `product-focused` | product-strategist, ux-researcher, functional-analyst | Default for any project. Balanced coverage. |
| `consumer` | product-strategist, ux-researcher, growth-specialist | Consumer-facing apps, B2C, mobile-first |
| `marketplace` | product-strategist, ux-researcher, marketplace-dynamics, growth-specialist | Two-sided marketplaces, platforms |
| `enterprise` | product-strategist, ux-researcher, compliance-regulatory | B2B, regulated industries, SaaS enterprise |
| `custom` | User selects from available_perspectives | When no preset fits |

**Weight distribution rules:**
- 2 members: 0.50 / 0.50
- 3 members: 0.35 / 0.35 / 0.30
- 4 members: 0.30 / 0.30 / 0.20 / 0.20
- 5 members: 0.25 / 0.25 / 0.20 / 0.15 / 0.15

The first two slots (typically product-strategist + ux-researcher) get the highest weights.
Weights must sum to exactly 1.0.

---

## 3. Available Perspectives Registry

The full registry lives in `config/requirements-config.yaml` under `panel.available_perspectives`.
Each perspective provides:

| Field | Description |
|-------|-------------|
| `id` | Unique identifier (matches config key) |
| `role` | Human-readable role title |
| `perspective_name` | Label used in multi-perspective analysis sections |
| `question_prefix` | 3-letter prefix for question IDs (e.g., PSQ, UXQ) |
| `default_weight` | Default scoring weight (adjusted by Panel Builder based on panel size) |
| `focus_areas` | List of analysis domains for this perspective |
| `prd_section_targets` | PRD sections this perspective primarily informs |

**Special: `domain-expert`**
The `domain-expert` perspective is a template. The Panel Builder must customize:
- `role`: Specific to the detected domain (e.g., "F&B Operations Specialist")
- `perspective_name`: Domain-specific label (e.g., "F&B Operations")
- `question_prefix`: Domain-specific prefix (e.g., "FBQ")
- `focus_areas`: 3-5 domain-specific focus areas
- `prd_section_targets`: Most relevant PRD sections for this domain

---

## 4. Domain Guidance Generation Protocol

For each panel member, generate a `domain_guidance` block (15-25 lines) and
5 custom `analysis_steps`. These are the primary vehicles for domain knowledge injection.

### 4.1 Domain Guidance Block

The domain guidance block tells the panel member HOW to think about the product
within its domain context. Structure:

```
You are analyzing a {DOMAIN_DESCRIPTION} product.
Key domain patterns to consider:
- {Pattern 1 relevant to this perspective's focus areas}
- {Pattern 2}
- {Pattern 3}
- {Pattern 4}
- {Pattern 5}
When generating questions, ground them in {domain} realities.
Reference competitors only if you are highly confident they exist.
Focus on {domain}-specific success metrics ({list 3-4 metrics}).
```

**Rules:**
- Keep to 15-25 lines max
- Ground in the draft's actual content -- don't invent context not in the draft
- Be specific to BOTH the domain AND the perspective (a UX researcher's domain guidance
  differs from a product strategist's even for the same domain)

### 4.2 Analysis Steps (Steps 1-5)

Each panel member gets 5 custom analysis steps used in the Sequential Thinking protocol.
Step 6 (Question Formulation) is always fixed in the template.

**Pattern for generating steps:**
1. Map the perspective's `focus_areas` to 5 analysis dimensions
2. For each dimension, write a 1-2 sentence step description
3. Include domain-specific framing in each step

**Example for Product Strategist analyzing a food-delivery app:**
```yaml
step_1: "Product Vision Analysis -- Is the vision clear? What problem does this fundamentally solve for people ordering food? How does it fit into their daily routine?"
step_2: "Market Positioning -- Direct/indirect competitors in food delivery? What gap exists? New market entry or differentiation play?"
step_3: "Business Model Exploration -- Commission-based vs subscription? Who pays (restaurants, consumers, both)? Pricing strategy for multi-sided economics?"
step_4: "Go-to-Market -- Initial city/market? MVP scope for marketplace launch? What validates product-market fit for food delivery?"
step_5: "Competitive Moat -- Network effects between restaurants and consumers? Switching costs? Data advantages from order history?"
```

**Example for UX Researcher analyzing the same app:**
```yaml
step_1: "Persona Clarity -- Who orders food delivery? Work-from-home, office workers, families? What's their context when they order?"
step_2: "Pain Point Deep Dive -- What frustrates people about existing delivery apps? Discovery overwhelm? Delivery reliability? Price transparency?"
step_3: "User Journey Mapping -- From craving to delivery. What triggers an order? How do they browse/search? What's the checkout flow expectation?"
step_4: "Emotional Design -- How should ordering feel? Excitement of discovery vs efficiency of reorder? Trust signals for new restaurants?"
step_5: "Accessibility & Inclusion -- Dietary restrictions as first-class filters? Multi-language menus? Accessibility for motor/vision impairments?"
```

---

## 5. Panel Validation Rules

Before finalizing, the Panel Builder must validate:

| Rule | Check | Action on Failure |
|------|-------|-------------------|
| Member count | 2 <= count <= 5 | Adjust to nearest valid count |
| Weight sum | Sum of all member weights == 1.0 | Redistribute proportionally |
| Product focus | At least 1 member focuses on "product" | Add product-strategist |
| User focus | At least 1 member focuses on "users" | Add ux-researcher |
| Unique prefixes | All question_prefix values are unique | Adjust conflicting prefix |
| Unique IDs | All member IDs are unique | Append numeric suffix |

---

## 6. Panel Builder Output Contract

The Panel Builder writes TWO artifacts:

### 6.1 Proposed Panel File

**Path:** `requirements/.panel-proposed.local.md`
**Format:** YAML frontmatter following `templates/.panel-config-template.local.md`

### 6.2 Summary File

**Path:** `requirements/.stage-summaries/panel-builder-summary.md`

```yaml
---
stage: "panel-builder"
status: needs-user-input
summary: "Proposed {PRESET_NAME} panel with {N} members for {DOMAIN_DESCRIPTION} product"
flags:
  block_reason: "Panel composition requires user validation"
  pause_type: "interactive"
  preset: "{PRESET_NAME}"
  members_count: {N}
  domain: "{DOMAIN_DESCRIPTION}"
  detected_signals:
    - "{signal_1}"
    - "{signal_2}"
  question_context:
    question: "Based on your draft about {PRODUCT_NAME}, the suggested panel is:\n\nPreset: {PRESET_NAME}\n{MEMBER_LIST_FORMATTED}\n\nAccept this panel or customize?"
    header: "Panel"
    options:
      - label: "Accept panel (Recommended)"
        description: "{PRESET_DESCRIPTION}"
      - label: "Choose different preset"
        description: "Select from: product-focused, consumer, marketplace, enterprise"
      - label: "Customize members"
        description: "Pick individual perspectives from the available registry"
---
```

The orchestrator reads this summary, presents the question via `AskUserQuestion`,
and acts on the user's choice:
- **Accept:** Rename `.panel-proposed` → `.panel-config.local.md`
- **Different preset:** Re-dispatch Panel Builder with the chosen preset
- **Customize:** Present available perspectives via multiSelect `AskUserQuestion`,
  then re-dispatch Panel Builder with the custom member list
