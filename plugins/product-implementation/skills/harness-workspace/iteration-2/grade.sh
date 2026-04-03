#!/bin/bash
# Grade eval outputs against assertions
# Usage: grade.sh <outputs_dir> <eval_id>

set -euo pipefail

OUTPUTS="$1"
EVAL_ID="$2"

pass=0
fail=0
results="["

check_file_exists() {
  local path="$1"
  local text="$2"
  # Try both direct path and dot-claude variant
  if [[ -f "$OUTPUTS/$path" ]]; then
    results="$results{\"text\":\"$text\",\"passed\":true,\"evidence\":\"File exists at $path\"},"
    pass=$((pass + 1))
  elif [[ -f "$OUTPUTS/${path/.claude/dot-claude}" ]]; then
    results="$results{\"text\":\"$text\",\"passed\":true,\"evidence\":\"File exists at ${path/.claude/dot-claude} (dot-claude variant)\"},"
    pass=$((pass + 1))
  else
    results="$results{\"text\":\"$text\",\"passed\":false,\"evidence\":\"File not found at $path\"},"
    fail=$((fail + 1))
  fi
}

check_file_contains() {
  local path="$1"
  local pattern="$2"
  local text="$3"
  local actual_path="$OUTPUTS/$path"
  # Try dot-claude variant
  if [[ ! -f "$actual_path" ]]; then
    actual_path="$OUTPUTS/${path/.claude/dot-claude}"
  fi
  if [[ -f "$actual_path" ]] && grep -qE "$pattern" "$actual_path" 2>/dev/null; then
    local match=$(grep -oE "$pattern" "$actual_path" 2>/dev/null | head -1)
    results="$results{\"text\":\"$text\",\"passed\":true,\"evidence\":\"Found: $match\"},"
    pass=$((pass + 1))
  elif [[ ! -f "$actual_path" ]]; then
    results="$results{\"text\":\"$text\",\"passed\":false,\"evidence\":\"File not found: $path\"},"
    fail=$((fail + 1))
  else
    results="$results{\"text\":\"$text\",\"passed\":false,\"evidence\":\"Pattern '$pattern' not found in $path\"},"
    fail=$((fail + 1))
  fi
}

check_file_json_valid() {
  local path="$1"
  local text="$2"
  local actual_path="$OUTPUTS/$path"
  if [[ -f "$actual_path" ]] && python3 -c "import json; json.load(open('$actual_path'))" 2>/dev/null; then
    results="$results{\"text\":\"$text\",\"passed\":true,\"evidence\":\"Valid JSON\"},"
    pass=$((pass + 1))
  elif [[ ! -f "$actual_path" ]]; then
    results="$results{\"text\":\"$text\",\"passed\":false,\"evidence\":\"File not found: $path\"},"
    fail=$((fail + 1))
  else
    results="$results{\"text\":\"$text\",\"passed\":false,\"evidence\":\"Invalid JSON in $path\"},"
    fail=$((fail + 1))
  fi
}

# ===== EVAL 2: nextjs-thorough-human-review =====
if [[ "$EVAL_ID" == "2" ]]; then
  check_file_json_valid ".specs/features/dashboard/.harness/feature-list.json" "feature-list.json exists and is valid JSON"
  # Also check alternate paths (some agents use .harness/ at root)
  check_file_contains ".specs/features/dashboard/.harness/eval-criteria.md" "[Aa]ccessib" "eval-criteria.md mentions accessibility"
  check_file_contains ".specs/features/dashboard/.harness/eval-criteria.md" "[Ee]valuator" "eval-criteria.md contains evaluator prompt"
  # Playwright check - try both files
  found_pw=false
  for f in ".specs/features/dashboard/.harness/eval-criteria.md" ".specs/features/dashboard/.harness/session-startup.md" ".harness/eval-criteria.md" ".harness/session-startup.md"; do
    actual="$OUTPUTS/$f"
    if [[ -f "$actual" ]] && grep -qiE "[Pp]laywright" "$actual" 2>/dev/null; then
      found_pw=true
      break
    fi
  done
  if $found_pw; then
    results="$results{\"text\":\"eval-criteria or session-startup mentions Playwright\",\"passed\":true,\"evidence\":\"Found Playwright reference\"},"
    pass=$((pass + 1))
  else
    results="$results{\"text\":\"eval-criteria or session-startup mentions Playwright\",\"passed\":false,\"evidence\":\"Playwright not found in eval-criteria or session-startup\"},"
    fail=$((fail + 1))
  fi
  check_file_contains ".claude/settings.json" "coverage" "hooks include coverage check"
fi

