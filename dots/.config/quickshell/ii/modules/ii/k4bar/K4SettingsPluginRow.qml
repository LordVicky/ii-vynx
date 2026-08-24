import QtQuick
import QtQuick.Layouts

// Static-registry plugin status row for K4-08. K4-11 later upgrades the same
// contract to dynamic instantiation/retry without changing this settings seam.
Rectangle {
    id: root

    required property var plugin
    required property var controller

    readonly property bool failed: plugin.loadError.length > 0
    readonly property string statusText: failed ? "Error"
        : plugin.enabled ? "Loaded" : "Disabled"

    implicitHeight: failed ? 66 : 54
    radius: 12
    color: rowHover.hovered ? K4Theme.surfaceHi : K4Theme.surface

    Behavior on color { ColorAnimation { duration: 120 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                Text {
                    Layout.fillWidth: true
                    text: root.plugin.title ?? root.plugin.name
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Text {
                    text: root.statusText
                    color: root.failed ? K4Theme.red
                        : root.plugin.enabled ? K4Theme.green : K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.failed ? root.plugin.loadError : root.plugin.name
                color: root.failed ? K4Theme.red : K4Theme.dim
                font.family: K4Theme.uiFont
                font.pixelSize: 9
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            radius: 10
            color: root.plugin.enabled ? K4Theme.blue : K4Theme.track

            Behavior on color { ColorAnimation { duration: 140 } }

            Rectangle {
                width: 16
                height: 16
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: root.plugin.enabled ? parent.width - width - 2 : 2
                color: K4Theme.ink

                Behavior on x {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    HoverHandler { id: rowHover }
    TapHandler {
        cursorShape: Qt.PointingHandCursor
        onTapped: {
            const value = !root.plugin.enabled
            root.controller.setPluginEnabled(root.plugin.name, value)
        }
    }
}
