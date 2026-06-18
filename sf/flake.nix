{
  description = "CI/CD-friendly Nix flake for Salesforce CLI + LWC withshells and apps";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    sfdx-nix.url = "github:rfaulhaber/sfdx-nix";
  };
  outputs = { self, nixpkgs, flake-utils, sfdx-nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [
          (final: prev: {
            sf = sfdx-nix.packages.${system}.sf;
          })
        ];
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };
        nodejs = pkgs.nodejs_22;
        python = pkgs.python311;
        java = pkgs.jdk21_headless;
        basePackages = [
          pkgs.sf
          nodejs
          python
          java
          pkgs.git
          pkgs.jq
          pkgs.yq-go
          pkgs.gnused
          pkgs.gawk
          pkgs.findutils
          pkgs.coreutils
          pkgs.which
          pkgs.curl
          pkgs.wget
          pkgs.unzip
          pkgs.zip
          pkgs.gzip
          pkgs.xz
          pkgs.ripgrep
          pkgs.fd
          pkgs.bashInteractive
          pkgs.lua
          pkgs.lua-language-server
          pkgs.stylua
          pkgs.shellcheck
          pkgs.shfmt
          pkgs.nodePackages.typescript
          pkgs.nodePackages.typescript-language-server
          pkgs.nodePackages.vscode-langservers-extracted
          pkgs.nodePackages.prettier
          pkgs.nodePackages.pyright
          pkgs.python312Packages.debugpy
          pkgs.delve
        ];
        mkApp = script: {
          type = "app";
          program = "${script}";
        };
        ciEnv = ''
          export CI=true
          export SF_AUTOUPDATE_DISABLE=true
          export SFDX_AUTOUPDATE_DISABLE=true
          export SF_DISABLE_AUTOUPDATE=true
          export SFDX_DISABLE_AUTOUPDATE=true
          export SF_HIDE_RELEASE_NOTES=true
          export SF_HIDE_RELEASE_NOTES_FOOTER=true
          export SF_USE_GENERIC_UNIX_KEYCHAIN=true
          export SFDX_USE_GENERIC_UNIX_KEYCHAIN=true
          export NODE_OPTIONS="--max-old-space-size=4096"
          export HOME="$(pwd)/.ci-home"
          export XDG_CONFIG_HOME="$HOME/.config"
          export XDG_CACHE_HOME="$HOME/.cache"
          export XDG_DATA_HOME="$HOME/.local/share"
          mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
        '';
      in {
        packages.default = pkgs.buildEnv {
          name = "salesforce-lwc-env";
          paths = basePackages;
        };
        packages.sf = pkgs.sf;

        apps.default = mkApp "${pkgs.writeShellScript "sf-help" ''
          exec ${pkgs.sf}/bin/sf --help
        ''}";
        apps.bootstrap = mkApp "${pkgs.writeShellScript "bootstrap-salesforce-project" ''
          set -euo pipefail
          : "''${PROJECT_NAME:=tds-fst-dashboard}"
          : "''${DEVHUB_ALIAS:=map-dev}"
          : "''${INSTANCE_URL:=https://tdstelecom.my.salesforce.com}"
          : "''${SCRATCH_ALIAS:=fst-dashboard-dev}"
          : "''${DURATION_DAYS:=7}"
          : "''${LWC_NAME:=fstTeamDashboard}"

          if [ -e "$PROJECT_NAME" ]; then
            echo "Refusing to overwrite existing path: $PROJECT_NAME" >&2
            exit 1
          fi

          ${pkgs.sf}/bin/sf project generate --name "$PROJECT_NAME"
          cd "$PROJECT_NAME"
          mkdir -p config scripts force-app/main/default/lwc .vscode .nvim .github/workflows
          cat > config/project-scratch-def.json <<JSON
          {
            "orgName": "TDS FST Dashboard",
            "edition": "Enterprise",
            "features": ["ServiceCloud"],
            "settings": {
              "lightningExperienceSettings": {
                "enableS1DesktopEnabled": true
              }
            }
          }
JSON

          ${pkgs.sf}/bin/sf lightning generate component \
            --type lwc \
            --name "$LWC_NAME" \
            --output-dir force-app/main/default/lwc

          cat > "force-app/main/default/lwc/$LWC_NAME/$LWC_NAME.js-meta.xml" <<XML
          <?xml version="1.0" encoding="UTF-8"?>
          <LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
            <apiVersion>63.0</apiVersion>
            <isExposed>true</isExposed>
            <masterLabel>FST Team Dashboard</masterLabel>
            <description>Starter team dashboard for field service workflows</description>
            <targets>
              <target>lightning__HomePage</target>
              <target>lightning__AppPage</target>
            </targets>
          </LightningComponentBundle>
