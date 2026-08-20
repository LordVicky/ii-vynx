import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common

Scope {
    id: root

    readonly property bool surfaceReady: GlobalStates.barOpen
        && !GlobalStates.screenLocked
        && Config.options.appearance.surfaceStyle === "liquidGlass"
        && RuntimeServices.liquidGlass?.ready === true
        && RuntimeServices.liquidGlass?.hyprGlassLoaded === true
        && RuntimeServices.liquidGlass?.configApplied === true

    Variants {
        id: glassVariants

        readonly property var variantModel: {
            const screens = Quickshell.screens;
            const list = Config.options.bar.screenList;
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }

        model: variantModel

        BarHugGlass {
            id: glassSurface

            required property ShellScreen modelData
            property bool hasActiveWindows: false

            screen: modelData
            surfaceActive: root.surfaceReady
            showBarBackground: Config.options.bar.barBackgroundStyle === 1
                || (Config.options.bar.barBackgroundStyle === 2 && glassSurface.hasActiveWindows)

            function updateHasActiveWindows() {
                if (Config.options.bar.barBackgroundStyle !== 2) {
                    glassSurface.hasActiveWindows = false;
                    return;
                }

                const monitor = HyprlandData.monitors.find(m => m.name === modelData.name);
                const workspaceId = monitor?.activeWorkspace?.id;
                glassSurface.hasActiveWindows = workspaceId
                    ? HyprlandData.windowList.some(w => w.workspace.id === workspaceId && !w.floating)
                    : false;
            }

            Component.onCompleted: glassSurface.updateHasActiveWindows()

            Connections {
                enabled: Config.options.bar.barBackgroundStyle === 2
                target: HyprlandData

                function onWindowListChanged() {
                    glassSurface.updateHasActiveWindows();
                }
            }
        }
    }
}
