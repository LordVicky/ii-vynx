import QtQuick
import QtQuick.Shapes
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

Item {
    id: root

    property real percentage: 0
    property color ringColor: Appearance.colors.colPrimary
    property real ringSize: 56
    property real lineWidth: 5
    property string centerIcon: ""
    property string centerCustomIcon: ""
    property string centerText: ""
    property bool charging: false
    property real scaleFactor: 1
    readonly property bool smallRing: ringSize <= 40 * scaleFactor

    implicitWidth: ringSize
    implicitHeight: ringSize

    CircularProgress {
        anchors.fill: parent
        implicitSize: root.ringSize
        lineWidth: root.lineWidth
        value: root.percentage
        colPrimary: root.ringColor
        colSecondary: Appearance.colors.colSecondaryContainer
    }

    TransformSafeSymbol {
        anchors.fill: parent
        visible: !root.charging && root.centerCustomIcon.length === 0 && root.centerIcon.length > 0
        text: root.centerIcon
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        baseIconSize: Appearance.font.pixelSize.normal
        scaleFactor: root.scaleFactor
        color: root.ringColor
        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
    }

    CustomIcon {
        anchors.centerIn: parent
        width: root.ringSize * 0.42
        height: width
        visible: !root.charging && root.centerCustomIcon.length > 0
        source: root.centerCustomIcon
        colorize: true
        color: root.ringColor
    }

    Shape {
        id: chargingBolt
        anchors.centerIn: parent
        width: root.ringSize * (root.smallRing ? 0.34 : 0.27)
        height: root.ringSize * (root.smallRing ? 0.40 : 0.31)
        visible: root.charging
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.ringColor
            strokeColor: root.ringColor
            strokeWidth: Math.max(0.6, chargingBolt.width * 0.055)
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            startX: chargingBolt.width * 0.62
            startY: chargingBolt.height * 0.06
            PathLine {
                x: chargingBolt.width * 0.22
                y: chargingBolt.height * 0.52
            }
            PathLine {
                x: chargingBolt.width * 0.50
                y: chargingBolt.height * 0.52
            }
            PathLine {
                x: chargingBolt.width * 0.36
                y: chargingBolt.height * 0.94
            }
            PathLine {
                x: chargingBolt.width * 0.80
                y: chargingBolt.height * 0.40
            }
            PathLine {
                x: chargingBolt.width * 0.52
                y: chargingBolt.height * 0.40
            }
            PathLine {
                x: chargingBolt.width * 0.62
                y: chargingBolt.height * 0.06
            }
        }
    }

    TransformSafeText {
        anchors.fill: parent
        visible: !root.charging && root.centerCustomIcon.length === 0 && root.centerIcon.length === 0 && root.centerText.length > 0
        text: root.centerText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        basePixelSize: Appearance.font.pixelSize.smallest
        scaleFactor: root.scaleFactor
        requestedWeight: Font.DemiBold
        color: root.ringColor
        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
        fontSizeMode: Text.Fit
        minimumPixelSize: Appearance.font.pixelSize.smallest * root.scaleFactor
    }
}
