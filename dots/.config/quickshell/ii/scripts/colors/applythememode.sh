#!/usr/bin/env bash

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
CACHED_APPLY_SCRIPT="$SCRIPT_DIR/applycachedpalette.sh"
SWITCHWALL_SCRIPT="$SCRIPT_DIR/switchwall.sh"

usage() {
    cat >&2 <<'USAGE'
Usage:
  applythememode.sh --mode <dark|light>
  applythememode.sh --toggle
USAGE
    exit 2
}

die() {
    printf 'applythememode: %s\n' "$*" >&2
    exit 1
}

is_generated_type() {
    case "$1" in
        auto|scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

resolve_current_mode() {
    local current_mode
    current_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'" || true)
    if [[ "$current_mode" == "prefer-dark" ]]; then
        printf 'dark\n'
    else
        printf 'light\n'
    fi
}

main() {
    local mode=""
    local toggle="false"
    local current_mode
    local type
    local accent_color
    local enable_apps_shell

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)
                [[ $# -ge 2 ]] || usage
                mode="$2"
                shift 2
                ;;
            --toggle)
                toggle="true"
                shift
                ;;
            *)
                usage
                ;;
        esac
    done

    [[ -r "$SHELL_CONFIG_FILE" ]] || die "config is not readable: $SHELL_CONFIG_FILE"
    [[ -r "$CACHED_APPLY_SCRIPT" ]] || die "cached palette helper is not readable: $CACHED_APPLY_SCRIPT"
    [[ -r "$SWITCHWALL_SCRIPT" ]] || die "wallpaper switch helper is not readable: $SWITCHWALL_SCRIPT"
    command -v jq >/dev/null 2>&1 || die "jq is required"
    command -v gsettings >/dev/null 2>&1 || die "gsettings is required"

    if [[ "$toggle" == "true" ]]; then
        [[ -z "$mode" ]] || usage
        current_mode=$(resolve_current_mode)
        if [[ "$current_mode" == "dark" ]]; then
            mode="light"
        else
            mode="dark"
        fi
    fi

    [[ "$mode" == "dark" || "$mode" == "light" ]] || usage

    if [[ "$mode" == "dark" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
    else
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
    fi

    type=$(jq -r '.appearance.palette.type // "auto"' "$SHELL_CONFIG_FILE")
    accent_color=$(jq -r '.appearance.palette.accentColor // ""' "$SHELL_CONFIG_FILE")
    enable_apps_shell=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell // true' "$SHELL_CONFIG_FILE")

    if [[ "$enable_apps_shell" == "true" ]] \
        && [[ ! "$accent_color" =~ ^#?[A-Fa-f0-9]{6}$ ]] \
        && is_generated_type "$type"; then
        exec bash "$CACHED_APPLY_SCRIPT" --type "$type" --mode "$mode"
    fi

    exec bash "$SWITCHWALL_SCRIPT" --mode "$mode" --noswitch --type "$type"
}

main "$@"
