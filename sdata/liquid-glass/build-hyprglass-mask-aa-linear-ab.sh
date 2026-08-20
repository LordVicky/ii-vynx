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
source = source.replace(old, new, 1)

side_function_marker = """    log \"Enabled ii-vynx low-alpha bar mask antialias A/B.\"
}
'''
"""
side_function_replacement = """    log \"Enabled ii-vynx low-alpha bar mask antialias A/B.\"
}

apply_side_wall_reflection_ab() {
    local source_dir=\"$1\"
    local target=\"$source_dir/src/Shaders.hpp\"

    python3 - \"$target\" <<'PY_SIDE_REFLECTION'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding=\"utf-8\")

old_background = '''    if (chromaticAberration > 0.001 && edgeProximity > 0.01) {
        color.r = sampleBlurred(uvR).r;
        color.g = sampleBlurred(uvG).g;
        color.b = sampleBlurred(uvB).b;
    } else {
        color = sampleBlurred(uvG).rgb;
    }
'''
new_background = old_background + '''
    // ii-vynx A/B: rounded side walls need the same optical presence as the
    // horizontal rims. Pull a narrow sample from just outside the mask and mix
    // it only where the inferred mask normal faces mostly left/right. This
    // creates the reflected/refracted side pickup visible on thick curved glass
    // without changing the already-good top and bottom edge treatment.
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
'''

if old_background not in text:
    raise SystemExit(\"HyprGlass side-reflection A/B could not locate background sampling\")
path.write_text(text.replace(old_background, new_background, 1), encoding=\"utf-8\")
PY_SIDE_REFLECTION

    log \"Enabled ii-vynx rounded side-wall reflection A/B.\"
}
'''
"""
if side_function_marker not in source:
    raise SystemExit("Could not locate the mask-AA function end for side reflection")
source = source.replace(side_function_marker, side_function_replacement, 1)

# The AA builder stores its patch-call sequence inside a one-line Python string
# assignment. Parse that line instead of depending on a particular combination
# of escaped quotes/backslashes in the wrapper source.
lines = source.splitlines(keepends=True)
call_index = next((
    index for index, line in enumerate(lines)
    if line.startswith("replacement =") and 'apply_mask_antialias_ab "$source_dir"' in line
), -1)
if call_index < 0:
    raise SystemExit("Could not locate the mask-AA replacement line for side reflection")

escaped_newline = chr(92) * 2 + "n"
call_marker = f'    apply_mask_antialias_ab "$source_dir"{escaped_newline}'
side_call = f'    apply_side_wall_reflection_ab "$source_dir"{escaped_newline}'
if call_marker not in lines[call_index]:
    raise SystemExit("Could not locate the mask-AA call within its replacement line")
lines[call_index] = lines[call_index].replace(call_marker, call_marker + side_call, 1)
source = "".join(lines)

target.write_text(source, encoding="utf-8")
PY_WRAPPER

chmod +x "$TMP_BUILDER"
"$TMP_BUILDER" "$@"
