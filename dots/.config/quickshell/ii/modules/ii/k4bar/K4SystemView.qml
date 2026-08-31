import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var plugin
    focus: true

    Component.onCompleted: { fade.start(); forceActiveFocus() }
    opacity: 0
    NumberAnimation { id: fade; target: root; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
    Keys.onEscapePressed: root.plugin.close()

    function pct(value) { return Math.round(Math.max(0, Math.min(1, value)) * 100) + "%" }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: K4System.hostname
                color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 18; font.weight: Font.DemiBold
            }
            Text {
                text: K4System.distro
                color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 11
            }
            Item { Layout.fillWidth: true }
            Text {
                text: K4System.cpuTemp + " · " + K4System.cpuFreq
                color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 11
            }
        }

        Text {
            Layout.fillWidth: true
            text: K4System.cpuModel
            color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 10; elide: Text.ElideRight
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: 10
            columnSpacing: 10

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 14; color: K4Theme.surface
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 10
                    RowLayout { Layout.fillWidth: true; Text { text: "CPU"; color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold } Item { Layout.fillWidth: true } Text { text: root.pct(K4System.cpu); color: K4Theme.blue; font.family: K4Theme.uiFont; font.pixelSize: 22; font.weight: Font.Bold } }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 8; radius: 4; color: K4Theme.track; Rectangle { width: parent.width * Math.max(0, Math.min(1, K4System.cpu)); height: parent.height; radius: parent.radius; color: K4Theme.blue } }
                    Item { Layout.fillHeight: true }
                    Text { text: K4System.cpuTemp + " · " + K4System.cpuFreq; color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 10 }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 14; color: K4Theme.surface
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 10
                    RowLayout { Layout.fillWidth: true; Text { text: "Memory"; color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold } Item { Layout.fillWidth: true } Text { text: root.pct(K4System.memory); color: K4Theme.green; font.family: K4Theme.uiFont; font.pixelSize: 22; font.weight: Font.Bold } }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 8; radius: 4; color: K4Theme.track; Rectangle { width: parent.width * Math.max(0, Math.min(1, K4System.memory)); height: parent.height; radius: parent.radius; color: K4Theme.green } }
                    Item { Layout.fillHeight: true }
                    Text { text: K4System.memoryUsed + " / " + K4System.memoryTotal; color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 10 }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 14; color: K4Theme.surface
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 10
                    RowLayout { Layout.fillWidth: true; Text { text: "Disk"; color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold } Item { Layout.fillWidth: true } Text { text: root.pct(K4System.disk); color: K4Theme.yellow; font.family: K4Theme.uiFont; font.pixelSize: 22; font.weight: Font.Bold } }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 8; radius: 4; color: K4Theme.track; Rectangle { width: parent.width * Math.max(0, Math.min(1, K4System.disk)); height: parent.height; radius: parent.radius; color: K4Theme.yellow } }
                    Item { Layout.fillHeight: true }
                    Text { text: K4System.swap > 0 ? "Swap " + root.pct(K4System.swap) : "Swap idle"; color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 10 }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 14; color: K4Theme.surface
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 10
                    Text { text: "Network"; color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold }
                    RowLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        ColumnLayout { Layout.fillWidth: true; Text { text: "↓"; color: K4Theme.green; font.family: K4Theme.uiFont; font.pixelSize: 18 } Text { text: K4System.formatRate(K4System.download); color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 16; font.weight: Font.DemiBold } }
                        ColumnLayout { Layout.fillWidth: true; Text { text: "↑"; color: K4Theme.blue; font.family: K4Theme.uiFont; font.pixelSize: 18 } Text { text: K4System.formatRate(K4System.upload); color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 16; font.weight: Font.DemiBold } }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "sampling only while open · esc closes"
            color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
