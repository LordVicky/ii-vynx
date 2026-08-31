pragma Singleton

import QtQuick
import Quickshell

// Narrow navigation seam for the one live K4 tray plugin. Presentation
// surfaces can open an item's tray detail without owning or duplicating the
// plugin instance.
Singleton {
    id: root

    property var plugin: null

    function toggle() {
        plugin?.toggle()
    }

    function openFor(item) {
        plugin?.openFor(item)
    }
}
