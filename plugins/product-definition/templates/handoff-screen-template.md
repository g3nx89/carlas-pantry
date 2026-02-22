### {{SCREEN_NUMBER}}. {{SCREEN_NAME}}

**Node ID:** `{{NODE_ID}}` | **Gaps:** {{GAP_COUNT}}

#### Behaviors (Not in Figma)

| Element | Action | Result |
|---------|--------|--------|
| {{ELEMENT}} | {{ACTION}} | {{RESULT}} |

#### State Transitions

| From | Trigger | To | Visual Change |
|------|---------|-----|---------------|
| {{FROM_STATE}} | {{TRIGGER}} | {{TO_STATE}} | {{VISUAL_CHANGE}} |

#### Animations

| Animation | Trigger | Spec |
|-----------|---------|------|
| {{ANIMATION_NAME}} | {{TRIGGER}} | {{SPEC}} |

#### Data Requirements

| Endpoint | Method | Payload | Response |
|----------|--------|---------|----------|
| {{ENDPOINT}} | {{METHOD}} | {{PAYLOAD}} | {{RESPONSE}} |

#### Edge Cases

- {{EDGE_CASE_DESCRIPTION}}

---

<!-- USAGE NOTES (for output assembly, not included in final output):

 1. Omit any section whose table would be empty.
    Example: if a screen has behaviors and edge cases but no animations
    or data requirements, render only Behaviors and Edge Cases sections.

 2. For screens with ZERO gaps, replace the entire template with:

    ### {{SCREEN_NUMBER}}. {{SCREEN_NAME}}
    **Node ID:** `{{NODE_ID}}` | **No supplement needed**

 3. Gap count ({{GAP_COUNT}}) is the total number of rows across all
    tables plus edge case bullets. It matches the count shown in the
    parent supplement's metadata table.

 4. Element names in Behaviors table should match Figma layer names
    (post-preparation naming) so coding agents can cross-reference.

 5. Spec column in Animations table uses format:
    "{DURATION}ms {EASING}" (e.g., "300ms ease-in-out")
-->
