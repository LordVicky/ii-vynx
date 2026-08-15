import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions as CF
import "AdaptiveContrast.js" as AdaptiveContrastMath

/**
 * Reusable frosted-glass / solid-tint panel background for desktop widgets.
 *
 * At blur = 0 it reads as an opaque, flat-tinted card (like the widgets looked
 * before this feature existed). At blur = 1 it reads as a blurred crop of the
 * wallpaper region directly behind the widget, with a light tint on top so
 * content stays readable ("frosted glass"). Values in between blend the two.
 *
 * Usage: size it (anchors.fill: parent) over the widget's card/panel Rectangle,
 * and feed it the host widget's own coordinates so the backdrop crop lines up:
 *
 *   WidgetBlurBackground {
 *       anchors.fill: card
 *       cornerRadius: card.radius
 *       blur: root.blur                     // AbstractBackgroundWidget.blur (configEntry.blur)
 *       wallpaperPath: root.wallpaperPath    // AbstractBackgroundWidget.wallpaperPath
 *       sourceWidth: root.scaledScreenWidth
 *       sourceHeight: root.scaledScreenHeight
 *       offsetX: root.x
 *       offsetY: root.y
 *       wallpaperRenderX: root.wallpaperRenderX          // live wallpaper geometry
 *       wallpaperRenderY: root.wallpaperRenderY           // passed down from Background.qml
 *       wallpaperRenderWidth: root.wallpaperRenderWidth   // (0 = fall back to the static
 *       wallpaperRenderHeight: root.wallpaperRenderHeight // sourceWidth/sourceHeight crop)
 *       parallaxBackdrop: root.parallaxBackdrop
 *   }
 *
 * There is no shared, unscaled "wallpaper" Image id in scope for widgets loaded via
 * FadeLoader (they live in their own QML document), so this loads the wallpaper
 * image directly from wallpaperPath instead of trying to reuse Background.qml's item.
 * When wallpaperRenderX/Y/Width/Height are supplied (and parallaxBackdrop is true),
 * the backdrop mirrors that live geometry exactly instead, so it tracks parallax
 * panning and drag updates in real time.
 */
