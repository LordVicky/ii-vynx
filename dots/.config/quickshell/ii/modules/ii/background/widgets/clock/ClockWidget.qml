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

    configEntryName: "clock"
    hoverEnabled: true

    // Live drag override. -1 means "not dragging", which lets widgetScale keep
    // its binding to the persisted config value; a plain assignment during drag
    // would break that binding permanently.
    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.clock.scale ?? 1)

    implicitHeight: scaleWrapper.implicitHeight * root.widgetScale
    implicitWidth: scaleWrapper.implicitWidth * root.widgetScale

    readonly property string clockStyle: GlobalStates.screenLocked ? Config.options.background.widgets.clock.styleLocked : Config.options.background.widgets.clock.style
    readonly property bool forceCenter: (GlobalStates.screenLocked && Config.options.lock.centerClock)
    readonly property bool shouldShow: (!Config.options.background.widgets.clock.showOnlyWhenLocked || GlobalStates.screenLocked)
    property bool wallpaperSafetyTriggered: false
    property bool isCovered: false
    needsColText: clockStyle === "digital"
    x: forceCenter ? ((root.screenWidth - root.width) / 2) : targetX
    y: forceCenter ? ((root.screenHeight - root.height) / 2) : targetY
    visibleWhenLocked: true

    property var textHorizontalAlignment: {
        if (!Config.options.background.widgets.clock.digital.adaptiveAlignment || root.forceCenter || Config.options.background.widgets.clock.digital.vertical) 
            return Text.AlignHCenter;
        if (root.x < root.scaledScreenWidth / 3)
            return Text.AlignLeft;
        if (root.x > root.scaledScreenWidth * 2 / 3)
            return Text.AlignRight;
        return Text.AlignHCenter;
    }

    Item {
        id: scaleWrapper
        implicitWidth: contentColumn.implicitWidth
        implicitHeight: contentColumn.implicitHeight
        width: implicitWidth
        height: implicitHeight
        transformOrigin: Item.TopLeft
        scale: root.widgetScale
        Behavior on scale { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }

        // Clock styles (cookie/digital/pixel) draw their own shapes/glyphs directly on
        // the wallpaper with no card behind them. Like media, the frosted backing
        // plate is additive here: invisible at blur = 0, fading in as blur increases.
        WidgetBlurBackground {
            anchors.centerIn: parent
            width: contentColumn.implicitWidth + 40
            height: contentColumn.implicitHeight + 32
            visible: root.blur > 0.01
            opacity: root.blur
            cornerRadius: Appearance.rounding?.verylarge ?? 30
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

        Column {
            id: contentColumn
            anchors.centerIn: parent
            spacing: 10

            FadeLoader {
                id: cookieClockLoader
                anchors.horizontalCenter: parent.horizontalCenter
                shown: root.clockStyle === "cookie" && (root.shouldShow)
                fade: false
                sourceComponent: Column {
                    spacing: 10
                    CookieClock {
                        anchors.horizontalCenter: parent.horizontalCenter
                        isCovered: root.isCovered
                    }
                    FadeLoader {
                        anchors.horizontalCenter: parent.horizontalCenter
                        shown: Config.options.background.widgets.clock.quote.enable && Config.options.background.widgets.clock.quote.text !== ""
                        sourceComponent: CookieQuote {}
                    }
                }
            }

            FadeLoader {
                id: digitalClockLoader
                anchors.horizontalCenter: parent.horizontalCenter
                shown: root.clockStyle === "digital" && (root.shouldShow)
                fade: false
                sourceComponent: DigitalClock {
                    colText: root.colText
                    colTextSecondary: root.colTextSecondary
                    colTextTertiary: root.colTextTertiary
                    textHorizontalAlignment: root.textHorizontalAlignment
                }
            }

            FadeLoader {
                id: pixelClockLoader
                anchors.horizontalCenter: parent.horizontalCenter
                shown: root.clockStyle === "pixel" && (root.shouldShow)
                fade: false
                sourceComponent: PixelClock {}
            }
            StatusRow {
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    WidgetResizeHandle {
        hostWidget: root
        currentScale: root.widgetScale
        baseSize: scaleWrapper.implicitWidth
        onRequestScale: (v) => root.dragScale = v
        onRequestCommit: (v) => { Config.options.background.widgets.clock.scale = v; root.dragScale = -1 }
    }

    component StatusRow: Item {
        id: statusText
        implicitHeight: statusTextBg.implicitHeight
        implicitWidth: statusTextBg.implicitWidth
        StyledRectangularShadow {
            target: statusTextBg
            visible: statusTextBg.visible && root.clockStyle === "cookie"
            opacity: statusTextBg.opacity
        }
        Rectangle {
            id: statusTextBg
            anchors.centerIn: parent
            clip: true
            opacity: (safetyStatusText.shown || lockStatusText.shown) ? 1 : 0
            visible: opacity > 0
            implicitHeight: statusTextRow.implicitHeight + 5 * 2
            implicitWidth: statusTextRow.implicitWidth + 5 * 2
            radius: Appearance.rounding.small
            color: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, root.clockStyle === "cookie" ? 0 : 1)

            Behavior on implicitWidth {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }
            Behavior on implicitHeight {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            RowLayout {
                id: statusTextRow
                anchors.centerIn: parent
                spacing: 14
                Item {
                    Layout.fillWidth: root.textHorizontalAlignment !== Text.AlignLeft
                    implicitWidth: 1
                }
                ClockStatusText {
                    id: safetyStatusText
                    shown: root.wallpaperSafetyTriggered
                    statusIcon: "hide_image"
                    statusText: Translation.tr("Wallpaper safety enforced")
                }
                ClockStatusText {
                    id: lockStatusText
                    shown: GlobalStates.screenLocked && Config.options.lock.showLockedText
                    statusIcon: "lock"
                    statusText: Translation.tr("Locked")
                }
                Item {
                    Layout.fillWidth: root.textHorizontalAlignment !== Text.AlignRight
                    implicitWidth: 1
                }
            }
        }
    }

    component ClockStatusText: Row {
        id: statusTextRow
        property alias statusIcon: statusIconWidget.text
        property alias statusText: statusTextWidget.text
        property bool shown: true
        property color textColor: root.clockStyle === "cookie" ? Appearance.colors.colOnSecondaryContainer : root.colText
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        spacing: 4
        MaterialSymbol {
            id: statusIconWidget
            anchors.verticalCenter: statusTextRow.verticalCenter
            iconSize: Appearance.font.pixelSize.huge
            color: statusTextRow.textColor
            style: Text.Raised
            styleColor: Appearance.colors.colShadow
        }
        ClockText {
            id: statusTextWidget
            color: statusTextRow.textColor
            horizontalAlignment: root.textHorizontalAlignment
            anchors.verticalCenter: statusTextRow.verticalCenter
            font {
                pixelSize: Appearance.font.pixelSize.large
                weight: Font.Normal
            }
            style: Text.Raised
            styleColor: Appearance.colors.colShadow
        }
    }
}
