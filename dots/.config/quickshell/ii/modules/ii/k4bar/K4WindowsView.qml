pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Windows is now intentionally an Alt-Tab-only K4 surface. Super-Tab belongs to
// the stock ii-vynx Overview, which owns workspace layout and drag/reorder.
Item {
    id: root
    required property var plugin
    focus: true
    opacity: 0

    Component.onCompleted: {
        fadeIn.start()
        forceActiveFocus()
    }

    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 160
        easing.type: Easing.OutCubic
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.plugin.close()
            event.accepted = true
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right) {
            root.plugin.advance()
            event.accepted = true
        } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left) {
            root.plugin.retreat()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            root.plugin.choose()
            event.accepted = true
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_W) {
            root.plugin.closeCurrent()
            event.accepted = true
        }
    }

    // Compositor-level Alt release is authoritative. Keep this as a harmless
    // fallback for cases where the island itself receives the release event.
    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Alt && root.plugin.commitRelease())
            event.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 12
        anchors.bottomMargin: 15
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 9

            Text {
                text: "Switch windows"
                color: K4Theme.ink
                font.family: K4Theme.uiFont
                font.pixelSize: 16
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: root.plugin.altTabCurrentWorkspaceOnly
                    ? `Workspace ${K4Workspaces.activeId}` : "All workspaces"
                color: K4Theme.panelMuted
                font.family: K4Theme.uiFont
                font.pixelSize: 10
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: currentOnlyToggle
                Layout.preferredWidth: currentOnlyLabel.implicitWidth + 40
                Layout.preferredHeight: 27
                radius: 13.5
                color: currentOnlyHover.hovered
                    ? K4Theme.panelSurfaceHot : K4Theme.panelSurfaceHi
                border.width: 1
                border.color: root.plugin.altTabCurrentWorkspaceOnly
                    ? K4Theme.blue : K4Theme.panelLine

                Row {
                    anchors.centerIn: parent
                    spacing: 7

                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.plugin.altTabCurrentWorkspaceOnly
                            ? K4Theme.blue : K4Theme.panelDim
                    }

                    Text {
                        id: currentOnlyLabel
                        text: "Current workspace only"
                        color: root.plugin.altTabCurrentWorkspaceOnly
                            ? K4Theme.panelInkSoft : K4Theme.panelMuted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 10
                        font.weight: root.plugin.altTabCurrentWorkspaceOnly
                            ? Font.DemiBold : Font.Normal
                        renderType: Text.NativeRendering
                    }
                }

                HoverHandler { id: currentOnlyHover }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: root.plugin.setAltTabCurrentWorkspaceOnly(
                        !root.plugin.altTabCurrentWorkspaceOnly)
                }
            }

            K4PanelButton {
                glyph: K4Theme.ico.close
                glyphSize: 14
                onActivated: root.plugin.close()
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Rectangle {
            id: stage
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 15
            color: K4Theme.panelSurface
            border.width: 1
            border.color: K4Theme.panelLine
            clip: true

            GridView {
                id: switcherGrid
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.plugin.entries
                currentIndex: root.plugin.index
                flow: GridView.FlowTopToBottom
                cellWidth: 260
                cellHeight: height

                delegate: Item {
                    id: switcherCell
                    required property var modelData
                    required property int index
                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight

                    Rectangle {
                        id: switcherCard
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: 13
                        color: K4Theme.panelSurfaceHi
                        border.width: switcherCard.selected ? 1 : 0
                        border.color: K4Theme.blue
                        clip: true

                        readonly property bool selected:
                            switcherCell.index === root.plugin.index
                        readonly property var toplevel:
                            K4Windows.toplevelFor(switcherCell.modelData)

                        Rectangle {
                            id: switcherPreview
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: switcherMeta.top
                            color: K4Theme.panelSurfaceHot
                            clip: true

                            Image {
                                anchors.centerIn: parent
                                width: 52
                                height: 52
                                source: K4Windows.appIcon(switcherCell.modelData)
                                sourceSize: Qt.size(72, 72)
                                fillMode: Image.PreserveAspectFit
                                opacity: switcherCard.toplevel ? 0 : 0.8
                            }

                            Loader {
                                anchors.fill: parent
                                active: switcherCard.toplevel !== null
                                sourceComponent: ScreencopyView {
                                    captureSource: switcherCard.toplevel
                                    live: true
                                    smooth: true
                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.mipmap: true
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: switcherCard.selected
                                    ? Qt.rgba(0.04, 0.52, 1, 0.08)
                                    : switcherMouse.containsMouse
                                        ? Qt.rgba(1, 1, 1, 0.035)
                                        : "transparent"
                            }
                        }

                        Rectangle {
                            id: switcherMeta
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 44
                            color: "#0b0b0d"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 9
                                spacing: 8

                                Image {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    source: K4Windows.appIcon(switcherCell.modelData)
                                    sourceSize: Qt.size(36, 36)
                                    fillMode: Image.PreserveAspectFit
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: K4Windows.appName(switcherCell.modelData)
                                        color: K4Theme.ink
                                        font.family: K4Theme.uiFont
                                        font.pixelSize: 11
                                        font.weight: switcherCard.selected
                                            ? Font.DemiBold : Font.Medium
                                        elide: Text.ElideRight
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: K4Windows.title(switcherCell.modelData)
                                        color: K4Theme.panelMuted
                                        font.family: K4Theme.uiFont
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        renderType: Text.NativeRendering
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: !root.plugin.altTabCurrentWorkspaceOnly
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 8
                            width: workspaceBadge.implicitWidth + 14
                            height: 21
                            radius: 10.5
                            color: "#bb000000"
                            border.width: 1
                            border.color: K4Theme.panelLine
                            z: 3

                            Text {
                                id: workspaceBadge
                                anchors.centerIn: parent
                                text: `WS ${K4Windows.workspace(switcherCell.modelData)}`
                                color: K4Theme.panelInkSoft
                                font.family: K4Theme.uiFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                            }
                        }

                        Rectangle {
                            visible: switcherMouse.containsMouse || switcherCard.selected
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            width: 26
                            height: 26
                            radius: 8
                            color: closeMouse.containsMouse
                                ? Qt.rgba(1, 0.27, 0.23, 0.24)
                                : "#bb000000"
                            border.width: 1
                            border.color: K4Theme.panelLine
                            z: 3

                            Text {
                                anchors.centerIn: parent
                                text: K4Theme.ico.close
                                color: K4Theme.ink
                                font.family: K4Theme.iconFont
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.plugin.index = switcherCell.index
                                    root.plugin.closeCurrent()
                                }
                            }
                        }

                        MouseArea {
                            id: switcherMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            z: 1
                            onEntered: root.plugin.index = switcherCell.index
                            onClicked: function(mouse) {
                                root.plugin.index = switcherCell.index
                                if (mouse.button === Qt.MiddleButton)
                                    root.plugin.closeCurrent()
                                else
                                    root.plugin.choose()
                            }
                        }
                    }
                }

                Connections {
                    target: root.plugin
                    function onIndexChanged() {
                        if (root.plugin.count > 0)
                            switcherGrid.positionViewAtIndex(
                                root.plugin.index, GridView.Contain)
                    }
                }
            }

            Text {
                visible: root.plugin.count === 0
                anchors.centerIn: parent
                text: "No windows available"
                color: K4Theme.panelMuted
                font.family: K4Theme.uiFont
                font.pixelSize: 12
                renderType: Text.NativeRendering
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            text: "Alt release focuses · Tab cycles · middle click/Delete closes"
            color: K4Theme.panelDim
            font.family: K4Theme.uiFont
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
            renderType: Text.NativeRendering
        }
    }
}
