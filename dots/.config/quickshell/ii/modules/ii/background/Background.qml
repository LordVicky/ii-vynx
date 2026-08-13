pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.utils //FIXME. remove
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.common.functions as CF
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.modules.ii.background.widgets
import qs.modules.ii.background.widgets.clock
import qs.modules.ii.background.widgets.weather
import qs.modules.ii.background.widgets.media
import qs.modules.ii.background.widgets.calendar
import qs.modules.ii.background.widgets.notes
import qs.modules.ii.background.widgets.resources
import qs.modules.ii.background.widgets.worldclock
import qs.modules.ii.background.widgets.usercard
import qs.modules.ii.background.widgets.visualizer
import qs.modules.ii.background.widgets.images
import qs.modules.ii.background.widgets.todo
import qs.modules.ii.background.widgets.pomodoro
import qs.modules.ii.background.widgets.lyrics
import qs.modules.ii.background.widgets.network
import qs.modules.ii.background.widgets.clipboard
import qs.modules.ii.background.widgets.updates
import qs.modules.ii.background.widgets.privacy
import qs.modules.ii.background.widgets.songrec
import qs.modules.ii.background.widgets.battery

Variants {
    id: root
    model: Quickshell.screens
    
    PanelWindow {
        id: bgRoot

        required property var modelData

        // Hide when fullscreen
        property list<HyprlandWorkspace> workspacesForMonitor: Hyprland.workspaces.values.filter(workspace => workspace.monitor && workspace.monitor.name == monitor.name)
        property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace.toplevels.values.filter(window => window.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
        visible: GlobalStates.screenLocked || (!(activeWorkspaceWithFullscreen != undefined)) || !Config?.options.background.hideWhenFullscreen

        // Workspaces
        property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

        readonly property int activeWorkspaceId: monitor?.activeWorkspace?.id ?? -1

        readonly property bool isCovered: {
            if (activeWorkspaceId === -1 || !monitor) return false;
            return HyprlandData.windowList.some(w => w.workspace?.id === activeWorkspaceId && w.monitor === monitor.id && !w.floating);
        }

        property list<var> relevantWindows: HyprlandData.windowList.filter(win => win.monitor == monitor?.id && win.workspace.id >= 0).sort((a, b) => a.workspace.id - b.workspace.id)
        property int firstWorkspaceId: relevantWindows[0]?.workspace.id || 1
        property int lastWorkspaceId: relevantWindows[relevantWindows.length - 1]?.workspace.id || 10

        // Wallpaper
        property bool wallpaperIsVideo: Config.options.background.wallpaperPath.endsWith(".mp4") || Config.options.background.wallpaperPath.endsWith(".webm") || Config.options.background.wallpaperPath.endsWith(".mkv") || Config.options.background.wallpaperPath.endsWith(".avi") || Config.options.background.wallpaperPath.endsWith(".mov")
        property string wallpaperPath: wallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath
        property bool wallpaperSafetyTriggered: {
            const enabled = Config.options.workSafety.enable.wallpaper;
            const sensitiveWallpaper = (CF.StringUtils.stringListContainsSubstring(wallpaperPath.toLowerCase(), Config.options.workSafety.triggerCondition.fileKeywords));
            const sensitiveNetwork = (CF.StringUtils.stringListContainsSubstring(Network.networkName.toLowerCase(), Config.options.workSafety.triggerCondition.networkNameKeywords));
            return enabled && sensitiveWallpaper && sensitiveNetwork;
        }
        property real wallpaperToScreenRatio: Math.min(wallpaperWidth / screen.width, wallpaperHeight / screen.height)
        property real preferredWallpaperScale: Config.options.background.parallax.workspaceZoom
        property real effectiveWallpaperScale: 1 // Some reasonable init value, to be updated
        property int wallpaperWidth: modelData.width // Some reasonable init value, to be updated
        property int wallpaperHeight: modelData.height // Some reasonable init value, to be updated
        property real movableXSpace: ((wallpaperWidth / wallpaperToScreenRatio * effectiveWallpaperScale) - screen.width) / 2
        property real movableYSpace: ((wallpaperHeight / wallpaperToScreenRatio * effectiveWallpaperScale) - screen.height) / 2

        readonly property bool verticalParallax: (Config.options.background.parallax.autoVertical && wallpaperHeight > wallpaperWidth) || Config.options.background.parallax.vertical
        // Colors
        property bool shouldBlur: (GlobalStates.screenLocked && Config.options.lock.blur.enable)
        property color dominantColor: Appearance.colors.colPrimary // Default, to be changed
        property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
        property color colText: {
            if (wallpaperSafetyTriggered)
                return CF.ColorUtils.mix(Appearance.colors.colOnLayer0, Appearance.colors.colPrimary, 0.75);
            return (GlobalStates.screenLocked && shouldBlur) ? Appearance.colors.colOnLayer0 : CF.ColorUtils.colorWithLightness(Appearance.colors.colPrimary, (dominantColorIsDark ? 0.8 : 0.12));
        }
        Behavior on colText {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        readonly property bool isScrollingLayout: Persistent.states.hyprland.layout === "scrolling"

        property var zoomLevels: {  // has to be reverted compared to background
            "in": { default: 1.04, zoomed: 1 },
            "out": { default: 1, zoomed: 1.04 }
        }

        property real defaultRatio: zoomInStyle ? zoomLevels.in.default : zoomLevels.out.default
        property real zoomedRatio: zoomInStyle ? zoomLevels.in.zoomed : zoomLevels.out.zoomed

        readonly property bool zoomInStyle: Config.options.overview.scrollingStyle.zoomStyle === "in"
        readonly property bool showOpeningAnimation: Config.options.overview.showOpeningAnimation

        property bool overviewOpen: GlobalStates.overviewOpen

        property real scaleAnimated: GlobalStates.overviewOpen && showOpeningAnimation ? zoomedRatio : defaultRatio
        Behavior on scaleAnimated {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        // Layer props
        screen: modelData
        exclusionMode: ExclusionMode.Ignore

        // One request-driven 8×8 CPU sampler for every desktop widget. Keep it
        // attached to an existing scene so Canvas can paint, but create it only
        // for the first screen to avoid one wallpaper decoder per monitor.
        Loader {
            active: bgRoot.modelData === Quickshell.screens[0]
            sourceComponent: WallpaperLuminanceCanvas {
                sourceWidth: bgRoot.wallpaperWidth
                sourceHeight: bgRoot.wallpaperHeight
            }
        }
        WlrLayershell.layer: (GlobalStates.screenLocked && !scaleAnim.running) ? WlrLayer.Top : WlrLayer.Bottom
        // WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:background"
        // Only grab keyboard focus while a desktop widget's text field is actively
        // being typed into (notes, world clock timezone search, ...); otherwise this
        // background layer stays out of the way of Super/global shortcuts.
        WlrLayershell.keyboardFocus: GlobalStates.desktopWidgetKeyboardFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: {
            if (!bgRoot.wallpaperSafetyTriggered || bgRoot.wallpaperIsVideo)
                return "transparent";
            return CF.ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colPrimary, 0.75);
        }
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        onWallpaperPathChanged: {
            bgRoot.updateZoomScale();
            // Clock position gets updated after zoom scale is updated
        }

        // Wallpaper zoom scale
        function updateZoomScale() {
            getWallpaperSizeProc.path = bgRoot.wallpaperPath;
            getWallpaperSizeProc.running = true;
        }
        Process {
            id: getWallpaperSizeProc
            property string path: bgRoot.wallpaperPath
            command: ["magick", "identify", "-format", "%w %h", path]
            stdout: StdioCollector {
                id: wallpaperSizeOutputCollector
                onStreamFinished: {
                    const output = wallpaperSizeOutputCollector.text;
                    const [width, height] = output.split(" ").map(Number);
                    const [screenWidth, screenHeight] = [bgRoot.screen.width, bgRoot.screen.height];
                    bgRoot.wallpaperWidth = width;
                    bgRoot.wallpaperHeight = height;

                    if (width <= screenWidth || height <= screenHeight) {
                        // Undersized/perfectly sized wallpapers
                        bgRoot.effectiveWallpaperScale = Math.max(screenWidth / width, screenHeight / height);
                    } else {
                        // Oversized = can be zoomed for parallax, yay
                        bgRoot.effectiveWallpaperScale = Math.min(bgRoot.preferredWallpaperScale, width / screenWidth, height / screenHeight);
                    }
                }
            }
        }

        property bool mediaModeOpen: mediaModeLoader.active && MprisController.activePlayer
        onMediaModeOpenChanged: {
            if (!mediaModeOpen && Config.options.appearance.palette.type.startsWith("scheme")) {
                Wallpapers.apply(Config.options.background.wallpaperPath)
                LyricsService.shellColorChanged = false
            }
        }

        property var _extensionBgWidgetEntries: []
        property var _pendingWidgetSaves: ({})

        Timer {
            id: bgWidgetSaveTimer
            interval: 300
            repeat: false
            onTriggered: {
                for (let key in bgRoot._pendingWidgetSaves) {
                    let p = bgRoot._pendingWidgetSaves[key]
                    ExtensionManager.saveExtensionWidgetConfig(p.extId, p.wid, p.config)
                }
                bgRoot._pendingWidgetSaves = {}
            }
        }

        function refreshExtensionBgWidgets() {
            // Destroy all existing extension widget objects
            for (let i = 0; i < _extensionBgWidgetEntries.length; i++) {
                let entry = _extensionBgWidgetEntries[i]
                if (entry) {
                    if (entry.cfg) entry.cfg.destroy()
                    if (entry.widget) entry.widget.destroy()
                }
            }
            _extensionBgWidgetEntries = []

            let list = ExtensionManager.getContributionPoint("backgroundWidgets")

            for (let wi = 0; wi < list.length; wi++) {
                let entry = list[wi]
                let fullPath = entry.fullPath
                let extId = entry.extensionId
                let wid = entry.identifier
                let x = entry.x
                let y = entry.y
                let strat = entry.placementStrategy || "free"

                let comp = ExtensionManager.loadExtensionQmlComponent(fullPath)

                let createWidget = (comp, entry, fullPath, extId, wid, x, y, strat) => {
                    let savedWidgetConfig = ExtensionManager.getExtensionWidgetConfig(extId, wid)
                    let savedX = savedWidgetConfig ? savedWidgetConfig.x : x
                    let savedY = savedWidgetConfig ? savedWidgetConfig.y : y
                    let qml = 'import QtQml; QtObject { property bool enable: true; property real x: ' + savedX + '; property real y: ' + savedY + '; property string placementStrategy: "' + strat + '" }'
                    let cfg = Qt.createQmlObject(qml,bgRoot)

                    let onPosChanged = () => {
                        bgRoot._pendingWidgetSaves[extId + "/" + wid] = {
                            extId: extId,
                            wid: wid,
                            config: { enable: cfg.enable, x: cfg.x, y: cfg.y }
                        }
                        bgWidgetSaveTimer.restart()
                    }
                    cfg.xChanged.connect(onPosChanged)
                    cfg.yChanged.connect(onPosChanged)

                    let widget = comp.createObject(widgetCanvas, {
                        configEntry: cfg,
                        screenWidth: bgRoot.screen.width,
                        screenHeight: bgRoot.screen.height,
                        scaledScreenWidth: bgRoot.screen.width,
                        scaledScreenHeight: bgRoot.screen.height,
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                    })

                    if (widget && extId) {
                        if ("extensionId" in widget) {
                            widget.extensionId = extId
                        } else {
                            Object.defineProperty(widget, "extensionId", {
                                value: extId,
                                writable: true,
                                configurable: true,
                                enumerable: true
                            })
                        }
                        let entries = _extensionBgWidgetEntries.slice()
                        entries.push({ widget: widget, cfg: cfg })
                        _extensionBgWidgetEntries = entries
                    }
                }

                if (comp.status === Component.Ready) {
                    createWidget(comp, entry, fullPath, extId, wid, x, y, strat)
                } else if (comp.status === Component.Error) {
                    console.warn("Background: failed to load extension widget component for", extId, wid, ":", comp.errorString())
                } else {
                    comp.statusChanged.connect(() => {
                        if (comp.status === Component.Ready) {
                            createWidget(comp, entry, fullPath, extId, wid, x, y, strat)
                        } else if (comp.status === Component.Error) {
                            console.warn("Background: async component error for", extId, wid, ":", comp.errorString())
                        }
                    })
                }
            }

        }

        Component.onCompleted: {
            refreshExtensionBgWidgets()
            if (!mediaModeOpen && Config.options.appearance.palette.type.startsWith("scheme")) {
                Wallpapers.apply(Config.options.background.wallpaperPath)
            }
        }

        Connections {
            target: ExtensionManager
            function onRefreshExtensions() { refreshExtensionBgWidgets() }
        }

        Item {
            id: wallpaperItem
            anchors.fill: parent
            clip: true
            scale: showOpeningAnimation && overviewOpen && bgRoot.isScrollingLayout ? zoomedRatio : defaultRatio
            opacity: mediaModeOpen ? 0 : 1
            
            Behavior on opacity {
                NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
            }

            Behavior on scale {
                animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
            }

            // Wallpaper
            TransitionImage {
                id: wallpaper
                visible: !blurLoader.active
                opacity: bgRoot.wallpaperIsVideo ? 0 : 1
                // Range = groups that workspaces span on
                property int chunkSize: Config?.options.bar.workspaces.shown ?? 10
                property int lower: Math.floor(bgRoot.firstWorkspaceId / chunkSize) * chunkSize
                property int upper: Math.ceil(bgRoot.lastWorkspaceId / chunkSize) * chunkSize
                property int range: upper - lower
                property real valueX: {
                    let result = 0.5;
                    if (Config.options.background.parallax.enableWorkspace && !bgRoot.verticalParallax) {
                        result = ((bgRoot.monitor.activeWorkspace?.id - lower) / range);

                    }
                    return result;
                }
                property real sidebarOffsetX: {
                    if (!Config.options.background.parallax.enableSidebar) return 0;
                    return (0.15 * GlobalStates.effectiveRightOpen - 0.15 * GlobalStates.effectiveLeftOpen);

                }
                property real valueY: {
                    let result = 0.5;
                    if (Config.options.background.parallax.enableWorkspace && bgRoot.verticalParallax) {
                        result = ((bgRoot.monitor.activeWorkspace?.id - lower) / range);
                    }
                    return result;
                }
                property real effectiveValueX: Math.max(0, Math.min(1, valueX)) + sidebarOffsetX
                property real effectiveValueY: Math.max(0, Math.min(1, valueY))
                x: -(bgRoot.movableXSpace) - (effectiveValueX - 0.5) * 2 * bgRoot.movableXSpace
                y: -(bgRoot.movableYSpace) - (effectiveValueY - 0.5) * 2 * bgRoot.movableYSpace

                imageSource: bgRoot.wallpaperSafetyTriggered ? "" : bgRoot.wallpaperPath
                animated: !bgRoot.wallpaperIsVideo
                fillMode: Image.PreserveAspectCrop
                Behavior on x {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: 800
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 800
                        easing.type: Easing.OutCubic
                    }
                }
                width: bgRoot.wallpaperWidth / bgRoot.wallpaperToScreenRatio * bgRoot.effectiveWallpaperScale
                height: bgRoot.wallpaperHeight / bgRoot.wallpaperToScreenRatio * bgRoot.effectiveWallpaperScale
            }

            Loader {
                id: blurLoader
                active: Config.options.lock.blur.enable && (GlobalStates.screenLocked || scaleAnim.running)
                anchors.fill: wallpaper
                scale: GlobalStates.screenLocked ? Config.options.lock.blur.extraZoom : 1
                Behavior on scale {
                    NumberAnimation {
                        id: scaleAnim
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                    }
                }
                sourceComponent: GaussianBlur {
                    source: wallpaper
                    radius: GlobalStates.screenLocked ? Config.options.lock.blur.radius : 0
                    samples: radius * 2 + 1

                    Rectangle {
                        opacity: GlobalStates.screenLocked ? 1 : 0
                        anchors.fill: parent
                        color: CF.ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7)
                    }
                }
            }

            WidgetCanvas {
                id: widgetCanvas
                // Anchored to the screen viewport (wallpaperItem is always screen-sized),
                // NOT to the wallpaper image - the wallpaper pans/zooms for parallax but
                // widgets must stay put relative to the display, and be draggable across
                // the full screen rather than being bounded by the (larger, panning)
                // wallpaper's own bounds. This is the same geometry the old lock-only
                // "centered" state used, just applied unconditionally.
                anchors.fill: parent
                scale: 1 - (defaultRatio - 1)
                Behavior on scale {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

                FadeLoader {
                    shown: Config.options.background.widgets.weather.enable
                    sourceComponent: WeatherWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.clock.enable
                    sourceComponent: ClockWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                        wallpaperSafetyTriggered: bgRoot.wallpaperSafetyTriggered
                        isCovered: bgRoot.isCovered
                    }
                }

                Timer {
                    id: mediaTimer
                    interval: 200
                    onTriggered: mediaLoader.enableLoading = true
                }

                FadeLoader {
                    id: mediaLoader
                    property bool enableLoading: true
                    shown: Config.options.background.widgets.media.enable && enableLoading
                    sourceComponent: MediaWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                    onLoaded: {
                        if (item && item.requestReset) {
                            item.requestReset.connect(() => { // hard reset
                                mediaLoader.enableLoading = false
                                mediaTimer.running = true
                            })
                        }
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.calendar.enable
                    sourceComponent: CalendarWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.notes.enable
                    sourceComponent: NotesWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.resources.enable
                    sourceComponent: ResourcesWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.worldClock.enable
                    sourceComponent: WorldClockWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.userCard.enable
                    sourceComponent: UserCardWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.todo.enable
                    sourceComponent: TodoWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.pomodoro.enable
                    sourceComponent: PomodoroWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.lyrics.enable
                    sourceComponent: LyricsWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.clipboard.enable
                    sourceComponent: ClipboardWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.updates.enable
                    sourceComponent: UpdatesWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.privacy.enable
                    sourceComponent: PrivacyWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.songRec.enable
                    sourceComponent: SongRecWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.battery.enable
                    sourceComponent: BatteryWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.visualizer.enable
                    sourceComponent: VisualizerWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.images.enable
                    sourceComponent: ImageConverterWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.customImage.enable
                    sourceComponent: CustomImage {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperRenderX: wallpaper.x
                        wallpaperRenderY: wallpaper.y
                        wallpaperRenderWidth: wallpaper.width
                        wallpaperRenderHeight: wallpaper.height
                        wallpaperSourceItem: wallpaper
                    }
                }
            }
        }

        GlobalShortcut {
            name: "mediaModeToggle"
            description: "Toggles media mode on press"

            onPressed: {
                if (!monitor.focused && Config.options.background.mediaMode.togglePerMonitor) return
                mediaModeLoader.active = !mediaModeLoader.active
                LyricsService.mediaModeOpenCount += mediaModeLoader.active ? 1 : -1
            }
        }
        
        Loader {
            id: mediaModeLoader
            anchors.fill: parent
            active: false
            asynchronous: true
            sourceComponent: MediaMode {}
            opacity: status === Loader.Ready ? 1 : 0
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }
}
