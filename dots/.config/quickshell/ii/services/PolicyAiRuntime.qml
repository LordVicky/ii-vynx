import QtQuick
import qs.modules.common

// Runtime instance with policy-safe effective bindings. In Local-only mode the
// persisted online provider is preserved, while the live runtime falls back to
// the first model actually discovered from Ollama.
AiRuntime {
    id: root

    currentModelId: {
        const persistedProvider = Persistent.states?.ai?.provider ?? "";
        if (root.models[persistedProvider])
            return persistedProvider;
        return root.modelList[0] ?? "";
    }

    availableTools: {
        const apiFormat = root.models[root.currentModelId]?.api_format || "openai";
        return Object.keys(root.tools[apiFormat] ?? {});
    }

    readonly property bool modelReady: !!root.models[root.currentModelId]
}
