import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Material symbols are font glyphs, so render them at their final pixel size too.
MaterialSymbol {
    id: root

    property real baseIconSize: Appearance.font.pixelSize.normal
    property real scaleFactor: 1

    renderType: Text.QtRendering
    iconSize: root.baseIconSize * root.scaleFactor
}
