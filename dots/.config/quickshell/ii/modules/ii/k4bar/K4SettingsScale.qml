import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root

    required property string title
    property string description: ""
    required property real value
    required property real minimum
    required property real maximum
    property real stepSize: 0.05

    signal valueEdited(real value)

    Layout.fillWidth: true
    Layout.preferredHeight: description.length > 0 ? 94 : 78
    radius: 12
    color: K4Theme.surface

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 5

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.title
                color: K4Theme.ink
                font.family: K4Theme.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            Item { Layout.fillWidth: true }

            Text {
                text: Math.round(root.value * 100) + "%"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 10
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
        }

        Text {
            visible: root.description.length > 0
            Layout.fillWidth: true
            text: root.description
            color: K4Theme.dim
            font.family: K4Theme.uiFont
            font.pixelSize: 9
            elide: Text.ElideRight
            maximumLineCount: 1
            renderType: Text.NativeRendering
        }

        Slider {
            id: slider
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            from: root.minimum
            to: root.maximum
            stepSize: root.stepSize
            value: root.value
            onMoved: root.valueEdited(value)

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 4
                radius: 2
                color: K4Theme.track

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: K4Theme.blue
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition
                    * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                implicitWidth: 14
                implicitHeight: 14
                radius: 7
                color: slider.pressed ? K4Theme.ink : K4Theme.muted
            }
        }
    }
}
