import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Ported widgets pass their authored font size and card scale separately so Qt
// rasterizes each glyph at its final on-screen pixel size.
StyledText {
    id: root

    property real basePixelSize: Appearance.font.pixelSize.normal
    property real scaleFactor: 1
    property int requestedWeight: Font.Normal

    renderType: Text.QtRendering
    font.pixelSize: root.basePixelSize * root.scaleFactor
    font.weight: root.requestedWeight

    // StyledText supplies the shell's variable-font axes, including its normal
    // wght value (currently 450). That explicit axis otherwise wins over a
    // caller's `font.weight: Font.DemiBold`, leaving widget headings looking as
    // light as body copy. Keep every shell-provided axis, but let an explicitly
    // stronger QFont weight raise the variable font's weight to match.
    font.variableAxes: {
        const shellAxes = root.shouldUseNumberFont
            ? Appearance.font.variableAxes.numbers
            : Appearance.font.variableAxes.main;
        const axes = Object.assign({}, shellAxes);
        axes.wght = Math.max(axes.wght ?? Font.Normal, root.requestedWeight);
        return axes;
    }
}