# ===== EVAL 4: nextjs-eval-loop-with-playwright =====
if [[ "$EVAL_ID" == "4" ]]; then
  check_file_exists ".specs/features/dashboard/.harness/evaluator-prompt.md" "evaluator-prompt.md exists"
  check_file_contains ".specs/features/dashboard/.harness/evaluator-prompt.md" "[Pp]laywright" "evaluator prompt mentions Playwright"
  check_file_contains ".specs/features/dashboard/.harness/evaluator-prompt.md" "[Ss]keptic" "evaluator prompt includes skepticism"
  # calibration examples
  found_cal=false
  for f in ".specs/features/dashboard/.harness/evaluator-prompt.md"; do
    actual="$OUTPUTS/$f"
    if [[ -f "$actual" ]] && grep -qiE "[Cc]alibrat|[Ee]xample.*[Ss]core|[Ss]core.*[0-9]" "$actual" 2>/dev/null; then
      found_cal=true
      break
    fi
  done
  if $found_cal; then
    results="$results{\"text\":\"evaluator prompt includes calibration examples\",\"passed\":true,\"evidence\":\"Found calibration/example references\"},"
    pass=$((pass + 1))
  else
    results="$results{\"text\":\"evaluator prompt includes calibration examples\",\"passed\":false,\"evidence\":\"No calibration examples found\"},"
    fail=$((fail + 1))
  fi
  check_file_contains ".specs/features/dashboard/.harness/evaluation-report-template.md" "[Vv]erdict\|PASS\|FAIL" "report template has verdict format"
  check_file_contains ".specs/features/dashboard/.harness/sprint-contract.md" "[Vv]erif\|[Cc]riterion\|[Hh]ow to" "sprint contract has verifiable criteria"
  check_file_exists ".claude/scripts/launch-app.sh" "launch-app.sh exists"
  check_file_contains ".claude/scripts/launch-app.sh" "npm\|next\|localhost" "launch-app.sh has dev server command"
  check_file_contains ".specs/features/dashboard/.harness/session-startup.md" "evaluation.report\|evaluation-report\|eval.*report" "session-startup includes eval report check"
  check_file_contains ".specs/features/dashboard/.harness/eval-criteria.md" "[Tt]hreshold\|[Bb]locking" "eval-criteria has hard thresholds"
  check_file_contains ".specs/features/dashboard/.harness/analysis.json" "evaluation_loop\|eval.*loop\|evaluation" "analysis.json records evaluation loop"
  check_file_contains ".specs/features/dashboard/.harness/analysis.json" "web\|playwright\|Playwright" "analysis.json records web platform"
fi

# ===== EVAL 5: android-eval-loop-with-cli-agents =====
if [[ "$EVAL_ID" == "5" ]]; then
  check_file_exists "features/user-auth/.harness/evaluator-prompt.md" "evaluator-prompt.md exists"
  check_file_contains "features/user-auth/.harness/evaluator-prompt.md" "mobile.mcp\|emulator\|mobile_" "evaluator prompt mentions mobile-mcp"
  check_file_contains "features/user-auth/.harness/evaluator-prompt.md" "[Ss]keptic" "evaluator prompt includes skepticism"
  check_file_exists "features/user-auth/.harness/sprint-contract.md" "sprint-contract.md exists"
  check_file_exists "features/user-auth/.harness/evaluation-report-template.md" "evaluation-report-template.md exists"
  check_file_exists ".claude/scripts/uat-dispatch.sh" "uat-dispatch.sh exists"
  check_file_contains ".claude/scripts/uat-dispatch.sh" "codex\|gemini" "uat-dispatch supports codex/gemini"
  check_file_exists ".claude/scripts/external-review.sh" "external-review.sh exists"
  check_file_exists "AGENTS.md" "AGENTS.md generated for Codex"
  check_file_exists "GEMINI.md" "GEMINI.md generated for Gemini"
  check_file_contains "features/user-auth/.harness/session-startup.md" "evaluation.report\|evaluation-report\|eval.*report" "session-startup includes eval report check"
  check_file_contains "features/user-auth/.harness/analysis.json" "evaluation_loop\|eval.*loop\|evaluation" "analysis.json records eval loop"
  check_file_contains "features/user-auth/.harness/analysis.json" "mobile" "analysis.json records mobile platform"
  check_file_contains "features/user-auth/.harness/analysis.json" "codex\|gemini" "analysis.json records CLI agents"
fi

