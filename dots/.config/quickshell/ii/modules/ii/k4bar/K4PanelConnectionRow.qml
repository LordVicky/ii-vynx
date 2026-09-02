import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property string title
    property string subtitle: ""
    property string glyph: ""
    property bool active: false
    property bool busy: false
    property bool secure: false
    property bool forgettable: false
    property bool hovered: false
    signal activated()
    signal forgotten()

    implicitHeight: 42
    radius: 11
    color: root.active ? K4Theme.panelSurfaceHot
        : root.hovered ? K4Theme.panelSurfaceHi : "transparent"
    border.width: root.active || root.hovered ? 1 : 0
    border.color: root.active ? K4Theme.panelLineStrong : K4Theme.panelLine

    Behavior on color { ColorAnimation { duration: 110 } }
    Behavior on border.color { ColorAnimation { duration: 110 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 9

        Rectangle {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 9
            color: root.active ? Qt.rgba(0.43, 0.66, 1, 0.18) : K4Theme.panelSurfaceHi
            border.width: 1
            border.color: root.active ? Qt.rgba(0.43, 0.66, 1, 0.30) : K4Theme.panelLine

            Text {
                anchors.centerIn: parent
                text: root.glyph
                color: root.active ? K4Theme.panelBlue : K4Theme.panelMuted
                font.family: K4Theme.iconFont
                font.pixelSize: 13
                renderType: Text.NativeRendering
            }
        }

        ColumnLayout {
            Layout.minimumWidth: 0
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.active ? K4Theme.ink : K4Theme.panelInkSoft
                font.family: K4Theme.uiFont
                font.pixelSize: 11
                font.weight: root.active ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.subtitle
                color: K4Theme.panelMuted
                font.family: K4Theme.uiFont
                font.pixelSize: 8
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }

        Text {
            visible: root.secure
            text: K4Theme.ico.lock
            color: K4Theme.panelDim
            font.family: K4Theme.iconFont
            font.pixelSize: 12
            renderType: Text.NativeRendering
        }

        Text {
            visible: root.busy
            text: "…"
            color: K4Theme.panelMuted
            font.family: K4Theme.uiFont
            font.pixelSize: 14
        }

        K4PanelButton {
            visible: root.forgettable
            glyph: K4Theme.ico.close
            glyphSize: 12
            glyphColor: K4Theme.panelDim
            onActivated: root.forgotten()
        }

        Text {
            visible: !root.busy
            text: root.active ? K4Theme.ico.check : K4Theme.ico.forward
            color: root.active ? K4Theme.green : K4Theme.panelDim
            font.family: K4Theme.iconFont
            font.pixelSize: 13
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
