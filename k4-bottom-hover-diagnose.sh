#!/usr/bin/env bash
# Capture synchronized evidence for K4 issue #22 without changing shell state.
#
# Streams:
#   - K4 Quickshell IPC state
#   - Hyprland global cursor position
#   - Hyprland layer-surface geometry
#   - new [K4BottomHover] probe lines from the Quickshell log

set -u
set -o pipefail

DURATION=15
STATE_INTERVAL=0.10
LAYER_INTERVAL=0.20
LOG_FILE=/tmp/ii-vynx-k4.log
OUTPUT_DIR=""
START_NOW=0

usage() {
    cat <<'USAGE'
Usage: bash ./k4-bottom-hover-diagnose.sh [options]

Options:
  --duration SECONDS       Maximum capture duration (default: 15)
  --state-interval SECONDS IPC/cursor sample interval (default: 0.10)
  --layer-interval SECONDS layer sample interval (default: 0.20)
  --log PATH               Quickshell log containing [K4BottomHover]
                           (default: /tmp/ii-vynx-k4.log)
  --output DIR             Output directory (default: /tmp/k4-bottom-hover-<time>)
  --start-now              Skip the pre-capture Enter prompt
  -h, --help               Show this help

During capture, reproduce issue #22 once. Press Enter immediately after the
second spawn to stop early, or let the capture time out.
USAGE
}

while (($#)); do
    case "$1" in
        --duration)
            DURATION="${2:?missing value for --duration}"
            shift 2
            ;;
        --state-interval)
            STATE_INTERVAL="${2:?missing value for --state-interval}"
            shift 2
            ;;
        --layer-interval)
            LAYER_INTERVAL="${2:?missing value for --layer-interval}"
            shift 2
            ;;
        --log)
            LOG_FILE="${2:?missing value for --log}"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="${2:?missing value for --output}"
            shift 2
            ;;
        --start-now)
            START_NOW=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

for cmd in qs hyprctl date sleep; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Missing required command: $cmd" >&2
        exit 1
    fi
done

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="${TMPDIR:-/tmp}/k4-bottom-hover-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$OUTPUT_DIR"

META_FILE="$OUTPUT_DIR/meta.txt"
STATE_FILE="$OUTPUT_DIR/state.tsv"
LAYER_FILE="$OUTPUT_DIR/layers.tsv"
SHELL_SEGMENT_FILE="$OUTPUT_DIR/quickshell-segment.log"
EVENT_FILE="$OUTPUT_DIR/bottom-events.log"
SUMMARY_FILE="$OUTPUT_DIR/summary.txt"
RUN_FLAG="$OUTPUT_DIR/.capturing"

: > "$STATE_FILE"
: > "$LAYER_FILE"
: > "$EVENT_FILE"
: > "$SHELL_SEGMENT_FILE"

now_ms() {
    date +%s%3N
}

capture_cmd() {
    if command -v timeout >/dev/null 2>&1; then
        timeout 0.8 "$@"
    else
        "$@"
    fi
}

one_line() {
    local value="$1"
    value="${value//$'\n'/ }"
    value="${value//$'\t'/ }"
    printf '%s' "$value"
}

{
    echo "capture_created=$(date --iso-8601=seconds 2>/dev/null || date)"
    echo "duration=$DURATION"
    echo "state_interval=$STATE_INTERVAL"
    echo "layer_interval=$LAYER_INTERVAL"
    echo "log_file=$LOG_FILE"
    echo
    echo "[git]"
    git rev-parse HEAD 2>&1 || true
    git status --short 2>&1 || true
    echo
    echo "[processes]"
    pgrep -a -x qs 2>&1 || true
    echo
    echo "[quickshell]"
    qs --version 2>&1 || true
    qs ipc show 2>&1 || true
    echo
    echo "[hyprland]"
    hyprctl version 2>&1 || true
    hyprctl -j monitors 2>&1 || true
    echo
    echo "[initial-k4-status]"
    qs ipc call k4barDebug status 2>&1 || true
    echo
    echo "[initial-cursor]"
    hyprctl -j cursorpos 2>&1 || true
} > "$META_FILE"

if ! qs ipc show 2>/dev/null | grep -q 'k4barDebug'; then
    echo "k4barDebug IPC target is not registered." >&2
    echo "Make sure the diagnostic K4 branch is deployed and qs -c ii is running." >&2
    echo "See: $META_FILE" >&2
    exit 1
fi

