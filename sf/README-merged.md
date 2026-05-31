# map-salesforce

This repository is a Salesforce DX project for the `map-salesforce` workspace, using `sf`/`sfdx` project configuration, sandbox-first defaults, and a two-package layout consisting of a base package and a dependent feature package.[file:290][web:197]

It is also set up so people who are newer to Salesforce CLI can understand the basics of what the CLI is, how org login works, and how this repository uses shared TDS org aliases plus personal Dev Hub aliases.[web:316][web:136]

## Salesforce CLI basics

Salesforce CLI is a free command-line tool from Salesforce that lets people work with Salesforce orgs from a terminal or command prompt instead of doing every task through the browser UI.[web:316][web:136]

A command-line interface, or CLI, is simply a text-based tool where tasks are done by typing commands.[web:315][web:317]

For this project, Salesforce CLI is mainly used to:

- Log into the TDS Salesforce org.[web:136]
- Set a default org and Dev Hub alias for local development.[web:207]
- Work with metadata in this repository.[web:319]
- Support scratch-org and packaging workflows.[web:226][web:247]

## Project configuration

The current project configuration targets API version `63.0`, uses `https://test.salesforce.com` as the project login default, and sets `oauthLocalPort` to `1718` to avoid common localhost callback conflicts during browser-based auth.[file:290][web:188]

The project-level `sfdcLoginUrl` is appropriate for sandbox-first workflows, but explicit CLI login commands can override it with a My Domain URL such as `https://tdstelecom.my.salesforce.com` when needed.[file:290][web:141]

The `plugins` block enables `salesforcedx-vscode-core.enable-sobject-refresh-on-startup`, which helps keep local SObject definitions fresh for Salesforce VS Code workflows.[file:290]

The `replacements` block defines environment substitutions for custom metadata and named credentials, replacing `API_BASE_URL_PLACEHOLDER` with `https://sandbox.my.salesforce.com` and `ENV_NAME_PLACEHOLDER` with `SANDBOX`.[file:290]

The project also enables these `sourceBehaviorOptions`:[file:290]

- `decomposeCustomLabelsBeta2`
- `decomposeExternalServiceRegistrationBeta`
- `decomposePermissionSetBeta2`
- `decomposeSharingRulesBeta`
- `decomposeWorkflowBeta`

## Project layout

The repository defines three package directories: `force-app` as the default base package root, `packages/feature` as a second package that depends on `map-base`, and `unpackaged/config` for unpackaged metadata or environment-specific configuration.[file:290]

| Path | Purpose | Notes |
|---|---|---|
| `force-app` | Base package source | Default package directory, mapped to `map-base`.[file:290] |
| `packages/feature` | Feature package source | Depends on `map-base@1.0.0.LATEST`.[file:290] |
| `unpackaged/config` | Unpackaged metadata | Not marked as default and not tied to a package alias.[file:290] |

## Packaging model

`packageAliases` maps readable package names to Salesforce package IDs and package version IDs so packaging commands can use aliases instead of raw IDs.[file:290]

The current package model is:

| Alias | Type | Value |
|---|---|---|
| `map-base` | Package ID | `0Ho000000000001AAA` |
| `map-base@1.0.0-1` | Package Version ID | `04t000000000001AAA` |
| `map-feature` | Package ID | `0Ho000000000002AAA` |
| `map-feature@1.0.0-1` | Package Version ID | `04t000000000002AAA` |

The feature package depends on `map-base` version `1.0.0.LATEST`, so package creation and install workflows should account for base-first ordering even though `pushPackageDirectoriesSequentially` is currently `false`.[file:290]

## Authentication

The easiest login method for most users is browser-based login with `sf org login web`, which opens a browser window and lets the user sign in with normal Salesforce credentials.[web:136]

For TDS work, use the My Domain URL directly when authorizing the CLI:

```bash
sf org login web \
  --instance-url https://tdstelecom.my.salesforce.com \
  --alias tds \
  --set-default
```

If the same org is also being used as a Dev Hub, authorize it like this:

```bash
sf org login web \
  --instance-url https://tdstelecom.my.salesforce.com \
  --alias map-dev \
  --set-default-dev-hub
```

Salesforce recommends using `--alias` for readable org names and `--set-default-dev-hub` when authorizing a Dev Hub org for scratch-org creation and packaging workflows.[web:136][web:207]

## Aliases explained

An alias is just a friendly nickname for a Salesforce org in the CLI, such as `tds`, `devhub`, or `map-dev`.[web:207][web:223]

This repository uses a simple pattern:

