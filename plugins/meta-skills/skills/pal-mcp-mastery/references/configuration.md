# PAL MCP Configuration & Override Guide

> **Compatibility**: Verified against PAL MCP v1.x (January 2026)

## Override Philosophy

**Prefer project-level overrides over user-level overrides.**

Project-level configuration ensures:
- Reproducible builds across team members
- Settings travel with the repository
- No hidden user-specific behavior
- Clear audit trail in version control

```
┌─────────────────────────────────────────────────────────────────┐
│  RECOMMENDED: Project-Level Overrides                           │
├─────────────────────────────────────────────────────────────────┤
│  • .env file in project root                                    │
│  • PROJECT_ROOT/conf/*.json for model catalogs                  │
│  • PROJECT_ROOT/conf/cli_clients/ for clink roles               │
│  • Shell scripts that set env vars before launching             │
├─────────────────────────────────────────────────────────────────┤
│  AVOID: User-Level Overrides (~/.pal/)                          │
│  • Use only for personal preferences not shareable              │
│  • Use only when project-level is not possible                  │
└─────────────────────────────────────────────────────────────────┘
```

## Configuration Priority Hierarchy

PAL resolves configuration in strict priority order (highest to lowest):

```
┌─────────────────────────────────────────────────────────────────┐
│  HIGHEST PRIORITY                                               │
├─────────────────────────────────────────────────────────────────┤
│  1. Environment Variables (system or .env)                      │
│     └── PAL_MCP_FORCE_ENV_OVERRIDE=true: .env wins over system  │
│     └── PAL_MCP_FORCE_ENV_OVERRIDE=false (default): system wins │
│  2. User Config (~/.pal/cli_clients/)  [CLINK ONLY]             │
│  3. Env Path Override (*_CONFIG_PATH)                           │
│  4. Package Resources (pip/uvx install)                         │
│  5. PROJECT_ROOT/conf/ (built-in defaults)  ← TARGET THIS       │
│  6. CWD/conf/ (fallback working directory)                      │
├─────────────────────────────────────────────────────────────────┤
│  LOWEST PRIORITY                                                │
└─────────────────────────────────────────────────────────────────┘
```

**Key insight**: `PROJECT_ROOT/conf/` is checked BEFORE CWD. Place overrides there for project-level control.

---

## Project-Level Override Strategies

### Strategy 1: Project .env File (Recommended)

Create `.env` in project root for environment variable overrides:

```bash
# PROJECT_ROOT/.env

# Force .env to override system environment
PAL_MCP_FORCE_ENV_OVERRIDE=true

# Model selection
DEFAULT_MODEL=flash
DEFAULT_THINKING_MODE_THINKDEEP=high

# Restrict available models for this project
OPENAI_ALLOWED_MODELS=o3-mini,o4-mini
GOOGLE_ALLOWED_MODELS=flash,pro

# Disable expensive/unused tools (saves ~90KB context)
DISABLED_TOOLS=analyze,refactor,testgen,secaudit,docgen,tracer

# Project-specific API endpoints
CUSTOM_API_URL=http://localhost:11434/v1
CUSTOM_MODEL_NAME=llama3.2

# Logging
LOG_LEVEL=INFO
```

**Important**: Set `PAL_MCP_FORCE_ENV_OVERRIDE=true` to ensure `.env` values take precedence over system environment variables.

### Strategy 2: Project conf/ Directory

Create model catalogs and clink configurations in `PROJECT_ROOT/conf/`:

```
my-project/
├── conf/
│   ├── gemini_models.json      # Project-specific Gemini models
│   ├── openai_models.json      # Project-specific OpenAI models
│   ├── custom_models.json      # Local/Ollama models for this project
│   └── cli_clients/
│       ├── gemini.json         # Project clink roles
│       ├── codex.json
│       └── gemini_*.txt        # Role prompt files
├── .env                        # Environment overrides
└── ...
```

This is automatically discovered by PAL without any environment variables.

### Strategy 3: Explicit Path Override (Most Control)

Point to project-specific config files via environment variables:

```bash
# In .env or shell script
GEMINI_MODELS_CONFIG_PATH=./conf/gemini_models.json
OPENAI_MODELS_CONFIG_PATH=./conf/openai_models.json
CLI_CLIENTS_CONFIG_PATH=./conf/cli_clients/
```

This gives explicit control and works even when PAL is installed globally.

### Strategy 4: Launch Script

Create a project launch script that sets environment before starting:

```bash
#!/bin/bash
# scripts/start-with-pal.sh

export PAL_MCP_FORCE_ENV_OVERRIDE=true
export DEFAULT_MODEL=flash
export DISABLED_TOOLS=analyze,refactor,testgen
export LOG_LEVEL=INFO

# Launch Claude Code with project settings
claude
```

