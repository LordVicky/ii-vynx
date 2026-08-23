#!/usr/bin/env python3

from pathlib import Path
import sys


SIGNATURE = "II_VYNX_CONTROL_MASK_PROTO_V1"


def patch_control_mask_shader(source_dir: Path) -> None:
    path = source_dir / "src" / "Shaders.hpp"
    text = path.read_text(encoding="utf-8")

    if SIGNATURE in text:
        return

    sample_anchor = """vec4 sampleBlurred(vec2 wuv) {
    vec2 tuv = toTexUV(wuv);
    return texture(tex, clamp(tuv, 0.001, 0.999));
}

"""
    helpers = r"""// II_VYNX_CONTROL_MASK_PROTO_V1
// Prototype: pixels deliberately rendered with high alpha inside the existing
// sidebar glass layer form a secondary control mask. This derives a narrow
// local edge field from that mask without creating one layer surface per control.
const float II_VYNX_CONTROL_MARKER_ALPHA = 0.72;

float iiVynxControlMaskInsideAt(vec2 layerUV) {
    if (layerUV.x < 0.0 || layerUV.x > 1.0 || layerUV.y < 0.0 || layerUV.y > 1.0)
        return 0.0;

    vec2 markerUV = layerUV * maskUVScale + maskUVOffset;
    float markerAlpha = texture(maskTex, clamp(markerUV, 0.001, 0.999)).a;
    return markerAlpha >= II_VYNX_CONTROL_MARKER_ALPHA ? 1.0 : 0.0;
}

float iiVynxControlMaskOutsideAt(vec2 uv, vec2 direction, float distancePx) {
    vec2 pxToUV = vec2(
        distancePx / max(fullSize.x, 1.0),
        distancePx / max(fullSize.y, 1.0)
    );
    return 1.0 - iiVynxControlMaskInsideAt(uv + direction * pxToUV);
}

void iiVynxGetControlEdgeField(vec2 uv, float bezelWidthPx,
                               out float edgeProximity, out vec2 inwardDir) {
    edgeProximity = 0.0;
    inwardDir = vec2(0.0);

    if (bezelWidthPx <= 0.001 || iiVynxControlMaskInsideAt(uv) < 0.5)
        return;

    // Four cardinal probes are the cheap rejection path. Deep control-interior
    // pixels stop after these four texture reads; only the narrow edge band pays
    // for the binary refinement below.
    float outL = iiVynxControlMaskOutsideAt(uv, vec2(-1.0,  0.0), bezelWidthPx);
    float outR = iiVynxControlMaskOutsideAt(uv, vec2( 1.0,  0.0), bezelWidthPx);
    float outT = iiVynxControlMaskOutsideAt(uv, vec2( 0.0, -1.0), bezelWidthPx);
    float outB = iiVynxControlMaskOutsideAt(uv, vec2( 0.0,  1.0), bezelWidthPx);

    float hitScore = outL + outR + outT + outB;
    if (hitScore < 0.5)
        return;

    vec2 inward = vec2(outL - outR, outT - outB);
    float inwardLength = length(inward);
    if (inwardLength < 0.001)
        return;

    inwardDir = inward / inwardLength;
    vec2 outwardDir = -inwardDir;

    // Three fixed binary steps are enough for an ~8 px optical band and keep the
    // prototype substantially cheaper than a distance transform or extra pass.
    float low = 0.0;
    float high = bezelWidthPx;
    if (iiVynxControlMaskOutsideAt(uv, outwardDir, high) < 0.5) {
        edgeProximity = 0.20;
        return;
    }

    float mid = (low + high) * 0.5;
    if (iiVynxControlMaskOutsideAt(uv, outwardDir, mid) > 0.5) high = mid; else low = mid;
    mid = (low + high) * 0.5;
    if (iiVynxControlMaskOutsideAt(uv, outwardDir, mid) > 0.5) high = mid; else low = mid;
    mid = (low + high) * 0.5;
    if (iiVynxControlMaskOutsideAt(uv, outwardDir, mid) > 0.5) high = mid; else low = mid;

    float normalizedDistance = clamp(high / bezelWidthPx, 0.0, 1.0);
    edgeProximity = 1.0 - smoothstep(0.0, 1.0, normalizedDistance);
}

"""

    if sample_anchor not in text:
        raise SystemExit("control-mask prototype could not locate sampleBlurred() in Shaders.hpp")
    text = text.replace(sample_anchor, sample_anchor + helpers, 1)

    sample_mask_anchor = """    if (hasMask) {
        vec2 maskUV = uv * maskUVScale + maskUVOffset;
        surfacePixel = texture(maskTex, clamp(maskUV, 0.001, 0.999));
        if (surfacePixel.a < maskAlphaThreshold) discard;
    }

"""
    sample_mask_replacement = sample_mask_anchor + """    // The dedicated sidebar surface keeps its ordinary low-alpha pane mask.
    // High-alpha regions are marker-only control silhouettes used for local
    // refraction; they are removed from the final surface composite below.
    bool iiVynxControlMarker = hasMask && surfacePixel.a >= II_VYNX_CONTROL_MARKER_ALPHA;

"""
    if sample_mask_anchor not in text:
        raise SystemExit("control-mask prototype could not locate layer mask sampling in Shaders.hpp")
    text = text.replace(sample_mask_anchor, sample_mask_replacement, 1)

    offset_anchor = """    float refractionPx = refractionStrength * 50.0;
    float refractionMag = edgeProximity * refractionPx;
    vec2 baseOffset = inwardDir * refractionMag / fullSize;
"""
    offset_replacement = offset_anchor + """

    // Prototype local control lens. It deliberately has no chromatic split: the
    // purpose is to test geometric edge refraction, not add decorative fringing.
    float iiVynxControlEdge = 0.0;
    vec2 iiVynxControlInward = vec2(0.0);
    if (iiVynxControlMarker)
        iiVynxGetControlEdgeField(uv, 8.0, iiVynxControlEdge, iiVynxControlInward);

    float iiVynxControlRefractionPx = 5.0 * iiVynxControlEdge;
    vec2 iiVynxControlOffset = iiVynxControlInward * iiVynxControlRefractionPx / fullSize;
    baseOffset += iiVynxControlOffset;
"""
    if offset_anchor not in text:
        raise SystemExit("control-mask prototype could not locate refraction offset in Shaders.hpp")
    text = text.replace(offset_anchor, offset_replacement, 1)

    specular_anchor = """    if (specularStrength > 0.001) {
        float topBias = pow(max(1.0 - uv.y, 0.0), 2.0);
        float spec = topBias * edgeProximity * edgeProximity * specularStrength * 0.08;
        color += vec3(1.0, 0.99, 0.97) * spec;
    }

"""
    local_rim = specular_anchor + """    // Local control boundary: a restrained Fresnel lift plus a directional
    // top-facing glint. The actual backdrop displacement above does the visual
    // work; this only makes the lens boundary readable on low-contrast wallpaper.
    if (iiVynxControlEdge > 0.001) {
        float localFresnel = iiVynxControlEdge * iiVynxControlEdge * 0.07;
        float topFacing = max(iiVynxControlInward.y, 0.0);
        float localSpec = topFacing * iiVynxControlEdge * iiVynxControlEdge * 0.04;
        color += vec3(1.0) * localFresnel;
        color += vec3(1.0, 0.99, 0.97) * localSpec;
    }

"""
    if specular_anchor not in text:
        raise SystemExit("control-mask prototype could not locate specular block in Shaders.hpp")
    text = text.replace(specular_anchor, local_rim, 1)

    composite_anchor = """    if (hasMask) {
        // Layers only: composite the rendered surface over the glass effect
        // in a single pass. surfacePixel is premultiplied alpha from Hyprland's
        // surface rendering, so we unpremultiply before the 'over' blend.
        float surfA = surfacePixel.a;
"""
    composite_replacement = """    if (hasMask) {
        // Marker pixels exist only to carry the internal control mask. Do not
        // paint the marker itself over the glass; the real interactive control
        // remains in the separate foreground sidebar window.
        if (iiVynxControlMarker)
            surfacePixel = vec4(0.0);

        // Layers only: composite the rendered surface over the glass effect
        // in a single pass. surfacePixel is premultiplied alpha from Hyprland's
        // surface rendering, so we unpremultiply before the 'over' blend.
        float surfA = surfacePixel.a;
"""
    if composite_anchor not in text:
        raise SystemExit("control-mask prototype could not locate layer composite block in Shaders.hpp")
    text = text.replace(composite_anchor, composite_replacement, 1)

    path.write_text(text, encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch-hyprglass-control-mask-prototype.py <hyprglass-source-dir>")

    source_dir = Path(sys.argv[1])
    if not source_dir.is_dir():
        raise SystemExit(f"HyprGlass source directory does not exist: {source_dir}")

    patch_control_mask_shader(source_dir)
    print("Enabled ii-vynx internal control-mask refraction prototype.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
