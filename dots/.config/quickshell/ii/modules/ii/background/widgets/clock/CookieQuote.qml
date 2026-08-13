import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Qt5Compat.GraphicalEffects


Item {
    id: root
    property real uiScale: 1

    readonly property string quoteText: Config.options.background.widgets.clock.quote.text

    implicitWidth: quoteBox.implicitWidth
    implicitHeight: quoteBox.implicitHeight

    DropShadow {
        source: quoteBox 
        anchors.fill: quoteBox
        horizontalOffset: 0
        verticalOffset: 2 * root.uiScale
        radius: 12 * root.uiScale
        samples: radius * 2 + 1
        color: Appearance.colors.colShadow
        transparentBorder: true
    }
    
    Rectangle {
        id: quoteBox

        implicitWidth: quoteRow.implicitWidth + 8 * 2 * root.uiScale
        implicitHeight: quoteRow.implicitHeight + 4 * 2 * root.uiScale
        radius: Appearance.rounding.small * root.uiScale
        color: Appearance.colors.colSecondaryContainer

        Row {
            id: quoteRow
            anchors.centerIn: parent
            spacing: 4 * root.uiScale
            
            MaterialSymbol {
                id: quoteIcon
                anchors.top: parent.top
                iconSize: Appearance.font.pixelSize.huge * root.uiScale
                renderType: Text.QtRendering
                text: "format_quote"
                color: Appearance.colors.colOnSecondaryContainer
            }
            StyledText {
                id: quoteStyledText
                horizontalAlignment: Text.AlignLeft
                text: Config.options.background.widgets.clock.quote.text
                color: Appearance.colors.colOnSecondaryContainer
                font {
                    family: Appearance.font.family.reading
                    pixelSize: Appearance.font.pixelSize.large * root.uiScale
                    weight: Font.Normal
                }
                renderType: Text.QtRendering
            }
        }
    }
}
