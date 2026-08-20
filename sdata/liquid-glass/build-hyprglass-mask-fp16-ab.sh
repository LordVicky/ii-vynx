#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_BUILDER="$SCRIPT_DIR/build-hyprglass-mask-aa-linear-ab.sh"
UPSTREAM_REPO="${HYPRGLASS_REPO:-https://github.com/hyprnux/hyprglass.git}"
UPSTREAM_REF="${HYPRGLASS_REF:-v0.7.0}"
TMP_ROOT=""

cleanup() {
    if [ -n "${TMP_ROOT:-}" ]; then
        rm -rf -- "$TMP_ROOT"
    fi
}
trap cleanup EXIT

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ii-vynx-hyprglass-fp16-ab.XXXXXX")"
SOURCE_DIR="$TMP_ROOT/hyprglass"
TEST_REF="ii-vynx-fp16-mask-ab"

printf '%s\n' "Preparing HyprGlass FP16 bar-mask A/B source..."
git clone --quiet --depth 1 --branch "$UPSTREAM_REF" "$UPSTREAM_REPO" "$SOURCE_DIR"

python3 - "$SOURCE_DIR/src/GlassLayerSurface.cpp" <<'PY_FP16_MASK'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = """    DRMFormat tempFormat = (monitor->useFP16()) ? source->m_drmFormat : DRM_FORMAT_ARGB8888;
"""
new = """    // ii-vynx A/B: preserve subpixel alpha precision for the horizontal bar
    // mask in SDR. Keep every other layer and the native FP16 path unchanged.
    const bool forceBarFP16Mask = layerSurface->m_namespace == \"quickshell:bar\";
    DRMFormat tempFormat = monitor->useFP16()
        ? source->m_drmFormat
        : (forceBarFP16Mask ? DRM_FORMAT_ABGR16161616F : DRM_FORMAT_ARGB8888);
"""
if old not in text:
    raise SystemExit("HyprGlass FP16 mask A/B no longer matches GlassLayerSurface.cpp")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY_FP16_MASK

git -C "$SOURCE_DIR" config user.name "ii-vynx A/B"
git -C "$SOURCE_DIR" config user.email "ii-vynx-ab@localhost"
git -C "$SOURCE_DIR" switch --quiet -c "$TEST_REF"
git -C "$SOURCE_DIR" add src/GlassLayerSurface.cpp
git -C "$SOURCE_DIR" commit --quiet -m "test: force FP16 bar mask framebuffer"

printf '%s\n' "Enabled ii-vynx FP16 horizontal bar mask A/B."
HYPRGLASS_REPO="file://$SOURCE_DIR" \
HYPRGLASS_REF="$TEST_REF" \
bash "$BASE_BUILDER" "$@"
