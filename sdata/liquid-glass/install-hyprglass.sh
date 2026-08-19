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

read_hyprland_version_json() {
    local version_json=""

    if command -v hyprctl >/dev/null 2>&1; then
        version_json="$(hyprctl -j version 2>/dev/null || true)"
    fi

    if [ -z "$version_json" ] && command -v Hyprland >/dev/null 2>&1; then
        version_json="$(Hyprland --version-json 2>/dev/null || true)"
    fi

    printf '%s' "$version_json"
}

extract_json_string() {
    local json="$1"
    local field="$2"

    printf '%s' "$json" \
        | tr -d '\n' \
        | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

abi_suffix_from_hash() {
    local abi_hash="$1"

    case "$abi_hash" in
        *_aq_*)
            printf '_aq_%s' "${abi_hash#*_aq_}"
            ;;
        *)
            return 1
            ;;
    esac
}

platform_id() {
    local os_fields os_id os_version arch

    if [ -n "${VYNX_GLASS_PLATFORM:-}" ]; then
        printf '%s' "$VYNX_GLASS_PLATFORM"
        return 0
    fi

    if [ ! -r /etc/os-release ]; then
        return 1
    fi

    os_fields="$(
        . /etc/os-release
        printf '%s\t%s' "${ID:-}" "${VERSION_ID:-}"
    )"
    IFS=$'\t' read -r os_id os_version <<< "$os_fields"
    arch="$(uname -m 2>/dev/null || true)"

    if [[ ! "$os_id" =~ ^[A-Za-z0-9._-]+$ ]] \
        || [[ ! "$os_version" =~ ^[A-Za-z0-9._-]+$ ]] \
        || [[ ! "$arch" =~ ^[A-Za-z0-9._-]+$ ]]; then
        return 1
    fi

    printf '%s-%s-%s' "$os_id" "$os_version" "$arch"
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
    local version_json hyprland_version abi_hash abi_suffix platform entry hyprglass_release asset_url
    local target_dir target magic download_status dependency_status

    if [ ! -r "$MANIFEST" ]; then
        log "HyprGlass compatibility manifest is missing: $MANIFEST"
        return 5
    fi

    version_json="$(read_hyprland_version_json)"
    hyprland_version="$(extract_json_string "$version_json" version)"
    abi_hash="$(extract_json_string "$version_json" abiHash)"
    abi_suffix="$(abi_suffix_from_hash "$abi_hash" 2>/dev/null || true)"
    platform="$(platform_id 2>/dev/null || true)"

    if [[ ! "$hyprland_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "Could not determine the running Hyprland version; skipping bundled HyprGlass."
        return 5
    fi

    if [[ ! "$abi_suffix" =~ ^_aq_[0-9]+(\.[0-9]+)+(_[a-z]+_[0-9]+(\.[0-9]+)+)+$ ]]; then
        log "Could not determine the running Hyprland dependency ABI; skipping bundled HyprGlass."
        return 5
    fi

    if [[ ! "$platform" =~ ^[A-Za-z0-9._-]+-[A-Za-z0-9._-]+-[A-Za-z0-9._-]+$ ]]; then
        log "Could not determine the runtime platform; skipping bundled HyprGlass."
        return 5
    fi

    entry="$(awk -F '\t' -v platform="$platform" -v abi="$abi_suffix" '$1 == platform && $2 == abi { print; exit }' "$MANIFEST")"
    if [ -z "$entry" ]; then
        log "No bundled HyprGlass build is registered for $platform, Hyprland $hyprland_version ABI $abi_suffix."
        return 2
    fi

    IFS=$'\t' read -r _ _ hyprglass_release asset_url <<< "$entry"
    if [ -z "$asset_url" ]; then
        log "Invalid HyprGlass compatibility entry for $platform ABI $abi_suffix."
        return 5
    fi

    target_dir="$INSTALL_ROOT/$abi_suffix"
    target="$target_dir/hyprglass.so"

    if [ -s "$target" ]; then
        magic="$(od -An -tx1 -N4 "$target" 2>/dev/null | tr -d '[:space:]')"
        if [ "$magic" = "7f454c46" ]; then
            check_runtime_dependencies "$target"
            dependency_status=$?
            if [ "$dependency_status" -eq 0 ]; then
                log "HyprGlass $hyprglass_release is already installed for $platform, Hyprland $hyprland_version ABI $abi_suffix."
                return 0
            fi
            return "$dependency_status"
        fi

        log "Existing HyprGlass binary is invalid; replacing it."
        rm -f -- "$target"
    fi

    TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/ii-vynx-hyprglass.XXXXXX")" || return 5

    log "Installing HyprGlass $hyprglass_release for $platform, Hyprland $hyprland_version ABI $abi_suffix..."
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
