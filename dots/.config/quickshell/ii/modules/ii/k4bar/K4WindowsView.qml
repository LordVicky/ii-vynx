pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Option A: workspace rail + live window stage for Super+Tab, with the same
// stage expanded to the full island for Alt+Tab. Previews come directly from
// Wayland ToplevelManager through K4Windows.toplevelFor().
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

    function moveWorkspace(delta) {
        if (!root.plugin.showWorkspaces)
            return
        const workspaces = K4Workspaces.list.filter(workspace => workspace.id > 0)
        if (workspaces.length === 0)
            return
        let current = workspaces.findIndex(workspace =>
            workspace.id === root.plugin.selectedWorkspaceId)
        if (current < 0)
            current = 0
        const next = (current + delta + workspaces.length) % workspaces.length
        root.plugin.selectWorkspace(workspaces[next].id)
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
        } else if (root.plugin.showWorkspaces && event.key === Qt.Key_Up) {
            root.moveWorkspace(-1)
            event.accepted = true
        } else if (root.plugin.showWorkspaces && event.key === Qt.Key_Down) {
            root.moveWorkspace(1)
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

    // Alt+Tab is a modifier session: the compositor keeps sending Tab presses
    // through the registered global shortcut, while releasing Alt lands here
    // after K4 has taken exclusive keyboard focus. Super+Tab is intentionally a
    // persistent overview and therefore does not commit on Super release.
    Keys.onReleased: function(event) {
        if (root.plugin.mode === "switcher" && event.key === Qt.Key_Alt) {
            root.plugin.choose()
            event.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 10
        anchors.bottomMargin: 14
        spacing: 9

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 9

            Text {
                text: root.plugin.showWorkspaces ? "Windows" : "Switch windows"
                color: K4Theme.ink
                font.family: K4Theme.uiFont
                font.pixelSize: 15
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: root.plugin.showWorkspaces
                    ? `Workspace ${root.plugin.selectedWorkspaceId}`
                    : root.plugin.altTabCurrentWorkspaceOnly
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
                visible: !root.plugin.showWorkspaces
                Layout.preferredWidth: currentOnlyLabel.implicitWidth + 38
                Layout.preferredHeight: 25
                radius: 12.5
                color: currentOnlyHover.hovered ? K4Theme.panelSurfaceHot
                    : K4Theme.panelSurfaceHi
                border.width: 1
                border.color: root.plugin.altTabCurrentWorkspaceOnly
                    ? K4Theme.blue : K4Theme.panelLine

                Row {
                    anchors.centerIn: parent
                    spacing: 6

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

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Rectangle {
                id: workspaceRail
                visible: root.plugin.showWorkspaces
                Layout.preferredWidth: root.plugin.showWorkspaces ? 174 : 0
                Layout.fillHeight: true
                radius: 14
                color: K4Theme.panelSurface
                border.width: 1
                border.color: K4Theme.panelLine
                clip: true

                ListView {
                    id: workspaceList
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 7
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: K4Workspaces.list.filter(workspace => workspace.id > 0)

                    delegate: Rectangle {
                        id: workspaceCard
                        required property var modelData
                        required property int index
                        readonly property int workspaceId: Number(modelData.id)
                        readonly property bool selected:
                            workspaceId === root.plugin.selectedWorkspaceId
                        readonly property bool active:
                            workspaceId === K4Workspaces.activeId
                        readonly property int windowCount:
                            K4Windows.windowCountForWorkspace(workspaceId)

                        width: ListView.view.width
                        height: 58
                        radius: 11
                        color: selected ? K4Theme.panelSurfaceHot
                            : workspaceHover.hovered ? K4Theme.panelSurfaceHi
                            : "transparent"
                        border.width: selected ? 1 : 0
                        border.color: selected ? K4Theme.blue : "transparent"

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 9
                            spacing: 7

                            Row {
                                width: parent.width
                                spacing: 6

                                Rectangle {
                                    visible: workspaceCard.active
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: K4Theme.blue
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: `Workspace ${workspaceCard.workspaceId}`
                                    color: K4Theme.ink
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 11
                                    font.weight: workspaceCard.selected
                                        ? Font.DemiBold : Font.Normal
                                    renderType: Text.NativeRendering
                                }

                                Item {
                                    width: Math.max(0, workspaceCard.width
                                        - (workspaceCard.active ? 102 : 90))
                                    height: 1
                                }

                                Text {
                                    text: workspaceCard.windowCount
                                    color: K4Theme.panelMuted
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering
                                }
                            }

                            Row {
                                spacing: 4
                                Repeater {
                                    model: Math.min(workspaceCard.windowCount, 6)
                                    Rectangle {
                                        required property int index
                                        width: 17 + (index % 2) * 5
                                        height: 8
                                        radius: 3
                                        color: workspaceCard.selected
                                            ? Qt.rgba(0.04, 0.52, 1, 0.34)
                                            : K4Theme.panelTrack
                                    }
                                }

                                Text {
                                    visible: workspaceCard.windowCount > 6
                                    text: `+${workspaceCard.windowCount - 6}`
                                    color: K4Theme.panelDim
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        HoverHandler { id: workspaceHover }
                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: root.plugin.selectWorkspace(
                                workspaceCard.workspaceId)
                        }
                    }
                }
            }

            Rectangle {
                id: stage
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: K4Theme.panelSurface
                border.width: 1
                border.color: K4Theme.panelLine
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 7

                    RowLayout {
                        visible: root.plugin.showWorkspaces
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 25 : 0

                        Text {
                            text: `Workspace ${root.plugin.selectedWorkspaceId}`
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }

                        Text {
                            text: `${root.plugin.count} window${root.plugin.count === 1 ? "" : "s"}`
                            color: K4Theme.panelMuted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 10
                            renderType: Text.NativeRendering
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "↑ ↓ workspaces · Tab windows"
                            color: K4Theme.panelDim
                            font.family: K4Theme.uiFont
                            font.pixelSize: 9
                            renderType: Text.NativeRendering
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        GridView {
                            id: windowGrid
                            anchors.fill: parent
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.plugin.entries
                            currentIndex: root.plugin.index
                            flow: root.plugin.showWorkspaces
                                ? GridView.FlowLeftToRight
                                : GridView.FlowTopToBottom
                            cellWidth: root.plugin.showWorkspaces
                                ? Math.max(190, width / 2)
                                : 210
                            cellHeight: root.plugin.showWorkspaces ? 155 : height

                            delegate: Item {
                                id: cardCell
                                required property var modelData
                                required property int index
                                width: GridView.view.cellWidth
                                height: GridView.view.cellHeight

                                Rectangle {
                                    id: card
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: 12
                                    color: K4Theme.panelSurfaceHi
                                    border.width: selected ? 1 : 0
                                    border.color: K4Theme.blue
                                    clip: true

                                    readonly property bool selected:
                                        cardCell.index === root.plugin.index
                                    readonly property var toplevel:
                                        K4Windows.toplevelFor(cardCell.modelData)

                                    Rectangle {
                                        id: previewFrame
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.bottom: cardMeta.top
                                        color: K4Theme.panelSurfaceHot
                                        clip: true

                                        Image {
                                            anchors.centerIn: parent
                                            width: 44
                                            height: 44
                                            source: K4Windows.appIcon(cardCell.modelData)
                                            sourceSize: Qt.size(64, 64)
                                            fillMode: Image.PreserveAspectFit
                                            opacity: card.toplevel ? 0 : 0.8
                                        }

                                        Loader {
                                            anchors.fill: parent
                                            active: card.toplevel !== null
                                            sourceComponent: ScreencopyView {
                                                captureSource: card.toplevel
                                                live: true
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            color: card.selected
                                                ? Qt.rgba(0.04, 0.52, 1, 0.08)
                                                : cardMouse.containsMouse
                                                    ? Qt.rgba(1, 1, 1, 0.035)
                                                    : "transparent"
                                        }
                                    }

                                    Rectangle {
                                        id: cardMeta
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 38
                                        color: "#0b0b0d"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 7

                                            Image {
                                                Layout.preferredWidth: 21
                                                Layout.preferredHeight: 21
                                                source: K4Windows.appIcon(cardCell.modelData)
                                                sourceSize: Qt.size(32, 32)
                                                fillMode: Image.PreserveAspectFit
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: K4Windows.appName(cardCell.modelData)
                                                    color: K4Theme.ink
                                                    font.family: K4Theme.uiFont
                                                    font.pixelSize: 11
                                                    font.weight: card.selected
                                                        ? Font.DemiBold : Font.Medium
                                                    elide: Text.ElideRight
                                                    renderType: Text.NativeRendering
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: K4Windows.title(cardCell.modelData)
                                                    color: K4Theme.panelMuted
                                                    font.family: K4Theme.uiFont
                                                    font.pixelSize: 9
                                                    elide: Text.ElideRight
                                                    renderType: Text.NativeRendering
                                                }
                                            }

                                            Text {
                                                visible: cardCell.modelData?.floating ?? false
                                                text: "Floating"
                                                color: K4Theme.panelDim
                                                font.family: K4Theme.uiFont
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: !root.plugin.showWorkspaces
                                            && !root.plugin.altTabCurrentWorkspaceOnly
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.margins: 7
                                        width: workspaceBadge.implicitWidth + 12
                                        height: 20
                                        radius: 10
                                        color: "#bb000000"
                                        border.width: 1
                                        border.color: K4Theme.panelLine

                                        Text {
                                            id: workspaceBadge
                                            anchors.centerIn: parent
                                            text: `WS ${K4Windows.workspace(cardCell.modelData)}`
                                            color: K4Theme.panelInkSoft
                                            font.family: K4Theme.uiFont
                                            font.pixelSize: 9
                                            font.weight: Font.DemiBold
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    Rectangle {
                                        visible: cardMouse.containsMouse || card.selected
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 7
                                        width: 24
                                        height: 24
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
                                                root.plugin.index = cardCell.index
                                                root.plugin.closeCurrent()
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: cardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                        onEntered: root.plugin.index = cardCell.index
                                        onClicked: function(mouse) {
                                            root.plugin.index = cardCell.index
                                            if (mouse.button === Qt.MiddleButton)
                                                root.plugin.closeCurrent()
                                            else
                                                root.plugin.choose()
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.plugin.count === 0
                            anchors.centerIn: parent
                            text: root.plugin.showWorkspaces
                                ? "No windows on this workspace"
                                : "No windows available"
                            color: K4Theme.panelMuted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 12
                            renderType: Text.NativeRendering
                        }

                        Connections {
                            target: root.plugin
                            function onIndexChanged() {
                                if (root.plugin.count > 0)
                                    windowGrid.positionViewAtIndex(
                                        root.plugin.index, GridView.Contain)
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            text: root.plugin.showWorkspaces
                ? "Enter focuses · middle click/Delete closes · Esc returns"
                : "Alt release focuses · Tab cycles · middle click/Delete closes"
            color: K4Theme.panelDim
            font.family: K4Theme.uiFont
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
            renderType: Text.NativeRendering
        }
    }
}
