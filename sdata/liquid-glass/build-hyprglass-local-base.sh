#!/usr/bin/env bash

set -euo pipefail

HYPRGLASS_REF="${HYPRGLASS_REF:-v0.7.0}"
HYPRGLASS_REPO="${HYPRGLASS_REPO:-https://github.com/hyprnux/hyprglass.git}"
HYPRLAND_REPO="${HYPRLAND_REPO:-https://github.com/hyprwm/Hyprland.git}"
HYPRLAND_PROTOCOLS_REPO="${HYPRLAND_PROTOCOLS_REPO:-https://github.com/hyprwm/hyprland-protocols.git}"
HYPRLAND_PROTOCOLS_REF="${HYPRLAND_PROTOCOLS_REF:-v0.7.0}"
HYPRGLASS_LIVE_BAR_REFRESH="${HYPRGLASS_LIVE_BAR_REFRESH:-1}"
LUA_RELEASE="${LUA_RELEASE:-5.5.1}"
LUA_URL="${LUA_URL:-https://www.lua.org/ftp/lua-${LUA_RELEASE}.tar.gz}"
LUA_SHA256="${LUA_SHA256:-1c4b4068d67061f2a2231ad2b5422e77acea1487ea9890f6320af614f4373dce}"
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
        *_aq_*) printf '_aq_%s' "${abi_hash#*_aq_}" ;;
        *) return 1 ;;
    esac
}

major_minor() {
    printf '%s\n' "$1" | awk -F. '{ print $1 "." $2 }'
}

pkg_version() {
    pkg-config --modversion "$1" 2>/dev/null
}

apply_live_bar_refresh_ab() {
    local source_dir="$1"
    local target="$source_dir/src/GlassLayerSurface.cpp"

    case "$HYPRGLASS_LIVE_BAR_REFRESH" in
        0)
            log "Building upstream HyprGlass layer cache behavior (live bar refresh A/B disabled)."
            return 0
            ;;
        1) ;;
        *)
            log "HYPRGLASS_LIVE_BAR_REFRESH must be 0 or 1."
            return 5
            ;;
    esac

    python3 - "$target" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = """    const bool backgroundChanged = !m_hasCachedSample ||
                                   currentGeneration != m_lastSceneGeneration ||
                                   isAnimating;
"""
new = """    // ii-vynx A/B: the upstream scene-generation cache does not track
    // per-frame window geometry or lower layer-surface content changes. Force
    // the horizontal shell bar surfaces to resample whenever Hyprland renders
    // them so moving windows and wallpaper parallax stay live in the glass.
    const bool forceLiveBarRefresh = layerSurface->m_namespace == \"quickshell:bar\" ||
                                     layerSurface->m_namespace == \"quickshell:bar-glass\";
    const bool backgroundChanged = forceLiveBarRefresh ||
                                   !m_hasCachedSample ||
                                   currentGeneration != m_lastSceneGeneration ||
                                   isAnimating;
"""
if old not in text:
    raise SystemExit("HyprGlass live-bar A/B patch no longer matches GlassLayerSurface.cpp")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY

    log "Enabled ii-vynx live bar background refresh A/B."
}

prepare_lua_headers() {
    local archive="$TMP_ROOT/lua-${LUA_RELEASE}.tar.gz"
    local source_dir="$TMP_ROOT/lua-${LUA_RELEASE}"
    local header

    log "Preparing Lua $LUA_RELEASE headers for Hyprland's Lua plugin API..."
    curl --fail --location --silent --show-error "$LUA_URL" --output "$archive"
    printf '%s  %s\n' "$LUA_SHA256" "$archive" | sha256sum --check --status
    tar -xzf "$archive" -C "$TMP_ROOT"

    for header in lua.h luaconf.h lauxlib.h lualib.h; do
        if [ ! -r "$source_dir/src/$header" ]; then
            log "Lua source archive is missing required header: $header"
            return 4
        fi
    done
}

