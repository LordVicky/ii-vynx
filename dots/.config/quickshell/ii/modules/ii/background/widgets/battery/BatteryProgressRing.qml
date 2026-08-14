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
    property string centerText: ""
    property bool charging: false
    property real scaleFactor: 1

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
        visible: !root.charging && root.centerIcon.length > 0
        text: root.centerIcon
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        baseIconSize: Appearance.font.pixelSize.normal
        scaleFactor: root.scaleFactor
        color: root.ringColor
        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
    }

    Shape {
        id: chargingBolt
        anchors.centerIn: parent
        width: root.ringSize * 0.28
        height: width
        visible: root.charging
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.ringColor
            strokeColor: root.ringColor
            strokeWidth: Math.max(0.8, chargingBolt.width * 0.09)
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            startX: chargingBolt.width * 0.58
            startY: chargingBolt.height * 0.08
            PathLine {
                x: chargingBolt.width * 0.22
                y: chargingBolt.height * 0.53
            }
            PathLine {
                x: chargingBolt.width * 0.47
                y: chargingBolt.height * 0.53
            }
            PathLine {
                x: chargingBolt.width * 0.34
                y: chargingBolt.height * 0.92
            }
            PathLine {
                x: chargingBolt.width * 0.79
                y: chargingBolt.height * 0.40
            }
            PathLine {
                x: chargingBolt.width * 0.53
                y: chargingBolt.height * 0.40
            }
            PathLine {
                x: chargingBolt.width * 0.58
                y: chargingBolt.height * 0.08
            }
        }
    }

    TransformSafeText {
        anchors.fill: parent
        visible: !root.charging && root.centerIcon.length === 0 && root.centerText.length > 0
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
