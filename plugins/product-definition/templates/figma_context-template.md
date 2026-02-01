# Figma Design Context

**Feature:** {{FEATURE_ID}}
**Captured:** {{TIMESTAMP}}

---

## Screens

{{#each screens}}
### {{name}} (`{{nodeId}}`)

![Screenshot](./figma/{{filename}}.png)

**Elements:** {{elements_summary}}

**Annotations:** {{annotations_if_any}}

---
{{/each}}

## Capture Notes

{{any_issues_or_warnings}}

---

## Usage

This context is consumed by `/sdd:01-specify` to correlate design mocks with requirements.

**Reference format in spec.md:**
```
@FigmaRef(nodeId="X:Y", screen="Screen Name")
```
