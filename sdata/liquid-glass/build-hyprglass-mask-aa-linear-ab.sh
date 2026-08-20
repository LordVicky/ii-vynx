#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_BUILDER="$SCRIPT_DIR/build-hyprglass-mask-aa-ab.sh"
TMP_BUILDER=""

cleanup() {
    if [ -n "${TMP_BUILDER:-}" ]; then
        rm -f -- "$TMP_BUILDER"
    fi
}
trap cleanup EXIT

TMP_BUILDER="$(mktemp "$SCRIPT_DIR/.build-hyprglass-mask-aa-linear.XXXXXX")"

python3 - "$BASE_BUILDER" "$TMP_BUILDER" <<'PY_WRAPPER'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
target = Path(sys.argv[2])

old_sample = '''        surfacePixel = texture(maskTex, clamp(maskUV, 0.001, 0.999));

        // ii-vynx A/B: preserve Qt's fractional coverage only for the shell's
'''
new_sample = '''        surfacePixel = texture(maskTex, clamp(maskUV, 0.001, 0.999));

        // ii-vynx A/B: supersample only the mask alpha used for coverage. The
        // center surfacePixel remains untouched for compositing, so this smooths
        // the silhouette without softening icons/text or changing the glass body.
        vec2 maskTexSize = max(vec2(textureSize(maskTex, 0)), vec2(1.0));
        vec2 maskTexel = 1.0 / maskTexSize;
        vec2 aaOffset = maskTexel * 0.35;
        float maskAlphaAA = 0.25 * (
            texture(maskTex, clamp(maskUV + vec2(-aaOffset.x, -aaOffset.y), 0.001, 0.999)).a +
            texture(maskTex, clamp(maskUV + vec2( aaOffset.x, -aaOffset.y), 0.001, 0.999)).a +
            texture(maskTex, clamp(maskUV + vec2(-aaOffset.x,  aaOffset.y), 0.001, 0.999)).a +
            texture(maskTex, clamp(maskUV + vec2( aaOffset.x,  aaOffset.y), 0.001, 0.999)).a
        );

        // ii-vynx A/B: preserve Qt's fractional coverage only for the shell's
'''
if old_sample not in source:
    raise SystemExit("Could not locate the low-alpha mask sample block")
source = source.replace(old_sample, new_sample, 1)

old_aa = '''        // ii-vynx A/B: preserve Qt's fractional coverage only for the shell's
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
'''
new_aa = '''        // ii-vynx A/B: reconstruct low-alpha bar coverage from a four-tap
        // alpha average. Fully transparent samples stay empty, while partially
        // covered rounded-edge texels blend smoothly into the 0.25% contour.
        float safeMaskThreshold = max(maskAlphaThreshold, 0.000001);
        if (maskAlphaThreshold < 0.01) {
            maskCoverage = clamp(maskAlphaAA / safeMaskThreshold, 0.0, 1.0);
            if (maskCoverage <= 0.0001) discard;
        } else if (surfacePixel.a < safeMaskThreshold) {
            discard;
        }
'''
if old_aa not in source:
    raise SystemExit("Could not locate the derivative-based low-alpha mask AA block")
source = source.replace(old_aa, new_aa, 1)

# Keep the side-wall experiment in the existing PY_MASK_AA patch pass instead
# of injecting a second shell function into the parent's raw triple-quoted
# string. Triple-double GLSL strings are safe inside that parent raw string.
write_marker = '''text = text.replace(old_glass_alpha, new_glass_alpha, 1)

path.write_text(text, encoding="utf-8")
PY_MASK_AA
'''
side_patch = r'''text = text.replace(old_glass_alpha, new_glass_alpha, 1)

old_background = """    if (chromaticAberration > 0.001 && edgeProximity > 0.01) {
        color.r = sampleBlurred(uvR).r;
        color.g = sampleBlurred(uvG).g;
        color.b = sampleBlurred(uvB).b;
    } else {
        color = sampleBlurred(uvG).rgb;
    }
"""
new_background = old_background + """
    // ii-vynx A/B: rounded side walls need the same optical presence as the
    // horizontal rims. Pull a narrow sample from just outside the mask and mix
    // it only where the inferred mask normal faces mostly left/right.
    if (hasMask && refractionStrength > 0.001 && edgeProximity > 0.01) {
        float sideFacing = smoothstep(0.45, 0.90, abs(inwardDir.x));
        float sideBand = sideFacing * edgeProximity * edgeProximity;
        if (sideBand > 0.001) {
            float sidePickupPx = refractionPx * 0.60;
            vec2 sidePickupUV = uv - inwardDir * sidePickupPx / fullSize;
            vec3 sidePickup = sampleBlurred(sidePickupUV).rgb;
            float sideMix = clamp(sideBand * refractionStrength * 0.42, 0.0, 0.34);
            color = mix(color, sidePickup, sideMix);
        }
    }
"""
if old_background not in text:
    raise SystemExit("HyprGlass side-reflection A/B could not locate background sampling")
text = text.replace(old_background, new_background, 1)

path.write_text(text, encoding="utf-8")
PY_MASK_AA
'''
if write_marker not in source:
    raise SystemExit("Could not locate the mask-AA write stage for side reflection")
source = source.replace(write_marker, side_patch, 1)

target.write_text(source, encoding="utf-8")
PY_WRAPPER

chmod +x "$TMP_BUILDER"
"$TMP_BUILDER" "$@"
