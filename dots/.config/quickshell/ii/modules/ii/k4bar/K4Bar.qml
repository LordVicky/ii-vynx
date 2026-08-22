pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common

// Island host geometry adapted from k4ditano/k4 at the pinned source commit.
// Copyright (c) 2026 k4ditano — MIT, see licenses/k4-NOTICE.txt.
Scope {
    id: root

    Variants {
        model: GlobalStates.screenLocked ? [] : Quickshell.screens

        delegate: PanelWindow {
            id: panelWindow
            required property var modelData
            screen: modelData

            readonly property bool bottom: Config.options.bar.k4.position === "bottom"
            readonly property real alignment:
                Math.max(0, Math.min(100, Config.options.bar.k4.alignment)) / 100
            readonly property int islandBodyWidth: idleContent.desiredBodyWidth
            readonly property int islandBodyHeight: K4Theme.baseHeight
            readonly property int targetHeight:
                Math.min(K4Theme.maxIslandHeight, islandBodyHeight + 2)
            property int surfaceHeight: targetHeight

            anchors.top: !bottom
            anchors.bottom: bottom
            anchors.left: true
            anchors.right: true
            color: "transparent"
            aboveWindows: true
            focusable: true

            WlrLayershell.namespace: "quickshell:k4bar"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            exclusiveZone: K4Theme.baseHeight
            implicitHeight: surfaceHeight
            mask: Region { item: island }

            onTargetHeightChanged: {
                if (targetHeight > surfaceHeight)
                    surfaceHeight = targetHeight
                else
                    surfaceShrinkTimer.restart()
            }

            Timer {
                id: surfaceShrinkTimer
                interval: 520
                onTriggered: panelWindow.surfaceHeight = panelWindow.targetHeight
            }

            Item {
                id: island
                anchors.top: panelWindow.bottom ? undefined : parent.top
                anchors.bottom: panelWindow.bottom ? parent.bottom : undefined
                x: (parent.width - width) * panelWindow.alignment
                width: Math.min(parent.width,
                    panelWindow.islandBodyWidth + K4Theme.wing * 2)
                height: panelWindow.islandBodyHeight

                readonly property real bodyRadius: Math.min(32, height / 2)

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

                    K4IdlePill {
                        id: idleContent
                        anchors.fill: parent
                    }
                }
            }
        }
    }
}
