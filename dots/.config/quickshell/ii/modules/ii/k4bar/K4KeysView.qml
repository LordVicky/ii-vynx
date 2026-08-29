import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Searchable grouped shortcut list adapted from pinned k4 KeysView.
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
        from: 0
        to: 1
        duration: 180
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

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 11
            color: K4Theme.surface

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 9

                Text {
                    text: String.fromCodePoint(0xF030C)
                    color: K4Theme.muted
                    font.family: K4Theme.iconFont
                    font.pixelSize: 15
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text.length === 0
                        text: "Search shortcuts, keys, or actions"
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
                        focus: true
                        activeFocusOnTab: true
                        clip: true
                        selectByMouse: true
                        cursorVisible: true
                        selectionColor: K4Theme.blue
                        text: root.plugin.query
                        onTextEdited: root.plugin.query = text

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                root.plugin.close()
                                event.accepted = true
                            }
                        }
                    }
                }

                Text {
                    text: `${root.plugin.count} of ${K4Keys.count}`
                    color: K4Theme.dim
                    font.family: K4Theme.uiFont
                    font.pixelSize: 10
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 1
            model: root.plugin.entries
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 5
                contentItem: Rectangle { implicitWidth: 4; radius: 2; color: parent.pressed ? K4Theme.muted : K4Theme.dim }
                background: Item {}
            }

            K4ViewportPointer {
                id: keysPointer
                surface: list
            }

            delegate: Column {
                id: row
                required property var modelData
                required property int index
                readonly property bool sectionStart: index === 0 || root.plugin.entries[index - 1].section !== modelData.section
                width: ListView.view.width
                spacing: 0

                Text {
                    visible: row.sectionStart
                    width: parent.width
                    height: visible ? 24 : 0
                    leftPadding: 4
                    verticalAlignment: Text.AlignBottom
                    bottomPadding: 4
                    text: row.modelData.section
                    color: K4Theme.dim
                    font.family: K4Theme.uiFont
                    font.pixelSize: 9
                    font.capitalization: Font.AllUppercase
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: keySurface
                    readonly property bool hovered: keysPointer.contains(keySurface)
                    width: parent.width
                    height: 34
                    radius: 8
                    color: hovered ? K4Theme.surfaceHi : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 10
                        spacing: 10

                        RowLayout {
                            Layout.preferredWidth: 270
                            Layout.fillWidth: false
                            spacing: 4

                            Repeater {
                                model: root.plugin.keys(row.modelData.combo)
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.preferredWidth: keyText.implicitWidth + 12
                                    Layout.preferredHeight: 20
                                    radius: 5
                                    color: K4Theme.surfaceHi
                                    border.width: 1
                                    border.color: "#1affffff"
                                    Text {
                                        id: keyText
                                        anchors.centerIn: parent
                                        text: parent.modelData
                                        color: K4Theme.ink
                                        font.family: K4Theme.uiFont
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.action
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.plugin.count === 0
                text: "No shortcuts match"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 11
            }
        }
    }
}
