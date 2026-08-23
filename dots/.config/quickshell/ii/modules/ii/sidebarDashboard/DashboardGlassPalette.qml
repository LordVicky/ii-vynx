import QtQuick
import qs.services

QtObject {
    readonly property bool active: RuntimeServices.liquidGlass?.surfaceReady === true
    readonly property bool dark: RuntimeServices.liquidGlass?.glassTheme === "dark"

    // Foreground structure for controls sitting above the Regular sidebar
    // material. Keep these neutral so the wallpaper and shell accent do not
    // muddy inactive controls; toggled/primary controls keep their normal accent.
    // These stay deliberately translucent: the optical rim should define the
    // control before the fill does.
    readonly property color controlSurface: dark
        ? Qt.rgba(0.06, 0.06, 0.07, 0.18)
        : Qt.rgba(1.0, 1.0, 1.0, 0.16)
    readonly property color controlSurfaceHover: dark
        ? Qt.rgba(0.08, 0.08, 0.09, 0.26)
        : Qt.rgba(1.0, 1.0, 1.0, 0.24)
    readonly property color controlSurfaceActive: dark
        ? Qt.rgba(0.10, 0.10, 0.11, 0.34)
        : Qt.rgba(1.0, 1.0, 1.0, 0.32)
    readonly property color controlSurfaceStrong: dark
        ? Qt.rgba(0.08, 0.08, 0.09, 0.26)
        : Qt.rgba(1.0, 1.0, 1.0, 0.22)

    readonly property color foregroundPrimary: dark
        ? Qt.rgba(0.97, 0.97, 0.98, 0.96)
        : Qt.rgba(0.08, 0.08, 0.09, 0.94)
    readonly property color foregroundSecondary: dark
        ? Qt.rgba(0.88, 0.88, 0.90, 0.72)
        : Qt.rgba(0.16, 0.16, 0.18, 0.68)
}
