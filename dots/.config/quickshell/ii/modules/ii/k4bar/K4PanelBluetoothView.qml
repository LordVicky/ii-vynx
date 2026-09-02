import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property var myDevices: K4Bluetooth.devices.filter(device => device.connected || device.paired)
    readonly property var nearbyDevices: K4Bluetooth.devices.filter(device => !device.connected && !device.paired)

    RowLayout {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            Layout.minimumWidth: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 17
            color: K4Theme.panelSurface
            border.width: 1
            border.color: K4Theme.panelLine

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 11
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    Text {
                        text: "My devices"
                        color: K4Theme.ink
                        font.family: K4Theme.uiFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: !K4Bluetooth.available ? "No adapter"
                            : !K4Bluetooth.enabled ? "Off"
                            : K4Bluetooth.discovering ? "Searching…" : root.myDevices.length + " known"
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 8
                        renderType: Text.NativeRendering
                    }

                    K4PanelSwitch {
                        checked: K4Bluetooth.enabled
                        onToggled: K4Bluetooth.toggle()
                    }
                }

                K4CursorTrackedListView {
                    id: myList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 3
                    rowHeight: 48
                    model: root.myDevices
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: K4PanelConnectionRow {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: ListView.view.rowHeight
                        title: modelData.name?.length > 0 ? modelData.name : modelData.address
                        subtitle: K4Bluetooth.status(modelData)
                        glyph: K4Theme.ico.bluetooth
                        active: modelData.connected
                        busy: modelData.pairing ?? false
                        forgettable: modelData.paired
                        hovered: index === myList.hoveredIndex
                        onActivated: K4Bluetooth.activate(modelData)
                        onForgotten: K4Bluetooth.togglePair(modelData)
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.myDevices.length === 0
                        text: !K4Bluetooth.enabled ? "Enable Bluetooth to see devices" : "No paired devices"
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 10
                        renderType: Text.NativeRendering
                    }
                }
            }
        }

        Rectangle {
            Layout.minimumWidth: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 17
            color: K4Theme.panelSurface
            border.width: 1
            border.color: K4Theme.panelLine

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 11
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    Text {
                        text: "Nearby"
                        color: K4Theme.ink
                        font.family: K4Theme.uiFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: K4Bluetooth.discovering
                        text: "Searching devices…"
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 8
                        renderType: Text.NativeRendering
                    }
                }

                K4CursorTrackedListView {
                    id: nearbyList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 3
                    rowHeight: 48
                    model: root.nearbyDevices
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: K4PanelConnectionRow {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: ListView.view.rowHeight
                        title: modelData.name?.length > 0 ? modelData.name : modelData.address
                        subtitle: K4Bluetooth.status(modelData)
                        glyph: K4Theme.ico.bluetooth
                        active: false
                        busy: modelData.pairing ?? false
                        forgettable: false
                        hovered: index === nearbyList.hoveredIndex
                        onActivated: K4Bluetooth.activate(modelData)
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.nearbyDevices.length === 0
                        text: !K4Bluetooth.enabled
                            ? "Bluetooth is off"
                            : K4Bluetooth.discovering ? "Searching devices…" : "No nearby devices"
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 10
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }
}
