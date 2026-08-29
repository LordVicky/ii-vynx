import QtQuick
import QtQuick.Layouts

// Compact K4 settings row used only for boolean preferences with live runtime
// consumers. The parent owns persistence through K4Settings.
Rectangle {
    id: root

    required property string title
    property string description: ""
    property string glyph: ""
    property bool checked: false
    property bool externalHovered: false
    signal toggled(bool value)

    implicitHeight: 58
    radius: 12
    color: externalHovered || rowHover.hovered ? K4Theme.surfaceHi : K4Theme.surface

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            visible: root.glyph.length > 0
            text: root.glyph
            color: K4Theme.muted
            font.family: K4Theme.iconFont
            font.pixelSize: 15
            renderType: Text.NativeRendering
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.title
                color: K4Theme.ink
                font.family: K4Theme.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                Layout.fillWidth: true
                visible: root.description.length > 0
                text: root.description
                color: K4Theme.muted
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
            color: root.checked ? K4Theme.blue : K4Theme.track

            Behavior on color { ColorAnimation { duration: 140 } }

            Rectangle {
                width: 16
                height: 16
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: root.checked ? parent.width - width - 2 : 2
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
        onTapped: root.toggled(!root.checked)
    }
}
