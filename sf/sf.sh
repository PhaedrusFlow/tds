#!/usr/bin/env bash
set -euo pipefail
INSTANCE_URL="https://tdstelecom.my.salesforce.com"
DEFAULT_ORG_ALIAS="tds"
sf config set disable-telemetry=true --global
sf config set org-api-version=67.0 --global
sf config set org-capitalize-record-types=false --global
sf config set org-max-query-limit=20000 --global
PLUGINS=(
    "@salesforce/plugin-deploy-retrieve@3.24.48"
    "@salesforce/plugin-settings@2.4.80"
    "@salesforce/plugin-info@3.4.133"
    "@salesforce/plugin-sobject@1.4.108"
    "@salesforce/plugin-limits@3.3.89"
    "@salesforce/plugin-schema@3.3.114"
    "@salesforce/plugin-custom-metadata@3.3.103"
    "@salesforce/plugin-data@4.0.101"
    "@salesforce/plugin-community@3.3.61"
    "@salesforce/plugin-signups@2.6.70"
    "@salesforce/plugin-user@3.10.0"
    "@salesforce/plugin-org@5.11.1"
    "@salesforce/plugin-packaging@2.28.2"
    "@salesforce/plugin-templates@56.17.2"
    "@salesforce/plugin-apex@3.9.29"
    "@salesforce/plugin-auth@4.4.0"
    "@salesforce/plugin-dev@2.5.2"
    "@salesforce/sfdx-plugin-lwc-test@1.2.1"
    "@salesforce/plugin-devops-center@1.2.27"
    "@salesforce/plugin-marketplace@1.3.26"
    "@salesforce/plugin-code-analyzer@5.12.0"
    "@salesforce/plugin-api@1.3.33"
    "@salesforce/plugin-agent@1.40.3"
    "@salesforce/plugin-flow@1.0.5"
    "@salesforce/plugin-lightning-dev@6.2.17"
    "@salesforce/plugin-ui-bundle-dev@1.2.2"
)
echo "Installing pinned Salesforce CLI plugins"
for plugin in "${PLUGINS[@]}"; do
    echo "  -> ${plugin}"
    sf plugins install "${plugin}"
done
echo
echo "Installed plugin versions:"
sf plugins --core
read -r -p "Enter Dev Hub alias (example: map-dev): " DEVHUB_ALIAS
if [[ -z ${DEVHUB_ALIAS} ]]; then
    echo "Error: Dev Hub alias cannot be empty."
    exit 1
fi
BROWSER=chromium sf org login web \
    --instance-url "${INSTANCE_URL}" \
    --alias "${DEVHUB_ALIAS}" \
    --set-default-dev-hub
sf config set "target-dev-hub=${DEVHUB_ALIAS}" --global
sf config set "target-org=${DEVHUB_ALIAS}" --global
echo "Dev Hub authorized and set."
echo "Default Dev Hub alias: ${DEVHUB_ALIAS}"
echo "Default org alias: ${DEVHUB_ALIAS}"
echo
echo "If you also want a general TDS alias, run:"
echo "  sf alias set ${DEFAULT_ORG_ALIAS}=\$(sf org display --target-org ${DEVHUB_ALIAS} --json | jq -r '.result.username')"
