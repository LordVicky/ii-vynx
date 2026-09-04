pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root

    property var notification: null
    property bool expanded: false
    property bool bandMode: false

    readonly property var buttons: K4Notifications.buttons(notification)
    readonly property string appIconSource: K4Notifications.appIconFor(notification)
    readonly property string imageSource: K4Notifications.imageFor(notification)
    readonly property bool hasImage: K4Notifications.hasImage(notification)
    readonly property bool critical: K4Notifications.isCritical(notification)
    readonly property string appName: singleLineText(notification?.appName ?? "Notification")
    readonly property string summary: singleLineText(notification?.summary ?? "")
    readonly property string body: singleLineText(notification?.body ?? "")
    readonly property string expandedBody: String(notification?.body ?? "")
        .replace(/\r\n/g, "\n")
        .replace(/\n{3,}/g, "\n\n")
        .trim()
    readonly property string compactLine: {
        if (!bandMode)
            return summary.length > 0 ? summary : "New notification"
        const primary = summary.length > 0 ? summary : body
        if (body.length === 0 || body === primary)
            return primary
        return primary + " — " + body
    }

    signal dismissRequested()
    signal actionRequested(var action)

    function singleLineText(value) {
        return String(value ?? "").replace(/\s*\n\s*/g, " ")
    }

    component AppIcon: ClippingRectangle {
        id: appIcon

        required property string iconSource

        radius: 9
        color: K4Theme.surface

        Image {
            id: appIconImage
            anchors.fill: parent
            anchors.margins: 4
            source: appIcon.iconSource
            sourceSize.width: 72
            sourceSize.height: 72
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: !appIconImage.visible
            text: K4Theme.ico.bell
            color: K4Theme.ink
            font.family: K4Theme.iconFont
            font.pixelSize: 16
            renderType: Text.NativeRendering
        }
    }

    component CloseButton: Item {
        id: closeButton

        signal clicked()

        implicitWidth: 32
        implicitHeight: 32

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: closeMouse.containsMouse ? K4Theme.surfaceHi : "transparent"

            Behavior on color { ColorAnimation { duration: 100 } }
        }

        Text {
            anchors.centerIn: parent
            text: K4Theme.ico.close
            color: closeMouse.containsMouse ? K4Theme.ink : K4Theme.muted
            font.family: K4Theme.iconFont
            font.pixelSize: 13
            renderType: Text.NativeRendering
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                mouse.accepted = true
                closeButton.clicked()
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        width: 3
        radius: 2
        color: K4Theme.red
        visible: root.critical
    }

    Item {
        id: compactLayer
        anchors.fill: parent
        opacity: root.expanded ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            spacing: 10

            AppIcon {
                iconSource: root.appIconSource
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        Layout.fillWidth: true
                        text: root.appName
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        renderType: Text.NativeRendering
                    }

                    Text {
                        visible: root.critical
                        text: "Critical"
                        color: K4Theme.red
                        font.family: K4Theme.uiFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: "now"
                        color: K4Theme.dim
                        font.family: K4Theme.uiFont
                        font.pixelSize: 9
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.compactLine
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    renderType: Text.NativeRendering
                }
            }

            CloseButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.dismissRequested()
            }
        }
    }

    Item {
        id: expandedLayer
        anchors.fill: parent
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 9
            anchors.bottomMargin: 10
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 9

                AppIcon {
                    iconSource: root.appIconSource
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: root.appName
                    color: K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    visible: root.critical
                    Layout.preferredWidth: criticalLabel.implicitWidth + 12
                    Layout.preferredHeight: 20
                    radius: 10
                    color: K4Theme.surfaceHi

                    Text {
                        id: criticalLabel
                        anchors.centerIn: parent
                        text: "Critical"
                        color: K4Theme.red
                        font.family: K4Theme.uiFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    text: "now"
                    color: K4Theme.dim
                    font.family: K4Theme.uiFont
                    font.pixelSize: 10
                    renderType: Text.NativeRendering
                }

                CloseButton {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    onClicked: root.dismissRequested()
                }
            }

            RowLayout {
                id: messageRow
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(messageColumn.implicitHeight,
                    notificationImage.visible ? 64 : 0)
                Layout.topMargin: 4
                Layout.bottomMargin: root.buttons.length > 0 ? 3 : 2
                spacing: 12

                ColumnLayout {
                    id: messageColumn
                    Layout.minimumWidth: 0
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 5

                    Text {
                        Layout.fillWidth: true
                        text: root.summary.length > 0 ? root.summary : root.body
                        color: K4Theme.ink
                        font.family: K4Theme.uiFont
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        textFormat: Text.PlainText
                        renderType: Text.NativeRendering
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.expandedBody.length > 0 && root.body !== root.summary
                        text: root.expandedBody
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 3
                        textFormat: Text.PlainText
                        renderType: Text.NativeRendering
                    }
                }

                ClippingRectangle {
                    id: notificationImage
                    visible: root.expanded && root.hasImage
                    Layout.preferredWidth: 92
                    Layout.preferredHeight: 64
                    Layout.alignment: Qt.AlignTop
                    radius: 10
                    color: K4Theme.surface

                    Image {
                        anchors.fill: parent
                        source: root.imageSource
                        sourceSize.width: 184
                        sourceSize.height: 128
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.buttons.length > 0 ? 46 : 0
                visible: root.buttons.length > 0

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: K4Theme.surfaceHi
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 36
                    spacing: 8

                    Repeater {
                        model: root.buttons

                        delegate: Rectangle {
                            id: actionButton
                            required property var modelData
                            readonly property string label:
                                modelData.text ?? modelData.identifier ?? ""

                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 9
                            color: actionMouse.containsMouse
                                ? K4Theme.blue : K4Theme.surfaceHi

                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                text: actionButton.label
                                color: K4Theme.ink
                                font.family: K4Theme.uiFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true
                                    root.actionRequested(actionButton.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
