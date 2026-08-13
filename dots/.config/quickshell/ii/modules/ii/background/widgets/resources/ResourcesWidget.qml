import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets
import "NetworkMetric.js" as NetworkMetric

AbstractBackgroundWidget {
    id: root
    configEntryName: "resources"
    hoverEnabled: true

    property real widgetWidth: 564
    property real cardSpacing: 12
    property real cardHeight: 120
    property real cardWidth: (widgetWidth - cardSpacing * 3) / 4
    property bool isVertical: root.configEntry.vertical ?? false
    property bool hasBattery: Battery.available
    readonly property string networkMode: root.configEntry.networkMode ?? "total"
    readonly property real networkSpeed: root.networkMode === "download"
        ? NetworkUsage.networkDownloadSpeed
        : root.networkMode === "upload"
            ? NetworkUsage.networkUploadSpeed
            : NetworkUsage.networkTotalSpeed

    Component.onCompleted: {
        ResourceUsage.resourceWidgetInstances += 1;
        NetworkUsage.activeInstances += 1;
        NetworkUsage.resourceWidgetInstances += 1;
    }
    Component.onDestruction: {
        ResourceUsage.resourceWidgetInstances = Math.max(0, ResourceUsage.resourceWidgetInstances - 1);
        NetworkUsage.activeInstances = Math.max(0, NetworkUsage.activeInstances - 1);
        NetworkUsage.resourceWidgetInstances = Math.max(0, NetworkUsage.resourceWidgetInstances - 1);
    }

    // Live drag override. -1 means "not dragging", which lets widgetScale keep
    // its binding to the persisted config value; a plain assignment during drag
    // would break that binding permanently.
    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.resources.scale ?? 1)
    function scaled(value) { return value * root.widgetScale; }

    implicitWidth: scaleWrapper.implicitWidth
    implicitHeight: scaleWrapper.implicitHeight

    component StatCard: Rectangle {
        id: statCard
        property string icon: ""
        property string value: ""
        property string label: ""
        property int shape: MaterialShape.Shape.Cookie12Sided
        property color bgColor: Appearance.colors.colPrimaryContainer
        property color shapeColor: Appearance.colors.colPrimary

        implicitWidth: root.scaled(root.cardWidth)
        implicitHeight: root.scaled(root.cardHeight)
        radius: root.scaled(Appearance.rounding?.verylarge ?? 30)
        color: root.blur > 0 ? "transparent" : statCard.bgColor

        StyledRectangularShadow {
            target: statCard
            z: -2
            blur: root.scaled(0.9 * Appearance.sizes.elevationMargin)
            offset: Qt.vector2d(0, root.scaled(1))
            spread: root.scaled(1)
        }

        WidgetBlurBackground {
            contrastHost: root
            anchors.fill: parent
            visible: root.blur > 0
            z: -1
            cornerRadius: statCard.radius
            blur: root.blur
            tintColor: statCard.bgColor
            wallpaperPath: root.wallpaperPath
            sourceWidth: root.scaledScreenWidth
            sourceHeight: root.scaledScreenHeight
            offsetX: root.x
            offsetY: root.y
            wallpaperRenderX: root.wallpaperRenderX
            wallpaperRenderY: root.wallpaperRenderY
            wallpaperRenderWidth: root.wallpaperRenderWidth
            wallpaperRenderHeight: root.wallpaperRenderHeight
            parallaxBackdrop: root.parallaxBackdrop
            wallpaperSourceItem: root.wallpaperSourceItem
            hostScale: root.widgetScale
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: root.scaled(14)
            }
            spacing: root.scaled(-4)

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignRight
                shape: statCard.shape
                color: statCard.shapeColor
                colSymbol: Appearance.colors.colOnPrimary
                text: statCard.icon
                iconSize: root.scaled(18)
                fill: 1
                padding: root.scaled(6)
                implicitWidth: root.scaled(34)
                implicitHeight: root.scaled(34)
            }

            Item { Layout.fillHeight: true }

            AnimatedValueText {
                Layout.fillWidth: true
                text: statCard.value
                pixelSize: root.scaled(Appearance.font.pixelSize.hugeass)
                transitionOffset: root.scaled(4)
                weight: Font.Bold
                textColor: Appearance.colors.colOnPrimaryContainer
            }

            StyledText {
                text: statCard.label
                font.pixelSize: root.scaled(Appearance.font.pixelSize.small)
                renderType: Text.QtRendering
                color: root.adaptiveSubtextColor
            }
        }
    }

    Item {
        id: scaleWrapper
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        width: implicitWidth
        height: implicitHeight
        Behavior on width { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }
        Behavior on height { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }

    Grid {
        id: row
        columns: root.isVertical ? 1 : 4
        rows: root.isVertical ? 4 : 1
        spacing: root.scaled(root.cardSpacing)

        Behavior on columns {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        StatCard {
            icon: "planner_review"
            value: Math.round(ResourceUsage.cpuUsage * 100) + "%"
            label: "CPU"
            shape: MaterialShape.Shape.Gem
        }
        StatCard {
            icon: "memory"
            value: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%"
            label: "RAM"
            shape: MaterialShape.Shape.Cookie4Sided
            bgColor: Appearance.colors.colSecondaryContainer
            shapeColor: Appearance.colors.colSecondary
        }
        StatCard {
            icon: root.hasBattery ? "battery_full" : "storage"
            value: root.hasBattery
                ? Math.round(Battery.percentage * 100) + "%"
                : Math.round(ResourceUsage.diskUsedPercentage * 100) + "%"
            label: root.hasBattery ? "Battery" : "Disk"
            shape: MaterialShape.Shape.Cookie12Sided
            bgColor: Appearance.colors.colTertiaryContainer
            shapeColor: Appearance.colors.colTertiary
        }
        StatCard {
            icon: "swap_vert"
            value: NetworkMetric.formatSpeed(root.networkSpeed)
            label: Translation.tr("Network")
            shape: MaterialShape.Shape.Cookie9Sided
            bgColor: Appearance.colors.colSurfaceContainerHigh
            shapeColor: Appearance.colors.colPrimary
        }
    }
    Rectangle {
        id: toggleHandle
        width: root.scaled(16)
        height: root.scaled(16)
        radius: root.scaled(6)
        color: Appearance.colors.colOnPrimaryContainer
        anchors {
            left: parent.right
            top: parent.top
            margins: root.scaled(-6)
        }
        opacity: root.containsMouse || toggleArea.containsMouse ? 0.7 : 0
        visible: opacity > 0 && !Config.options.background.widgetsLocked

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "rotate_right"
            iconSize: root.scaled(11)
            renderType: Text.QtRendering
            color: Appearance.colors.colPrimaryContainer

            RotationAnimation on rotation {
                running: toggleArea.containsMouse
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
            }
        }

        MouseArea {
            id: toggleArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.isVertical = !root.isVertical
                root.configEntry.vertical = root.isVertical
            }
        }
    }
    }

    WidgetResizeHandle {
        hostWidget: root
        currentScale: root.widgetScale
        baseSize: root.isVertical ? root.cardWidth : root.widgetWidth
        onRequestScale: (v) => root.dragScale = v
        onRequestCommit: (v) => { Config.options.background.widgets.resources.scale = v; root.dragScale = -1 }
    }
}
