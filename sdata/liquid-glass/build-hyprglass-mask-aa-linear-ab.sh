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
new_aa = '''        // ii-vynx A/B: reconstruct the ultra-low-alpha bar contour with a
        // center-weighted isotropic ring. The neutral QML mask body is exactly
        // twice the configured 50% contour threshold, so normalize against that
        // full-mask alpha instead of saturating half-covered edge pixels.
        float safeMaskThreshold = max(maskAlphaThreshold, 0.000001);
        if (maskAlphaThreshold < 0.01) {
            vec2 maskTexSize = max(vec2(textureSize(maskTex, 0)), vec2(1.0));
            vec2 maskTexel = 1.0 / maskTexSize;
            vec2 aaRadius = maskTexel * 0.32;
            const float AA_DIAGONAL = 0.70710678;
            float maskRingAlpha = 0.125 * (
                texture(maskTex, clamp(maskUV + vec2( aaRadius.x, 0.0), 0.001, 0.999)).a +
                texture(maskTex, clamp(maskUV + vec2(-aaRadius.x, 0.0), 0.001, 0.999)).a +
                texture(maskTex, clamp(maskUV + vec2(0.0,  aaRadius.y), 0.001, 0.999)).a +
                texture(maskTex, clamp(maskUV + vec2(0.0, -aaRadius.y), 0.001, 0.999)).a +
                texture(maskTex, clamp(maskUV + vec2( aaRadius.x * AA_DIAGONAL,  aaRadius.y * AA_DIAGONAL), 0.001, 0.999)).a +
                texture(maskTex, clamp(maskUV + vec2(-aaRadius.x * AA_DIAGONAL,  aaRadius.y * AA_DIAGONAL), 0.001, 0.999)).a +
                texture(maskTex, clamp(maskUV + vec2( aaRadius.x * AA_DIAGONAL, -aaRadius.y * AA_DIAGONAL), 0.001, 0.999)).a +
                texture(maskTex, clamp(maskUV + vec2(-aaRadius.x * AA_DIAGONAL, -aaRadius.y * AA_DIAGONAL), 0.001, 0.999)).a
            );
            float maskAlphaAA = surfacePixel.a * 0.5 + maskRingAlpha * 0.5;
            float fullMaskAlpha = safeMaskThreshold * 2.0;
            maskCoverage = clamp(maskAlphaAA / fullMaskAlpha, 0.0, 1.0);
            if (maskCoverage <= 0.0001) discard;
        } else if (surfacePixel.a < safeMaskThreshold) {
            discard;
        }
'''
if old_aa not in source:
    raise SystemExit("Could not locate the derivative-based low-alpha mask AA block")
source = source.replace(old_aa, new_aa, 1)

target.write_text(source, encoding="utf-8")
PY_WRAPPER

chmod +x "$TMP_BUILDER"
"$TMP_BUILDER" "$@"
