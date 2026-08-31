import QtQuick
import QtQuick.Layouts

// Recent notification strip adapted from pinned k4 widgets/NotifStrip.qml.
// Notification ownership remains in ii-vynx's shared Notifications service.
ColumnLayout {
    id: strip

    property int max: 3

    readonly property int shown: Math.min(K4Notifications.recent.length, max)
    readonly property int rowHeight: 34
    readonly property int neededHeight: K4Notifications.stripHeight(max)

    visible: K4Notifications.recent.length > 0
    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 14
        spacing: 6

        Text {
            text: K4Theme.ico.bell
            color: K4Theme.muted
            font.family: K4Theme.iconFont
            font.pixelSize: 11
            renderType: Text.NativeRendering
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: K4Notifications.recent.length === 1
                ? "1 notification"
                : K4Notifications.recent.length + " notifications"
            color: K4Theme.muted
            font.family: K4Theme.uiFont
            font.pixelSize: 10
            renderType: Text.NativeRendering
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Text {
            visible: K4Notifications.recent.length > strip.shown
            text: "+" + (K4Notifications.recent.length - strip.shown) + " more"
            color: K4Theme.dim
            font.family: K4Theme.uiFont
            font.pixelSize: 10
            renderType: Text.NativeRendering
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            Layout.preferredWidth: clearRow.implicitWidth + 12
            Layout.preferredHeight: 15
            Layout.alignment: Qt.AlignVCenter
            radius: 7
            color: clearMouse.containsMouse ? K4Theme.red : K4Theme.surfaceHi

            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                id: clearRow
                anchors.centerIn: parent
                spacing: 3

                Text {
                    text: K4Theme.ico.clearAll
                    color: clearMouse.containsMouse ? K4Theme.ink : K4Theme.muted
                    font.family: K4Theme.iconFont
                    font.pixelSize: 10
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Clear all"
                    color: clearMouse.containsMouse ? K4Theme.ink : K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: K4Notifications.clear()
            }
        }
    }

    Repeater {
        model: K4Notifications.recent.slice(0, strip.shown)

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property string iconSource: K4Notifications.iconFor(modelData)

            Layout.fillWidth: true
            Layout.preferredHeight: strip.rowHeight
            radius: 9
            color: rowMouse.containsMouse ? K4Theme.surfaceHi : K4Theme.surface

            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 4
                spacing: 8

                Item {
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        id: rowIcon
                        anchors.fill: parent
                        source: row.iconSource
                        sourceSize.width: 32
                        sourceSize.height: 32
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !rowIcon.visible
                        text: K4Theme.ico.bell
                        color: K4Theme.muted
                        font.family: K4Theme.iconFont
                        font.pixelSize: 13
                        renderType: Text.NativeRendering
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: (row.modelData?.summary ?? "").replace(/\s*\n\s*/g, " ")
                        color: K4Theme.ink
                        font.family: K4Theme.uiFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        renderType: Text.NativeRendering
                    }

                    Text {
                        Layout.fillWidth: true
                        text: ((row.modelData?.body?.length ?? 0) > 0
                                ? row.modelData.body : (row.modelData?.appName ?? ""))
                            .replace(/\s*\n\s*/g, " ")
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 9
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        renderType: Text.NativeRendering
                    }
                }

                Item {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: K4Theme.ico.close
                        color: rowMouse.containsMouse ? K4Theme.ink : K4Theme.dim
                        font.family: K4Theme.iconFont
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            mouse.accepted = true
                            K4Notifications.dismiss(row.modelData)
                        }
                    }
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                z: -1
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: K4Notifications.activate(row.modelData)
            }
        }
    }
}