prepare_hyprland_headers() {
    local runtime_version="$1"
    local runtime_commit="$2"
    local aq_full="$3"
    local hu_full="$4"
    local hg_full="$5"
    local hc_full="$6"
    local hlg_full="$7"
    local lua_include="$8"
    local source_dir="$TMP_ROOT/hyprland"
    local protocols_repo="$TMP_ROOT/hyprland-protocols"
    local pc_dir="$TMP_ROOT/pkgconfig"
    local protocol_list="$TMP_ROOT/protocols.tsv"
    local wayland_protocols_dir wayland_scanner_dir actual_commit
    local proto_path proto_name external xml
    local aq_major aq_minor aq_patch

    git clone --quiet --depth 1 --branch "v${runtime_version}" "$HYPRLAND_REPO" "$source_dir"
    actual_commit="$(git -C "$source_dir" rev-parse HEAD)"
    if [ "$actual_commit" != "$runtime_commit" ]; then
        log "Hyprland v${runtime_version} resolved to $actual_commit, but the running compositor reports $runtime_commit."
        return 2
    fi

    (
        cd "$source_dir"
        ./scripts/generateShaderIncludes.sh >/dev/null
    )

    wayland_protocols_dir="$(pkg-config --variable=pkgdatadir wayland-protocols 2>/dev/null || true)"
    wayland_scanner_dir="$(pkg-config --variable=pkgdatadir wayland-scanner 2>/dev/null || true)"
    if [ -z "$wayland_protocols_dir" ] || [ ! -d "$wayland_protocols_dir" ]; then
        log "Could not locate wayland-protocols data through pkg-config."
        return 5
    fi
    if [ -z "$wayland_scanner_dir" ] || [ ! -r "$wayland_scanner_dir/wayland.xml" ]; then
        log "Could not locate wayland.xml through pkg-config wayland-scanner."
        return 5
    fi

    git clone --quiet --depth 1 --branch "$HYPRLAND_PROTOCOLS_REF" "$HYPRLAND_PROTOCOLS_REPO" "$protocols_repo"

    python3 - "$source_dir/CMakeLists.txt" > "$protocol_list" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
pattern = re.compile(
    r'protocolnew\(\s*"([^"]+)"\s+"([^"]+)"\s+(true|false)\s*\)',
    re.MULTILINE,
)
for path, name, external in pattern.findall(text):
    print(path, name, external, sep="\t")
PY

    if [ ! -s "$protocol_list" ]; then
        log "Could not extract Hyprland protocol generation list."
        return 5
    fi

    while IFS=$'\t' read -r proto_path proto_name external; do
        case "$proto_path" in
            *'${HYPRLAND_PROTOCOLS}'*)
                xml="$protocols_repo/protocols/$proto_name.xml"
                ;;
            *)
                if [ "$external" = "true" ]; then
                    xml="$source_dir/$proto_path/$proto_name.xml"
                else
                    xml="$wayland_protocols_dir/$proto_path/$proto_name.xml"
                fi
                ;;
        esac

        if [ ! -r "$xml" ]; then
            log "Missing protocol source while preparing exact Hyprland headers: $xml"
            return 5
        fi
        hyprwayland-scanner "$xml" "$source_dir/protocols/" >/dev/null
    done < "$protocol_list"

    hyprwayland-scanner --wayland-enums "$wayland_scanner_dir/wayland.xml" "$source_dir/protocols/" >/dev/null

    IFS=. read -r aq_major aq_minor aq_patch _ <<< "$aq_full"
    cat > "$source_dir/src/version.h" <<EOF_VERSION
#pragma once
#define GIT_COMMIT_HASH    "$runtime_commit"
#define GIT_BRANCH         "v$runtime_version"
#define GIT_COMMIT_MESSAGE ""
#define GIT_COMMIT_DATE    ""
#define GIT_DIRTY          ""
#define GIT_TAG            "v$runtime_version"
#define GIT_COMMITS        ""
#define AQUAMARINE_VERSION "$aq_full"
#define AQUAMARINE_VERSION_MAJOR $aq_major
#define AQUAMARINE_VERSION_MINOR $aq_minor
#define AQUAMARINE_VERSION_PATCH ${aq_patch:-0}
#define HYPRLANG_VERSION     "$hlg_full"
#define HYPRUTILS_VERSION    "$hu_full"
#define HYPRCURSOR_VERSION   "$hc_full"
#define HYPRGRAPHICS_VERSION "$hg_full"
EOF_VERSION

    mkdir -p "$pc_dir"
    cat > "$pc_dir/hyprland.pc" <<EOF_PC
