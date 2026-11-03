#!/usr/bin/env bash
# PASS when the loaded Alertmanager config routes severity=warning to
# platform-oncall, severity=critical to pager, and everything else to
# team-default, and amtool accepts the configuration.
set -uo pipefail

am() { kubectl -n monitoring exec deploy/alertmanager -- amtool --alertmanager.url=http://localhost:9093 "$@" 2>&1; }

route_for() {
  # route_for LABEL=VALUE...: prints the receiver amtool picks for the labels.
  am config routes test "$@" | tr -d '[:space:]'
}

check() {
  # check EXPECTED LABEL=VALUE...
  local expected="$1"; shift
  local got
  got="$(route_for "$@")"
  if [ "$got" != "$expected" ]; then
    echo "FAIL: the labels '$*' go to the receiver '${got}', expected '${expected}'."
    exit 1
  fi
}

check platform-oncall alertname=TektonTooManyRunningTaskRuns severity=warning
check pager alertname=TektonControllerDown severity=critical
check team-default alertname=Watchdog severity=info

echo "PASS: warning goes to platform-oncall, critical to pager, everything else to team-default."
exit 0
