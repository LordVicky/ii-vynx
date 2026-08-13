import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "weather"
    hoverEnabled: true

    // Live drag override. -1 means "not dragging", which lets widgetScale keep
    // its binding to the persisted config value; a plain assignment during drag
    // would break that binding permanently.
    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.weather.scale ?? 1)

    implicitHeight: scaleWrapper.implicitHeight * root.widgetScale
    implicitWidth: scaleWrapper.implicitWidth * root.widgetScale

    Item {
        id: scaleWrapper
        implicitHeight: backgroundShape.implicitHeight
        implicitWidth: backgroundShape.implicitWidth
        width: implicitWidth
        height: implicitHeight
        transformOrigin: Item.TopLeft
        scale: root.widgetScale
        Behavior on scale { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }

        StyledDropShadow {
            target: backgroundShape
        }

        WidgetBlurBackground {
            anchors.fill: backgroundShape
            cornerRadius: backgroundShape.width / 2
            blur: root.blur
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

        MaterialShape {
            id: backgroundShape
            anchors.fill: parent
            shape: MaterialShape.Shape.Pill
            color: root.blur > 0 ? "transparent" : Appearance.colors.colPrimaryContainer
            implicitSize: 200

            StyledText {
                font {
                    pixelSize: 80
                    family: Appearance.font.family.expressive
                    weight: Font.Medium
                }
                color: Appearance.colors.colPrimary
                text: Weather.data?.temp.substring(0,Weather.data?.temp.length - 1) ?? "--°"
                anchors {
                    right: parent.right
                    top: parent.top
                    rightMargin: 16
                    topMargin: 20
                }
            }

            MaterialSymbol {
                iconSize: 80
                color: Appearance.colors.colOnPrimaryContainer
                text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                anchors {
                    left: parent.left
                    bottom: parent.bottom

                    leftMargin: 16
                    bottomMargin: 20
                }
            }
        }
    }

    WidgetResizeHandle {
        hostWidget: root
        currentScale: root.widgetScale
        baseSize: scaleWrapper.implicitWidth
        onRequestScale: (v) => root.dragScale = v
        onRequestCommit: (v) => { Config.options.background.widgets.weather.scale = v; root.dragScale = -1 }
    }
}
