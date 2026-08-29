import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

// Two-pane tray/menu surface adapted from pinned k4 TrayView. The opener reads
// the DBus menu handle already owned by the selected ii-vynx tray item.
Item {
    id: root
    required property var plugin
    readonly property var selected: plugin.selected

    opacity: 0
    Component.onCompleted: fadeIn.start()

    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    QsMenuOpener {
        id: opener
        menu: root.selected && root.selected.hasMenu ? root.selected.menu : null
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
            Layout.preferredHeight: 28
            spacing: 10

            Text { text: String.fromCodePoint(0xF1296); color: K4Theme.muted; font.family: K4Theme.iconFont; font.pixelSize: 16 }
            Text { text: "System Tray"; color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 15; font.weight: Font.DemiBold }
            Text { text: K4Tray.count === 0 ? "" : `${K4Tray.count} ${K4Tray.count === 1 ? "application" : "applications"}`; color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 11 }
            Item { Layout.fillWidth: true }
            Rectangle {
                implicitWidth: 30; implicitHeight: 26; radius: 13
                color: closeMouse.containsMouse ? K4Theme.surfaceHi : "transparent"
                Text { anchors.centerIn: parent; text: K4Theme.ico.close; color: K4Theme.muted; font.family: K4Theme.iconFont; font.pixelSize: 15 }
                MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.plugin.close() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                radius: 16
                color: K4Theme.surface

                ListView {
                    id: trayApps
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    spacing: 2
                    model: K4Tray.sorted
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 5
                        contentItem: Rectangle { implicitWidth: 4; radius: 2; color: parent.pressed ? K4Theme.muted : K4Theme.dim }
                        background: Item {}
                    }

                    K4ViewportPointer {
                        id: trayAppsPointer
                        surface: trayApps
                    }

                    delegate: Rectangle {
                        id: appRow
                        required property var modelData
                        readonly property bool current: root.selected === modelData
                        readonly property bool hovered: trayAppsPointer.contains(appRow)
                        width: ListView.view.width
                        height: 46
                        radius: 10
                        color: current || hovered ? K4Theme.surfaceHi : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Image {
                                source: appRow.modelData.icon
                                sourceSize.width: 44
                                sourceSize.height: 44
                                fillMode: Image.PreserveAspectFit
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text { Layout.fillWidth: true; text: K4Tray.label(appRow.modelData); color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 12; font.weight: appRow.current ? Font.DemiBold : Font.Normal; elide: Text.ElideRight }
                                Text { Layout.fillWidth: true; text: K4Tray.statusText(appRow.modelData); color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 9; elide: Text.ElideRight }
                            }
                            Text { visible: appRow.modelData.hasMenu; text: K4Theme.ico.forward; color: appRow.current ? K4Theme.ink : K4Theme.dim; font.family: K4Theme.iconFont; font.pixelSize: 13 }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: function(mouse) {
                                root.plugin.select(appRow.modelData)
                                if (mouse.button === Qt.MiddleButton) K4Tray.secondary(appRow.modelData)
                            }
                            onDoubleClicked: K4Tray.primary(appRow.modelData)
                            onWheel: function(wheel) { K4Tray.scroll(appRow.modelData, wheel.angleDelta.y) }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        visible: K4Tray.count === 0
                        text: "No applications in the system tray"
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 16
                color: K4Theme.surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    visible: root.selected !== null

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Image { source: root.selected ? root.selected.icon : ""; sourceSize.width: 52; sourceSize.height: 52; fillMode: Image.PreserveAspectFit; Layout.preferredWidth: 26; Layout.preferredHeight: 26 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { Layout.fillWidth: true; text: K4Tray.label(root.selected); color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; text: K4Tray.detail(root.selected); color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 10; elide: Text.ElideRight }
                        }
                        Rectangle {
                            visible: root.selected !== null && !root.selected.onlyMenu
                            implicitWidth: openLabel.implicitWidth + 24
                            implicitHeight: 24
                            radius: 12
                            color: openMouse.containsMouse ? K4Theme.blue : K4Theme.surfaceHi
                            Text { id: openLabel; anchors.centerIn: parent; text: "Open"; color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 11; font.weight: Font.DemiBold }
                            MouseArea { id: openMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { K4Tray.primary(root.selected); root.plugin.close() } }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: K4Theme.surfaceHi }

                    ListView {
                        id: trayMenu
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 1
                        model: opener.children
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 5
                            contentItem: Rectangle { implicitWidth: 4; radius: 2; color: parent.pressed ? K4Theme.muted : K4Theme.dim }
                            background: Item {}
                        }

                        K4ViewportPointer {
                            id: trayMenuPointer
                            surface: trayMenu
                        }

                        delegate: Item {
                            id: entryRow
                            required property var modelData
                            readonly property bool hovered: trayMenuPointer.contains(entryRow)
                            width: ListView.view.width
                            height: modelData.isSeparator ? 9 : 30

                            Rectangle {
                                visible: entryRow.modelData.isSeparator
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.leftMargin: 8; anchors.rightMargin: 8
                                height: 1
                                color: K4Theme.surfaceHi
                            }

                            Rectangle {
                                visible: !entryRow.modelData.isSeparator
                                anchors.fill: parent
                                radius: 8
                                color: entryRow.hovered && entryRow.modelData.enabled ? K4Theme.surfaceHi : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                                    Text { visible: entryRow.modelData.buttonType !== 0; text: entryRow.modelData.checkState === Qt.Checked ? K4Theme.ico.check : ""; color: K4Theme.green; font.family: K4Theme.iconFont; font.pixelSize: 12; Layout.preferredWidth: 14 }
                                    Image { visible: entryRow.modelData.icon.length > 0; source: entryRow.modelData.icon; sourceSize.width: 32; sourceSize.height: 32; fillMode: Image.PreserveAspectFit; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
                                    Text { Layout.fillWidth: true; text: entryRow.modelData.text; color: entryRow.modelData.enabled ? K4Theme.ink : K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 12; elide: Text.ElideRight }
                                    Text { visible: entryRow.modelData.hasChildren; text: K4Theme.ico.forward; color: K4Theme.dim; font.family: K4Theme.iconFont; font.pixelSize: 12 }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: entryRow.modelData.enabled && !entryRow.modelData.hasChildren ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    enabled: entryRow.modelData.enabled && !entryRow.modelData.hasChildren
                                    onClicked: { entryRow.modelData.triggered(); root.plugin.close() }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 24
                            visible: opener.children.values.length === 0
                            text: root.selected && !root.selected.hasMenu ? "This application does not expose a menu" : "Loading menu…"
                            color: K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 32
                    visible: root.selected === null
                    text: "Select a tray application"
                    color: K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
