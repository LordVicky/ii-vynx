import QtQuick

Item {
    id: root

    required property string glyph
    property int glyphSize: 15
    property color glyphColor: K4Theme.panelMuted
    property color activeColor: K4Theme.panelSurfaceHot
    property bool enabledAction: true
    property bool active: false
    signal activated()

    implicitWidth: 28
    implicitHeight: 28
    opacity: enabledAction ? 1 : 0.28

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.active || hover.hovered ? root.activeColor : "transparent"
        border.width: root.active || hover.hovered ? 1 : 0
        border.color: K4Theme.panelLineStrong

        Behavior on color { ColorAnimation { duration: 110 } }
        Behavior on border.color { ColorAnimation { duration: 110 } }
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
