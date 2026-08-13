import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "resources"
    hoverEnabled: true

    property real widgetWidth: 420
    property real cardSpacing: 12
    property real cardHeight: 120
    property real cardWidth: (widgetWidth - cardSpacing * 2) / 3
    property bool isVertical: root.configEntry.vertical ?? false
    property bool hasBattery: Battery.available

    // Live drag override. -1 means "not dragging", which lets widgetScale keep
    // its binding to the persisted config value; a plain assignment during drag
    // would break that binding permanently.
    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.resources.scale ?? 1)

    implicitWidth: scaleWrapper.implicitWidth * root.widgetScale
    implicitHeight: scaleWrapper.implicitHeight * root.widgetScale

    component StatCard: Rectangle {
        id: statCard
        property string icon: ""
        property string value: ""
        property string label: ""
        property int shape: MaterialShape.Shape.Cookie12Sided
        property color bgColor: Appearance.colors.colPrimaryContainer
        property color shapeColor: Appearance.colors.colPrimary

        implicitWidth: root.cardWidth
        implicitHeight: root.cardHeight
        radius: Appearance.rounding?.verylarge ?? 30
        color: root.blur > 0 ? "transparent" : statCard.bgColor

        StyledRectangularShadow {
            target: statCard
            z: -2
        }

        WidgetBlurBackground {
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
                margins: 14
            }
            spacing: -4

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignRight
                shape: statCard.shape
                color: statCard.shapeColor
                colSymbol: Appearance.colors.colOnPrimary
                text: statCard.icon
                iconSize: 18
                fill: 1
                padding: 6
                implicitWidth: 34
                implicitHeight: 34
            }

            Item { Layout.fillHeight: true }

            StyledText {
                text: statCard.value
                font.pixelSize: Appearance.font.pixelSize.hugeass
                font.weight: Font.Bold
                color: Appearance.colors.colOnPrimaryContainer
            }

            StyledText {
                text: statCard.label
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnPrimaryContainer
                opacity: 0.6
            }
        }
    }

    Item {
        id: scaleWrapper
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        width: implicitWidth
        height: implicitHeight
        transformOrigin: Item.TopLeft
        scale: root.widgetScale
        Behavior on scale { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }

    Grid {
        id: row
        columns: root.isVertical ? 1 : 3
        rows: root.isVertical ? 3 : 1
        spacing: root.cardSpacing

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
    }
    Rectangle {
        id: toggleHandle
        width: 16
        height: 16
        radius: 6
        color: Appearance.colors.colOnPrimaryContainer
        anchors {
            left: parent.right
            top: parent.top
            margins: -6
        }
        opacity: root.containsMouse || toggleArea.containsMouse ? 0.7 : 0
        visible: opacity > 0 && !Config.options.background.widgetsLocked

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "rotate_right"
            iconSize: 11
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
        baseSize: scaleWrapper.implicitWidth
        onRequestScale: (v) => root.dragScale = v
        onRequestCommit: (v) => { Config.options.background.widgets.resources.scale = v; root.dragScale = -1 }
    }
}