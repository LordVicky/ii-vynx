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


def patch_sidebar_close_snapshot(source_dir: Path) -> None:
    surface_target = source_dir / "src" / "GlassLayerSurface.cpp"
    surface_text = surface_target.read_text(encoding="utf-8")

    old_sample_guard = """    if (!layerSurface->m_mapped) {
        // During fade-out, re-sampling captures stale pixels. Reuse cached sample.
        if (!m_hasCachedSample)
            return;
    } else if (backgroundChanged) {
"""
    new_sample_guard = """    const bool renderingSnapshot = g_pHyprRenderer->m_bRenderingSnapshot;
    if (!layerSurface->m_mapped || renderingSnapshot) {
        // Closing layers are rendered into a blank snapshot framebuffer. Never
        // sample that target as the background; reuse the last real scene sample
        // so the glass material is baked into Hyprland's close snapshot.
        if (!m_hasCachedSample)
            return;
    } else if (backgroundChanged) {
"""

    if old_sample_guard not in surface_text:
        raise SystemExit("HyprGlass close-snapshot cache patch no longer matches GlassLayerSurface.cpp")

    surface_target.write_text(surface_text.replace(old_sample_guard, new_sample_guard, 1), encoding="utf-8")

    main_target = source_dir / "src" / "main.cpp"
    main_text = main_target.read_text(encoding="utf-8")

    old_close = """static void clearLayerGlassOnClose(PHLLS layerSurface) {
    if (!g_pGlobalState || !layerSurface)
        return;

    // Drop cached layer glass immediately. Otherwise the previous glass output
    // can remain in the damage history while Hyprland switches to its close
    // snapshot path, showing stale/black pixels for a frame.
    std::erase_if(g_pGlobalState->layerSurfaces, [&](const auto& pair) {
        return pair.first == layerSurface.get() || pair.second->getLayerSurface() == layerSurface;
    });

    if (auto monitor = layerSurface->m_monitor.lock())
        g_pHyprRenderer->damageMonitor(monitor);
}
"""
    new_close = """static void clearLayerGlassOnClose(PHLLS layerSurface) {
    if (!g_pGlobalState || !layerSurface)
        return;

    const auto& ns = layerSurface->m_namespace;
    const bool preserveForCloseSnapshot = ns == \"quickshell:sidebar-dashboard-glass\" ||
                                          ns == \"quickshell:sidebar-policies-glass-left\" ||
                                          ns == \"quickshell:sidebar-policies-glass-right\";

    // Hyprland emits layer.closed immediately before it captures the close
    // snapshot. Keep dedicated sidebar glass state alive through that synchronous
    // capture so the snapshot can reuse the last valid background sample. Other
    // layer namespaces retain upstream's immediate cleanup behavior.
    if (!preserveForCloseSnapshot) {
        std::erase_if(g_pGlobalState->layerSurfaces, [&](const auto& pair) {
            return pair.first == layerSurface.get() || pair.second->getLayerSurface() == layerSurface;
        });
    }

    if (auto monitor = layerSurface->m_monitor.lock())
        g_pHyprRenderer->damageMonitor(monitor);
}
"""

    if old_close not in main_text:
        raise SystemExit("HyprGlass close-snapshot lifecycle patch no longer matches main.cpp")
    main_text = main_text.replace(old_close, new_close, 1)

    old_snapshot_bypass = """    // Hyprland renders closing layers from snapshots. Do not inject the glass
    // pipeline while that snapshot is being captured: the snapshot framebuffer
    // starts transparent/black, so sampling it as a background can bake a black
    // rectangle into the fade-out snapshot.
    if (g_pHyprRenderer->m_bRenderingSnapshot) {
        ((renderLayerFn)g_pGlobalState->renderLayerHook->m_original)(thisptr, layerSurface, monitor, now, popups, lockscreen);
        return;
    }

"""
    new_snapshot_bypass = """    // Most HyprGlass layers keep upstream's snapshot bypass. Dedicated sidebar
    // glass is different: its cached scene sample is preserved on close, so it
    // can be composited into Hyprland's snapshot without sampling the blank
    // snapshot framebuffer itself.
    if (g_pHyprRenderer->m_bRenderingSnapshot) {
        const auto& ns = layerSurface->m_namespace;
        const bool preserveSidebarGlass = ns == \"quickshell:sidebar-dashboard-glass\" ||
                                          ns == \"quickshell:sidebar-policies-glass-left\" ||
                                          ns == \"quickshell:sidebar-policies-glass-right\";
        if (!preserveSidebarGlass) {
            ((renderLayerFn)g_pGlobalState->renderLayerHook->m_original)(thisptr, layerSurface, monitor, now, popups, lockscreen);
            return;
        }
    }

"""

    if old_snapshot_bypass not in main_text:
        raise SystemExit("HyprGlass close-snapshot render patch no longer matches main.cpp")

    main_target.write_text(main_text.replace(old_snapshot_bypass, new_snapshot_bypass, 1), encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch-hyprglass-layer-damage.py <hyprglass-source-dir>")

    source_dir = Path(sys.argv[1])
    if not source_dir.is_dir():
        raise SystemExit(f"HyprGlass source directory does not exist: {source_dir}")

    patch_previous_layer_damage(source_dir)
    patch_live_policy_namespaces(source_dir)
    patch_live_sidebar_damage(source_dir)
    patch_sidebar_close_snapshot(source_dir)

    print("Enabled ii-vynx layer damage, live sidebar invalidation, and close-snapshot fixes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
