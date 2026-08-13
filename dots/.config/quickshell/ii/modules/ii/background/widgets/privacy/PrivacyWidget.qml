import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "privacy"
    hoverEnabled: true

    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.privacy.scale ?? 1)

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    readonly property bool micActive: Privacy.micActive
    readonly property bool screenSharing: Privacy.screenSharing
    readonly property bool anyActive: micActive || screenSharing

    BackgroundWidgetCard {
        id: card
        host: root
        scaleFactor: root.widgetScale
        baseWidth: 220
        baseHeight: 132
        onRequestScale: v => root.dragScale = v
        onCommitScale: v => {
            Config.options.background.widgets.privacy.scale = v;
            root.dragScale = -1;
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: root.anyActive ? "shield_lock" : "shield"
                    iconSize: Appearance.font.pixelSize.large
                    color: root.anyActive ? Appearance.colors.colError : Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Privacy")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
            }

            PrivacyRow {
                icon: "mic"
                label: Translation.tr("Microphone")
                active: root.micActive
            }
            PrivacyRow {
                icon: "screen_share"
                label: Translation.tr("Screen share")
                active: root.screenSharing
            }

            Item { Layout.fillHeight: true }
        }
    }

    component PrivacyRow: RowLayout {
        id: privacyRow
        property string icon: ""
        property string label: ""
        property bool active: false

        Layout.fillWidth: true
        spacing: 6

        MaterialSymbol {
            text: privacyRow.icon
            iconSize: Appearance.font.pixelSize.smaller
            color: privacyRow.active ? Appearance.colors.colError : Appearance.colors.colSubtext
        }
        StyledText {
            Layout.fillWidth: true
            text: privacyRow.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: privacyRow.active ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
        }
        Rectangle {
            implicitWidth: 8
            implicitHeight: 8
            radius: 4
            color: privacyRow.active ? Appearance.colors.colError : Appearance.colors.colOutlineVariant
        }
    }
}
