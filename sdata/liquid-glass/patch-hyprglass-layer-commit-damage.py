#!/usr/bin/env python3

from pathlib import Path
import sys


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch-hyprglass-layer-commit-damage.py <hyprglass-source-dir>")

    source_dir = Path(sys.argv[1])
    target = source_dir / "src" / "main.cpp"
    text = target.read_text(encoding="utf-8")

    hook_anchor = """using renderLayerFn = void (*)(Render::IHyprRenderer*, PHLLS, PHLMONITOR, const Time::steady_tp&, bool, bool);\n"""
    hook_block = """using renderLayerFn = void (*)(Render::IHyprRenderer*, PHLLS, PHLMONITOR, const Time::steady_tp&, bool, bool);\nusing layerCommitFn = void (*)(Desktop::View::CLayerSurface*);\n\nstatic CFunctionHook* g_layerCommitHook = nullptr;\n\nstatic void hkLayerCommit(Desktop::View::CLayerSurface* thisptr) {\n    ((layerCommitFn)g_layerCommitHook->m_original)(thisptr);\n\n    if (!g_pGlobalState || !thisptr)\n        return;\n\n    auto it = g_pGlobalState->layerSurfaces.find(thisptr);\n    if (it == g_pGlobalState->layerSurfaces.end() || !it->second)\n        return;\n\n    // ii-vynx: run geometry damage from the layer's actual Wayland commit.\n    // Calling this only from hkRenderLayer is circular: it cannot wake an idle\n    // compositor when a glass layer moves or resizes.\n    it->second->damageIfMoved();\n}\n"""

    if hook_anchor not in text:
        raise SystemExit("HyprGlass layer-commit hook anchor no longer matches main.cpp")
    text = text.replace(hook_anchor, hook_block, 1)

    init_anchor = """    HyprlandAPI::reloadConfig();\n"""
    init_block = """    // ii-vynx: wake the compositor as soon as a tracked glass layer commits\n    // new geometry instead of waiting for hkRenderLayer to run first.\n    auto layerCommitMatches = HyprlandAPI::findFunctionsByName(PHANDLE, \"onCommit\");\n    for (const auto& match : layerCommitMatches) {\n        if (match.demangled.contains(\"CLayerSurface::onCommit\")) {\n            g_layerCommitHook = HyprlandAPI::createFunctionHook(PHANDLE, match.address, (void*)hkLayerCommit);\n            if (g_layerCommitHook)\n                g_layerCommitHook->hook();\n            break;\n        }\n    }\n\n    if (!g_layerCommitHook) {\n        HyprlandAPI::addNotificationV2(PHANDLE, {\n            {\"text\", std::string(\"[hyprglass] Could not hook CLayerSurface::onCommit — dynamic layer damage disabled\")},\n            {\"time\", (uint64_t)5000},\n            {\"color\", CHyprColor{1.0, 0.8, 0.2, 1.0}},\n        });\n    }\n\n    HyprlandAPI::reloadConfig();\n"""

    if init_anchor not in text:
        raise SystemExit("HyprGlass layer-commit init anchor no longer matches main.cpp")
    text = text.replace(init_anchor, init_block, 1)

    target.write_text(text, encoding="utf-8")
    print("Enabled ii-vynx layer-commit damage wakeup.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
