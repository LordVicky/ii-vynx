import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var plugin

    focus: true
    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.plugin.close()
            event.accepted = true
        } else if (root.plugin.tab === "displays"
                && event.key === Qt.Key_Up && root.plugin.drafts.length > 0) {
            root.plugin.selectedIndex = Math.max(0, root.plugin.selectedIndex - 1)
            event.accepted = true
        } else if (root.plugin.tab === "displays"
                && event.key === Qt.Key_Down && root.plugin.drafts.length > 0) {
            root.plugin.selectedIndex = Math.min(root.plugin.drafts.length - 1,
                root.plugin.selectedIndex + 1)
            event.accepted = true
        }
    }

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool selected: false
        signal clicked()

        implicitWidth: Math.max(52, chipText.implicitWidth + 20)
        implicitHeight: 30
        radius: 15
        opacity: enabled ? 1 : 0.35
        color: selected ? K4Theme.surfaceHi
            : chipMouse.containsMouse && enabled ? K4Theme.surface : "transparent"
        border.width: selected ? 1 : 0
        border.color: selected ? K4Theme.blue : "transparent"

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.selected ? K4Theme.ink : K4Theme.muted
            font.family: K4Theme.uiFont
            font.pixelSize: 10
            font.weight: chip.selected ? Font.DemiBold : Font.Normal
            renderType: Text.NativeRendering
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: chip.enabled
            cursorShape: chip.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: chip.clicked()
        }
    }

    component Action: Rectangle {
        id: action
        property string label: ""
        property bool primary: false
        signal clicked()

        implicitWidth: actionText.implicitWidth + 26
        implicitHeight: 34
        radius: 17
        opacity: enabled ? 1 : 0.38
        color: primary ? K4Theme.ink
            : actionMouse.containsMouse && enabled ? K4Theme.surfaceHi : K4Theme.surface

        Text {
            id: actionText
            anchors.centerIn: parent
            text: action.label
            color: action.primary ? K4Theme.islandBg : K4Theme.ink
            font.family: K4Theme.uiFont
            font.pixelSize: 10
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: action.enabled
            cursorShape: action.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: action.clicked()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 9

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            spacing: 8

            Text {
                text: "Displays"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 11
                renderType: Text.NativeRendering
            }

            Text {
                visible: root.plugin.dirty
                text: "session changes"
                color: K4Theme.yellow
                font.family: K4Theme.uiFont
                font.pixelSize: 9
                renderType: Text.NativeRendering
            }

            Item { Layout.fillWidth: true }

            Text {
                text: K4Theme.ico.close
                color: closeMouse.containsMouse ? K4Theme.ink : K4Theme.muted
                font.family: K4Theme.iconFont
                font.pixelSize: 14
                renderType: Text.NativeRendering

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.plugin.close()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 5

            Chip {
                label: "Displays"
                selected: root.plugin.tab === "displays"
                enabled: !root.plugin.busy
                onClicked: root.plugin.tab = "displays"
            }

            Chip {
                label: "Workspaces"
                selected: root.plugin.tab === "workspaces"
                enabled: !root.plugin.busy
                onClicked: root.plugin.tab = "workspaces"
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Session only"
                color: K4Theme.dim
                font.family: K4Theme.uiFont
                font.pixelSize: 8
                renderType: Text.NativeRendering
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.fill: parent
                spacing: 10
                visible: root.plugin.tab === "displays"

                Rectangle {
                    Layout.preferredWidth: 220
                    Layout.fillHeight: true
                    radius: 14
                    color: K4Theme.surface

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 7

                        Text {
                            text: "Active monitors"
                            color: K4Theme.dim
                            font.family: K4Theme.uiFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: width
                            contentHeight: monitorColumn.implicitHeight

                            Column {
                                id: monitorColumn
                                width: parent.width
                                spacing: 5

                                Repeater {
                                    model: root.plugin.drafts

                                    delegate: Rectangle {
                                        id: monitorRow
                                        required property var modelData
                                        required property int index

                                        width: monitorColumn.width
                                        height: 58
                                        radius: 11
                                        color: index === root.plugin.selectedIndex
                                            ? K4Theme.surfaceHi
                                            : monitorMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                                        border.width: index === root.plugin.selectedIndex ? 1 : 0
                                        border.color: K4Theme.blue

                                        Column {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 11
                                            anchors.rightMargin: 8
                                            spacing: 3

                                            Text {
                                                width: parent.width
                                                text: monitorRow.modelData.name
                                                color: K4Theme.ink
                                                font.family: K4Theme.uiFont
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                width: parent.width
                                                text: monitorRow.modelData.mode + "  ·  "
                                                    + Number(monitorRow.modelData.scale).toFixed(2) + "×"
                                                color: K4Theme.dim
                                                font.family: K4Theme.uiFont
                                                font.pixelSize: 9
                                                elide: Text.ElideRight
                                                renderType: Text.NativeRendering
                                            }
                                        }

                                        MouseArea {
                                            id: monitorMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.plugin.selectedIndex = monitorRow.index
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.025)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 9

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: root.plugin.selectedDraft?.name ?? "No display selected"
                                color: K4Theme.ink
                                font.family: K4Theme.uiFont
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.plugin.selectedDraft?.description ?? ""
                                color: K4Theme.dim
                                font.family: K4Theme.uiFont
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }
                        }

                        Text {
                            text: "Mode"
                            color: K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            clip: true
                            contentWidth: modeRow.implicitWidth
                            contentHeight: height
                            boundsBehavior: Flickable.StopAtBounds

                            Row {
                                id: modeRow
                                height: parent.height
                                spacing: 5

                                Repeater {
                                    model: root.plugin.selectedDraft?.availableModes ?? []
                                    delegate: Chip {
                                        required property var modelData
                                        label: String(modelData)
                                        selected: String(modelData) === String(root.plugin.selectedDraft?.mode ?? "")
                                        enabled: !root.plugin.busy
                                        onClicked: root.plugin.updateSelected("mode", String(modelData))
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Scale"
                            color: K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Repeater {
                                model: [0.75, 1.0, 1.25, 1.5, 2.0]
                                delegate: Chip {
                                    required property var modelData
                                    label: Number(modelData).toFixed(Number(modelData) % 1 === 0 ? 0 : 2) + "×"
                                    selected: Math.abs(Number(root.plugin.selectedDraft?.scale ?? 1) - Number(modelData)) < 0.01
                                    enabled: !root.plugin.busy
                                    onClicked: root.plugin.updateSelected("scale", Number(modelData))
                                }
                            }
                        }

                        Text {
                            text: "Rotation"
                            color: K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Repeater {
                                model: [
                                    { value: 0, label: "0°" },
                                    { value: 1, label: "90°" },
                                    { value: 2, label: "180°" },
                                    { value: 3, label: "270°" }
                                ]
                                delegate: Chip {
                                    required property var modelData
                                    label: modelData.label
                                    selected: Number(root.plugin.selectedDraft?.transform ?? 0) === modelData.value
                                    enabled: !root.plugin.busy
                                    onClicked: root.plugin.updateSelected("transform", modelData.value)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Position"
                                color: K4Theme.muted
                                font.family: K4Theme.uiFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                            }

                            Text {
                                text: root.plugin.selectedDraft
                                    ? String(root.plugin.selectedDraft.x) + ", " + String(root.plugin.selectedDraft.y)
                                    : "—"
                                color: K4Theme.dim
                                font.family: K4Theme.uiFont
                                font.pixelSize: 9
                                renderType: Text.NativeRendering
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                visible: root.plugin.drafts.length < 2
                                text: "Connect another monitor to arrange"
                                color: K4Theme.dim
                                font.family: K4Theme.uiFont
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Repeater {
                                model: [
                                    { id: "left", label: "Left" },
                                    { id: "right", label: "Right" },
                                    { id: "above", label: "Above" },
                                    { id: "below", label: "Below" },
                                    { id: "mirror", label: "Mirror" }
                                ]
                                delegate: Chip {
                                    required property var modelData
                                    label: modelData.label
                                    enabled: root.plugin.drafts.length > 1 && !root.plugin.busy
                                    onClicked: root.plugin.placeSelected(modelData.id)
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: root.plugin.tab === "workspaces"
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.025)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: "Workspace routing"
                        color: K4Theme.ink
                        font.family: K4Theme.uiFont
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.plugin.drafts.length < 2
                            ? "One monitor is active. You can still create session rules for workspaces; cross-monitor routing needs another connected monitor."
                            : "Choose the monitor that should own each workspace. Existing workspaces move on Apply; future openings follow the session rule."
                        color: K4Theme.dim
                        font.family: K4Theme.uiFont
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                        renderType: Text.NativeRendering
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: workspaceColumn.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: workspaceColumn
                            width: parent.width
                            spacing: 5

                            Repeater {
                                model: root.plugin.workspaceNumbers

                                delegate: Rectangle {
                                    id: workspaceRow
                                    required property var modelData
                                    readonly property int workspaceNumber: Number(modelData)
                                    readonly property string assignedMonitor: root.plugin.workspaceMonitor(workspaceNumber)

                                    width: workspaceColumn.width
                                    height: 42
                                    radius: 10
                                    color: workspaceMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.035) : K4Theme.surface

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        Text {
                                            text: "Workspace " + workspaceRow.workspaceNumber
                                            color: K4Theme.ink
                                            font.family: K4Theme.uiFont
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            renderType: Text.NativeRendering
                                            Layout.preferredWidth: 102
                                        }

                                        Repeater {
                                            model: root.plugin.drafts

                                            delegate: Chip {
                                                id: monitorChip
                                                required property var modelData
                                                label: String(modelData.name)
                                                selected: workspaceRow.assignedMonitor === String(modelData.name)
                                                enabled: !root.plugin.busy
                                                onClicked: root.plugin.setWorkspaceAssignment(
                                                    workspaceRow.workspaceNumber, String(monitorChip.modelData.name))
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            visible: workspaceRow.assignedMonitor.length === 0
                                            text: "No live/rule assignment"
                                            color: K4Theme.dim
                                            font.family: K4Theme.uiFont
                                            font.pixelSize: 8
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    MouseArea {
                                        id: workspaceMouse
                                        anchors.fill: parent
                                        acceptedButtons: Qt.NoButton
                                        hoverEnabled: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: root.plugin.message
                color: root.plugin.messageError ? K4Theme.red : K4Theme.dim
                font.family: K4Theme.uiFont
                font.pixelSize: 9
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Action {
                label: "Refresh"
                enabled: !root.plugin.busy
                onClicked: root.plugin.refresh(false)
            }

            Action {
                label: root.plugin.busy ? "Applying…" : "Apply"
                primary: true
                enabled: root.plugin.dirty && !root.plugin.busy
                onClicked: root.plugin.apply()
            }
        }
    }
}
