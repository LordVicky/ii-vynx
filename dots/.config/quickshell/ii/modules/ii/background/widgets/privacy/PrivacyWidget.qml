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
            spacing: card.scaled(8)

            RowLayout {
                Layout.fillWidth: true
                spacing: card.scaled(8)

                TransformSafeSymbol {
                    text: root.anyActive ? "shield_lock" : "shield"
                    baseIconSize: Appearance.font.pixelSize.large
                    scaleFactor: root.widgetScale
                    color: root.anyActive ? Appearance.colors.colError : Appearance.colors.colPrimary
                }
                TransformSafeText {
                    Layout.fillWidth: true
                    text: Translation.tr("Privacy")
                    basePixelSize: Appearance.font.pixelSize.normal
                    scaleFactor: root.widgetScale
                    requestedWeight: Font.DemiBold
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
        spacing: card.scaled(6)

        TransformSafeSymbol {
            text: privacyRow.icon
            baseIconSize: Appearance.font.pixelSize.smaller
            scaleFactor: root.widgetScale
            color: privacyRow.active ? Appearance.colors.colError : Appearance.colors.colSubtext
        }
        TransformSafeText {
            Layout.fillWidth: true
            text: privacyRow.label
            basePixelSize: Appearance.font.pixelSize.smaller
            scaleFactor: root.widgetScale
            color: privacyRow.active ? Appearance.colors.colOnLayer0 : root.adaptiveSubtextColor
        }
        Rectangle {
            implicitWidth: card.scaled(8)
            implicitHeight: card.scaled(8)
            radius: card.scaled(4)
            color: privacyRow.active ? Appearance.colors.colError : Appearance.colors.colOutlineVariant
        }
    }
}