---

## Complete Environment Variables Reference

### Override Control

| Env Var | Default | Effect |
|---------|---------|--------|
| `PAL_MCP_FORCE_ENV_OVERRIDE` | `false` | When `true`, `.env` values override system env |

**Recommendation**: Always set `true` in project `.env` files.

### Model Selection

| Env Var | Default | Values |
|---------|---------|--------|
| `DEFAULT_MODEL` | `auto` | `auto`, `pro`, `flash`, `o3`, `gpt5.2`, etc. |
| `DEFAULT_THINKING_MODE_THINKDEEP` | `high` | `minimal`, `low`, `medium`, `high`, `max` |

### Model Catalog Paths

Override default model catalogs by pointing to project-specific JSON files:

| Env Var | Default File | Provider |
|---------|-------------|----------|
| `GEMINI_MODELS_CONFIG_PATH` | `conf/gemini_models.json` | Gemini |
| `OPENAI_MODELS_CONFIG_PATH` | `conf/openai_models.json` | OpenAI |
| `XAI_MODELS_CONFIG_PATH` | `conf/xai_models.json` | X.AI/Grok |
| `AZURE_MODELS_CONFIG_PATH` | `conf/azure_models.json` | Azure OpenAI |
| `DIAL_MODELS_CONFIG_PATH` | `conf/dial_models.json` | DIAL |
| `OPENROUTER_MODELS_CONFIG_PATH` | `conf/openrouter_models.json` | OpenRouter |
| `CUSTOM_MODELS_CONFIG_PATH` | `conf/custom_models.json` | Custom/Local |
| `CLI_CLIENTS_CONFIG_PATH` | `conf/cli_clients/` | Clink |

**Project-level example**:
```bash
# In .env - use relative paths from project root
GEMINI_MODELS_CONFIG_PATH=./conf/gemini_models.json
CLI_CLIENTS_CONFIG_PATH=./conf/cli_clients/
```

### Model Restrictions (Allowlists)

Restrict which models are available per provider:

| Env Var | Provider | Example |
|---------|----------|---------|
| `OPENAI_ALLOWED_MODELS` | OpenAI | `o3-mini,o4-mini,gpt-4o` |
| `GOOGLE_ALLOWED_MODELS` | Gemini | `flash,pro` |
| `XAI_ALLOWED_MODELS` | X.AI/Grok | `grok-2,grok-2-mini` |
| `OPENROUTER_ALLOWED_MODELS` | OpenRouter | Comma-separated list |
| `DIAL_ALLOWED_MODELS` | DIAL | Comma-separated list |
| `AZURE_OPENAI_ALLOWED_MODELS` | Azure OpenAI | Managed by Azure provider separately |

**Note**: `CUSTOM_ALLOWED_MODELS` does NOT exist.

**Note**: `AZURE_OPENAI_ALLOWED_MODELS` is handled directly by the Azure provider, not by ModelRestrictionService.

### API Keys & Endpoints

| Env Var | Provider | Notes |
|---------|----------|-------|
| `GEMINI_API_KEY` | Gemini | Required |
| `GEMINI_BASE_URL` | Gemini | Optional custom endpoint |
| `OPENAI_API_KEY` | OpenAI | Required |
| `AZURE_OPENAI_API_KEY` | Azure | Required with ENDPOINT |
| `AZURE_OPENAI_ENDPOINT` | Azure | Required with API_KEY |
| `AZURE_OPENAI_API_VERSION` | Azure | Default: `2024-02-15-preview` |
| `XAI_API_KEY` | X.AI | Required for Grok |
| `DIAL_API_KEY` | DIAL | Required |
| `DIAL_API_HOST` | DIAL | Default: `https://core.dialx.ai` |
| `DIAL_API_VERSION` | DIAL | Optional |
| `OPENROUTER_API_KEY` | OpenRouter | Required |
| `CUSTOM_API_URL` | Local | Required for Ollama/vLLM |
| `CUSTOM_API_KEY` | Local | Optional (empty for Ollama) |
| `CUSTOM_MODEL_NAME` | Local | Default: `llama3.2` |

**Security**: Never commit API keys. Use `.env` (gitignored) or environment injection.

### Custom Provider Timeouts

| Env Var | Remote Default | Localhost Default |
|---------|---------------|-------------------|
| `CUSTOM_CONNECT_TIMEOUT` | 45s | 60s |
| `CUSTOM_READ_TIMEOUT` | 900s | 1800s |
| `CUSTOM_WRITE_TIMEOUT` | 900s | 1800s |
| `CUSTOM_POOL_TIMEOUT` | 900s | 1800s |

### Conversation Management

