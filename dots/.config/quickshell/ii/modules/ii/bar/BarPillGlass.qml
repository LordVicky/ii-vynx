import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

PanelWindow {
    id: root

    required property var targetScreen
    required property bool surfaceActive
    required property real surfaceX
    required property real surfaceWidth
    required property real startRadius
    required property real endRadius
    property bool surfaceCommitScheduled: false
    readonly property real autoHideOffset: Number(GlobalStates.barAutoHideOffsets[root.targetScreen?.name ?? ""] ?? 0)

    function scheduleSurfaceCommit() {
        if (root.surfaceCommitScheduled)
            return;

        root.surfaceCommitScheduled = true;
        Qt.callLater(root.forceSurfaceCommit);
    }

    function forceSurfaceCommit() {
        root.surfaceCommitScheduled = false;

        const contentItem = root.contentItem;
        if (!contentItem)
            return;

        contentItem.ensurePolished();
        surfaceVisual.update();
    }

    onSurfaceXChanged: root.scheduleSurfaceCommit()
    onSurfaceWidthChanged: root.scheduleSurfaceCommit()

    screen: root.targetScreen
    visible: root.surfaceActive && root.surfaceWidth > 0
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    implicitWidth: Math.max(1, root.surfaceWidth)
    implicitHeight: Appearance.sizes.baseBarHeight - 8

    WlrLayershell.namespace: "quickshell:bar-glass"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        left: true
        top: !Config.options.bar.bottom
        bottom: Config.options.bar.bottom
    }

    margins {
        left: Math.round(root.surfaceX)
        top: Config.options.bar.bottom
            ? 0
            : (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0) + 4 + root.autoHideOffset
        bottom: Config.options.bar.bottom
            ? (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0) + 4 + root.autoHideOffset
            : 0
    }

    // Visual-only surface; the existing bar keeps all group input handling.
    mask: Region {
        width: 0
        height: 0
    }

    Rectangle {
        id: surfaceVisual

        anchors.fill: parent
        color: RuntimeServices.liquidGlass?.barSurfaceColor ?? "transparent"
        topLeftRadius: root.startRadius
        bottomLeftRadius: root.startRadius
        topRightRadius: root.endRadius
        bottomRightRadius: root.endRadius
        antialiasing: true
    }
}
