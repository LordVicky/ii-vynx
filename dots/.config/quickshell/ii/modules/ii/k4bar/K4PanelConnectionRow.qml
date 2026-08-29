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
    radius: 10
    color: root.active ? K4Theme.surfaceHi
        : root.hovered ? K4Theme.surface : "transparent"

    function reportPointer(x, y) {
        const tracker = root.ListView.view
        if (!tracker || typeof tracker.rememberPointer !== "function")
            return

        const mapped = rowMouse.mapToItem(tracker, x, y)
        tracker.rememberPointer(mapped.y)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 9

        Text {
            text: root.glyph
            color: root.active ? K4Theme.ink : K4Theme.muted
            font.family: K4Theme.iconFont
            font.pixelSize: 14
            renderType: Text.NativeRendering
            Layout.preferredWidth: 18
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.active ? K4Theme.ink : K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 12
                font.weight: root.active ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.subtitle
                color: K4Theme.dim
                font.family: K4Theme.uiFont
                font.pixelSize: 9
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }

        Text {
            visible: root.secure
            text: K4Theme.ico.lock
            color: K4Theme.dim
            font.family: K4Theme.iconFont
            font.pixelSize: 12
            renderType: Text.NativeRendering
        }

        Text {
            visible: root.busy
            text: "…"
            color: K4Theme.muted
            font.family: K4Theme.uiFont
            font.pixelSize: 14
        }

        K4PanelButton {
            visible: root.forgettable
            glyph: K4Theme.ico.close
            glyphSize: 12
            glyphColor: K4Theme.dim
            onActivated: root.forgotten()
        }

        Text {
            visible: !root.busy
            text: root.active ? K4Theme.ico.check : K4Theme.ico.forward
            color: root.active ? K4Theme.green : K4Theme.dim
            font.family: K4Theme.iconFont
            font.pixelSize: 13
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.reportPointer(mouseX, mouseY)
        onPositionChanged: mouse => root.reportPointer(mouse.x, mouse.y)
        onClicked: root.activated()
    }
}
