import QtQuick

Item {
    id: root

    required property var controller
    required property var panel

    readonly property int gap: 10
    readonly property int stripHeight: 40
    readonly property var configuredIds: K4ShortcutSettings.shortcuts ?? []
    readonly property var available: {
        const result = []
        if (!controller)
            return result
        for (let i = 0; i < configuredIds.length; ++i) {
            const target = controller.plugin(configuredIds[i])
            if (target && target.enabled)
                result.push({ id: configuredIds[i], target: target })
        }
        return result
    }
    readonly property int cellWidth: available.length > 0
        ? (width - gap * available.length) / (available.length + 1)
        : width

    property int dragging: -1
    property int destination: -1

    implicitHeight: stripHeight

    function xFor(slot) {
        return slot * (cellWidth + gap)
    }

    function slotFor(index) {
        if (dragging < 0 || destination < 0 || dragging === destination)
            return index
        if (index === dragging)
            return destination
        if (dragging < destination && index > dragging && index <= destination)
            return index - 1
        if (dragging > destination && index >= destination && index < dragging)
            return index + 1
        return index
    }

    function applyReorder(from, to) {
        if (from < 0 || to < 0 || from === to)
            return

        const visibleIds = available.map(entry => entry.id)
        visibleIds.splice(to, 0, visibleIds.splice(from, 1)[0])
        const hiddenIds = configuredIds.filter(id => visibleIds.indexOf(id) < 0)
        K4ShortcutSettings.setShortcuts(visibleIds.concat(hiddenIds))
    }

    function launch(target) {
        if (!target || !target.enabled)
            return
        panel.close()
        if (typeof target.toggle === "function")
            target.toggle()
        else if (typeof target.open === "function")
            target.open()
    }

    Repeater {
        model: root.available

        delegate: K4PanelTile {
            id: cell
            required property var modelData
            required property int index

            interactive: false
            width: root.cellWidth
            height: root.stripHeight
            y: 0
            z: root.dragging === index ? 2 : 1

            property real draggedX: 0
            x: root.dragging === index ? draggedX : root.xFor(root.slotFor(index))

            Behavior on x {
                enabled: root.dragging !== cell.index
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }

            Row {
                anchors.centerIn: parent
                spacing: 7

                Text {
                    text: K4Theme.ico.grid
                    color: K4Theme.muted
                    font.family: K4Theme.iconFont
                    font.pixelSize: 14
                    renderType: Text.NativeRendering
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: cell.modelData.target.title ?? cell.modelData.id
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                property real grabbedAt: 0
                property bool moved: false

                onPressed: function(event) {
                    grabbedAt = event.x
                    moved = false
                    cell.draggedX = cell.x
                    root.dragging = cell.index
                    root.destination = cell.index
                }

                onPositionChanged: function(event) {
                    if (root.dragging !== cell.index)
                        return
                    if (!moved && Math.abs(event.x - grabbedAt) < 6)
                        return
                    moved = true
                    cell.draggedX = Math.max(0,
                        Math.min(root.width - cell.width,
                            cell.draggedX + event.x - grabbedAt))
                    const next = Math.round(cell.draggedX / (root.cellWidth + root.gap))
                    if (next >= 0 && next < root.available.length)
                        root.destination = next
                }

                onReleased: {
                    const didMove = moved
                    const from = root.dragging
                    const to = root.destination
                    const target = cell.modelData.target

                    root.dragging = -1
                    root.destination = -1

                    if (didMove)
                        root.applyReorder(from, to)
                    else
                        root.launch(target)
                }
            }
        }
    }

    K4PanelTile {
        id: allTile
        readonly property string name: "All"
        readonly property var appsTarget: root.controller?.plugin("apps") ?? null

        x: root.xFor(root.available.length)
        width: root.cellWidth
        height: root.stripHeight
        interactive: appsTarget !== null && appsTarget.enabled
        opacity: interactive ? 1 : 0.42
        onActivated: root.launch(appsTarget)

        Behavior on x {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        Row {
            anchors.centerIn: parent
            spacing: 7

            Text {
                text: K4Theme.ico.grid
                color: K4Theme.muted
                font.family: K4Theme.iconFont
                font.pixelSize: 15
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: allTile.name
                color: allTile.interactive ? K4Theme.ink : K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 11
                font.weight: Font.Medium
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
