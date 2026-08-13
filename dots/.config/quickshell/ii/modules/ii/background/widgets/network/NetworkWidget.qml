import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "network"
    hoverEnabled: true

    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.network.scale ?? 1)

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // NetworkUsage only polls while something is watching it.
    Component.onCompleted: NetworkUsage.activeInstances += 1
    Component.onDestruction: NetworkUsage.activeInstances = Math.max(0, NetworkUsage.activeInstances - 1)

    readonly property int historyLength: 40
    property list<real> downHistory: []
    property list<real> upHistory: []

    // Graph values are normalised against the largest sample in the window, so a
    // quiet line still reads as a line rather than a flat floor.
    readonly property real peak: {
        let m = 1;
        for (let i = 0; i < downHistory.length; i++) m = Math.max(m, downHistory[i]);
        for (let i = 0; i < upHistory.length; i++) m = Math.max(m, upHistory[i]);
        return m;
    }
    readonly property list<real> downNormalised: downHistory.map(v => v / root.peak)
    readonly property list<real> upNormalised: upHistory.map(v => v / root.peak)

    function formatSpeed(bytesPerSecond) {
        const bps = Math.max(0, bytesPerSecond);
        if (bps < 1024)
            return `${Math.round(bps)} B/s`;
        if (bps < 1024 * 1024)
            return `${(bps / 1024).toFixed(1)} KB/s`;
        return `${(bps / (1024 * 1024)).toFixed(1)} MB/s`;
    }

    Timer {
        running: true
        repeat: true
        interval: 1000
        onTriggered: {
            let d = root.downHistory.slice(-(root.historyLength - 1));
            let u = root.upHistory.slice(-(root.historyLength - 1));
            d.push(NetworkUsage.networkDownloadSpeed);
            u.push(NetworkUsage.networkUploadSpeed);
            root.downHistory = d;
            root.upHistory = u;
        }
    }

    BackgroundWidgetCard {
        id: card
        host: root
        scaleFactor: root.widgetScale
        baseWidth: 276
        baseHeight: 168
        onRequestScale: v => root.dragScale = v
        onCommitScale: v => {
            Config.options.background.widgets.network.scale = v;
            root.dragScale = -1;
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "swap_vert"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Network")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
            }

            SpeedRow {
                icon: "download"
                iconColor: Appearance.colors.colPrimary
                label: root.formatSpeed(NetworkUsage.networkDownloadSpeed)
            }
            SpeedRow {
                icon: "upload"
                iconColor: Appearance.colors.colTertiary
                label: root.formatSpeed(NetworkUsage.networkUploadSpeed)
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Graph {
                    anchors.fill: parent
                    values: root.downNormalised
                    color: Appearance.colors.colPrimary
                    fillOpacity: 0.35
                }
                Graph {
                    anchors.fill: parent
                    values: root.upNormalised
                    color: Appearance.colors.colTertiary
                    fillOpacity: 0.2
                }
            }
        }
    }

    component SpeedRow: RowLayout {
        id: speedRow
        property string icon: ""
        property color iconColor: Appearance.colors.colPrimary
        property string label: ""

        Layout.fillWidth: true
        spacing: 6

        MaterialSymbol {
            text: speedRow.icon
            iconSize: Appearance.font.pixelSize.smaller
            color: speedRow.iconColor
        }
        StyledText {
            Layout.fillWidth: true
            text: speedRow.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer0
        }
    }
}