XML
          cat > scripts/login-devhub.sh <<SH
          #!/usr/bin/env bash
          set -euo pipefail
          exec sf org login web \
            --instance-url "$INSTANCE_URL" \
            --alias "$DEVHUB_ALIAS" \
            --set-default-dev-hub
SH
          chmod +x scripts/login-devhub.sh
          cat > scripts/auth-jwt.sh <<SH
          #!/usr/bin/env bash
          set -euo pipefail
          : "''${SF_CLIENT_ID:?missing SF_CLIENT_ID}"
          : "''${SF_JWT_KEY_FILE:?missing SF_JWT_KEY_FILE}"
          : "''${SF_USERNAME:?missing SF_USERNAME}"
          : "''${SF_INSTANCE_URL:?missing SF_INSTANCE_URL}"
          exec sf org login jwt \
            --client-id "$SF_CLIENT_ID" \
            --jwt-key-file "$SF_JWT_KEY_FILE" \
            --username "$SF_USERNAME" \
            --instance-url "$SF_INSTANCE_URL" \
            --alias ci-org \
            --set-default
SH
          chmod +x scripts/auth-jwt.sh
          cat > scripts/create-scratch.sh <<SH
          #!/usr/bin/env bash
          set -euo pipefail
          exec sf org create scratch \
            --definition-file config/project-scratch-def.json \
            --target-dev-hub "$DEVHUB_ALIAS" \
            --alias "$SCRATCH_ALIAS" \
            --duration-days "$DURATION_DAYS" \
            --set-default \
            --wait 10
SH
          chmod +x scripts/create-scratch.sh

          cat > scripts/deploy-dashboard.sh <<SH
          #!/usr/bin/env bash
          set -euo pipefail
          : "''${TARGET_ORG:=$SCRATCH_ALIAS}"
          exec sf project deploy start \
            --target-org "$TARGET_ORG" \
            --metadata "LightningComponentBundle:$LWC_NAME" \
            --wait 10
SH
          chmod +x scripts/deploy-dashboard.sh

          cat > scripts/validate.sh <<SH
          #!/usr/bin/env bash
          set -euo pipefail
          : "''${TARGET_ORG:?set TARGET_ORG}"
          sf project deploy start \
            --target-org "$TARGET_ORG" \
            --source-dir force-app \
            --dry-run \
            --test-level NoTestRun \
            --wait 10
SH
          chmod +x scripts/validate.sh

          cat > scripts/run-apex-tests.sh <<SH
          #!/usr/bin/env bash
          set -euo pipefail
          : "''${TARGET_ORG:?set TARGET_ORG}"
          exec sf apex run test \
            --target-org "$TARGET_ORG" \
            --code-coverage \
            --result-format human \
            --wait 20
SH
          chmod +x scripts/run-apex-tests.sh

          cat > scripts/open-org.sh <<SH
          #!/usr/bin/env bash
          set -euo pipefail
          exec sf org open --target-org "$SCRATCH_ALIAS"
SH
          chmod +x scripts/open-org.sh

          cat > scripts/install-sf-plugins.sh <<SH
          #!/usr/bin/env bash
          set -euo pipefail
          sf plugins install @salesforce/plugin-data
          sf plugins --core
          sf plugins
SH
          chmod +x scripts/install-sf-plugins.sh

          cat > scripts/soql-query.sh <<SH
          #!/usr/bin/env bash
          set -euo pipefail
          : "''${TARGET_ORG:?set TARGET_ORG or export it}"
          : "''${SOQL:?set SOQL or export it}"
          exec sf data query \
            --target-org "$TARGET_ORG" \
            --query "$SOQL" \
            --result-format json
SH
          chmod +x scripts/soql-query.sh

          cat > .vscode/extensions.json <<JSON
          {
            "recommendations": [
              "salesforce.salesforcedx-vscode",
              "salesforce.apex-language-server-extension",
              "ms-python.python",
              "ms-vscode.js-debug-nightly"
            ]
          }
