import QtQuick
import QtQuick.Shapes

/**
 * Transport glyphs drawn as vector geometry rather than icon-font text.
 *
 * The media widget is scaled freely by the user, so its icons land on whatever
 * device size that scale happens to produce — often under 20px, where a font
 * glyph has too few pixels to carry both the bar and the triangle of
 * skip_previous/skip_next and reads as a smudge. Shape geometry is tessellated
 * at render time against the accumulated scene transform, so it stays clean at
 * any widget size instead of degrading with it.
 *
 * Everything is expressed as a fraction of `size`, so there is one source of
 * truth for the proportions and nothing to re-tune per layout.
 */
Item {
    id: root

    /// One of: play_arrow, pause, skip_next, skip_previous
    property string symbol: "play_arrow"
    property real size: 24
    property color color: "white"

    /// Corner rounding, matching the Material Symbols "Rounded" style the rest
    /// of the shell uses. Applied as a same-coloured stroke with round joins,
    /// which grows the shape slightly — the path is inset to compensate.
    readonly property real round: root.size * 0.075

    implicitWidth: root.size
    implicitHeight: root.size

    component Tri: Shape {
        id: tri
        /// x of the flat back edge, and of the opposite apex. Which way the
        /// triangle points falls out of their order — no direction flag, since
        /// one that disagreed with the coordinates silently drew it backwards.
        property real xBack: 0
        property real xApex: 1
        property real yTop: 0.16
        property real yBottom: 0.84
        /// y of the apex. Centred for the transport glyphs, but the shuffle
        /// arrowheads sit on their own rows, so it has to be movable.
        property real yMid: 0.5

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Antialiasing is analytic with the curve renderer, so this stays crisp
        // however the widget is scaled.
        // PathLine's `parent` is not the ShapePath, so every coordinate has to
        // go through these ids explicitly.
        ShapePath {
            id: sp
            fillColor: root.color
            strokeColor: root.color
            strokeWidth: root.round
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            readonly property real ax: tri.xBack * root.size
            readonly property real bx: tri.xApex * root.size

            startX: sp.ax
            startY: tri.yTop * root.size
            PathLine {
                x: sp.bx
                y: tri.yMid * root.size
            }
            PathLine {
                x: sp.ax
                y: tri.yBottom * root.size
            }
            PathLine {
                x: sp.ax
                y: tri.yTop * root.size
            }
        }
    }

    /// The transport glyphs are solid shapes; shuffle and repeat are drawn
    /// lines with arrowheads on the end, so they need an open stroked path
    /// instead of a fill. Weight is a fraction of `size` like everything else,
    /// so it thins with the icon rather than staying put and going blobby.
    component Stroke: ShapePath {
        /// Line weight as a fraction of `size`. The numeral inside repeat_one
        /// runs thinner than the loop around it, so it stays a separate mark
        /// rather than reading as part of the same drawing.
        property real weight: 0.105

        fillColor: "transparent"
        strokeColor: root.color
        strokeWidth: root.size * weight
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
    }

    component Bar: Rectangle {
        property real xLeft: 0
        property real wide: 0.12
        property real yTop: 0.16
        property real tall: 0.68

        color: root.color
        x: xLeft * root.size
        y: yTop * root.size
        // Never let the bar vanish: below ~1px it would drop out entirely and
        // skip_next would read as a bare play arrow.
        width: Math.max(1, wide * root.size)
        height: tall * root.size
        radius: width / 2
    }

    // play_arrow — a single triangle, inset for the rounding stroke.
    Loader {
        anchors.fill: parent
        active: root.symbol === "play_arrow"
        sourceComponent: Tri {
            xBack: 0.31
            xApex: 0.76
            yTop: 0.22
            yBottom: 0.78
        }
    }

    // pause — two bars.
    Loader {
        anchors.fill: parent
        active: root.symbol === "pause"
        sourceComponent: Item {
            Bar {
                xLeft: 0.28
                wide: 0.16
                yTop: 0.21
                tall: 0.58
            }
            Bar {
                xLeft: 0.56
                wide: 0.16
                yTop: 0.21
                tall: 0.58
            }
        }
    }

    // skip_next / skip_previous — triangle plus the end-stop bar.
    Loader {
        anchors.fill: parent
        active: root.symbol === "skip_next" || root.symbol === "skip_previous"
        sourceComponent: Item {
            id: skip
            readonly property bool fwd: root.symbol === "skip_next"

            Tri {
                xBack: skip.fwd ? 0.21 : 0.79
                xApex: skip.fwd ? 0.61 : 0.39
                yTop: 0.23
                yBottom: 0.77
            }
            Bar {
                xLeft: skip.fwd ? 0.70 : 0.185
                wide: 0.115
                yTop: 0.21
                tall: 0.58
            }
        }
    }

    // shuffle — two paths that swap rows as they cross, both ending in an
    // arrowhead on the right. The crossing is the whole icon: two lines that
    // merely ran parallel would read as an equals sign.
    Loader {
        anchors.fill: parent
        active: root.symbol === "shuffle"
        sourceComponent: Item {
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                // top-left, crossing down to the bottom-right
                Stroke {
                    startX: 0.08 * root.size
                    startY: 0.27 * root.size
                    PathLine {
                        x: 0.27 * root.size
                        y: 0.27 * root.size
                    }
                    PathLine {
                        x: 0.60 * root.size
                        y: 0.73 * root.size
                    }
                    PathLine {
                        x: 0.72 * root.size
                        y: 0.73 * root.size
                    }
                }
                // bottom-left, crossing up to the top-right
                Stroke {
                    startX: 0.08 * root.size
                    startY: 0.73 * root.size
                    PathLine {
                        x: 0.27 * root.size
                        y: 0.73 * root.size
                    }
                    PathLine {
                        x: 0.60 * root.size
                        y: 0.27 * root.size
                    }
                    PathLine {
                        x: 0.72 * root.size
                        y: 0.27 * root.size
                    }
                }
            }
            Tri {
                xBack: 0.70
                xApex: 0.94
                yTop: 0.09
                yBottom: 0.45
                yMid: 0.27
            }
            Tri {
                xBack: 0.70
                xApex: 0.94
                yTop: 0.55
                yBottom: 0.91
                yMid: 0.73
            }
        }
    }

    // repeat / repeat_one — two rotationally symmetric brackets chasing each
    // other round a loop. repeat_one adds the numeral in the gap between them.
    Loader {
        anchors.fill: parent
        active: root.symbol === "repeat" || root.symbol === "repeat_one"
        sourceComponent: Item {
            id: rep
            readonly property bool one: root.symbol === "repeat_one"

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                // upper bracket: up the left side, round the corner, run right
                Stroke {
                    startX: 0.14 * root.size
                    startY: 0.54 * root.size
                    PathLine {
                        x: 0.14 * root.size
                        y: 0.32 * root.size
                    }
                    PathArc {
                        x: 0.26 * root.size
                        y: 0.20 * root.size
                        radiusX: 0.12 * root.size
                        radiusY: 0.12 * root.size
                        direction: PathArc.Clockwise
                    }
                    PathLine {
                        x: 0.60 * root.size
                        y: 0.20 * root.size
                    }
                }
                // lower bracket: the same shape turned through 180°
                Stroke {
                    startX: 0.86 * root.size
                    startY: 0.46 * root.size
                    PathLine {
                        x: 0.86 * root.size
                        y: 0.68 * root.size
                    }
                    PathArc {
                        x: 0.74 * root.size
                        y: 0.80 * root.size
                        radiusX: 0.12 * root.size
                        radiusY: 0.12 * root.size
                        direction: PathArc.Clockwise
                    }
                    PathLine {
                        x: 0.40 * root.size
                        y: 0.80 * root.size
                    }
                }
            }
            Tri {
                xBack: 0.58
                xApex: 0.84
                yTop: 0.03
                yBottom: 0.37
                yMid: 0.20
            }
            Tri {
                xBack: 0.42
                xApex: 0.16
                yTop: 0.63
                yBottom: 0.97
                yMid: 0.80
            }

            // The "1". A bare upright is ambiguous at this size, so it gets the
            // numeral's angled flag — two strokes are still cheaper than
            // hand-authoring digit outlines.
            //
            // Kept short and thin on purpose. Drawn at the loop's own weight
            // and full height it came within a fifth of a stroke of both
            // brackets and the three marks merged into one blob; this leaves a
            // clear stroke-width of air above and below.
            Loader {
                anchors.fill: parent
                active: rep.one
                sourceComponent: Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    Stroke {
                        weight: 0.085
                        startX: 0.42 * root.size
                        startY: 0.47 * root.size
                        PathLine {
                            x: 0.50 * root.size
                            y: 0.40 * root.size
                        }
                        PathLine {
                            x: 0.50 * root.size
                            y: 0.61 * root.size
                        }
                    }
                }
            }
        }
    }
}
