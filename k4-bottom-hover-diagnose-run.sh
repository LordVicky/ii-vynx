#!/usr/bin/env bash
# Instance-aware launcher for k4-bottom-hover-diagnose.sh.
# Keeps the capture harness pointed at the same named Quickshell config that
# was launched with `qs -c ii`, and waits for IPC registration before capture.

set -euo pipefail

CONFIG="ii"
WAIT_SECONDS="10"
LOG_FILE="/tmp/ii-vynx-k4.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS="$SCRIPT_DIR/k4-bottom-hover-diagnose.sh"

usage() {
    cat <<'USAGE'
Usage: bash ./k4-bottom-hover-diagnose-run.sh [runner options] [-- harness options]

Runner options:
  --config NAME           Quickshell config name (default: ii)
  --wait SECONDS          Wait for k4barDebug registration (default: 10)
  --log PATH              Quickshell log used for startup diagnostics and passed
                          through to the capture harness
  -h, --help              Show this help

Any remaining arguments are passed to k4-bottom-hover-diagnose.sh.
USAGE
}

HARNESS_ARGS=()
while (($#)); do
    case "$1" in
        --config)
            CONFIG="${2:?missing value for --config}"
            shift 2
            ;;
        --wait)
            WAIT_SECONDS="${2:?missing value for --wait}"
            shift 2
            ;;
        --log)
            LOG_FILE="${2:?missing value for --log}"
            HARNESS_ARGS+=("--log" "$LOG_FILE")
            shift 2
            ;;
        --)
            shift
            HARNESS_ARGS+=("$@")
            break
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            HARNESS_ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ ! -f "$HARNESS" ]]; then
    echo "Capture harness not found: $HARNESS" >&2
    exit 1
fi

REAL_QS="$(command -v qs || true)"
if [[ -z "$REAL_QS" ]]; then
    echo "Missing required command: qs" >&2
    exit 1
fi

ipc_show() {
    "$REAL_QS" -c "$CONFIG" ipc show 2>&1
}

printf 'Waiting up to %ss for k4barDebug on Quickshell config %q...\n' "$WAIT_SECONDS" "$CONFIG"
DEADLINE=$((SECONDS + WAIT_SECONDS))
IPC_OUTPUT=""
while (( SECONDS <= DEADLINE )); do
    IPC_OUTPUT="$(ipc_show || true)"
    if grep -q '^target k4barDebug\b' <<<"$IPC_OUTPUT"; then
        break
    fi
    sleep 0.25
done

if ! grep -q '^target k4barDebug\b' <<<"$IPC_OUTPUT"; then
    echo >&2
    echo "k4barDebug did not register on config '$CONFIG'." >&2
    echo >&2
    echo "=== qs -c $CONFIG ipc show ===" >&2
    printf '%s\n' "$IPC_OUTPUT" >&2
    echo >&2
    echo "=== Quickshell processes ===" >&2
    pgrep -af '(^|/)(qs|quickshell)( |$)' >&2 || true
    if [[ -f "$LOG_FILE" ]]; then
        echo >&2
        echo "=== tail -n 120 $LOG_FILE ===" >&2
        tail -n 120 "$LOG_FILE" >&2 || true
    else
        echo >&2
        echo "Quickshell log not found: $LOG_FILE" >&2
    fi
    exit 1
fi

# The capture script invokes `qs` through `timeout`, so a shell function is not
# sufficient. Put a tiny executable shim first in PATH that pins every IPC call
# to the selected config while leaving version/help calls untouched.
SHIM_DIR="$(mktemp -d "${TMPDIR:-/tmp}/k4-qs-shim.XXXXXX")"
trap 'rm -rf "$SHIM_DIR"' EXIT
export K4_REAL_QS="$REAL_QS"
export K4_QS_CONFIG="$CONFIG"

cat > "$SHIM_DIR/qs" <<'SHIM'
#!/usr/bin/env bash
set -e
case "${1:-}" in
    --version|-v|--help|-h)
        exec "$K4_REAL_QS" "$@"
        ;;
    *)
        exec "$K4_REAL_QS" -c "$K4_QS_CONFIG" "$@"
        ;;
esac
SHIM
chmod +x "$SHIM_DIR/qs"

printf 'k4barDebug registered. Starting synchronized capture on config %q.\n' "$CONFIG"
PATH="$SHIM_DIR:$PATH" bash "$HARNESS" "${HARNESS_ARGS[@]}"