# ===== EVAL 6: nextjs-codex-plugin-thorough =====
if [[ "$EVAL_ID" == "6" ]]; then
  check_file_json_valid ".specs/features/dashboard/.harness/feature-list.json" "feature-list.json exists and is valid JSON"
  check_file_contains ".specs/features/dashboard/.harness/eval-criteria.md" "REVISE" "eval-criteria.md uses 3-tier verdict (REVISE)"
  check_file_contains ".specs/features/dashboard/.harness/eval-criteria.md" "[Ww]eight|%" "eval-criteria.md has dimension weights"
  check_file_contains ".specs/features/dashboard/.harness/evaluation-report-template.md" "eval-reports|timestamp|YYYY" "evaluation-report-template.md has timestamped pattern"
  check_file_contains ".specs/features/dashboard/.harness/evaluation-report-template.md" "[Ss]core.*[Tt]rend|[Tt]rend" "evaluation-report-template.md has Score Trend section"
  check_file_exists ".specs/features/dashboard/.harness/evaluator-tuning-log.md" "evaluator-tuning-log.md exists"
  check_file_contains ".specs/features/dashboard/.harness/evaluator-tuning-log.md" "[Oo]bservation|[Aa]djustment" "evaluator-tuning-log has observation/adjustment structure"
  check_file_contains ".specs/features/dashboard/.harness/sprint-contract.md" "[Hh]ow to [Vv]erify|[Vv]erification" "sprint-contract.md has verification table"
  check_file_contains ".specs/features/dashboard/.harness/sprint-contract.md" "[Dd]efinition of [Dd]one|[Dd]one" "sprint-contract.md has Definition of Done"
  check_file_contains ".specs/features/dashboard/.harness/session-startup.md" "eval-reports|eval.reports" "session-startup.md references eval-reports directory"
  # Codex plugin checks
  found_codex=false
  for f in ".specs/features/dashboard/.harness/session-startup.md" ".specs/features/dashboard/.harness/eval-criteria.md" ".specs/features/dashboard/.harness/evaluator-prompt.md"; do
    actual="$OUTPUTS/$f"
    if [[ -f "$actual" ]] && grep -qiE "adversarial|/codex:" "$actual" 2>/dev/null; then
      found_codex=true
      break
    fi
  done
  if $found_codex; then
    results="$results{\"text\":\"session-startup or evaluator-prompt references adversarial/codex\",\"passed\":true,\"evidence\":\"Found adversarial or /codex: reference\"},"
    pass=$((pass + 1))
  else
    results="$results{\"text\":\"session-startup or evaluator-prompt references adversarial/codex\",\"passed\":false,\"evidence\":\"No adversarial or /codex: reference found\"},"
    fail=$((fail + 1))
  fi
  check_file_contains ".specs/features/dashboard/.harness/session-startup.md" "stop.gate|review.gate|enable-review-gate" "session-startup mentions stop gate as opt-in"
  check_file_contains ".specs/features/dashboard/.harness/analysis.json" "codex_plugin|codex.plugin" "analysis.json records codex_plugin as true"
  check_file_exists "AGENTS.md" "AGENTS.md generated"
  check_file_contains ".specs/features/dashboard/.harness/evaluator-prompt.md" "[Nn]ext|[Rr]eact|[Rr]echarts|dashboard" "evaluator-prompt.md has project-specific Next.js content"
fi

# ===== EVAL 7: bare-api-eval-loop-no-ui =====
if [[ "$EVAL_ID" == "7" ]]; then
  check_file_json_valid "features/api-v2/.harness/feature-list.json" "feature-list.json exists and is valid JSON"
  check_file_exists "features/api-v2/.harness/evaluator-prompt.md" "evaluator-prompt.md exists"
  check_file_contains "features/api-v2/.harness/evaluator-prompt.md" "curl|HTTP|endpoint|API|request" "evaluator prompt focuses on API/HTTP testing"
  # Negative assertion: must NOT mention Playwright
  actual_path="$OUTPUTS/features/api-v2/.harness/evaluator-prompt.md"
  if [[ ! -f "$actual_path" ]]; then
    actual_path="$OUTPUTS/${actual_path/.claude/dot-claude}"
  fi
  if [[ -f "$actual_path" ]] && grep -qE "[Pp]laywright|browser_click|browser_navigate" "$actual_path" 2>/dev/null; then
    results="$results{\"text\":\"evaluator prompt does NOT mention Playwright or browser\",\"passed\":false,\"evidence\":\"Playwright/browser reference found in API-only evaluator\"},"
    fail=$((fail + 1))
  elif [[ -f "$actual_path" ]]; then
    results="$results{\"text\":\"evaluator prompt does NOT mention Playwright or browser\",\"passed\":true,\"evidence\":\"Correctly absent\"},"
    pass=$((pass + 1))
  else
    results="$results{\"text\":\"evaluator prompt does NOT mention Playwright or browser\",\"passed\":false,\"evidence\":\"File not found\"},"
    fail=$((fail + 1))
  fi
  check_file_contains "features/api-v2/.harness/eval-criteria.md" "REVISE" "eval-criteria.md uses 3-tier verdict (REVISE)"
  check_file_contains "features/api-v2/.harness/eval-criteria.md" "API|[Ee]rror|[Pp]erformance|[Cc]orrect" "eval-criteria.md has backend-relevant dimensions"
  check_file_contains "features/api-v2/.harness/evaluation-report-template.md" "eval-reports|timestamp|YYYY" "evaluation-report-template.md has timestamped pattern"
  check_file_contains "features/api-v2/.harness/sprint-contract.md" "curl|endpoint|POST|GET|HTTP|API" "sprint-contract.md has API-specific verification"
  check_file_contains "features/api-v2/.harness/analysis.json" "api" "analysis.json records api platform"
  check_file_contains "features/api-v2/.harness/session-startup.md" "eval-reports|eval.reports|evaluation" "session-startup.md references eval-reports directory"
  check_file_contains "features/api-v2/.harness/evaluator-prompt.md" "[Pp]ython|[Ff]ast[Aa][Pp][Ii]|pytest|uvicorn" "evaluator prompt has Python/FastAPI specific content"
  check_file_exists "AGENTS.md" "AGENTS.md generated for Codex"
  check_file_contains "features/api-v2/.harness/evaluator-prompt.md" "[Ll]og|[Oo]bserv|response.time|[Mm]etric" "evaluator prompt mentions log/observability checking"
