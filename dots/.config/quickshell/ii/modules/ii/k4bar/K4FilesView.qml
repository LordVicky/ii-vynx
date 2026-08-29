import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    required property var plugin
    property int focusAttempts: 0

    Component.onCompleted: {
        fade.start()
        focusTimer.start()
        Qt.callLater(() => queryInput.forceActiveFocus())
    }
    opacity: 0
    NumberAnimation { id: fade; target: root; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
    Timer {
        id: focusTimer; interval: 140
        onTriggered: {
            if (!root.plugin.open) return
            queryInput.forceActiveFocus()
            if (!queryInput.activeFocus && root.focusAttempts++ < 6) restart()
        }
    }

    function sizeText(bytes) {
        if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(1) + " GB"
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB"
        if (bytes >= 1024) return Math.round(bytes / 1024) + " KB"
        return bytes + " B"
    }
    function displayPath(path) {
        const home = Quickshell.env("HOME")
        return home && path.indexOf(home) === 0 ? "~" + path.substring(home.length) : path
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 8
            Text { text: String.fromCodePoint(0xF0349); color: K4Theme.muted; font.family: K4Theme.iconFont; font.pixelSize: 15 }
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                Text {
                    anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                    visible: queryInput.text.length === 0; text: "Find files…"
                    color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 15
                }
                TextInput {
                    id: queryInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    text: K4Files.query
                    onTextEdited: { K4Files.query = text; root.plugin.index = 0 }
                    color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 15
                    focus: true; activeFocusOnTab: true; clip: true; selectByMouse: true
                    selectionColor: K4Theme.blue; selectedTextColor: K4Theme.ink; cursorVisible: true
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) { root.plugin.close(); event.accepted = true }
                        else if (event.key === Qt.Key_Down) { root.plugin.moveSelection(1); event.accepted = true }
                        else if (event.key === Qt.Key_Up) { root.plugin.moveSelection(-1); event.accepted = true }
                        else if (event.key === Qt.Key_PageDown) { root.plugin.moveSelection(7); event.accepted = true }
                        else if (event.key === Qt.Key_PageUp) { root.plugin.moveSelection(-7); event.accepted = true }
                        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) { root.plugin.openContaining(); event.accepted = true }
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.plugin.choose(); event.accepted = true }
                        else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_C) { root.plugin.copyPath(); event.accepted = true }
                    }
                }
            }
            Text {
                visible: K4Files.searching
                text: "searching…"
                color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 10
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [
                    { label: "Home", value: "home", group: "scope" },
                    { label: "System", value: "system", group: "scope" },
                    { label: "Files", value: "file", group: "type" },
                    { label: "Folders", value: "dir", group: "type" }
                ]
                Rectangle {
                    required property var modelData
                    implicitWidth: chipText.implicitWidth + 18
                    implicitHeight: 24
                    radius: 12
                    readonly property bool selected: modelData.group === "scope"
                        ? K4Files.scope === modelData.value
                        : K4Files.typeFilter === modelData.value
                    color: selected ? K4Theme.surfaceHi : chipMouse.containsMouse ? K4Theme.surface : "transparent"
                    border.width: selected ? 1 : 0
                    border.color: selected ? K4Theme.blue : "transparent"
                    Text { id: chipText; anchors.centerIn: parent; text: modelData.label; color: parent.selected ? K4Theme.ink : K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 10 }
                    MouseArea {
                        id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (parent.modelData.group === "scope") K4Files.scope = parent.modelData.value
                            else root.plugin.toggleType(parent.modelData.value)
                            queryInput.forceActiveFocus()
                        }
                    }
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: root.plugin.count > 0
                text: root.plugin.count + " results · " + K4Files.elapsedMs + " ms"
                color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 10
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: K4Theme.surfaceHi }

        ListView {
            id: rows
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 3; boundsBehavior: Flickable.StopAtBounds
            model: root.plugin.entries
            currentIndex: root.plugin.count > 0 ? root.plugin.index : -1
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded; width: 5
                contentItem: Rectangle { implicitWidth: 4; radius: 2; color: parent.pressed ? K4Theme.muted : K4Theme.dim }
                background: Item {}
            }

            K4ViewportPointer {
                id: filesPointer
                surface: rows
            }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool selected: index === root.plugin.index
                readonly property bool hovered: filesPointer.contains(row)
                width: ListView.view.width; height: 48; radius: 9
                color: selected || hovered ? K4Theme.surfaceHi : "transparent"
                onHoveredChanged: if (hovered) root.plugin.index = index
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                    Text {
                        Layout.preferredWidth: 28; horizontalAlignment: Text.AlignHCenter
                        text: row.modelData.isDirectory ? String.fromCodePoint(0xF024B) : String.fromCodePoint(0xF0214)
                        color: row.modelData.isDirectory ? K4Theme.blue : K4Theme.muted
                        font.family: K4Theme.iconFont; font.pixelSize: 18
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { Layout.fillWidth: true; text: row.modelData.name; color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 13; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: root.displayPath(row.modelData.path); color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 10; elide: Text.ElideMiddle }
                    }
                    Text { visible: !row.modelData.isDirectory; text: root.sizeText(row.modelData.bytes); color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 10 }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.plugin.index = row.index; root.plugin.choose() }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: !K4Files.searching && root.plugin.count === 0
                text: K4Files.query.trim().length < 2 ? "Type at least two characters" : "No matching files"
                color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 12
            }
        }

        Text {
            Layout.fillWidth: true
            text: "enter opens · ctrl+enter opens folder · ctrl+c copies path · esc closes"
            color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
