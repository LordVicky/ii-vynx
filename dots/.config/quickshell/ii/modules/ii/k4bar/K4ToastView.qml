import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.common.widgets

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
            Layout.alignment: Qt.AlignTop
            radius: 19
            color: K4Theme.surface

            Image {
                id: notificationIcon
                anchors.fill: parent
                source: root.iconSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 96
                sourceSize.height: 96
                visible: status === Image.Ready
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: !notificationIcon.visible
                text: "notifications"
                fill: 1
                iconSize: 18
                color: K4Theme.ink
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: root.notification?.summary ?? ""
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 12
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
                    Layout.maximumWidth: 100
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "×"
                    color: closeHover.hovered ? K4Theme.ink : K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 15
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    renderType: Text.NativeRendering

                    HoverHandler { id: closeHover }
                    TapHandler { onTapped: K4Notifications.dismissToast() }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.fillHeight: root.buttons.length === 0
                text: root.notification?.body ?? ""
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 11
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: root.buttons.length > 0 ? 1 : 2
                renderType: Text.NativeRendering
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: root.buttons.length > 0

                Item { Layout.fillWidth: true }

                Repeater {
                    model: root.buttons

                    delegate: Rectangle {
                        required property var modelData
                        readonly property string label: modelData.text ?? modelData.identifier ?? ""
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: Math.max(54, actionText.implicitWidth + 18)
                        radius: 12
                        color: actionHover.hovered ? K4Theme.track : K4Theme.surface

                        Text {
                            id: actionText
                            anchors.centerIn: parent
                            text: parent.label
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                        }

                        HoverHandler { id: actionHover }
                        TapHandler {
                            onTapped: {
                                K4Notifications.invokeAction(root.notification, modelData)
                                K4Notifications.dismissToast()
                            }
                        }
                    }
                }
            }
        }
    }
}
