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
    function scaled(value) { return value * root.widgetScale; }

    implicitHeight: scaleWrapper.implicitHeight
    implicitWidth: scaleWrapper.implicitWidth

    Item {
        id: scaleWrapper
        implicitHeight: root.scaled(200)
        implicitWidth: root.scaled(200)
        width: implicitWidth
        height: implicitHeight
        Behavior on width { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }
        Behavior on height { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }

        StyledDropShadow {
            target: backgroundShape
            radius: root.scaled(8)
            samples: Math.max(1, Math.ceil(radius * 2 + 1))
        }

        WidgetBlurBackground {
            contrastHost: root
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
            implicitSize: root.scaled(200)

            StyledText {
                font {
                    pixelSize: root.scaled(80)
                    family: Appearance.font.family.expressive
                    weight: Font.Medium
                }
                color: Appearance.colors.colPrimary
                renderType: Text.QtRendering
                text: Weather.data?.temp.substring(0,Weather.data?.temp.length - 1) ?? "--°"
                anchors {
                    right: parent.right
                    top: parent.top
                    rightMargin: root.scaled(16)
                    topMargin: root.scaled(20)
                }
            }

            MaterialSymbol {
                iconSize: root.scaled(80)
                renderType: Text.QtRendering
                color: Appearance.colors.colOnPrimaryContainer
                text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                anchors {
                    left: parent.left
                    bottom: parent.bottom

                    leftMargin: root.scaled(16)
                    bottomMargin: root.scaled(20)
                }
            }
        }
    }

    WidgetResizeHandle {
        hostWidget: root
        currentScale: root.widgetScale
        baseSize: 200
        onRequestScale: (v) => root.dragScale = v
        onRequestCommit: (v) => { Config.options.background.widgets.weather.scale = v; root.dragScale = -1 }
    }
}
