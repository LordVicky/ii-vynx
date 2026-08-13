import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import qs.services

RowLayout {
    id: root
    spacing: 10
    Layout.leftMargin: 8
    Layout.rightMargin: 8

    property string text: ""
    property string buttonIcon: ""
    property alias value: slider.value
    property alias stopIndicatorValues: slider.stopIndicatorValues
    property bool usePercentTooltip: true
    property real from: slider.from
    property real to: slider.to
    property real textWidth: 120

    readonly property string currentSearch: SearchRegistry.currentSearch
    onCurrentSearchChanged: {
        if (SearchRegistry.currentSearch.toLowerCase() === root.text.toLowerCase()) {
            highlightOverlay.startAnimation()
        }
    }

    
    RowLayout {
        id: row
        spacing: 10

        OptionalMaterialSymbol {
            opacity: 1 - highlightOverlay.opacity
            id: iconWidget
            icon: root.buttonIcon
            iconSize: Appearance.font.pixelSize.larger
        }
        StyledText {
            opacity: 1 - highlightOverlay.opacity
            id: labelWidget
            Layout.preferredWidth: root.textWidth
            // The label column is a fixed width, but Text neither wraps nor
            // clips by default, so anything wider than textWidth silently paints
            // out over the slider instead of stopping at its boundary. Every
            // English label happens to fit today; a translation need not, since
            // these all come through Translation.tr. Eliding keeps a too-long
            // label inside its column and costs nothing when it already fits.
            elide: Text.ElideRight
            text: root.text
            color: Appearance.colors.colOnSecondaryContainer
        }
        HighlightOverlay {
            id: highlightOverlay
            visible: false
        }
    }
    
    StyledSlider {
        id: slider
        configuration: StyledSlider.Configuration.XS
        usePercentTooltip: root.usePercentTooltip
        value: root.value
        from: root.from
        to: root.to
    }
}