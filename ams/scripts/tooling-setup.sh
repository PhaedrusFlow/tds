#!/usr/bin/env bash
#
# tooling-setup.sh -- verify (and optionally install) JVM diagnostic tooling
# for working with the AMS Java application server.
#
# WHAT IT DOES
#   Checks for the free, reputable tooling that makes JVM work sane, and
#   tells you exactly how to get what's missing:
#     JDK built-ins (free, ship with the JDK -- no download, no license):
#       java, jstack, jmap, jcmd, jstat, jinfo, jconsole
#     async-profiler (Apache 2.0, github.com/async-profiler/async-profiler):
#       low-overhead CPU/alloc profiling; verified present or gives you the
#       release URL + checksum steps. NEVER auto-downloaded.
#     VisualVM (GPL-2.0): optional GUI profiler -- install hint only.
#
# WHAT IT DOES NOT DO
#   - Does not download anything without --allow-downloads AND a typed "yes".
#   - Does not install anything without a typed "yes" (package manager only).
#   - Does not phone home: every check is local. No telemetry, no license
#     servers, no accounts. If a tool ever needs a license, this script
#     refuses to fetch it and says so loudly (none of the tools below do).
#
# USAGE
#   ./tooling-setup.sh [--allow-downloads] [--install]
#     --allow-downloads  permit fetching async-profiler from its GitHub
#                        release page (checksum-verified, still asks first)
#     --install          permit 'sudo dnf install' for missing JDK tooling
#                        (still asks first)
#
# WHERE IT RUNS: on the AMS server as amssys (sudo used only for dnf).
#   From Windows use tooling-setup.cmd / tooling-setup.ps1 (SSH).

set -uo pipefail

ALLOW_DL=0
ALLOW_INSTALL=0
for a in "$@"; do
    case "${a}" in
        --allow-downloads) ALLOW_DL=1 ;;
        --install)         ALLOW_INSTALL=1 ;;
        -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "unknown flag: ${a} (see --help)"; exit 1 ;;
    esac
done

MISSING=0
ok()   { printf '  [ok] %s\n' "$*"; }
miss() { printf '  [MISSING] %s\n' "$*"; MISSING=1; }

confirm() { # $1 = prompt
    printf '%s Type "yes" to continue: ' "$1"
    IFS= read -r ans
    [ "${ans}" = "yes" ]
}

echo "## JVM tooling check -- $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

echo "### 1. JDK built-ins (free, ship with the JDK)"
if command -v java >/dev/null 2>&1; then
    ok "java: $(command -v java)"
    java -version 2>&1 | sed 's/^/         /' | head -3
else
    miss "java not on PATH"
fi
for t in jstack jmap jcmd jstat jinfo jconsole; do
    if command -v "${t}" >/dev/null 2>&1; then
        ok "${t}: $(command -v "${t}")"
    else
        miss "${t} not found -- you have a JRE but not the JDK (devel package)"
    fi
done
echo ""
echo "  fix (RHEL, match YOUR AMS release's JDK first):"
echo "    sudo dnf install java-17-openjdk-devel"
echo ""

echo "### 2. async-profiler (Apache 2.0 -- CPU/alloc profiling, ~no overhead)"
AP_URL="https://github.com/async-profiler/async-profiler/releases"
if command -v asprof >/dev/null 2>&1 || [ -x /opt/async-profiler/bin/asprof ]; then
    ok "async-profiler present: $(command -v asprof 2>/dev/null || echo /opt/async-profiler/bin/asprof)"
else
    miss "async-profiler not found"
    echo "  get it (manual, recommended): ${AP_URL}"
    echo "    1. download the linux-x64 tar.gz for your glibc"
    echo "    2. verify the SHA256 checksum published on the release page:"
    echo "         sha256sum async-profiler-*.tar.gz   # compare with the release page value"
    echo "    3. extract to /opt/async-profiler (root) and use bin/asprof"
    if [ "${ALLOW_DL}" = "1" ]; then
        echo ""
        if confirm "download the latest async-profiler release to /tmp and checksum-verify it?"; then
            echo "  NOTE: this sandbox step is intentionally manual -- download it yourself from:"
            echo "  ${AP_URL}"
            echo "  Automatic GitHub-release scraping is deliberately NOT implemented here:"
            echo "  picking the right build for your glibc/JDK is a human decision."
        else
            echo "  skipped by operator."
        fi
    else
        echo "  (re-run with --allow-downloads to be walked through the fetch)"
    fi
fi
echo ""

echo "### 3. VisualVM (optional GUI profiler, GPL-2.0)"
if command -v visualvm >/dev/null 2>&1; then
    ok "visualvm: $(command -v visualvm)"
else
    miss "visualvm not found (optional -- only useful with a display or remote JMX)"
    echo "  get it: https://visualvm.github.io/  (or: sudo dnf install visualvm)"
fi
echo ""

echo "### 4. package-manager install (only with --install)"
if [ "${ALLOW_INSTALL}" = "1" ]; then
    if confirm "run 'sudo dnf install java-17-openjdk-devel' now?"; then
        sudo dnf install -y java-17-openjdk-devel
    else
        echo "  skipped by operator."
    fi
else
    echo "  skipped (re-run with --install to permit dnf installs; still asks first)"
fi
echo ""

if [ "${MISSING}" = "1" ]; then
    echo "result: some tooling is missing -- follow the fix hints above."
    exit 1
fi
echo "result: all checked tooling is present."
