#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_BUILDER="$SCRIPT_DIR/build-hyprglass-local.sh"
TMP_BUILDER=""

cleanup() {
    if [ -n "${TMP_BUILDER:-}" ]; then
        rm -f -- "$TMP_BUILDER"
    fi
}
trap cleanup EXIT

TMP_BUILDER="$(mktemp "$SCRIPT_DIR/.build-hyprglass-mask-aa.XXXXXX")"

python3 - "$BASE_BUILDER" "$TMP_BUILDER" <<'PY_WRAPPER'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
target = Path(sys.argv[2])

function_end = '''    log "Enabled ii-vynx alpha-mask edge refraction."
}
\'\'\'
'''
if function_end not in source:
    raise SystemExit("Could not locate the production mask-edge patch function")

antialias_function = r'''    log "Enabled ii-vynx alpha-mask edge refraction."
}

apply_mask_antialias_ab() {
    local source_dir="$1"
    local target="$source_dir/src/Shaders.hpp"

    python3 - "$target" <<'PY_MASK_AA'
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

        // ii-vynx A/B: preserve Qt's fractional coverage only for the shell's
        // ultra-low-alpha bar mask. The production mask-edge field remains
        // unchanged and still determines refraction/highlight geometry.
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
new_glass_alpha = """    // Preserve subpixel coverage at the horizontal bar silhouette while
    // keeping the validated interior optical field and all normal masks intact.
    float glassA = glassOpacity * cornerAlpha * maskCoverage;
"""
if old_glass_alpha not in text:
    raise SystemExit("HyprGlass mask-AA patch could not locate glass alpha")
text = text.replace(old_glass_alpha, new_glass_alpha, 1)

path.write_text(text, encoding="utf-8")
PY_MASK_AA

    log "Enabled ii-vynx low-alpha bar mask antialias A/B."
}
'''

source = source.replace(function_end, antialias_function + "'''\n", 1)

call = '''    call_marker + '    apply_mask_edge_refraction "$source_dir"\\n',
'''
replacement = '''    call_marker + '    apply_mask_edge_refraction "$source_dir"\\n    apply_mask_antialias_ab "$source_dir"\\n',
'''
if call not in source:
    raise SystemExit("Could not locate production mask-edge patch call")
source = source.replace(call, replacement, 1)

target.write_text(source, encoding="utf-8")
PY_WRAPPER

chmod +x "$TMP_BUILDER"
"$TMP_BUILDER" "$@"
