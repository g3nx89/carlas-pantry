# Code Handoff Protocol

> **Cross-references**: `recipes-advanced.md` (Handoff Preparation Pattern + naming audit recipe), `design-rules.md` (Code-readiness SHOULD rules #11-14), `st-integration.md` (Naming Audit Reasoning template), `tool-playbook.md` (Complementary Workflow — downstream Official MCP tools)

When the design session is complete and the design will be implemented as code,
run this protocol to prepare the Figma artifact for downstream consumption by the
coding agent. The coding agent uses `get_design_context` (Official MCP) to extract
framework-ready specs (React, SwiftUI, Compose, etc.) and the `implement-design`
Agent Skill to translate them into production code.

**How this compensates for missing Code Connect**: `get_design_context` returns
component names, variant properties, and descriptions. The naming conventions below
ensure these names match the codebase, allowing the coding agent to identify the
correct code component without Code Connect bidirectional mappings. This is
best-effort alignment — not equivalent to Code Connect. For full bidirectional
mapping of custom components, an Organization/Enterprise plan is required.

**Load**: `recipes-advanced.md` (Handoff Preparation Pattern)

## Steps

1. **Naming audit** — run the Handoff Naming Audit recipe via `figma_execute` to
   check all components for non-PascalCase names and uppercase variant property keys
2. **Fix naming** — rename components to match the target codebase's component
   naming convention (typically PascalCase: `ProductCard`, not `product card`
   or `Frame 42`); rename variant property keys to lowercase (`size`, `variant`,
   `state`)
3. **Exception descriptions** — `figma_set_description` ONLY where the Figma name
   must differ from the code name:
   ```
   Code name: CallToActionButton
   Note: Figma name "CTA Button" differs for brevity
   ```
4. **Token alignment** — verify variable/token names correspond to the codebase
   token system (e.g., `color/primary/500` -> `--color-primary-500`)
5. **UI kit preference** — where possible, compose with M3/Apple/SDS library
   components that have automatic Code Connect on Professional+ plans
6. **Health check** — `figma_audit_design_system` for final naming, token, and
   consistency scores

> **ST trigger**: When the naming audit (step 1) surfaces >5 issues with ambiguous false positives (CTA, 2XL, etc.), activate ST with a TAO Loop to reason through each flagged item: classify as true positive, false positive, or ambiguous. See [`st-integration.md#template-naming-audit-reasoning`].

## Multi-Platform Notes

The component name is the cross-platform contract. The coding
agent for each platform searches its own codebase for a component matching the
Figma name. `get_design_context` handles framework-specific translation. For
components where platform names diverge (e.g., Figma `BottomNavigation` vs
SwiftUI `TabView`), use step 3 exception descriptions with platform-specific
code names.

## Scope

This protocol prepares the Figma artifact for downstream consumption.
Actual code generation is performed by the `implement-design` Agent Skill via Official MCP.
For plan-specific availability of downstream tools, see `tool-playbook.md`
(Complementary Workflow).
