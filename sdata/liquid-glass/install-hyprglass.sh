#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="$SCRIPT_DIR/hyprglass-compat.tsv"
LICENSE_SOURCE="$REPO_ROOT/licenses/HyprGlass-BSD-3-Clause.txt"
INSTALL_ROOT="$HOME/.local/lib/ii-vynx/hyprglass"
LICENSE_TARGET="$HOME/.local/share/licenses/ii-vynx/HyprGlass-BSD-3-Clause.txt"

log() {
    printf '%s\n' "$*"
}

read_hyprland_commit() {
    local version_json=""

    if command -v hyprctl >/dev/null 2>&1; then
        version_json="$(hyprctl -j version 2>/dev/null || true)"
    fi

    if [ -z "$version_json" ] && command -v Hyprland >/dev/null 2>&1; then
        version_json="$(Hyprland --version-json 2>/dev/null || true)"
    fi

    printf '%s' "$version_json" \
        | tr -d '\n' \
        | sed -n 's/.*"commit"[[:space:]]*:[[:space:]]*"\([0-9A-Fa-f]\{7,64\}\)".*/\1/p'
}

download_asset() {
    local url="$1"
    local destination="$2"

    if command -v curl >/dev/null 2>&1; then
        curl --fail --location --retry 3 --retry-delay 1 --output "$destination" "$url"
        return $?
    fi

    if command -v wget >/dev/null 2>&1; then
        wget --tries=3 --output-document="$destination" "$url"
        return $?
    fi

    return 127
}

main() {
    local commit entry hyprland_version hyprglass_release asset_url
    local target_dir target tmp magic

    if [ ! -r "$MANIFEST" ]; then
        log "HyprGlass compatibility manifest is missing: $MANIFEST"
        return 5
    fi

    commit="$(read_hyprland_commit)"
    if [[ ! "$commit" =~ ^[0-9A-Fa-f]{7,64}$ ]]; then
        log "Could not determine the running Hyprland commit; skipping bundled HyprGlass."
        return 5
    fi

    entry="$(awk -F '\t' -v commit="$commit" '$1 == commit { print; exit }' "$MANIFEST")"
    if [ -z "$entry" ]; then
        log "No bundled HyprGlass build is registered for Hyprland commit $commit."
        return 2
    fi

    IFS=$'\t' read -r _ hyprland_version hyprglass_release asset_url <<< "$entry"
    if [ -z "$asset_url" ]; then
        log "Invalid HyprGlass compatibility entry for Hyprland commit $commit."
        return 5
    fi

    target_dir="$INSTALL_ROOT/$commit"
    target="$target_dir/hyprglass.so"

    if [ -s "$target" ]; then
        log "HyprGlass $hyprglass_release is already installed for Hyprland $hyprland_version."
        return 0
    fi

    tmp="$(mktemp "${TMPDIR:-/tmp}/ii-vynx-hyprglass.XXXXXX")" || return 5
    trap 'rm -f "$tmp"' EXIT INT TERM

    log "Installing HyprGlass $hyprglass_release for Hyprland $hyprland_version..."
    if ! download_asset "$asset_url" "$tmp"; then
        case $? in
            127) log "Neither curl nor wget is available; cannot download HyprGlass." ;;
            *) log "Failed to download the HyprGlass prebuilt binary." ;;
        esac
        return 3
    fi

    magic="$(od -An -tx1 -N4 "$tmp" 2>/dev/null | tr -d '[:space:]')"
    if [ "$magic" != "7f454c46" ]; then
        log "Downloaded HyprGlass asset is not an ELF binary; refusing to install it."
        return 4
    fi

    mkdir -p "$target_dir"
    install -m 0644 "$tmp" "$target"

    if [ -r "$LICENSE_SOURCE" ]; then
        mkdir -p "$(dirname "$LICENSE_TARGET")"
        install -m 0644 "$LICENSE_SOURCE" "$LICENSE_TARGET"
    fi

    log "Installed bundled HyprGlass backend: $target"
    return 0
}

main "$@"