| Env Var | Code Default | .env.example Suggests |
|---------|-------------|----------------------|
| `CONVERSATION_TIMEOUT_HOURS` | 3 | 24 |
| `MAX_CONVERSATION_TURNS` | 50 | 40 |

### Tool Management

| Env Var | Description |
|---------|-------------|
| `DISABLED_TOOLS` | Comma-separated list of tools to disable |

**Default disabled** (from .env.example):
```
analyze,refactor,testgen,secaudit,docgen,tracer
```

**All available tools**:
- Core: `chat`, `clink`, `thinkdeep`, `planner`, `consensus`
- Code: `codereview`, `precommit`, `debug`, `secaudit`, `docgen`
- Analysis: `analyze`, `refactor`, `tracer`, `testgen`, `challenge`
- Utility: `apilookup`, `listmodels`, `version`

**Non-disableable**: `version`, `listmodels`

**Context impact**: Disabling unused tools saves ~90KB of context. Recommended for projects using only specific tools.

### Logging & Output

| Env Var | Default | Values |
|---------|---------|--------|
| `LOG_LEVEL` | `DEBUG` | `DEBUG`, `INFO`, `WARNING`, `ERROR` |
| `LOCALE` | `""` (English) | Language code for AI responses |
| `MAX_MCP_OUTPUT_TOKENS` | ~25000 | MCP response token limit |

---

## Project conf/ Directory Structure

### Model Catalog Format

Create project-specific model catalogs in `PROJECT_ROOT/conf/`:

```json
// conf/gemini_models.json
{
  "models": [
    {
      "id": "gemini-2.0-flash",
      "name": "flash",
      "aliases": ["gemini-flash", "flash-2.0"],
      "context_window": 1000000,
      "supports_thinking": false
    },
    {
      "id": "gemini-2.0-pro",
      "name": "pro",
      "aliases": ["gemini-pro", "pro-2.0"],
      "context_window": 1000000,
      "supports_thinking": true
    }
  ]
}
```

### Clink Configuration Format

Create `PROJECT_ROOT/conf/cli_clients/{cli_name}.json`:

```json
{
  "name": "gemini",
  "command": "gemini",
  "additional_args": ["--yolo"],
  "env": {},
  "roles": {
    "default": {
      "prompt_path": "systemprompts/clink/default.txt",
      "role_args": []
    },
    "deepthinker": {
      "prompt_path": "gemini_deepthinker.txt",
      "role_args": [],
      "description": "Deep systematic analysis with Sequential Thinking"
    },
    "planreviewer": {
      "prompt_path": "gemini_planreviewer.txt",
      "role_args": [],
      "description": "Red/Blue team plan validation"
    }
  }
}
```

### Prompt Path Resolution for Clink

Clink resolves `prompt_path` in this order:
1. **Relative to the directory containing the JSON config**
2. Relative to `PROJECT_ROOT`

**Project-level example**:
```
my-project/
├── conf/
│   └── cli_clients/
│       ├── gemini.json              # References "./gemini_deepthinker.txt"
│       ├── gemini_deepthinker.txt   # Found first (same directory)
│       └── gemini_planreviewer.txt
```

---

## User-Level Overrides (~/.pal/) - When Necessary

**Use only when project-level configuration is not possible.**

The `~/.pal/` directory provides user-level overrides **for Clink CLI clients only**.

### Supported in ~/.pal/

| Resource | Path | Overrides |
|----------|------|-----------|
| CLI Clients | `~/.pal/cli_clients/*.json` | `conf/cli_clients/` |
| Clink Prompts | `~/.pal/cli_clients/*.txt` | `systemprompts/clink/` |

### NOT Supported via ~/.pal/

- Model catalogs → Use `*_MODELS_CONFIG_PATH` env vars
- Tool system prompts → Modify `systemprompts/` directly in source
- Environment variables → Use `.env` or shell

### When to Use ~/.pal/

- Personal clink roles not suitable for sharing
- Testing roles before adding to project
- Overriding behavior for all projects (rare)

---

## System Prompts

| Type | Location | Override Method |
|------|----------|-----------------|
| Tool Prompts | `systemprompts/*.py` | Modify Python source directly |
| Clink Prompts | `systemprompts/clink/*.txt` | Via JSON in `conf/cli_clients/` |

**Tools with Python prompts**: chat, codereview, analyze, refactor, testgen, debug, planner, consensus, docgen, tracer, thinkdeep, secaudit, precommit

---

## Log Files

| File | Max Size | Backups |
|------|----------|---------|
| `logs/mcp_server.log` | 20MB | 5 |
| `logs/mcp_activity.log` | 10MB | 2 |

---

## Quick Setup Templates

### Template 1: Minimal Project Setup

