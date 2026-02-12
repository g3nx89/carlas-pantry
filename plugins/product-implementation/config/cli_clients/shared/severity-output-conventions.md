# Shared Severity & Output Conventions

> Injected into all clink role prompts at dispatch time by coordinators.
> Canonical severity definitions sourced from `config/implementation-config.yaml`.

## Severity Classification (Canonical)

- **Critical**: Breaks functionality, security vulnerability, data loss risk
- **High**: Likely to cause bugs, significant code quality issue. **ESCALATE** a finding to High (not Medium) if ANY of these apply: user-visible data corruption or data loss, implicit ordering dependency that silently produces wrong results, UI state contradiction (displayed state differs from actual state), singleton or shared-state leak across scopes, race condition with user-visible effect
- **Medium**: Code smell, maintainability concern, minor pattern violation
- **Low**: Style preference, minor optimization opportunity

## Output Format Convention

All clink role prompts MUST include a `<SUMMARY>` block as their final output section:

```
<SUMMARY>
format_version: 1
## {Role-Specific Summary Title}
- **{Field 1}**: {value}
- **{Field 2}**: {value}
...
</SUMMARY>
```

The `format_version: 1` field enables future format evolution without breaking parsers.

## Quality Rules (Universal)

These rules apply to ALL clink role prompts:
- Every finding must include file:line location and a specific recommendation
- Never mix opinions with verifiable facts -- label each clearly
- If a behavior cannot be verified, state the limitation explicitly
- Report in severity order: Critical -> High -> Medium -> Low

## Available MCP Tools (Universal)

All clink agents have access to the following MCP tools. Each role prompt specifies which subset is relevant, but the full set is always available:

| Tool | Primary Use | Usage Guidance |
|------|------------|----------------|
| **Ref** (`ref_search_documentation`, `ref_read_url`) | Search and read library/framework documentation | Primary research tool. Use `ref_search_documentation` to find docs, `ref_read_url` to read specific pages. Supports private docs via `ref_src=private`. |
| **Context7** (`resolve-library-id`, `query-docs`) | Library-specific code examples and API reference | Always call `resolve-library-id` first to get library ID, then `query-docs`. Best for version-specific API signatures and code patterns. |
| **Tavily** (`tavily_search`, `tavily_extract`, `tavily_research`) | Web search, content extraction, deep research | Use `tavily_search` for quick lookups (CVEs, known bugs, current versions). Use `tavily_research` for comprehensive multi-source research. Last resort after Ref and Context7. |
| **Sequential Thinking** (`sequentialthinking`) | Structured multi-step reasoning | Use for complex data flow analysis, multi-requirement validation, systematic checklists. Supports branching and revision. |
| **Mobile MCP** (`mobile_list_available_devices`, `mobile_list_elements_on_screen`, `mobile_click_on_screen_at_coordinates`, `mobile_long_press_on_screen_at_coordinates`, `mobile_type_keys`, `mobile_swipe_on_screen`, `mobile_press_button`, `mobile_take_screenshot`, `mobile_save_screenshot`, `mobile_launch_app`, `mobile_install_app`, `mobile_terminate_app`, `mobile_uninstall_app`, `mobile_get_screen_size`, `mobile_get_orientation`, `mobile_set_orientation`, `mobile_open_url`) | Mobile device interaction and screenshot capture | Use for UAT testing on emulators. Always call `mobile_list_elements_on_screen` before clicking to find correct coordinates. Use `mobile_save_screenshot` for evidence capture at assertion points. Use `mobile_get_screen_size` to understand coordinate space. |
| **Figma** (`get_design_context`, `get_screenshot`, `get_metadata`) | Design context and visual reference | Use when implementation involves UI components. Extract design tokens, layout specs, and component structure. *(Referenced by UAT mobile tester role prompt for visual fidelity verification.)* |

**Budget constraints**: Coordinators inject per-dispatch MCP tool budgets from `clink_dispatch.mcp_tool_budgets` into clink agent prompts. These budgets are **advisory** -- they are guidance embedded in the prompt text, not programmatically enforced hard caps. Clink agents should use MCP tools judiciously -- prefer cached/local knowledge first, escalate to MCP tools for verification or when stuck. Coordinators can verify compliance post-dispatch by counting MCP tool references in the agent's output.
