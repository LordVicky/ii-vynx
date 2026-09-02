import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root

    Rectangle {
        anchors.fill: parent
        radius: 17
        color: K4Theme.panelSurface
        border.width: 1
        border.color: K4Theme.panelLine

        ListView {
            anchors.fill: parent
            anchors.margins: 9
            clip: true
            spacing: 7
            model: K4Notifications.history
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property var actions: K4Notifications.buttons(modelData)
                readonly property string iconSource: K4Notifications.iconFor(modelData)

                width: ListView.view.width
                height: 66 + (actions.length > 0 ? 28 : 0)
                radius: 14
                color: cardHover.hovered ? K4Theme.panelSurfaceHot : K4Theme.panelSurfaceHi
                border.width: 1
                border.color: cardHover.hovered ? K4Theme.panelLineStrong : K4Theme.panelLine

                Behavior on color { ColorAnimation { duration: 110 } }
                Behavior on border.color { ColorAnimation { duration: 110 } }

                HoverHandler { id: cardHover }
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: K4Notifications.activate(card.modelData)
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
                        radius: 11
                        color: K4Theme.panelSurfaceHot
                        border.width: 1
                        border.color: K4Theme.panelLine

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
                            color: K4Theme.panelInkSoft
                            font.family: K4Theme.iconFont
                            font.pixelSize: 15
                            textFormat: Text.PlainText
                        }
                    }

                    ColumnLayout {
                        Layout.minimumWidth: 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: (card.modelData?.summary ?? "").replace(/\s*\n\s*/g, " ")
                                color: K4Theme.panelInkSoft
                                font.family: K4Theme.uiFont
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }

                            Text {
                                text: card.modelData?.appName ?? ""
                                color: K4Theme.panelDim
                                font.family: K4Theme.uiFont
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                Layout.maximumWidth: 110
                                textFormat: Text.PlainText
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (card.modelData?.body ?? "").replace(/\s*\n\s*/g, " ")
                            color: K4Theme.panelMuted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            textFormat: Text.PlainText
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
                                    color: chipHover.hovered ? K4Theme.panelBlue : K4Theme.panelSurfaceHot
                                    border.width: 1
                                    border.color: chipHover.hovered
                                        ? Qt.rgba(0.04, 0.52, 1, 0.42) : K4Theme.panelLine

                                    Text {
                                        id: chipText
                                        anchors.centerIn: parent
                                        text: chip.modelData.text ?? chip.modelData.identifier ?? ""
                                        color: chipHover.hovered ? "#07111e" : K4Theme.panelInkSoft
                                        font.family: K4Theme.uiFont
                                        font.pixelSize: 9
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
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
                        activeColor: K4Theme.panelSurfaceHot
                        onActivated: K4Notifications.dismiss(card.modelData)
                        Layout.alignment: Qt.AlignTop
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: K4Notifications.history.length === 0
                text: "No notifications"
                color: K4Theme.panelMuted
                font.family: K4Theme.uiFont
                font.pixelSize: 12
                textFormat: Text.PlainText
            }
        }
    }
}
