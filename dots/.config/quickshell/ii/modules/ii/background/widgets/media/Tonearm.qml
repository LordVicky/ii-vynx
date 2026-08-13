import QtQuick
import qs.modules.common

/**
 * A tonearm that pivots about its own mounting point.
 *
 * The item itself is zero-sized and positioned exactly ON the pivot, so
 * `rotation` turns about the pivot by construction — transformOrigin defaults
 * to Center, and on a 0x0 item that is the origin. Everything hangs off it at
 * negative x, reaching out over the record. Nothing has to be kept in sync when
 * the angle changes, which is what makes the geometry hard to get wrong.
 *
 * At `armAngle: 0` the arm points along -x. The caller supplies angles solved
 * against its own platter geometry:
 *
 *   Tonearm {
 *       x: 206; y: 26          // the pivot, in the layout's coordinates
 *       armLength: 130
 *       armAngle: down ? (a0 + (a1 - a0) * progress) : park
 *   }
 */
Item {
    id: root

    property real armLength: 130
    property real armAngle: 0
    property real tubeThickness: 4
    property real pivotSize: 18
    property real headWidth: 15
    property real headHeight: 12
    property bool showWeight: true
    // Base plate under the pivot. Only wanted when the arm mounts somewhere
    // other than a plinth (the platter layout pivots out over the wallpaper,
    // where a bare pivot reads as floating). Circular, so it is unaffected by
    // the rotation it inherits.
    property real mountSize: 0

    readonly property color metalLight: "#EFE9DC"
    readonly property color metalMid: "#A49D91"
    readonly property color metalDark: "#56514A"

    width: 0
    height: 0
    rotation: armAngle

    // Cueing: the arm lifts to its rest and sets back down, it does not snap.
    Behavior on rotation {
        NumberAnimation {
            duration: 650
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
        }
    }

    // ---- mount plate, behind everything
    Rectangle {
        visible: root.mountSize > 0
        x: -root.mountSize / 2
        y: -root.mountSize / 2
        width: root.mountSize
        height: root.mountSize
        radius: width / 2
        color: Qt.rgba(0.08, 0.07, 0.07, 0.55)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
    }

    // ---- arm tube
    Rectangle {
        x: -root.armLength
        y: -root.tubeThickness / 2
        width: root.armLength
        height: root.tubeThickness
        radius: root.tubeThickness / 2
        gradient: Gradient {
            GradientStop { position: 0.00; color: root.metalLight }
            GradientStop { position: 0.55; color: root.metalMid }
            GradientStop { position: 1.00; color: root.metalDark }
        }
    }

    // ---- headshell + stylus
    Rectangle {
        id: head
        x: -root.armLength - root.headWidth + 4
        y: -root.headHeight / 2
        width: root.headWidth
        height: root.headHeight
        radius: 2
        gradient: Gradient {
            GradientStop { position: 0.00; color: "#37342F" }
            GradientStop { position: 1.00; color: "#161513" }
        }

        Rectangle { // the stylus itself, riding in the groove
            x: 2
            y: parent.height - 1
            width: 2
            height: Math.max(3, root.headHeight * 0.3)
            radius: 1
            color: "#E8E2D6"
        }
    }

    // ---- counterweight behind the pivot
    Rectangle {
        visible: root.showWeight
        x: root.pivotSize / 2
        y: -root.headHeight / 2
        width: root.pivotSize * 0.95
        height: root.headHeight
        radius: 3
        gradient: Gradient {
            GradientStop { position: 0.00; color: "#4C473F" }
            GradientStop { position: 1.00; color: "#232120" }
        }
    }

    // ---- pivot, drawn last so it sits over both the tube and the weight
    Rectangle {
        x: -root.pivotSize / 2
        y: -root.pivotSize / 2
        width: root.pivotSize
        height: root.pivotSize
        radius: width / 2
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.4)
        gradient: Gradient {
            GradientStop { position: 0.00; color: "#F4EEE1" }
            GradientStop { position: 0.55; color: "#ABA498" }
            GradientStop { position: 1.00; color: "#5C574F" }
        }
    }
}
