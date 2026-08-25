import QtQuick
import Quickshell.Io

// Isolated K4-11 prototype harness. This object never joins arbitration,
// Settings, Apps or persisted enablement. The only lifetime control is
// Loader.active so Qt owns creation and release of the probe QObject.
QtObject {
    id: root

    property bool probeEnabled: false
    property int generation: 0

    property var lifecycleLoader: Loader {
        active: root.probeEnabled
        asynchronous: false
        sourceComponent: Component { K4PluginLifecycleProbe {} }
        onLoaded: root.generation += 1
    }

    property var debugIpc: IpcHandler {
        target: "k4.pluginLifecycleProbe"

        function enable(): void { root.probeEnabled = true }
        function disable(): void { root.probeEnabled = false }
        function toggle(): void { root.probeEnabled = !root.probeEnabled }

        function status(): string {
            return JSON.stringify({
                enabled: root.probeEnabled,
                loaded: root.lifecycleLoader.item !== null,
                generation: root.generation,
                loaderStatus: root.lifecycleLoader.status
            })
        }
    }
}
