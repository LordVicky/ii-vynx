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

extra_functions = r'''    log "Enabled ii-vynx alpha-mask edge refraction."
}

apply_mask_edge_normal_smoothing_ab() {
    local source_dir="$1"
    local target="$source_dir/src/Shaders.hpp"

    python3 - "$target" <<'PY_MASK_NORMAL'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

old_direction_field = r"""    const float D = 0.70710678;

    // First do one radius check in eight directions. Interior pixels stop here,
    // so the extra mask work is concentrated around the actual visible edge.
    float outL  = maskOutsideAt(uv, vec2(-1.0,  0.0), bezelWidthPx);
    float outR  = maskOutsideAt(uv, vec2( 1.0,  0.0), bezelWidthPx);
    float outT  = maskOutsideAt(uv, vec2( 0.0, -1.0), bezelWidthPx);
    float outB  = maskOutsideAt(uv, vec2( 0.0,  1.0), bezelWidthPx);
    float outTL = maskOutsideAt(uv, vec2(-D, -D), bezelWidthPx);
    float outTR = maskOutsideAt(uv, vec2( D, -D), bezelWidthPx);
    float outBL = maskOutsideAt(uv, vec2(-D,  D), bezelWidthPx);
    float outBR = maskOutsideAt(uv, vec2( D,  D), bezelWidthPx);

    float hitScore = outL + outR + outT + outB + outTL + outTR + outBL + outBR;
    if (hitScore < 0.5)
        return;

    // Oppose the directions that crossed transparency. This produces the
    // inward surface normal for straight edges and a diagonal at corners.
    vec2 inward = vec2(0.0);
    inward += vec2( 1.0,  0.0) * outL;
    inward += vec2(-1.0,  0.0) * outR;
    inward += vec2( 0.0,  1.0) * outT;
    inward += vec2( 0.0, -1.0) * outB;
    inward += vec2( D,  D) * outTL;
    inward += vec2(-D,  D) * outTR;
    inward += vec2( D, -D) * outBL;
    inward += vec2(-D, -D) * outBR;

    float inwardLength = length(inward);
"""
new_direction_field = r"""    // ii-vynx A/B: use a denser angular field for layer-mask normals.
    // Eight cardinal/diagonal probes visibly quantize semicircular floating
    // caps and create a kink where the straight edge transitions into the arc.
    // Sixteen evenly spaced probes halve that angular step while preserving the
    // same mask-derived geometry and single-ray distance refinement below.
    const int EDGE_DIRECTION_SAMPLES = 16;
    const float EDGE_TAU = 6.28318530718;
    float hitScore = 0.0;
    vec2 inward = vec2(0.0);

    for (int sampleIndex = 0; sampleIndex < EDGE_DIRECTION_SAMPLES; ++sampleIndex) {
        float angle = EDGE_TAU * (float(sampleIndex) / float(EDGE_DIRECTION_SAMPLES));
        vec2 outwardSample = vec2(cos(angle), sin(angle));
        float outside = maskOutsideAt(uv, outwardSample, bezelWidthPx);
        hitScore += outside;
        inward -= outwardSample * outside;
    }

    if (hitScore < 0.5)
        return;

    float inwardLength = length(inward);
"""

if old_direction_field not in text:
    raise SystemExit("HyprGlass smooth-normal A/B could not locate the 8-direction mask field")
text = text.replace(old_direction_field, new_direction_field, 1)
path.write_text(text, encoding="utf-8")
PY_MASK_NORMAL

    log "Enabled ii-vynx 16-direction mask-edge normal A/B."
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

source = source.replace(function_end, extra_functions + "'''\n", 1)

call = '''    call_marker + '    apply_mask_edge_refraction "$source_dir"\\n',
'''
replacement = '''    call_marker + '    apply_mask_edge_refraction "$source_dir"\\n    apply_mask_edge_normal_smoothing_ab "$source_dir"\\n    apply_mask_antialias_ab "$source_dir"\\n',
'''
if call not in source:
    raise SystemExit("Could not locate production mask-edge patch call")
source = source.replace(call, replacement, 1)

target.write_text(source, encoding="utf-8")
PY_WRAPPER

chmod +x "$TMP_BUILDER"
"$TMP_BUILDER" "$@"
