pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.modules.common.widgets

// Separate notification band used when an explicit island plugin owns the
// island. It never reserves compositor space; K4Bar remains the sole owner of
// the 34px exclusive zone.
Scope {
    Variants {
        model: GlobalStates.screenLocked ? [] : Quickshell.screens

        delegate: PanelWindow {
            id: bandWindow
            required property var modelData
            screen: modelData

            readonly property bool bottom: Config.options.bar.k4.position === "bottom"
            readonly property var islandRect: IslandState.rects[bandWindow.screen.name] ?? null
            readonly property bool targetScreen: IslandState.activeScreen === bandWindow.screen.name
            readonly property bool shouldShow: K4Notifications.toastOpen && K4Notifications.inBand
                && targetScreen && islandRect !== null
            readonly property real desiredLeft: islandRect
                ? islandRect.x + islandRect.ancho / 2 - implicitWidth / 2 : 0

            anchors.top: !bottom
            anchors.bottom: bottom
            anchors.left: true

            margins.left: Math.max(8, Math.min(screen.width - implicitWidth - 8, desiredLeft))
            margins.top: !bottom && islandRect ? islandRect.y + islandRect.alto + 8 : 0
            margins.bottom: bottom && islandRect ? screen.height - islandRect.y + 8 : 0

            implicitWidth: 420
            implicitHeight: 56
            color: "transparent"
            aboveWindows: true
            focusable: false
            exclusionMode: ExclusionMode.Ignore
            visible: shouldShow
            mask: Region { item: band }

            Rectangle {
                id: band
                anchors.fill: parent
                radius: 16
                color: K4Theme.islandBg

                readonly property var notification: K4Notifications.latest
                readonly property string iconSource: K4Notifications.iconFor(notification)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    ClippingRectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter
                        radius: 16
                        color: K4Theme.surface

                        Image {
                            id: bandIcon
                            anchors.fill: parent
                            source: band.iconSource
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 80
                            sourceSize.height: 80
                            visible: status === Image.Ready
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: !bandIcon.visible
                            text: "notifications"
                            fill: 1
                            iconSize: 16
                            color: K4Theme.ink
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: band.notification?.summary ?? ""
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            renderType: Text.NativeRendering
                        }

                        Text {
                            Layout.fillWidth: true
                            text: band.notification?.body ?? ""
                            color: K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            renderType: Text.NativeRendering
                        }
                    }

                    Text {
                        text: "×"
                        color: bandCloseHover.hovered ? K4Theme.ink : K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 15
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.NativeRendering

                        HoverHandler { id: bandCloseHover }
                        TapHandler { onTapped: K4Notifications.dismissToast() }
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered)
                            K4Notifications.holdToast()
                        else
                            K4Notifications.resumeToast()
                    }
                }

                TapHandler {
                    onTapped: {
                        K4Notifications.activate(K4Notifications.latest)
                        K4Notifications.dismissToast()
                    }
                }
            }
        }
    }
}
