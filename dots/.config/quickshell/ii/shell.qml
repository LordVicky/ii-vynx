//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Remove two slashes below and adjust the value to change the UI scale
////@ pragma Env QT_SCALE_FACTOR=1

import "modules/common"
import "services"
import "panelFamilies"

import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root

    function applyAiPolicy() {
        // Policy mode changes are lifetime boundaries. Recreate even for
        // Yes <-> Local so remote-only objects cannot survive Local mode.
        const runtime = aiRuntimeLoader.item;
        RuntimeServices.ai = null;
        if (runtime)
            runtime.shutdown();
        aiRuntimeLoader.active = false;

        if (AiPolicy.enabled) {
            Qt.callLater(() => {
                if (AiPolicy.enabled)
                    aiRuntimeLoader.active = true;
            });
        }
    }

    // Stuff for every panel family
    ReloadPopup {}

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        Hyprsunset.load()
        FirstRunExperience.load()
        ConflictKiller.load()
        Cliphist.refresh()
        Wallpapers.load()
        Updates.load()
        root.applyAiPolicy()
    }


    // Optional AI runtime. The implementation object only exists while the
    // policy permits AI and is fully recreated on every policy-mode transition.
    LazyLoader {
        id: aiRuntimeLoader
        active: false
        component: PolicyAiRuntime {}
        onItemChanged: RuntimeServices.ai = item ?? null
    }

    // Keep the liquid-glass backend completely out of the Material lifetime.
    // Using a source URI avoids instantiating the runtime (and its Process)
    // until the user explicitly selects the liquid-glass surface style.
    LazyLoader {
        id: liquidGlassRuntimeLoader
        active: Config.ready && Config.options.appearance.surfaceStyle === "liquidGlass"
        source: "services/LiquidGlassRuntime.qml"
        onItemChanged: RuntimeServices.liquidGlass = item ?? null
    }

    Connections {
        target: AiPolicy
        function onModeChanged() { root.applyAiPolicy(); }
    }

    Component.onDestruction: {
        const runtime = aiRuntimeLoader.item;
        RuntimeServices.ai = null;
        RuntimeServices.liquidGlass = null;
        if (runtime)
            runtime.shutdown();
    }

    // Panel families
    property list<string> families: ["ii", "waffle"]
    function cyclePanelFamily() {
        const currentIndex = families.indexOf(Config.options.panelFamily)
        const nextIndex = (currentIndex + 1) % families.length
        Config.options.panelFamily = families[nextIndex]
    }

    component PanelFamilyLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready && Config.options.panelFamily === identifier && extraCondition
    }
    
    PanelFamilyLoader {
        identifier: "ii"
        component: IllogicalImpulseFamily {}
    }

    PanelFamilyLoader {
        identifier: "waffle"
        component: WaffleFamily {}
    }


    // Shortcuts
    IpcHandler {
        target: "panelFamily"

        function cycle(): void {
            root.cyclePanelFamily()
        }
    }

    GlobalShortcut {
        name: "panelFamilyCycle"
        description: "Cycles panel family"

        onPressed: root.cyclePanelFamily()
    }
}
