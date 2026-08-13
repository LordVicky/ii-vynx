import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "clipboard"
    hoverEnabled: true

    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.clipboard.scale ?? 1)

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    readonly property int maxEntries: 8
    readonly property var recentEntries: Cliphist.entries.slice(0, root.maxEntries)

    Component.onCompleted: Cliphist.refresh()

    // Cliphist entries arrive as "<id>\t<preview>"; the id is only needed when
    // copying back, so strip it for display.
    function entryLabel(entry) {
        const tab = entry.indexOf("\t");
        return tab >= 0 ? entry.slice(tab + 1) : entry;
    }

    BackgroundWidgetCard {
        id: card
        host: root
        scaleFactor: root.widgetScale
        baseWidth: 300
        baseHeight: 264
        onRequestScale: v => root.dragScale = v
        onCommitScale: v => {
            Config.options.background.widgets.clipboard.scale = v;
            root.dragScale = -1;
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: card.scaled(8)

            RowLayout {
                Layout.fillWidth: true
                spacing: card.scaled(8)

                TransformSafeSymbol {
                    text: "content_paste"
                    baseIconSize: Appearance.font.pixelSize.large
                    scaleFactor: root.widgetScale
                    color: Appearance.colors.colPrimary
                }
                TransformSafeText {
                    Layout.fillWidth: true
                    text: Translation.tr("Clipboard")
                    basePixelSize: Appearance.font.pixelSize.normal
                    scaleFactor: root.widgetScale
                    requestedWeight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
                TransformSafeSymbol {
                    text: "refresh"
                    baseIconSize: Appearance.font.pixelSize.normal
                    scaleFactor: root.widgetScale
                    color: refreshArea.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colSubtext

                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Cliphist.refresh()
                    }
                }
            }

            StyledListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: card.scaled(3)
                clip: true
                model: root.recentEntries

                delegate: Rectangle {
                    required property string modelData
                    width: ListView.view.width
                    implicitHeight: card.scaled(28)
                    radius: card.scaled(Appearance.rounding?.verysmall ?? 8)
                    color: entryArea.containsMouse ? Appearance.colors.colLayer1Hover : "transparent"

                    TransformSafeText {
                        anchors.fill: parent
                        anchors.leftMargin: card.scaled(8)
                        anchors.rightMargin: card.scaled(8)
                        verticalAlignment: Text.AlignVCenter
                        text: root.entryLabel(modelData)
                        basePixelSize: Appearance.font.pixelSize.smaller
                        scaleFactor: root.widgetScale
                        color: Appearance.colors.colOnLayer0
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: entryArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Copy rather than paste: pasting drives ydotool at the
                        // focused window, which is not meaningful from the desktop.
                        onClicked: Cliphist.copy(modelData)
                    }
                }
            }

            TransformSafeText {
                Layout.fillWidth: true
                visible: root.recentEntries.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Clipboard is empty")
                basePixelSize: Appearance.font.pixelSize.smaller
                scaleFactor: root.widgetScale
                color: root.adaptiveSubtextColor
            }
        }
    }
}
