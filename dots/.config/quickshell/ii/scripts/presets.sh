#!/usr/bin/env bash

set -euo pipefail

umask 077

config_home="${XDG_CONFIG_HOME:-${HOME:?HOME is not set}/.config}"
shell_config_dir="${config_home}/illogical-impulse"
config_file="${shell_config_dir}/config.json"
presets_dir="${shell_config_dir}/presets"

die() {
    printf 'presets: %s\n' "$*" >&2
    exit 1
}

require_jq() {
    command -v jq >/dev/null 2>&1 || die "jq is required"
}

validate_name() {
    local name="$1"

    [[ -n "$name" ]] || die "preset name cannot be empty"
    ((${#name} <= 80)) || die "preset name must be 80 characters or fewer"
    [[ "$name" != "." && "$name" != ".." ]] || die "invalid preset name"
    [[ "$name" != .* ]] || die "preset name cannot start with a dot"
    [[ "$name" != [[:space:]]* && "$name" != *[[:space:]] ]] || die "preset name cannot start or end with whitespace"
    [[ "$name" != */* && "$name" != *\\* ]] || die "preset name cannot contain path separators"
    [[ ! "$name" =~ [[:cntrl:]] ]] || die "preset name cannot contain control characters"
}

preset_path() {
    printf '%s/%s.json\n' "$presets_dir" "$1"
}

validate_json_object() {
    local path="$1"
    local label="$2"

    [[ -r "$path" ]] || die "$label is not readable: $path"
    jq -e 'type == "object"' "$path" >/dev/null 2>&1 || die "$label must contain a valid JSON object: $path"
}

save_preset() {
    local name="$1"
    local description="${2:-}"
    local replace="${3:-false}"
    local destination tmp

    validate_name "$name"
    validate_json_object "$config_file" "config"
    mkdir -p -- "$presets_dir"

    destination="$(preset_path "$name")"
    if [[ -e "$destination" || -L "$destination" ]]; then
        [[ -f "$destination" && ! -L "$destination" ]] || die "preset destination is not a regular file: $name"
        [[ "$replace" == "true" ]] || die "preset already exists: $name"
    fi

    tmp="$(mktemp "${presets_dir}/.preset-save.XXXXXX")"
    trap 'rm -f -- "$tmp"' EXIT

    if [[ -n "$description" ]]; then
        jq --arg description "$description" \
            'del(._presetMeta) | . + {"_presetMeta": {"description": $description}}' \
            "$config_file" > "$tmp"
        jq -e 'type == "object" and (._presetMeta.description | type == "string")' "$tmp" >/dev/null
    else
        jq 'del(._presetMeta)' "$config_file" > "$tmp"
        jq -e 'type == "object" and (has("_presetMeta") | not)' "$tmp" >/dev/null
    fi

    mv -f -- "$tmp" "$destination"
    trap - EXIT

    printf '%s\n' "$destination"
}

apply_preset() {
    local name="$1"
    local source tmp

    validate_name "$name"
    source="$(preset_path "$name")"
    [[ -f "$source" && ! -L "$source" ]] || die "preset is not a regular file: $name"
    validate_json_object "$config_file" "config"
    validate_json_object "$source" "preset"

    tmp="$(mktemp "${shell_config_dir}/.config-preset.XXXXXX")"
    trap 'rm -f -- "$tmp"' EXIT

    jq -s '(.[0] | del(._presetMeta)) * (.[1] | del(._presetMeta))' "$config_file" "$source" > "$tmp"
    jq -e 'type == "object" and (has("_presetMeta") | not)' "$tmp" >/dev/null
    chmod --reference="$config_file" "$tmp"
    mv -f -- "$tmp" "$config_file"
    trap - EXIT

    printf '%s\n' "$config_file"
}

remove_preset() {
    local name="$1"
    local source

    validate_name "$name"
    source="$(preset_path "$name")"
    [[ -e "$source" ]] || die "preset does not exist: $name"
    [[ -f "$source" && ! -L "$source" ]] || die "preset is not a regular file: $name"
    rm -f -- "$source"
}

list_presets() {
    local file

    [[ -d "$presets_dir" ]] || return 0
    while IFS= read -r -d '' file; do
        [[ -f "$file" && ! -L "$file" ]] || continue
        basename -- "$file" .json
    done < <(find "$presets_dir" -maxdepth 1 -type f -name '*.json' -print0 | sort -z)
}

usage() {
    cat >&2 <<'USAGE'
Usage:
  presets.sh --save <preset-name> [description]
  presets.sh --replace <preset-name> [description]
  presets.sh --apply <preset-name>
  presets.sh --remove <preset-name>
  presets.sh --list
USAGE
    exit 2
}

main() {
    require_jq

    case "${1:-}" in
        --save|save)
            (($# == 2 || $# == 3)) || usage
            save_preset "$2" "${3:-}" false
            ;;
        --replace|replace)
            (($# == 2 || $# == 3)) || usage
            save_preset "$2" "${3:-}" true
            ;;
        --apply|apply)
            (($# == 2)) || usage
            apply_preset "$2"
            ;;
        --remove|remove)
            (($# == 2)) || usage
            remove_preset "$2"
            ;;
        --list|list)
            (($# == 1)) || usage
            list_presets
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
