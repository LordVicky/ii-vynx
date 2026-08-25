import QtQuick
import QtQuick.Layouts

// Plugin lifecycle row. Managed descriptors survive while their live instance
// is disabled or failed. Teardown can still transiently clear a delegate's
// modelData, so every binding treats the model object as nullable.
Rectangle {
    id: root

    required property var plugin
    required property var controller

    readonly property var safePlugin: plugin ?? null
    readonly property bool failed: (safePlugin?.loadError ?? "").length > 0
    readonly property string statusText: !safePlugin ? ""
        : failed ? "Error" : safePlugin.enabled ? "Loaded" : "Disabled"

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
                    text: root.safePlugin?.title ?? root.safePlugin?.name ?? ""
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
                        : root.safePlugin?.enabled ? K4Theme.green : K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
            }

            Text {
                Layout.fillWidth: true
                text: !root.safePlugin ? ""
                    : root.failed
                        ? root.safePlugin.loadError + " · click to retry"
                        : root.safePlugin.name
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
            color: root.safePlugin?.enabled ? K4Theme.blue : K4Theme.track

            Behavior on color { ColorAnimation { duration: 140 } }

            Rectangle {
                width: 16
                height: 16
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: root.safePlugin?.enabled ? parent.width - width - 2 : 2
                color: K4Theme.ink

                Behavior on x {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    HoverHandler { id: rowHover }
    TapHandler {
        cursorShape: root.safePlugin ? Qt.PointingHandCursor : Qt.ArrowCursor
        onTapped: {
            const candidate = root.safePlugin
            const host = root.controller
            if (!candidate || !host)
                return

            const id = String(candidate.name)
            const enabled = Boolean(candidate.enabled)
            const failed = (candidate.loadError ?? "").length > 0
            if (failed && enabled) {
                host.retryPlugin(id)
                return
            }
            host.setPluginEnabled(id, !enabled)
        }
    }
}
