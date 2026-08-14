pragma Singleton

import QtQuick
import qs.modules.common

// Shared baseline geometry for desktop widgets. Presentation tiers describe
// spatial treatment; they do not force unrelated widgets to share dimensions.
QtObject {
    readonly property QtObject presentationTier: QtObject {
        readonly property string condensed: "condensed"
        readonly property string compact: "compact"
        readonly property string standard: "standard"
        readonly property string showcase: "showcase"
    }

    readonly property QtObject typography: QtObject {
        readonly property int caption: Appearance.font.pixelSize.smallest
        readonly property int supporting: Appearance.font.pixelSize.smaller
        readonly property int body: Appearance.font.pixelSize.normal
        readonly property int actionLabel: Appearance.font.pixelSize.small
        readonly property int primaryLabel: Appearance.font.pixelSize.huge
        readonly property int heading: Appearance.font.pixelSize.hugeass
    }

    readonly property QtObject glyph: QtObject {
        readonly property int caption: 11
        readonly property int compactAction: 16
        readonly property int standardAction: 20
        readonly property int prominentAction: 25
    }

    readonly property QtObject control: QtObject {
        readonly property int compact: 28
        readonly property int standard: 36
        readonly property int prominent: 52
    }

    readonly property QtObject spacing: QtObject {
        readonly property int tight: 2
        readonly property int compact: 6
        readonly property int standard: 8
        readonly property int roomy: 12
    }

    readonly property QtObject padding: QtObject {
        readonly property int condensed: 8
        readonly property int compact: 10
        readonly property int standard: 16
    }

    readonly property QtObject height: QtObject {
        readonly property int condensed: 56
        readonly property int compactBar: 72
    }

    // Shared authored card widths keep equivalent desktop widget layouts on
    // the same canvas while allowing compact presentations to stay smaller.
    readonly property QtObject canvas: QtObject {
        readonly property int standard: 276
        readonly property int compact: 220
    }

}
