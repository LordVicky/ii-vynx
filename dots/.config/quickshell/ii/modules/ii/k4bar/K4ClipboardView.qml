import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Clipboard list adapted from k4ditano/k4 ClipboardView at the pinned source
// commit. The row model is supplied by K4Clipboard over ii-vynx Cliphist.
Item {
    id: root
    required property var plugin
    property int focusAttempts: 0

    opacity: 0
    Component.onCompleted: {
        fadeIn.start()
        focusTimer.start()
        Qt.callLater(() => searchInput.forceActiveFocus())
    }

    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0; to: 1; duration: 180
        easing.type: Easing.OutCubic
    }

    Timer {
        id: focusTimer
        interval: 140
        onTriggered: {
            if (!root.plugin.open) return
            searchInput.forceActiveFocus()
            if (!searchInput.activeFocus && root.focusAttempts < 6) {
                root.focusAttempts += 1
                restart()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 8

            Text {
                text: String.fromCodePoint(0xF0349)
                color: K4Theme.muted
                font.family: K4Theme.iconFont
                font.pixelSize: 15
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: searchInput.text.length === 0
                    text: "Search clipboard…"
                    color: K4Theme.dim
                    font.family: K4Theme.uiFont
                    font.pixelSize: 15
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 15
                    selectByMouse: true
                    selectionColor: K4Theme.blue
                    selectedTextColor: K4Theme.ink
                    cursorVisible: true
                    focus: true
                    activeFocusOnTab: true
                    clip: true
                    text: root.plugin.query
                    onTextEdited: {
                        root.plugin.query = text
                        root.plugin.index = 0
                    }
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            root.plugin.close(); event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            root.plugin.moveSelection(1); event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.plugin.moveSelection(-1); event.accepted = true
                        } else if (event.key === Qt.Key_PageDown) {
                            root.plugin.moveSelection(6); event.accepted = true
                        } else if (event.key === Qt.Key_PageUp) {
                            root.plugin.moveSelection(-6); event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.plugin.choose(); event.accepted = true
                        } else if (event.key === Qt.Key_Delete) {
                            root.plugin.removeCurrent(); event.accepted = true
                        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_P) {
                            root.plugin.pinCurrent(); event.accepted = true
                        }
                    }
                }
            }

            Text {
                text: root.plugin.count + (root.plugin.count === 1 ? " copy" : " copies")
                color: K4Theme.dim
                font.family: K4Theme.uiFont
                font.pixelSize: 10
            }

            Rectangle {
                Layout.preferredWidth: clearText.implicitWidth + 20
                Layout.preferredHeight: 22
                radius: 11
                visible: K4Clipboard.count > 0
                color: clearMouse.containsMouse ? K4Theme.red : K4Theme.surfaceHi
                Text {
                    id: clearText
                    anchors.centerIn: parent
                    text: "Clear"
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: K4Clipboard.clear()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: K4Theme.surfaceHi }

        ListView {
            id: rows
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 300
            clip: true
            spacing: 3
            boundsBehavior: Flickable.StopAtBounds
            model: root.plugin.entries
            currentIndex: root.plugin.count > 0 ? root.plugin.index : -1
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 5
                contentItem: Rectangle { implicitWidth: 4; radius: 2; color: parent.pressed ? K4Theme.muted : K4Theme.dim }
                background: Item {}
            }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool selected: index === root.plugin.index
                width: ListView.view.width
                height: 48
                radius: 9
                color: selected ? K4Theme.surfaceHi : rowMouse.containsMouse ? K4Theme.surface : "transparent"
                Behavior on color { ColorAnimation { duration: 110 } }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.plugin.index = row.index
                    onClicked: {
                        root.plugin.index = row.index
                        root.plugin.choose()
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 9
                    z: 1

                    Text {
                        Layout.preferredWidth: 30
                        horizontalAlignment: Text.AlignHCenter
                        text: row.modelData.type === "image" ? String.fromCodePoint(0xF021F)
                            : row.modelData.label === "link" ? String.fromCodePoint(0xF0339)
                            : row.modelData.label === "color" ? String.fromCodePoint(0xF0765)
                            : row.modelData.label === "command" ? String.fromCodePoint(0xF018D)
                            : row.modelData.label === "path" ? String.fromCodePoint(0xF024B)
                            : row.modelData.label === "code" ? String.fromCodePoint(0xF0169)
                            : String.fromCodePoint(0xF0219)
                        color: row.selected ? K4Theme.ink : K4Theme.muted
                        font.family: K4Theme.iconFont
                        font.pixelSize: 17
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.type === "image" ? "Image clipboard entry" : row.modelData.summary
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                        RowLayout {
                            spacing: 6
                            Text {
                                text: row.modelData.label
                                color: K4Theme.blue
                                font.family: K4Theme.uiFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                            Text {
                                visible: row.modelData.lines > 1
                                text: row.modelData.lines + " lines"
                                color: K4Theme.dim
                                font.family: K4Theme.uiFont
                                font.pixelSize: 10
                            }
                        }
                    }

                    Rectangle {
                        visible: row.modelData.label === "color"
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        radius: 4
                        color: row.modelData.label === "color" ? row.modelData.summary : "transparent"
                        border.width: 1
                        border.color: "#33ffffff"
                    }

                    Text {
                        text: String.fromCodePoint(0xF0403)
                        color: row.modelData.pinned ? K4Theme.yellow : K4Theme.dim
                        opacity: row.modelData.pinned || row.selected || rowMouse.containsMouse ? 1 : 0
                        font.family: K4Theme.iconFont
                        font.pixelSize: 13
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: K4Clipboard.togglePin(row.modelData)
                        }
                    }

                    Text {
                        text: K4Theme.ico.close
                        color: K4Theme.dim
                        opacity: row.selected || rowMouse.containsMouse ? 1 : 0
                        font.family: K4Theme.iconFont
                        font.pixelSize: 12
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: K4Clipboard.remove(row.modelData)
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.plugin.count === 0
                text: K4Clipboard.count === 0 ? "Nothing copied yet" : "No clipboard matches"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 12
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.plugin.count > 0
            text: "enter copies · delete removes · ctrl+p pins · esc closes"
            color: K4Theme.dim
            font.family: K4Theme.uiFont
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
