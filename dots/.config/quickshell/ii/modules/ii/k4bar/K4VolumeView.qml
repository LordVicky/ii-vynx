import QtQuick
import QtQuick.Layouts

// Volume HUD adapted from pinned k4 VolumeView.qml.
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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 10

        Text {
            text: K4Audio.muted ? K4Theme.ico.volOff
                : K4Audio.volume > 45 ? K4Theme.ico.volHigh : K4Theme.ico.volMed
            color: K4Audio.muted ? K4Theme.muted : K4Theme.ink
            font.family: K4Theme.iconFont
            font.pixelSize: 15
            renderType: Text.NativeRendering
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: K4Theme.track
            }

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, K4Audio.volume / 100))
                height: parent.height
                radius: height / 2
                color: K4Audio.muted ? K4Theme.muted : K4Theme.ink

                Behavior on width {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
                Behavior on color { ColorAnimation { duration: 140 } }
            }
        }

        Text {
            text: K4Audio.muted ? "—" : K4Audio.volume + "%"
            color: K4Theme.muted
            font.family: K4Theme.uiFont
            font.pixelSize: 11
            horizontalAlignment: Text.AlignRight
            renderType: Text.NativeRendering
            Layout.preferredWidth: 30
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
