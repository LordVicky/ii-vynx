#!/usr/bin/env bash

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
LIVE_THEME="$XDG_STATE_HOME/quickshell/user/generated/colors.json"
CACHE_SCRIPT="$SCRIPT_DIR/cachepalette.sh"
FULL_APPLY_SCRIPT="$SCRIPT_DIR/applypalette.sh"

usage() {
    cat >&2 <<'USAGE'
Usage:
  applycachedpalette.sh [--type <auto|scheme-*>]

If --type is omitted, the palette type is read from the live config file.
USAGE
    exit 2
}

die() {
    printf 'applycachedpalette: %s\n' "$*" >&2
    exit 1
}

is_video() {
    local extension="${1##*.}"
    case "${extension,,}" in
        mp4|webm|mkv|avi|mov) return 0 ;;
        *) return 1 ;;
    esac
}

is_valid_type() {
    case "$1" in
        scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

resolve_source_image() {
    local wallpaper="$1"
    local thumbnail

    if ! is_video "$wallpaper"; then
        printf '%s\n' "$wallpaper"
        return
    fi

    thumbnail=$(jq -r '.background.thumbnailPath // ""' "$SHELL_CONFIG_FILE" 2>/dev/null || true)
    [[ -n "$thumbnail" && "$thumbnail" != "null" && -f "$thumbnail" ]] \
        || die "video wallpaper has no readable cached thumbnail"
    printf '%s\n' "$thumbnail"
}

resolve_mode() {
    local current_mode
    current_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'" || true)
    if [[ "$current_mode" == "prefer-dark" ]]; then
        printf 'dark\n'
    else
        printf 'light\n'
    fi
}

resolve_auto_type() {
    local source_image="$1"
    local detected_type
    local venv

    venv="$(eval echo "${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}")"
    if [[ -n "$venv" && -f "$venv/bin/activate" ]]; then
        # shellcheck disable=SC1090
        source "$venv/bin/activate"
        detected_type=$("$SCRIPT_DIR/scheme_for_image.py" "$source_image" 2>/dev/null | tr -d '\n' || true)
        deactivate
    else
        detected_type=$("$SCRIPT_DIR/scheme_for_image.py" "$source_image" 2>/dev/null | tr -d '\n' || true)
    fi

    if is_valid_type "$detected_type"; then
        printf '%s\n' "$detected_type"
    else
        printf 'scheme-tonal-spot\n'
    fi
}

main() {
    local type=""
    local wallpaper
    local source_image
    local mode
    local cached_palette
    local tmp_theme
    local accent_color

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                [[ $# -ge 2 ]] || usage
                type="$2"
                shift 2
                ;;
            *)
                usage
                ;;
        esac
    done

    [[ -r "$SHELL_CONFIG_FILE" ]] || die "config is not readable: $SHELL_CONFIG_FILE"
    [[ -r "$CACHE_SCRIPT" ]] || die "cache helper is not readable: $CACHE_SCRIPT"
    [[ -r "$FULL_APPLY_SCRIPT" ]] || die "full palette helper is not readable: $FULL_APPLY_SCRIPT"
    command -v jq >/dev/null 2>&1 || die "jq is required"

    if [[ -z "$type" ]]; then
        type=$(jq -r '.appearance.palette.type // "auto"' "$SHELL_CONFIG_FILE")
    fi

    accent_color=$(jq -r '.appearance.palette.accentColor // ""' "$SHELL_CONFIG_FILE")
    if [[ "$accent_color" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
        exec bash "$FULL_APPLY_SCRIPT" --type "$type"
    fi

    if [[ "$type" != "auto" ]] && ! is_valid_type "$type"; then
        exec bash "$FULL_APPLY_SCRIPT" --type "$type"
    fi

    wallpaper=$(jq -r '.background.wallpaperPath // ""' "$SHELL_CONFIG_FILE")
    [[ -n "$wallpaper" && "$wallpaper" != "null" && -f "$wallpaper" ]] \
        || die "current wallpaper is not a readable file"

    source_image=$(resolve_source_image "$wallpaper")
    mode=$(resolve_mode)

    if [[ "$type" == "auto" ]]; then
        type=$(resolve_auto_type "$source_image")
    else
        is_valid_type "$type" || die "invalid generated palette type: $type"
    fi

    cached_palette=$(bash "$CACHE_SCRIPT" --source "$source_image" --type "$type" --mode "$mode")
    jq -e 'type == "object"' "$cached_palette" >/dev/null \
        || die "cached palette is invalid: $cached_palette"

    mkdir -p -- "$(dirname "$LIVE_THEME")"
    tmp_theme=$(mktemp "${LIVE_THEME}.XXXXXX")
    trap 'rm -f -- "$tmp_theme"' EXIT
    cp -- "$cached_palette" "$tmp_theme"
    mv -f -- "$tmp_theme" "$LIVE_THEME"
    trap - EXIT

    printf '%s\t%s\n' "$type" "$cached_palette"

    # Keep terminal/KDE/Code/etc. in sync after the shell palette is already live.
    # This remains in the same process group so a newer palette request can cancel
    # stale secondary theming work without blocking the cached shell update.
    bash "$FULL_APPLY_SCRIPT" --type "$type"
}

main "$@"
