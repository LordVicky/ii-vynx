import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: K4Theme.surface

        ListView {
            anchors.fill: parent
            anchors.margins: 10
            clip: true
            spacing: 8
            model: K4Notifications.history
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property var actions: K4Notifications.buttons(modelData)
                readonly property string iconSource: K4Notifications.iconFor(modelData)

                width: ListView.view.width
                height: 66 + (actions.length > 0 ? 28 : 0)
                radius: 11
                color: cardHover.hovered ? K4Theme.surfaceHi : K4Theme.surface

                Behavior on color { ColorAnimation { duration: 110 } }

                HoverHandler { id: cardHover }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: K4Notifications.activate(card.modelData)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    spacing: 10

                    ClippingRectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignTop
                        radius: 18
                        color: K4Theme.surfaceHi

                        Image {
                            id: icon
                            anchors.fill: parent
                            anchors.margins: 6
                            source: card.iconSource
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !icon.visible
                            text: K4Theme.ico.bell
                            color: K4Theme.ink
                            font.family: K4Theme.iconFont
                            font.pixelSize: 15
                            renderType: Text.NativeRendering
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: (card.modelData?.summary ?? "").replace(/\s*\n\s*/g, " ")
                                color: K4Theme.ink
                                font.family: K4Theme.uiFont
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }

                            Text {
                                text: card.modelData?.appName ?? ""
                                color: K4Theme.dim
                                font.family: K4Theme.uiFont
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                Layout.maximumWidth: 110
                                renderType: Text.NativeRendering
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (card.modelData?.body ?? "").replace(/\s*\n\s*/g, " ")
                            color: K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            renderType: Text.NativeRendering
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: card.actions.length > 0
                            spacing: 5

                            Repeater {
                                model: card.actions
                                delegate: Rectangle {
                                    id: chip
                                    required property var modelData
                                    Layout.preferredWidth: Math.min(chipText.implicitWidth + 18, 145)
                                    Layout.preferredHeight: 20
                                    radius: 10
                                    color: chipHover.hovered ? K4Theme.blue : K4Theme.surfaceHi

                                    Text {
                                        id: chipText
                                        anchors.centerIn: parent
                                        text: chip.modelData.text ?? chip.modelData.identifier ?? ""
                                        color: K4Theme.ink
                                        font.family: K4Theme.uiFont
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        renderType: Text.NativeRendering
                                    }

                                    HoverHandler { id: chipHover }
                                    TapHandler {
                                        cursorShape: Qt.PointingHandCursor
                                        onTapped: K4Notifications.invokeAction(card.modelData, chip.modelData)
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }

                    K4PanelButton {
                        glyph: K4Theme.ico.close
                        glyphSize: 12
                        onActivated: K4Notifications.dismiss(card.modelData)
                        Layout.alignment: Qt.AlignTop
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: K4Notifications.history.length === 0
                text: "No notifications"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 12
                renderType: Text.NativeRendering
            }
        }
    }
}
