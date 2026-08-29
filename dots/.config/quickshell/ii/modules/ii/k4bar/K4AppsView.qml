import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Five-column utility drawer adapted from k4ditano/k4 AppsView at the pinned
// source commit. Package-update controls are outside this K4-07 tracer.
Item {
    id: root

    required property var plugin
    property int focusAttempts: 0

    readonly property string searchGlyph: String.fromCodePoint(0xF0349)

    opacity: 0
    Component.onCompleted: {
        focusAttempts = 0
        fadeIn.start()
        focusTimer.start()
        Qt.callLater(() => appsInput.forceActiveFocus())
    }

    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    Timer {
        id: focusTimer
        interval: 140
        onTriggered: {
            if (!root.plugin.open)
                return
            appsInput.forceActiveFocus()
            if (!appsInput.activeFocus && root.focusAttempts < 6) {
                root.focusAttempts += 1
                restart()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 12
            color: K4Theme.surface

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                Text {
                    text: root.searchGlyph
                    color: K4Theme.muted
                    font.family: K4Theme.iconFont
                    font.pixelSize: 15
                    renderType: Text.NativeRendering
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: appsInput.text.length === 0
                        text: "Search K4 utilities"
                        color: K4Theme.dim
                        font.family: K4Theme.uiFont
                        font.pixelSize: 16
                        renderType: Text.NativeRendering
                    }

                    TextInput {
                        id: appsInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        color: K4Theme.ink
                        font.family: K4Theme.uiFont
                        font.pixelSize: 16
                        focus: true
                        activeFocusOnTab: true
                        clip: true
                        selectByMouse: true
                        cursorVisible: true
                        selectionColor: K4Theme.blue
                        selectedTextColor: K4Theme.ink
                        text: root.plugin.query

                        onTextEdited: root.plugin.query = text

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                root.plugin.close()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.plugin.launchSelected()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Right) {
                                root.plugin.move(1, 0)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Left) {
                                root.plugin.move(-1, 0)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down) {
                                root.plugin.move(0, 1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                root.plugin.move(0, -1)
                                event.accepted = true
                            }
                        }
                    }
                }

                Text {
                    text: String(root.plugin.applications.length)
                    color: K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        GridView {
            id: utilityGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.plugin.applications
            currentIndex: root.plugin.applications.length > 0 ? root.plugin.selection : -1
            cellWidth: width / root.plugin.columns
            cellHeight: 104

            onCurrentIndexChanged: {
                if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, GridView.Contain)
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 5
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: parent.pressed ? K4Theme.muted : K4Theme.dim
                }
                background: Item {}
            }

            K4ViewportPointer {
                id: utilityPointer
                surface: utilityGrid
            }

            delegate: Rectangle {
                id: utilityTile
                required property var modelData
                required property int index
                readonly property bool hovered: utilityPointer.contains(utilityTile)

                width: GridView.view.cellWidth - 6
                height: GridView.view.cellHeight - 6
                radius: 14
                opacity: modelData.enabled ? 1 : 0.38
                color: index === root.plugin.selection || hovered
                    ? K4Theme.surfaceHi : "transparent"
                border.width: index === root.plugin.selection ? 2 : 0
                border.color: K4Theme.blue

                onHoveredChanged: {
                    if (hovered)
                        root.plugin.selection = index
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 14
                    spacing: 7

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.applicationGlyph.length > 0
                            ? modelData.applicationGlyph : K4Theme.ico.grid
                        color: modelData.enabled ? K4Theme.ink : K4Theme.dim
                        font.family: K4Theme.iconFont
                        font.pixelSize: 30
                        renderType: Text.NativeRendering
                    }

                    Text {
                        width: parent.width
                        text: modelData.title ?? modelData.name
                        color: modelData.enabled ? K4Theme.ink : K4Theme.dim
                        font.family: K4Theme.uiFont
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        root.plugin.selection = utilityTile.index
                        if (utilityTile.modelData.enabled)
                            root.plugin.launch(utilityTile.modelData.name)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.plugin.applications.length === 0
                text: root.plugin.query.length > 0
                    ? "No matching utilities"
                    : "No K4 utilities registered yet"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 13
                renderType: Text.NativeRendering
            }
        }
    }
}
