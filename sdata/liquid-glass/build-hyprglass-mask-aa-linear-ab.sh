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

old = '''        // ii-vynx A/B: preserve Qt's fractional coverage only for the shell's
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
new = '''        // ii-vynx A/B: reconstruct low-alpha bar coverage from a four-tap
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

if old not in source:
    raise SystemExit("Could not locate the derivative-based low-alpha mask AA block")

target.write_text(source.replace(old, new, 1), encoding="utf-8")
PY_WRAPPER

chmod +x "$TMP_BUILDER"
"$TMP_BUILDER" "$@"
