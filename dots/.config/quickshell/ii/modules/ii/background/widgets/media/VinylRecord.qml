import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.widgets

/**
 * A vinyl record: a static grooved disc, a rotating album-art label and a
 * turned-metal spindle pin.
 *
 * Only the label turns. Grooves are concentric and therefore rotationally
 * symmetric, so animating them would be invisible work — they are painted once
 * into a Canvas (which keeps its own texture) and repainted only when the disc
 * is resized. The sheen belongs to the room's light rather than to the record,
 * so it stays put too. That leaves exactly one moving node while a track plays.
 *
 *   VinylRecord {
 *       width: 200; height: 200
 *       labelSize: 88
 *       artSource: root.displayedArtFilePath
 *       angle: root.spinAngle
 *   }
 */
Item {
    id: root

    property real labelSize: 88
    property real pinSize: 11
    property string artSource: ""
    property real angle: 0
    property color labelFallback: Appearance.colors.colPrimaryContainer
    property color labelFallbackText: Appearance.colors.colOnPrimaryContainer
    // Shown in the label when there is nothing to play.
    property bool idle: false

    // Supersampling factor for the two things here that rasterise to a texture
    // rather than to geometry: the groove Canvas and the masked art label.
    // The widget canvas sits under a fractional scene transform (0.9984 with
    // the default zoom style), so a texture rendered at exactly 1:1 gets
    // resampled and shows its edges. Drawing at 2x and scaling back down means
    // the downsample does the antialiasing instead. Rectangles and text are
    // unaffected — those are geometry and glyphs, not textures.
    readonly property real ss: 2
    property bool shadow: true

    implicitWidth: 200
    implicitHeight: 200

    // ---- drop shadow. Cast from a plain static circle rather than from the
    // record itself: shadowing the real disc would re-render the blur on every
    // frame of rotation, for a result that is identical each time.
    Rectangle {
        id: shadowCaster
        anchors.fill: parent
        radius: width / 2
        color: "black"
        visible: false
    }

    StyledDropShadow {
        target: shadowCaster
        visible: root.shadow
        radius: 14
        verticalOffset: 5
    }

    // ---- disc body + grooves. Painted once per size change, never per frame.
    Canvas {
        id: grooves
        anchors.centerIn: parent
        width: root.width * root.ss
        height: root.height * root.ss
        scale: 1 / root.ss

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onLabelSizeChanged() { grooves.requestPaint() }
        }

        onPaint: {
            const w = width;
            const h = height;
            if (w <= 0 || h <= 0)
                return;

            const ctx = getContext("2d");
            const cx = w / 2;
            const cy = h / 2;
            // Inset by a pixel of item space. Filling right up to the canvas
            // boundary leaves the antialiased falloff nowhere to go, so the
            // rasteriser clips it and the rim comes out visibly stepped.
            const R = Math.min(cx, cy) - root.ss;
            ctx.reset();

            // Vinyl body: darkest at the rim, very slightly lifted at the centre.
            const body = ctx.createRadialGradient(cx, cy, 0, cx, cy, R);
            body.addColorStop(0.00, "#171719");
            body.addColorStop(0.62, "#121214");
            body.addColorStop(0.94, "#0A0A0C");
            body.addColorStop(1.00, "#050506");
            ctx.fillStyle = body;
            ctx.beginPath();
            ctx.arc(cx, cy, R, 0, Math.PI * 2);
            ctx.fill();

            // Grooves, from just outside the label to just inside the rim.
            // labelSize is in item units, so scale it into canvas units.
            const inner = (root.labelSize * root.ss) / 2 + Math.max(3, R * 0.03);
            const outer = R - Math.max(2, R * 0.02);
            if (outer > inner) {
                // Fixed pitch in item space, so a small disc gets proportionally
                // as many grooves as a large one instead of a handful.
                const pitch = 2.6 * root.ss;
                ctx.lineWidth = root.ss * 0.6;
                ctx.strokeStyle = "rgba(255,255,255,0.10)";
                for (let r = inner; r <= outer; r += pitch) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    ctx.stroke();
                }

                // The wider "lands" a real pressing leaves between tracks.
                ctx.lineWidth = root.ss;
                ctx.strokeStyle = "rgba(255,255,255,0.19)";
                const lands = [0.34, 0.61, 0.83];
                for (let i = 0; i < lands.length; i++) {
                    const lr = inner + (outer - inner) * lands[i];
                    ctx.beginPath();
                    ctx.arc(cx, cy, lr, 0, Math.PI * 2);
                    ctx.stroke();
                }

                // Dark run-out ring separating the grooves from the label.
                ctx.lineWidth = root.ss * 1.5;
                ctx.strokeStyle = "rgba(0,0,0,0.55)";
                ctx.beginPath();
                ctx.arc(cx, cy, (root.labelSize * root.ss) / 2 + root.ss, 0, Math.PI * 2);
                ctx.stroke();
            }
        }
    }

    // ---- the only thing that turns
    Item {
        id: rotor
        anchors.fill: parent
        rotation: root.angle

        // Drawn at ss times final size and scaled back down, so the circular
        // mask edge is resolved by the downsample rather than by the mask's own
        // one-pixel boundary.
        Item {
            id: artHolder
            anchors.centerIn: parent
            width: root.labelSize * root.ss
            height: root.labelSize * root.ss
            scale: 1 / root.ss

            Rectangle {
                id: labelPlate
                anchors.fill: parent
                radius: width / 2
                color: root.labelFallback

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: root.idle
                    text: "music_off"
                    fill: 1
                    iconSize: Math.max(12, root.labelSize * 0.34) * root.ss
                    color: root.labelFallbackText
                }
            }

            StyledImage {
                id: art
                anchors.fill: parent
                visible: root.artSource !== ""
                source: root.artSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                antialiasing: true
                // Downscaling a cover to label size without mipmaps is the other
                // half of the aliasing; this costs one extra chain per texture.
                mipmap: true
                // A fixed cap rather than one derived from labelSize: every
                // layout then shares a single entry in Qt's pixmap cache, so
                // switching layouts reuses the decoded cover. 512 leaves room
                // for the 2x supersample plus a scaled-up widget.
                sourceSize.width: 512
                sourceSize.height: 512
                cache: true

                layer.enabled: true
                layer.smooth: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: art.width
                        height: art.height
                        radius: width / 2
                    }
                }
            }
        }
    }

    // ---- specular sheen. A pressed record is anisotropic: its grooves are
    // concentric, so the reflection is not a blob but two opposed lobes, and the
    // brightness swings twice per turn around the disc.
    //
    // The lobe ANGLE is measured, not eyeballed: sampling the prototype's
    // luminance against angle and fitting it gave cos(2(a - 162 deg)). Matching
    // the prototype's amplitude too turned out to be wrong in practice — it was
    // shot against a dark plinth, whereas this widget sits on whatever wallpaper
    // is behind it, and at that strength the shine vanished. Hence the two
    // intensities below being properties rather than baked into the stops.
    //
    // ConicalGradient runs clockwise from 12 o'clock, so a screen angle maps to
    // a stop position as ((a - 270) mod 360)/360 — putting the highlights at
    // 0.20 and 0.70, and the shadows at 0.45 and 0.95.
    //
    // Gloss and shadow are separate passes so they can be dialled independently,
    // and because interpolating a white stop straight into a black one runs the
    // crossover through mid-grey and hazes the disc. Each carries the shape at
    // full alpha and is scaled by its opacity.
    //
    // Both sit OVER the label: the shadow barely registers on near-black vinyl
    // but reads as the shaded half of the label, which is the asymmetry the
    // prototype shows. Fixed to the light, so they do not turn with the record,
    // and cached so they rasterise once rather than per frame.

    /// Peak alpha of the highlight lobes. This is the "shininess" knob.
    property real sheenGloss: 0.28
    /// Peak alpha of the shadow lobes.
    property real sheenShade: 0.34

    Rectangle {
        id: sheenMask
        anchors.fill: parent
        anchors.margins: 1
        radius: width / 2
        visible: false
    }

    // Highlights. Tightened with an exponent (k=1.6) rather than left as a plain
    // cosine: a narrower lobe against a wider falloff is what reads as gloss
    // instead of as a flat wash.
    ConicalGradient {
        anchors.fill: sheenMask
        source: sheenMask
        cached: true
        angle: 0
        opacity: root.sheenGloss
        gradient: Gradient {
            GradientStop { position: 0.0000; color: Qt.rgba(1, 0.988, 0.965, 0.0000) }
            GradientStop { position: 0.0417; color: Qt.rgba(1, 0.988, 0.965, 0.0000) }
            GradientStop { position: 0.0833; color: Qt.rgba(1, 0.988, 0.965, 0.0270) }
            GradientStop { position: 0.1250; color: Qt.rgba(1, 0.988, 0.965, 0.4273) }
            GradientStop { position: 0.1667; color: Qt.rgba(1, 0.988, 0.965, 0.8653) }
            GradientStop { position: 0.2083; color: Qt.rgba(1, 0.988, 0.965, 0.9912) }
            GradientStop { position: 0.2500; color: Qt.rgba(1, 0.988, 0.965, 0.7124) }
            GradientStop { position: 0.2917; color: Qt.rgba(1, 0.988, 0.965, 0.2371) }
            GradientStop { position: 0.3333; color: Qt.rgba(1, 0.988, 0.965, 0.0000) }
            GradientStop { position: 0.3750; color: Qt.rgba(1, 0.988, 0.965, 0.0000) }
            GradientStop { position: 0.4167; color: Qt.rgba(1, 0.988, 0.965, 0.0000) }
            GradientStop { position: 0.4583; color: Qt.rgba(1, 0.988, 0.965, 0.0000) }
            GradientStop { position: 0.5000; color: Qt.rgba(1, 0.988, 0.965, 0.0000) }
            GradientStop { position: 0.5417; color: Qt.rgba(1, 0.988, 0.965, 0.0000) }
            GradientStop { position: 0.5833; color: Qt.rgba(1, 0.988, 0.965, 0.0270) }
            GradientStop { position: 0.6250; color: Qt.rgba(1, 0.988, 0.965, 0.4273) }
            GradientStop { position: 0.6667; color: Qt.rgba(1, 0.988, 0.965, 0.8653) }
            GradientStop { position: 0.7083; color: Qt.rgba(1, 0.988, 0.965, 0.9912) }
            GradientStop { position: 0.7500; color: Qt.rgba(1, 0.988, 0.965, 0.7124) }
            GradientStop { position: 0.7917; color: Qt.rgba(1, 0.988, 0.965, 0.2371) }
            GradientStop { position: 0.8333; color: Qt.rgba(1, 0.988, 0.965, 0.0000) }
            GradientStop { position: 0.8750; color: Qt.rgba(1, 0.988, 0.965, 0.0000) }
            GradientStop { position: 0.9167; color: Qt.rgba(1, 0.988, 0.965, 0.0000) }
            GradientStop { position: 0.9583; color: Qt.rgba(1, 0.988, 0.965, 0.0000) }
            GradientStop { position: 1.0000; color: Qt.rgba(1, 0.988, 0.965, 0.0000) }
        }
    }

    // Shadows.
    ConicalGradient {
        anchors.fill: sheenMask
        source: sheenMask
        cached: true
        angle: 0
        opacity: root.sheenShade
        gradient: Gradient {
            GradientStop { position: 0.0000; color: Qt.rgba(0, 0, 0, 0.8090) }
            GradientStop { position: 0.0625; color: Qt.rgba(0, 0, 0, 0.1564) }
            GradientStop { position: 0.1250; color: Qt.rgba(0, 0, 0, 0.0000) }
            GradientStop { position: 0.1875; color: Qt.rgba(0, 0, 0, 0.0000) }
            GradientStop { position: 0.2500; color: Qt.rgba(0, 0, 0, 0.0000) }
            GradientStop { position: 0.3125; color: Qt.rgba(0, 0, 0, 0.0000) }
            GradientStop { position: 0.3750; color: Qt.rgba(0, 0, 0, 0.5878) }
            GradientStop { position: 0.4375; color: Qt.rgba(0, 0, 0, 0.9877) }
            GradientStop { position: 0.5000; color: Qt.rgba(0, 0, 0, 0.8090) }
            GradientStop { position: 0.5625; color: Qt.rgba(0, 0, 0, 0.1564) }
            GradientStop { position: 0.6250; color: Qt.rgba(0, 0, 0, 0.0000) }
            GradientStop { position: 0.6875; color: Qt.rgba(0, 0, 0, 0.0000) }
            GradientStop { position: 0.7500; color: Qt.rgba(0, 0, 0, 0.0000) }
            GradientStop { position: 0.8125; color: Qt.rgba(0, 0, 0, 0.0000) }
            GradientStop { position: 0.8750; color: Qt.rgba(0, 0, 0, 0.5878) }
            GradientStop { position: 0.9375; color: Qt.rgba(0, 0, 0, 0.9877) }
            GradientStop { position: 1.0000; color: Qt.rgba(0, 0, 0, 0.8090) }
        }
    }

    // ---- rim. Inset by a pixel so the groove Canvas circle is the ONLY thing
    // defining the silhouette: two circles of the same nominal radius rasterise
    // slightly differently, and the doubled edge is what reads as a jagged rim.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.09)
    }

    // ---- spindle pin, standing proud of the label
    Rectangle {
        anchors.centerIn: parent
        width: root.pinSize
        height: root.pinSize
        radius: width / 2
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.55)
        gradient: Gradient {
            GradientStop { position: 0.00; color: "#FDF8EE" }
            GradientStop { position: 0.45; color: "#C9C2B4" }
            GradientStop { position: 1.00; color: "#4E4941" }
        }
    }
}
