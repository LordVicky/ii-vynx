import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "lyrics"
    hoverEnabled: true

    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.lyrics.scale ?? 1)

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    readonly property bool hasLyrics: LyricsService.syncedLines.length > 0

    BackgroundWidgetCard {
        id: card
        host: root
        scaleFactor: root.widgetScale
        baseWidth: 360
        baseHeight: 200
        onRequestScale: v => root.dragScale = v
        onCommitScale: v => {
            Config.options.background.widgets.lyrics.scale = v;
            root.dragScale = -1;
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "lyrics"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: MprisController.activePlayer?.trackTitle || Translation.tr("Nothing playing")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                }
            }

            // LyricScroller drives itself off LyricsService (and calls
            // initiliazeLyrics on completion), so it only needs a box to live in.
            // It hides itself when there are no synced lines.
            LyricScroller {
                Layout.fillWidth: true
                Layout.fillHeight: true
                halfVisibleLines: 1
                defaultLyricsSize: Appearance.font.pixelSize.normal
                rowHeight: Math.max(24, Math.floor(height / 3))
            }

            StyledText {
                Layout.fillWidth: true
                Layout.fillHeight: !root.hasLyrics
                visible: !root.hasLyrics
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                text: LyricsService.statusText || Translation.tr("No synced lyrics")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }
}
