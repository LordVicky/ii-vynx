pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common

Scope {
    id: root

    Variants {
        model: GlobalStates.screenLocked ? [] : Quickshell.screens

        delegate: PanelWindow {
            id: panelWindow
            required property var modelData
            screen: modelData

            readonly property bool bottom: Config.options.bar.k4.position === "bottom"
            readonly property real alignment: Math.max(0, Math.min(100, Config.options.bar.k4.alignment)) / 100

            anchors.top: !bottom
            anchors.bottom: bottom
            anchors.left: true
            anchors.right: true
            color: "transparent"
            aboveWindows: true
            focusable: false

            WlrLayershell.namespace: "quickshell:k4bar"

            implicitHeight: 34
            exclusiveZone: 34
            mask: Region { item: island }

            Item {
                id: island
                width: 176
                height: 34
                x: (parent.width - width) * panelWindow.alignment
                anchors.top: panelWindow.bottom ? undefined : parent.top
                anchors.bottom: panelWindow.bottom ? parent.bottom : undefined

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "#000000"
                }
            }
        }
    }
}
