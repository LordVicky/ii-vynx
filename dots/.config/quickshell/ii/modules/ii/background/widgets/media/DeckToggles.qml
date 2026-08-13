import Quickshell.Services.Mpris
import QtQuick
import qs.modules.common
import qs.modules.common.widgets

/**
 * Shuffle and repeat for the deck's corner, shaped like the 33/45 speed
 * selector a turntable has in roughly that spot.
 *
 * Square rather than round, unlike the transport buttons below them: these are
 * mode switches that stay pressed, and the LED reads as state where a round
 * chip would just look like another transport button.
 *
 * Each button hides independently when the current player cannot do it —
 * shuffle and loop are separate MPRIS capabilities and players do support one
 * without the other.
 *
 * An Item wrapping a Row rather than a bare Row: the buttons size themselves
 * off the slot width, and a Row's own width is implicit from its contents, so
 * the two would have chased each other in a binding loop.
 */
Item {
    id: root

    /// The widget's own current player - NOT MprisController.activePlayer.
    /// MediaWidget cycles its player independently of the global one.
    property var player: null
    /// MediaWidget.dynamicColors, so these track the album palette.
    property var colors: ({})
    property real spacing: 7

    readonly property bool shuffleOn: root.player?.shuffle ?? false
    readonly property var loop: root.player?.loopState ?? MprisLoopState.None
    readonly property bool repeatOn: root.loop !== MprisLoopState.None
    readonly property bool canControl: root.player?.canControl ?? false

    component DeckButton: RippleButton {
        id: btn
        property bool active: false
        property string symbol: ""

        implicitWidth: (root.width - root.spacing) / 2
        implicitHeight: root.height
        buttonRadius: Appearance.rounding?.verysmall ?? 4

        colBackground: root.colors.colSecondaryBackground ?? Appearance.colors.colSecondaryContainer
        colBackgroundHover: root.colors.colSecondaryBackgroundHover ?? Appearance.colors.colSecondaryContainerHover
        colRipple: root.colors.colSecondaryRipple ?? Appearance.colors.colSecondaryContainerActive

        Column {
            anchors.centerIn: parent
            spacing: 4

            TransportIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                symbol: btn.symbol
                size: btn.implicitHeight * 0.40
                // Vector geometry rather than an icon font: the widget is
                // scaled freely and a glyph this small smears. See
                // TransportIcon.qml.
                color: btn.active ? (root.colors.colPrimary ?? Appearance.colors.colPrimary) : (root.colors.colOnSurface ?? Appearance.colors.colOnSecondaryContainer)
            }

            // The pilot lamp. Dark but still drawn when off, so the button
            // keeps its shape and the lit state reads as a change rather than
            // as something appearing.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 5
                height: 5
                radius: height / 2
                color: btn.active ? (root.colors.colPrimary ?? Appearance.colors.colPrimary) : Qt.rgba(0, 0, 0, 0.35)
                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }
        }
    }

    Row {
        anchors.fill: parent
        spacing: root.spacing

        DeckButton {
            symbol: "shuffle"
            active: root.shuffleOn
            visible: (root.player?.shuffleSupported ?? false) && root.canControl
            onClicked: {
                if (root.player)
                    root.player.shuffle = !root.shuffleOn;
            }
        }

        DeckButton {
            // repeat_one only differs from repeat by the numeral, which is the
            // whole point: the button has three states and the icon has to say
            // which of the two "on" ones you are in.
            symbol: root.loop === MprisLoopState.Track ? "repeat_one" : "repeat"
            active: root.repeatOn
            visible: (root.player?.loopSupported ?? false) && root.canControl
            onClicked: {
                if (!root.player)
                    return;
                // None -> whole playlist -> just this track -> None.
                root.player.loopState = root.loop === MprisLoopState.None ? MprisLoopState.Playlist : root.loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
            }
        }
    }
}
