import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var plugin

    readonly property var actions: [
        { title: "Screenshot region", detail: "Select an area", glyph: String.fromCodePoint(0xF019E) },
        { title: "Screenshot screen", detail: "Copy full screen", glyph: String.fromCodePoint(0xF0379) },
        { title: "Record region", detail: "Select area + audio", glyph: String.fromCodePoint(0xF0E52) },
        { title: "Record screen", detail: "Full screen + audio", glyph: String.fromCodePoint(0xF0474) }
    ]

    focus: true
    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.plugin.close()
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            root.plugin.move(-1, 0)
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            root.plugin.move(1, 0)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            root.plugin.move(0, -1)
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            root.plugin.move(0, 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            root.plugin.trigger(root.plugin.selection)
            event.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            spacing: 8

            Text {
                text: "Capture"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 11
                renderType: Text.NativeRendering
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                visible: root.plugin.recording
                spacing: 6

                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    color: K4Theme.red
                }

                Text {
                    text: root.plugin.recordingDuration
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
            }

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

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    id: actionTile
                    required property var modelData
                    required property int index

                    readonly property bool actionEnabled: !(root.plugin.recording && index >= 2)

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 13
                    opacity: actionEnabled ? 1 : 0.38
                    color: index === root.plugin.selection
                        ? K4Theme.surfaceHi
                        : actionMouse.containsMouse ? K4Theme.surface : "transparent"
                    border.width: index === root.plugin.selection ? 1 : 0
                    border.color: K4Theme.blue

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Text {
                            text: actionTile.modelData.glyph
                            color: index === root.plugin.selection ? K4Theme.ink : K4Theme.muted
                            font.family: K4Theme.iconFont
                            font.pixelSize: 25
                            renderType: Text.NativeRendering
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: actionTile.modelData.title
                                color: K4Theme.ink
                                font.family: K4Theme.uiFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }

                            Text {
                                Layout.fillWidth: true
                                text: actionTile.modelData.detail
                                color: K4Theme.dim
                                font.family: K4Theme.uiFont
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }
                        }
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: actionTile.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: if (actionTile.actionEnabled) root.plugin.selection = actionTile.index
                        onClicked: if (actionTile.actionEnabled) root.plugin.trigger(actionTile.index)
                    }
                }
            }
        }

        Rectangle {
            visible: root.plugin.recording
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 34 : 0
            radius: 12
            color: stopMouse.containsMouse ? "#3a1416" : K4Theme.surface
            border.width: 1
            border.color: Qt.rgba(1, 0.27, 0.23, 0.35)

            RowLayout {
                anchors.centerIn: parent
                spacing: 7

                Rectangle {
                    Layout.preferredWidth: 9
                    Layout.preferredHeight: 9
                    radius: 2
                    color: K4Theme.red
                }

                Text {
                    text: "Stop recording"
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: stopMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.plugin.stopRecording()
            }
        }
    }
}
