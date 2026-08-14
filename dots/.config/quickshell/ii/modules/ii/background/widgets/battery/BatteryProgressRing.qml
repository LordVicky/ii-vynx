import QtQuick
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
        visible: root.centerIcon.length > 0
        text: root.centerIcon
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        baseIconSize: Appearance.font.pixelSize.normal
        scaleFactor: root.scaleFactor
        color: root.ringColor
        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
    }

    TransformSafeText {
        anchors.fill: parent
        visible: root.centerIcon.length === 0 && root.centerText.length > 0
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
