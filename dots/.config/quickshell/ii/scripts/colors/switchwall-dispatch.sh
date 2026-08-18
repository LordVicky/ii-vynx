#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE_SCRIPT="$SCRIPT_DIR/applythememode.sh"
SWITCHWALL_SCRIPT="$SCRIPT_DIR/switchwall.sh"

main() {
    local -a original=("$@")
    local mode=""
    local mode_only="true"
    local saw_noswitch="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)
                [[ $# -ge 2 ]] || {
                    mode_only="false"
                    break
                }
                mode="$2"
                shift 2
                ;;
            --noswitch)
                saw_noswitch="true"
                shift
                ;;
            *)
                mode_only="false"
                break
                ;;
        esac
    done

    if [[ "$mode_only" == "true" ]] \
        && [[ "$saw_noswitch" == "true" ]] \
        && [[ "$mode" == "dark" || "$mode" == "light" ]] \
        && [[ -r "$MODE_SCRIPT" ]]; then
        exec bash "$MODE_SCRIPT" --mode "$mode"
    fi

    exec bash "$SWITCHWALL_SCRIPT" "${original[@]}"
}

main "$@"
