import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

PanelWindow {
    id: root

    required property bool isOnRight
    required property bool surfaceActive
    property int sidebarWidth: Appearance.sizes.sidebarWidth

    readonly property real contentPadding: 10
    readonly property real systemRowHeight: 48
    readonly property real sliderHeight: 47
    readonly property real androidSpacing: 6
    readonly property real androidPadding: 6
    readonly property real androidCellHeight: 56
    readonly property bool quickSlidersVisible: {
        const sliders = Config.options.sidebar.quickSliders;
        if (!sliders.enable)
            return false;
        return sliders.showMic || sliders.showVolume || sliders.showBrightness;
    }
    readonly property bool androidMaskActive: root.surfaceActive
        && Config.options.sidebar.quickToggles.style === "android"
    readonly property real androidMaskTop: root.contentPadding
        + 5
        + root.systemRowHeight
        + root.contentPadding
        + (root.quickSlidersVisible ? root.sliderHeight + root.contentPadding : 0)
    readonly property real androidMaskWidth: Math.max(0, root.width - root.contentPadding * 2)
    readonly property var androidMaskRects: {
        const columns = Math.max(1, Number(Config.options.sidebar.quickToggles.android.columns) || 1);
        const toggles = Config.ready ? Config.options.sidebar.quickToggles.android.toggles : [];
        const availableWidth = root.androidMaskWidth
            - root.androidPadding * 2
            - root.androidSpacing * columns;
        const cellWidth = availableWidth / columns;
        const rects = [];
        let row = 0;
        let column = 0;

        for (let i = 0; i < toggles.length; i++) {
            const toggle = toggles[i];
            if (!toggle)
                continue;

            const size = Math.max(1, Math.min(columns, Number(toggle.size) || 1));
            if (column + size > columns) {
                row += 1;
                column = 0;
            }

            rects.push({
                x: root.androidPadding + column * (cellWidth + root.androidSpacing),
                y: root.androidPadding + row * (root.androidCellHeight + root.androidSpacing),
                width: cellWidth * size + root.androidSpacing * (size - 1),
                height: root.androidCellHeight,
            });
            column += size;
        }

        return rects;
    }

    visible: root.surfaceActive && GlobalStates.sidebarRightOpen
    exclusionMode: ExclusionMode.Normal
    focusable: false
    color: "transparent"
    implicitWidth: root.sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin

    WlrLayershell.namespace: "quickshell:sidebar-dashboard-glass"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        top: true
        bottom: true
        left: !root.isOnRight
        right: root.isOnRight
    }

    margins {
        top: Appearance.sizes.hyprlandGapsOut
        bottom: Appearance.sizes.hyprlandGapsOut
        left: root.isOnRight ? 0 : Appearance.sizes.hyprlandGapsOut
        right: root.isOnRight ? Appearance.sizes.hyprlandGapsOut : 0
    }

    // Visual-only surface. Pointer and keyboard handling stay on the existing
    // interactive dashboard window so glass cannot intercept sidebar input.
    mask: Region {
        width: 0
        height: 0
    }

    Rectangle {
        anchors.fill: parent
        color: RuntimeServices.liquidGlass?.sidebarSurfaceColor ?? "transparent"
        radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
        antialiasing: true
    }

    // Prototype-only secondary mask. High alpha identifies the Android control
    // silhouettes to the local HyprGlass shader; the shader removes these marker
    // pixels before compositing, so the real interactive controls remain the only
    // visible foreground UI.
    Item {
        x: root.contentPadding
        y: root.androidMaskTop
        width: root.androidMaskWidth
        height: Math.max(0, root.height - y)
        visible: root.androidMaskActive

        Repeater {
            model: root.androidMaskRects

            delegate: Rectangle {
                required property var modelData
                x: modelData.x
                y: modelData.y
                width: modelData.width
                height: modelData.height
                radius: height / 2
                antialiasing: true
                color: {
                    const base = RuntimeServices.liquidGlass?.sidebarSurfaceColor ?? "#ffffff";
                    return Qt.rgba(base.r, base.g, base.b, 0.80);
                }
            }
        }
    }
}
