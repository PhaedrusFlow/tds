#!/usr/bin/env bash
# Salesforce API Report Script
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
########################################################################
This script checks Salesforce API usage with Salesforce CLI and sends alerts to Slack and/or email when thresholds are crossed.
#Requirements: sf, jq, curl, mailx
### An authenticated Salesforce org alias/username
#Salesforce CLI exposes org limits through sf org list limits, including API request remaining/max.
#Salesforce and the REST API limits resource describe API usage as remaining and maximum allocation values.
#Slack incoming webhooks accept JSON payloads over HTTP POST.
#Examples
#Slack only
#./salesforce-api-alert.sh \
#  --target-org map-dev \
#  --warn 60 \
#  --crit 80 \
#  --slack-webhook https://hooks.slack.com/services/...
#Email only
#./salesforce-api-alert.sh \
#  --target-org map-dev \
#  --warn 70 \
#  --crit 90 \
#  --email-to ops@example.com
#Avoid duplicate alerts
#./salesforce-api-alert.sh \
#  --target-org map-dev \
#  --slack-webhook https://hooks.slack.com/services/... \
#  --state-file .state/salesforce-api-alert-map-dev.state
#Dry run
#./salesforce-api-alert.sh \
#  --target-org map-dev \
#  --slack-webhook https://hooks.slack.com/services/... \
#  --dry-run
#JSON output
#./salesforce-api-alert.sh --target-org map-dev --json
#Scheduling
#Cron example every 15 minutes:
#*/15 * * * * /path/to/salesforce-api-alert.sh \
#  --target-org map-dev \
#  --warn 60 \
#  --crit 80 \
#  --slack-webhook https://hooks.slack.com/services/... \
#  --state-file /path/to/state/map-dev.state >> /var/log/salesforce-api-alert.log 2>&1
############# Salesforce also provides API Usage Notifications in Setup, where you can configure an admin to receive email when usage exceeds a chosen threshold within a selected interval. #############
set -euo pipefail
usage()
{
    cat << USAGE
Usage:
  $0 --target-org <alias-or-username> [--top <n>] [--sobjects "Account,Contact,WorkOrder"] [--json]
Description:
  Produces a compact API/storage report from Salesforce CLI.
  - Reads org limits to estimate API usage remaining/max.
  - Reads approximate record counts for storage-related object counts.
  - Optionally filters to specific sObjects.

Examples:
  $0 --target-org map-dev
  $0 --target-org tds-prod --top 15
  $0 --target-org fst-dashboard-dev --sobjects "Account,Contact,Lead"
USAGE
}

TARGET_ORG=""
TOP_N=20
SOBJECTS=""
JSON_MODE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target-org | -o)
            TARGET_ORG="${2:-}"
            shift 2
            ;;
        --top)
            TOP_N="${2:-20}"
            shift 2
            ;;
        --sobjects)
            SOBJECTS="${2:-}"
            shift 2
            ;;
        --json)
            JSON_MODE=1
            shift
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z $TARGET_ORG ]]; then
    echo "Error: --target-org is required" >&2
    usage >&2
    exit 1
fi

for cmd in sf jq; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
        echo "Error: required command not found: $cmd" >&2
        exit 1
    fi
done
LIMITS_JSON="$(sf org list limits --target-org "$TARGET_ORG" --json)"
if [[ -n $SOBJECTS ]]; then
    IFS=',' read -r -a arr <<< "$SOBJECTS"
    SOBJECT_ARGS=()
    for s in "${arr[@]}"; do
        s_trimmed="$(echo "$s" | sed 's/^ *//;s/ *$//')"
        [[ -n $s_trimmed ]] && SOBJECT_ARGS+=(--sobject "$s_trimmed")
    done
    RECORDS_JSON="$(sf org list sobject record-counts --target-org "$TARGET_ORG" "${SOBJECT_ARGS[@]}" --json)"
else
    RECORDS_JSON="$(sf org list sobject record-counts --target-org "$TARGET_ORG" --json)"
fi
if [[ $JSON_MODE -eq 1 ]]; then
    jq -n \
        --arg targetOrg "$TARGET_ORG" \
        --argjson limits "$LIMITS_JSON" \
        --argjson records "$RECORDS_JSON" \
        '{targetOrg:$targetOrg, limits:$limits.result, recordCounts:$records.result}'
    exit 0
fi
api_remaining="$(echo "$LIMITS_JSON" | jq -r '.result[] | select(.name=="DailyApiRequests" or .name=="ApiRequests") | .remaining' | head -n1)"
api_max="$(echo "$LIMITS_JSON" | jq -r '.result[] | select(.name=="DailyApiRequests" or .name=="ApiRequests") | .max' | head -n1)"
active_scratch_remaining="$(echo "$LIMITS_JSON" | jq -r '.result[] | select(.name=="ActiveScratchOrgs") | .remaining' | head -n1)"
active_scratch_max="$(echo "$LIMITS_JSON" | jq -r '.result[] | select(.name=="ActiveScratchOrgs") | .max' | head -n1)"
daily_scratch_remaining="$(echo "$LIMITS_JSON" | jq -r '.result[] | select(.name=="DailyScratchOrgs") | .remaining' | head -n1)"
daily_scratch_max="$(echo "$LIMITS_JSON" | jq -r '.result[] | select(.name=="DailyScratchOrgs") | .max' | head -n1)"
echo "Salesforce usage report for: $TARGET_ORG"
echo
printf '%-28s %s\n' "API requests remaining/max:" "${api_remaining:-N/A}/${api_max:-N/A}"
printf '%-28s %s\n' "Active scratch orgs:" "${active_scratch_remaining:-N/A}/${active_scratch_max:-N/A}"
printf '%-28s %s\n' "Daily scratch orgs:" "${daily_scratch_remaining:-N/A}/${daily_scratch_max:-N/A}"
echo
echo "Top record counts"
echo "-----------------"
echo "$RECORDS_JSON" | jq -r '
  .result
  | sort_by(.count // 0)
  | reverse
  | .[]
  | [.sObjectType, (.count // 0)]
  | @tsv
' | head -n "$TOP_N" | awk -F'\t' '{printf "%-40s %12s\n", $1, $2}'

echo
echo "Tip: record counts are approximate and align with Salesforce Storage Usage reporting."
