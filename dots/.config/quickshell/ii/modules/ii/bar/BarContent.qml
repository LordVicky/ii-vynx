import qs.modules.ii.bar.weather
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

import Quickshell.Io

Item { // Bar content region
    id: root

    property var screen: root.QsWindow.window?.screen
    property int monitorIndex
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0
    readonly property int centerSideModuleWidth: (useShortenedForm == 2) ? Appearance.sizes.barCenterSideModuleWidthHellaShortened : (useShortenedForm == 1) ? Appearance.sizes.barCenterSideModuleWidthShortened : Appearance.sizes.barCenterSideModuleWidth

    property bool hasActiveWindows: false
    property bool showBarBackground: root.hasActiveWindows && Config.options.bar.barBackgroundStyle === 2 || Config.options.bar.barBackgroundStyle === 1
    readonly property bool liquidGlassSurfaceActive: Config.options.appearance.surfaceStyle === "liquidGlass"
        && RuntimeServices.liquidGlass?.ready === true
        && RuntimeServices.liquidGlass?.hyprGlassLoaded === true
        && RuntimeServices.liquidGlass?.configApplied === true
    readonly property bool dedicatedLiquidGlassSurfaceActive: root.liquidGlassSurfaceActive
        && RuntimeServices.liquidGlass?.dedicatedBarSurfaceActive === true
    readonly property bool standaloneLiquidGlassIslandActive: root.dedicatedLiquidGlassSurfaceActive
        && !root.showBarBackground
        && Config.options.bar.barGroupStyle === 1
    readonly property color liquidGlassBarSurfaceColor: RuntimeServices.liquidGlass?.barSurfaceColor ?? ColorUtils.transparentize(Appearance.colors.colLayer0Base, 0.82)

    Connections {
        enabled: Config.options.bar.barBackgroundStyle === 2
        target: HyprlandData
        function onWindowListChanged() {
            const monitor = HyprlandData.monitors.find(m => m.id === monitorIndex);
            const wsId = monitor?.activeWorkspace?.id;

            const hasWindow = wsId ? HyprlandData.windowList.some(w => w.workspace.id === wsId && !w.floating) : false;

            root.hasActiveWindows = hasWindow
        }
    }

    ////// Definning places of center modules //////
    property var fullModel: Config.options.bar.layouts.center

    property var leftList: []
    property var centerList: []
    property var rightList: []

    onFullModelChanged: {
        const idx = fullModel.findIndex(item => item.centered)
        
        if (idx === -1) {
            leftList = []
            centerList = fullModel
            rightList = []
            return
        }

        leftList = fullModel.slice(0, idx)
        centerList = [fullModel[idx]]
        rightList = fullModel.slice(idx + 1)
    }

    // Background shadow. In Liquid Glass the shadow becomes part of the layer
    // alpha mask, producing a second glass band around the floating bar. Let
    // HyprGlass provide the edge depth instead and keep this Material-only.
    Loader {
        active: root.showBarBackground
            && Config.options.bar.cornerStyle === 1
            && Config.options.bar.floatStyleShadow
            && !root.liquidGlassSurfaceActive
        anchors.fill: barBackground
        sourceComponent: StyledRectangularShadow {
            anchors.fill: undefined // The loader's anchors act on this, and this should not have any anchor
            target: barBackground
        }
    }
    // Background
    Rectangle {
        id: barBackground
        z: -10 // making sure its behind everything
        anchors {
            fill: parent
            margins: Config.options.bar.cornerStyle === 1 ? (Appearance.sizes.hyprlandGapsOut) : 0 // idk why but +1 is needed
        }
        color: root.showBarBackground
            ? (Config.options.appearance.surfaceStyle === "liquidGlass"
                ? (root.dedicatedLiquidGlassSurfaceActive
                    ? "transparent"
                    : (root.liquidGlassSurfaceActive
                        ? root.liquidGlassBarSurfaceColor
                        : ColorUtils.transparentize(Appearance.colors.colLayer0Base, 0.18)))
                : Appearance.colors.colLayer0)
            : "transparent"
        radius: Config.options.bar.cornerStyle === 1
            ? (root.liquidGlassSurfaceActive ? height / 2 : Appearance.rounding.windowRounding)
            : 0
        // The Material floating outline is redundant with HyprGlass's own
        // Fresnel/specular edge and would otherwise tint the glass perimeter.
        border.width: Config.options.bar.cornerStyle === 1 && !root.liquidGlassSurfaceActive ? 1 : 0
        border.color: root.showBarBackground
            ? (Config.options.appearance.surfaceStyle === "liquidGlass"
                ? ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.82)
                : Appearance.colors.colLayer0Border)
            : "transparent"

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    FocusedScrollMouseArea { // Left side | scroll to change brightness
        id: barLeftSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            right: middleSection.left
        }
        implicitHeight: Appearance.sizes.baseBarHeight

        onScrollDown: Brightness.decreaseBrightness()
        onScrollUp: Brightness.increaseBrightness()
        onMovedAway: GlobalStates.osdBrightnessOpen = false
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }

        ScrollHint {
            reveal: barLeftSideMouseArea.hovered
            icon: Hyprsunset.gamma === 100 ? "light_mode" : "wb_twilight"
            tooltipText: Translation.tr("Scroll to change brightness")
            side: "left"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    

    Item {
        id: leftStopper
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            leftMargin: Math.ceil(Appearance.rounding.screenRounding / 2)
        }
        width: 1
    }

    RowLayout { // Left section
        id: leftSection
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: leftStopper.right
        }
        spacing: 4

        Repeater {
            id: leftRepeater
            model: Config.options.bar.layouts.left
            delegate: BarComponent {
                list: Config.options.bar.layouts.left
                barSection: 0
                barBackgroundVisible: root.showBarBackground
                barSurfaceX: leftSection.x + x
                standaloneLiquidGlassIslandActive: root.standaloneLiquidGlassIslandActive
            }
        }
    }

    Item { // Middle section positioning anchor
        id: middleSection
        width: 0
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }

        RowLayout {
            id: middleLeftSection
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: centerCenter.left
                rightMargin: 4
            }
            Repeater {
                id: middleLeftRepeater
                model: root.leftList
                delegate: BarComponent {
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    barBackgroundVisible: root.showBarBackground
                    barSurfaceX: middleSection.x + middleLeftSection.x + x
                    standaloneLiquidGlassIslandActive: root.standaloneLiquidGlassIslandActive
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id) // we have to recalculate the index because repeater.model has changed
                }
            }
        }

        RowLayout { //center
            id: centerCenter
            anchors {
                top: parent.top
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
            }
            Repeater {
                model: root.centerList
                delegate: BarComponent {
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    barBackgroundVisible: root.showBarBackground
                    barSurfaceX: middleSection.x + centerCenter.x + x
                    standaloneLiquidGlassIslandActive: root.standaloneLiquidGlassIslandActive
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id)
                }
            }
        }

        RowLayout {
            id: middleRightSection
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: centerCenter.right
                leftMargin: 4
            }
            Repeater {
                id: middleRightRepeater
                model: root.rightList
                delegate: BarComponent {
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    barBackgroundVisible: root.showBarBackground
                    barSurfaceX: middleSection.x + middleRightSection.x + x
                    standaloneLiquidGlassIslandActive: root.standaloneLiquidGlassIslandActive
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id)
                }
            }
        }

    }

    RowLayout { // Right section
        id: rightSection
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: rightStopper.left
            rightMargin: Math.ceil(Appearance.rounding.screenRounding / 2)
        }
        spacing: 4

        Repeater {
            id: rightRepeater
            model: Config.options.bar.layouts.right
            delegate: BarComponent {
                list: rightRepeater.model
                barSection: 2
                barBackgroundVisible: root.showBarBackground
                barSurfaceX: rightSection.x + x
                standaloneLiquidGlassIslandActive: root.standaloneLiquidGlassIslandActive
            }
        }
    }

    readonly property bool middleIslandHasContent: middleLeftSection.width > 0
        || centerCenter.width > 0
        || middleRightSection.width > 0
    readonly property real middleIslandLocalLeft: {
        let left = 0;
        let hasValue = false;
        if (middleLeftSection.width > 0) {
            left = middleLeftSection.x;
            hasValue = true;
        }
        if (centerCenter.width > 0) {
            left = hasValue ? Math.min(left, centerCenter.x) : centerCenter.x;
            hasValue = true;
        }
        if (middleRightSection.width > 0)
            left = hasValue ? Math.min(left, middleRightSection.x) : middleRightSection.x;
        return left;
    }
    readonly property real middleIslandLocalRight: {
        let right = 0;
        if (middleLeftSection.width > 0)
            right = middleLeftSection.x + middleLeftSection.width;
        if (centerCenter.width > 0)
            right = Math.max(right, centerCenter.x + centerCenter.width);
        if (middleRightSection.width > 0)
            right = Math.max(right, middleRightSection.x + middleRightSection.width);
        return right;
    }
    readonly property real middleIslandX: middleSection.x + root.middleIslandLocalLeft
    readonly property real middleIslandWidth: Math.max(0, root.middleIslandLocalRight - root.middleIslandLocalLeft)

    LazyLoader {
        active: root.standaloneLiquidGlassIslandActive && leftSection.width > 0
        component: BarPillGlass {
            targetScreen: root.screen
            surfaceActive: root.standaloneLiquidGlassIslandActive
            segmentKey: "island:left"
            surfaceX: leftSection.x
            surfaceWidth: leftSection.width
            startRadius: Appearance.rounding.full
            endRadius: Appearance.rounding.full
        }
    }

    LazyLoader {
        active: root.standaloneLiquidGlassIslandActive && root.middleIslandHasContent
        component: BarPillGlass {
            targetScreen: root.screen
            surfaceActive: root.standaloneLiquidGlassIslandActive
            segmentKey: "island:center"
            surfaceX: root.middleIslandX
            surfaceWidth: root.middleIslandWidth
            startRadius: Appearance.rounding.full
            endRadius: Appearance.rounding.full
        }
    }

    LazyLoader {
        active: root.standaloneLiquidGlassIslandActive && rightSection.width > 0
        component: BarPillGlass {
            targetScreen: root.screen
            surfaceActive: root.standaloneLiquidGlassIslandActive
            segmentKey: "island:right"
            surfaceX: rightSection.x
            surfaceWidth: rightSection.width
            startRadius: Appearance.rounding.full
            endRadius: Appearance.rounding.full
        }
    }


    Item {
        id: rightStopper
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }
        width: 1
    }

    

    FocusedScrollMouseArea { // Right side | scroll to change volume
        id: barRightSideMouseArea

        z: -1
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: middleSection.right
            right: parent.right
        }
        implicitHeight: Appearance.sizes.baseBarHeight

        onScrollDown: Audio.decrementVolume();
        onScrollUp: Audio.incrementVolume();
        onMovedAway: GlobalStates.osdVolumeOpen = false;
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }
        }

        ScrollHint {
            reveal: barRightSideMouseArea.hovered
            icon: "volume_up"
            tooltipText: Translation.tr("Scroll to change volume")
            side: "right"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
