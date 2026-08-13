import qs.modules.common
import QtQuick

Item {
    id: root
    property string text: ""
    property int fontSize: Appearance.font.pixelSize.normal
    property int fontWeight: Font.Normal
    property color textColor: Appearance.colors.colOnLayer0
    property bool running: false

    /// Show an ellipsis while parked instead of a bare cut at the clip edge.
    /// Off by default so existing callers keep the behaviour they had.
    property bool elideWhenIdle: false
    /// Opacity of the text itself, kept off the root so a caller can dim the
    /// text without also dimming a background it might be sitting on.
    property alias textOpacity: innerText.opacity
    /// Native rendering re-rasterises at the scene scale; hosts that get scaled
    /// freely (the desktop widgets) need Qt rendering so the glyph outlines
    /// scale instead of the bitmap.
    property alias renderType: innerText.renderType

    /// Whether it is actually moving right now, as opposed to merely allowed to.
    readonly property bool scrolling: root.running && root.overflows

    // Measured on a TextMetrics rather than the item's own implicitWidth. With
    // elideWhenIdle the item's width is constrained while parked, and asking a
    // constrained, eliding Text how wide it wants to be is both unreliable and
    // circular - width would depend on overflow, which would depend on width.
    TextMetrics {
        id: metrics
        text: root.text
        font: innerText.font
    }

    readonly property bool overflows: metrics.width > root.width + 1
    /// How far the text has to travel, plus a gap so the tail clears the edge
    /// before it wraps back around.
    readonly property real scrollDistance: Math.max(0, metrics.width - root.width + 20)

    /// Normalised 0..1 sweep. The animation drives THIS rather than x directly,
    /// because NumberAnimation reads `from`/`to`/`duration` once, when it
    /// starts. Driving x meant `to` was -(implicitWidth - width + 20) evaluated
    /// before the text had been laid out: implicitWidth was 0, `to` came out
    /// POSITIVE, and the text slid off to the right instead of scrolling. With a
    /// constant 0..1 sweep the endpoints cannot go stale, and x is a live
    /// binding on the real geometry, so it is correct whenever layout settles.
    property real sweep: 0

    clip: true
    implicitHeight: innerText.implicitHeight

    StyledText {
        id: innerText
        text: root.text
        font.pixelSize: root.fontSize
        font.weight: root.fontWeight
        color: root.textColor
        // Constrained and eliding only while parked; free to overrun its host
        // while scrolling, which is the whole point.
        width: (root.elideWhenIdle && !root.scrolling) ? root.width : implicitWidth
        elide: (root.elideWhenIdle && !root.scrolling) ? Text.ElideRight : Text.ElideNone
        x: -root.sweep * root.scrollDistance
    }

    NumberAnimation {
        target: root
        property: "sweep"
        running: root.scrolling
        from: 0
        to: 1
        duration: Math.max(3500, root.scrollDistance * 28)
        easing.type: Easing.Linear
        loops: Animation.Infinite
        onStopped: root.sweep = 0
    }
}
