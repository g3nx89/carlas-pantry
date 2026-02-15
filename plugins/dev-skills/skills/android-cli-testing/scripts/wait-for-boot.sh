#!/usr/bin/env bash
# wait-for-boot.sh — Robust emulator boot-wait with timeout
#
# Usage:
#   ./wait-for-boot.sh                    # Default 300s timeout
#   BOOT_TIMEOUT=120 ./wait-for-boot.sh   # Custom timeout
#   EMULATOR_SERIAL=emulator-5556 ./wait-for-boot.sh  # Target specific emulator
#
# Checks sys.boot_completed, init.svc.bootanim, AND PackageManager readiness
# before declaring ready. After boot: dismisses lock screen and disables
# all animations for testing.

set -euo pipefail

TIMEOUT=${BOOT_TIMEOUT:-300}
WAIT_FOR_DEVICE_TIMEOUT=60
INTERVAL=5
ELAPSED=0
SERIAL=${EMULATOR_SERIAL:-""}

ADB_CMD=(adb)
if [ -n "$SERIAL" ]; then
  ADB_CMD=(adb -s "$SERIAL")
fi

echo "Waiting for emulator to come online (timeout: ${WAIT_FOR_DEVICE_TIMEOUT}s)..."
if ! timeout "$WAIT_FOR_DEVICE_TIMEOUT" "${ADB_CMD[@]}" wait-for-device; then
  echo "ERROR: Emulator did not come online within ${WAIT_FOR_DEVICE_TIMEOUT}s"
  exit 1
fi

echo "Waiting for boot to complete (timeout: ${TIMEOUT}s)..."
while true; do
  BOOT_COMPLETE=$("${ADB_CMD[@]}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || echo "")
  BOOT_ANIM=$("${ADB_CMD[@]}" shell getprop init.svc.bootanim 2>/dev/null | tr -d '\r' || echo "")

  if [ "$BOOT_COMPLETE" = "1" ] && [ "$BOOT_ANIM" = "stopped" ]; then
    # Verify PackageManager is ready (prevents race on app install)
    if "${ADB_CMD[@]}" shell pm list packages 2>/dev/null | head -1 | grep -q "package:"; then
      echo "Boot completed after ${ELAPSED}s"
      break
    fi
  fi

  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "ERROR: Boot timed out after ${TIMEOUT}s"
    exit 1
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

# Dismiss lock screen and disable animations for testing
"${ADB_CMD[@]}" shell input keyevent 82
"${ADB_CMD[@]}" shell settings put global window_animation_scale 0
"${ADB_CMD[@]}" shell settings put global transition_animation_scale 0
"${ADB_CMD[@]}" shell settings put global animator_duration_scale 0

echo "Emulator ready!"
