import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

// Notification toast adapted from pinned k4 ToastView.qml. Notification
// lifecycle/actions remain owned by ii-vynx's Notifications singleton.
Item {
    id: root

    readonly property var notification: K4Notifications.latest
    readonly property var buttons: K4Notifications.buttons(notification)
    readonly property string iconSource: K4Notifications.iconFor(notification)

    opacity: 0
    Component.onCompleted: fadeIn.start()

    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 12

        ClippingRectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            Layout.alignment: Qt.AlignVCenter
            radius: 19
            color: K4Theme.surface

            Image {
                id: notificationIcon
                anchors.fill: parent
                anchors.margins: 6
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                sourceSize.width: 76
                sourceSize.height: 76
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !notificationIcon.visible
                text: K4Theme.ico.bell
                color: K4Theme.ink
                font.family: K4Theme.iconFont
                font.pixelSize: 17
                renderType: Text.NativeRendering
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: (root.notification?.summary ?? "").replace(/\s*\n\s*/g, " ")
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    renderType: Text.NativeRendering
                }

                Text {
                    text: root.notification?.appName ?? ""
                    color: K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.maximumWidth: 90
                    renderType: Text.NativeRendering
                }
            }

            Text {
                Layout.fillWidth: true
                text: (root.notification?.body ?? "").replace(/\s*\n\s*/g, " ")
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: root.buttons.length > 0 ? 1 : 2
                renderType: Text.NativeRendering
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 6
                visible: root.buttons.length > 0

                Repeater {
                    model: root.buttons

                    delegate: Rectangle {
                        id: actionChip
                        required property var modelData
                        readonly property string label: modelData.text ?? modelData.identifier ?? ""
                        Layout.preferredWidth: Math.min(actionLabel.implicitWidth + 20, 150)
                        Layout.preferredHeight: 20
                        radius: 10
                        color: actionMouse.containsMouse ? K4Theme.blue : K4Theme.surfaceHi

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            id: actionLabel
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            text: actionChip.label
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                K4Notifications.invokeAction(root.notification, actionChip.modelData)
                                K4Notifications.dismissToast()
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        Item {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: K4Theme.ico.close
                color: closeMouse.containsMouse ? K4Theme.ink : K4Theme.muted
                font.family: K4Theme.iconFont
                font.pixelSize: 14
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: K4Notifications.dismissToast()
            }
        }
    }
}