prefix=$TMP_ROOT
Name: Hyprland
URL: https://github.com/hyprwm/Hyprland
Description: Temporary exact Hyprland headers for ii-vynx HyprGlass build
Version: $runtime_version
Requires: aquamarine, hyprcursor, hyprgraphics, hyprlang, hyprutils, libdrm, egl, cairo, xkbcommon, libinput, wayland-server, xcb, xcb-render, xcb-xfixes, xcb-icccm, xcb-composite, xcb-res, xcb-errors
Cflags: -I$TMP_ROOT -I$source_dir/protocols -I$source_dir -I$source_dir/src -I$lua_include
EOF_PC
}

main() {
    local command version_json runtime_version runtime_commit abi_hash runtime_abi
    local aq_full hu_full hg_full hc_full hlg_full aq hu hg hc hlg build_abi
    local source_dir pc_dir lua_include target_dir target magic deps

    for command in hyprctl pkg-config git make g++ python3 hyprwayland-scanner curl tar sha256sum ldd od install awk sed grep tr mktemp; do
        require_command "$command" || return 5
    done

    for module in pixman-1 libdrm aquamarine hyprutils hyprgraphics hyprcursor hyprlang wayland-protocols wayland-scanner; do
        if ! pkg-config --exists "$module"; then
            log "Missing required development module: $module"
            return 5
        fi
    done

    version_json="$(hyprctl -j version 2>/dev/null || true)"
    runtime_version="$(extract_json_string "$version_json" version)"
    runtime_commit="$(extract_json_string "$version_json" commit)"
    abi_hash="$(extract_json_string "$version_json" abiHash)"
    runtime_abi="$(abi_suffix_from_hash "$abi_hash" 2>/dev/null || true)"

    if [[ ! "$runtime_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
        || [[ ! "$runtime_commit" =~ ^[0-9a-f]{40}$ ]]; then
        log "Could not determine the running Hyprland version and commit."
        return 5
    fi

    if [[ ! "$runtime_abi" =~ ^_aq_[0-9]+(\.[0-9]+)+(_[a-z]+_[0-9]+(\.[0-9]+)+)+$ ]]; then
        log "Could not determine the running Hyprland dependency ABI."
        return 5
    fi

    aq_full="$(pkg_version aquamarine)"
    hu_full="$(pkg_version hyprutils)"
    hg_full="$(pkg_version hyprgraphics)"
    hc_full="$(pkg_version hyprcursor)"
    hlg_full="$(pkg_version hyprlang)"
    aq="$(major_minor "$aq_full")"
    hu="$(major_minor "$hu_full")"
    hg="$(major_minor "$hg_full")"
    hc="$(major_minor "$hc_full")"
    hlg="$(major_minor "$hlg_full")"
    build_abi="_aq_${aq}_hu_${hu}_hg_${hg}_hc_${hc}_hlg_${hlg}"

    if [ "$build_abi" != "$runtime_abi" ]; then
        log "Installed development libraries do not match the running Hyprland dependency ABI."
        log "Running: $runtime_abi"
        log "Build:   $build_abi"
        return 2
    fi

    TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ii-vynx-hyprglass-build.XXXXXX")"
    source_dir="$TMP_ROOT/hyprglass"
    pc_dir="$TMP_ROOT/pkgconfig"
    lua_include="$TMP_ROOT/lua-${LUA_RELEASE}/src"

    prepare_lua_headers

    log "Preparing exact Hyprland $runtime_version plugin headers without hyprland-devel..."
    prepare_hyprland_headers "$runtime_version" "$runtime_commit" "$aq_full" "$hu_full" "$hg_full" "$hc_full" "$hlg_full" "$lua_include"

    log "Building HyprGlass $HYPRGLASS_REF for Hyprland $runtime_version ABI $runtime_abi..."
    git clone --quiet --depth 1 --branch "$HYPRGLASS_REF" "$HYPRGLASS_REPO" "$source_dir"
    apply_live_bar_refresh_ab "$source_dir"
    python3 "$SCRIPT_DIR/patch-hyprglass-layer-damage.py" "$source_dir"
    PKG_CONFIG_PATH="$pc_dir${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" make -C "$source_dir" -j"$(nproc)"

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