Item {
    id: root

    property real blur: 0.6 // 0 = opaque solid tint, 1 = clear frosted glass
    property real cornerRadius: Appearance.rounding?.verylarge ?? 30
    property color tintColor: Appearance.colors.colPrimaryContainer
    // Every frosted desktop widget shares the single request-driven wallpaper
    // sampler. Individual callers can opt out, but readability is the safe
    // default when cards can be dragged over arbitrary wallpaper regions.
    property bool adaptiveContrast: true
    property Item contrastHost: null

    // AbstractBackgroundWidget inherits AbstractWidget, whose `dragging`
    // property tracks the real drag interaction. Keep adaptive-contrast sampling
    // asleep while the card is stationary.
    readonly property bool contrastSamplingActive:
        root.contrastHost?.dragging ?? false

    // Backdrop exposure. Read straight from Config, like widgetTint, because this
    // is a wallpaper-wide problem rather than a per-widget one - plumbing it
    // through all eleven widgets would buy nothing.
    //
    // On a pale wallpaper frosted glass is white on white: the card dissolves into
    // the background and the light-on-glass content goes with it. Pushing the
    // backdrop down restores the contrast the glass is meant to provide, without
    // touching the colour scheme or forcing an opaque tint. -1..1, 0 = stock.
    readonly property real backdropBrightness: Config.options.background.widgetBrightness ?? 0
    // Opacity of the scrim at the slider's ends. Calibrated against the
    // brightness parameter this used to drive: 0.6 reproduces that range to
    // within a few levels of luminance at every stop.
    readonly property real _scrimMax: 0.6

    property string wallpaperPath: ""
    property real sourceWidth: 0
    property real sourceHeight: 0
    // Position (in the widget canvas' coordinate space) of the widget this
    // background sits behind - i.e. the host widget's own x/y.
    property real offsetX: 0
    property real offsetY: 0

    // Live geometry (in the widget canvas' coordinate space) of the real,
    // on-screen `wallpaper` TransitionImage in Background.qml. When set
    // (width/height > 0) and parallaxBackdrop is enabled, the backdrop below
    // mirrors this exactly instead of using the static sourceWidth/sourceHeight
    // crop, so it tracks parallax panning and stays correct while dragging.
    property real wallpaperRenderX: 0
    property real wallpaperRenderY: 0
    property real wallpaperRenderWidth: 0
    property real wallpaperRenderHeight: 0
    property bool parallaxBackdrop: true

    // The live wallpaper Item itself. Preferred over the numeric geometry above,
    // because subtracting coordinates cannot survive the transform stack between
    // the wallpaper and a widget: wallpaperItem scales both by defaultRatio,
    // WidgetCanvas then applies its own scale about its CENTRE, and a widget adds
    // a third scale of its own when resized. mapFromItem walks that whole chain,
    // so the crop lines up at any zoom, parallax offset or widget scale.
    // Extension widgets that don't pass an item fall back to the numeric path.
    property Item wallpaperSourceItem: null

    property int _contrastClientId: -1
    property real _sampledLuminance: -1
    property double _lastContrastRequestMs: 0
    property string _lastContrastCropSignature: ""
    property bool _useDarkSubtext: false
    readonly property real automaticScrimOpacity: root._sampledLuminance >= 0
        ? AdaptiveContrastMath.automaticScrimOpacity(root._sampledLuminance)
        : 0
    readonly property color adaptiveSubtextColor: {
        if (root._sampledLuminance < 0)
            return Appearance.colors.colSubtext;
        return CF.ColorUtils.colorWithLightness(
            Appearance.colors.colOnLayer0,
            root._useDarkSubtext ? 0.16 : 0.92
        );
    }

    function ensureContrastClient() {
        if (!root.adaptiveContrast || root._contrastClientId >= 0)
            return;
        root._contrastClientId = AdaptiveContrast.registerClient();
    }

    function normalizedWallpaperCrop() {
        let left;
        let top;
        let right;
        let bottom;
        let displayWidth;
        let displayHeight;

        if (root._useItem) {
            const topLeft = root.mapToItem(root.wallpaperSourceItem, 0, 0);
            const topRight = root.mapToItem(root.wallpaperSourceItem, root.width, 0);
            const bottomLeft = root.mapToItem(root.wallpaperSourceItem, 0, root.height);
            const bottomRight = root.mapToItem(root.wallpaperSourceItem, root.width, root.height);
            left = Math.min(topLeft.x, topRight.x, bottomLeft.x, bottomRight.x);
            top = Math.min(topLeft.y, topRight.y, bottomLeft.y, bottomRight.y);
            right = Math.max(topLeft.x, topRight.x, bottomLeft.x, bottomRight.x);
            bottom = Math.max(topLeft.y, topRight.y, bottomLeft.y, bottomRight.y);
            displayWidth = root.wallpaperSourceItem.width;
            displayHeight = root.wallpaperSourceItem.height;
        } else if (root._useParallax) {
            left = root.offsetX - root.wallpaperRenderX;
            top = root.offsetY - root.wallpaperRenderY;
            right = left + root.width;
            bottom = top + root.height;
            displayWidth = root.wallpaperRenderWidth;
            displayHeight = root.wallpaperRenderHeight;
        } else {
            left = root.offsetX;
            top = root.offsetY;
            right = left + root.width;
            bottom = top + root.height;
            displayWidth = root.sourceWidth;
            displayHeight = root.sourceHeight;
        }

        if (![left, top, right, bottom, displayWidth, displayHeight].every(Number.isFinite)
                || displayWidth <= 0 || displayHeight <= 0 || right <= left || bottom <= top)
            return null;

        return {
            rect: Qt.rect(left / displayWidth, top / displayHeight,
                (right - left) / displayWidth, (bottom - top) / displayHeight),
            displaySize: Qt.size(displayWidth, displayHeight)
        };
    }

    function clearContrastSample() {
        root._sampledLuminance = -1;
        root._useDarkSubtext = false;
    }

    function requestContrastSample() {
        if (!root.adaptiveContrast)
            return;
        if (root.wallpaperPath === "" || root.width <= 0 || root.height <= 0) {
            root.clearContrastSample();
            return;
        }
        root.ensureContrastClient();
        const crop = root.normalizedWallpaperCrop();
        if (root._contrastClientId < 0 || crop === null) {
            root.clearContrastSample();
            return;
        }
        const rect = crop.rect;
        const size = crop.displaySize;
        const signature = `${root.wallpaperPath}:${Math.round(rect.x * size.width / 2)}:${Math.round(rect.y * size.height / 2)}:${Math.round(rect.width * size.width / 2)}:${Math.round(rect.height * size.height / 2)}`;
        if (signature === root._lastContrastCropSignature)
            return;
        root._lastContrastCropSignature = signature;
        root._lastContrastRequestMs = Date.now();
        AdaptiveContrast.requestSample(root._contrastClientId, root.wallpaperPath, crop.rect, crop.displaySize);
    }

    function scheduleContrastSample() {
        if (!root.adaptiveContrast || !root.contrastSamplingActive)
            return;
        const remaining = 150 - (Date.now() - root._lastContrastRequestMs);
        if (remaining <= 0) {
            contrastThrottle.stop();
            root.requestContrastSample();
            return;
        }
        contrastThrottle.interval = Math.max(1, Math.ceil(remaining));
        contrastThrottle.restart();
    }

    function scheduleContrastAfterBackdropSettles() {
        if (root.adaptiveContrast && root.contrastSamplingActive)
            backdropSettle.restart();
    }

    Component.onCompleted: {
        root.ensureContrastClient();
    }
    Component.onDestruction: {
        if (root._contrastClientId >= 0)
            AdaptiveContrast.unregisterClient(root._contrastClientId);
    }
    onAdaptiveContrastChanged: {
        if (adaptiveContrast) {
            root.ensureContrastClient();
            root.scheduleContrastSample();
        } else {
            contrastThrottle.stop();
            backdropSettle.stop();
            root.clearContrastSample();
        }
    }

    onContrastSamplingActiveChanged: {
        if (!root.adaptiveContrast)
            return;

        if (root.contrastSamplingActive) {
            root.scheduleContrastSample();
        } else {
            // Guarantee a sample for the released/snapped final position.
            contrastThrottle.stop();
            backdropSettle.stop();
            root._lastContrastCropSignature = "";
            root.requestContrastSample();
        }
    }
    onWallpaperPathChanged: {
        root._sampledLuminance = -1;
        root._lastContrastRequestMs = 0;
        root._lastContrastCropSignature = "";
        root.scheduleContrastSample();
    }
    onWidthChanged: root.scheduleContrastSample()
    onHeightChanged: root.scheduleContrastSample()
    onOffsetXChanged: root.scheduleContrastSample()
    onOffsetYChanged: root.scheduleContrastSample()
    onHostScaleChanged: root.scheduleContrastSample()
    onSourceWidthChanged: root.scheduleContrastAfterBackdropSettles()
    onSourceHeightChanged: root.scheduleContrastAfterBackdropSettles()
    onWallpaperRenderXChanged: root.scheduleContrastAfterBackdropSettles()
    onWallpaperRenderYChanged: root.scheduleContrastAfterBackdropSettles()
    onWallpaperRenderWidthChanged: root.scheduleContrastAfterBackdropSettles()
    onWallpaperRenderHeightChanged: root.scheduleContrastAfterBackdropSettles()

    Connections {
        target: root.wallpaperSourceItem
        enabled: root.adaptiveContrast && root.wallpaperSourceItem !== null
        function onXChanged() { root.scheduleContrastAfterBackdropSettles(); }
        function onYChanged() { root.scheduleContrastAfterBackdropSettles(); }
        function onWidthChanged() { root.scheduleContrastAfterBackdropSettles(); }
        function onHeightChanged() { root.scheduleContrastAfterBackdropSettles(); }
    }

    Connections {
        target: AdaptiveContrast
        function onSampleReady(clientId, luminance) {
            if (clientId !== root._contrastClientId)
                return;
            if (luminance < 0) {
                root.clearContrastSample();
                return;
            }
            const scrimOpacity = AdaptiveContrastMath.automaticScrimOpacity(luminance);
            const effective = AdaptiveContrastMath.effectiveLuminance(luminance, scrimOpacity);
            root._useDarkSubtext = AdaptiveContrastMath.shouldUseDarkText(effective, root._useDarkSubtext);
            if (root._sampledLuminance < 0 || Math.abs(luminance - root._sampledLuminance) >= 0.025)
                root._sampledLuminance = luminance;
        }
    }

    Binding {
        target: root.contrastHost
        property: "adaptiveSubtextColor"
        value: root.adaptiveSubtextColor
        when: root.contrastHost !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    Timer {
        id: contrastThrottle
        repeat: false
        onTriggered: root.requestContrastSample()
    }

    Timer {
        id: backdropSettle
        interval: 250
        repeat: false
        onTriggered: root.requestContrastSample()
    }

    // Blur radius ceiling, and how far the blurred layer extends past the widget
    // so the filter has real content to sample at the edges instead of fading
    // into transparency. Full bleed would be _blurMax; two thirds is enough in
    // practice because the outermost ring is under the rounded mask, and it keeps
    // the layer meaningfully smaller.
    readonly property real _blurMax: 96
    readonly property real _blurBleed: Math.ceil(_blurMax * 0.67)
    // Longest edge, in px, the wallpaper is decoded at for use as a backdrop.
    readonly property int _backdropDecodeWidth: 1920

    // Dependency tokens. mapFromItem is a function call, so a binding using it
    // only re-evaluates when some property it *reads* changes. These are read in
    // _backdropRect purely so the crop recomputes as things move.
    property real hostScale: 1
    readonly property bool _useItem: parallaxBackdrop && wallpaperSourceItem !== null && wallpaperSourceItem.width > 0
    readonly property bool _useParallax: !_useItem && parallaxBackdrop && wallpaperRenderWidth > 0 && wallpaperRenderHeight > 0

    readonly property rect _backdropRect: {
        if (!_useItem)
            return Qt.rect(0, 0, 0, 0);
        // Read the animated inputs so this binding is re-evaluated when the
        // wallpaper pans/zooms, the widget is dragged, or it is resized.
        const _deps = [wallpaperSourceItem.x, wallpaperSourceItem.y, wallpaperSourceItem.width, wallpaperSourceItem.height, root.offsetX, root.offsetY, root.hostScale, root.width, root.height];
        const topLeft = root.mapFromItem(wallpaperSourceItem, 0, 0);
        const bottomRight = root.mapFromItem(wallpaperSourceItem, wallpaperSourceItem.width, wallpaperSourceItem.height);
        return Qt.rect(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y);
    }

    Item {
        id: clipContent
        anchors.fill: parent
        clip: true
        visible: root.blur > 0.001 && root.wallpaperPath !== ""

        // The blurred layer lives on THIS item, not on the backdrop image, and it
        // is only widget-sized (plus a blur-radius bleed margin). That matters a
        // lot: `backdrop` is the size of the whole on-screen wallpaper, so putting
        // layer.enabled on it allocated a full-wallpaper FBO *per widget* and ran
        // the blur chain over all of it, when >99% of the result is thrown away by
        // the clip. With ~17 widgets enabled that is what made wallpaper changes
        // and shell reloads crawl - the wallpaper's width/height Behavior animates
        // for 800ms, invalidating every one of those giant layers on every frame.
        //
        // Blurring a clipped item normally fades at the edges, because the filter
        // samples transparency just past the boundary. The bleed margin below is
        // the fix: the layer extends `_blurBleed` px beyond the widget on all
        // sides, so the faded ring falls outside the visible area and is discarded
        // by clipContent's clip and root's rounded mask.
        Item {
            id: blurSource
            x: -root._blurBleed
            y: -root._blurBleed
            width: root.width + root._blurBleed * 2
            height: root.height + root._blurBleed * 2
            clip: true

            layer.enabled: true
            layer.effect: MultiEffect {
                // macOS "vibrancy": the backdrop is not just blurred, it is pushed
                // saturated and slightly brighter, which is what stops frosted glass
                // reading as flat grey haze. blurMax is the radius ceiling; `blur`
                // scales within it, so raising the ceiling softens the whole range.
                saturation: 0.35
                // Deliberately constant. See the scrim below: routing the
                // brightness slider through here instead makes dragging it
                // re-run this blur chain, on every widget, every frame.
                brightness: 0.04
                blurEnabled: true
                blurMax: root._blurMax
                blur: root.blur
            }

            Image {
                id: backdrop
                // Positions come from root's coordinate space, shifted by the bleed
                // margin because this item's origin sits above/left of root's.
                x: root._blurBleed + (root._useItem ? root._backdropRect.x : root._useParallax ? (root.wallpaperRenderX - root.offsetX) : -root.offsetX)
                y: root._blurBleed + (root._useItem ? root._backdropRect.y : root._useParallax ? (root.wallpaperRenderY - root.offsetY) : -root.offsetY)
                width: Math.max(1, root._useItem ? root._backdropRect.width : root._useParallax ? root.wallpaperRenderWidth : root.sourceWidth)
                height: Math.max(1, root._useItem ? root._backdropRect.height : root._useParallax ? root.wallpaperRenderHeight : root.sourceHeight)
                source: root.wallpaperPath !== "" ? Qt.resolvedUrl(root.wallpaperPath) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                // Cap the decode. Every widget shares one entry in Qt's pixmap
                // cache (same source + same sourceSize), so this is a single
                // decode and a single texture for the whole desktop instead of a
                // full-resolution one - a 4K wallpaper is 4x the pixels for detail
                // that a blur destroys anyway. Keep it constant: varying it per
                // widget would defeat the cache sharing and force a re-decode.
                sourceSize.width: root._backdropDecodeWidth
            }
        }
    }

    // Backdrop brightness, as a plain quad over the finished glass rather than a
    // parameter fed into the MultiEffect above.
    //
    // The effect already exposes `brightness`, so driving it from the slider
    // looked free - one fewer item, no extra draw call. It is not. A MultiEffect
    // property change marks the whole effect dirty, so every frame of a slider
    // drag re-runs the blur chain on all ~17 widgets at once, which is what made
    // dragging crawl. Changing a Rectangle's opacity dirties one node: the
    // cached blurred texture underneath is reused untouched, and the per-frame
    // cost is a single alpha blend per widget.
    //
    // Blending toward black/white is not identical to an additive brightness
    // shift, but it is calibrated to the same range, and it degrades better -
    // additive crushed a dark wallpaper to flat black at the bottom of the
    // slider, where this keeps the texture.
    Rectangle {
        id: scrim
        anchors.fill: parent
        visible: clipContent.visible && root.backdropBrightness !== 0
        color: root.backdropBrightness < 0 ? "black" : "white"
        opacity: Math.abs(root.backdropBrightness) * root._scrimMax
    }

    Rectangle {
        anchors.fill: parent
        visible: opacity > 0
        color: "black"
        opacity: root.adaptiveContrast ? root.automaticScrimOpacity : 0
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    Rectangle {
        id: tint
        anchors.fill: parent
        color: root.tintColor
        opacity: (1 - root.blur * 0.65) * (Config.options.background.widgetTint ?? 0)
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    // Hairline highlight along the panel edge. Subtle, but it's what separates
    // glass from a plain translucent rectangle - it reads as the lit rim of a
    // physical pane rather than a hole cut in the wallpaper.
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border.width: 1
        // A white rim needs something darker to sit against. Once the backdrop is
        // pushed up it has nothing left to contrast with and the edge disappears,
        // so the rim crosses over to dark as brightness goes positive - still the
        // lit-edge read, just from the other side.
        readonly property real _rimDark: Math.max(0, root.backdropBrightness)
        border.color: Qt.rgba(1 - _rimDark, 1 - _rimDark, 1 - _rimDark, (0.12 + 0.06 * _rimDark) * Math.max(0.35, root.blur))
        visible: root.blur > 0.001
    }

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.cornerRadius
        }
    }
}
