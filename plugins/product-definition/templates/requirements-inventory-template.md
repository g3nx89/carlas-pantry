---
feature_id: "{FEATURE_ID}"
source: "{SOURCE_DESCRIPTION}"
requirements_count: 0
confirmed: false
---

# Requirements Inventory: {FEATURE_NAME}

> **Purpose**: Captures all discrete requirements extracted from the user's input.
> Each requirement gets a stable `REQ-NNN` identifier used throughout the specification workflow
> for traceability (RTM). Review this list, add/remove/edit entries, then confirm to proceed.

## Source Requirements

| REQ ID | Category | Requirement | Priority | Source |
|--------|----------|-------------|----------|--------|
| REQ-001 | {Functional/NFR/Constraint} | {Requirement description} | {HIGH/MEDIUM/LOW} | {user input / research / stakeholder} |

## Categories

- **Functional**: User-facing capabilities ("users must be able to...")
- **NFR**: Non-functional requirements (performance, security, accessibility)
- **Constraint**: Business or technical constraints ("must work offline", "GDPR compliant")

## Instructions

1. Review each requirement — edit descriptions for clarity
2. Add any requirements the extraction missed
3. Remove entries that are not actual requirements (e.g., context statements)
4. Adjust priorities as needed
5. When satisfied, confirm to proceed — IDs become stable after confirmation
