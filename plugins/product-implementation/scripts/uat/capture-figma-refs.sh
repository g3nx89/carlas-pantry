#!/usr/bin/env bash
# Capture Figma reference screenshots for visual parity testing
#
# Auto-discovers all FRAME nodes from a Figma file via REST API,
# then batch-exports them as PNG. No hardcoded node IDs needed.
#
# Prerequisites:
#   - bash 4+ (uses associative arrays)
#   - FIGMA_ACCESS_TOKEN env var (personal access token from figma.com/developers)
#   - curl, jq
#
# Usage:
#   ./capture-figma-refs.sh <FILE_KEY> [OUTPUT_DIR] [options]
#   ./capture-figma-refs.sh <FILE_KEY> --list          # list discovered frames without downloading
#   ./capture-figma-refs.sh <FILE_KEY> --force          # re-download all screenshots
#   ./capture-figma-refs.sh <FILE_KEY> --clean          # remove PNGs not matching any Figma frame
#   ./capture-figma-refs.sh <FILE_KEY> --page "Final"   # export only from a specific page
#   ./capture-figma-refs.sh <FILE_KEY> --scale 3        # export at 3x scale
#   ./capture-figma-refs.sh <FILE_KEY> --depth 4        # Figma tree traversal depth
#   ./capture-figma-refs.sh --help                      # show this help
#
# If FIGMA_ACCESS_TOKEN is not set, the script will try to extract it from
# a running figma-console-mcp process (macOS only).
#
# Frame naming: uses the frame name prefix (first word before " " or "—").
# All FRAME nodes are exported — no prefix filtering.

set -euo pipefail

if ((BASH_VERSINFO[0] < 4)); then
    echo "[ERROR] bash 4+ required (found ${BASH_VERSION}). Install via: brew install bash"
    exit 1
fi

# ── Show help ────────────────────────────────────────────────────────────────
show_help() {
    sed -n '2,/^$/{ s/^# //; s/^#//; p; }' "$0"
    exit 0
}

# ── Defaults ─────────────────────────────────────────────────────────────────
FILE_KEY="${FIGMA_FILE_KEY:-}"
OUTPUT_DIR="./figma-references/"
PAGE_NAME="${FIGMA_PAGE_NAME:-}"
SCALE=2
DEPTH=3
FORCE=false
LIST_ONLY=false
CLEAN=false

# ── Parse args ───────────────────────────────────────────────────────────────
POSITIONAL=()
NEXT_ARG=""
for arg in "$@"; do
    if [[ -n "$NEXT_ARG" ]]; then
        case "$NEXT_ARG" in
            page)   PAGE_NAME="$arg" ;;
            scale)  SCALE="$arg" ;;
            depth)  DEPTH="$arg" ;;
            output) OUTPUT_DIR="$arg" ;;
        esac
        NEXT_ARG=""
        continue
    fi
    case "$arg" in
        --help)   show_help ;;
        --force)  FORCE=true ;;
        --list)   LIST_ONLY=true ;;
        --clean)  CLEAN=true ;;
        --page)   NEXT_ARG="page" ;;
        --scale)  NEXT_ARG="scale" ;;
        --depth)  NEXT_ARG="depth" ;;
        --output) NEXT_ARG="output" ;;
        -*)       echo "Unknown option: $arg"; exit 1 ;;
        *)        POSITIONAL+=("$arg") ;;
    esac
done