LOG_START_BYTES=0
if [[ -f "$LOG_FILE" ]]; then
    LOG_START_BYTES=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
else
    echo "Warning: $LOG_FILE does not exist; internal [K4BottomHover] events cannot be correlated." >&2
fi

if (( START_NOW == 0 )); then
    cat <<'READY'

K4 #22 capture is ready.

Before starting:
  1. Put K4 at the bottom.
  2. Have Player available/playing.
  3. Keep the pointer away from the island.

Press Enter, then hover the collapsed pill and KEEP THE CURSOR STATIONARY.
After the second spawn, press Enter again to stop the capture early.
READY
    read -r _
fi

START_MS=$(now_ms)
printf 'start_ms=%s\n' "$START_MS" >> "$META_FILE"
touch "$RUN_FLAG"

sample_state() {
    while [[ -e "$RUN_FLAG" ]]; do
        local ts status cursor
        ts=$(now_ms)
        status=$(capture_cmd qs ipc call k4barDebug status 2>&1 || true)
        cursor=$(capture_cmd hyprctl -j cursorpos 2>&1 || true)
        printf '%s\t%s\t%s\n' \
            "$ts" "$(one_line "$status")" "$(one_line "$cursor")" >> "$STATE_FILE"
        sleep "$STATE_INTERVAL"
    done
}

sample_layers() {
    while [[ -e "$RUN_FLAG" ]]; do
        local ts layers
        ts=$(now_ms)
        layers=$(capture_cmd hyprctl -j layers 2>&1 || true)
        printf '%s\t%s\n' "$ts" "$(one_line "$layers")" >> "$LAYER_FILE"
        sleep "$LAYER_INTERVAL"
    done
}

sample_state &
STATE_PID=$!
sample_layers &
LAYER_PID=$!

printf 'Capturing for up to %ss. Reproduce #22 now; press Enter after the second spawn...\n' "$DURATION"
if (( START_NOW == 1 )); then
    sleep "$DURATION"
else
    read -r -t "$DURATION" _ || true
fi

rm -f "$RUN_FLAG"
kill "$STATE_PID" "$LAYER_PID" 2>/dev/null || true
wait "$STATE_PID" "$LAYER_PID" 2>/dev/null || true

END_MS=$(now_ms)
printf 'end_ms=%s\n' "$END_MS" >> "$META_FILE"

if [[ -f "$LOG_FILE" ]]; then
    if (( LOG_START_BYTES == 0 )); then
        cat "$LOG_FILE" > "$SHELL_SEGMENT_FILE"
    else
        tail -c +$((LOG_START_BYTES + 1)) "$LOG_FILE" > "$SHELL_SEGMENT_FILE" 2>/dev/null || true
    fi
    grep '\[K4BottomHover\]' "$SHELL_SEGMENT_FILE" > "$EVENT_FILE" || true
fi

if command -v python3 >/dev/null 2>&1; then
    python3 - "$OUTPUT_DIR" <<'PY' > "$SUMMARY_FILE"
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
state_path = root / "state.tsv"
layer_path = root / "layers.tsv"
event_path = root / "bottom-events.log"


def parse_json(text):
    try:
        return json.loads(text)
    except Exception:
        return None


def cursor_xy(obj):
    if isinstance(obj, dict):
        x = obj.get("x")
        y = obj.get("y")
        if isinstance(x, (int, float)) and isinstance(y, (int, float)):
            return (x, y)
    if isinstance(obj, list) and len(obj) >= 2 and all(isinstance(v, (int, float)) for v in obj[:2]):
        return tuple(obj[:2])
    return None


def find_k4_layers(obj):
    found = []

    def visit(value):
        if isinstance(value, dict):
            if value.get("namespace") == "quickshell:k4bar":
                found.append(value)
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)

    visit(obj)
    return found


def slim_layer(layer):
    if not isinstance(layer, dict):
        return layer
    result = {}
    for key, value in layer.items():
        if isinstance(value, (str, int, float, bool)) or value is None:
            result[key] = value
        elif isinstance(value, list) and len(value) <= 4 and all(isinstance(v, (str, int, float, bool)) for v in value):
            result[key] = value
    return result


states = []
if state_path.exists():
    for line in state_path.read_text(errors="replace").splitlines():
        parts = line.split("\t", 2)
        if len(parts) != 3:
            continue
        try:
            ts = int(parts[0])
        except ValueError:
            continue
        states.append((ts, parse_json(parts[1]), parse_json(parts[2]), parts[1], parts[2]))

