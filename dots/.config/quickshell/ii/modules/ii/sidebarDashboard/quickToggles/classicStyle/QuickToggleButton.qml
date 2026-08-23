import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarDashboard
import QtQuick

GroupButton {
    id: button
    property string buttonIcon
    baseWidth: 40
    baseHeight: 40
    clickedWidth: baseWidth + 20
    toggled: false

    DashboardGlassPalette {
        id: glassPalette
    }

    colBackgroundHover: glassPalette.active ? glassPalette.controlSurfaceHover : Appearance.colors.colLayer1Hover
    colBackgroundActive: glassPalette.active ? glassPalette.controlSurfaceActive : Appearance.colors.colLayer1Active

    readonly property bool sharpMode: Config.options.appearance.sharpMode
    buttonRadius: (altAction && toggled) ? Appearance?.rounding.normal : sharpMode ? 0 : Math.min(baseHeight, baseWidth) / 2
    buttonRadiusPressed: Appearance?.rounding?.small

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        iconSize: 22
        fill: toggled ? 1 : 0
        color: toggled
            ? Appearance.m3colors.m3onPrimary
            : (glassPalette.active ? glassPalette.foregroundPrimary : Appearance.colors.colOnLayer1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: buttonIcon

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

}
