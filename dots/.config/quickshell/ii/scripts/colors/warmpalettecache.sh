#!/usr/bin/env bash

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
CACHE_ROOT="$XDG_CACHE_HOME/quickshell/palettes"
CACHE_SCRIPT="$SCRIPT_DIR/cachepalette.sh"

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
    if [[ -n "$thumbnail" && "$thumbnail" != "null" && -f "$thumbnail" ]]; then
        printf '%s\n' "$thumbnail"
        return
    fi

    return 1
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
    local wallpaper
    local source_image
    local source_hash
    local mode
    local configured_type
    local auto_type
    local priority_type
    local cached_palette
    local cache_dir=""
    local auto_tmp
    local current_wallpaper
    local type
    local -a types=(
        scheme-content
        scheme-expressive
        scheme-fidelity
        scheme-fruit-salad
        scheme-monochrome
        scheme-neutral
        scheme-rainbow
        scheme-tonal-spot
    )
    local -a ordered_types=()

    [[ -r "$SHELL_CONFIG_FILE" ]] || return 0
    [[ -r "$CACHE_SCRIPT" ]] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    command -v sha256sum >/dev/null 2>&1 || return 0

    wallpaper=$(jq -r '.background.wallpaperPath // ""' "$SHELL_CONFIG_FILE")
    [[ -n "$wallpaper" && "$wallpaper" != "null" && -f "$wallpaper" ]] || return 0
    source_image=$(resolve_source_image "$wallpaper") || return 0
    mode=$(resolve_mode)
    auto_type=$(resolve_auto_type "$source_image")
    configured_type=$(jq -r '.appearance.palette.type // "auto"' "$SHELL_CONFIG_FILE")

    if [[ "$configured_type" == "auto" ]]; then
        priority_type="$auto_type"
    elif is_valid_type "$configured_type"; then
        priority_type="$configured_type"
    else
        priority_type="$auto_type"
    fi

    ordered_types+=("$priority_type")
    for type in "${types[@]}"; do
        [[ "$type" == "$priority_type" ]] || ordered_types+=("$type")
    done

    mkdir -p -- "$CACHE_ROOT"
    source_hash=$(sha256sum -- "$source_image" | cut -d' ' -f1)
    exec 9>"$CACHE_ROOT/.warm-${source_hash}-${mode}.lock"
    if command -v flock >/dev/null 2>&1; then
        flock -n 9 || return 0
    fi

    for type in "${ordered_types[@]}"; do
        current_wallpaper=$(jq -r '.background.wallpaperPath // ""' "$SHELL_CONFIG_FILE" 2>/dev/null || true)
        [[ "$current_wallpaper" == "$wallpaper" ]] || return 0

        cached_palette=$(bash "$CACHE_SCRIPT" --source "$source_image" --type "$type" --mode "$mode") \
            || continue
        [[ -n "$cache_dir" ]] || cache_dir=$(dirname "$cached_palette")
    done

    if [[ -n "$cache_dir" ]]; then
        auto_tmp=$(mktemp "$cache_dir/.auto.XXXXXX")
        trap 'rm -f -- "$auto_tmp"' EXIT
        printf '%s\n' "$auto_type" > "$auto_tmp"
        mv -f -- "$auto_tmp" "$cache_dir/auto.txt"
        trap - EXIT
    fi
}

main "$@"
