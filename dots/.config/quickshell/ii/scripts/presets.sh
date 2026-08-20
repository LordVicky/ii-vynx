#!/usr/bin/env bash

set -euo pipefail

umask 077

config_home="${XDG_CONFIG_HOME:-${HOME:?HOME is not set}/.config}"
shell_config_dir="${config_home}/illogical-impulse"
config_file="${shell_config_dir}/config.json"
liquid_glass_file="${shell_config_dir}/liquid-glass.json"
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
    local has_liquid_glass=false

    validate_name "$name"
    validate_json_object "$config_file" "config"

    if [[ -e "$liquid_glass_file" || -L "$liquid_glass_file" ]]; then
        [[ -f "$liquid_glass_file" && ! -L "$liquid_glass_file" ]] || die "liquid glass settings are not a regular file"
        validate_json_object "$liquid_glass_file" "liquid glass settings"
        has_liquid_glass=true
    fi

    mkdir -p -- "$presets_dir"

    destination="$(preset_path "$name")"
    if [[ -e "$destination" || -L "$destination" ]]; then
        [[ -f "$destination" && ! -L "$destination" ]] || die "preset destination is not a regular file: $name"
        [[ "$replace" == "true" ]] || die "preset already exists: $name"
    fi

    tmp="$(mktemp "${presets_dir}/.preset-save.XXXXXX")"
    trap 'rm -f -- "$tmp"' EXIT

    if [[ "$has_liquid_glass" == "true" ]]; then
        if [[ -n "$description" ]]; then
            jq --arg description "$description" --slurpfile liquidGlass "$liquid_glass_file" \
                'del(._presetMeta) | . + {"_presetMeta": {"description": $description, "liquidGlass": $liquidGlass[0]}}' \
                "$config_file" > "$tmp"
        else
            jq --slurpfile liquidGlass "$liquid_glass_file" \
                'del(._presetMeta) | . + {"_presetMeta": {"liquidGlass": $liquidGlass[0]}}' \
                "$config_file" > "$tmp"
        fi
        jq -e 'type == "object" and (._presetMeta.liquidGlass | type == "object")' "$tmp" >/dev/null
    elif [[ -n "$description" ]]; then
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
    local source tmp liquid_tmp=""
    local restore_liquid_glass=false

    validate_name "$name"
    source="$(preset_path "$name")"
    [[ -f "$source" && ! -L "$source" ]] || die "preset is not a regular file: $name"
    validate_json_object "$config_file" "config"
    validate_json_object "$source" "preset"

    if jq -e '._presetMeta? | type == "object" and has("liquidGlass")' "$source" >/dev/null 2>&1; then
        jq -e '._presetMeta.liquidGlass | type == "object"' "$source" >/dev/null 2>&1 \
            || die "preset liquid glass settings must be a JSON object: $name"
        restore_liquid_glass=true
    fi

    tmp="$(mktemp "${shell_config_dir}/.config-preset.XXXXXX")"
    cleanup_apply() {
        rm -f -- "$tmp"
        if [[ -n "$liquid_tmp" ]]; then
            rm -f -- "$liquid_tmp"
        fi
    }
    trap cleanup_apply EXIT

    jq -s '(.[0] | del(._presetMeta)) * (.[1] | del(._presetMeta))' "$config_file" "$source" > "$tmp"
    jq -e 'type == "object" and (has("_presetMeta") | not)' "$tmp" >/dev/null

    if [[ "$restore_liquid_glass" == "true" ]]; then
        liquid_tmp="$(mktemp "${shell_config_dir}/.liquid-glass-preset.XXXXXX")"

        if [[ -e "$liquid_glass_file" || -L "$liquid_glass_file" ]]; then
            [[ -f "$liquid_glass_file" && ! -L "$liquid_glass_file" ]] || die "liquid glass settings are not a regular file"
            validate_json_object "$liquid_glass_file" "liquid glass settings"
            jq -s '.[0] * .[1]._presetMeta.liquidGlass' "$liquid_glass_file" "$source" > "$liquid_tmp"
            chmod --reference="$liquid_glass_file" "$liquid_tmp"
        else
            jq '._presetMeta.liquidGlass' "$source" > "$liquid_tmp"
        fi

        jq -e 'type == "object"' "$liquid_tmp" >/dev/null 2>&1 \
            || die "resolved liquid glass preset settings must be a JSON object: $name"
    fi

    chmod --reference="$config_file" "$tmp"
    mv -f -- "$tmp" "$config_file"

    if [[ "$restore_liquid_glass" == "true" ]]; then
        mv -f -- "$liquid_tmp" "$liquid_glass_file"
    fi

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
