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
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "content_paste"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Clipboard")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
                MaterialSymbol {
                    text: "refresh"
                    iconSize: Appearance.font.pixelSize.normal
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
                spacing: 3
                clip: true
                model: root.recentEntries

                delegate: Rectangle {
                    required property string modelData
                    width: ListView.view.width
                    implicitHeight: 28
                    radius: Appearance.rounding?.verysmall ?? 8
                    color: entryArea.containsMouse ? Appearance.colors.colLayer1Hover : "transparent"

                    StyledText {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        text: root.entryLabel(modelData)
                        font.pixelSize: Appearance.font.pixelSize.smaller
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

            StyledText {
                Layout.fillWidth: true
                visible: root.recentEntries.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Clipboard is empty")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }
}
