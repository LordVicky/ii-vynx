import QtQuick
import QtQuick.Layouts

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 10

            Text {
                text: !K4Bluetooth.available ? "No Bluetooth adapter"
                    : !K4Bluetooth.enabled ? "Bluetooth disabled"
                    : K4Bluetooth.discovering ? "Searching devices…" : "Devices"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 11
                renderType: Text.NativeRendering
            }

            Item { Layout.fillWidth: true }

            K4PanelSwitch {
                checked: K4Bluetooth.enabled
                onToggled: K4Bluetooth.toggle()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: K4Theme.surface

            K4HoverListView {
                id: devicesList
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                spacing: 2
                model: K4Bluetooth.devices
                boundsBehavior: Flickable.StopAtBounds

                delegate: K4PanelConnectionRow {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    title: modelData.name?.length > 0 ? modelData.name : modelData.address
                    subtitle: K4Bluetooth.status(modelData)
                    glyph: K4Theme.ico.bluetooth
                    active: modelData.connected
                    busy: modelData.pairing ?? false
                    forgettable: modelData.paired
                    hovered: index === devicesList.hoveredIndex
                    onActivated: K4Bluetooth.activate(modelData)
                    onForgotten: K4Bluetooth.togglePair(modelData)
                }

                Text {
                    anchors.centerIn: parent
                    visible: K4Bluetooth.devices.length === 0
                    text: K4Bluetooth.enabled ? "Searching devices…" : "Enable Bluetooth to search"
                    color: K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Use × to forget paired devices; select a row to connect or disconnect."
            color: K4Theme.dim
            font.family: K4Theme.uiFont
            font.pixelSize: 9
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }
    }
}
