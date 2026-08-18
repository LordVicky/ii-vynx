#!/usr/bin/env bash

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
LIVE_THEME="$XDG_STATE_HOME/quickshell/user/generated/colors.json"
SHELL_QML="$XDG_CONFIG_HOME/quickshell/ii/shell.qml"

usage() {
    cat >&2 <<'USAGE'
Usage:
  publishpalette.sh --source <palette.json>

Validates and publishes one palette JSON to the live Quickshell theme file.
USAGE
    exit 2
}

die() {
    printf 'publishpalette: %s\n' "$*" >&2
    exit 1
}

main() {
    local source=""
    local source_real
    local live_real
    local lock_file

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --source)
                [[ $# -ge 2 ]] || usage
                source="$2"
                shift 2
                ;;
            *)
                usage
                ;;
        esac
    done

    [[ -n "$source" ]] || usage
    [[ -f "$source" && -r "$source" ]] || die "palette is not readable: $source"
    command -v jq >/dev/null 2>&1 || die "jq is required"

    jq -e 'type == "object" and length > 0' "$source" >/dev/null \
        || die "palette is not a non-empty JSON object: $source"

    mkdir -p -- "$(dirname "$LIVE_THEME")"
    lock_file="$(dirname "$LIVE_THEME")/.palette-publish.lock"
    exec 9>"$lock_file"
    if command -v flock >/dev/null 2>&1; then
        flock 9
    fi

    source_real=$(readlink -f -- "$source")
    live_real=$(readlink -f -- "$LIVE_THEME" 2>/dev/null || true)

    if [[ "$source_real" != "$live_real" ]] && ! cmp -s -- "$source" "$LIVE_THEME" 2>/dev/null; then
        if [[ -f "$LIVE_THEME" ]]; then
            # Preserve the inode so FileView remains attached across theme changes.
            cat -- "$source" > "$LIVE_THEME"
        else
            cp -- "$source" "$LIVE_THEME"
        fi
    fi

    jq -e 'type == "object" and length > 0' "$LIVE_THEME" >/dev/null \
        || die "live palette became invalid after publication"

    # The watcher remains the fallback, but explicitly ask the shell process to
    # consume the completed file when its IPC endpoint is available.
    if command -v qs >/dev/null 2>&1 && [[ -f "$SHELL_QML" ]]; then
        qs -p "$SHELL_QML" ipc call theme refreshMaterialPalette >/dev/null 2>&1 || true
    fi
}

main "$@"
