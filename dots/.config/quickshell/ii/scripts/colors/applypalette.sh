#!/usr/bin/env bash

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
TERMINAL_SCHEME="$SCRIPT_DIR/terminal/scheme-base.json"
THUMBNAIL_DIR="$XDG_CONFIG_HOME/hypr/custom/scripts/mpvpaper_thumbnails"

die() {
    printf 'applypalette: %s\n' "$*" >&2
    exit 1
}

is_video() {
    local extension="${1##*.}"
    case "${extension,,}" in
        mp4|webm|mkv|avi|mov) return 0 ;;
        *) return 1 ;;
    esac
}

get_image_source() {
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

    command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg is required to sample a video wallpaper"
    mkdir -p "$THUMBNAIL_DIR"
    thumbnail="$THUMBNAIL_DIR/$(basename "$wallpaper").jpg"
    ffmpeg -y -i "$wallpaper" -vframes 1 "$thumbnail" >/dev/null 2>&1
    [[ -f "$thumbnail" ]] || die "could not extract a frame from the current video wallpaper"
    printf '%s\n' "$thumbnail"
}

detect_scheme_type() {
    local source_image="$1"
    local venv

    venv="$(eval echo "${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}")"
    if [[ -n "$venv" && -f "$venv/bin/activate" ]]; then
        # shellcheck disable=SC1090
        source "$venv/bin/activate"
        "$SCRIPT_DIR/scheme_for_image.py" "$source_image" 2>/dev/null | tr -d '\n'
        deactivate
    else
        "$SCRIPT_DIR/scheme_for_image.py" "$source_image" 2>/dev/null | tr -d '\n'
    fi
}

apply_post_colors() {
    local type="$1"
    local enable_qt_apps
    local kde_scheme_variant

    enable_qt_apps=$(jq -r '.appearance.wallpaperTheming.enableQtApps' "$SHELL_CONFIG_FILE" 2>/dev/null || echo true)
    if [[ "$enable_qt_apps" == "true" ]]; then
        case "$type" in
            scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot)
                kde_scheme_variant="$type"
                ;;
            *)
                kde_scheme_variant="scheme-tonal-spot"
                ;;
        esac
        "$XDG_CONFIG_HOME/matugen/templates/kde/kde-material-you-colors-wrapper.sh" \
            --scheme-variant "$kde_scheme_variant" >/dev/null 2>&1 &
    fi

    "$SCRIPT_DIR/code/material-code-set-color.sh" || true
    "$SCRIPT_DIR/../ytmusic/generate-ytmusic-theme.sh" >/dev/null 2>&1 &
}

main() {
    local type=""
    local wallpaper
    local source_image
    local accent_color
    local current_mode
    local mode
    local force_dark_mode
    local harmony
    local harmonize_threshold
    local term_fg_boost
    local detected_type
    local venv
    local -a matugen_args=(--source-color-index 0)
    local -a material_args=()
    local allowed_types=(
        scheme-content
        scheme-expressive
        scheme-fidelity
        scheme-fruit-salad
        scheme-monochrome
        scheme-neutral
        scheme-rainbow
        scheme-tonal-spot
        auto
    )

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                [[ $# -ge 2 ]] || die "--type requires a value"
                type="$2"
                shift 2
                ;;
            *)
                die "unknown argument: $1"
                ;;
        esac
    done

    [[ -r "$SHELL_CONFIG_FILE" ]] || die "config is not readable: $SHELL_CONFIG_FILE"
    command -v jq >/dev/null 2>&1 || die "jq is required"
    command -v matugen >/dev/null 2>&1 || die "matugen is required"

    if [[ -z "$type" ]]; then
        type=$(jq -r '.appearance.palette.type // "auto"' "$SHELL_CONFIG_FILE")
    fi

    local valid_type="false"
    local candidate
    for candidate in "${allowed_types[@]}"; do
        if [[ "$candidate" == "$type" ]]; then
            valid_type="true"
            break
        fi
    done
    [[ "$valid_type" == "true" ]] || die "invalid palette type: $type"

    wallpaper=$(jq -r '.background.wallpaperPath // ""' "$SHELL_CONFIG_FILE")
    [[ -n "$wallpaper" && "$wallpaper" != "null" && -f "$wallpaper" ]] || die "current wallpaper is not a readable file"
    source_image=$(get_image_source "$wallpaper")

    if [[ "$type" == "auto" ]]; then
        detected_type=$(detect_scheme_type "$source_image")
        valid_type="false"
        for candidate in "${allowed_types[@]}"; do
            if [[ "$candidate" == "$detected_type" && "$candidate" != "auto" ]]; then
                valid_type="true"
                break
            fi
        done
        if [[ "$valid_type" == "true" ]]; then
            type="$detected_type"
        else
            type="scheme-tonal-spot"
        fi
    fi

    accent_color=$(jq -r '.appearance.palette.accentColor // ""' "$SHELL_CONFIG_FILE")
    if [[ "$accent_color" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
        matugen_args+=(color hex "$accent_color")
        material_args=(--color "$accent_color")
    else
        matugen_args+=(image "$source_image")
        material_args=(--path "$source_image")
    fi

    current_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'" || true)
    if [[ "$current_mode" == "prefer-dark" ]]; then
        mode="dark"
    else
        mode="light"
    fi
    matugen_args+=(--mode "$mode" --type "$type")

    force_dark_mode=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode // false' "$SHELL_CONFIG_FILE")
    if [[ "$force_dark_mode" == "true" ]]; then
        material_args+=(--mode dark)
    else
        material_args+=(--mode "$mode")
    fi
    material_args+=(--scheme "$type" --termscheme "$TERMINAL_SCHEME" --blend_bg_fg)
    material_args+=(--cache "$STATE_DIR/user/generated/color.txt")

    harmony=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmony // empty' "$SHELL_CONFIG_FILE")
    harmonize_threshold=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold // empty' "$SHELL_CONFIG_FILE")
    term_fg_boost=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost // empty' "$SHELL_CONFIG_FILE")
    [[ -n "$harmony" ]] && material_args+=(--harmony "$harmony")
    [[ -n "$harmonize_threshold" ]] && material_args+=(--harmonize_threshold "$harmonize_threshold")
    [[ -n "$term_fg_boost" ]] && material_args+=(--term_fg_boost "$term_fg_boost")

    if [[ $(jq -r '.appearance.wallpaperTheming.enableAppsAndShell' "$SHELL_CONFIG_FILE") == "false" ]]; then
        exit 0
    fi

    mkdir -p "$CACHE_DIR/user/generated" "$STATE_DIR/user/generated"
    matugen "${matugen_args[@]}" || die "matugen failed"

    venv="$(eval echo "${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}")"
    if [[ -n "$venv" && -f "$venv/bin/activate" ]]; then
        # shellcheck disable=SC1090
        source "$venv/bin/activate"
        python3 "$SCRIPT_DIR/generate_colors_material.py" "${material_args[@]}" \
            > "$STATE_DIR/user/generated/material_colors.scss" || die "material color generation failed"
        deactivate
    else
        python3 "$SCRIPT_DIR/generate_colors_material.py" "${material_args[@]}" \
            > "$STATE_DIR/user/generated/material_colors.scss" || die "material color generation failed"
    fi

    "$SCRIPT_DIR/applycolor.sh" || true
    apply_post_colors "$type"
}

main "$@"
