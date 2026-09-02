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
                readonly property string summaryText: String(modelData?.summary ?? "Notification")
                    .replace(/\s*\n\s*/g, " ")
                readonly property string bodyText: String(modelData?.body ?? "")
                    .replace(/\r\n/g, "\n")
                    .replace(/\n{3,}/g, "\n\n")
                    .trim()
                readonly property string appNameText: String(modelData?.appName ?? "")
                    .replace(/\s*\n\s*/g, " ")

                width: ListView.view.width
                height: 78 + (actions.length > 0 ? 32 : 0)
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
                    anchors.leftMargin: 11
                    anchors.rightMargin: 8
                    anchors.topMargin: 9
                    anchors.bottomMargin: 9
                    spacing: 11

                    ClippingRectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignTop
                        radius: 12
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
                            font.pixelSize: 16
                            textFormat: Text.PlainText
                        }
                    }

                    ColumnLayout {
                        Layout.minimumWidth: 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.minimumWidth: 0
                                Layout.fillWidth: true
                                text: card.summaryText
                                color: K4Theme.panelInkSoft
                                font.family: K4Theme.uiFont
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                textFormat: Text.PlainText
                            }

                            Text {
                                visible: card.appNameText.length > 0
                                text: card.appNameText
                                color: K4Theme.panelDim
                                font.family: K4Theme.uiFont
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.maximumWidth: 120
                                textFormat: Text.PlainText
                            }
                        }

                        Text {
                            Layout.minimumWidth: 0
                            Layout.fillWidth: true
                            visible: card.bodyText.length > 0
                            text: card.bodyText
                            color: K4Theme.panelMuted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            textFormat: Text.PlainText
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            visible: card.actions.length > 0
                            spacing: 6

                            Repeater {
                                model: card.actions
                                delegate: Rectangle {
                                    id: chip
                                    required property var modelData
                                    Layout.preferredWidth: Math.min(chipText.implicitWidth + 20, 160)
                                    Layout.preferredHeight: 24
                                    radius: 12
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
                                        font.pixelSize: 10
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