```bash
# Create project .env
cat > .env << 'EOF'
PAL_MCP_FORCE_ENV_OVERRIDE=true
DEFAULT_MODEL=flash
DISABLED_TOOLS=analyze,refactor,testgen,secaudit,docgen,tracer
LOG_LEVEL=INFO
EOF

# Add to .gitignore
echo ".env" >> .gitignore
```

### Template 2: Full Project Setup with Custom Models

```bash
# Create conf directory
mkdir -p conf/cli_clients

# Create .env
cat > .env << 'EOF'
PAL_MCP_FORCE_ENV_OVERRIDE=true
DEFAULT_MODEL=flash
GOOGLE_ALLOWED_MODELS=flash,pro
OPENAI_ALLOWED_MODELS=o3-mini,o4-mini
DISABLED_TOOLS=analyze,refactor,testgen,secaudit,docgen,tracer
CLI_CLIENTS_CONFIG_PATH=./conf/cli_clients/
LOG_LEVEL=INFO
EOF

# Create clink config
cat > conf/cli_clients/gemini.json << 'EOF'
{
  "name": "gemini",
  "command": "gemini",
  "additional_args": ["--yolo"],
  "roles": {
    "default": { "prompt_path": "systemprompts/clink/default.txt" },
    "deepthinker": { "prompt_path": "gemini_deepthinker.txt" }
  }
}
EOF
```

### Template 3: Local Ollama Setup

```bash
cat > .env << 'EOF'
PAL_MCP_FORCE_ENV_OVERRIDE=true
DEFAULT_MODEL=custom
CUSTOM_API_URL=http://localhost:11434/v1
CUSTOM_MODEL_NAME=llama3.2
# No CUSTOM_API_KEY needed for Ollama
CUSTOM_READ_TIMEOUT=1800
DISABLED_TOOLS=analyze,refactor,testgen,secaudit,docgen,tracer
EOF
```

---

## Troubleshooting Configuration

### Changes Not Taking Effect

1. Verify `.env` has `PAL_MCP_FORCE_ENV_OVERRIDE=true`
2. Restart Claude Code completely (not just MCP server)
3. Check environment with: `echo $DEFAULT_MODEL`

### Clink Role Not Found

1. Verify JSON syntax in `conf/cli_clients/*.json`
2. Check prompt file exists at resolved path (relative to JSON directory)
3. Ensure `prompt_path` points to existing file

### Model Not Available

1. Check API key is set for the provider
2. Verify model is not excluded by `*_ALLOWED_MODELS`
3. Run `listmodels` to see available models

### Path Resolution Issues

PAL resolves config files in this order:
1. Env var path (`*_CONFIG_PATH`)
2. Package resources (installed package)
3. `PROJECT_ROOT/conf/`
4. `CWD/conf/`

Use explicit `*_CONFIG_PATH` env vars for guaranteed resolution.

---

## Migrating from ~/.pal/ to Project-Level

If currently using `~/.pal/cli_clients/` for clink roles, follow this migration:

### Step 1: Create Project Structure

```bash
mkdir -p conf/cli_clients
```

### Step 2: Copy Existing Configs

```bash
# Copy JSON configs
cp ~/.pal/cli_clients/*.json conf/cli_clients/

# Copy prompt files
cp ~/.pal/cli_clients/*.txt conf/cli_clients/
```

### Step 3: Update .env

```bash
# Add to PROJECT_ROOT/.env
PAL_MCP_FORCE_ENV_OVERRIDE=true
CLI_CLIENTS_CONFIG_PATH=./conf/cli_clients/
```

### Step 4: Verify and Clean Up

```bash
# Test that roles work from project config
# Then optionally remove user-level overrides:
rm ~/.pal/cli_clients/{migrated_files}
```

### Step 5: Commit to Repository

```bash
# .env should be gitignored (contains secrets)
echo ".env" >> .gitignore

# conf/ should be committed (no secrets)
git add conf/
git commit -m "chore: migrate clink roles to project-level configuration"
```

**Benefits after migration**:
- Team members get same roles automatically
- Settings documented in version control
- No "works on my machine" issues
- Easier onboarding for new team members

---

## Summary: Project-Level Override Checklist

- [ ] Create `.env` in project root
- [ ] Set `PAL_MCP_FORCE_ENV_OVERRIDE=true`
- [ ] Set `DISABLED_TOOLS` to reduce context (~90KB savings)
- [ ] Create `conf/cli_clients/` for custom clink roles
- [ ] Point `CLI_CLIENTS_CONFIG_PATH` to project conf (optional but explicit)
- [ ] Add `.env` to `.gitignore` (contains API keys)
- [ ] Commit `conf/` directory (no secrets)

---

## See Also

- **`clink-roles.md`** - Custom clink role documentation
- **`tool-clink.md`** - Clink tool parameters and usage
- **`troubleshooting.md`** - Error resolution guide