# Positional args: FILE_KEY [OUTPUT_DIR]
if [[ ${#POSITIONAL[@]} -ge 1 ]]; then
    FILE_KEY="${POSITIONAL[0]}"
fi
if [[ ${#POSITIONAL[@]} -ge 2 ]]; then
    OUTPUT_DIR="${POSITIONAL[1]}"
fi

# Require file key
if [[ -z "$FILE_KEY" ]]; then
    echo "[ERROR] Figma file key is required."
    echo "  Usage: ./capture-figma-refs.sh <FILE_KEY> [OUTPUT_DIR] [options]"
    echo "  Or set: export FIGMA_FILE_KEY=<key>"
    exit 1
fi

# ── Resolve FIGMA_ACCESS_TOKEN ───────────────────────────────────────────────
# Validate existing token if set
if [[ -n "${FIGMA_ACCESS_TOKEN:-}" ]]; then
  HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" "https://api.figma.com/v1/me" 2>/dev/null || true)
  if [[ "$HTTP_CODE" != "200" ]]; then
    echo "[WARN] Existing FIGMA_ACCESS_TOKEN is invalid (HTTP $HTTP_CODE), will auto-detect..."
    unset FIGMA_ACCESS_TOKEN
  fi
fi

if [[ -z "${FIGMA_ACCESS_TOKEN:-}" ]]; then
  echo "[INFO] FIGMA_ACCESS_TOKEN not set, trying to extract from running figma-console-mcp..."
  # Try processes from newest to oldest — older ones may have expired tokens
  while IFS= read -r MCP_PID; do
    [[ -z "$MCP_PID" ]] && continue
    TOKEN=$(ps -Eww -p "$MCP_PID" 2>/dev/null | grep -oE 'FIGMA_ACCESS_TOKEN=[^ ]+' | head -1 | cut -d= -f2 || true)
    if [[ -n "${TOKEN:-}" ]]; then
      # Verify the token is still valid
      HTTP_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" -H "X-Figma-Token: $TOKEN" "https://api.figma.com/v1/me" 2>/dev/null || true)
      if [[ "$HTTP_STATUS" == "200" ]]; then
        export FIGMA_ACCESS_TOKEN="$TOKEN"
        echo "[INFO] Extracted valid token from PID $MCP_PID"
        break
      fi
    fi
  done <<< "$(pgrep -f 'figma-console' 2>/dev/null | sort -rn)"
fi

if [[ -z "${FIGMA_ACCESS_TOKEN:-}" ]]; then
  echo "[ERROR] FIGMA_ACCESS_TOKEN is required."
  echo "  Set it via: export FIGMA_ACCESS_TOKEN=figd_..."
  echo "  Or ensure figma-console-mcp is running (token will be auto-detected)."
  exit 1
fi

# ── Check dependencies ───────────────────────────────────────────────────────
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "[ERROR] $cmd is required but not found."
    exit 1
  fi
done

mkdir -p "$OUTPUT_DIR"

# ── Discover frames from Figma file tree ─────────────────────────────────────
echo "[API] Fetching file tree (depth=$DEPTH)..."

# Get file tree — save to temp file (response can be several MB)
TREE_TMP=$(mktemp)
trap 'rm -f "$TREE_TMP"' EXIT

HTTP_CODE=$(curl -sS -w "%{http_code}" \
  -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/files/${FILE_KEY}?depth=${DEPTH}" \
  -o "$TREE_TMP")

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "[ERROR] Figma API returned HTTP $HTTP_CODE"
  jq . < "$TREE_TMP" 2>/dev/null || cat "$TREE_TMP"
  exit 1
fi

FILE_SIZE=$(wc -c < "$TREE_TMP" | tr -d ' ')
echo "[INFO] File tree: ${FILE_SIZE} bytes"

API_ERR=$(jq -r '.status // empty' < "$TREE_TMP" 2>/dev/null || true)
if [[ "$API_ERR" == "403" ]] || [[ "$API_ERR" == "404" ]]; then
  echo "[ERROR] Figma API error: $(jq -r '.err // .message // "unknown"' < "$TREE_TMP")"
  exit 1
fi

# Build jq filter based on whether a page filter is specified
if [[ -n "$PAGE_NAME" ]]; then
  # Extract FRAME nodes from a specific page (with sections at depth 3)
  JQ_FILTER=$(cat <<'JQEOF'
    .document.children[]
    | select(.name == $page)
    | .. | select(.type? == "FRAME")
    | { name: (.name | split(" ") | .[0] | split("—") | .[0] | gsub("\\s+$"; "")),
        fullName: .name,
        id: .id }
JQEOF
  )
  SCREEN_JSON=$(jq -c --arg page "$PAGE_NAME" "$JQ_FILTER" < "$TREE_TMP")
else
  # Extract ALL FRAME nodes from all pages
  JQ_FILTER=$(cat <<'JQEOF'
    .document.children[]
    | .. | select(.type? == "FRAME")
    | { name: (.name | split(" ") | .[0] | split("—") | .[0] | gsub("\\s+$"; "")),
        fullName: .name,
        id: .id }
JQEOF
  )
  SCREEN_JSON=$(jq -c "$JQ_FILTER" < "$TREE_TMP")
fi

if [[ -z "$SCREEN_JSON" ]]; then
  if [[ -n "$PAGE_NAME" ]]; then
    echo "[ERROR] No FRAME nodes found on page \"$PAGE_NAME\"."
  else
    echo "[ERROR] No FRAME nodes found in the file."
  fi
  exit 1
fi

# Build associative arrays from discovered frames
declare -A SCREENS=()       # name -> nodeId
declare -A SCREEN_LABELS=() # name -> full Figma name

while IFS= read -r line; do
  base_name=$(echo "$line" | jq -r '.name')
  node_id=$(echo "$line" | jq -r '.id')
  full_name=$(echo "$line" | jq -r '.fullName')
  # Deduplicate: if name already exists, append -v2, -v3, etc.
  name="$base_name"
  if [[ -n "${SCREENS[$name]+x}" ]]; then
    i=2
    while [[ -n "${SCREENS[${base_name}-v${i}]+x}" ]]; do
      i=$((i + 1))
    done
    name="${base_name}-v${i}"
  fi
  SCREENS["$name"]="$node_id"
  SCREEN_LABELS["$name"]="$full_name"
done <<< "$SCREEN_JSON"

TOTAL=${#SCREENS[@]}
PAGE_MSG=""
[[ -n "$PAGE_NAME" ]] && PAGE_MSG=" on page \"$PAGE_NAME\""
echo "[INFO] Discovered $TOTAL FRAME nodes${PAGE_MSG}"

# ── Clean mode: remove orphan PNGs ──────────────────────────────────────────
if [[ "$CLEAN" == true ]]; then
  REMOVED=0
  for f in "$OUTPUT_DIR"/*.png; do
    [[ -f "$f" ]] || continue
    base=$(basename "$f" .png)
    if [[ -z "${SCREENS[$base]+x}" ]]; then
      echo "[CLEAN] Removing $base.png (no matching Figma frame)"
      rm "$f"
      REMOVED=$((REMOVED + 1))
    fi
  done
  echo "[CLEAN] Removed $REMOVED orphan file(s)."
  [[ "$FORCE" != true && "$LIST_ONLY" != true ]] && exit 0
fi

# ── List mode ────────────────────────────────────────────────────────────────
if [[ "$LIST_ONLY" == true ]]; then
  echo ""
  echo "Frame ID -> Figma Node ($TOTAL frames)"
  echo "──────────────────────────────────────────────────────────────"
  for screen in $(echo "${!SCREENS[@]}" | tr ' ' '\n' | sort); do
    exists=" "
    [[ -f "$OUTPUT_DIR/${screen}.png" ]] && exists="✓"
    printf "  [%s] %-22s %-10s  %s\n" "$exists" "$screen" "${SCREENS[$screen]}" "${SCREEN_LABELS[$screen]}"
  done
  echo ""
  echo "✓ = file exists in $OUTPUT_DIR/"
  exit 0
fi

# ── Determine which frames need downloading ──────────────────────────────────
TO_DOWNLOAD=()
for screen in "${!SCREENS[@]}"; do
  if [[ "$FORCE" == true ]] || [[ ! -f "$OUTPUT_DIR/${screen}.png" ]]; then
    TO_DOWNLOAD+=("$screen")
  fi
done

if [[ ${#TO_DOWNLOAD[@]} -eq 0 ]]; then
  echo "All $TOTAL screenshots already exist. Use --force to re-download."
  exit 0
fi

echo ""
echo "=========================================="
echo "  Figma Reference Screenshot Exporter"
echo "=========================================="
echo "File key:  $FILE_KEY"
echo "Scale:     ${SCALE}x"
echo "Output:    $OUTPUT_DIR"
echo "To export: ${#TO_DOWNLOAD[@]} of $TOTAL frames"
echo ""

# ── Build comma-separated node IDs for batch image API call ──────────────────
IDS=""
for screen in "${TO_DOWNLOAD[@]}"; do
  node_id="${SCREENS[$screen]}"
  if [[ -n "$IDS" ]]; then
    IDS="${IDS},${node_id}"
  else
    IDS="${node_id}"
  fi
done

echo "[API] Requesting image URLs for ${#TO_DOWNLOAD[@]} nodes..."

RESPONSE=$(curl -sS \
  -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/images/${FILE_KEY}?ids=${IDS}&scale=${SCALE}&format=png")

API_ERR=$(echo "$RESPONSE" | jq -r '.err // empty' 2>/dev/null)
if [[ -n "$API_ERR" ]]; then
  echo "[ERROR] Figma API error: $API_ERR"
  echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
  exit 1
fi

# ── Download each image ──────────────────────────────────────────────────────
DOWNLOADED=0
FAILED=0

for screen in $(echo "${TO_DOWNLOAD[@]}" | tr ' ' '\n' | sort); do
  node_id="${SCREENS[$screen]}"
  output_file="$OUTPUT_DIR/${screen}.png"

  IMAGE_URL=$(echo "$RESPONSE" | jq -r ".images[\"${node_id}\"] // empty" 2>/dev/null)

  if [[ -z "$IMAGE_URL" ]] || [[ "$IMAGE_URL" == "null" ]]; then
    echo "[FAIL] $screen — no image URL returned (node: $node_id)"
    FAILED=$((FAILED + 1))
    continue
  fi

  printf "[DOWNLOAD] %-22s " "$screen..."
  if curl -sL "$IMAGE_URL" -o "$output_file"; then
    SIZE=$(wc -c < "$output_file" | tr -d ' ')
    echo "OK ($(( SIZE / 1024 ))KB)"
    DOWNLOADED=$((DOWNLOADED + 1))
  else
    echo "FAILED"
    rm -f "$output_file"
    FAILED=$((FAILED + 1))
  fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "=========================================="
echo "  Done: $DOWNLOADED downloaded, $FAILED failed"
EXISTING=$(ls "$OUTPUT_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')
echo "  Total PNGs in output dir: $EXISTING"
echo "=========================================="
