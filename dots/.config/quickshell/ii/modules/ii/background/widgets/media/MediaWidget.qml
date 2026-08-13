import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

/**
 * Turntable media widget, in three layouts the user cycles with the small
 * button in the corner (same affordance as the calendar's size toggle):
 *
 *   platter  272x232  the record alone — closest to the old circular widget
 *   deck     320x239  a whole turntable, with title/artist and transport
 *   spindle  350x98   a bar with a small record at one end
 *
 * Across all three the tonearm encodes progress: it sets down on the outer
 * groove as a track starts and tracks inward as it plays. Pausing cues it up
 * and spins the platter down.
 *
 * Everything that moves is gated on playback. Nothing here animates, polls or
 * repaints while the music is stopped — see the spin machinery below.
 */
AbstractBackgroundWidget {
    id: root

    signal requestReset()

    configEntryName: "media"
    hoverEnabled: true

    // ---------------------------------------------------------------- layout
    readonly property var layoutOrder: ["platter", "deck", "spindle"]
    // Kept as a binding rather than assigned on click: writing configEntry.layout
    // lets this update itself, so the binding is never destroyed.
    readonly property string layoutMode: {
        const m = root.configEntry.layout ?? "platter";
        return root.layoutOrder.indexOf(m) >= 0 ? m : "platter";
    }

    function cycleLayout() {
        const i = root.layoutOrder.indexOf(root.layoutMode);
        root.configEntry.layout = root.layoutOrder[(i + 1) % root.layoutOrder.length];
    }

    readonly property real baseWidth: layoutMode === "deck" ? 320 : layoutMode === "spindle" ? 350 : 272
    readonly property real baseHeight: layoutMode === "deck" ? 239 : layoutMode === "spindle" ? 98 : 232

    // Live drag override. -1 means "not dragging", which lets widgetScale keep
    // its binding to the persisted config value; a plain assignment during drag
    // would break that binding permanently.
    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.media.scale ?? 1)

    implicitWidth: root.baseWidth * root.widgetScale
    implicitHeight: root.baseHeight * root.widgetScale

    // ---------------------------------------------------------------- player
    readonly property var playerList: MprisController.players
    property MprisPlayer currentPlayer: MprisController.activePlayer
    readonly property bool hasPlayer: root.currentPlayer !== null
    readonly property bool playing: root.currentPlayer?.isPlaying ?? false

    readonly property string trackTitle: root.currentPlayer?.trackTitle ?? Translation.tr("Nothing playing")
    readonly property string trackSubtitle: {
        if (!root.hasPlayer)
            return Translation.tr("No media player");
        const artist = root.currentPlayer.trackArtist ?? "";
        const album = root.currentPlayer.trackAlbum ?? "";
        if (artist !== "" && album !== "")
            return `${artist} — ${album}`;
        return artist !== "" ? artist : album;
    }

    readonly property real progress: {
        const len = root.currentPlayer?.length ?? 0;
        if (len <= 0)
            return 0;
        return Math.max(0, Math.min(1, (root.currentPlayer?.position ?? 0) / len));
    }

    // MprisPlayer.position is only refreshed when asked. One ping a second is
    // ample for a tonearm that crosses the record over several minutes, and it
    // stops dead the moment playback does.
    Timer {
        running: root.playing
        interval: 1000
        repeat: true
        onTriggered: root.currentPlayer?.positionChanged()
    }

    function nextPlayer() {
        if (root.playerList.length === 0)
            return;
        root.currentPlayer = root.playerList[(root.playerList.indexOf(root.currentPlayer) + 1) % root.playerList.length];
    }

    // ------------------------------------------------------------------ spin
    // 33 1/3 rpm is one turn per 1.8s. The platter eases up to speed and coasts
    // down rather than snapping, and when it has stopped no animation is left
    // running at all.
    property real spinAngle: 0

    NumberAnimation {
        id: spinLoop
        target: root
        property: "spinAngle"
        duration: 1800
        loops: Animation.Infinite
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: spinUp
        target: root
        property: "spinAngle"
        duration: 850
        easing.type: Easing.InQuad
        onFinished: {
            spinLoop.from = root.spinAngle;
            spinLoop.to = root.spinAngle + 360;
            spinLoop.start();
        }
    }

    NumberAnimation {
        id: spinDown
        target: root
        property: "spinAngle"
        duration: 1500
        easing.type: Easing.OutCubic
        // Keep the accumulated angle bounded across play/pause cycles.
        onFinished: root.spinAngle = root.spinAngle % 360
    }

    function applySpinState() {
        spinLoop.stop();
        spinUp.stop();
        spinDown.stop();
        if (root.playing) {
            spinUp.from = root.spinAngle;
            spinUp.to = root.spinAngle + 200;
            spinUp.start();
        } else {
            spinDown.from = root.spinAngle;
            spinDown.to = root.spinAngle + 150;
            spinDown.start();
        }
    }

    // Only fires on an actual change, so a widget created while paused starts
    // and stays completely still.
    onPlayingChanged: root.applySpinState()
    Component.onCompleted: if (root.playing) root.applySpinState()

    // The arm is cued up whenever nothing is playing.
    readonly property bool armDown: root.playing
    function armAngle(park, a0, a1) {
        return root.armDown ? (a0 + (a1 - a0) * root.progress) : park;
    }

    // ---------------------------------------------------------------- colours
    readonly property bool useAlbumColors: Config.options.background.widgets.media.useAlbumColors
    readonly property bool useDynamicColors: root.useAlbumColors && root.hasPlayer
    readonly property bool hideAllButtons: Config.options.background.widgets.media.hideAllButtons
    readonly property bool showPreviousToggle: Config.options.background.widgets.media.showPreviousToggle
    readonly property bool hovering: root.containsMouse
    readonly property bool showButtons: root.hideAllButtons ? root.hovering : true

    // The shell's Material scheme is built to tame chroma, which is the opposite
    // of what this widget wants — the prototype's accent is a vivid amber,
    // measured at S 74% / V 89%. Three things were flattening it:
    //
    //   1. the quantizer ran at depth 0 / rescale 1, i.e. it returned the
    //      cover's AVERAGE pixel, and averaging a colourful cover cancels its
    //      chroma into mud;
    //   2. artDominantColor then mixed that 20% toward a container colour;
    //   3. AdaptedMaterialScheme mixes every output half-way to an already
    //      muted theme colour.
    //
    // So sample several swatches, pick the most chromatic one, and keep only its
    // HUE — saturation and value are pinned to the constants below. Every cover
    // then lands at the same vivid, retro-poster intensity and only the hue
    // travels, which is what makes the prototype's palette feel deliberate
    // rather than "whatever the artwork averaged to".
    readonly property real accentSaturation: 0.74
    readonly property real accentValue: 0.89
    /// Hue used when the artwork is greyscale, so the accent never goes colourless.
    readonly property real fallbackHue: 0.086 // amber, as in the prototype

    // Most chromatic swatch that is neither near-black nor near-white. Weighted
    // toward brighter candidates so a dark corner of the sleeve does not win on
    // saturation alone.
    readonly property color artSwatch: {
        const cs = colorQuantizer?.colors ?? [];
        let best = null;
        let bestScore = -1;
        for (let i = 0; i < cs.length; i++) {
            const c = cs[i];
            if (c.hsvValue < 0.18 || c.hsvValue > 0.97)
                continue;
            const score = c.hsvSaturation * (0.35 + 0.65 * c.hsvValue);
            if (score > bestScore) {
                bestScore = score;
                best = c;
            }
        }
        return best ?? (cs.length > 0 ? cs[0] : Appearance.colors.colPrimary);
    }

    // hsvHue is -1 for greys, which would otherwise produce red.
    readonly property real accentHue: root.artSwatch.hsvSaturation > 0.05 && root.artSwatch.hsvHue >= 0 ? root.artSwatch.hsvHue : root.fallbackHue

    function accentAt(sat, val) {
        return Qt.hsva(root.accentHue, sat, val, 1);
    }

    readonly property var dynamicColors: ({
            colPrimary: root.useDynamicColors ? root.accentAt(root.accentSaturation, root.accentValue) : Appearance.colors.colPrimary,
            colPrimaryBackground: root.useDynamicColors ? root.accentAt(0.55, 0.28) : Appearance.colors.colPrimaryContainer,
            colPrimaryBackgroundHover: root.useDynamicColors ? root.accentAt(0.58, 0.34) : Appearance.colors.colPrimaryContainerHover,
            colPrimaryRipple: root.useDynamicColors ? root.accentAt(0.62, 0.42) : Appearance.colors.colPrimaryContainerActive,
            colSecondary: root.useDynamicColors ? root.accentAt(0.55, 0.72) : Appearance.colors.colSecondary,
            // The quiet chips the skip buttons sit on: near-neutral, but carrying
            // a trace of the accent hue so they read as part of the same palette.
            colSecondaryBackground: root.useDynamicColors ? root.accentAt(0.16, 0.20) : Appearance.colors.colSecondaryContainer,
            colSecondaryBackgroundHover: root.useDynamicColors ? root.accentAt(0.20, 0.28) : Appearance.colors.colSecondaryContainerHover,
            colSecondaryRipple: root.useDynamicColors ? root.accentAt(0.24, 0.36) : Appearance.colors.colSecondaryContainerActive,
            colOnSurface: root.useDynamicColors ? root.accentAt(0.10, 0.74) : Appearance.colors.colOnSecondaryContainer,
            // Dark rather than white: a light glyph on a vivid accent greys the
            // accent out, where a near-black one lets it stay saturated.
            colOnPrimary: root.useDynamicColors ? root.accentAt(0.88, 0.13) : Appearance.colors.colOnPrimary,
            colPrimaryHover: root.useDynamicColors ? root.accentAt(root.accentSaturation - 0.08, 0.97) : Appearance.colors.colPrimaryHover,
            colPrimaryActive: root.useDynamicColors ? root.accentAt(root.accentSaturation + 0.06, 0.80) : Appearance.colors.colPrimaryActive
        })

    // ------------------------------------------------------------- cover art
    readonly property var artUrl: root.currentPlayer?.trackArtUrl
    readonly property string artDownloadLocation: Directories.coverArt
    readonly property string artFileName: Qt.md5(root.artUrl)
    readonly property string artFilePath: `${root.artDownloadLocation}/${root.artFileName}`
    property bool downloaded: false
    readonly property string displayedArtFilePath: root.downloaded ? Qt.resolvedUrl(root.artFilePath) : ""

    onArtFilePathChanged: root.updateArt()

    function updateArt() {
        if (!root.artUrl) {
            root.downloaded = false;
            return;
        }
        coverArtDownloader.targetFile = root.artUrl;
        coverArtDownloader.artFilePath = root.artFilePath;
        root.downloaded = false;
        coverArtDownloader.running = true;
    }

    Process {
        id: coverArtDownloader
        property string targetFile: root.artUrl ?? ""
        property string artFilePath: root.artFilePath
        command: [
            "bash",
            "-c",
            `[ -f "$1" ] || curl -sSL -- "$2" -o "$1"`,
            "download-cover",
            artFilePath,
            targetFile
        ]
        onExited: (exitCode, exitStatus) => {
            root.downloaded = true;
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        // depth 0 / rescale 1 returned a single colour: the cover's average
        // pixel, which is mud on anything colourful. depth 3 gives 8 swatches to
        // choose the most chromatic one from, off a 64px sample.
        depth: 3
        rescaleSize: 64
    }

    // ----------------------------------------------------------- visualizer
    // One cava process, shared by both things that need levels: the platter's
    // radial wave and the deck's block meter. It is a real process, so it runs
    // only while a layout that shows levels has something playing.
    //
    // The platter's wave stays behind the visualizer.enable option because it is
    // an overlay on the artwork. The deck's meter is part of that layout's
    // design rather than an extra, so it is not optional.
    readonly property bool visualizerActive: root.playing && (root.layoutMode === "deck" || (root.layoutMode === "platter" && Config.options.background.widgets.media.visualizer.enable))
    property list<real> visualizerPoints: []

    Process {
        id: cavaProc
        running: root.visualizerActive
        onRunningChanged: {
            if (!cavaProc.running)
                root.visualizerPoints = [];
        }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                let points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
                root.visualizerPoints = points;
            }
        }
    }

    // ------------------------------------------------------------ behaviours
    allowMiddleClick: true
    onClicked: event => {
        if (event.button === Qt.MiddleButton)
            root.requestReset();
    }

    // ------------------------------------------------------------ components
    component TransportButton: RippleButton {
        id: transportButton
        property string symbolText
        property real size: 30
        // Play/pause carries the accent; the skips stay quiet, so the primary
        // action reads first.
        property bool accent: false

        implicitWidth: size
        implicitHeight: size
        buttonRadius: size / 2
        colBackground: accent ? root.dynamicColors.colPrimary : root.dynamicColors.colSecondaryBackground
        colBackgroundHover: accent ? root.dynamicColors.colPrimaryHover : root.dynamicColors.colSecondaryBackgroundHover
        colRipple: accent ? root.dynamicColors.colPrimaryActive : root.dynamicColors.colSecondaryRipple

        // Vector geometry, not icon-font text. The widget is scaled freely, so
        // a font glyph landed on whatever device size that produced — usually
        // under 20px, where skip_previous/skip_next have too few pixels for
        // both the bar and the triangle and read as a smudge. Shapes are
        // tessellated against the live scene transform, so these stay clean at
        // any widget size. See TransportIcon.qml.
        TransportIcon {
            anchors.centerIn: parent
            symbol: transportButton.symbolText
            size: transportButton.size * 0.64
            color: transportButton.accent ? root.dynamicColors.colOnPrimary : root.dynamicColors.colOnSurface
        }
    }

    component TransportRow: Row {
        id: transportRow
        property real size: 30
        spacing: 6

        TransportButton {
            size: transportRow.size
            visible: root.showPreviousToggle
            symbolText: "skip_previous"
            onClicked: root.currentPlayer?.previous()
        }
        TransportButton {
            size: transportRow.size
            accent: true
            symbolText: root.playing ? "pause" : "play_arrow"
            onClicked: root.currentPlayer?.togglePlaying()
        }
        TransportButton {
            size: transportRow.size
            symbolText: "skip_next"
            onClicked: root.currentPlayer?.next()
        }
    }

    // Retro LED level meter: a row of identical blocks that light up from the
    // left with how loud the music is. Deliberately NOT a spectrum — the blocks
    // are all the same size and only their lit state changes, which is what
    // gives it the old-hi-fi look.
    //
    // Levels come from the cava stream MediaWidget already runs for the radial
    // visualiser. cava emits 50 bands at 60fps, autosens-normalised to roughly
    // 0..1000; those are averaged into one loudness figure rather than being
    // mapped per-block.
    component BlockMeter: Item {
        id: blockMeter
        property var levels: []
        // Eight, as on the reference.
        property int count: 8
        property real maxLevel: 1000
        // cava's per-band mean sits low even on loud material, so the meter
        // reaches full scale well before the theoretical maximum.
        property real sensitivity: 0.32

        implicitWidth: meterRow.implicitWidth
        implicitHeight: meterRow.implicitHeight

        readonly property real level: {
            const src = blockMeter.levels;
            if (!src || src.length === 0)
                return 0;
            let sum = 0;
            for (let i = 0; i < src.length; i++)
                sum += src[i];
            const mean = sum / src.length;
            return Math.max(0, Math.min(1, mean / (blockMeter.maxLevel * blockMeter.sensitivity)));
        }

        // Animated separately so the lit count steps smoothly instead of
        // flickering between neighbouring blocks.
        property real displayLevel: level
        Behavior on displayLevel {
            NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
        }

        readonly property int litCount: Math.round(displayLevel * count)

        // Lamp glow, as on the reference: lit blocks bleed light instead of
        // being flat swatches. Declared before the row so it sits behind, and
        // transparentBorder lets it spill past the row's bounds.
        Glow {
            anchors.fill: meterRow
            source: meterRow
            radius: 4
            samples: 9
            color: root.dynamicColors.colPrimary
            transparentBorder: true
            opacity: 0.5
        }

        Row {
            id: meterRow
            spacing: 3

            Repeater {
                model: blockMeter.count
                delegate: Rectangle {
                    required property int index
                    readonly property bool lit: index < blockMeter.litCount

                    width: 3
                    height: 9
                    radius: 1
                    color: root.dynamicColors.colPrimary
                    opacity: lit ? 1 : 0.18

                    Behavior on opacity {
                        NumberAnimation { duration: 110 }
                    }
                }
            }
        }
    }

    component TrackProgress: Rectangle {
        id: trackProgress
        property real value: 0

        implicitHeight: 3
        radius: height / 2
        color: ColorUtils.transparentize(root.dynamicColors.colOnSurface, 0.74)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, trackProgress.value))
            height: parent.height
            radius: parent.radius
            color: root.dynamicColors.colPrimary
            Behavior on width {
                NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
            }
        }
    }

    // Blurred copy of the cover spilling out from behind the record.
    component ArtGlow: Item {
        id: artGlow
        property real discSize: 200

        width: discSize * 1.28
        height: discSize * 1.28
        visible: Config.options.background.widgets.media.glow.enable && root.displayedArtFilePath !== ""

        Image {
            id: glowImage
            anchors.fill: parent
            source: root.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            // Blurred to mush anyway, so it never needs a large decode.
            sourceSize.width: 128
            sourceSize.height: 128
            cache: true
            asynchronous: true
            opacity: 0.5
            layer.enabled: true
            layer.effect: StyledBlurEffect {
                source: glowImage
                brightness: 0.002 * Config.options.background.widgets.media.glow.brightness
            }
        }
    }

    component Panel: Item {
        id: panel
        property real cornerRadius: Appearance.rounding?.verylarge ?? 30

        StyledRectangularShadow {
            target: plate
            z: -2
        }

        Rectangle {
            id: plate
            anchors.fill: parent
            radius: panel.cornerRadius
            color: "transparent"
            z: -1

            WidgetBlurBackground {
                anchors.fill: parent
                cornerRadius: plate.radius
                blur: root.blur
                wallpaperPath: root.wallpaperPath
                sourceWidth: root.scaledScreenWidth
                sourceHeight: root.scaledScreenHeight
                offsetX: root.x
                offsetY: root.y
                wallpaperRenderX: root.wallpaperRenderX
                wallpaperRenderY: root.wallpaperRenderY
                wallpaperRenderWidth: root.wallpaperRenderWidth
                wallpaperRenderHeight: root.wallpaperRenderHeight
                parallaxBackdrop: root.parallaxBackdrop
                wallpaperSourceItem: root.wallpaperSourceItem
                hostScale: root.widgetScale
            }
        }
    }

    // ---------------------------------------------------------------- layouts
    Item {
        id: scaleWrapper
        width: root.baseWidth
        height: root.baseHeight
        transformOrigin: Item.TopLeft
        scale: root.widgetScale
        Behavior on scale {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }

        Loader {
            id: layoutLoader
            anchors.fill: parent
            sourceComponent: {
                if (root.layoutMode === "deck")
                    return deckLayout;
                if (root.layoutMode === "spindle")
                    return spindleLayout;
                return platterLayout;
            }
        }

        // ---- platter  272x232
        // disc c(116,116) r100 · pivot (244,40) len 126
        // The widget is wider than the frosted halo on purpose: a tonearm has to
        // pivot from OUTSIDE the record, and a square that hugs the disc leaves
        // nowhere to mount it — the arm ends up near-vertical, reading as a stick
        // rather than an arm. The extra 40px to the right is the arm's mount.
        Component {
            id: platterLayout
            Item {
                anchors.fill: parent

                Panel {
                    width: 232
                    height: 232
                    cornerRadius: 116
                }

                ArtGlow {
                    discSize: 200
                    x: 116 - width / 2
                    y: 116 - height / 2
                }

                VinylRecord {
                    x: 16
                    y: 16
                    width: 200
                    height: 200
                    labelSize: 88
                    pinSize: 11
                    artSource: root.displayedArtFilePath
                    angle: root.spinAngle
                    idle: !root.hasPlayer
                    labelFallback: root.dynamicColors.colSecondaryBackground
                    labelFallbackText: root.dynamicColors.colOnSurface

                    RadialWaveVisualizer {
                        anchors.fill: parent
                        z: 1
                        points: root.visualizerPoints
                        live: root.visualizerActive
                        color: root.dynamicColors.colSecondaryBackground
                        waveOpacity: Config.options.background.widgets.media.visualizer.opacity
                        waveBlur: Config.options.background.widgets.media.visualizer.blur
                        smoothing: Config.options.background.widgets.media.visualizer.smoothing
                    }
                }

                Tonearm {
                    x: 244
                    y: 40
                    armLength: 126
                    mountSize: 32
                    armAngle: root.armAngle(-74.5, -68.7, -47.5)
                }

                // No room for type here, so the controls only appear on hover.
                // Centred on the disc, not the widget, since the widget extends
                // past the halo to carry the arm mount.
                TransportRow {
                    x: 116 - width / 2
                    y: 194
                    size: 30
                    opacity: root.hovering && root.hasPlayer ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                }
            }
        }

        // The two things that can occupy the deck's corner, picked by
        // Config...media.deckControls. Both take the widget's own currentPlayer
        // rather than reaching for MprisController.activePlayer, which can be a
        // different player entirely once you cycle this widget's source.
        Component {
            id: deckFaderComponent
            DeckFader {
                player: root.currentPlayer
                colors: root.dynamicColors
                // Drives how much fine detail it draws: its knurling and caption
                // are 1px features that vanish under a device pixel when the
                // widget is shrunk toward the handle's 0.5x floor.
                hostScale: root.widgetScale
            }
        }

        Component {
            id: deckTogglesComponent
            DeckToggles {
                player: root.currentPlayer
                colors: root.dynamicColors
            }
        }

        // ---- deck  320x239
        // platter c(94,92) r74 · pivot (271,60) len 157
        // Proportions taken off the prototype, measured as fractions of its
        // plinth: 1.337 aspect, pivot at (0.846, 0.252), arm 0.490 of the
        // width. The platter already matched and is unchanged.
        //
        // The arm mounts well below the top edge — parking it up in the corner
        // shortened its reach across the record and read as a stick rather than
        // an arm. Its lowest reach (park, y=154) still has to clear the top of
        // the text column, or the title ends up underneath the stylus.
        Component {
            id: deckLayout
            Item {
                anchors.fill: parent

                Panel {
                    anchors.fill: parent
                    // A plinth, not a pill. verylarge (30) rounded the corners
                    // so hard the panel stopped reading as a deck.
                    cornerRadius: Appearance.rounding?.normal ?? 17
                }

                ArtGlow {
                    discSize: 148
                    x: 94 - width / 2
                    y: 92 - height / 2
                }

                VinylRecord {
                    x: 20
                    y: 18
                    width: 148
                    height: 148
                    labelSize: 62
                    pinSize: 9
                    artSource: root.displayedArtFilePath
                    angle: root.spinAngle
                    idle: !root.hasPlayer
                    labelFallback: root.dynamicColors.colSecondaryBackground
                    labelFallbackText: root.dynamicColors.colOnSurface
                }

                Tonearm {
                    // Angles are solved against the platter, not eyeballed: park
                    // sits the stylus 80px from the centre (just off the record),
                    // and the two playing angles put it on the outer groove
                    // (r=68) and the inner one (r=34). Move the pivot or the
                    // length and these have to be re-solved with it.
                    x: 271
                    y: 60
                    armLength: 157
                    armAngle: root.armAngle(-36.6, -32.3, -18.9)
                }

                // Level meter under the platter. No progress bar here — the
                // tonearm already carries position, so a bar was a third copy
                // of the same information.
                BlockMeter {
                    x: 20
                    y: 172
                    levels: root.visualizerPoints
                }

                // The plinth's empty corner, right of the platter and under the
                // arm pivot.
                //
                // Width and right edge are taken from the transport row rather
                // than picked, so the fader and the buttons under it are exactly
                // the same length and share both ends. The row is three 36px
                // buttons with 6px gaps (120), right-aligned inside a box that
                // starts at x=20 and is `parent.width - 36` wide, so its right
                // edge is `parent.width - 16` = 304 and it spans 184..304.
                // Binding to it keeps the two matched if the previous-track
                // button is turned off and the row narrows to 78.
                //
                // The top is set by the tonearm, which sweeps diagonally across
                // this corner as a track plays. At park the arm runs from its
                // pivot (271,60) to the stylus at
                //   (271 - 157·cos36.6°, 60 + 157·sin36.6°) = (144.95, 153.61)
                // a slope of -0.7426, so its centreline at the slot's left edge
                // x=184 is y=124.61 and the underside of the 4px tube is at
                // 126.61. y=132 leaves ~5px under it. That is the worst case:
                // the arm only climbs as x grows, and park is its lowest angle.
                //
                // Bottom lands at 182, six clear of the title row at y=188.
                Loader {
                    id: deckCorner
                    width: deckTransport.width
                    x: parent.width - 16 - width
                    y: 132
                    height: 50
                    readonly property string mode: Config.options.background.widgets.media.deckControls ?? "volume"
                    active: mode === "volume" || mode === "toggles"
                    sourceComponent: mode === "toggles" ? deckTogglesComponent : deckFaderComponent
                }

                // Bottom row: type on the left, transport on the right.
                Item {
                    x: 20
                    y: 188
                    // Ends at x=304, flush with the right edge of the corner
                    // slot above it, so the transport row and the fader share
                    // one right-hand line. Lining up with the control directly
                    // above reads stronger than matching the 20px the row keeps
                    // on the left against the plinth.
                    //
                    // This used to stop at 276, inset an extra 24px to dodge the
                    // resize handle, which was a bad trade: the handle only
                    // appears on hover, while this row is always drawn, so the
                    // layout sat permanently lopsided for something usually not
                    // on screen. The handle now lives outside the plinth
                    // instead - see `chrome` below.
                    width: parent.width - 36
                    // Has to clear the 36px transport buttons below.
                    height: 40

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - (deckTransport.visible ? deckTransport.width + 16 : 0)
                        spacing: 2

                        StyledText {
                            width: parent.width
                            text: root.trackTitle
                            elide: Text.ElideRight
                            renderType: Text.QtRendering
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                        }

                        StyledText {
                            width: parent.width
                            text: root.trackSubtitle
                            elide: Text.ElideRight
                            renderType: Text.QtRendering
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            opacity: 0.85
                            visible: text !== ""
                        }
                    }

                    TransportRow {
                        id: deckTransport
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        // 30px buttons put the glyphs around 16 device pixels,
                        // which is too few for skip_previous/skip_next to read
                        // as anything but a smudge. 36 buys ~23px.
                        size: 36
                        visible: root.showButtons && root.hasPlayer
                    }
                }
            }
        }

        // ---- spindle  350x98
        // disc c(49,49) r36 · pivot (96,20) len 46
        // Mounting the pivot past the disc (rather than directly above it) is
        // what keeps the arm reading as an arm at this size; the text column
        // starts clear of it at x=110.
        Component {
            id: spindleLayout
            Item {
                anchors.fill: parent

                Panel {
                    anchors.fill: parent
                    cornerRadius: Appearance.rounding?.large ?? 18
                }

                ArtGlow {
                    discSize: 72
                    x: 49 - width / 2
                    y: 49 - height / 2
                }

                VinylRecord {
                    x: 13
                    y: 13
                    width: 72
                    height: 72
                    labelSize: 30
                    pinSize: 6
                    artSource: root.displayedArtFilePath
                    angle: root.spinAngle
                    idle: !root.hasPlayer
                    labelFallback: root.dynamicColors.colSecondaryBackground
                    labelFallbackText: root.dynamicColors.colOnSurface
                }

                Tonearm {
                    x: 96
                    y: 20
                    armLength: 46
                    tubeThickness: 3
                    pivotSize: 10
                    headWidth: 10
                    headHeight: 8
                    showWeight: false
                    armAngle: root.armAngle(-74, -68.4, -48)
                }

                Column {
                    x: 110
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 110 - (playPause.visible ? playPause.width + 12 : 0) - 16
                    spacing: 4

                    StyledText {
                        width: parent.width
                        text: root.trackTitle
                        elide: Text.ElideRight
                        renderType: Text.QtRendering
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }

                    StyledText {
                        width: parent.width
                        text: root.trackSubtitle
                        elide: Text.ElideRight
                        renderType: Text.QtRendering
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        opacity: 0.85
                        visible: text !== ""
                    }

                    TrackProgress {
                        width: parent.width
                        value: root.progress
                        visible: root.hasPlayer
                    }
                }

                TransportButton {
                    id: playPause
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    size: 34
                    visible: root.showButtons && root.hasPlayer
                    symbolText: root.playing ? "pause" : "play_arrow"
                    onClicked: root.currentPlayer?.togglePlaying()
                }
            }
        }
    }

    // ------------------------------------------------------------- affordances
    // Chrome cannot just anchor to the widget's corners. The platter's panel is
    // a circle inscribed in a taller-than-wide box, so its corners fall outside
    // the visible surface entirely; the spindle's left end is the record. Each
    // layout therefore names its own three positions, in unscaled layout
    // coordinates.
    //
    // On deck and spindle the resize handle sits just PAST the right edge
    // rather than inside. Parked inside, it forced the deck's always-visible
    // title row to inset an extra 24px on the right to dodge a handle that only
    // appears on hover. Flush against the edge rather than held off it - the
    // handle's opacity is gated on the widget being hovered or the handle
    // itself being hovered, so any gap between the two is dead ground where it
    // fades out while you are reaching for it.
    //
    // Outside works because nothing in the chain clips: neither WidgetCanvas nor
    // AbstractWidget sets clip, and Qt Quick only prunes a subtree from hit
    // testing when an ancestor does.
    //
    // The platter deliberately does NOT follow: its visible surface is a circle
    // inscribed in a much wider box, so "just outside the box" is a long way
    // from anything you can see, and the handle ends up floating unattached in
    // the wallpaper. Its box corners are already empty, so the handle has
    // nothing to push around and stays on the halo with the other two.
    readonly property var chrome: {
        if (layoutMode === "deck")
            return {
                toggle: Qt.point(12, 12),
                player: Qt.point(292, 12),
                resize: Qt.point(320, 200)
            };
        if (layoutMode === "spindle")
            return {
                toggle: Qt.point(92, 76),
                player: Qt.point(326, 6),
                resize: Qt.point(350, 41)
            };
        // On the circle: 135 / -45 / 45 degrees at radius 96 from the disc
        // centre, which keeps all three on the frosted halo.
        return {
            toggle: Qt.point(40, 176),
            player: Qt.point(176, 40),
            resize: Qt.point(176, 176)
        };
    }

    WidgetResizeHandle {
        parent: scaleWrapper
        // The component anchors itself bottom-right; clear that so the
        // per-layout position above applies.
        anchors.right: undefined
        anchors.bottom: undefined
        x: root.chrome.resize.x
        y: root.chrome.resize.y
        hostWidget: root
        currentScale: root.widgetScale
        baseSize: root.baseWidth
        onRequestScale: v => root.dragScale = v
        onRequestCommit: v => {
            Config.options.background.widgets.media.scale = v;
            root.dragScale = -1;
        }
    }

    // Layout cycle, matching the calendar's size toggle.
    Rectangle {
        id: layoutToggle
        parent: scaleWrapper
        width: 16
        height: 16
        radius: 4
        z: 100
        color: Appearance.colors.colOnPrimaryContainer
        x: root.chrome.toggle.x
        y: root.chrome.toggle.y
        opacity: (root.hovering || layoutToggleArea.containsMouse) ? 0.5 : 0
        visible: opacity > 0 && !Config.options.background.widgetsLocked
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: root.layoutMode === "deck" ? "crop_landscape" : root.layoutMode === "spindle" ? "crop_16_9" : "album"
            iconSize: 11
            color: Appearance.colors.colPrimaryContainer
        }

        MouseArea {
            id: layoutToggleArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.cycleLayout()
        }
    }

    // Player switcher, only meaningful with more than one player around.
    Rectangle {
        id: playerToggle
        parent: scaleWrapper
        width: 16
        height: 16
        radius: 4
        z: 100
        color: Appearance.colors.colOnPrimaryContainer
        x: root.chrome.player.x
        y: root.chrome.player.y
        opacity: (root.hovering || playerToggleArea.containsMouse) && root.playerList.length > 1 ? 0.5 : 0
        visible: opacity > 0 && !Config.options.background.widgetsLocked
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "360"
            iconSize: 11
            color: Appearance.colors.colPrimaryContainer
        }

        MouseArea {
            id: playerToggleArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.nextPlayer()
        }
    }
}
