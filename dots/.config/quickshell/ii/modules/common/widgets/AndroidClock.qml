import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common

/**
 * Small self-contained analog clock face, used by widgets that need to show
 * several cities' time at once (e.g. the world clock's compact "4x1" mode).
 * Either drive it live via autoTime, or pass explicit hourAngle/minuteAngle
 * (in degrees, 0 = 12 o'clock, clockwise) for a specific timezone/instant.
 */
Item {
    id: root

    property color backgroundColor: Appearance.colors.colPrimary
    property color handColor: Appearance.colors.colOnPrimary
    property color centerDotColor: Appearance.colors.colOnPrimary
    property string label: ""
    property color labelColor: Appearance.colors.colOnLayer0
    property real labelSpacing: 6

    property bool autoTime: false
    property real hourAngle: 0
    property real minuteAngle: 0

    readonly property real liveHourAngle: (DateTime.clock.date.getHours() % 12) * 30 + DateTime.clock.date.getMinutes() * 0.5
    readonly property real liveMinuteAngle: DateTime.clock.date.getMinutes() * 6
    readonly property real effectiveHourAngle: autoTime ? liveHourAngle : hourAngle
    readonly property real effectiveMinuteAngle: autoTime ? liveMinuteAngle : minuteAngle

    implicitWidth: 64
    implicitHeight: 64 + (root.label.length > 0 ? faceLabel.implicitHeight + root.labelSpacing : 0)

    ColumnLayout {
        anchors.fill: parent
        spacing: root.labelSpacing

        Item {
            id: face
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real faceSize: Math.min(width, height > 0 ? height : width)

            Rectangle {
                width: face.faceSize
                height: face.faceSize
                anchors.centerIn: parent
                radius: width / 2
                color: root.backgroundColor

                Behavior on color { ColorAnimation { duration: 300 } }

                // Hour hand
                Rectangle {
                    width: parent.width * 0.06
                    height: parent.height * 0.26
                    radius: width / 2
                    color: root.handColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    transformOrigin: Item.Bottom
                    y: parent.height / 2 - height
                    rotation: root.effectiveHourAngle

                    Behavior on rotation {
                        RotationAnimation {
                            direction: RotationAnimation.Clockwise
                            duration: 300
                        }
                    }
                }

                // Minute hand
                Rectangle {
                    width: parent.width * 0.045
                    height: parent.height * 0.36
                    radius: width / 2
                    color: root.handColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    transformOrigin: Item.Bottom
                    y: parent.height / 2 - height
                    rotation: root.effectiveMinuteAngle

                    Behavior on rotation {
                        RotationAnimation {
                            direction: RotationAnimation.Clockwise
                            duration: 300
                        }
                    }
                }

                Rectangle {
                    width: parent.width * 0.1
                    height: width
                    radius: width / 2
                    color: root.centerDotColor
                    anchors.centerIn: parent
                }
            }
        }

        StyledText {
            id: faceLabel
            Layout.alignment: Qt.AlignHCenter
            visible: root.label.length > 0
            text: root.label
            color: root.labelColor
            font.pixelSize: Appearance.font.pixelSize.smaller
            elide: Text.ElideRight
        }
    }
}
