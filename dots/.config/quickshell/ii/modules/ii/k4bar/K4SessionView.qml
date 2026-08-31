import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var plugin
    focus: true

    Component.onCompleted: { fade.start(); forceActiveFocus() }
    opacity: 0
    NumberAnimation { id: fade; target: root; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) { root.plugin.close(); event.accepted = true }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { root.plugin.advance(); event.accepted = true }
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) { root.plugin.retreat(); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { root.plugin.choose(); event.accepted = true }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Text {
            Layout.fillWidth: true
            text: "Session"
            color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 15; font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Repeater {
                model: root.plugin.actions
                Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.plugin.index
                    readonly property bool confirm: index === root.plugin.confirming
                    Layout.preferredWidth: 110
                    Layout.fillHeight: true
                    radius: 14
                    color: confirm ? "#332c2c2e" : selected ? K4Theme.surfaceHi : cardMouse.containsMouse ? K4Theme.surface : "transparent"
                    border.width: selected ? 1 : 0
                    border.color: confirm ? K4Theme.red : K4Theme.blue

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: 7
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: card.modelData.glyph
                            color: card.modelData.tone
                            font.family: K4Theme.iconFont; font.pixelSize: 28
                        }
                        Text {
                            Layout.fillWidth: true
                            text: card.confirm ? "Confirm?" : card.modelData.label
                            color: card.confirm ? K4Theme.red : K4Theme.ink
                            font.family: K4Theme.uiFont; font.pixelSize: 11
                            font.weight: card.selected ? Font.DemiBold : Font.Normal
                            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: cardMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: { root.plugin.index = card.index; if (root.plugin.confirming !== card.index) root.plugin.confirming = -1 }
                        onClicked: { root.plugin.index = card.index; root.plugin.execute(card.index) }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "irreversible actions require a second activation · esc closes"
            color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
