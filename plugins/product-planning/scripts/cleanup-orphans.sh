#!/usr/bin/env bash
# cleanup-orphans.sh — Gastown Layer 3: Periodic orphan sweep
# Finds PPID=1 processes matching codex/gemini patterns and kills them.
# Safe to run as a cron job or manually after dispatch sessions.

set -euo pipefail

echo "Scanning for orphaned CLI agent processes (PPID=1)..."

KILLED=0
while IFS= read -r line; do
  PID="$(echo "$line" | awk '{print $1}')"
  CMD="$(echo "$line" | awk '{$1=$2=""; print $0}' | xargs)"
  if kill -9 "$PID" 2>/dev/null; then
    echo "  Killed PID $PID: $CMD"
    KILLED=$((KILLED + 1))
  fi
done < <(ps -eo pid,ppid,args 2>/dev/null | awk '$2==1 && (/codex/ || /gemini/) && !/cleanup-orphans/ && !/dispatch-cli-agent/')

echo "Done. Killed $KILLED orphaned process(es)."
