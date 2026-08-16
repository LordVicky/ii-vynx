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
        if (aiRuntimeLoader.item)
            aiRuntimeLoader.item.shutdown();
        aiRuntimeLoader.active = false;
        RuntimeServices.ai = null;

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
        component: AiRuntime {}
        onItemChanged: RuntimeServices.ai = item ?? null
    }

    Connections {
        target: AiPolicy
        function onModeChanged() { root.applyAiPolicy(); }
    }

    Component.onDestruction: {
        if (aiRuntimeLoader.item)
            aiRuntimeLoader.item.shutdown();
        RuntimeServices.ai = null;
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

