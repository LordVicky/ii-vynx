pragma Singleton

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions

QtObject {
    id: root

    readonly property bool liquidGlassActive: Config.options.appearance.surfaceStyle === "liquidGlass"
        && RuntimeServices.liquidGlass?.hyprGlassLoaded === true
        && RuntimeServices.liquidGlass?.configApplied === true
    readonly property string systemTheme: Appearance.m3colors.darkmode ? "dark" : "light"
    readonly property bool useInverseForeground: root.liquidGlassActive
        && RuntimeServices.liquidGlass?.glassTheme !== root.systemTheme

    function foreground(fallbackColor) {
        return root.useInverseForeground
            ? Appearance.m3colors.m3inverseOnSurface
            : fallbackColor;
    }

    function secondary(fallbackColor) {
        return root.useInverseForeground
            ? ColorUtils.transparentize(Appearance.m3colors.m3inverseOnSurface, 0.35)
            : fallbackColor;
    }
}