JSON

          cat > .github/workflows/salesforce-ci.yml <<YAML
          name: salesforce-ci

          on:
            workflow_dispatch:
            push:
              branches: [ main ]
            pull_request:

          jobs:
            validate:
              runs-on: ubuntu-latest
              steps:
                - uses: actions/checkout@v4
                - uses: cachix/install-nix-action@v31
                - name: Enter strict shell and verify toolchain
                  run: |
                    nix develop --command bash -lc 'sf --version && node --version && python --version'
                - name: JWT auth
                  env:
                    SF_CLIENT_ID: \\${{ secrets.SF_CLIENT_ID }}
                    SF_JWT_KEY_FILE: \\${{ github.workspace }}/server.key
                    SF_USERNAME: \\${{ secrets.SF_USERNAME }}
                    SF_INSTANCE_URL: \\${{ secrets.SF_INSTANCE_URL }}
                    SF_JWT_SERVER_KEY: \\${{ secrets.SF_JWT_SERVER_KEY }}
                  run: |
                    printf '%s' "$SF_JWT_SERVER_KEY" > server.key
                    chmod 600 server.key
                    nix develop --command bash -lc './scripts/auth-jwt.sh'
                - name: Validate metadata
                  env:
                    TARGET_ORG: ci-org
                  run: |
                    nix develop --command bash -lc './scripts/validate.sh'
          YAML

          cat > .envrc.example <<ENV
          export PROJECT_NAME="$PROJECT_NAME"
          export DEVHUB_ALIAS="$DEVHUB_ALIAS"
          export INSTANCE_URL="$INSTANCE_URL"
          export SCRATCH_ALIAS="$SCRATCH_ALIAS"
          export DURATION_DAYS="$DURATION_DAYS"
          export LWC_NAME="$LWC_NAME"
ENV

          cat > README.md <<MD
          # $PROJECT_NAME

          Reproducible Salesforce CLI + LWC development project bootstrapped from the flake.

          ## Commands

          - Login Dev Hub: \
            \\`./scripts/login-devhub.sh\\`
          - JWT auth for CI: \
            \\`./scripts/auth-jwt.sh\\`
          - Create scratch org: \
            \\`./scripts/create-scratch.sh\\`
          - Install Salesforce CLI plugins: \
            \\`./scripts/install-sf-plugins.sh\\`
          - Run SOQL query: \
            \\`TARGET_ORG=$SCRATCH_ALIAS SOQL='SELECT Id FROM Account LIMIT 5' ./scripts/soql-query.sh\\`
          - Validate metadata: \
            \\`TARGET_ORG=$SCRATCH_ALIAS ./scripts/validate.sh\\`
          - Run Apex tests: \
            \\`TARGET_ORG=$SCRATCH_ALIAS ./scripts/run-apex-tests.sh\\`
          - Deploy dashboard: \
            \\`./scripts/deploy-dashboard.sh\\`
          - Open org: \
            \\`./scripts/open-org.sh\\`

          ## CI notes

          - Uses JWT auth instead of interactive login.
          - Forces CLI auto-update off.
          - Uses a workspace-local HOME for deterministic pipeline behavior.
          - Includes a sample GitHub Actions workflow for validation.
MD

          echo "Bootstrapped Salesforce project at $PROJECT_NAME"
        ''}";

        devShells.default = pkgs.mkShell {
          packages = basePackages;
          shellHook = ''
            export SF_AUTOUPDATE_DISABLE=true
            export SFDX_AUTOUPDATE_DISABLE=true
            export SF_DISABLE_AUTOUPDATE=true
            export SFDX_DISABLE_AUTOUPDATE=true
            export SF_HIDE_RELEASE_NOTES=true
            export SF_HIDE_RELEASE_NOTES_FOOTER=true
            export SF_USE_GENERIC_UNIX_KEYCHAIN=true
            export SFDX_USE_GENERIC_UNIX_KEYCHAIN=true
            export NODE_OPTIONS="--max-old-space-size=4096"
            echo "Salesforce dev shell ready"
            echo "Tip: nix develop --command bash -lc 'sf --version'"
          '';
        };
        devShells.ci = pkgs.mkShell {
          packages = basePackages;
          shellHook = ''
            ${ciEnv}
            echo "Strict CI shell ready"
            echo "HOME=$HOME"
            echo "XDG_CONFIG_HOME=$XDG_CONFIG_HOME"
            echo "sf=$(sf --version | head -n 1)"
          '';
        };
      });
}
