import QtQuick
import QtQuick.Layouts

Item {
    id: root

    component DeviceGroup: ColumnLayout {
        id: group
        required property string title
        required property var nodes
        required property var activeNode
        required property bool input

        Layout.fillWidth: true
        spacing: 4

        Text {
            text: group.title.toUpperCase()
            color: K4Theme.dim
            font.family: K4Theme.uiFont
            font.pixelSize: 9
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        Text {
            visible: group.nodes.length === 0
            text: "Nothing connected"
            color: K4Theme.dim
            font.family: K4Theme.uiFont
            font.pixelSize: 11
            renderType: Text.NativeRendering
        }

        Repeater {
            model: group.nodes

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool selected: group.activeNode === modelData
                readonly property int volume: K4AudioDevices.volumeFor(modelData)
                readonly property bool muted: K4AudioDevices.mutedFor(modelData)

                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: 10
                color: selected ? K4Theme.surfaceHi : rowHover.hovered ? K4Theme.surface : "transparent"

                Behavior on color { ColorAnimation { duration: 110 } }

                HoverHandler { id: rowHover }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        if (group.input)
                            K4AudioDevices.selectInput(row.modelData)
                        else
                            K4AudioDevices.selectOutput(row.modelData)
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    anchors.topMargin: 5
                    anchors.bottomMargin: 5
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: row.selected ? K4Theme.ico.check
                                : group.input ? K4Theme.ico.microphone : K4Theme.ico.speaker
                            color: row.selected ? K4Theme.green : K4Theme.dim
                            font.family: K4Theme.iconFont
                            font.pixelSize: 12
                            renderType: Text.NativeRendering
                        }

                        Text {
                            Layout.fillWidth: true
                            text: K4AudioDevices.nameFor(row.modelData)
                            color: row.selected ? K4Theme.ink : K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Text {
                            text: row.volume + "%"
                            color: row.muted ? K4Theme.dim : K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 10
                            renderType: Text.NativeRendering
                        }

                        K4PanelButton {
                            glyph: row.muted ? K4Theme.ico.volOff : K4Theme.ico.volMed
                            glyphSize: 12
                            glyphColor: row.muted ? K4Theme.red : K4Theme.muted
                            onActivated: K4AudioDevices.toggleMute(row.modelData)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12

                        Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: K4Theme.track
                            opacity: row.muted ? 0.45 : 1

                            Rectangle {
                                width: track.width * Math.min(1, row.volume / 150)
                                height: parent.height
                                radius: parent.radius
                                color: row.selected ? K4Theme.green : K4Theme.muted
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.topMargin: -5
                            anchors.bottomMargin: -5
                            cursorShape: Qt.PointingHandCursor

                            function setAt(x) {
                                K4AudioDevices.setVolume(row.modelData,
                                    x / Math.max(1, width) * 150)
                            }
                            onPressed: function(event) { setAt(event.x) }
                            onPositionChanged: function(event) {
                                if (pressed)
                                    setAt(event.x)
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: K4Theme.surface

        Flickable {
            anchors.fill: parent
            anchors.margins: 12
            contentWidth: width
            contentHeight: devices.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: devices
                width: parent.width
                spacing: 10

                DeviceGroup {
                    title: "Output"
                    nodes: K4AudioDevices.outputs
                    activeNode: K4AudioDevices.activeOutput
                    input: false
                }

                DeviceGroup {
                    title: "Input"
                    nodes: K4AudioDevices.inputs
                    activeNode: K4AudioDevices.activeInput
                    input: true
                }
            }
        }
    }
}
