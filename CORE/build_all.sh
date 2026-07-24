#!/usr/bin/env bash
# Build the MEGA65 bitstreams of all four boards (R3, R4, R5, R6) one after
# another in Vivado batch mode - made for overnight runs:
#
#   cd CORE
#   source /tools/Xilinx/Vivado/2022.2/settings64.sh   # or wherever Vivado is
#   nohup ./build_all.sh > build_all.out 2>&1 &
#
# Optional: pass a subset of boards (./build_all.sh R4 R6); board names are
# case-insensitive. JOBS=<n> sets the number of parallel Vivado jobs per run
# (default 4). A single Ctrl-C cleanly terminates the running Vivado (and its
# synthesis/implementation children) and stops the run - no manual pkill needed.

set -u
cd "$(dirname "$0")"

if ! command -v vivado >/dev/null 2>&1; then
    echo "ERROR: vivado is not on the PATH - source settings64.sh first." >&2
    exit 1
fi

# --- Clean interrupt handling ------------------------------------------------
# Vivado in -mode batch spawns synthesis/implementation child processes. We run
# each Vivado in its own session (via setsid) and wait for it, so that a single
# Ctrl-C - handled here - tears down the whole process group at once instead of
# leaving orphaned vivado processes behind that you would then have to "pkill
# vivado" by hand. On the rare host without setsid we fall back to a best-effort
# parent-based kill.
if command -v setsid >/dev/null 2>&1; then use_setsid=1; else use_setsid=0; fi
child_pid=""

terminate_child() {
    [ -n "${child_pid}" ] || return 0
    if [ "${use_setsid}" = 1 ]; then
        kill -TERM -- "-${child_pid}" 2>/dev/null          # signal the whole group
        for _ in 1 2 3 4 5 6 7 8 9 10; do                  # up to 10s to exit
            kill -0 -- "-${child_pid}" 2>/dev/null || return 0
            sleep 1
        done
        kill -KILL -- "-${child_pid}" 2>/dev/null          # then force it
    else
        pkill -TERM -P "${child_pid}" 2>/dev/null
        kill  -TERM    "${child_pid}" 2>/dev/null
        sleep 5
        pkill -KILL -P "${child_pid}" 2>/dev/null
        kill  -KILL    "${child_pid}" 2>/dev/null
    fi
}

on_interrupt() {
    trap - INT TERM
    echo >&2
    echo "Interrupted - stopping the current Vivado build and exiting..." >&2
    terminate_child
    exit 130
}
trap on_interrupt INT TERM
# -----------------------------------------------------------------------------

# The QNICE assembler binaries live in a folder that macOS and the Ubuntu VM
# share, so whichever OS compiled them last wins. Rebuild them for this OS
# and assemble the firmware once: a firmware problem aborts the run here,
# before the first multi-hour synthesis (synth_pre.tcl re-runs make_rom.sh
# during synthesis anyway).
./make_qasm.sh || exit 1
( cd m2m-rom && ./make_rom.sh ) || exit 1

if [ "$#" -gt 0 ]; then boards=("$@"); else boards=(R3 R4 R5 R6); fi
jobs="${JOBS:-4}"
failed=0

# Board names are case-insensitive on the command line ("R4", "r4" and "R4" all
# work), but the Vivado project files CORE-R<n>.xpr are always upper case, so we
# normalise them here. This also matters on the case-sensitive Linux build VM,
# where "r4" would otherwise fail to open CORE-R4.xpr. Unknown boards are
# rejected up front (checked against the actual .xpr files) instead of failing
# deep inside Vivado.
for i in "${!boards[@]}"; do
    boards[$i]=$(printf '%s' "${boards[$i]}" | tr '[:lower:]' '[:upper:]')
    if [ ! -f "CORE-${boards[$i]}.xpr" ]; then
        echo "ERROR: unknown board '${boards[$i]}' - no CORE-${boards[$i]}.xpr in $(pwd)." >&2
        echo "       Available: $(ls CORE-R*.xpr 2>/dev/null | sed 's/^CORE-\(.*\)\.xpr$/\1/' | tr '\n' ' ')" >&2
        exit 1
    fi
done

for board in "${boards[@]}"; do
    echo "=== ${board}: build started $(date) ==="
    # Launch Vivado in its own session (see interrupt handling above) and wait
    # for it, so Ctrl-C is caught by on_interrupt instead of racing Vivado.
    if [ "${use_setsid}" = 1 ]; then
        setsid vivado -mode batch -notrace -source build_bitstream.tcl \
               -log "build_${board}.log" -journal "build_${board}.jou" \
               -tclargs "${board}" "${jobs}" &
    else
        vivado -mode batch -notrace -source build_bitstream.tcl \
               -log "build_${board}.log" -journal "build_${board}.jou" \
               -tclargs "${board}" "${jobs}" &
    fi
    child_pid=$!
    wait "${child_pid}" || failed=1
    child_pid=""
done

echo
echo "=== Summary $(date) ==="
for board in "${boards[@]}"; do
    grep -h "^RESULT ${board}" "build_${board}.log" 2>/dev/null \
        || echo "RESULT ${board} FAILED - see build_${board}.log"
done
exit "${failed}"
