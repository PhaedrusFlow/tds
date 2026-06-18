#!/usr/bin/env bash
# Salesforce Limit Check Script
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
# ########################################################################
#Examples
#./check-salesforce-limits.sh --target-org map-dev
#./check-salesforce-limits.sh --target-org fst-dashboard-dev --json
#./check-salesforce-api-and-storage.sh --target-org map-dev
#./check-salesforce-api-and-storage.sh --target-org map-dev --top 10
#./check-salesforce-api-and-storage.sh --target-org map-dev --sobjects "Account,Contact,Lead"
#./check-salesforce-api-and-storage.sh --target-org map-dev --json
#sf org list limits is provided by Salesforce CLI's limits plugin and returns remaining/max for limits in the org.
#sf org list sobject record-counts returns approximate record counts that correspond to the Storage Usage page in Setup.
#This does not directly calculate file storage consumption by ContentVersion/Files bytes; use Setup UI for exact file/data storage totals.
##########################################################################################################################################3
set -euo pipefail
check-salesforce-limits.sh
usage()
{
    cat << USAGE
Usage:
  $0 --target-org <alias-or-username> [--json]

Description:
  Shows Salesforce org limits with emphasis on API usage, scratch org allocations,
  and approximate object record counts that correspond to Storage Usage in Setup.

Examples:
  $0 --target-org map-dev
  $0 --target-org fst-dashboard-dev --json
USAGE
}

TARGET_ORG=""
JSON_MODE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target-org | -o)
            TARGET_ORG="${2:-}"
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
if ! command -v sf > /dev/null 2>&1; then
    echo "Error: Salesforce CLI (sf) not found in PATH" >&2
    exit 1
fi
if [[ $JSON_MODE -eq 1 ]]; then
    sf org list limits --target-org "$TARGET_ORG" --json
    exit 0
fi
echo "== Org auth =="
sf org display --target-org "$TARGET_ORG" --verbose || true
echo
echo "== Key limits =="
sf org list limits --target-org "$TARGET_ORG"
echo
echo "== Approximate record counts (storage-related) =="
sf org list sobject record-counts --target-org "$TARGET_ORG" || true
echo
echo "Notes:"
echo "- 'API Requests' in the limits output shows remaining vs maximum for the org."
echo "- 'ActiveScratchOrgs' and 'DailyScratchOrgs' are especially relevant when the target org is a Dev Hub."
echo "- Record counts are approximate and correspond to the Storage Usage page in Setup."
