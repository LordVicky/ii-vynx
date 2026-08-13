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
            spacing: card.scaled(8)

            RowLayout {
                Layout.fillWidth: true
                spacing: card.scaled(8)

                TransformSafeSymbol {
                    text: "graphic_eq"
                    baseIconSize: Appearance.font.pixelSize.large
                    scaleFactor: root.widgetScale
                    color: SongRec.running ? Appearance.colors.colTertiary : Appearance.colors.colPrimary
                }
                TransformSafeText {
                    Layout.fillWidth: true
                    text: Translation.tr("Recognise")
                    basePixelSize: Appearance.font.pixelSize.normal
                    scaleFactor: root.widgetScale
                    requestedWeight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: card.scaled(2)

                TransformSafeText {
                    Layout.fillWidth: true
                    text: root.hasResult ? SongRec.recognizedTrack.title : SongRec.running ? Translation.tr("Listening…") : Translation.tr("Nothing recognised yet")
                    basePixelSize: Appearance.font.pixelSize.smallie
                    scaleFactor: root.widgetScale
                    requestedWeight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                }
                TransformSafeText {
                    Layout.fillWidth: true
                    visible: root.hasResult
                    text: SongRec.recognizedTrack.subtitle
                    basePixelSize: Appearance.font.pixelSize.smaller
                    scaleFactor: root.widgetScale
                    color: root.adaptiveSubtextColor
                    elide: Text.ElideRight
                }
                Item { Layout.fillHeight: true }
                TransformSafeText {
                    Layout.fillWidth: true
                    text: Translation.tr("Source: %1").arg(SongRec.monitorSourceString)
                    basePixelSize: Appearance.font.pixelSize.smallest
                    scaleFactor: root.widgetScale
                    color: root.adaptiveSubtextColor
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: card.scaled(30)
                radius: card.scaled(Appearance.rounding?.small ?? 12)
                color: listenArea.containsMouse ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colPrimaryContainer

                TransformSafeText {
                    anchors.centerIn: parent
                    text: SongRec.running ? Translation.tr("Stop") : Translation.tr("Listen")
                    basePixelSize: Appearance.font.pixelSize.smaller
                    scaleFactor: root.widgetScale
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
