#!/usr/bin/env bash

# Shared policy helpers for shell-side feature entry points.
# The QML Config singleton and these helpers intentionally read the same file:
#   $XDG_CONFIG_HOME/illogical-impulse/config.json
# Invalid, absent, or unreadable policy state fails closed.

_vynx_policy_config_file() {
    local xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    printf '%s/illogical-impulse/config.json\n' "$xdg_config_home"
}

_vynx_ai_policy() {
    local config_file
    config_file="$(_vynx_policy_config_file)"

    if [[ ! -r "$config_file" ]] || ! command -v jq >/dev/null 2>&1; then
        printf '0\n'
        return 0
    fi

    local value
    value="$(jq -er '.policies.ai // 0 | if type == "number" then . else 0 end' "$config_file" 2>/dev/null)" || value=0

    case "$value" in
        0|1|2) printf '%s\n' "$value" ;;
        *) printf '0\n' ;;
    esac
}

ai_enabled() {
    case "$(_vynx_ai_policy)" in
        1|2) return 0 ;;
        *) return 1 ;;
    esac
}

ai_local_allowed() {
    ai_enabled
}

ai_online_allowed() {
    [[ "$(_vynx_ai_policy)" == "1" ]]
}

require_ai() {
    if ai_enabled; then
        return 0
    fi
    printf 'AI is disabled by policies.ai\n' >&2
    return 77
}

require_local_ai() {
    if ai_local_allowed; then
        return 0
    fi
    printf 'Local AI is disabled by policies.ai\n' >&2
    return 77
}

require_online_ai() {
    if ai_online_allowed; then
        return 0
    fi
    printf 'Online AI is disabled by policies.ai\n' >&2
    return 77
}
