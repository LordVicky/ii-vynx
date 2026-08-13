import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "updates"
    hoverEnabled: true

    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.updates.scale ?? 1)

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    readonly property color statusColor: Updates.updateStronglyAdvised ? Appearance.colors.colError : Updates.updateAdvised ? Appearance.colors.colTertiary : Appearance.colors.colPrimary

    readonly property string statusText: {
        if (Updates.checking)
            return Translation.tr("Checking…");
        if (!Updates.available)
            return Translation.tr("Up to date");
        if (Updates.updateStronglyAdvised)
            return Translation.tr("Update strongly advised");
        if (Updates.updateAdvised)
            return Translation.tr("Update advised");
        return Translation.tr("Updates available");
    }

    BackgroundWidgetCard {
        id: card
        host: root
        scaleFactor: root.widgetScale
        baseWidth: 240
        baseHeight: 132
        onRequestScale: v => root.dragScale = v
        onCommitScale: v => {
            Config.options.background.widgets.updates.scale = v;
            root.dragScale = -1;
        }

        RowLayout {
            anchors.fill: parent
            spacing: 12

            MaterialSymbol {
                text: Updates.available ? "system_update_alt" : "task_alt"
                iconSize: Appearance.font.pixelSize.hugeass * 1.4
                color: root.statusColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    // The icon already carries the "all clear" state, so the big
                    // number only appears when there's actually a count to show.
                    visible: Updates.available
                    text: `${Updates.count}`
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.statusText
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    Timer {
        // The service refreshes on its own schedule elsewhere; this only makes
        // sure a freshly placed widget isn't blank until that fires.
        running: true
        repeat: false
        interval: 1000
        onTriggered: Updates.refresh()
    }
}