layers = []
if layer_path.exists():
    for line in layer_path.read_text(errors="replace").splitlines():
        parts = line.split("\t", 1)
        if len(parts) != 2:
            continue
        try:
            ts = int(parts[0])
        except ValueError:
            continue
        layers.append((ts, parse_json(parts[1])))

events = []
event_re = re.compile(r"\[K4BottomHover\]\s+(\d+)\s+(\S+)")
if event_path.exists():
    for line in event_path.read_text(errors="replace").splitlines():
        match = event_re.search(line)
        if match:
            events.append((int(match.group(1)), match.group(2), line))
        else:
            events.append((None, "unparsed", line))


def nearest(items, ts):
    if ts is None or not items:
        return None
    return min(items, key=lambda item: abs(item[0] - ts))


print("K4 #22 bottom-hover diagnostic summary")
print("======================================")
print(f"state_samples: {len(states)}")
print(f"layer_samples: {len(layers)}")
print(f"bottom_hover_events: {len(events)}")

positions = [cursor_xy(s[2]) for s in states]
positions = [p for p in positions if p is not None]
if positions:
    xs = [p[0] for p in positions]
    ys = [p[1] for p in positions]
    print(f"cursor_range: x={min(xs)}..{max(xs)} (span {max(xs)-min(xs)}), y={min(ys)}..{max(ys)} (span {max(ys)-min(ys)})")
    if max(xs) - min(xs) <= 2 and max(ys) - min(ys) <= 2:
        print("cursor_stationary_check: PASS (<=2 px span)")
    else:
        print("cursor_stationary_check: MOVED (>2 px span)")
else:
    print("cursor_stationary_check: unavailable")

occupants = []
for ts, status, cursor, _, _ in states:
    if isinstance(status, dict):
        item = (status.get("occupant"), status.get("hovered"), status.get("activeScreen"))
        if not occupants or occupants[-1][1:] != item:
            occupants.append((ts,) + item)
if occupants:
    print("\nIPC state transitions:")
    for ts, occupant, hovered, screen in occupants:
        print(f"  {ts}: occupant={occupant!r} hovered={hovered!r} activeScreen={screen!r}")

print("\nCorrelated [K4BottomHover] timeline:")
if not events:
    print("  NO EVENTS CAPTURED")
else:
    for event_ts, reason, raw in events:
        print(f"\n  event {event_ts or '?'} {reason}")
        print(f"    qml: {raw.strip()}")
        state = nearest(states, event_ts)
        if state:
            sts, status, cursor, status_raw, cursor_raw = state
            delta = sts - event_ts if event_ts is not None else 0
            if isinstance(status, dict):
                print("    ipc(%+dms): occupant=%r hovered=%r activeScreen=%r rect=%r" % (
                    delta, status.get("occupant"), status.get("hovered"),
                    status.get("activeScreen"), status.get("rect")))
            else:
                print(f"    ipc({delta:+d}ms): {status_raw[:500]}")
            pos = cursor_xy(cursor)
            print(f"    cursor({delta:+d}ms): {pos if pos is not None else cursor_raw[:200]}")
        layer = nearest(layers, event_ts)
        if layer:
            lts, obj = layer
            delta = lts - event_ts if event_ts is not None else 0
            matches = find_k4_layers(obj)
            print(f"    k4_layers({delta:+d}ms): {json.dumps([slim_layer(x) for x in matches], separators=(',', ':'))}")

print("\nFiles:")
for name in ("meta.txt", "state.tsv", "layers.tsv", "quickshell-segment.log", "bottom-events.log"):
    print(f"  {root / name}")
PY
else
    {
        echo "python3 unavailable; raw capture completed."
        echo "state_samples=$(wc -l < "$STATE_FILE")"
        echo "layer_samples=$(wc -l < "$LAYER_FILE")"
        echo "bottom_hover_events=$(wc -l < "$EVENT_FILE")"
    } > "$SUMMARY_FILE"
fi

ARCHIVE="${OUTPUT_DIR%/}.tar.gz"
tar -czf "$ARCHIVE" -C "$(dirname "$OUTPUT_DIR")" "$(basename "$OUTPUT_DIR")" 2>/dev/null || true

cat "$SUMMARY_FILE"
echo
echo "Capture directory: $OUTPUT_DIR"
if [[ -f "$ARCHIVE" ]]; then
    echo "Bundle: $ARCHIVE"
fi
echo "Upload the .tar.gz bundle or paste summary.txt for diagnosis."
