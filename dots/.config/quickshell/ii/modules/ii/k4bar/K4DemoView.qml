import QtQuick
import QtQuick.Layouts

// Temporary K4-03 runtime harness. Real feature plugins replace these demo
// views in later parity tickets.
Item {
    id: root

    required property string title
    required property string detail

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 5

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.title
            color: K4Theme.ink
            font.family: K4Theme.uiFont
            font.pixelSize: 15
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.detail
            color: K4Theme.muted
            font.family: K4Theme.uiFont
            font.pixelSize: 11
            renderType: Text.NativeRendering
        }
    }
}
