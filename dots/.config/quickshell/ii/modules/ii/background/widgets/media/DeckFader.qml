import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common

/**
 * The deck's pitch fader, wired to player volume.
 *
 * Real turntables put a long fader on the plinth to the right of the platter,
 * which is exactly where the Deck layout has spare room — and volume is a control
 * this widget otherwise does not expose anywhere, in any layout.
 *
 * Hidden outright when the current player cannot do volume. Plenty of players
 * (browsers especially) report volumeSupported = false, and a fader that looks
 * live but silently does nothing is worse than an empty corner. The slot is
 * absolutely positioned, so nothing reflows when this disappears.
 */
Item {
    id: root

    /// The widget's own current player - NOT MprisController.activePlayer.
    /// MediaWidget cycles its player independently of the global one.
    property var player: null
    /// MediaWidget.dynamicColors, so this tracks the album palette.
    property var colors: ({})
    /// MediaWidget.widgetScale. Everything here is authored in unscaled layout
    /// pixels and multiplied by this on the way to the screen.
    property real hostScale: 1

    /// How much fine detail is worth drawing. The resize handle goes down to
    /// 0.5x, and at that size the 1px knurling and the hot filament land under
    /// a single device pixel and smear into grey mush - the thumb stops reading
    /// as metal and becomes a dark blob.
    ///
    /// So they fade out instead: 0 below 0.72, full by 0.88. A ramp rather than
    /// a threshold because resizing is a live drag, and detail popping out on
    /// one frame reads as a glitch. The tube and the bare thumb carry every size
    /// below that; they are the parts still legible at 6x10 device pixels.
    readonly property real detail: Math.max(0, Math.min(1, (root.hostScale - 0.72) / 0.16))

    readonly property bool supported: (root.player?.volumeSupported ?? false) && (root.player?.canControl ?? false)
    readonly property real volume: Math.max(0, Math.min(1, root.player?.volume ?? 0))

    visible: root.supported
    // Not just invisible: an enabled MouseArea would keep swallowing presses
    // that should reach the widget underneath and start a drag.
    enabled: root.supported

    function applyAtX(px: real) {
        if (!root.supported)
            return;
        // The thumb's centre tracks the cursor, so the usable travel is the
        // track minus one thumb - otherwise the ends are unreachable.
        const usable = Math.max(1, track.width - thumb.width);
        root.player.volume = Math.max(0, Math.min(1, (px - thumb.width / 2) / usable));
    }

    Item {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        height: 22

        // Recessed channel. The gradient runs dark at the top so it reads as
        // cut into the plinth rather than sitting on it.
        Rectangle {
            id: channel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: height / 2
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.darker(root.colors.colSecondaryBackground ?? Appearance.colors.colSecondaryContainer, 1.7)
                }
                GradientStop {
                    position: 1
                    color: root.colors.colSecondaryBackground ?? Appearance.colors.colSecondaryContainer
                }
            }

            // Lit like a neon tube rather than a backlit bar. One glow gives a
            // flat halo that stops abruptly; a tube reads as two things at
            // once — a wide, faint bloom hanging in the air around it, and a
            // tight bright one hugging the glass. Both are declared before the
            // fill so they sit behind it, and transparentBorder lets the light
            // spill past the channel instead of being cut off at its edge.
            Glow {
                anchors.fill: fill
                source: fill
                radius: 16
                samples: 33
                color: root.colors.colPrimary ?? Appearance.colors.colPrimary
                transparentBorder: true
                opacity: 0.42
                visible: fill.width > channel.height
            }

            Glow {
                anchors.fill: fill
                source: fill
                radius: 6
                samples: 13
                color: root.colors.colPrimary ?? Appearance.colors.colPrimary
                transparentBorder: true
                opacity: 0.85
                visible: fill.width > channel.height
            }

            Rectangle {
                id: fill
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(parent.height, (thumb.x + thumb.width / 2))
                height: parent.height
                radius: parent.radius
                color: root.colors.colPrimary ?? Appearance.colors.colPrimary
            }

            // The hot filament down the middle of the tube. Real neon is
            // washed out to near-white at the centre and only saturates in the
            // halo; without this the bar is one flat colour with a glow stuck
            // around it. A sibling rather than a child of `fill`, so the glows
            // above sample the pure accent and do not bloom white.
            //
            // Faded at its edges rather than drawn as a solid line. At full
            // strength it was a crisp bright rule sitting on the bar - brighter
            // and harder-edged than anything else on the plinth, so it read as
            // a separate object instead of the inside of the tube. The vertical
            // gradient does the softening for free; blurring it would have
            // meant re-running a shader every time the volume moved.
            Rectangle {
                id: filament
                readonly property color hot: Qt.lighter(root.colors.colPrimary ?? Appearance.colors.colPrimary, 1.35)

                anchors.verticalCenter: fill.verticalCenter
                x: fill.x + 1
                width: Math.max(0, fill.width - 2)
                height: Math.max(1, fill.height * 0.55)
                radius: height / 2
                opacity: 0.5 * root.detail
                visible: fill.width > channel.height && root.detail > 0
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(filament.hot.r, filament.hot.g, filament.hot.b, 0)
                    }
                    GradientStop {
                        position: 0.5
                        color: filament.hot
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(filament.hot.r, filament.hot.g, filament.hot.b, 0)
                    }
                }
            }
        }

        // Turned-metal thumb with the machined ridges faders always have.
        Rectangle {
            id: thumb
            width: 13
            height: 21
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            x: (track.width - width) * root.volume
            color: root.colors.colOnSurface ?? Appearance.colors.colOnSecondaryContainer
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.45)

            Behavior on x {
                // Only smooths volume changed from elsewhere (keys, the OSD).
                // While dragging, x follows the value the drag just wrote, so
                // the animation is short enough not to feel like lag.
                enabled: !dragArea.pressed
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            // Machined ridges, running the full width inside the border and
            // packed at the prototype's pitch: a 1px line every 3px, which
            // fills the thumb rather than leaving three lonely marks in the
            // middle of it. Derived from the height so the knurling stays
            // right if the thumb is ever resized.
            Column {
                anchors.centerIn: parent
                spacing: 2
                opacity: root.detail
                visible: root.detail > 0
                Repeater {
                    model: Math.max(3, Math.floor((thumb.height - 2) / 3) + 1)
                    Rectangle {
                        width: thumb.width - 2
                        height: 1
                        color: Qt.rgba(0, 0, 0, 0.28)
                    }
                }
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            // The widget root is itself a MouseArea with drag.target set, and
            // it will steal the grab once the pointer passes the drag threshold
            // unless this says otherwise - dragging the fader would slide the
            // whole deck across the wallpaper.
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => root.applyAtX(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    root.applyAtX(mouse.x);
            }
        }
    }
}