- `tds` is the shared standard alias for the TDS work org.[web:223]
- A personal alias such as `map-dev` can be used for the same org when that org is acting as the developer's default Dev Hub.[web:207]

That makes commands easier to read and helps teams stay consistent.[web:207][web:223]

## Dev Hub basics

A Dev Hub is a Salesforce org with Dev Hub enabled so it can create and manage scratch orgs for development workflows.[web:226][web:247]

Because the TDS org is being used as a Dev Hub, each developer can give that same org a personal Dev Hub alias and then use it for scratch-org commands.[web:226][web:247]

## `sf.sh` guidance

The setup script should treat the TDS org as the shared work org alias and allow each developer to enter a personal Dev Hub alias, then map that alias to the same authenticated org.[web:223][web:230]

A recommended `sf.sh` looks like this:

```bash
#!/usr/bin/env bash

set -euo pipefail

INSTANCE_URL="https://tdstelecom.my.salesforce.com"
DEFAULT_ORG_ALIAS="tds"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1"
    exit 1
  }
}

install_plugin_if_missing() {
  local plugin="$1"

  if sf plugins | grep -Fq "$plugin"; then
    echo "Plugin already installed: $plugin"
  else
    echo "Installing plugin: $plugin"
    sf plugins install "$plugin"
  fi
}

require_cmd sf

sf config set disable-telemetry=true --global
sf config set org-api-version=63.0 --global
sf config set org-capitalize-record-types=false --global
sf config set org-max-query-limit=20000 --global
sf config set rest-deploy=false --global
sf config set org-instance-url="${INSTANCE_URL}" --global

read -r -p "Enter Dev Hub alias (example: map-dev): " DEVHUB_ALIAS

if [[ -z "${DEVHUB_ALIAS}" ]]; then
  echo "Error: Dev Hub alias cannot be empty."
  exit 1
fi

BROWSER=chromium sf org login web \
  --instance-url "${INSTANCE_URL}" \
  --alias "${DEFAULT_ORG_ALIAS}" \
  --set-default \
  --set-default-dev-hub

sf alias set "${DEVHUB_ALIAS}=${DEFAULT_ORG_ALIAS}"

sf config set target-org="${DEFAULT_ORG_ALIAS}" --global
sf config set target-dev-hub="${DEVHUB_ALIAS}" --global

install_plugin_if_missing "@salesforce/plugin-packaging"
install_plugin_if_missing "@salesforce/plugin-devops-center"

sf plugins --core
sf plugins
```

This structure keeps `tds` as the team-standard org alias, allows a user-defined Dev Hub alias such as `map-dev`, and installs the additional official plugins that are useful beyond the CLI's built-in core and just-in-time plugin behavior.[web:264][web:266][web:272]

## Recommended commands

Common commands for this repo:

```bash
# show CLI version
sf --version

# log into the TDS org
sf org login web --instance-url https://tdstelecom.my.salesforce.com --alias tds --set-default

# log into the same org as a Dev Hub
sf org login web --instance-url https://tdstelecom.my.salesforce.com --alias map-dev --set-default-dev-hub

# list orgs and aliases
sf org list
sf alias list

# open the default org in a browser
sf org open

# create a scratch org
sf org create scratch --definition-file config/project-scratch-def.json --alias map-scratch --set-default

# inspect plugins
sf plugins --core
sf plugins
```

These commands are enough for most people to confirm the CLI is installed, the org login worked, and the local environment is ready.[web:147][web:180][web:266]

## Plugins

Salesforce CLI supports plugins, which add groups of commands to the CLI.[web:272][web:264]

Many important capabilities already come from core or just-in-time plugins, but this repository's setup script explicitly installs additional official plugins such as `@salesforce/plugin-packaging` and `@salesforce/plugin-devops-center` when needed.[web:264][web:266]

## Good beginner habits

- Use aliases so org commands are easier to remember.[web:207][web:223]
- Use browser login first because it is the simplest path for most users, especially with MFA or SSO.[web:136]
- Start by learning a few commands: `sf --version`, `sf org list`, `sf org open`, and `sf plugins`.[web:147][web:180]
- Use the repo's standard TDS alias pattern so the team stays consistent.[web:223]

## Notes

- `sf` still uses `sfdx-project.json` or `sfdx-project.jsonc` as the project configuration format; there is no separate `sf-project.json` format.[file:290]
- `oauthLocalPort: 1718` is useful when default localhost callback ports are unavailable during browser-based auth.[web:188][web:199]
- `sfdcLoginUrl` sets a project default, but `--instance-url` on the command line takes precedence for explicit org login commands.[file:290][web:141]
