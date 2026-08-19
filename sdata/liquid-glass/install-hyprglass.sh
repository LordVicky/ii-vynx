#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="$SCRIPT_DIR/hyprglass-compat.tsv"
LICENSE_SOURCE="$REPO_ROOT/licenses/HyprGlass-BSD-3-Clause.txt"
INSTALL_ROOT="$HOME/.local/lib/ii-vynx/hyprglass"
LICENSE_TARGET="$HOME/.local/share/licenses/ii-vynx/HyprGlass-BSD-3-Clause.txt"
TMP_FILE=""

log() {
    printf '%s\n' "$*"
}

cleanup() {
    if [ -n "${TMP_FILE:-}" ]; then
        rm -f -- "$TMP_FILE"
    fi
}

trap cleanup EXIT

read_hyprland_version() {
    local version_json=""

    if command -v hyprctl >/dev/null 2>&1; then
        version_json="$(hyprctl -j version 2>/dev/null || true)"
    fi

    if [ -z "$version_json" ] && command -v Hyprland >/dev/null 2>&1; then
        version_json="$(Hyprland --version-json 2>/dev/null || true)"
    fi

    printf '%s' "$version_json" \
        | tr -d '\n' \
        | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)".*/\1/p'
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

check_runtime_dependencies() {
    local binary="$1"
    local output status

    if ! command -v ldd >/dev/null 2>&1; then
        log "ldd is unavailable; cannot validate HyprGlass runtime dependencies."
        return 5
    fi

    output="$(ldd "$binary" 2>&1)"
    status=$?
    if [ "$status" -ne 0 ]; then
        log "Could not inspect HyprGlass runtime dependencies."
        printf '%s\n' "$output"
        return 4
    fi

    if printf '%s\n' "$output" | grep -q 'not found'; then
        log "HyprGlass prebuilt has unresolved runtime dependencies:"
        printf '%s\n' "$output" | grep 'not found'
        return 4
    fi

    return 0
}

main() {
    local hyprland_version entry hyprglass_release asset_url
    local target_dir target magic download_status dependency_status

    if [ ! -r "$MANIFEST" ]; then
        log "HyprGlass compatibility manifest is missing: $MANIFEST"
        return 5
    fi

    hyprland_version="$(read_hyprland_version)"
    if [[ ! "$hyprland_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "Could not determine the running Hyprland version; skipping bundled HyprGlass."
        return 5
    fi

    entry="$(awk -F '\t' -v version="$hyprland_version" '$1 == version { print; exit }' "$MANIFEST")"
    if [ -z "$entry" ]; then
        log "No bundled HyprGlass build is registered for Hyprland $hyprland_version."
        return 2
    fi

    IFS=$'\t' read -r _ hyprglass_release asset_url <<< "$entry"
    if [ -z "$asset_url" ]; then
        log "Invalid HyprGlass compatibility entry for Hyprland $hyprland_version."
        return 5
    fi

    target_dir="$INSTALL_ROOT/$hyprland_version"
    target="$target_dir/hyprglass.so"

    if [ -s "$target" ]; then
        magic="$(od -An -tx1 -N4 "$target" 2>/dev/null | tr -d '[:space:]')"
        if [ "$magic" = "7f454c46" ]; then
            check_runtime_dependencies "$target"
            dependency_status=$?
            if [ "$dependency_status" -eq 0 ]; then
                log "HyprGlass $hyprglass_release is already installed for Hyprland $hyprland_version."
                return 0
            fi
            return "$dependency_status"
        fi

        log "Existing HyprGlass binary is invalid; replacing it."
        rm -f -- "$target"
    fi

    TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/ii-vynx-hyprglass.XXXXXX")" || return 5

    log "Installing HyprGlass $hyprglass_release for Hyprland $hyprland_version..."
    download_asset "$asset_url" "$TMP_FILE"
    download_status=$?
    if [ "$download_status" -ne 0 ]; then
        case "$download_status" in
            127) log "Neither curl nor wget is available; cannot download HyprGlass." ;;
            *) log "Failed to download the HyprGlass prebuilt binary." ;;
        esac
        return 3
    fi

    magic="$(od -An -tx1 -N4 "$TMP_FILE" 2>/dev/null | tr -d '[:space:]')"
    if [ "$magic" != "7f454c46" ]; then
        log "Downloaded HyprGlass asset is not an ELF binary; refusing to install it."
        return 4
    fi

    check_runtime_dependencies "$TMP_FILE"
    dependency_status=$?
    if [ "$dependency_status" -ne 0 ]; then
        return "$dependency_status"
    fi

    mkdir -p "$target_dir"
    install -m 0644 "$TMP_FILE" "$target"

    if [ -r "$LICENSE_SOURCE" ]; then
        mkdir -p "$(dirname "$LICENSE_TARGET")"
        install -m 0644 "$LICENSE_SOURCE" "$LICENSE_TARGET"
    fi

    log "Installed bundled HyprGlass backend: $target"
    return 0
}

main "$@"
