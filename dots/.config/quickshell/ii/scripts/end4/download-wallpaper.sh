#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
    printf 'Usage: %s URL TARGET_PATH\n' "${0##*/}" >&2
    exit 2
fi

url=$1
target_path=$2
target_dir=${target_path%/*}

if [[ -z $url || -z $target_path || $target_dir == "$target_path" ]]; then
    printf 'Invalid wallpaper URL or target path\n' >&2
    exit 2
fi

mkdir -p -- "$target_dir"
temp_path=$(mktemp --tmpdir="$target_dir" ".${target_path##*/}.XXXXXX")
trap 'rm -f -- "$temp_path"' EXIT

curl --fail --location --silent --show-error --output "$temp_path" -- "$url"
mv -f -- "$temp_path" "$target_path"
trap - EXIT
