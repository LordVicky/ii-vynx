pragma Singleton

import QtQuick

// Narrow global entry point for controls that need to navigate into the panel
// (for example Player's output-device button). The K4PanelPlugin remains the
// state/ownership object; this singleton only delegates to the live instance.
Singleton {
    id: root

    property var plugin: null

    readonly property bool open: plugin?.open ?? false
    readonly property string tab: plugin?.tab ?? "controls"

    function toggle(wanted = "controls") {
        plugin?.toggle(wanted)
    }

    function openTab(wanted) {
        plugin?.openTab(wanted)
    }

    function close() {
        plugin?.close()
    }
}
