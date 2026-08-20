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
new = '''        // ii-vynx A/B: reconstruct low-alpha bar coverage directly from the
        // sampled mask. Screen-space derivatives can become wider than the
        // 0.25% contour around a tangent and create glass in fully transparent
        // texels. Linear sub-threshold coverage keeps alpha=0 exactly empty,
        // preserves the validated 50% optical contour, and leaves accepted
        // interior pixels at full glass strength.
        float safeMaskThreshold = max(maskAlphaThreshold, 0.000001);
        if (maskAlphaThreshold < 0.01) {
            maskCoverage = clamp(surfacePixel.a / safeMaskThreshold, 0.0, 1.0);
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
