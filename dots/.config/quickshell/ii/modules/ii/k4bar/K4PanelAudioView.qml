import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

Item {
    id: root

    // Non-default PipeWire nodes expose their audio/name properties only while
    // observed. Keep that observation scoped to the visible Sound detail rather
    // than creating another service owner or a permanent background tracker.
    PwObjectTracker {
        objects: root.visible
            ? K4AudioDevices.outputs.concat(K4AudioDevices.inputs)
            : []
    }

    component DevicePane: Rectangle {
        id: pane
        required property string title
        required property var nodes
        required property var activeNode
        required property bool input

        radius: 17
        color: K4Theme.panelSurface
        border.width: 1
        border.color: K4Theme.panelLine

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 11
            spacing: 8

            Text {
                text: pane.title
                color: K4Theme.ink
                font.family: K4Theme.uiFont
                font.pixelSize: 10
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: devices.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: devices
                    width: parent.width
                    spacing: 4

                    Text {
                        visible: pane.nodes.length === 0
                        text: "Nothing connected"
                        color: K4Theme.dim
                        font.family: K4Theme.uiFont
                        font.pixelSize: 10
                        renderType: Text.NativeRendering
                    }

                    Repeater {
                        model: pane.nodes

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            readonly property bool selected: pane.activeNode
                                && pane.activeNode.id === modelData.id
                            readonly property int volume: K4AudioDevices.volumeFor(modelData)
                            readonly property bool muted: K4AudioDevices.mutedFor(modelData)
                            readonly property int base: K4AudioDevices.baseFor(modelData)
                            readonly property real db: K4AudioDevices.dbOverNatural(modelData)

                            Layout.fillWidth: true
                            Layout.preferredHeight: 62
                            radius: 12
                            color: selected
                                ? Qt.rgba(0.37, 0.62, 1, 0.10)
                                : rowHover.hovered ? K4Theme.panelSurfaceHot : K4Theme.panelSurfaceHi
                            border.width: selected ? 1 : 0
                            border.color: selected ? Qt.rgba(0.37, 0.62, 1, 0.35) : "transparent"

                            HoverHandler { id: rowHover }
                            MouseArea {
                                anchors.fill: parent
                                z: -1
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (pane.input)
                                        K4AudioDevices.selectInput(row.modelData)
                                    else
                                        K4AudioDevices.selectOutput(row.modelData)
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 7
                                anchors.topMargin: 6
                                anchors.bottomMargin: 6
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 7

                                    Rectangle {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        radius: 9
                                        color: K4Theme.panelSurfaceHot

                                        Text {
                                            anchors.centerIn: parent
                                            text: row.selected ? K4Theme.ico.check
                                                : pane.input ? K4Theme.ico.microphone : K4Theme.ico.speaker
                                            color: row.selected ? K4Theme.green : K4Theme.muted
                                            font.family: K4Theme.iconFont
                                            font.pixelSize: 12
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.minimumWidth: 0
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: K4AudioDevices.nameFor(row.modelData)
                                            color: K4Theme.ink
                                            font.family: K4Theme.uiFont
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: row.selected ? "Default" : "Available"
                                            color: K4Theme.muted
                                            font.family: K4Theme.uiFont
                                            font.pixelSize: 8
                                            elide: Text.ElideRight
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    Text {
                                        visible: row.base > 0 && row.volume > row.base
                                        text: "+" + row.db.toFixed(0) + " dB"
                                        color: row.selected ? K4Theme.yellow : K4Theme.dim
                                        font.family: K4Theme.uiFont
                                        font.pixelSize: 8
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        text: row.volume + "%"
                                        color: row.muted ? K4Theme.dim : K4Theme.muted
                                        font.family: K4Theme.uiFont
                                        font.pixelSize: 9
                                        renderType: Text.NativeRendering
                                    }

                                    K4PanelButton {
                                        glyph: row.muted ? K4Theme.ico.volOff : K4Theme.ico.volMed
                                        glyphSize: 11
                                        glyphColor: row.muted ? K4Theme.red : K4Theme.muted
                                        activeColor: K4Theme.panelSurfaceHot
                                        onActivated: K4AudioDevices.toggleMute(row.modelData)
                                    }
                                }

                                Item {
                                    Layout.minimumWidth: 0
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 12

                                    Rectangle {
                                        id: track
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 4
                                        radius: 2
                                        color: "#29313a"
                                        opacity: row.muted ? 0.45 : 1

                                        Rectangle {
                                            width: track.width * Math.min(1, row.volume / 150)
                                            height: parent.height
                                            radius: parent.radius
                                            color: !row.selected ? K4Theme.muted
                                                : row.base > 0 && row.volume > row.base
                                                    ? K4Theme.yellow : K4Theme.green
                                        }

                                        Rectangle {
                                            visible: row.base > 0
                                            x: track.width * (row.base / 150) - 1
                                            y: -3
                                            width: 2
                                            height: 10
                                            radius: 1
                                            color: K4Theme.ink
                                            opacity: 0.55
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
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        DevicePane {
            Layout.minimumWidth: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "Output"
            nodes: K4AudioDevices.outputs
            activeNode: K4AudioDevices.activeOutput
            input: false
        }

        DevicePane {
            Layout.minimumWidth: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "Input"
            nodes: K4AudioDevices.inputs
            activeNode: K4AudioDevices.activeInput
            input: true
        }
    }
}
