# PAL MCP Architecture

## Overview

PAL MCP Server is a collaborative intelligence layer implemented in Python 3.10+ using the `uv` high-performance package manager. It abstracts provider-specific APIs into a unified Model Context Protocol (MCP) framework.

## Client Configuration

| Client Application | Configuration File Location | Recommended Transport |
|--------------------|----------------------------|----------------------|
| **Claude Code CLI** | `project_root/.mcp.json` or `~/.claude.json` | stdio |
| **Claude Desktop** | `~/Library/Application Support/Claude/claude_desktop_config.json` | stdio |
| **Cursor IDE** | Settings > Integrations > MCP | stdio |
| **Codex CLI** | `~/.codex/config.toml` | stdio |
| **VS Code (Claude Dev)** | Command Palette > Configure MCP Servers | stdio |

**Critical**: Extend default timeouts for high-reasoning operations:
```json
{
  "env": {
    "MCP_TIMEOUT": "300000",
    "MCP_TOOL_TIMEOUT": "300000"
  }
}
```

## Provider Matrix

| Provider | Technical Role | Connection Type | Capability Highlights |
|----------|----------------|-----------------|----------------------|
| **Google Gemini** | High-Context Specialist | Native API | 1M token window, advanced thinking modes |
| **OpenAI** | Logical Reasoning Expert | Native / Azure / OpenRouter | o3/o4 reasoning, agentic coding focus |
| **X.AI (Grok)** | Flagship Generalist | Native API | Vision capabilities, massive reasoning depth |
| **OpenRouter** | Unified Cloud Bridge | Multi-Provider API | Access to Llama, Mistral, and niche models |
| **Local (Ollama)** | Privacy/Zero-Cost Utility | Localhost / v1 API | On-device processing, privacy-safe analysis |
| **DIAL Platform** | Enterprise Orchestrator | Vendor-Agnostic API | Compliance-focused model routing |

## Core Infrastructure

### BaseTool Inheritance

Every tool inherits from a `BaseTool` class that standardizes:
- System prompt injection
- Codebase context handling
- Communication protocol consistency
- Fluid model handoffs

System prompts are centralized in the `systemprompts/` directory.

### Capability-Aware Routing

Tools are "capability-aware" - they route tasks only to models possessing necessary features (e.g., vision tasks only to vision-capable models).

## Large Prompt Bridge

**Problem:** MCP ecosystem imposes ~25k token limit on tool inputs.

**Solution:** When prompt exceeds ~50k characters:
1. Server detects oversized prompt
2. Returns special status instructing agent to persist content
3. Agent writes full content to temporary `prompt.txt` file
4. Server reads file directly into target model's memory
5. Bypasses protocol limitations

This enables analysis of entire codebases in a single turn.

## Context Revival Logic

Most agents suffer from context degradation as sessions progress. PAL mitigates this with a persistent memory store outside any single model's context.

### How It Works

1. **Shadow History**: Persists across tool switches and context resets
2. **Cross-Model Recovery**: If Claude's memory clears, PAL invokes secondary model (like o3)
3. **Re-contextualization**: Secondary model retrieves history, synthesizes critical points
4. **True Continuity**: Gemini remembers what o3 said 10 steps ago

## Configuration Variables

| Variable | Default | Strategic Impact |
|----------|---------|------------------|
| `DEFAULT_MODEL` | auto | Claude intelligently selects best model |
| `DISABLED_TOOLS` | analyze,refactor,docgen | Reduces context clutter |
| `CONVERSATION_TIMEOUT_HOURS` | 5 | Thread expiry time |
| `MAX_CONVERSATION_TURNS` | 40 | Prevents infinite loops |
| `LOG_LEVEL` | DEBUG | Essential for troubleshooting handoffs |
| `FORCE_ENV_FILE` | true | Ensures .env values take precedence |

## Two-Phase Tool Methodology

Tools like `debug` and `codereview` implement a professional two-phase approach:

### Phase 1: Investigation
- Led by primary agent
- Examines code, traces stack traces
- Gathers evidence over multiple steps
- Documents findings and hypotheses

### Phase 2: Expert Analysis
- Triggered automatically if confidence < "certain"
- Uses assistant model (e.g., Gemini Pro) for deep-dive
- Reviews all gathered findings
- Provides independent validation

**Bypass:** Set `use_assistant_model=false` for quick checks not requiring external validation.

## Tool-Specific Capability Matrix

An agent must be aware of the "Secondary Capabilities" of each tool to optimize its prompts:

| Tool | Multi-Model Support | Vision Support | Web Search Support | Continuation Support |
|------|---------------------|----------------|--------------------|--------------------|
| `chat` | Yes | Yes | Yes (via Claude) | Yes |
| `debug` | Yes | Yes | Yes (Recommended) | Yes |
| `consensus` | Yes (Required) | Yes | Yes | Yes |
| `analyze` | Yes | Yes | Yes | Yes |
| `clink` | Yes (Via Bridge) | Yes | Yes (Via CLI) | Yes |
| `precommit` | Yes | No | No | Yes |
| `codereview` | Yes | Yes | Yes | Yes |
| `thinkdeep` | Yes | Yes | Yes | Yes |
| `planner` | Yes | No | No | Yes |

## OODA Loop Framework for Tool Selection

For senior-level proficiency with PAL, implement an "Observe-Orient-Decide-Act" (OODA) loop:

1. **Observe**: Detect the complexity and requirements of the user's prompt
   - Is there an error log? → `debug`
   - Is this a new feature? → `planner`
   - Is this a framework decision? → `consensus`

2. **Orient**: Check local environment state
   - Rate limits on preferred model?
   - Active models via `listmodels`?
   - Version of PAL?

3. **Decide**: Select the tool that offers appropriate reasoning depth while minimizing token costs
   - Use the Tool Selection Matrix
   - Match thinking_mode to task complexity

4. **Act**: Execute with precise parameterization
   - Favor multi-step workflows for tasks involving >2 files
   - Always use absolute paths
   - Track continuation_id for related operations

## Integration Points

PAL is designed to work alongside specialized MCP servers:

| Server | Purpose | Role in Stack |
|--------|---------|---------------|
| **Serena** | Semantic code analysis | Intelligent navigation |
| **Task Master** | AI-powered task management | PRD parsing |
| **Context7** | Library documentation | Up-to-date code examples |

PAL acts as the "reasoning hub" synthesizing data from specialized servers.
