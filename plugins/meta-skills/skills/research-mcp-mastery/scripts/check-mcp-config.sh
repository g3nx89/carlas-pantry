#!/bin/bash
# check-mcp-config.sh - Validate research MCP server configuration
# Usage: ./check-mcp-config.sh

set -euo pipefail

echo "=== Research MCP Server Configuration Check ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_server() {
    local name="$1"
    local pattern="$2"

    if claude mcp list 2>/dev/null | grep -qi "$pattern"; then
        echo -e "${GREEN}[OK]${NC} $name is configured"
        return 0
    else
        echo -e "${RED}[MISSING]${NC} $name not found"
        return 1
    fi
}

check_env_var() {
    local var="$1"
    local desc="$2"

    if [[ -n "${!var:-}" ]]; then
        echo -e "${GREEN}[SET]${NC} $var"
    else
        echo -e "${YELLOW}[UNSET]${NC} $var - $desc"
    fi
}

echo "Checking MCP server configuration..."
echo ""

# Check each research server
missing=0
check_server "Context7" "context7" || ((missing++))
check_server "Ref" "ref" || ((missing++))
check_server "Tavily" "tavily" || ((missing++))

echo ""
echo "Checking environment variables..."
echo ""

check_env_var "CONTEXT7_API_KEY" "Optional: increases rate limits"
check_env_var "REF_API_KEY" "Required for Ref (format: ref_*)"
check_env_var "TAVILY_API_KEY" "Required for Tavily (format: tvly-*)"

echo ""
echo "Checking timeout configuration..."
echo ""

check_env_var "MCP_TIMEOUT" "Recommended: 60000 for Context7/Ref"
check_env_var "MCP_TOOL_TIMEOUT" "Recommended: 120000 for deep searches"

echo ""
if [[ $missing -gt 0 ]]; then
    echo -e "${YELLOW}Missing $missing server(s). Install with:${NC}"
    echo ""
    echo "  # Context7 (remote - recommended)"
    echo '  claude mcp add --transport http context7 https://mcp.context7.com/mcp'
    echo ""
    echo "  # Ref (HTTP - recommended)"
    echo '  claude mcp add --transport http Ref "https://api.ref.tools/mcp?apiKey=YOUR_KEY"'
    echo ""
    echo "  # Tavily (remote - recommended)"
    echo '  claude mcp add --transport http tavily "https://mcp.tavily.com/mcp/?tavilyApiKey=YOUR_KEY"'
else
    echo -e "${GREEN}All research MCP servers configured.${NC}"
fi
