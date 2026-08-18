#!/usr/bin/env bash

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
CACHE_SCRIPT="$SCRIPT_DIR/cachepalette.sh"
PUBLISH_SCRIPT="$SCRIPT_DIR/publishpalette.sh"
SWITCHWALL_SCRIPT="$SCRIPT_DIR/switchwall.sh"

usage() {
    cat >&2 <<'USAGE'
Usage:
  applycachedpalette.sh [--type <auto|scheme-*>] [--mode <dark|light>]

If --type is omitted, the palette type is read from the live config file.
If --mode is omitted, the mode is resolved from the current system color scheme.
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

apply_system_mode() {
    local mode="$1"

    case "$mode" in
        dark)
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
            gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' || true
            ;;
        light)
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' || true
            gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3' || true
            ;;
    esac
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
    local mode=""
    local cached_palette
    local accent_color
    local enable_apps_shell
    local builtin_theme
    local custom_theme
    local theme_file

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                [[ $# -ge 2 ]] || usage
                type="$2"
                shift 2
                ;;
            --mode)
                [[ $# -ge 2 ]] || usage
                mode="$2"
                shift 2
                ;;
            *)
                usage
                ;;
        esac
    done

    [[ -r "$SHELL_CONFIG_FILE" ]] || die "config is not readable: $SHELL_CONFIG_FILE"
    [[ -r "$CACHE_SCRIPT" ]] || die "cache helper is not readable: $CACHE_SCRIPT"
    [[ -r "$PUBLISH_SCRIPT" ]] || die "palette publisher is not readable: $PUBLISH_SCRIPT"
    [[ -r "$SWITCHWALL_SCRIPT" ]] || die "wallpaper switch helper is not readable: $SWITCHWALL_SCRIPT"
    command -v jq >/dev/null 2>&1 || die "jq is required"

    if [[ -n "$mode" && "$mode" != "dark" && "$mode" != "light" ]]; then
        die "invalid mode: $mode"
    fi

    if [[ -z "$type" ]]; then
        type=$(jq -r '.appearance.palette.type // "auto"' "$SHELL_CONFIG_FILE")
    fi

    if [[ -n "$mode" ]]; then
        apply_system_mode "$mode"
    fi

    enable_apps_shell=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell // true' "$SHELL_CONFIG_FILE")
    accent_color=$(jq -r '.appearance.palette.accentColor // ""' "$SHELL_CONFIG_FILE")
    if [[ "$enable_apps_shell" == "false" || "$accent_color" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
        exec bash "$SWITCHWALL_SCRIPT" --noswitch --type "$type"
    fi

    if [[ "$type" != "auto" ]] && ! is_valid_type "$type"; then
        builtin_theme="$SCRIPT_DIR/../../defaults/themes/${type}.json"
        custom_theme="$(dirname "$SHELL_CONFIG_FILE")/themes/${type}.json"
        theme_file=""

        if [[ -f "$builtin_theme" && -r "$builtin_theme" ]]; then
            theme_file="$builtin_theme"
        elif [[ -f "$custom_theme" && -r "$custom_theme" ]]; then
            theme_file="$custom_theme"
        fi

        if [[ -n "$theme_file" ]]; then
            exec bash "$PUBLISH_SCRIPT" --source "$theme_file"
        fi

        exec bash "$SWITCHWALL_SCRIPT" --noswitch --type "$type"
    fi

    wallpaper=$(jq -r '.background.wallpaperPath // ""' "$SHELL_CONFIG_FILE")
    [[ -n "$wallpaper" && "$wallpaper" != "null" && -f "$wallpaper" ]] \
        || die "current wallpaper is not a readable file"

    source_image=$(resolve_source_image "$wallpaper")
    if [[ -z "$mode" ]]; then
        mode=$(resolve_mode)
    fi

    if [[ "$type" == "auto" ]]; then
        type=$(resolve_auto_type "$source_image")
    else
        is_valid_type "$type" || die "invalid generated palette type: $type"
    fi

    cached_palette=$(bash "$CACHE_SCRIPT" --source "$source_image" --type "$type" --mode "$mode")
    jq -e 'type == "object"' "$cached_palette" >/dev/null \
        || die "cached palette is invalid: $cached_palette"

    bash "$PUBLISH_SCRIPT" --source "$cached_palette"
    printf '%s\t%s\n' "$type" "$cached_palette"
}

main "$@"
