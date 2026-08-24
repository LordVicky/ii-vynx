import QtQuick
import QtQuick.Layouts

// Clock hover view adapted from pinned k4 ClockView.qml.
// Copyright (c) 2026 k4ditano — MIT, see licenses/k4-NOTICE.txt.
Item {
    id: root

    property var trayPlugin: null

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

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.bottomMargin: K4Settings.notificationsOnHover && K4Notifications.recent.length > 0 ? 12 : 0
        spacing: 6

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 68

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: K4Clock.date.toLocaleDateString(K4Clock.locale, "dddd")
                    color: K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 11
                    font.capitalization: Font.Capitalize
                    renderType: Text.NativeRendering
                }

                Text {
                    text: K4Clock.date.toLocaleDateString(K4Clock.locale, "d MMMM")
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(K4Clock.date, "HH:mm")
                color: K4Theme.ink
                font.family: K4Theme.uiFont
                font.pixelSize: 30
                font.weight: Font.Light
                renderType: Text.NativeRendering
            }

            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                K4TrayRow {
                    visible: root.trayPlugin !== null && K4Tray.count > 0
                    trayPlugin: root.trayPlugin
                    max: 5
                    iconSize: 16
                }

                K4RecordingPill {
                    interactive: true
                }
            }
        }

        K4NotifStrip {
            visible: K4Settings.notificationsOnHover
            max: 3
            Layout.fillWidth: true
        }
    }
}
