#!/usr/bin/env python3

from pathlib import Path
import sys


def patch_previous_layer_damage(source_dir: Path) -> None:
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


def patch_live_policy_namespaces(source_dir: Path) -> None:
    target = source_dir / "src" / "GlassLayerSurface.cpp"
    text = target.read_text(encoding="utf-8")

    old = """    const bool forceLiveSurfaceRefresh = layerSurface->m_namespace == \"quickshell:bar\" ||
                                         layerSurface->m_namespace == \"quickshell:bar-glass\" ||
                                         layerSurface->m_namespace == \"quickshell:sidebar-dashboard-glass\";
"""
    new = """    const bool forceLiveSurfaceRefresh = layerSurface->m_namespace == \"quickshell:bar\" ||
                                         layerSurface->m_namespace == \"quickshell:bar-glass\" ||
                                         layerSurface->m_namespace == \"quickshell:sidebar-dashboard-glass\" ||
                                         layerSurface->m_namespace == \"quickshell:sidebar-policies-glass-left\" ||
                                         layerSurface->m_namespace == \"quickshell:sidebar-policies-glass-right\";
"""

    if old not in text:
        raise SystemExit("HyprGlass live-surface namespace patch no longer matches GlassLayerSurface.cpp")

    target.write_text(text.replace(old, new, 1), encoding="utf-8")


def patch_live_sidebar_damage(source_dir: Path) -> None:
    target = source_dir / "src" / "main.cpp"
    text = target.read_text(encoding="utf-8")

    anchor = """    static auto onWorkspaceActive = Event::bus()->m_events.workspace.active.listen(
        [&](PHLWORKSPACE ws) {
            if (ws) if (auto mon = ws->m_monitor.lock()) g_pGlobalState->bumpSceneGeneration(mon);
        });

"""
    replacement = anchor + """    // ii-vynx: HyprGlass's layer cache can only resample a sidebar once the
    // sidebar participates in the current render damage. Ordinary window motion
    // behind an unchanged layer may otherwise be occluded from that layer, so a
    // workspace switch refreshes it while dragging a window does not. If this
    // monitor already has a real frame to render, extend that frame's damage to
    // the dedicated sidebar glass bounds. This does not schedule idle frames and
    // deliberately leaves the already-live bar path unchanged.
    static auto onRenderPre = Event::bus()->m_events.render.pre.listen([&](PHLMONITOR monitor) {
        if (!monitor || !g_pHyprRenderer->shouldRenderMonitor(monitor))
            return;

        bool damagedLiveSidebar = false;
        for (const auto& [_, state] : g_pGlobalState->layerSurfaces) {
            if (!state)
                continue;

            const auto layerSurface = state->getLayerSurface();
            if (!layerSurface || !layerSurface->m_mapped || layerSurface->m_monitor.lock() != monitor)
                continue;

            const auto& ns = layerSurface->m_namespace;
            if (ns != \"quickshell:sidebar-dashboard-glass\" &&
                ns != \"quickshell:sidebar-policies-glass-left\" &&
                ns != \"quickshell:sidebar-policies-glass-right\")
                continue;

            const auto currentPosition = layerSurface->position(Desktop::View::IGeometric::GEOMETRIC_CURRENT);
            const auto currentSize = layerSurface->size(Desktop::View::IGeometric::GEOMETRIC_CURRENT);
            if (currentSize.x <= 0.0 || currentSize.y <= 0.0)
                continue;

            auto box = CBox{currentPosition, currentSize};
            box.expand(GlassRenderer::SAMPLE_PADDING_PX).noNegativeSize();
            if (box.w <= 0.0 || box.h <= 0.0)
                continue;

            g_pHyprRenderer->damageBox(box);
            damagedLiveSidebar = true;
        }

        if (damagedLiveSidebar)
            g_pGlobalState->bumpSceneGeneration(monitor);
    });

"""

    if anchor not in text:
        raise SystemExit("HyprGlass live-sidebar damage patch could not locate workspace invalidation hook")

    target.write_text(text.replace(anchor, replacement, 1), encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch-hyprglass-layer-damage.py <hyprglass-source-dir>")

    source_dir = Path(sys.argv[1])
    if not source_dir.is_dir():
        raise SystemExit(f"HyprGlass source directory does not exist: {source_dir}")

    patch_previous_layer_damage(source_dir)
    patch_live_policy_namespaces(source_dir)
    patch_live_sidebar_damage(source_dir)

    print("Enabled ii-vynx layer damage and live sidebar invalidation fixes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
