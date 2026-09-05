pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Super+Tab mirrors the actual Hyprland workspace geometry and supports native
// window moves between workspaces. Alt+Tab remains a focused windows-only
// switcher with larger live previews.
Item {
    id: root
    required property var plugin
    focus: true
    opacity: 0

    property int draggingTargetWorkspace: -1

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

    function finishMove(row, targetWorkspace) {
        root.draggingTargetWorkspace = -1
        K4Windows.moveToWorkspace(row, targetWorkspace)
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

    Keys.onReleased: function(event) {
        if (root.plugin.mode === "switcher" && event.key === Qt.Key_Alt) {
            root.plugin.choose()
            event.accepted = true
        }
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
                text: root.plugin.showWorkspaces ? "Windows" : "Switch windows"
                color: K4Theme.ink
                font.family: K4Theme.uiFont
                font.pixelSize: 16
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

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Rectangle {
                id: workspaceRail
                visible: root.plugin.showWorkspaces
                Layout.preferredWidth: 226
                Layout.fillHeight: true
                radius: 15
                color: K4Theme.panelSurface
                border.width: 1
                border.color: K4Theme.panelLine
                clip: true

                ListView {
                    id: workspaceList
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 9
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: K4Workspaces.list.filter(workspace => workspace.id > 0)

                    delegate: Rectangle {
                        id: workspaceCard
                        required property var modelData
                        required property int index
                        property bool dragHover: false
                        readonly property int workspaceId: Number(modelData.id)
                        readonly property bool selected:
                            workspaceId === root.plugin.selectedWorkspaceId
                        readonly property bool active:
                            workspaceId === K4Workspaces.activeId
                        readonly property int windowCount:
                            K4Windows.windowCountForWorkspace(workspaceId)

                        width: ListView.view.width
                        height: 105
                        radius: 12
                        color: workspaceCard.dragHover
                            ? Qt.rgba(0.04, 0.52, 1, 0.13)
                            : workspaceCard.selected
                                ? K4Theme.panelSurfaceHot
                                : workspaceHover.hovered
                                    ? K4Theme.panelSurfaceHi : "transparent"
                        border.width: workspaceCard.dragHover || workspaceCard.selected ? 1 : 0
                        border.color: workspaceCard.dragHover
                            ? K4Theme.blue
                            : workspaceCard.selected ? K4Theme.blue : "transparent"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 18
                                spacing: 6

                                Rectangle {
                                    visible: workspaceCard.active
                                    Layout.preferredWidth: 6
                                    Layout.preferredHeight: 6
                                    radius: 3
                                    color: K4Theme.blue
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

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: workspaceCard.windowCount
                                    color: K4Theme.panelMuted
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering
                                }
                            }

                            K4WorkspaceLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                workspaceId: workspaceCard.workspaceId
                                mini: true
                                interactive: false
                            }
                        }

                        HoverHandler { id: workspaceHover }
                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: root.plugin.selectWorkspace(
                                workspaceCard.workspaceId)
                        }

                        DropArea {
                            anchors.fill: parent
                            enabled: selectedWorkspaceLayout.draggingWindow !== null
                            onEntered: {
                                root.draggingTargetWorkspace = workspaceCard.workspaceId
                                workspaceCard.dragHover = true
                            }
                            onExited: {
                                workspaceCard.dragHover = false
                                if (root.draggingTargetWorkspace
                                        === workspaceCard.workspaceId)
                                    root.draggingTargetWorkspace = -1
                            }
                        }
                    }
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
                clip: false

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        visible: root.plugin.showWorkspaces
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 28 : 0
                        spacing: 6

                        Text {
                            text: `Workspace ${root.plugin.selectedWorkspaceId}`
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }

                        Text {
                            text: root.plugin.count === 1
                                ? "1 window" : `${root.plugin.count} windows`
                            color: K4Theme.panelMuted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 10
                            renderType: Text.NativeRendering
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: selectedWorkspaceLayout.draggingWindow
                                ? "Drop on a workspace to move"
                                : "↑ ↓ workspaces · Tab windows · drag to move"
                            color: selectedWorkspaceLayout.draggingWindow
                                ? K4Theme.blue : K4Theme.panelDim
                            font.family: K4Theme.uiFont
                            font.pixelSize: 9
                            renderType: Text.NativeRendering
                        }
                    }

                    Item {
                        visible: root.plugin.showWorkspaces
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        K4WorkspaceLayout {
                            id: selectedWorkspaceLayout
                            anchors.fill: parent
                            workspaceId: Math.max(1, root.plugin.selectedWorkspaceId)
                            interactive: true
                            mini: false
                            showLabels: true
                            selectedIndex: root.plugin.index
                            draggingTargetWorkspace: root.draggingTargetWorkspace
                            onHighlighted: index => root.plugin.index = index
                            onActivated: row => root.plugin.chooseWindow(row)
                            onCloseRequested: row => K4Windows.close(row)
                            onMoveRequested: (row, targetWorkspace) =>
                                root.finishMove(row, targetWorkspace)
                        }
                    }

                    Item {
                        visible: !root.plugin.showWorkspaces
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        GridView {
                            id: switcherGrid
                            anchors.fill: parent
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.plugin.entries
                            currentIndex: root.plugin.index
                            flow: GridView.FlowTopToBottom
                            cellWidth: 270
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
                                        width: switcherWorkspaceBadge.implicitWidth + 14
                                        height: 21
                                        radius: 10.5
                                        color: "#bb000000"
                                        border.width: 1
                                        border.color: K4Theme.panelLine
                                        z: 3

                                        Text {
                                            id: switcherWorkspaceBadge
                                            anchors.centerIn: parent
                                            text: `WS ${K4Windows.workspace(switcherCell.modelData)}`
                                            color: K4Theme.panelInkSoft
                                            font.family: K4Theme.uiFont
                                            font.pixelSize: 9
                                            font.weight: Font.DemiBold
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    MouseArea {
                                        id: switcherMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
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

                        Connections {
                            target: root.plugin
                            function onIndexChanged() {
                                if (root.plugin.count > 0)
                                    switcherGrid.positionViewAtIndex(
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
                ? "Drag a window onto another workspace · click focuses · middle click/Delete closes"
                : "Alt release focuses · Tab cycles · middle click/Delete closes"
            color: K4Theme.panelDim
            font.family: K4Theme.uiFont
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
            renderType: Text.NativeRendering
        }
    }
}
