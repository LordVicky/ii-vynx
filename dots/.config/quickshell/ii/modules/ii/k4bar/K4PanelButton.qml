import QtQuick

Item {
    id: root

    required property string glyph
    property int glyphSize: 15
    property color glyphColor: K4Theme.muted
    property color activeColor: K4Theme.surfaceHi
    property bool enabledAction: true
    property bool active: false
    signal activated()

    implicitWidth: 28
    implicitHeight: 28
    opacity: enabledAction ? 1 : 0.32

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.active || hover.hovered ? root.activeColor : "transparent"

        Behavior on color { ColorAnimation { duration: 110 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        color: root.active ? K4Theme.ink : root.glyphColor
        font.family: K4Theme.iconFont
        font.pixelSize: root.glyphSize
        renderType: Text.NativeRendering
    }

    HoverHandler { id: hover; enabled: root.enabledAction }
    TapHandler {
        enabled: root.enabledAction
        cursorShape: Qt.PointingHandCursor
        onTapped: root.activated()
    }
}
