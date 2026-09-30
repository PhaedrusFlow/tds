#!/usr/bin/env bash
#
# jvm-optimize.sh -- JVM sizing/tuning recommendations for the AMS app server.
#
# WHAT IT DOES
#   1. Detects the Java runtime on this host (version, vendor).
#   2. Finds running AMS Java processes and shows their CURRENT JVM flags
#      (read from /proc -- no changes, no restarts).
#   3. Computes a recommendation: heap sizing from installed RAM, G1GC
#      selection, GC logging flags, and heap-dump-on-OOM wiring.
#   4. Writes the recommendation to reports/jvm-recommendations-<UTC>.txt
#      (printed path at the end). Nothing is applied by default.
#
# WHAT IT DOES NOT DO
#   It does NOT edit AMS configuration. The Nokia guides do not document
#   where AMS JVM flags live (no JAVA_OPTS/wrapper.conf location is given),
#   so there is no safe automatic target. With --apply-to <file> (and a typed
#   "yes") it appends an export block to a file YOU name, after backing that
#   file up -- you must still wire that file into the AMS startup per the
#   controlling Nokia documentation and validate in a lab first.
#
# ASSUMPTIONS (the guides do not pin these down -- stated so you can check):
#   A1. The AMS application server runs on a JVM. Evidence in the guides:
#       jstack/jmap captured via ams_support.sh, a JBoss/SSL check script
#       (ams_check_ssl.sh), and JMS (Java Message Service) configuration.
#   A2. The JDK version AMS ships, its default heap, and its GC choice are
#       NOT documented in the guides. Flags below are chosen for a generic
#       long-running management-plane server and must be validated.
#   A3. Workload shape: AMS manages thousands of NEs with bursty management
#       traffic -- latency-sensitive admin/GUI operations, so G1GC (the
#       default on JDK 11+, good pause-time behavior) is recommended over
#       ParallelGC. If AMS ships JDK 8, the JDK-8 flag spellings are printed
#       instead (see the report).
#   A4. Heap sizing: dedicated server -> up to ~50% of RAM for the Java heap,
#       capped at 31 GB to stay under the compressed-oops threshold; never
#       exceed ~70% of RAM total for heap+metaspace+off-heap. Xms == Xmx to
#       avoid heap-resize pauses. These are starting points, not gospel --
#       size from YOUR observed peak old-gen occupancy plus 30-40% headroom.
#
# USAGE
#   ./jvm-optimize.sh [--apply-to /path/to/env/file]
#
# WHERE IT RUNS
#   On the AMS server as amssys (reads /proc and runs java -version).
#   From Windows use jvm-optimize.cmd / jvm-optimize.ps1 (SSH).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${SCRIPT_DIR}/reports"
mkdir -p "${REPORT_DIR}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
REPORT="${REPORT_DIR}/jvm-recommendations-${STAMP}.txt"

APPLY_TO=""
if [ "${1:-}" = "--apply-to" ] && [ -n "${2:-}" ]; then
    APPLY_TO="$2"
fi

log() { printf '%s\n' "$*" | tee -a "${REPORT}"; }

log "# JVM optimization recommendations -- $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "# host: $(hostname 2>/dev/null || echo unknown)"
log ""
log "## Assumptions (see script header for the full list)"
log "A1: AMS app server runs on a JVM (jstack/jmap/JBoss/JMS evidence in the guides)."
log "A2: JDK version, default heap, and GC choice are NOT documented -- validate everything."
log "A3: G1GC recommended for a latency-sensitive management-plane workload."
log "A4: Heap ~= 50% of RAM, capped at 31g (compressed oops); Xms == Xmx."

# --- 1. Java runtime detection ------------------------------------------------
log ""
log "## 1. Java runtime"
if ! command -v java >/dev/null 2>&1; then
    log "[MISSING] no 'java' on PATH. Install a JDK or add the AMS-bundled one to PATH."
    log "fix (RHEL): sudo dnf install java-17-openjdk-devel   # match YOUR AMS release's JDK first"
    exit 1
fi
log "java binary: $(command -v java)"
java -version 2>&1 | while IFS= read -r l; do log "  ${l}"; done

# Detect major version for flag spelling
JAVA_MAJOR="$(java -version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 | cut -d. -f1)"
if [ -z "${JAVA_MAJOR}" ]; then JAVA_MAJOR="$(java -version 2>&1 | head -1 | grep -oE '"[0-9]+' | tr -d '"' | head -1)"; fi
log "detected java major version: ${JAVA_MAJOR:-unknown}"
if [ -n "${JAVA_MAJOR}" ] && [ "${JAVA_MAJOR}" -ge 11 ] 2>/dev/null; then
    GC_LOG_FLAGS="-Xlog:gc*,gc+phases=debug:/var/log/ams/gc.log:time,uptime,level,tags:filecount=10,filesize=50M"
    log "GC logging (JDK 11+ unified logging): ${GC_LOG_FLAGS}"
