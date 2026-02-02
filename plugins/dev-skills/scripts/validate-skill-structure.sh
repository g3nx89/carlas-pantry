#!/bin/bash
# Validate skill structure for dev-skills plugin
# Checks that all skills follow best practices:
# - SKILL.md exists
# - Description uses third-person format
# - No emojis in section headers
# - All referenced files exist

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/../skills"
ERRORS=0
WARNINGS=0

echo "Validating skills in $SKILLS_DIR..."
echo ""

for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    skill_file="$skill_dir/SKILL.md"

    echo "Checking $skill_name..."

    # Check SKILL.md exists
    if [[ ! -f "$skill_file" ]]; then
        echo "  ERROR: SKILL.md missing"
        ((ERRORS++))
        continue
    fi

    # Check third-person description
    if ! grep -q "This skill should be used when" "$skill_file" 2>/dev/null; then
        echo "  WARNING: Description not in third-person format"
        ((WARNINGS++))
    fi

    # Check for emojis in section headers
    if grep -E "^##.*[🔧🔴⚠️📱🧠⚡📝📋📚✅❌]" "$skill_file" >/dev/null 2>&1; then
        echo "  WARNING: Emojis found in section headers"
        ((WARNINGS++))
    fi

    # Check allowed-tools is defined
    if ! grep -q "^allowed-tools:" "$skill_file" 2>/dev/null; then
        echo "  WARNING: allowed-tools not defined in frontmatter"
        ((WARNINGS++))
    fi

    # Check references exist
    refs=$(grep -oE '\(references/[^)]+\)' "$skill_file" 2>/dev/null | sed 's/[()]//g' | sort -u || true)
    for ref in $refs; do
        if [[ ! -f "$skill_dir/$ref" ]]; then
            echo "  ERROR: Missing reference file: $ref"
            ((ERRORS++))
        fi
    done

    # Check scripts exist
    scripts=$(grep -oE '\`scripts/[^`]+\`' "$skill_file" 2>/dev/null | sed 's/`//g' | sort -u || true)
    for script in $scripts; do
        if [[ ! -f "$skill_dir/$script" ]]; then
            echo "  ERROR: Missing script file: $script"
            ((ERRORS++))
        fi
    done

    echo "  OK"
done

echo ""
echo "========================================="
echo "Validation Summary"
echo "========================================="
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [[ $ERRORS -gt 0 ]]; then
    echo "FAILED: $ERRORS error(s) found"
    exit 1
elif [[ $WARNINGS -gt 0 ]]; then
    echo "PASSED with $WARNINGS warning(s)"
    exit 0
else
    echo "PASSED: All skills validated successfully"
    exit 0
fi
