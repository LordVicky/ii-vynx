import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.bar as Bar

Item { // Bar content region
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    property bool showBarBackground: false
    readonly property bool standaloneLiquidGlassIslandActive: GlobalStates.verticalBarGlassSurfaceActive
        && !root.showBarBackground
        && Config.options.bar.barGroupStyle === 1

    component HorizontalBarSeparator: Rectangle {
        Layout.leftMargin: Appearance.sizes.baseBarHeight / 3
        Layout.rightMargin: Appearance.sizes.baseBarHeight / 3
        Layout.fillWidth: true
        implicitHeight: 1
        color: Appearance.colors.colOutlineVariant
    }


    ////// Definning places of center modules //////
    property var fullModel: Config.options?.bar?.layouts?.center

    property int centerIdx: (fullModel || []).findIndex(item => item.centered)

    property var leftList: centerIdx === -1 ? [] : fullModel.slice(0, centerIdx)
    property var centerList: centerIdx === -1 ? fullModel : [fullModel[centerIdx]]
    property var rightList: centerIdx === -1 ? [] : fullModel.slice(centerIdx + 1)

    // Background shadow
    Loader {
        active: root.showBarBackground
            && Config.options.bar.cornerStyle === 1
            && Config.options.bar.floatStyleShadow
            && !GlobalStates.verticalBarGlassSurfaceActive
        anchors.fill: barBackground
        sourceComponent: StyledRectangularShadow {
            anchors.fill: undefined // The loader's anchors act on this, and this should not have any anchor
            target: barBackground
        }
    }
    // Background
    Rectangle {
        id: barBackground
        anchors {
            fill: parent
            margins: Config.options.bar.cornerStyle === 1 ? (Appearance.sizes.hyprlandGapsOut) : 0 // idk why but +1 is needed
        }
        z: -10 // making sure its behind everything
        color: root.showBarBackground && !GlobalStates.verticalBarGlassSurfaceActive
            ? Appearance.colors.colLayer0
            : "transparent"
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.cornerStyle === 1 && !GlobalStates.verticalBarGlassSurfaceActive ? 1 : 0
        border.color: root.showBarBackground && !GlobalStates.verticalBarGlassSurfaceActive
            ? Appearance.colors.colLayer0Border
            : "transparent"
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    FocusedScrollMouseArea { // Top section | scroll to change brightness
        id: barTopSectionMouseArea
        anchors.top: parent.top
        

        anchors {
            top: parent.top
            bottom: middleSection.top
            left: parent.left
            right: parent.right
        }
        implicitWidth: Appearance.sizes.baseVerticalBarWidth
        height: (root.height - middleSection.height) / 2
        width: Appearance.sizes.verticalBarWidth

        onScrollDown: Brightness.decreaseBrightness()
        onScrollUp: Brightness.increaseBrightness()
        onMovedAway: GlobalStates.osdBrightnessOpen = false
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }

    }

    Item {
        id: topStopper
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: Math.ceil(Appearance.rounding.screenRounding / 2.5)
        }
        height: 1
    }

    ColumnLayout { // Top section
        id: topSection
        anchors {
            top: topStopper.bottom
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 4

        Repeater {
            id: leftRepeater
            model: Config.options.bar.layouts.left
            delegate: Bar.BarComponent {
                vertical: true
                list: leftRepeater.model
                barSection: 0
                barBackgroundVisible: root.showBarBackground
                barSurfaceY: topSection.y + y
                barSurfaceScreen: root.screen
                standaloneLiquidGlassIslandActive: root.standaloneLiquidGlassIslandActive
            }
        }
    }

    Item {
        id: middleSection
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
        }

        ColumnLayout {
            id: middleLeftSection
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: centerCenter.top
                bottomMargin: 4
            }
            Repeater {
                id: middleLeftRepeater
                model: root.leftList
                delegate: Bar.BarComponent {
                    vertical: true
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    barBackgroundVisible: root.showBarBackground
                    barSurfaceY: middleSection.y + middleLeftSection.y + y
                    barSurfaceScreen: root.screen
                    standaloneLiquidGlassIslandActive: root.standaloneLiquidGlassIslandActive
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id) // we have to recalculate the index because repeater.model has changed
                }
            }
        }

        ColumnLayout { //center
            id: centerCenter
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }
            Repeater {
                model: root.centerList
                delegate: Bar.BarComponent {
                    vertical: true
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    barBackgroundVisible: root.showBarBackground
                    barSurfaceY: middleSection.y + centerCenter.y + y
                    barSurfaceScreen: root.screen
                    standaloneLiquidGlassIslandActive: root.standaloneLiquidGlassIslandActive
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id)
                }
            }
        }

        ColumnLayout {
            id: middleRightSection
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: centerCenter.bottom
                topMargin: 4
            }
            Repeater {
                id: middleRightRepeater
                model: root.rightList
                delegate: Bar.BarComponent {
                    vertical: true
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    barBackgroundVisible: root.showBarBackground
                    barSurfaceY: middleSection.y + middleRightSection.y + y
                    barSurfaceScreen: root.screen
                    standaloneLiquidGlassIslandActive: root.standaloneLiquidGlassIslandActive
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id)
                }
            }
        }

    }

    readonly property bool middleIslandHasContent: middleLeftSection.height > 0
        || centerCenter.height > 0
        || middleRightSection.height > 0
    readonly property real middleIslandLocalTop: {
        let top = 0;
        let hasValue = false;
        if (middleLeftSection.height > 0) {
            top = middleLeftSection.y;
            hasValue = true;
        }
        if (centerCenter.height > 0) {
            top = hasValue ? Math.min(top, centerCenter.y) : centerCenter.y;
            hasValue = true;
        }
        if (middleRightSection.height > 0)
            top = hasValue ? Math.min(top, middleRightSection.y) : middleRightSection.y;
        return top;
    }
    readonly property real middleIslandLocalBottom: {
        let bottom = 0;
        if (middleLeftSection.height > 0)
            bottom = middleLeftSection.y + middleLeftSection.height;
        if (centerCenter.height > 0)
            bottom = Math.max(bottom, centerCenter.y + centerCenter.height);
        if (middleRightSection.height > 0)
            bottom = Math.max(bottom, middleRightSection.y + middleRightSection.height);
        return bottom;
    }
    readonly property real middleIslandY: middleSection.y + root.middleIslandLocalTop
    readonly property real middleIslandHeight: Math.max(0, root.middleIslandLocalBottom - root.middleIslandLocalTop)

    ColumnLayout { // Bottom section
        id: bottomSection
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: bottomStopper.top
        }
        spacing: 4

        Repeater {
            id: rightRepeater
            model: Config.options.bar.layouts.right
            delegate: Bar.BarComponent {
                vertical: true
                list: rightRepeater.model
                barSection: 2
                barBackgroundVisible: root.showBarBackground
                barSurfaceY: bottomSection.y + y
                barSurfaceScreen: root.screen
                standaloneLiquidGlassIslandActive: root.standaloneLiquidGlassIslandActive
            }
        }
    }

    LazyLoader {
        active: root.standaloneLiquidGlassIslandActive && topSection.height > 0
        component: VerticalBarPillGlass {
            targetScreen: root.screen
            surfaceActive: root.standaloneLiquidGlassIslandActive
            surfaceY: topSection.y
            surfaceHeight: topSection.height
            startRadius: Appearance.rounding.full
            endRadius: Appearance.rounding.full
        }
    }

    LazyLoader {
        active: root.standaloneLiquidGlassIslandActive && root.middleIslandHasContent
        component: VerticalBarPillGlass {
            targetScreen: root.screen
            surfaceActive: root.standaloneLiquidGlassIslandActive
            surfaceY: root.middleIslandY
            surfaceHeight: root.middleIslandHeight
            startRadius: Appearance.rounding.full
            endRadius: Appearance.rounding.full
        }
    }

    LazyLoader {
        active: root.standaloneLiquidGlassIslandActive && bottomSection.height > 0
        component: VerticalBarPillGlass {
            targetScreen: root.screen
            surfaceActive: root.standaloneLiquidGlassIslandActive
            surfaceY: bottomSection.y
            surfaceHeight: bottomSection.height
            startRadius: Appearance.rounding.full
            endRadius: Appearance.rounding.full
        }
    }

    Item {
        id: bottomStopper
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            bottomMargin: Math.ceil(Appearance.rounding.screenRounding / 2.5)
        }
        height: 1
    }

    FocusedScrollMouseArea { // Bottom section | scroll to change volume
        id: barBottomSectionMouseArea

        z: -1
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            top: middleSection.bottom
        }
        implicitWidth: Appearance.sizes.baseVerticalBarWidth
        
        onScrollDown: Audio.decrementVolume();
        onScrollUp: Audio.incrementVolume();
        onMovedAway: GlobalStates.osdVolumeOpen = false;
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }
        }
    }
}
