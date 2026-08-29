import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Spotlight-style launcher surface adapted from k4ditano/k4 LauncherView at
// the pinned source commit. ii-vynx supplies DesktopEntry data; this view owns
// only K4 launcher presentation and interaction.
Item {
    id: root

    required property var plugin
    property int focusAttempts: 0

    readonly property string searchGlyph: String.fromCodePoint(0xF0349)
    readonly property string enterGlyph: String.fromCodePoint(0xF0311)

    opacity: 0
    Component.onCompleted: {
        root.plugin.rebuild()
        focusAttempts = 0
        fadeIn.start()
        focusTimer.start()
        Qt.callLater(() => launcherInput.forceActiveFocus())
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
            launcherInput.forceActiveFocus()
            if (!launcherInput.activeFocus && root.focusAttempts < 6) {
                root.focusAttempts += 1
                restart()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 14
        anchors.bottomMargin: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 12

            Text {
                text: root.searchGlyph
                color: K4Theme.muted
                font.family: K4Theme.iconFont
                font.pixelSize: 20
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.plugin.query.length === 0
                    text: "Search applications"
                    color: K4Theme.dim
                    font.family: K4Theme.uiFont
                    font.pixelSize: 19
                    renderType: Text.NativeRendering
                }

                TextInput {
                    id: launcherInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 19
                    focus: true
                    activeFocusOnTab: true
                    clip: true
                    selectByMouse: true
                    cursorVisible: true
                    selectionColor: K4Theme.blue
                    selectedTextColor: K4Theme.ink
                    text: root.plugin.query

                    onTextEdited: {
                        root.plugin.query = text
                        root.plugin.rebuild()
                    }

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            root.plugin.close()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.plugin.launchSelected()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            root.plugin.moveSelection(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.plugin.moveSelection(-1)
                            event.accepted = true
                        }
                    }
                }
            }

            Text {
                text: "esc"
                color: K4Theme.dim
                font.family: K4Theme.uiFont
                font.pixelSize: 11
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: K4Theme.surfaceHi
        }

        ListView {
            id: appResults
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: root.plugin.matches
            currentIndex: root.plugin.index
            highlightMoveDuration: 140

            onCurrentIndexChanged: {
                if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)
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
                id: launcherPointer
                surface: appResults
            }

            delegate: Rectangle {
                id: appRow
                required property var modelData
                required property int index
                readonly property bool hovered: launcherPointer.contains(appRow)

                width: ListView.view.width
                height: 42
                radius: 10
                color: index === root.plugin.index || hovered
                    ? K4Theme.surfaceHi : "transparent"

                onHoveredChanged: {
                    if (hovered)
                        root.plugin.index = index
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 12

                    IconImage {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignVCenter
                        source: Quickshell.iconPath(appRow.modelData.icon, "image-missing")
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: appRow.modelData.name ?? ""
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Text {
                            Layout.fillWidth: true
                            text: appRow.modelData.genericName
                                || appRow.modelData.comment
                                || appRow.modelData.id
                                || ""
                            color: K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }
                    }

                    Text {
                        visible: appRow.index === root.plugin.index
                        text: root.enterGlyph
                        color: K4Theme.muted
                        font.family: K4Theme.iconFont
                        font.pixelSize: 14
                        renderType: Text.NativeRendering
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.plugin.index = appRow.index
                        root.plugin.launchSelected()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.plugin.matches.length === 0
                text: "No results"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 13
                renderType: Text.NativeRendering
            }
        }
    }
}
