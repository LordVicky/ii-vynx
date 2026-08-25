import QtQuick
import QtQuick.Layouts

// Plugin status row. Static plugins remain instantiated; K4-11 managed proxies
// keep this same stable object while their Loader-owned implementation comes
// and goes behind it.
Rectangle {
    id: root

    required property var plugin
    required property var controller

    readonly property bool failed: plugin.loadError.length > 0
    readonly property string statusText: !plugin.enabled ? "Disabled"
        : failed ? "Error"
        : plugin.instantiated ? "Loaded" : "Loading"

    implicitHeight: failed ? 66 : 54
    radius: 12
    color: rowHover.hovered ? K4Theme.surfaceHi : K4Theme.surface

    Behavior on color { ColorAnimation { duration: 120 } }

    function toggleEnabled() {
        const value = !plugin.enabled
        controller.setPluginEnabled(plugin.name, value)
    }

    function retryLoad() {
        if (plugin.enabled && typeof plugin.retryLoad === "function")
            plugin.retryLoad()
    }

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
                    color: root.failed && root.plugin.enabled ? K4Theme.red
                        : root.plugin.enabled && root.plugin.instantiated
                            ? K4Theme.green : K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.failed && root.plugin.enabled
                    ? root.plugin.loadError
                    : root.plugin.name
                color: root.failed && root.plugin.enabled ? K4Theme.red : K4Theme.dim
                font.family: K4Theme.uiFont
                font.pixelSize: 9
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }

        Rectangle {
            visible: root.failed && root.plugin.enabled
            Layout.preferredWidth: visible ? 46 : 0
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
            radius: 12
            color: retryHover.hovered ? K4Theme.surfaceHi : K4Theme.track

            Text {
                anchors.centerIn: parent
                text: "Retry"
                color: K4Theme.ink
                font.family: K4Theme.uiFont
                font.pixelSize: 9
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            HoverHandler { id: retryHover }
            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: root.retryLoad()
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

            TapHandler {
                enabled: root.failed
                cursorShape: Qt.PointingHandCursor
                onTapped: root.toggleEnabled()
            }
        }
    }

    HoverHandler { id: rowHover }
    TapHandler {
        enabled: !root.failed
        cursorShape: Qt.PointingHandCursor
        onTapped: root.toggleEnabled()
    }
}
