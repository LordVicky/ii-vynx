#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_BUILDER="$SCRIPT_DIR/build-hyprglass-local.sh"
MASK_ANTIALIAS="${HYPRGLASS_MASK_ANTIALIAS:-1}"
TMP_BUILDER=""

cleanup() {
    if [ -n "${TMP_BUILDER:-}" ]; then
        rm -f -- "$TMP_BUILDER"
    fi
}
trap cleanup EXIT

case "$MASK_ANTIALIAS" in
    0)
        exec "$BASE_BUILDER" "$@"
        ;;
    1) ;;
    *)
        printf '%s\n' "HYPRGLASS_MASK_ANTIALIAS must be 0 or 1." >&2
        exit 5
        ;;
esac

TMP_BUILDER="$(mktemp "$SCRIPT_DIR/.build-hyprglass-mask-aa.XXXXXX")"

python3 - "$BASE_BUILDER" "$TMP_BUILDER" <<'PY_WRAPPER'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
target = Path(sys.argv[2])

function_marker = "\nprepare_lua_headers() {\n"
if function_marker not in source:
    raise SystemExit("Could not locate prepare_lua_headers() in the HyprGlass builder")

function_text = r'''
apply_mask_antialias_ab() {
    local source_dir="$1"
    local target="$source_dir/src/Shaders.hpp"

    python3 - "$target" <<'PY_MASK'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

old_mask_sample = """    vec4 surfacePixel = vec4(0.0);
    bool hasMask = (useMask == 1);
    if (hasMask) {
        vec2 maskUV = uv * maskUVScale + maskUVOffset;
        surfacePixel = texture(maskTex, clamp(maskUV, 0.001, 0.999));
        if (surfacePixel.a < maskAlphaThreshold) discard;
    }
"""
new_mask_sample = """    vec4 surfacePixel = vec4(0.0);
    bool hasMask = (useMask == 1);
    float maskCoverage = 1.0;
    if (hasMask) {
        vec2 maskUV = uv * maskUVScale + maskUVOffset;
        surfacePixel = texture(maskTex, clamp(maskUV, 0.001, 0.999));

        // ii-vynx A/B: the horizontal bar uses a deliberately low-alpha QML
        // surface as its shape mask. Preserve Qt's fractional edge coverage
        // around the configured contour instead of snapping accepted edge
        // pixels to full-strength glass.
        float safeMaskThreshold = max(maskAlphaThreshold, 0.000001);
        if (maskAlphaThreshold < 0.01) {
            float maskAAWidth = max(fwidth(surfacePixel.a), 0.000001);
            maskCoverage = smoothstep(
                safeMaskThreshold - maskAAWidth,
                safeMaskThreshold + maskAAWidth,
                surfacePixel.a
            );
            if (maskCoverage < 0.001) discard;
        } else if (surfacePixel.a < safeMaskThreshold) {
            discard;
        }
    }
"""

if old_mask_sample not in text:
    raise SystemExit("HyprGlass mask-AA patch could not locate layer mask sampling")
text = text.replace(old_mask_sample, new_mask_sample, 1)

old_glass_alpha = "    float glassA = glassOpacity * cornerAlpha;\n"
new_glass_alpha = """    // Carry the low-alpha bar mask's antialias coverage through the final
    // premultiplied composite. Windows and normal layer masks remain unchanged.
    float glassA = glassOpacity * cornerAlpha * maskCoverage;
"""
if old_glass_alpha not in text:
    raise SystemExit("HyprGlass mask-AA patch could not locate glass alpha")
text = text.replace(old_glass_alpha, new_glass_alpha, 1)

path.write_text(text, encoding="utf-8")
PY_MASK

    log "Enabled ii-vynx low-alpha layer mask antialias A/B."
}
'''

source = source.replace(function_marker, "\n" + function_text + function_marker, 1)

call_marker = '    apply_live_bar_refresh_ab "$source_dir"\n'
if call_marker not in source:
    raise SystemExit("Could not locate the live-refresh patch call in the HyprGlass builder")
source = source.replace(
    call_marker,
    call_marker + '    apply_mask_antialias_ab "$source_dir"\n',
    1,
)

target.write_text(source, encoding="utf-8")
PY_WRAPPER

chmod +x "$TMP_BUILDER"
"$TMP_BUILDER" "$@"
