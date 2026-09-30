#!/usr/bin/env bash
#
# jvm-troubleshoot.sh -- JVM diagnostics for the AMS app server.
#
# WHAT IT DOES
#   Read-only section (always safe):
#     - java -version, and the flags the running JVMs were started with
#     - jcmd <pid> VM.flags / GC.heap_info (heap + GC state, no pause)
#     - jstat -gcutil <pid> (GC utilization snapshot)
#     - prints the GC-logging and heap-dump-on-OOM flag recipes so you can
#       enable them per the Nokia documentation
#   Gated section (NOTHING dumps without you opting in):
#     --thread-dump   jstack <pid>  (thread dump; brief stall possible on a
#                     heavily loaded JVM -- warn the NOC first, per the guides)
#     --heap-info     jcmd <pid> GC.heap_info (safe) -- kept as a flag for symmetry
#     --heap-dump     jmap -dump:format=b,file=... <pid> (FULL heap dump;
#                     heavier than jstack -- take jstack first, warn the NOC)
#     --yes           skip the per-action "type yes" prompt (the flag itself
#                     is still required -- dumps never happen by accident)
#
# Dumps are written to /tmp/ams-jvm-<pid>-<UTC>.{tdump,hprof} and the paths
# are printed. Ship them with the support bundle from the dry-run playbook.
#
# ASSUMPTIONS: same as jvm-optimize.sh -- the guides document that AMS runs
#   on a JVM (jstack/jmap via ams_support.sh) but not the JDK version or the
#   flag-injection mechanism. This script only OBSERVES; enabling GC logging
#   or OOM dumps permanently is a config change for the Nokia procedure.
#
# WHERE IT RUNS: on the AMS server as amssys (needs to see the java processes).
#   From Windows use jvm-troubleshoot.cmd / jvm-troubleshoot.ps1 (SSH).

set -uo pipefail

THREAD_DUMP=0
HEAP_DUMP=0
YES=0
for a in "$@"; do
    case "${a}" in
        --thread-dump) THREAD_DUMP=1 ;;
        --heap-dump)   HEAP_DUMP=1 ;;
        --yes)         YES=1 ;;
        -h|--help)     sed -n '2,/^$/p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "unknown flag: ${a} (see --help)"; exit 1 ;;
    esac
done

confirm_dump() { # $1 = description
    if [ "${YES}" = "1" ]; then return 0; fi
    printf 'About to: %s\nType "yes" to continue: ' "$1"
    IFS= read -r ans
    [ "${ans}" = "yes" ]
}

echo "## JVM troubleshooting -- $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# --- prerequisites ----------------------------------------------------------------
for t in java jcmd jstat; do
    if ! command -v "${t}" >/dev/null 2>&1; then
        echo "ERROR: '${t}' not found. Install the JDK (not just the JRE):"
        echo "  sudo dnf install java-17-openjdk-devel   # match YOUR AMS release's JDK first"
        exit 1
    fi
done
# jstack/jmap only needed when their flags are used
if [ "${THREAD_DUMP}" = "1" ] && ! command -v jstack >/dev/null 2>&1; then
    echo "ERROR: 'jstack' not found (JDK devel package missing)."; exit 1
fi
if [ "${HEAP_DUMP}" = "1" ] && ! command -v jmap >/dev/null 2>&1; then
    echo "ERROR: 'jmap' not found (JDK devel package missing)."; exit 1
fi

echo "### java -version"
java -version 2>&1 | sed 's/^/  /'
echo ""

# --- find JVM pids -----------------------------------------------------------------
PIDS="$(pgrep -f 'java.*ams\|jboss' 2>/dev/null || true)"
if [ -z "${PIDS}" ]; then PIDS="$(pgrep -f java 2>/dev/null || true)"; fi
if [ -z "${PIDS}" ]; then
    echo "no java processes found. Start AMS first."
    exit 1
fi
echo "### JVM processes"
for pid in ${PIDS}; do
    CMDLINE="$(tr '\0' ' ' < "/proc/${pid}/cmdline" 2>/dev/null || echo unreadable)"
    echo "  pid ${pid}: ${CMDLINE:0:300}"
done
echo ""

# --- read-only diagnostics -----------------------------------------------------------
echo "### read-only diagnostics (safe -- no pauses)"
for pid in ${PIDS}; do
    echo "--- pid ${pid} ---"
    echo "  [jcmd VM.flags]"
    jcmd "${pid}" VM.flags 2>&1 | sed 's/^/    /' | head -30
    echo "  [jcmd GC.heap_info]"
    jcmd "${pid}" GC.heap_info 2>&1 | sed 's/^/    /' | head -20
    echo "  [jstat -gcutil]"
    jstat -gcutil "${pid}" 2>&1 | sed 's/^/    /'
done
echo ""

# --- flag recipes (not applied -- config change, see Nokia docs) -----------------------
echo "### flag recipes (to enable permanently, follow the Nokia procedure)"
echo "  GC logging (JDK 11+):"
echo "    -Xlog:gc*,gc+phases=debug:/var/log/ams/gc.log:time,uptime,level,tags:filecount=10,filesize=50M"
echo "  GC logging (JDK 8):"
echo "    -Xloggc:/var/log/ams/gc.log -XX:+PrintGCDetails -XX:+PrintGCDateStamps \\"
echo "      -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=50M"
echo "  Heap dump on OutOfMemoryError:"
echo "    -XX:+HeapDumpOnOOM -XX:HeapDumpPath=/var/log/ams/heapdump.hprof"
echo "  (ensure the dump directory has headroom: a full dump ~= heap size)"
echo ""

# --- gated dumps -----------------------------------------------------------------------
STAMP="$(date -u +%Y%m%d-%H%M%S)"
for pid in ${PIDS}; do
    if [ "${THREAD_DUMP}" = "1" ]; then
        OUT="/tmp/ams-jvm-${pid}-${STAMP}.tdump"
        if confirm_dump "jstack thread dump of pid ${pid} -> ${OUT} (may briefly stall a loaded JVM)"; then
            echo "capturing thread dump: pid ${pid} -> ${OUT}"
            jstack "${pid}" > "${OUT}" 2>/tmp/ams-jvm-jstack.err || { echo "jstack failed (see /tmp/ams-jvm-jstack.err)"; exit 1; }
            echo "wrote ${OUT} ($(du -h "${OUT}" | cut -f1))"
        else
            echo "thread dump for pid ${pid} skipped by operator."
        fi
    fi
    if [ "${HEAP_DUMP}" = "1" ]; then
        OUT="/tmp/ams-jvm-${pid}-${STAMP}.hprof"
        if confirm_dump "jmap full heap dump of pid ${pid} -> ${OUT} (HEAVY -- take jstack first, warn the NOC)"; then
            echo "capturing heap dump: pid ${pid} -> ${OUT}"
            jmap -dump:format=b,file="${OUT}" "${pid}" || { echo "jmap failed"; exit 1; }
            echo "wrote ${OUT} ($(du -h "${OUT}" | cut -f1))"
        else
            echo "heap dump for pid ${pid} skipped by operator."
        fi
    fi
done

if [ "${THREAD_DUMP}" = "0" ] && [ "${HEAP_DUMP}" = "0" ]; then
    echo "no dump flags given -- read-only diagnostics only. Re-run with --thread-dump and/or --heap-dump to capture."
fi
echo ""
echo "done."
