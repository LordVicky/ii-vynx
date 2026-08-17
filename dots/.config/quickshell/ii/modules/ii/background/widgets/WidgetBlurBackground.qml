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
 * Built-in widgets receive Background.qml's live wallpaper Loader through
 * wallpaperSourceItem. Their glass samples only the card-sized region of that
 * already-rendered source, avoiding a second wallpaper Image per widget. Extension
 * widgets that do not provide the live item keep the wallpaperPath fallback.
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

    // The existing Desktop widgets > Live frosted glass switch is the resource
    // lifetime gate. Off means tint-only: no wallpaper backdrop decode, blur FBO,
    // rounded-mask FBO or adaptive wallpaper sampling remains active.
    readonly property bool glassEnabled: Config.options.background.parallaxBackdrop ?? true
    readonly property bool adaptiveContrastActive: root.glassEnabled && root.adaptiveContrast

    // AbstractBackgroundWidget inherits AbstractWidget, whose `dragging`
    // property tracks the real drag interaction. Keep adaptive-contrast sampling
    // asleep while the card is stationary.
    readonly property bool contrastSamplingActive:
        root.adaptiveContrastActive && (root.contrastHost?.dragging ?? false)

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

    // Built-in widgets pass Background.qml's Loader as wallpaperSourceItem. Its
    // loaded TransitionImage already exposes transitionActive and frontImg, so
    // use those public properties as the only continuous-update gate. This keeps
    // static wallpaper captures frozen without adding another revision/service
    // object or coupling extension widgets to the built-in wallpaper pipeline.
    readonly property var _sharedWallpaperContent: {
        if (!root._useSharedBackdrop || root.wallpaperSourceItem === null)
            return null;
        return root.wallpaperSourceItem["item"] ?? null;
    }
    readonly property var _sharedWallpaperFrontItem:
        root._sharedWallpaperContent !== null
            ? (root._sharedWallpaperContent["frontImg"] ?? null)
            : null
    readonly property bool _sharedBackdropLive: {
        const content = root._sharedWallpaperContent;
        if (content === null)
            return false;
        if (content["transitionActive"] === true)
            return true;
        const front = root._sharedWallpaperFrontItem;
        if (front === null)
            return false;
        const status = front["status"];
        return status === Image.Null || status === Image.Loading;
    }
    property bool _backdropReady: false

    // A frozen ShaderEffectSource is a cache *and* an allocated render target.
    // Resizing that same target in place proved unreliable on the current RHI:
    // both scheduleUpdate() and temporarily setting live=true could leave the
    // pre-resize sample stretched into the new dimensions. Keep one stable
    // allocation active while geometry moves, then prime a second slot at the
    // settled size and swap to it. The old slot is immediately nulled/released,
    // so at rest only one capture texture is resident.
    property bool _resizeCaptureLive: false
    property int _activeCaptureSlot: 0
    property int _primingCaptureSlot: -1
    property size _captureSizeA: Qt.size(0, 0)
    property size _captureSizeB: Qt.size(0, 0)

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
        if (!root.adaptiveContrastActive || root._contrastClientId >= 0)
            return;
        root._contrastClientId = AdaptiveContrast.registerClient();
    }

    function releaseContrastClient() {
        contrastThrottle.stop();
        backdropSettle.stop();
        if (root._contrastClientId >= 0) {
            AdaptiveContrast.unregisterClient(root._contrastClientId);
            root._contrastClientId = -1;
        }
        root.clearContrastSample();
    }

    function activeBackdropCapture() {
        return root._activeCaptureSlot === 0 ? backdropCaptureA : backdropCaptureB;
    }

    function desiredBackdropTextureSize() {
        return Qt.size(
            Math.max(1, Math.ceil(blurSource.width)),
            Math.max(1, Math.ceil(blurSource.height))
        );
    }

    function ensureActiveBackdropTextureSize() {
        const desired = root.desiredBackdropTextureSize();
        if (root._activeCaptureSlot === 0) {
            if (root._captureSizeA.width !== desired.width || root._captureSizeA.height !== desired.height)
                root._captureSizeA = desired;
        } else if (root._captureSizeB.width !== desired.width || root._captureSizeB.height !== desired.height) {
            root._captureSizeB = desired;
        }
    }

    // ShaderEffectSource.live=false turns the card crop into a real cache. All
    // ordinary invalidation funnels through the currently selected capture.
    function scheduleBackdropUpdate() {
        const capture = root.activeBackdropCapture();
        if (!root._backdropReady || capture === null || capture.sourceItem === null || capture.live)
            return;
        capture.scheduleUpdate();
    }

    function holdBackdropLiveForResize() {
        if (!root._backdropReady)
            return;

        const capture = root.activeBackdropCapture();
        if (capture === null || capture.sourceItem === null)
            return;

        if (root._primingCaptureSlot >= 0) {
            captureSwapTimer.stop();
            root._primingCaptureSlot = -1;
        }

        // Keep the active slot's allocation fixed while resizing. live=true then
        // changes only the source crop/content instead of reallocating this FBO.
        root.ensureActiveBackdropTextureSize();
        root._resizeCaptureLive = true;
        resizeCaptureSettle.restart();
    }

    function beginBackdropCaptureRebuild() {
        if (!root._backdropReady) {
            root._resizeCaptureLive = false;
            return;
        }

        const capture = root.activeBackdropCapture();
        if (capture === null || capture.sourceItem === null) {
            root._resizeCaptureLive = false;
            return;
        }

        const nextSlot = root._activeCaptureSlot === 0 ? 1 : 0;
        const desired = root.desiredBackdropTextureSize();
        if (nextSlot === 0)
            root._captureSizeA = desired;
        else
            root._captureSizeB = desired;

        // Allocate and populate a fresh target at the settled dimensions while
        // the old one remains the visible source.
        root._primingCaptureSlot = nextSlot;
        captureSwapTimer.restart();
    }

    function finishBackdropCaptureRebuild() {
        if (root._primingCaptureSlot < 0) {
            root._resizeCaptureLive = false;
            return;
        }

        // Switch to the already-populated target, then release the old slot.
        root._activeCaptureSlot = root._primingCaptureSlot;
        root._primingCaptureSlot = -1;
        root._resizeCaptureLive = false;
        root.scheduleBackdropUpdate();
    }

    function backdropCaptureSourceRect(item) {
        if (item === null || !clipContent.visible)
            return Qt.rect(0, 0, 0, 0);

        const _deps = [item.x, item.y, item.width, item.height,
            root.offsetX, root.offsetY, root.hostScale, root.width, root.height,
            root.wallpaperRenderX, root.wallpaperRenderY,
            root.wallpaperRenderWidth, root.wallpaperRenderHeight,
            blurSource.width, blurSource.height];

        const topLeft = blurSource.mapToItem(item, 0, 0);
        const topRight = blurSource.mapToItem(item, blurSource.width, 0);
        const bottomLeft = blurSource.mapToItem(item, 0, blurSource.height);
        const bottomRight = blurSource.mapToItem(item, blurSource.width, blurSource.height);
        const left = Math.min(topLeft.x, topRight.x, bottomLeft.x, bottomRight.x);
        const top = Math.min(topLeft.y, topRight.y, bottomLeft.y, bottomRight.y);
        const right = Math.max(topLeft.x, topRight.x, bottomLeft.x, bottomRight.x);
        const bottom = Math.max(topLeft.y, topRight.y, bottomLeft.y, bottomRight.y);
        return Qt.rect(left, top, Math.max(1, right - left), Math.max(1, bottom - top));
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
        if (!root.adaptiveContrastActive)
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
        if (!root.adaptiveContrastActive || !root.contrastSamplingActive)
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
        if (root.adaptiveContrastActive && root.contrastSamplingActive)
            backdropSettle.restart();
    }

    Component.onCompleted: {
        root._captureSizeA = root.desiredBackdropTextureSize();
        root._backdropReady = true;
        root.ensureContrastClient();
        root.scheduleBackdropUpdate();
    }
    Component.onDestruction: {
        if (root._contrastClientId >= 0)
            AdaptiveContrast.unregisterClient(root._contrastClientId);
    }
    onAdaptiveContrastChanged: {
        if (root.adaptiveContrastActive) {
            root.ensureContrastClient();
            root.scheduleContrastSample();
        } else {
            root.releaseContrastClient();
        }
    }
    onGlassEnabledChanged: {
        if (root.adaptiveContrastActive) {
            root.ensureContrastClient();
            root.scheduleContrastSample();
        } else {
            root.releaseContrastClient();
        }

        if (root.glassEnabled) {
            root.ensureActiveBackdropTextureSize();
        } else {
            resizeCaptureSettle.stop();
            captureSwapTimer.stop();
            root._primingCaptureSlot = -1;
            root._resizeCaptureLive = false;
        }
        root.scheduleBackdropUpdate();
    }

    onContrastSamplingActiveChanged: {
        if (!root.adaptiveContrastActive)
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
        root.scheduleBackdropUpdate();
    }
    onWidthChanged: {
        root.scheduleContrastSample();
        root.holdBackdropLiveForResize();
    }
    onHeightChanged: {
        root.scheduleContrastSample();
        root.holdBackdropLiveForResize();
    }
    onOffsetXChanged: {
        root.scheduleContrastSample();
        root.scheduleBackdropUpdate();
    }
    onOffsetYChanged: {
        root.scheduleContrastSample();
        root.scheduleBackdropUpdate();
    }
    onHostScaleChanged: {
        root.scheduleContrastSample();
        root.holdBackdropLiveForResize();
    }
    onSourceWidthChanged: {
        root.scheduleContrastAfterBackdropSettles();
        root.scheduleBackdropUpdate();
    }
    onSourceHeightChanged: {
        root.scheduleContrastAfterBackdropSettles();
        root.scheduleBackdropUpdate();
    }
    onWallpaperRenderXChanged: {
        root.scheduleContrastAfterBackdropSettles();
        root.scheduleBackdropUpdate();
    }
    onWallpaperRenderYChanged: {
        root.scheduleContrastAfterBackdropSettles();
        root.scheduleBackdropUpdate();
    }
    onWallpaperRenderWidthChanged: {
        root.scheduleContrastAfterBackdropSettles();
        root.scheduleBackdropUpdate();
    }
    onWallpaperRenderHeightChanged: {
        root.scheduleContrastAfterBackdropSettles();
        root.scheduleBackdropUpdate();
    }

    Connections {
        target: root.wallpaperSourceItem
        enabled: root.adaptiveContrastActive && root.wallpaperSourceItem !== null
        function onXChanged() { root.scheduleContrastAfterBackdropSettles(); }
        function onYChanged() { root.scheduleContrastAfterBackdropSettles(); }
        function onWidthChanged() { root.scheduleContrastAfterBackdropSettles(); }
        function onHeightChanged() { root.scheduleContrastAfterBackdropSettles(); }
    }

    // sourceRect depends on capture-item geometry as well as the explicit root
    // properties above. Loader parallax/zoom and fallback Image readiness can
    // therefore invalidate the frozen texture without keeping it live at rest.
    Connections {
        target: root._useSharedBackdrop ? root.wallpaperSourceItem : fallbackBackdrop
        enabled: root._backdropReady && target !== null
        ignoreUnknownSignals: true
        function onXChanged() { root.scheduleBackdropUpdate(); }
        function onYChanged() { root.scheduleBackdropUpdate(); }
        function onWidthChanged() { root.scheduleBackdropUpdate(); }
        function onHeightChanged() { root.scheduleBackdropUpdate(); }
        function onStatusChanged() { root.scheduleBackdropUpdate(); }
    }

    Connections {
        target: AdaptiveContrast
        enabled: root.adaptiveContrastActive
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
        when: root.adaptiveContrastActive && root.contrastHost !== null
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

    Timer {
        id: resizeCaptureSettle
        interval: 80
        repeat: false
        onTriggered: root.beginBackdropCaptureRebuild()
    }

    Timer {
        id: captureSwapTimer
        // The replacement exists only for the resize hand-off. Give it several
        // render opportunities before switching the blur to it.
        interval: 50
        repeat: false
        onTriggered: root.finishBackdropCaptureRebuild()
    }

    // Blur radius ceiling, and how far the blurred layer extends past the widget
    // so the filter has real content to sample at the edges instead of fading
    // into transparency. Full bleed would be _blurMax; two thirds is enough in
    // practice because the outermost ring is under the rounded mask, and it keeps
    // the layer meaningfully smaller.
    readonly property real _blurMax: 96
    readonly property real _blurBleed: Math.ceil(_blurMax * 0.67)
    // Longest edge, in px, used only by the extension/video fallback Image.
    readonly property int _backdropDecodeWidth: 1920

    // Dependency tokens. mapFromItem is a function call, so a binding using it
    // only re-evaluates when some property it *reads* changes. These are read in
    // _backdropRect purely so the crop recomputes as things move.
    property real hostScale: 1
    readonly property bool _useItem: parallaxBackdrop && wallpaperSourceItem !== null && wallpaperSourceItem.width > 0
    readonly property bool _useParallax: !_useItem && parallaxBackdrop && wallpaperRenderWidth > 0 && wallpaperRenderHeight > 0
    // Video wallpapers feed thumbnailPath to widgets while the live wallpaper
    // Loader points at the video path itself. Only share the live source when it
    // represents the same image the widget would otherwise load.
    readonly property bool _useSharedBackdrop: root._useItem
        && root.wallpaperPath !== ""
        && root.wallpaperPath === Config.options.background.wallpaperPath

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
        visible: root.glassEnabled && root.blur > 0.001 && root.wallpaperPath !== ""

        // Keep the blur input widget-sized plus the existing bleed margin. For
        // built-in image wallpapers the input texture now comes from a card-sized
        // ShaderEffectSource crop of Background.qml's already-rendered wallpaper,
        // rather than a second Image object loading wallpaperPath in every widget.
        // The ShaderEffectSource replaces the old blurSource layer FBO; it is not
        // an additional render target. Extensions and video thumbnails retain the
        // old Image path as a compatibility fallback, but that Image has no source
        // while the shared live source is usable.
        Item {
            id: blurSource
            x: -root._blurBleed
            y: -root._blurBleed
            width: root.width + root._blurBleed * 2
            height: root.height + root._blurBleed * 2
            clip: true

            Image {
                id: fallbackBackdrop
                visible: false
                // Keep the exact old geometry for extension widgets and video
                // thumbnail fallback, including live-item placement when present.
                x: root._blurBleed + (root._useItem ? root._backdropRect.x : root._useParallax ? (root.wallpaperRenderX - root.offsetX) : -root.offsetX)
                y: root._blurBleed + (root._useItem ? root._backdropRect.y : root._useParallax ? (root.wallpaperRenderY - root.offsetY) : -root.offsetY)
                width: Math.max(1, root._useItem ? root._backdropRect.width : root._useParallax ? root.wallpaperRenderWidth : root.sourceWidth)
                height: Math.max(1, root._useItem ? root._backdropRect.height : root._useParallax ? root.wallpaperRenderHeight : root.sourceHeight)
                source: !root._useSharedBackdrop && root.glassEnabled && root.wallpaperPath !== ""
                    ? Qt.resolvedUrl(root.wallpaperPath) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                sourceSize.width: root._backdropDecodeWidth
            }

            ShaderEffectSource {
                id: backdropCaptureA
                anchors.fill: parent
                visible: false
                readonly property Item captureItem: root._useSharedBackdrop
                    ? root.wallpaperSourceItem : fallbackBackdrop
                readonly property bool resident:
                    root._activeCaptureSlot === 0 || root._primingCaptureSlot === 0
                sourceItem: clipContent.visible && resident ? captureItem : null
                hideSource: false
                live: sourceItem === null
                    || root._sharedBackdropLive
                    || root._resizeCaptureLive
                    || root._primingCaptureSlot === 0
                recursive: false
                textureSize: sourceItem !== null ? root._captureSizeA : Qt.size(0, 0)
                sourceRect: sourceItem !== null
                    ? root.backdropCaptureSourceRect(captureItem)
                    : Qt.rect(0, 0, 0, 0)
                onSourceItemChanged: {
                    if (root._activeCaptureSlot === 0 && sourceItem !== null) {
                        root.ensureActiveBackdropTextureSize();
                        root.scheduleBackdropUpdate();
                    }
                }
                onLiveChanged: {
                    if (root._activeCaptureSlot === 0 && !live)
                        root.scheduleBackdropUpdate();
                }
            }

            ShaderEffectSource {
                id: backdropCaptureB
                anchors.fill: parent
                visible: false
                readonly property Item captureItem: root._useSharedBackdrop
                    ? root.wallpaperSourceItem : fallbackBackdrop
                readonly property bool resident:
                    root._activeCaptureSlot === 1 || root._primingCaptureSlot === 1
                sourceItem: clipContent.visible && resident ? captureItem : null
                hideSource: false
                live: sourceItem === null
                    || root._sharedBackdropLive
                    || root._resizeCaptureLive
                    || root._primingCaptureSlot === 1
                recursive: false
                textureSize: sourceItem !== null ? root._captureSizeB : Qt.size(0, 0)
                sourceRect: sourceItem !== null
                    ? root.backdropCaptureSourceRect(captureItem)
                    : Qt.rect(0, 0, 0, 0)
                onSourceItemChanged: {
                    if (root._activeCaptureSlot === 1 && sourceItem !== null) {
                        root.ensureActiveBackdropTextureSize();
                        root.scheduleBackdropUpdate();
                    }
                }
                onLiveChanged: {
                    if (root._activeCaptureSlot === 1 && !live)
                        root.scheduleBackdropUpdate();
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: root._activeCaptureSlot === 0 ? backdropCaptureA : backdropCaptureB
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
        visible: root.glassEnabled && clipContent.visible && root.backdropBrightness !== 0
        color: root.backdropBrightness < 0 ? "black" : "white"
        opacity: Math.abs(root.backdropBrightness) * root._scrimMax
    }

    Rectangle {
        anchors.fill: parent
        visible: opacity > 0
        color: "black"
        opacity: root.adaptiveContrastActive ? root.automaticScrimOpacity : 0
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    Rectangle {
        id: tint
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.tintColor
        // With glass disabled this is the only panel background. Keep the
        // configured per-widget tint color and tint amount, but remove the blur
        // attenuation because there is no glass layer to blend against.
        opacity: root.glassEnabled
            ? (1 - root.blur * 0.65) * (Config.options.background.widgetTint ?? 0)
            : (Config.options.background.widgetTint ?? 0)
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
        visible: root.glassEnabled && root.blur > 0.001
    }

    // The rounded-mask layer owns another offscreen texture. Tint-only mode uses
    // the tint Rectangle's radius directly so this FBO can be released as well.
    layer.enabled: root.glassEnabled
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.cornerRadius
        }
    }
}
