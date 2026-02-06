---
name: qa-test-planner
description: This skill should be used when the user asks to "create a test plan", "generate test cases", "build regression suite", "write smoke tests", "validate against Figma design", "create bug report", "document a bug", "write QA documentation", or needs manual testing templates and structured documentation for quality assurance.
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
---

# QA Test Planner

A comprehensive skill for creating test plans, generating manual test cases, building regression test suites, validating designs against Figma, and documenting bugs effectively.

---

## Quick Start

| Task | Command Example |
|------|-----------------|
| Test Plan | "Create a test plan for the user authentication feature" |
| Test Cases | "Generate manual test cases for the checkout flow" |
| Regression Suite | "Build a regression test suite for the payment module" |
| Figma Validation | "Compare the login page against the Figma design at [URL]" |
| Bug Report | "Create a bug report for the form validation issue" |

---

## Workflow

```
Request → Analyze → Generate → Validate → Deliverable
```

**1. Analyze**
- Parse feature/requirement description
- Identify test types needed (functional, UI, integration, regression)
- Determine scope, priorities, and edge cases

**2. Generate**
- Apply templates from references/
- Include comprehensive edge cases and variations
- Structure content for execution and tracking

**3. Validate**
- Check completeness against checklists
- Verify traceability between requirements and tests
- Ensure all steps are clear and actionable

---

## Core Deliverables

### Test Plans
- Test scope and objectives
- Testing approach and strategy
- Environment requirements
- Entry/exit criteria
- Risk assessment with mitigations
- Timeline and milestones

### Manual Test Cases
- Step-by-step instructions
- Expected vs actual results
- Preconditions and test data
- Priority assignment (P0-P3)
- Edge cases and variations

### Regression Suites

| Suite Type | Duration | When to Run |
|------------|----------|-------------|
| Smoke | 15-30 min | Daily, before detailed testing |
| Targeted | 30-60 min | After specific changes |
| Full | 2-4 hours | Before releases, weekly |
| Sanity | 10-15 min | After hotfixes |

### Bug Reports
- Clear reproduction steps
- Environment details (OS, browser, device, build)
- Expected vs actual behavior
- Visual evidence (screenshots, logs)
- Severity and priority classification

### Figma Validation
- Component-by-component comparison
- Spacing, typography, and color checks
- Interactive state validation
- Responsive behavior verification

---

## Priority Definitions

| Priority | Description | When to Run |
|----------|-------------|-------------|
| P0 | Critical path, blocks release | Every build |
| P1 | Major features, high impact | Daily/Weekly |
| P2 | Standard features, moderate impact | Weekly/Release |
| P3 | Minor features, low impact | Release only |

---

## Severity Definitions

| Level | Criteria | Examples |
|-------|----------|----------|
| Critical | System crash, data loss, security | Payment fails, login broken |
| High | Major feature broken, no workaround | Search not working |
| Medium | Feature partial, workaround exists | Filter missing option |
| Low | Cosmetic, rare edge case | Typo, minor alignment |

---

## Response Time Guidelines

| Severity | Target Response |
|----------|-----------------|
| Critical | < 4 hours |
| High | < 24 hours |
| Medium | < 1 week |
| Low | Next release |

---

## Priority vs Severity Matrix

|  | Low Impact | Medium Impact | High Impact | Critical Impact |
|--|-----------|---------------|-------------|-----------------|
| **Rare** | P3 | P3 | P2 | P1 |
| **Sometimes** | P3 | P2 | P1 | P0 |
| **Often** | P2 | P1 | P0 | P0 |
| **Always** | P2 | P1 | P0 | P0 |

---

## Anti-Patterns to Avoid

| Avoid | Why | Instead |
|-------|-----|---------|
| Vague test steps | Cannot reproduce | Specific actions + expected results |
| Missing preconditions | Tests fail unexpectedly | Document all setup requirements |
| No test data | Tester blocked | Provide sample data or generation |
| Generic bug titles | Hard to track | Specific: "[Feature] issue when [action]" |
| Skip edge cases | Miss critical bugs | Include boundary values, nulls |

---

## Verification Checklists

**Test Plan:**
- [ ] Scope clearly defined (in/out)
- [ ] Entry/exit criteria specified
- [ ] Risks identified with mitigations
- [ ] Timeline realistic

**Test Cases:**
- [ ] Each step has expected result
- [ ] Preconditions documented
- [ ] Test data available
- [ ] Priority assigned

**Bug Reports:**
- [ ] Reproducible steps
- [ ] Environment documented
- [ ] Screenshots/evidence attached
- [ ] Severity/priority set

---

## Interactive Scripts

Execute directly for guided creation:

| Script | Purpose |
|--------|---------|
| `./scripts/generate_test_cases.sh` | Interactive test case creation with prompts |
| `./scripts/create_bug_report.sh` | Guided bug report generation |

---

## Reference Documentation

Detailed templates and guides in `references/`:

| File | Content |
|------|---------|
| **test_case_templates.md** | Standard formats for functional, UI, integration, regression, security, and performance test cases |
| **bug_report_templates.md** | Templates for standard, quick, UI, performance, security, and crash bugs |
| **regression_testing.md** | Suite building strategies, execution order, pass/fail criteria, reporting |
| **figma_validation.md** | Design validation workflow, MCP queries, comparison checklists |

---

## Example Files

Working examples in `examples/`:

| File | Description |
|------|-------------|
| **login-test-case.md** | Complete functional test case for user login |
| **ui-validation-test.md** | Visual validation test case with Figma reference |
| **bug-report-sample.md** | Structured bug report with all required fields |
| **smoke-test-suite.md** | Minimal smoke test suite template |

---

## Figma MCP Integration

When Figma MCP is configured, extract design specifications directly:

**Example Queries:**
```
"Get button specifications from Figma design [URL]"
"Extract spacing values for the card component"
"List all color tokens in the design system"
"Compare navigation implementation against Figma"
```

**Returns:**
- Dimensions (width, height)
- Colors (background, text, border with hex values)
- Typography (font, size, weight, line-height)
- Spacing (padding, margin)
- Interactive states (default, hover, active, disabled)

For detailed workflow, see `references/figma_validation.md`.

---

## Output Format

All deliverables are generated in **Markdown format** for compatibility with:
- Jira, Linear, GitHub Issues
- Confluence, Notion
- TestRail, Zephyr
- Google Docs, Word

---

## Quick Commands

| Need | Say |
|------|-----|
| Full test plan | "Create a test plan for [feature]" |
| N test cases | "Generate N test cases for [feature]" |
| Smoke tests | "Build smoke test suite for [module]" |
| Full regression | "Create full regression suite" |
| Figma check | "Validate [component] against Figma at [URL]" |
| Bug report | "Document bug: [description]" |

---

**"Testing shows the presence, not the absence of bugs."** — Edsger Dijkstra

**"Quality is not an act, it is a habit."** — Aristotle
