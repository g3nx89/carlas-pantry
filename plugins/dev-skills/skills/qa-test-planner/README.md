# QA Test Planner

A Claude Code skill for QA engineers to generate test plans, test cases, regression suites, Figma validations, and bug reports.

## Overview

The QA Test Planner skill creates thorough, well-structured testing documentation quickly and consistently, eliminating repetitive formatting while ensuring best practices.

## Key Capabilities

- **Test Plans** - Complete plans with scope, strategy, risks, entry/exit criteria
- **Test Cases** - Step-by-step instructions with expected results and edge cases
- **Regression Suites** - Smoke, targeted, and full regression test suites
- **Figma Validation** - Design-implementation comparison using Figma MCP
- **Bug Reports** - Structured reports with reproduction steps and evidence

## Quick Start

```
"Create a test plan for user authentication"
"Generate 5 test cases for the checkout flow"
"Build a smoke test suite for payments"
"Validate the button against Figma at [URL]"
"Create a bug report for the validation issue"
```

## Skill Structure

```
qa-test-planner/
├── SKILL.md              # Detailed instructions and workflow
├── examples/             # Working sample files
│   ├── login-test-case.md
│   ├── ui-validation-test.md
│   ├── bug-report-sample.md
│   └── smoke-test-suite.md
├── references/           # Detailed templates and guides
│   ├── test_case_templates.md
│   ├── bug_report_templates.md
│   ├── regression_testing.md
│   └── figma_validation.md
└── scripts/              # Interactive generators
    ├── generate_test_cases.sh
    └── create_bug_report.sh
```

## Documentation

| Resource | Description |
|----------|-------------|
| **SKILL.md** | Complete workflow, checklists, and quick reference |
| **examples/** | Ready-to-use sample test cases and bug reports |
| **references/** | Detailed templates for all deliverable types |

## Output Format

All deliverables are Markdown, compatible with Jira, Linear, GitHub Issues, Confluence, Notion, TestRail, and more.

---

**"Testing shows the presence, not the absence of bugs."** — Edsger Dijkstra
