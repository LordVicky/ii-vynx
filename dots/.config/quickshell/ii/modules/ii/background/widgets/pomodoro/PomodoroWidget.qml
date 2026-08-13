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
            spacing: card.scaled(6)

            TransformSafeText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.phaseLabel
                basePixelSize: Appearance.font.pixelSize.smaller
                scaleFactor: root.widgetScale
                requestedWeight: Font.DemiBold
                color: root.phaseColor
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                CircularProgress {
                    anchors.centerIn: parent
                    implicitSize: Math.min(parent.width, parent.height)
                    lineWidth: card.scaled(6)
                    value: root.progress
                    colPrimary: root.phaseColor
                    colSecondary: Appearance.colors.colSecondaryContainer
                }

                TransformSafeText {
                    anchors.centerIn: parent
                    text: root.formatTime(root.secondsLeft)
                    basePixelSize: Appearance.font.pixelSize.huge
                    scaleFactor: root.widgetScale
                    requestedWeight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: card.scaled(10)

                PomodoroButton {
                    icon: TimerService.pomodoroRunning ? "pause" : "play_arrow"
                    onTriggered: TimerService.togglePomodoro()
                }
                PomodoroButton {
                    icon: "restart_alt"
                    onTriggered: TimerService.resetPomodoro()
                }
                TransformSafeText {
                    Layout.alignment: Qt.AlignVCenter
                    text: Translation.tr("Cycle %1/%2").arg(TimerService.pomodoroCycle + 1).arg(TimerService.cyclesBeforeLongBreak)
                    basePixelSize: Appearance.font.pixelSize.smallest
                    scaleFactor: root.widgetScale
                    color: root.adaptiveSubtextColor
                }
            }
        }
    }

    component PomodoroButton: Rectangle {
        id: button
        property string icon: ""
        signal triggered

        implicitWidth: card.scaled(30)
        implicitHeight: card.scaled(30)
        radius: card.scaled(Appearance.rounding?.full ?? 15)
        color: buttonArea.containsMouse ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colPrimaryContainer

        TransformSafeSymbol {
            anchors.centerIn: parent
            text: button.icon
            baseIconSize: Appearance.font.pixelSize.normal
            scaleFactor: root.widgetScale
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
