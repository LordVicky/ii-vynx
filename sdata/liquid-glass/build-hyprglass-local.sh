#!/usr/bin/env bash

set -euo pipefail

HYPRGLASS_REF="${HYPRGLASS_REF:-v0.7.0}"
HYPRGLASS_REPO="${HYPRGLASS_REPO:-https://github.com/hyprnux/hyprglass.git}"
INSTALL_ROOT="$HOME/.local/lib/ii-vynx/hyprglass"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
LICENSE_SOURCE="$REPO_ROOT/licenses/HyprGlass-BSD-3-Clause.txt"
LICENSE_TARGET="$HOME/.local/share/licenses/ii-vynx/HyprGlass-BSD-3-Clause.txt"
TMP_ROOT=""

log() {
    printf '%s\n' "$*"
}

cleanup() {
    if [ -n "${TMP_ROOT:-}" ]; then
        rm -rf -- "$TMP_ROOT"
    fi
}

trap cleanup EXIT

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log "Missing required build command: $1"
        return 1
    fi
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

major_minor() {
    printf '%s\n' "$1" | awk -F. '{ print $1 "." $2 }'
}

pkg_version() {
    pkg-config --modversion "$1" 2>/dev/null
}

main() {
    local command version_json runtime_version abi_hash runtime_abi
    local hyprland_version aq hu hg hc hlg build_abi
    local source_dir target_dir target magic deps

    for command in hyprctl pkg-config git make g++ ldd od install awk sed grep tr mktemp; do
        require_command "$command" || return 5
    done

    for module in hyprland pixman-1 libdrm aquamarine hyprutils hyprgraphics hyprcursor hyprlang; do
        if ! pkg-config --exists "$module"; then
            log "Missing required development module: $module"
            return 5
        fi
    done

    version_json="$(hyprctl -j version 2>/dev/null || true)"
    runtime_version="$(extract_json_string "$version_json" version)"
    abi_hash="$(extract_json_string "$version_json" abiHash)"
    runtime_abi="$(abi_suffix_from_hash "$abi_hash" 2>/dev/null || true)"

    if [[ ! "$runtime_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "Could not determine the running Hyprland version."
        return 5
    fi

    if [[ ! "$runtime_abi" =~ ^_aq_[0-9]+(\.[0-9]+)+(_[a-z]+_[0-9]+(\.[0-9]+)+)+$ ]]; then
        log "Could not determine the running Hyprland dependency ABI."
        return 5
    fi

    hyprland_version="$(pkg_version hyprland)"
    if [ "$hyprland_version" != "$runtime_version" ]; then
        log "Installed Hyprland development headers ($hyprland_version) do not match the running Hyprland ($runtime_version)."
        return 2
    fi

    aq="$(major_minor "$(pkg_version aquamarine)")"
    hu="$(major_minor "$(pkg_version hyprutils)")"
    hg="$(major_minor "$(pkg_version hyprgraphics)")"
    hc="$(major_minor "$(pkg_version hyprcursor)")"
    hlg="$(major_minor "$(pkg_version hyprlang)")"
    build_abi="_aq_${aq}_hu_${hu}_hg_${hg}_hc_${hc}_hlg_${hlg}"

    if [ "$build_abi" != "$runtime_abi" ]; then
        log "Installed development libraries do not match the running Hyprland dependency ABI."
        log "Running: $runtime_abi"
        log "Build:   $build_abi"
        return 2
    fi

    TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ii-vynx-hyprglass-build.XXXXXX")"
    source_dir="$TMP_ROOT/hyprglass"

    log "Building HyprGlass $HYPRGLASS_REF for Hyprland $runtime_version ABI $runtime_abi..."
    git clone --quiet --depth 1 --branch "$HYPRGLASS_REF" "$HYPRGLASS_REPO" "$source_dir"
    make -C "$source_dir" -j"$(nproc)"

    magic="$(od -An -tx1 -N4 "$source_dir/hyprglass.so" 2>/dev/null | tr -d '[:space:]')"
    if [ "$magic" != "7f454c46" ]; then
        log "Built HyprGlass output is not an ELF binary."
        return 4
    fi

    deps="$(ldd "$source_dir/hyprglass.so" 2>&1)"
    if printf '%s\n' "$deps" | grep -q 'not found'; then
        log "Built HyprGlass has unresolved runtime dependencies:"
        printf '%s\n' "$deps" | grep 'not found'
        return 4
    fi

    target_dir="$INSTALL_ROOT/$runtime_abi"
    target="$target_dir/hyprglass.so"
    mkdir -p "$target_dir"
    install -m 0644 "$source_dir/hyprglass.so" "$target"

    if [ -r "$LICENSE_SOURCE" ]; then
        mkdir -p "$(dirname "$LICENSE_TARGET")"
        install -m 0644 "$LICENSE_SOURCE" "$LICENSE_TARGET"
    fi

    log "Installed locally built HyprGlass backend: $target"
}

main "$@"
