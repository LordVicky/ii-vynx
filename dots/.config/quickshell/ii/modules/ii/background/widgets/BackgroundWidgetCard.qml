import QtQuick
import qs
import qs.modules.common
import qs.modules.common.widgets

// Shared card chrome for desktop widgets: frosted panel, drop shadow and
// drag-to-resize, so a widget only has to supply its own content.
//
// The nine service-backed widgets (todo, pomodoro, lyrics, network, clipboard,
// updates, privacy, songRec, battery) all wear the identical panel, so the
// chrome lives here instead of being copy-pasted. The older widgets predate
// this and still inline their own; they can migrate as they're touched.
//
// Usage from an AbstractBackgroundWidget subclass:
//
//     BackgroundWidgetCard {
//         id: card
//         host: root
//         scaleFactor: root.widgetScale
//         baseWidth: 276; baseHeight: 160
//         onRequestScale: (v) => root.dragScale = v
//         onCommitScale: (v) => { Config...scale = v; root.dragScale = -1 }
//         <content items here>
//     }
Item {
    id: card

    property Item host                 // the AbstractBackgroundWidget root
    property real baseWidth: 276       // UNSCALED content size
    property real baseHeight: 252
    property real scaleFactor: 1
    property real cornerRadius: Appearance.rounding?.verylarge ?? 30
    property real contentPadding: 16
    property bool showResizeHandle: true
    readonly property real animatedWidth: scaleWrapper.width * scaleWrapper.scale

    signal requestScale(real newScale)  // live, during drag
    signal commitScale(real newScale)   // on release

    // Content goes into the padded area inside the frosted panel.
    default property alias content: contentHolder.data

    function scaled(value) {
        return value * card.scaleFactor;
    }

    implicitWidth: baseWidth * scaleFactor
    implicitHeight: baseHeight * scaleFactor

    Item {
        id: scaleWrapper
        width: card.implicitWidth
        height: card.implicitHeight
        Behavior on width { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }
        Behavior on height { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }

        StyledDropShadow {
            target: contentRect
            radius: card.scaled(8)
            samples: Math.max(1, Math.ceil(radius * 2 + 1))
        }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: "transparent"
            radius: card.scaled(card.cornerRadius)

            WidgetBlurBackground {
                anchors.fill: parent
                adaptiveContrast: true
                contrastHost: card.host
                cornerRadius: contentRect.radius
                blur: card.host?.blur ?? 0.6
                wallpaperPath: card.host?.wallpaperPath ?? ""
                sourceWidth: card.host?.scaledScreenWidth ?? 0
                sourceHeight: card.host?.scaledScreenHeight ?? 0
                offsetX: card.host?.x ?? 0
                offsetY: card.host?.y ?? 0
                wallpaperRenderX: card.host?.wallpaperRenderX ?? 0
                wallpaperRenderY: card.host?.wallpaperRenderY ?? 0
                wallpaperRenderWidth: card.host?.wallpaperRenderWidth ?? 0
                wallpaperRenderHeight: card.host?.wallpaperRenderHeight ?? 0
                parallaxBackdrop: card.host?.parallaxBackdrop ?? true
                wallpaperSourceItem: card.host?.wallpaperSourceItem ?? null
                hostScale: card.scaleFactor
            }

            Item {
                id: contentHolder
                anchors.fill: parent
                anchors.margins: card.scaled(card.contentPadding)
            }
        }
    }

    WidgetResizeHandle {
        hostWidget: card.host
        visible: card.showResizeHandle && opacity > 0 && !Config.options.background.widgetsLocked
        currentScale: card.scaleFactor
        baseSize: card.baseWidth
        onRequestScale: (v) => card.requestScale(v)
        onRequestCommit: (v) => card.commitScale(v)
    }
}
