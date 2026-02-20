#!/usr/bin/env bash
# planning-hint.sh — EHRB (Environmental/Human/Regulatory/Business) risk routing hook
# Strategy S7: Reads spec content from stdin, scans for risk category keywords,
# outputs a mode suggestion hint for the orchestrator.
#
# Usage:
#   cat spec.md | ./planning-hint.sh
#   echo "payment processing with GDPR compliance" | ./planning-hint.sh
#
# Output (JSON):
#   { "suggested_mode": "advanced", "risk_categories": ["financial", "compliance"], "keyword_count": 4 }

set -euo pipefail

# Require Bash 4+ for associative arrays (macOS ships Bash 3.2)
if ((BASH_VERSINFO[0] < 4)); then
  echo '{"suggested_mode":"standard","risk_categories":[],"keyword_count":0,"error":"bash 4+ required for associative arrays"}' >&2
  exit 0
fi

# Read stdin into variable
INPUT=$(cat)

# Risk category keyword patterns (case-insensitive via grep -i)
declare -A CATEGORIES

CATEGORIES[financial]="payment|billing|credit.card|transaction|financial|invoice|refund|subscription|pricing|stripe|paypal"
CATEGORIES[compliance]="GDPR|HIPAA|SOC2|PCI.DSS|compliance|regulation|audit|data.retention|right.to.forget|consent"
CATEGORIES[security]="authentication|authorization|encryption|credential|password|token|OAuth|SAML|JWT|XSS|injection|CSRF"
CATEGORIES[infrastructure]="migration|database.schema|scaling|load.balancer|CDN|containeriz|kubernetes|terraform|CI.CD|deploy"
CATEGORIES[data_sensitivity]="PII|PHI|personal.data|sensitive|confidential|secret|API.key|private.key|certificate"

matched_categories=()
total_keywords=0

for category in "${!CATEGORIES[@]}"; do
  pattern="${CATEGORIES[$category]}"
  count=$(echo "$INPUT" | grep -ioE "$pattern" | wc -l | tr -d ' ')

  if [ "$count" -gt 0 ]; then
    matched_categories+=("\"$category\"")
    total_keywords=$((total_keywords + count))
  fi
done

# Determine suggested mode based on matches
num_categories=${#matched_categories[@]}

if [ "$num_categories" -ge 3 ] || [ "$total_keywords" -ge 8 ]; then
  suggested_mode="complete"
elif [ "$num_categories" -ge 2 ] || [ "$total_keywords" -ge 4 ]; then
  suggested_mode="advanced"
elif [ "$num_categories" -ge 1 ]; then
  suggested_mode="standard"
else
  suggested_mode="rapid"
fi

# Build JSON output
categories_json=$(IFS=,; echo "${matched_categories[*]:-}")

cat <<EOF
{
  "suggested_mode": "$suggested_mode",
  "risk_categories": [${categories_json}],
  "keyword_count": $total_keywords
}
EOF
