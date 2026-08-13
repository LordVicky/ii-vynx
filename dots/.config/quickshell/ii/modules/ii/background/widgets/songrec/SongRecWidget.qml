import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "songRec"
    hoverEnabled: true

    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.songRec.scale ?? 1)

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    readonly property bool hasResult: (SongRec.recognizedTrack?.title ?? "").length > 0

    BackgroundWidgetCard {
        id: card
        host: root
        scaleFactor: root.widgetScale
        baseWidth: 268
        baseHeight: 168
        onRequestScale: v => root.dragScale = v
        onCommitScale: v => {
            Config.options.background.widgets.songRec.scale = v;
            root.dragScale = -1;
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "graphic_eq"
                    iconSize: Appearance.font.pixelSize.large
                    color: SongRec.running ? Appearance.colors.colTertiary : Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Recognise")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.hasResult ? SongRec.recognizedTrack.title : SongRec.running ? Translation.tr("Listening…") : Translation.tr("Nothing recognised yet")
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: root.hasResult
                    text: SongRec.recognizedTrack.subtitle
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
                Item { Layout.fillHeight: true }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Source: %1").arg(SongRec.monitorSourceString)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Appearance.rounding?.small ?? 12
                color: listenArea.containsMouse ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colPrimaryContainer

                StyledText {
                    anchors.centerIn: parent
                    text: SongRec.running ? Translation.tr("Stop") : Translation.tr("Listen")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnPrimaryContainer
                }

                MouseArea {
                    id: listenArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SongRec.toggleRunning(!SongRec.running)
                }
            }
        }
    }
}
