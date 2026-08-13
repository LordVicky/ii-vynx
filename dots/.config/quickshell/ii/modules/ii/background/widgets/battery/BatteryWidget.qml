import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "battery"
    hoverEnabled: true

    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.battery.scale ?? 1)

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // UPower reports no laptop battery on a desktop; the widget would just show a
    // meaningless 100%, so it hides itself rather than lying.
    readonly property bool hasBattery: Battery.available
    readonly property real percent: Battery.percentage
    readonly property bool low: Battery.isLowAndNotCharging

    readonly property color levelColor: {
        if (Battery.isCharging)
            return Appearance.colors.colTertiary;
        if (root.low)
            return Appearance.colors.colError;
        return Appearance.colors.colPrimary;
    }

    BackgroundWidgetCard {
        id: card
        host: root
        scaleFactor: root.widgetScale
        baseWidth: 220
        baseHeight: 132
        onRequestScale: v => root.dragScale = v
        onCommitScale: v => {
            Config.options.background.widgets.battery.scale = v;
            root.dragScale = -1;
        }

        RowLayout {
            anchors.fill: parent
            spacing: 12
            visible: root.hasBattery

            Item {
                implicitWidth: 56
                implicitHeight: 56
                Layout.alignment: Qt.AlignVCenter

                CircularProgress {
                    anchors.fill: parent
                    implicitSize: 56
                    lineWidth: 5
                    value: root.percent
                    colPrimary: root.levelColor
                    colSecondary: Appearance.colors.colSecondaryContainer
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: Battery.isCharging ? "bolt" : "battery_full"
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.levelColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: `${Math.round(root.percent * 100)}%`
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Battery.isCharging ? Translation.tr("Charging") : Battery.isPluggedIn ? Translation.tr("Plugged in") : Translation.tr("On battery")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: !root.hasBattery
            text: Translation.tr("No battery detected")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
    }
}
