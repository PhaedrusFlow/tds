#!/usr/bin/env bash

# speedtest.sh
# Speed Test Script
set -euo pipefail
DURATION="${DURATION:-30}"
PARALLEL="${PARALLEL:-4}"
REVERSE="${REVERSE:-0}"
OUTDIR="${OUTDIR:-./iperf3-results}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOGFILE="$OUTDIR/iperf3-$STAMP.log"
CSVFILE="$OUTDIR/iperf3-$STAMP.csv"
mkdir -p "$OUTDIR"
SERVERS=(
    "iperf.scottlinux.com"
    "bouygues.testdebit.info"
    "ping-90ms.online.net"
)
if [[ $# -gt 0 ]]; then
    SERVERS=("$@")
fi
command -v iperf3 > /dev/null 2>&1 || {
    echo "iperf3 is not installed. On Arch: sudo pacman -S iperf3" >&2
    exit 1
}
printf 'timestamp,server,mode,parallel,duration,summary\n' > "$CSVFILE"
echo "Writing logs to: $LOGFILE"
echo "Writing csv to: $CSVFILE"
echo
run_test()
{
    local server="$1"
    local mode="upload"
    local extra=()

    if [[ $REVERSE == "1" ]]; then
        mode="download"
        extra=(-R)
    fi
    echo "===== $server ($mode) =====" | tee -a "$LOGFILE"
    local tmp
    tmp="$(mktemp)"
    if iperf3 -c "$server" -P "$PARALLEL" -t "$DURATION" "${extra[@]}" 2>&1 | tee "$tmp" | tee -a "$LOGFILE"; then
        local summary
        summary="$(grep -E '\[SUM\].*(sender|receiver)' "$tmp" | tail -n 1 | sed 's/^[[:space:]]*//; s/[[:space:]]\+/ /g')"
        if [[ -z $summary ]]; then
            summary="$(grep -E '(sender|receiver)' "$tmp" | tail -n 1 | sed 's/^[[:space:]]*//; s/[[:space:]]\+/ /g')"
        fi
        printf '%s,%s,%s,%s,%s,"%s"\n' "$(date --iso-8601=seconds)" "$server" "$mode" "$PARALLEL" "$DURATION" "$summary" >> "$CSVFILE"
    else
        printf '%s,%s,%s,%s,%s,"FAILED"\n' "$(date --iso-8601=seconds)" "$server" "$mode" "$PARALLEL" "$DURATION" >> "$CSVFILE"
        echo "Test failed for $server" | tee -a "$LOGFILE"
    fi
    rm -f "$tmp"
    echo | tee -a "$LOGFILE"
}
for server in "${SERVERS[@]}"; do
    run_test "$server"
    sleep 2
done
echo "Done. Review: $CSVFILE and $LOGFILE"
echo "Tip: run download tests with REVERSE=1 ./iperf3-multitest.sh"
echo "Tip: override defaults with DURATION=60 PARALLEL=8 ./iperf3-multitest.sh"
