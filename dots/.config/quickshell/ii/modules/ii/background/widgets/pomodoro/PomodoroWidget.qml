import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "pomodoro"
    hoverEnabled: true

    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.pomodoro.scale ?? 1)

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    readonly property int secondsLeft: TimerService.pomodoroSecondsLeft
    readonly property int lapDuration: Math.max(1, TimerService.pomodoroLapDuration)
    // Counts DOWN, so the ring drains as the lap elapses.
    readonly property real progress: Math.max(0, Math.min(1, secondsLeft / lapDuration))
    readonly property string phaseLabel: TimerService.pomodoroLongBreak ? Translation.tr("Long break") : TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
    readonly property color phaseColor: TimerService.pomodoroBreak ? Appearance.colors.colTertiary : Appearance.colors.colPrimary

    function formatTime(totalSeconds) {
        const s = Math.max(0, totalSeconds);
        const mm = Math.floor(s / 60);
        const ss = s % 60;
        return `${mm}:${ss < 10 ? "0" : ""}${ss}`;
    }

    BackgroundWidgetCard {
        id: card
        host: root
        scaleFactor: root.widgetScale
        baseWidth: 236
        baseHeight: 236
        onRequestScale: v => root.dragScale = v
        onCommitScale: v => {
            Config.options.background.widgets.pomodoro.scale = v;
            root.dragScale = -1;
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 6

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.phaseLabel
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: root.phaseColor
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                CircularProgress {
                    anchors.centerIn: parent
                    implicitSize: Math.min(parent.width, parent.height)
                    lineWidth: 6
                    value: root.progress
                    colPrimary: root.phaseColor
                    colSecondary: Appearance.colors.colSecondaryContainer
                }

                StyledText {
                    anchors.centerIn: parent
                    text: root.formatTime(root.secondsLeft)
                    font.pixelSize: Appearance.font.pixelSize.huge
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                PomodoroButton {
                    icon: TimerService.pomodoroRunning ? "pause" : "play_arrow"
                    onTriggered: TimerService.togglePomodoro()
                }
                PomodoroButton {
                    icon: "restart_alt"
                    onTriggered: TimerService.resetPomodoro()
                }
                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: Translation.tr("Cycle %1/%2").arg(TimerService.pomodoroCycle + 1).arg(TimerService.cyclesBeforeLongBreak)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }

    component PomodoroButton: Rectangle {
        id: button
        property string icon: ""
        signal triggered

        implicitWidth: 30
        implicitHeight: 30
        radius: Appearance.rounding?.full ?? 15
        color: buttonArea.containsMouse ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colPrimaryContainer

        MaterialSymbol {
            anchors.centerIn: parent
            text: button.icon
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnPrimaryContainer
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }
}
