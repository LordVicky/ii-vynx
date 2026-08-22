import QtQuick

// Clock hover view adapted from pinned k4 ClockView.qml.
// Copyright (c) 2026 k4ditano — MIT, see licenses/k4-NOTICE.txt.
Item {
    id: root

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

    Item {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 22

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

        K4RecordingPill {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
        }
    }
}
