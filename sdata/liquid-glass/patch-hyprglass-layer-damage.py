#!/usr/bin/env python3

from pathlib import Path
import subprocess
import sys


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch-hyprglass-layer-damage.py <hyprglass-source-dir>")

    source_dir = Path(sys.argv[1])
    target = source_dir / "src" / "GlassLayerSurface.cpp"
    text = target.read_text(encoding="utf-8")

    old = """    if (moved || isAnimating) {
        m_lastPosition  = currentPosition;
        m_lastSize      = currentSize;

        auto box = CBox{currentPosition, currentSize};
        const auto monitor = layerSurface->m_monitor.lock();
        const float scale = monitor ? monitor->m_scale : 1.0f;
        box.expand(GlassRenderer::SAMPLE_PADDING_PX / scale).noNegativeSize();
        if (box.w > 0.0 && box.h > 0.0)
            g_pHyprRenderer->damageBox(box);

        if (monitor)
            g_pGlobalState->bumpSceneGeneration(monitor);
    }
"""

    new = """    if (moved || isAnimating) {
        const auto monitor = layerSurface->m_monitor.lock();
        const float scale = monitor ? monitor->m_scale : 1.0f;
        const float padding = GlassRenderer::SAMPLE_PADDING_PX / scale;

        // ii-vynx: damage the area the layer just vacated before replacing
        // the stored geometry. Upstream only damages the new box, so moving or
        // resizing glass layers can leave stale glass pixels on an idle scene.
        if (moved && m_lastSize.x > 0.0 && m_lastSize.y > 0.0 &&
            std::isfinite(m_lastPosition.x) && std::isfinite(m_lastPosition.y) &&
            std::isfinite(m_lastSize.x) && std::isfinite(m_lastSize.y)) {
            auto previousBox = CBox{m_lastPosition, m_lastSize};
            previousBox.expand(padding).noNegativeSize();
            if (previousBox.w > 0.0 && previousBox.h > 0.0)
                g_pHyprRenderer->damageBox(previousBox);
        }

        m_lastPosition  = currentPosition;
        m_lastSize      = currentSize;

        auto box = CBox{currentPosition, currentSize};
        box.expand(padding).noNegativeSize();
        if (box.w > 0.0 && box.h > 0.0)
            g_pHyprRenderer->damageBox(box);

        if (monitor)
            g_pGlobalState->bumpSceneGeneration(monitor);
    }
"""

    if old not in text:
        raise SystemExit("HyprGlass layer-move damage patch no longer matches GlassLayerSurface.cpp")

    target.write_text(text.replace(old, new, 1), encoding="utf-8")

    commit_patch = Path(__file__).with_name("patch-hyprglass-layer-commit-damage.py")
    subprocess.run([sys.executable, str(commit_patch), str(source_dir)], check=True)

    print("Enabled ii-vynx previous-layer damage fix.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
