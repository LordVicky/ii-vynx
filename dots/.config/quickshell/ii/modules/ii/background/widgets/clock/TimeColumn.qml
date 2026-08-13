pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Column {
    id: root
    property real uiScale: 1
    property list<string> clockNumbers: DateTime.time.split(/[: ]/)
    property bool isEnabled: Config.options.background.widgets.clock.cookie.timeIndicators
    property color color: Appearance.colors.colOnSecondaryContainer

    property bool hourMarksEnabled: Config.options.background.widgets.clock.cookie.hourMarks
    spacing: -16 * uiScale

    Repeater {
        model: root.clockNumbers

        delegate: StyledText {
            required property string modelData
            text: modelData.padStart(2, "0")
            property bool isAmPm: !text.match(/\d{2}/i)
            property real numberSizeWithoutGlow: (isAmPm ? 26 : 68) * root.uiScale
            property real numberSizeWithGlow: (isAmPm ? 20 : 40) * root.uiScale
            property real numberSize: root.hourMarksEnabled ? numberSizeWithGlow : numberSizeWithoutGlow

            anchors.horizontalCenter: root.horizontalCenter
            color: root.color
            font {
                family: Appearance.font.family.expressive
                weight: Font.Bold
                pixelSize: numberSize
            }
            renderType: Text.QtRendering

            Behavior on numberSize {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }
        }
    }
}
