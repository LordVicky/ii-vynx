import qs.modules.common
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool vertical: false
    property real padding: 5
    implicitWidth: vertical ? Appearance.sizes.baseVerticalBarWidth : (gridLayout.implicitWidth + padding * 2)
    implicitHeight: vertical ? (gridLayout.implicitHeight + padding * 2) : Appearance.sizes.baseBarHeight
    default property alias items: gridLayout.children
    property var startRadius // left - top
    property var endRadius // right - bottom

    property color colBackground: Appearance.m3colors.m3surfaceContainerLow
    property bool inlay: false
    property color colInlayBorder: "transparent"
    property bool recessedInlay: false
    property color colInlayShadow: "transparent"
    property color colInlayHighlight: "transparent"

    Rectangle {
        id: background
        anchors {
            fill: parent
            topMargin: root.vertical ? 0 : 4
            bottomMargin: root.vertical ? 0 : 4
            leftMargin: root.vertical ? 4 : 0
            rightMargin: root.vertical ? 4 : 0
        }
        color: root.colBackground
        topLeftRadius: startRadius
        bottomLeftRadius: root.vertical ? endRadius: startRadius
        topRightRadius: root.vertical ? startRadius: endRadius
        bottomRightRadius: endRadius
        border.width: root.inlay && !root.recessedInlay ? 1 : 0
        border.color: root.inlay && !root.recessedInlay ? root.colInlayBorder : "transparent"

        Rectangle {
            anchors.fill: parent
            visible: root.recessedInlay
            color: "transparent"
            topLeftRadius: background.topLeftRadius
            bottomLeftRadius: background.bottomLeftRadius
            topRightRadius: background.topRightRadius
            bottomRightRadius: background.bottomRightRadius
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: root.colInlayShadow }
                GradientStop { position: 0.24; color: "transparent" }
                GradientStop { position: 0.76; color: "transparent" }
                GradientStop { position: 1.0; color: root.colInlayHighlight }
            }
        }

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors {
            verticalCenter: root.vertical ? undefined : parent.verticalCenter
            horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            left: root.vertical ? undefined : parent.left
            right: root.vertical ? undefined : parent.right
            top: root.vertical ? parent.top : undefined
            bottom: root.vertical ? parent.bottom : undefined
            margins: root.padding
        }
        columnSpacing: 4
        rowSpacing: 12
    }
}
