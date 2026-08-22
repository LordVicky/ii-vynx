#!/usr/bin/env python3

from pathlib import Path
import sys


def patch_live_bar_refresh(source_dir: Path) -> None:
    path = source_dir / "src" / "GlassLayerSurface.cpp"
    text = path.read_text(encoding="utf-8")
    old = """    const bool backgroundChanged = !m_hasCachedSample ||
                                   currentGeneration != m_lastSceneGeneration ||
                                   isAnimating;
"""
    new = """    // ii-vynx: the upstream scene-generation cache does not track
    // per-frame window geometry or lower layer-surface content changes. Force
    // the horizontal shell bar surfaces to resample whenever Hyprland renders
    // them so moving windows and wallpaper parallax stay live in the glass.
    const bool forceLiveBarRefresh = layerSurface->m_namespace == \"quickshell:bar\" ||
                                     layerSurface->m_namespace == \"quickshell:bar-glass\";
    const bool backgroundChanged = forceLiveBarRefresh ||
                                   !m_hasCachedSample ||
                                   currentGeneration != m_lastSceneGeneration ||
                                   isAnimating;
"""
    if old not in text:
        raise SystemExit("HyprGlass live-bar patch no longer matches GlassLayerSurface.cpp")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def patch_mask_edges(source_dir: Path) -> None:
    path = source_dir / "src" / "Shaders.hpp"
    text = path.read_text(encoding="utf-8")

    sample_anchor = """vec4 sampleBlurred(vec2 wuv) {
    vec2 tuv = toTexUV(wuv);
    return texture(tex, clamp(tuv, 0.001, 0.999));
}

"""
    mask_helpers = r"""// ii-vynx: layer surfaces can contain transparent padding around the
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
    path.write_text(text.replace(old_edge, new_edge, 1), encoding="utf-8")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch-hyprglass-backend.py <hyprglass-source-dir>")

    source_dir = Path(sys.argv[1])
    if not source_dir.is_dir():
        raise SystemExit(f"HyprGlass source directory does not exist: {source_dir}")

    patch_live_bar_refresh(source_dir)
    patch_mask_edges(source_dir)
    print("Applied ii-vynx live-bar refresh and alpha-mask edge patches.")


if __name__ == "__main__":
    main()
