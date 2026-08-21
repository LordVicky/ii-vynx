#!/usr/bin/env python3

from pathlib import Path
import sys


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch-hyprglass-layer-commit-damage.py <hyprglass-source-dir>")

    source_dir = Path(sys.argv[1])
    target = source_dir / "src" / "main.cpp"
    text = target.read_text(encoding="utf-8")

    include_anchor = """#include <cstdlib>\n#include <sstream>\n"""
    include_block = """#include <cstdlib>\n#include <fstream>\n#include <sstream>\n"""
    if include_anchor not in text:
        raise SystemExit("HyprGlass layer-commit include anchor no longer matches main.cpp")
    text = text.replace(include_anchor, include_block, 1)

    hook_anchor = """using renderLayerFn = void (*)(Render::IHyprRenderer*, PHLLS, PHLMONITOR, const Time::steady_tp&, bool, bool);\n"""
    hook_block = """using renderLayerFn = void (*)(Render::IHyprRenderer*, PHLLS, PHLMONITOR, const Time::steady_tp&, bool, bool);\nusing layerCommitFn = void (*)(Desktop::View::CLayerSurface*);\n\nstatic CFunctionHook* g_layerCommitHook = nullptr;\nstatic bool g_layerCommitHookActive = false;\n\nstatic void traceLayerCommit(const std::string& line, bool truncate = false) {\n    std::ofstream trace(\"/tmp/ii-vynx-hyprglass-hook.log\",\n        truncate ? std::ios::trunc : std::ios::app);\n    if (trace)\n        trace << line << '\\n';\n}\n\nstatic void hkLayerCommit(Desktop::View::CLayerSurface* thisptr) {\n    ((layerCommitFn)g_layerCommitHook->m_original)(thisptr);\n\n    if (!thisptr)\n        return;\n\n    const bool traceBarGlass = thisptr->m_namespace == \"quickshell:bar-glass\";\n    if (!g_pGlobalState) {\n        if (traceBarGlass)\n            traceLayerCommit(\"commit global-state-missing\");\n        return;\n    }\n\n    auto it = g_pGlobalState->layerSurfaces.find(thisptr);\n    const bool tracked = it != g_pGlobalState->layerSurfaces.end() && it->second;\n\n    if (traceBarGlass) {\n        const auto position = thisptr->position(Desktop::View::IGeometric::GEOMETRIC_CURRENT);\n        const auto size = thisptr->size(Desktop::View::IGeometric::GEOMETRIC_CURRENT);\n        const auto bufferSize = thisptr->m_layerSurface && thisptr->m_layerSurface->m_surface\n            ? thisptr->m_layerSurface->m_surface->m_current.size\n            : Vector2D{};\n        std::ostringstream line;\n        line << \"commit tracked=\" << tracked\n             << \" x=\" << position.x << \" y=\" << position.y\n             << \" w=\" << size.x << \" h=\" << size.y\n             << \" bufferW=\" << bufferSize.x << \" bufferH=\" << bufferSize.y;\n        traceLayerCommit(line.str());\n    }\n\n    if (!tracked)\n        return;\n\n    // ii-vynx: run geometry damage from the layer's actual Wayland commit.\n    // Calling this only from hkRenderLayer is circular: it cannot wake an idle\n    // compositor when a glass layer moves or resizes.\n    if (traceBarGlass)\n        traceLayerCommit(\"commit damage-if-moved\");\n    it->second->damageIfMoved();\n}\n"""

    if hook_anchor not in text:
        raise SystemExit("HyprGlass layer-commit hook anchor no longer matches main.cpp")
    text = text.replace(hook_anchor, hook_block, 1)

    init_anchor = """    HyprlandAPI::reloadConfig();\n"""
    init_block = """    // ii-vynx: wake the compositor as soon as a tracked glass layer commits\n    // new geometry instead of waiting for hkRenderLayer to run first.\n    auto layerCommitMatches = HyprlandAPI::findFunctionsByName(PHANDLE, \"onCommit\");\n    {\n        std::ostringstream line;\n        line << \"init matches=\" << layerCommitMatches.size();\n        traceLayerCommit(line.str(), true);\n    }\n    for (const auto& match : layerCommitMatches) {\n        if (match.demangled.contains(\"CLayerSurface::onCommit\")) {\n            traceLayerCommit(std::string(\"candidate \" ) + match.demangled);\n            g_layerCommitHook = HyprlandAPI::createFunctionHook(PHANDLE, match.address, (void*)hkLayerCommit);\n            if (g_layerCommitHook)\n                g_layerCommitHookActive = g_layerCommitHook->hook();\n            traceLayerCommit(std::string(\"hook created=\") + (g_layerCommitHook ? \"1\" : \"0\") +\n                             \" active=\" + (g_layerCommitHookActive ? \"1\" : \"0\"));\n            break;\n        }\n    }\n\n    if (!g_layerCommitHook || !g_layerCommitHookActive) {\n        HyprlandAPI::addNotificationV2(PHANDLE, {\n            {\"text\", std::string(\"[hyprglass] Could not hook CLayerSurface::onCommit — dynamic layer damage disabled\")},\n            {\"time\", (uint64_t)5000},\n            {\"color\", CHyprColor{1.0, 0.8, 0.2, 1.0}},\n        });\n    }\n\n    HyprlandAPI::reloadConfig();\n"""

    if init_anchor not in text:
        raise SystemExit("HyprGlass layer-commit init anchor no longer matches main.cpp")
    text = text.replace(init_anchor, init_block, 1)

    target.write_text(text, encoding="utf-8")
    print("Enabled ii-vynx layer-commit damage wakeup.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
