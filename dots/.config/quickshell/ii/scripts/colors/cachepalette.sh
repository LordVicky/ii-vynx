#!/usr/bin/env bash

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_ROOT="$XDG_CACHE_HOME/quickshell/palettes"
MATUGEN_TEMPLATE="$XDG_CONFIG_HOME/matugen/templates/colors.json"
CACHE_FORMAT_VERSION="1"

usage() {
    cat >&2 <<'USAGE'
Usage:
  cachepalette.sh --source <image> --type <scheme> --mode <dark|light>

Ensures the requested shell palette exists in the on-disk Vynx cache and
prints the cached JSON path on success.
USAGE
    exit 2
}

die() {
    printf 'cachepalette: %s\n' "$*" >&2
    exit 1
}

escape_toml_string() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    printf '%s' "$value"
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

main() {
    local source=""
    local type=""
    local mode=""
    local source_hash
    local template_hash
    local matugen_version
    local cache_key
    local cache_dir
    local destination
    local tmp_output
    local tmp_config
    local escaped_template
    local escaped_output

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --source)
                [[ $# -ge 2 ]] || usage
                source="$2"
                shift 2
                ;;
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

    [[ -n "$source" && -n "$type" && -n "$mode" ]] || usage
    [[ -f "$source" && -r "$source" ]] || die "source image is not readable: $source"
    [[ -f "$MATUGEN_TEMPLATE" && -r "$MATUGEN_TEMPLATE" ]] || die "Matugen colors template is not readable: $MATUGEN_TEMPLATE"
    is_valid_type "$type" || die "invalid generated palette type: $type"
    [[ "$mode" == "dark" || "$mode" == "light" ]] || die "mode must be dark or light"

    command -v matugen >/dev/null 2>&1 || die "matugen is required"
    command -v jq >/dev/null 2>&1 || die "jq is required"
    command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required"

    source_hash=$(sha256sum -- "$source" | cut -d' ' -f1)
    template_hash=$(sha256sum -- "$MATUGEN_TEMPLATE" | cut -d' ' -f1)
    matugen_version=$(matugen --version 2>/dev/null | head -n1 | tr -d '\r\n')
    [[ -n "$matugen_version" ]] || die "could not determine matugen version"

    cache_key=$(printf '%s\n%s\n%s\n%s\n' \
        "$CACHE_FORMAT_VERSION" "$source_hash" "$template_hash" "$matugen_version" \
        | sha256sum | cut -d' ' -f1)
    cache_dir="$CACHE_ROOT/$cache_key/$mode"
    destination="$cache_dir/$type.json"

    if jq -e 'type == "object"' "$destination" >/dev/null 2>&1; then
        printf '%s\n' "$destination"
        return 0
    fi

    mkdir -p -- "$cache_dir"
    exec 9>"$cache_dir/.${type}.lock"
    if command -v flock >/dev/null 2>&1; then
        flock 9
    fi

    # Another caller may have completed this entry while we waited for the lock.
    if jq -e 'type == "object"' "$destination" >/dev/null 2>&1; then
        printf '%s\n' "$destination"
        return 0
    fi

    tmp_output=$(mktemp "$cache_dir/.${type}.XXXXXX.json")
    tmp_config=$(mktemp "$cache_dir/.matugen.XXXXXX.toml")
    trap 'rm -f -- "$tmp_output" "$tmp_config"' EXIT

    escaped_template=$(escape_toml_string "$MATUGEN_TEMPLATE")
    escaped_output=$(escape_toml_string "$tmp_output")
    cat > "$tmp_config" <<EOF_CONFIG
[config]
version_check = false
caching = true

[templates.m3colors]
input_path = "$escaped_template"
output_path = "$escaped_output"
EOF_CONFIG

    matugen \
        --config "$tmp_config" \
        --source-color-index 0 \
        --mode "$mode" \
        --type "$type" \
        --quiet \
        image "$source"

    jq -e 'type == "object"' "$tmp_output" >/dev/null \
        || die "Matugen produced an invalid cached palette"

    mv -f -- "$tmp_output" "$destination"
    rm -f -- "$tmp_config"
    trap - EXIT

    printf '%s\n' "$destination"
}

main "$@"