fi

# ===== EVAL 8: android-codex-plugin-stop-gate =====
if [[ "$EVAL_ID" == "8" ]]; then
  check_file_json_valid "features/user-auth/.harness/feature-list.json" "feature-list.json exists and is valid JSON"
  check_file_contains "features/user-auth/.harness/eval-criteria.md" "REVISE" "eval-criteria.md uses 3-tier verdict (REVISE)"
  check_file_contains "features/user-auth/.harness/evaluator-prompt.md" "mobile.mcp|emulator|mobile_" "evaluator-prompt.md mentions mobile-mcp"
  check_file_contains "features/user-auth/.harness/evaluator-prompt.md" "[Ss]keptic" "evaluator-prompt.md includes skepticism"
  check_file_contains "features/user-auth/.harness/evaluation-report-template.md" "eval-reports|timestamp|YYYY" "evaluation-report-template.md has timestamped pattern"
  check_file_exists "features/user-auth/.harness/evaluator-tuning-log.md" "evaluator-tuning-log.md exists"
  check_file_contains "features/user-auth/.harness/sprint-contract.md" "[Hh]ow to [Vv]erify|[Vv]erification" "sprint-contract.md has verification table"
  check_file_contains "features/user-auth/.harness/session-startup.md" "adversarial|/codex:|codex.plugin" "session-startup mentions adversarial review or /codex:"
  check_file_contains "features/user-auth/.harness/session-startup.md" "stop.gate|review.gate|enable-review-gate" "session-startup mentions stop gate opt-in"
  # Rescue check across multiple files
  found_rescue=false
  for f in "features/user-auth/.harness/session-startup.md" "features/user-auth/.harness/eval-criteria.md" "CLAUDE.md"; do
    actual="$OUTPUTS/$f"
    if [[ -f "$actual" ]] && grep -qiE "rescue|/codex:rescue" "$actual" 2>/dev/null; then
      found_rescue=true
      break
    fi
  done
  if $found_rescue; then
    results="$results{\"text\":\"session-startup or eval-criteria mentions /codex:rescue for debugging\",\"passed\":true,\"evidence\":\"Found rescue reference\"},"
    pass=$((pass + 1))
  else
    results="$results{\"text\":\"session-startup or eval-criteria mentions /codex:rescue for debugging\",\"passed\":false,\"evidence\":\"No rescue reference found\"},"
    fail=$((fail + 1))
  fi
  check_file_contains "features/user-auth/.harness/analysis.json" "codex_plugin|codex.plugin" "analysis.json records codex_plugin"
  check_file_contains "features/user-auth/.harness/analysis.json" "mobile" "analysis.json records mobile platform"
  check_file_exists "AGENTS.md" "AGENTS.md generated"
  check_file_exists "GEMINI.md" "GEMINI.md generated"
  check_file_contains "features/user-auth/.harness/evaluator-prompt.md" "[Aa]ndroid|[Cc]ompose|[Kk]otlin|[Mm]aterial" "evaluator prompt has Android/Compose specific content"
fi

# Close JSON array
results="${results%,}]"

# Summary
total=$((pass + fail))
echo "{\"pass\": $pass, \"fail\": $fail, \"total\": $total, \"pass_rate\": $(python3 -c "print(round($pass/$total*100,1) if $total > 0 else 0)"), \"expectations\": $results}"
