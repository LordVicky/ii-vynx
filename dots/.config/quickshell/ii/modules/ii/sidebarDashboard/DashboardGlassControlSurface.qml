import QtQuick
import qs.modules.common

Item {
    id: root

    property bool opticalActive: false
    property color surfaceColor: "transparent"
    property real surfaceRadius: 0
    property real surfaceLeftRadius: root.surfaceRadius
    property real surfaceRightRadius: root.surfaceRadius
    property bool dark: false
    property bool hovered: false
    property bool pressed: false
    property bool focusVisible: false
    property color focusColor: "transparent"

    readonly property real rimWidth: 1
    readonly property real artworkOpacity: root.pressed ? 0.74 : (root.hovered ? 1.0 : 0.88)
    readonly property real sheenInset: Math.max(
        root.rimWidth + 2,
        Math.max(root.surfaceLeftRadius, root.surfaceRightRadius) * 0.42
    )

    implicitHeight: 50

    Behavior on surfaceColor {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    // Preserve the ordinary control background exactly when Liquid Glass is off.
    Rectangle {
        anchors.fill: parent
        visible: !root.opticalActive
        topLeftRadius: root.surfaceLeftRadius
        bottomLeftRadius: root.surfaceLeftRadius
        topRightRadius: root.surfaceRightRadius
        bottomRightRadius: root.surfaceRightRadius
        color: root.surfaceColor
    }

    Item {
        anchors.fill: parent
        visible: root.opticalActive

        // The outer band stays luminous all the way around the control. Avoid a
        // dark underside: that reads as an embossed Material shadow rather than
        // a refractive glass boundary.
        Rectangle {
            anchors.fill: parent
            topLeftRadius: root.surfaceLeftRadius
            bottomLeftRadius: root.surfaceLeftRadius
            topRightRadius: root.surfaceRightRadius
            bottomRightRadius: root.surfaceRightRadius
            opacity: root.artworkOpacity
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: root.dark
                        ? Qt.rgba(1.0, 1.0, 1.0, 0.30)
                        : Qt.rgba(1.0, 1.0, 1.0, 0.44)
                }
                GradientStop {
                    position: 0.52
                    color: root.dark
                        ? Qt.rgba(1.0, 1.0, 1.0, 0.16)
                        : Qt.rgba(1.0, 1.0, 1.0, 0.22)
                }
                GradientStop {
                    position: 1.0
                    color: root.dark
                        ? Qt.rgba(1.0, 1.0, 1.0, 0.08)
                        : Qt.rgba(1.0, 1.0, 1.0, 0.10)
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: root.rimWidth
            topLeftRadius: Math.max(0, root.surfaceLeftRadius - root.rimWidth)
            bottomLeftRadius: Math.max(0, root.surfaceLeftRadius - root.rimWidth)
            topRightRadius: Math.max(0, root.surfaceRightRadius - root.rimWidth)
            bottomRightRadius: Math.max(0, root.surfaceRightRadius - root.rimWidth)
            color: root.surfaceColor
        }

        // A faint inner ring gives the edge optical thickness without becoming
        // a conventional outline.
        Rectangle {
            anchors.fill: parent
            anchors.margins: root.rimWidth
            topLeftRadius: Math.max(0, root.surfaceLeftRadius - root.rimWidth)
            bottomLeftRadius: Math.max(0, root.surfaceLeftRadius - root.rimWidth)
            topRightRadius: Math.max(0, root.surfaceRightRadius - root.rimWidth)
            bottomRightRadius: Math.max(0, root.surfaceRightRadius - root.rimWidth)
            color: "transparent"
            border.width: 1
            border.color: root.dark
                ? Qt.rgba(1.0, 1.0, 1.0, 0.06)
                : Qt.rgba(1.0, 1.0, 1.0, 0.10)
            opacity: root.artworkOpacity
        }

        // The strongest highlight is local to the top-facing edge instead of
        // wrapping the entire control in a glowing white stroke.
        Rectangle {
            x: root.sheenInset
            y: root.rimWidth + 0.5
            width: Math.max(0, parent.width - root.sheenInset * 2)
            height: 1
            radius: 0.5
            color: root.dark
                ? Qt.rgba(1.0, 1.0, 1.0, 0.12)
                : Qt.rgba(1.0, 1.0, 1.0, 0.18)
            opacity: root.artworkOpacity
        }
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.surfaceLeftRadius
        bottomLeftRadius: root.surfaceLeftRadius
        topRightRadius: root.surfaceRightRadius
        bottomRightRadius: root.surfaceRightRadius
        color: "transparent"
        border.width: root.focusVisible ? 2 : 0
        border.color: root.focusColor
    }
}
