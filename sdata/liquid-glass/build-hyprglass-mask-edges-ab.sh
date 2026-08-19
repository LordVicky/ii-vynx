#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_BUILDER="$SCRIPT_DIR/build-hyprglass-local.sh"
MASK_EDGE_REFRACTION="${HYPRGLASS_MASK_EDGE_REFRACTION:-1}"
TMP_BUILDER=""

cleanup() {
    if [ -n "${TMP_BUILDER:-}" ]; then
        rm -f -- "$TMP_BUILDER"
    fi
}
trap cleanup EXIT

case "$MASK_EDGE_REFRACTION" in
    0)
        exec "$BASE_BUILDER" "$@"
        ;;
    1) ;;
    *)
        printf '%s\n' "HYPRGLASS_MASK_EDGE_REFRACTION must be 0 or 1." >&2
        exit 5
        ;;
esac

TMP_BUILDER="$(mktemp "$SCRIPT_DIR/.build-hyprglass-mask-edges.XXXXXX")"

python3 - "$BASE_BUILDER" "$TMP_BUILDER" <<'PY_WRAPPER'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
target = Path(sys.argv[2])

function_marker = "\nprepare_lua_headers() {\n"
if function_marker not in source:
    raise SystemExit("Could not locate prepare_lua_headers() in the HyprGlass builder")

function_text = r'''
apply_mask_edge_refraction_ab() {
    local source_dir="$1"
    local target="$source_dir/src/Shaders.hpp"

    python3 - "$target" <<'PY_MASK'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

sample_anchor = """vec4 sampleBlurred(vec2 wuv) {
    vec2 tuv = toTexUV(wuv);
    return texture(tex, clamp(tuv, 0.001, 0.999));
}

"""
mask_helpers = r"""// ii-vynx A/B: layer surfaces can contain transparent padding around the
// actual visible glass shape. Derive the layer edge field from the captured
// alpha mask instead of assuming the whole layer-shell rectangle is glass.
float maskInsideAt(vec2 layerUV) {
    if (layerUV.x < 0.0 || layerUV.x > 1.0 || layerUV.y < 0.0 || layerUV.y > 1.0)
        return 0.0;

    vec2 maskUV = layerUV * maskUVScale + maskUVOffset;
    float maskAlpha = texture(maskTex, clamp(maskUV, 0.001, 0.999)).a;
    return maskAlpha >= max(maskAlphaThreshold, 0.000001) ? 1.0 : 0.0;
}

float maskOutsideAt(vec2 uv, vec2 direction, float distancePx) {
    vec2 pxToUV = vec2(
        distancePx / max(fullSize.x, 1.0),
        distancePx / max(fullSize.y, 1.0)
    );
    return 1.0 - maskInsideAt(uv + direction * pxToUV);
}

void getMaskEdgeField(vec2 uv, float bezelWidthPx, out float edgeProximity, out vec2 inwardDir) {
    edgeProximity = 0.0;
    inwardDir = vec2(0.0);
    if (bezelWidthPx <= 0.001)
        return;

    const float D = 0.70710678;

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
    if (inwardLength < 0.001)
        return;

    inwardDir = inward / inwardLength;
    vec2 outwardDir = -inwardDir;

    // Refine the distance to the alpha-mask boundary along the inferred normal.
    // Four binary steps give 1/16 of the configured bezel width without adding
    // another render pass or a CPU/GPU readback.
    float low = 0.0;
    float high = bezelWidthPx;
    if (maskOutsideAt(uv, outwardDir, high) < 0.5) {
        // Rare corner/concavity fallback: keep a conservative edge response
        // instead of inventing a direction from the layer rectangle.
        edgeProximity = 0.25;
        return;
    }

    float mid = (low + high) * 0.5;
    if (maskOutsideAt(uv, outwardDir, mid) > 0.5) high = mid; else low = mid;
    mid = (low + high) * 0.5;
    if (maskOutsideAt(uv, outwardDir, mid) > 0.5) high = mid; else low = mid;
    mid = (low + high) * 0.5;
    if (maskOutsideAt(uv, outwardDir, mid) > 0.5) high = mid; else low = mid;
    mid = (low + high) * 0.5;
    if (maskOutsideAt(uv, outwardDir, mid) > 0.5) high = mid; else low = mid;

    float normalizedDistance = clamp(high / bezelWidthPx, 0.0, 1.0);
    edgeProximity = 1.0 - smoothstep(0.0, 1.0, normalizedDistance);
}

"""

if sample_anchor not in text:
    raise SystemExit("HyprGlass mask-edge patch could not locate sampleBlurred()")
text = text.replace(sample_anchor, sample_anchor + mask_helpers, 1)

old_edge = """    float minDim = min(fullSize.x, fullSize.y);
    float bezelWidthPx = edgeThickness * minDim;

    // ========================================
    // EDGE PROXIMITY + DIRECTION
    // edgeProximity: 1.0 at boundary, exponential decay inward
    // inwardDir: pixel-space direction toward center (smooth everywhere)
    // ========================================
    float edgeProximity = exp(cornerSdf / bezelWidthPx);
    vec2 inwardDir = refractionDir(uv);
"""
new_edge = """    float minDim = min(fullSize.x, fullSize.y);
    float bezelWidthPx = max(edgeThickness * minDim, 0.001);

    // ========================================
    // EDGE PROXIMITY + DIRECTION
    // Windows use the native rounded-box field. Layer surfaces instead use
    // their captured alpha mask so transparent layer-shell padding does not
    // move the optical edge away from the visible bar/popup silhouette.
    // ========================================
    float edgeProximity = 0.0;
    vec2 inwardDir = vec2(0.0);
    if (edgeThickness > 0.0001) {
        if (hasMask) {
            getMaskEdgeField(uv, bezelWidthPx, edgeProximity, inwardDir);
        } else {
            edgeProximity = exp(cornerSdf / bezelWidthPx);
            inwardDir = refractionDir(uv);
        }
    }
"""

if old_edge not in text:
    raise SystemExit("HyprGlass mask-edge patch could not locate native edge field")
text = text.replace(old_edge, new_edge, 1)

path.write_text(text, encoding="utf-8")
PY_MASK

    log "Enabled ii-vynx alpha-mask edge refraction A/B."
}
'''

source = source.replace(function_marker, "\n" + function_text + function_marker, 1)

call_marker = '    apply_live_bar_refresh_ab "$source_dir"\n'
if call_marker not in source:
    raise SystemExit("Could not locate the live-refresh patch call in the HyprGlass builder")
source = source.replace(
    call_marker,
    call_marker + '    apply_mask_edge_refraction_ab "$source_dir"\n',
    1,
)

target.write_text(source, encoding="utf-8")
PY_WRAPPER

chmod +x "$TMP_BUILDER"
"$TMP_BUILDER" "$@"
