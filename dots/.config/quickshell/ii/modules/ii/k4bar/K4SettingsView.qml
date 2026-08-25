import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Settings presentation adapted from pinned k4 SettingsView.qml. K4-08 ports
// only options with live ii-vynx consumers; later tickets append their own
// settings when those behaviors exist.
Item {
    id: root

    required property var plugin

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

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 12
        anchors.bottomMargin: 22
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 9

            Text {
                text: String.fromCodePoint(0xF0493)
                color: K4Theme.muted
                font.family: K4Theme.iconFont
                font.pixelSize: 16
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: "Settings"
                color: K4Theme.ink
                font.family: K4Theme.uiFont
                font.pixelSize: 15
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            K4PanelButton {
                glyph: K4Theme.ico.close
                glyphSize: 15
                onActivated: root.plugin.close()
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Flickable {
            id: scroller
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: settingsColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

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

            ColumnLayout {
                id: settingsColumn
                width: scroller.width
                spacing: 8

                Text {
                    text: "ISLAND"
                    color: K4Theme.dim
                    font.family: K4Theme.uiFont
                    font.pixelSize: 9
                    font.capitalization: Font.AllUppercase
                    renderType: Text.NativeRendering
                    Layout.leftMargin: 2
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    radius: 12
                    color: K4Theme.surface

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 7

                        Text {
                            text: "Bar position"
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Repeater {
                                model: K4Settings.positions
                                delegate: Rectangle {
                                    id: positionChoice
                                    required property var modelData
                                    readonly property bool selected: K4Settings.position === modelData.value
                                    Layout.preferredWidth: positionLabel.implicitWidth + 24
                                    Layout.preferredHeight: 26
                                    radius: 13
                                    color: selected ? K4Theme.blue
                                        : positionHover.hovered ? K4Theme.surfaceHi : K4Theme.track

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        id: positionLabel
                                        anchors.centerIn: parent
                                        text: positionChoice.modelData.label
                                        color: positionChoice.selected ? K4Theme.ink : K4Theme.muted
                                        font.family: K4Theme.uiFont
                                        font.pixelSize: 10
                                        font.weight: positionChoice.selected ? Font.DemiBold : Font.Normal
                                        renderType: Text.NativeRendering
                                    }

                                    HoverHandler { id: positionHover }
                                    TapHandler {
                                        cursorShape: Qt.PointingHandCursor
                                        onTapped: K4Settings.setPosition(positionChoice.modelData.value)
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    radius: 12
                    color: K4Theme.surface

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 7

                        Text {
                            text: "Island alignment"
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Repeater {
                                model: K4Settings.alignments
                                delegate: Rectangle {
                                    id: alignmentChoice
                                    required property var modelData
                                    readonly property bool selected: K4Settings.alignment === modelData.value
                                    Layout.preferredWidth: alignmentLabel.implicitWidth + 24
                                    Layout.preferredHeight: 26
                                    radius: 13
                                    color: selected ? K4Theme.blue
                                        : alignmentHover.hovered ? K4Theme.surfaceHi : K4Theme.track

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        id: alignmentLabel
                                        anchors.centerIn: parent
                                        text: alignmentChoice.modelData.label
                                        color: alignmentChoice.selected ? K4Theme.ink : K4Theme.muted
                                        font.family: K4Theme.uiFont
                                        font.pixelSize: 10
                                        font.weight: alignmentChoice.selected ? Font.DemiBold : Font.Normal
                                        renderType: Text.NativeRendering
                                    }

                                    HoverHandler { id: alignmentHover }
                                    TapHandler {
                                        cursorShape: Qt.PointingHandCursor
                                        onTapped: K4Settings.setAlignment(alignmentChoice.modelData.value)
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                K4SettingsToggle {
                    Layout.fillWidth: true
                    title: "Tray in collapsed pill"
                    description: "Show up to four system-tray items beside the clock"
                    glyph: String.fromCodePoint(0xF1296)
                    checked: K4Settings.trayInPill
                    onToggled: value => K4Settings.setTrayInPill(value)
                }

                K4SettingsToggle {
                    Layout.fillWidth: true
                    title: "Recent notifications on hover"
                    description: "Show the recent-notification strip under Clock and Player"
                    glyph: K4Theme.ico.bellOutline
                    checked: K4Settings.notificationsOnHover
                    onToggled: value => K4Settings.setNotificationsOnHover(value)
                }

                K4SettingsToggle {
                    Layout.fillWidth: true
                    title: "Dismiss when application is focused"
                    description: "Clear matching notifications after their application takes focus"
                    glyph: K4Theme.ico.check
                    checked: K4Settings.dismissNotificationsOnFocus
                    onToggled: value => K4Settings.setDismissNotificationsOnFocus(value)
                }

                Text {
                    Layout.topMargin: 8
                    Layout.leftMargin: 2
                    text: "PLUGINS"
                    color: K4Theme.dim
                    font.family: K4Theme.uiFont
                    font.pixelSize: 9
                    font.capitalization: Font.AllUppercase
                    renderType: Text.NativeRendering
                }

                Repeater {
                    model: root.plugin.controller
                        ? root.plugin.controller.configurablePlugins() : []

                    delegate: K4SettingsPluginRow {
                        required property var modelData
                        Layout.fillWidth: true
                        plugin: modelData
                        controller: root.plugin.controller
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 3
                    text: "More K4 settings appear here only when their runtime feature is present."
                    color: K4Theme.dim
                    font.family: K4Theme.uiFont
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
