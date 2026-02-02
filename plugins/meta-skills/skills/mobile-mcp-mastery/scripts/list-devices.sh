#!/bin/bash
# list-devices.sh - List available mobile devices for automation
# Usage: ./list-devices.sh [android|ios|all]

set -e

PLATFORM="${1:-all}"

echo "========================================"
echo "Available Mobile Devices"
echo "========================================"
echo ""

# Android devices
if [ "$PLATFORM" = "android" ] || [ "$PLATFORM" = "all" ]; then
    echo "--- Android Devices (ADB) ---"

    if command -v adb &> /dev/null; then
        # Use timeout to prevent hangs if ADB server is unresponsive
        timeout 10 adb devices -l 2>/dev/null | tail -n +2 | while read -r line; do
            if [ -n "$line" ]; then
                DEVICE_ID=$(echo "$line" | awk '{print $1}')
                DEVICE_INFO=$(echo "$line" | cut -d' ' -f2-)

                if [ -n "$DEVICE_ID" ]; then
                    # Get device model
                    MODEL=$(adb -s "$DEVICE_ID" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
                    SDK=$(adb -s "$DEVICE_ID" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')

                    echo "Device ID: $DEVICE_ID"
                    echo "  Model: ${MODEL:-Unknown}"
                    echo "  API Level: ${SDK:-Unknown}"
                    echo "  Status: $DEVICE_INFO"
                    echo ""
                fi
            fi
        done

        DEVICE_COUNT=$(timeout 5 adb devices 2>/dev/null | grep -v "List" | grep -v "^$" | wc -l | tr -d ' ')
        if [ "$DEVICE_COUNT" -eq 0 ]; then
            echo "No Android devices found."
            echo "Start an emulator with: emulator -avd <AVD_NAME>"
            echo "List AVDs with: emulator -list-avds"
        fi
    elif [ -n "$ANDROID_HOME" ] && [ -f "$ANDROID_HOME/platform-tools/adb" ]; then
        echo "Using ADB from ANDROID_HOME..."
        timeout 10 "$ANDROID_HOME/platform-tools/adb" devices -l 2>/dev/null | tail -n +2 | while read -r line; do
            if [ -n "$line" ]; then
                DEVICE_ID=$(echo "$line" | awk '{print $1}')
                if [ -n "$DEVICE_ID" ]; then
                    MODEL=$("$ANDROID_HOME/platform-tools/adb" -s "$DEVICE_ID" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
                    SDK=$("$ANDROID_HOME/platform-tools/adb" -s "$DEVICE_ID" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')
                    echo "Device ID: $DEVICE_ID"
                    echo "  Model: ${MODEL:-Unknown}"
                    echo "  API Level: ${SDK:-Unknown}"
                    echo ""
                fi
            fi
        done
    else
        echo "ADB not found. Set ANDROID_HOME or install Android platform-tools."
    fi

    echo ""
fi

# iOS devices (macOS only)
if [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "all" ]; then
    echo "--- iOS Simulators ---"

    if [[ "$(uname)" != "Darwin" ]]; then
        echo "iOS Simulators only available on macOS."
    elif command -v xcrun &> /dev/null; then
        # List booted simulators first (with timeout)
        echo "Running:"
        timeout 10 xcrun simctl list devices 2>/dev/null | grep "Booted" | while read -r line; do
            NAME=$(echo "$line" | sed 's/ (.*//g' | xargs)
            # Case-insensitive UDID match (iOS can return lowercase)
            UDID=$(echo "$line" | grep -oEi '[A-F0-9-]{36}')
            echo "  $NAME"
            echo "    UDID: $UDID"
            echo "    Status: Booted"
        done

        BOOTED_COUNT=$(timeout 5 xcrun simctl list devices 2>/dev/null | grep -c "Booted" || echo "0")
        if [ "$BOOTED_COUNT" -eq 0 ]; then
            echo "  (none)"
        fi

        echo ""
        echo "Available (not running):"
        timeout 10 xcrun simctl list devices available 2>/dev/null | grep -v "Booted" | grep -v "==" | grep -v "^--" | head -20 | while read -r line; do
            if [ -n "$line" ] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
                echo "  $line"
            fi
        done

        echo ""
        echo "To boot a simulator: xcrun simctl boot \"<Simulator Name>\""
    else
        echo "xcrun not found. Install Xcode and command line tools."
    fi

    echo ""

    # Physical iOS devices (if libimobiledevice installed)
    echo "--- iOS Physical Devices ---"
    if command -v idevice_id &> /dev/null; then
        PHYSICAL=$(idevice_id -l 2>/dev/null | wc -l | tr -d ' ')
        if [ "$PHYSICAL" -gt 0 ]; then
            idevice_id -l 2>/dev/null | while read -r udid; do
                NAME=$(idevicename -u "$udid" 2>/dev/null || echo "Unknown")
                echo "  $NAME"
                echo "    UDID: $udid"
            done
        else
            echo "  No physical iOS devices connected."
        fi
    else
        echo "  libimobiledevice not installed."
        echo "  Install with: brew install libimobiledevice"
    fi
fi

echo ""
echo "========================================"
echo "Use device IDs with mobile_use_device tool"
echo "========================================"
