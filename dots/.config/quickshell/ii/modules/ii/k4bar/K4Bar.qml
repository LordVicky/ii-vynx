pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.modules.common

// Island host geometry and arbitration adapted from k4ditano/k4 at the pinned
// source commit. Copyright (c) 2026 k4ditano — MIT,
// see licenses/k4-NOTICE.txt.
Scope {
    id: root

    K4Plugin {
        id: idlePlugin
        name: "idle"
        priority: 0
        active: true
        islandWidth: 90
        islandHeight: K4Theme.baseHeight
    }

    // Temporary K4-03 runtime harness. These stay inactive unless explicitly
    // opened through k4barDebug IPC and are replaced by real plugins later.
    K4Plugin {
        id: demoTransient
        name: "demo-transient"
        title: "Transient"
        priority: 59
        transitorio: true
        islandWidth: 250
        islandHeight: 88
        closeOnHoverExit: true
        hoverExitDelay: 700
        onHoverTimedOut: close()
        view: Component {
            K4DemoView {
                title: "Transient"
                detail: "priority 59 · closes when preempted"
            }
        }
    }

    K4Plugin {
        id: demoSecondary
        name: "demo-secondary"
        title: "Secondary"
        priority: 70
        islandWidth: 290
        islandHeight: 118
        handlesBackgroundTap: true
        onBackgroundTapped: close()
        view: Component {
            K4DemoView {
                title: "Secondary"
                detail: "priority 70 · background click closes"
            }
        }
    }

    K4Plugin {
        id: demoPrimary
        name: "demo-primary"
        title: "Primary"
        priority: 80
        islandWidth: 360
        islandHeight: 162
        optionalKeyboard: true
        view: Component {
            K4DemoView {
                title: "Primary"
                detail: "priority 80 · click then Escape closes"
            }
        }
    }

    K4PluginController {
        id: controller
        plugins: [idlePlugin, demoTransient, demoSecondary, demoPrimary]
    }

    function openDemo(plugin, screenName) {
        if (screenName)
            IslandState.requestScreen(screenName)
        plugin.open()
    }

    function closeDemos() {
        demoPrimary.close()
        demoSecondary.close()
        demoTransient.close()
    }

    Component.onDestruction: controller.reset()

    IpcHandler {
        target: "k4barDebug"

        function openPrimary(): void { root.openDemo(demoPrimary, "") }
        function openPrimaryOn(screen: string): void { root.openDemo(demoPrimary, screen) }
        function closePrimary(): void { demoPrimary.close() }

        function openSecondary(): void { root.openDemo(demoSecondary, "") }
        function openSecondaryOn(screen: string): void { root.openDemo(demoSecondary, screen) }
        function closeSecondary(): void { demoSecondary.close() }

        function openTransient(): void { root.openDemo(demoTransient, "") }
        function closeTransient(): void { demoTransient.close() }
        function closeAll(): void { root.closeDemos() }

        function disablePrimary(): void { demoPrimary.enabled = false }
        function enablePrimary(): void { demoPrimary.enabled = true }

        function hideIsland(): void { IslandState.hidden = true }
        function showIsland(): void { IslandState.hidden = false }
        function dialogOpen(): void { IslandState.openSystemDialog() }
        function dialogClose(): void { IslandState.closeSystemDialog() }

        function placePrimary(fraction: real, durationMs: int): void {
            demoPrimary.requestPlacement(fraction, durationMs)
        }
        function releasePrimaryPlacement(): void { demoPrimary.releasePlacement() }
        function gesture(name: string, strength: real): void {
            demoPrimary.requestGesture(name, strength)
        }

        function status(): string {
            return JSON.stringify({
                occupant: IslandState.occupant,
                open: IslandState.open,
                activeScreen: IslandState.activeScreen,
                requestedScreen: IslandState.requestedScreen,
                position: IslandState.position,
                rect: IslandState.rect,
                rects: IslandState.rects,
                hovered: IslandState.hovered,
                placement: IslandState.placement,
                placementOwner: IslandState.placementOwner,
                hidden: IslandState.hidden,
                dialogs: IslandState.systemDialogs,
                suppressed: IslandState.suppressed,
                primaryActive: demoPrimary.active,
                primaryEnabled: demoPrimary.enabled,
                secondaryActive: demoSecondary.active,
                transientActive: demoTransient.active
            })
        }
    }

    Variants {
        model: GlobalStates.screenLocked ? [] : Quickshell.screens

        delegate: PanelWindow {
            id: panelWindow
            required property var modelData
            screen: modelData

            readonly property bool bottom: Config.options.bar.k4.position === "bottom"
            readonly property var pluginVisible:
                controller.visiblePluginFor(panelWindow.screen.name)
            readonly property bool showingIdle:
                !pluginVisible || pluginVisible.name === "idle"
            readonly property int islandBodyWidth: showingIdle
                ? idleContent.desiredBodyWidth : pluginVisible.islandWidth
            readonly property int islandBodyHeight: showingIdle
                ? K4Theme.baseHeight : pluginVisible.islandHeight
            readonly property int targetHeight: Math.min(K4Theme.maxIslandHeight,
                islandBodyHeight + 2 + (island.gestureInProgress ? 44 : 0))
            property int surfaceHeight: targetHeight

            anchors.top: !bottom
            anchors.bottom: bottom
            anchors.left: true
            anchors.right: true
            color: "transparent"
            aboveWindows: true
            focusable: true

            WlrLayershell.namespace: "quickshell:k4bar"
            WlrLayershell.keyboardFocus: {
                if (IslandState.suppressed)
                    return WlrKeyboardFocus.None
                const plugin = panelWindow.pluginVisible
                if (!plugin || plugin !== controller.activePlugin
                        || plugin.name === "idle")
                    return WlrKeyboardFocus.None
                if (plugin.grabKeyboard)
                    return WlrKeyboardFocus.Exclusive
                if (plugin.keyboardOnHover && IslandState.hovered)
                    return WlrKeyboardFocus.Exclusive
                if (plugin.optionalKeyboard)
                    return WlrKeyboardFocus.OnDemand
                return WlrKeyboardFocus.None
            }

            exclusiveZone: K4Theme.baseHeight
            implicitHeight: surfaceHeight
            mask: Region { item: IslandState.suppressed ? null : island }

            onTargetHeightChanged: {
                if (targetHeight > surfaceHeight)
                    surfaceHeight = targetHeight
                else
                    surfaceShrinkTimer.restart()
            }

            onBottomChanged: island.publishRect()

            Timer {
                id: surfaceShrinkTimer
                interval: 520
                onTriggered: panelWindow.surfaceHeight = panelWindow.targetHeight
            }

            Item {
                id: island
                anchors.top: panelWindow.bottom ? undefined : parent.top
                anchors.bottom: panelWindow.bottom ? parent.bottom : undefined

                opacity: IslandState.suppressed ? 0 : 1
                property real smoothPlacement: IslandState.placement
                x: (parent.width - width) * smoothPlacement
                width: Math.min(parent.width,
                    panelWindow.islandBodyWidth + K4Theme.wing * 2)
                height: panelWindow.islandBodyHeight

                readonly property real bodyRadius: Math.min(32, height / 2)

                Behavior on smoothPlacement {
                    NumberAnimation {
                        duration: 440
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.42
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: 440
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.42
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.32
                    }
                }

                // Root focus receives Escape after nested controls have had the
                // opportunity to consume it.
                focus: true
                readonly property var windowFocusItem: island.Window.activeFocusItem
                onWindowFocusItemChanged: if (!windowFocusItem) Qt.callLater(claimFocus)

                function claimFocus() {
                    if (!island.Window.activeFocusItem)
                        island.forceActiveFocus()
                }

                Keys.onPressed: function (event) {
                    if (event.key !== Qt.Key_Escape)
                        return
                    const plugin = panelWindow.pluginVisible
                    if (plugin && plugin.name !== "idle"
                            && typeof plugin.close === "function") {
                        plugin.close()
                        event.accepted = true
                    }
                }

                // Geometry publication is screen-local and follows the animated
                // island rather than the full layer surface.
                onXChanged: publishRect()
                onWidthChanged: publishRect()
                onHeightChanged: publishRect()

                Component.onCompleted: {
                    publishRect()
                    forceActiveFocus()
                }

                function publishRect() {
                    IslandState.publishRect(panelWindow.screen.name, {
                        x: island.x,
                        y: panelWindow.bottom
                            ? panelWindow.screen.height - island.height : 0,
                        ancho: island.width,
                        alto: island.height
                    }, panelWindow.modelData === Quickshell.screens[0])
                }

                transform: Translate { id: gestureTranslate }

                readonly property bool gestureInProgress:
                    shakeAnimation.running || pushAnimation.running
                    || tugAnimation.running
                readonly property real gestureDirection: panelWindow.bottom ? -1 : 1

                SequentialAnimation {
                    id: shakeAnimation
                    property real strength: 1
                    NumberAnimation { target: gestureTranslate; property: "x"; to: -8 * shakeAnimation.strength; duration: 40 }
                    NumberAnimation { target: gestureTranslate; property: "x"; to: 7 * shakeAnimation.strength; duration: 70 }
                    NumberAnimation { target: gestureTranslate; property: "x"; to: -5 * shakeAnimation.strength; duration: 70 }
                    NumberAnimation { target: gestureTranslate; property: "x"; to: 3 * shakeAnimation.strength; duration: 60 }
                    NumberAnimation { target: gestureTranslate; property: "x"; to: 0; duration: 60; easing.type: Easing.OutQuad }
                }

                SequentialAnimation {
                    id: pushAnimation
                    property real strength: 1
                    NumberAnimation {
                        target: gestureTranslate
                        property: "y"
                        to: 26 * pushAnimation.strength * island.gestureDirection
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: gestureTranslate
                        property: "y"
                        to: 0
                        duration: 320
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.4
                    }
                }

                SequentialAnimation {
                    id: tugAnimation
                    property real strength: 1
                    NumberAnimation { target: gestureTranslate; property: "y"; to: 10 * tugAnimation.strength * island.gestureDirection; duration: 90; easing.type: Easing.OutQuad }
                    NumberAnimation { target: gestureTranslate; property: "y"; to: 2 * island.gestureDirection; duration: 90 }
                    NumberAnimation { target: gestureTranslate; property: "y"; to: 12 * tugAnimation.strength * island.gestureDirection; duration: 90 }
                    NumberAnimation { target: gestureTranslate; property: "y"; to: 0; duration: 140; easing.type: Easing.OutQuad }
                }

                Connections {
                    target: IslandState
                    function onGesture(name, strength) {
                        shakeAnimation.stop()
                        pushAnimation.stop()
                        tugAnimation.stop()
                        gestureTranslate.x = 0
                        gestureTranslate.y = 0

                        if (name === "sacudida") {
                            shakeAnimation.strength = strength
                            shakeAnimation.start()
                        } else if (name === "empujon") {
                            pushAnimation.strength = strength
                            pushAnimation.start()
                        } else if (name === "tiron") {
                            tugAnimation.strength = strength
                            tugAnimation.start()
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered)
                            controller.hoverEntered(panelWindow.screen.name)
                        else
                            controller.hoverExited()
                    }
                }

                Shape {
                    id: silhouette
                    anchors.fill: parent
                    antialiasing: true
                    layer.enabled: true
                    layer.samples: 8
                    layer.smooth: true

                    transform: Scale {
                        origin.y: silhouette.height / 2
                        yScale: panelWindow.bottom ? -1 : 1
                    }

                    ShapePath {
                        id: islandPath
                        fillColor: K4Theme.islandBg
                        strokeWidth: 0
                        strokeColor: "transparent"

                        readonly property real w: island.width
                        readonly property real h: island.height
                        readonly property real r: island.bodyRadius
                        readonly property real g: Math.min(K4Theme.wing, island.height / 2)

                        startX: 0
                        startY: 0

                        PathArc {
                            x: islandPath.g
                            y: islandPath.g
                            radiusX: islandPath.g
                            radiusY: islandPath.g
                            direction: PathArc.Clockwise
                        }
                        PathLine { x: islandPath.g; y: islandPath.h - islandPath.r }
                        PathArc {
                            x: islandPath.g + islandPath.r
                            y: islandPath.h
                            radiusX: islandPath.r
                            radiusY: islandPath.r
                            direction: PathArc.Counterclockwise
                        }
                        PathLine {
                            x: islandPath.w - islandPath.g - islandPath.r
                            y: islandPath.h
                        }
                        PathArc {
                            x: islandPath.w - islandPath.g
                            y: islandPath.h - islandPath.r
                            radiusX: islandPath.r
                            radiusY: islandPath.r
                            direction: PathArc.Counterclockwise
                        }
                        PathLine { x: islandPath.w - islandPath.g; y: islandPath.g }
                        PathArc {
                            x: islandPath.w
                            y: 0
                            radiusX: islandPath.g
                            radiusY: islandPath.g
                            direction: PathArc.Clockwise
                        }
                        PathLine { x: 0; y: 0 }
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: K4Theme.wing
                    anchors.rightMargin: K4Theme.wing
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: controller.backgroundTap(panelWindow.screen.name)
                    }

                    Item {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: panelWindow.islandBodyWidth
                        height: panelWindow.islandBodyHeight

                        K4IdlePill {
                            id: idleContent
                            anchors.fill: parent
                            visible: panelWindow.showingIdle
                        }

                        Repeater {
                            model: controller.plugins

                            delegate: Loader {
                                required property var modelData
                                anchors.fill: parent
                                active: modelData?.name !== "idle"
                                    && modelData === panelWindow.pluginVisible
                                    && modelData.enabled
                                    && modelData.viewLoaded
                                    && modelData.view !== null
                                sourceComponent: modelData?.view ?? null

                                onStatusChanged: {
                                    if (status === Loader.Error)
                                        console.warn("[k4] view load failed:", modelData?.name ?? "unknown")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
