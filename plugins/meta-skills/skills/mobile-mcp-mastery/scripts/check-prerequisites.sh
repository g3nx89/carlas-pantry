#!/bin/bash
# check-prerequisites.sh - Verify mobile-mcp prerequisites are installed
# Usage: ./check-prerequisites.sh [android|ios|all]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PLATFORM="${1:-all}"
ERRORS=0

print_status() {
    if [ "$2" = "ok" ]; then
        echo -e "${GREEN}[OK]${NC} $1"
    elif [ "$2" = "warn" ]; then
        echo -e "${YELLOW}[WARN]${NC} $1"
    else
        echo -e "${RED}[FAIL]${NC} $1"
        ERRORS=$((ERRORS + 1))
    fi
}

check_command() {
    if command -v "$1" &> /dev/null; then
        print_status "$1 found: $(command -v "$1")" "ok"
        return 0
    else
        print_status "$1 not found" "fail"
        return 1
    fi
}

echo "========================================"
echo "Mobile-MCP Prerequisites Check"
echo "Platform: $PLATFORM"
echo "========================================"
echo ""

# Common prerequisites
echo "--- Common Prerequisites ---"

# Node.js
MIN_NODE_VERSION=18
if check_command "node"; then
    NODE_VERSION=$(node --version)
    MAJOR_VERSION=$(echo "$NODE_VERSION" | cut -d. -f1 | tr -d 'v')
    if [[ "$MAJOR_VERSION" -ge "$MIN_NODE_VERSION" ]]; then
        print_status "Node.js version $NODE_VERSION (>=$MIN_NODE_VERSION required)" "ok"
    else
        print_status "Node.js version $NODE_VERSION (>=$MIN_NODE_VERSION required)" "fail"
    fi
fi

# npm
check_command "npm"

# npx
check_command "npx"

echo ""

# Android prerequisites
if [ "$PLATFORM" = "android" ] || [ "$PLATFORM" = "all" ]; then
    echo "--- Android Prerequisites ---"

    # ANDROID_HOME
    if [ -n "$ANDROID_HOME" ]; then
        print_status "ANDROID_HOME set: $ANDROID_HOME" "ok"
    else
        print_status "ANDROID_HOME not set" "fail"
        echo "  Set with: export ANDROID_HOME=/path/to/android/sdk"
    fi

    # Java
    if check_command "java"; then
        JAVA_VERSION=$(java -version 2>&1 | head -1)
        print_status "Java: $JAVA_VERSION" "ok"
    fi

    # JAVA_HOME
    if [ -n "$JAVA_HOME" ]; then
        print_status "JAVA_HOME set: $JAVA_HOME" "ok"
    else
        print_status "JAVA_HOME not set" "warn"
    fi

    # ADB
    if [ -n "$ANDROID_HOME" ] && [ -f "$ANDROID_HOME/platform-tools/adb" ]; then
        ADB_VERSION=$("$ANDROID_HOME/platform-tools/adb" version 2>&1 | head -1)
        print_status "ADB found: $ADB_VERSION" "ok"
    elif check_command "adb"; then
        ADB_VERSION=$(adb version 2>&1 | head -1)
        print_status "ADB in PATH: $ADB_VERSION" "ok"
    else
        print_status "ADB not found" "fail"
    fi

    # Check for running emulator (with timeout to prevent hangs)
    if command -v adb &> /dev/null; then
        if DEVICES=$(timeout 5 adb devices 2>/dev/null | grep -v "List" | grep -v "^$" | wc -l); then
            if [ "$DEVICES" -gt 0 ]; then
                print_status "Android device(s) connected: $DEVICES" "ok"
            else
                print_status "No Android devices connected" "warn"
            fi
        else
            print_status "ADB timed out (server may be unresponsive)" "warn"
        fi
    fi

    echo ""
fi

# iOS prerequisites (macOS only)
if [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "all" ]; then
    echo "--- iOS Prerequisites ---"

    if [[ "$(uname)" != "Darwin" ]]; then
        print_status "iOS development requires macOS" "fail"
    else
        # Xcode
        if check_command "xcodebuild"; then
            XCODE_VERSION=$(xcodebuild -version 2>&1 | head -1)
            print_status "Xcode: $XCODE_VERSION" "ok"
        fi

        # xcode-select
        if xcode-select -p &> /dev/null; then
            print_status "Xcode command line tools installed" "ok"
        else
            print_status "Xcode command line tools not installed" "fail"
            echo "  Install with: xcode-select --install"
        fi

        # simctl (with timeout to prevent hangs)
        if check_command "xcrun"; then
            if timeout 10 xcrun simctl list devices &> /dev/null; then
                print_status "simctl available" "ok"

                # Check for booted simulators
                BOOTED=$(xcrun simctl list devices | grep "Booted" | wc -l)
                if [ "$BOOTED" -gt 0 ]; then
                    print_status "iOS Simulator(s) running: $BOOTED" "ok"
                else
                    print_status "No iOS Simulators running" "warn"
                fi
            else
                print_status "simctl timed out or unavailable" "warn"
            fi
        fi
    fi

    echo ""
fi

# Summary
echo "========================================"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}All critical prerequisites satisfied!${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS critical issue(s) found.${NC}"
    echo "Please resolve before using mobile-mcp."
    exit 1
fi