else
    GC_LOG_FLAGS="-Xloggc:/var/log/ams/gc.log -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=50M"
    log "GC logging (JDK 8 spelling): ${GC_LOG_FLAGS}"
fi

# --- 2. Current AMS JVM flags (read-only) -------------------------------------
log ""
log "## 2. Running JVM processes and their current flags (read-only)"
PIDS="$(pgrep -f 'java.*ams\|jboss' 2>/dev/null || true)"
if [ -z "${PIDS}" ]; then
    PIDS="$(pgrep -f java 2>/dev/null || true)"
fi
if [ -z "${PIDS}" ]; then
    log "no java processes found. Start AMS first, or the app server runs under a different name."
else
    for pid in ${PIDS}; do
        CMDLINE="$(tr '\0' ' ' < "/proc/${pid}/cmdline" 2>/dev/null || echo unreadable)"
        log "pid ${pid}: ${CMDLINE:0:400}"
    done
fi

# --- 3. Sizing ----------------------------------------------------------------
log ""
log "## 3. Sizing recommendation"
MEM_KB="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
MEM_GB=$((MEM_KB / 1024 / 1024))
log "installed RAM: ${MEM_GB} GiB"
if [ "${MEM_GB}" -ge 8 ]; then
    HEAP_GB=$((MEM_GB / 2))
    [ "${HEAP_GB}" -gt 31 ] && HEAP_GB=31   # stay under compressed-oops threshold
    log "recommended heap: -Xms${HEAP_GB}g -Xmx${HEAP_GB}g  (50% of RAM, capped at 31g)"
else
    log "less than 8 GiB RAM: do NOT size blindly -- run AMS on its documented minimum hardware"
    log "and re-run this script there. Provisional: -Xms2g -Xmx2g for lab use only."
    HEAP_GB=2
fi
log "GC: -XX:+UseG1GC  (default on JDK 11+; explicit is documentation)"
log "optional G1 tuning (only after reading a GC log, not preemptively):"
log "  -XX:MaxGCPauseMillis=500 -XX:G1HeapRegionSize=<from log> -XX:InitiatingHeapOccupancyPercent=45"
log "metaspace: leave defaults unless 'Metaspace' OOMs appear in logs;"
log "  then raise with -XX:MaxMetaspaceSize=<observed peak + 50%>."
log "heap dump on OOM: -XX:+HeapDumpOnOOM -XX:HeapDumpPath=/var/log/ams/heapdump.hprof"
log "  (dumps land on disk -- make sure /var/log/ams has headroom; a full heap dump ~= heap size)"

# --- 4. The flag block ----------------------------------------------------------
log ""
log "## 4. Recommended JVM flag block"
log "(apply ONLY to a JVM options file the Nokia documentation blesses for your release)"
log ""
log "  -Xms${HEAP_GB}g -Xmx${HEAP_GB}g \\"
log "  -XX:+UseG1GC \\"
log "  ${GC_LOG_FLAGS} \\"
log "  -XX:+HeapDumpOnOOM -XX:HeapDumpPath=/var/log/ams/heapdump.hprof"
log ""
log "rollout order: lab -> enable GC logging first -> capture a week of GC logs ->"
log "tune from the logs (pause times, promotion rate) -> change ONE thing at a time."

# --- 5. Optional apply -----------------------------------------------------------
log ""
log "## 5. Apply"
if [ -z "${APPLY_TO}" ]; then
    log "no --apply-to given: nothing was modified. Re-run with:"
    log "  ./jvm-optimize.sh --apply-to /path/to/env/file"
    log "and confirm the target file is actually consumed by the AMS startup scripts."
else
    log "requested target file: ${APPLY_TO}"
    if [ ! -f "${APPLY_TO}" ]; then
        log "ERROR: target file does not exist -- refusing to create JVM config blindly."
        exit 1
    fi
    printf 'Type "yes" to append the recommended block to %s (a .bak copy is made first): ' "${APPLY_TO}"
    IFS= read -r ans
    if [ "${ans}" != "yes" ]; then log "aborted by operator -- no changes made."; exit 1; fi
    cp -p "${APPLY_TO}" "${APPLY_TO}.bak-${STAMP}"
    {
        echo ""
        echo "# Added by jvm-optimize.sh ${STAMP} -- VERIFY against Nokia docs before relying on this"
        echo "export JAVA_OPTS=\"\${JAVA_OPTS} -Xms${HEAP_GB}g -Xmx${HEAP_GB}g -XX:+UseG1GC ${GC_LOG_FLAGS} -XX:+HeapDumpOnOOM -XX:HeapDumpPath=/var/log/ams/heapdump.hprof\""
    } >> "${APPLY_TO}"
    log "appended to ${APPLY_TO} (backup: ${APPLY_TO}.bak-${STAMP})"
    log "YOU MUST: confirm AMS startup consumes this file, then restart per the Nokia procedure."
fi

log ""
log "Report: ${REPORT}"
echo ""
echo "Recommendations written to: ${REPORT}"
