#!/usr/bin/env bash
# PASS when the loaded Alertmanager config groups alerts by alertname and sets
# group_wait 10s and repeat_interval 4h on the warning route, and
# repeat_interval 1h on the critical route.
set -uo pipefail

config="$(kubectl -n monitoring exec deploy/client -- sh -c \
  'curl -fsS http://alertmanager.monitoring:9093/api/v2/status | jq -r ".config.original"' 2>/dev/null)"
if [ -z "$config" ]; then
  echo "FAIL: could not read the loaded configuration from Alertmanager."
  exit 1
fi

# block RECEIVER: prints the route block that names the receiver.
block() {
  printf '%s\n' "$config" | awk -v r="$1" '
    /^[[:space:]]*- receiver:/ || /^[[:space:]]*receiver:/ { if (seen) exit; if ($0 ~ r) seen=1 }
    seen { print }'
}

warn="$(block platform-oncall)"
crit="$(block pager)"
for need in 'group_by' 'alertname' 'group_wait: 10s' 'repeat_interval: 4h'; do
  if ! printf '%s\n' "$warn" | grep -q "$need"; then
    echo "FAIL: the route for platform-oncall must have '$need'."
    exit 1
  fi
done
if ! printf '%s\n' "$crit" | grep -q 'repeat_interval: 1h'; then
  echo "FAIL: the route for pager must have 'repeat_interval: 1h'."
  exit 1
fi

echo "PASS: the routes group by alertname and use the required wait and repeat times."
exit 0
