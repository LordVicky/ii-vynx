import QtQuick
import qs.services
import "widgets/AdaptiveContrast.js" as AdaptiveContrastMath

Item {
    id: root

    required property real sourceWidth
    required property real sourceHeight

    width: 8
    height: 8
    opacity: 0

    property var _activeRequest: null
    property string _loadedUrl: ""

    function processNext() {
        if (root._activeRequest !== null || !sampleCanvas.available)
            return;

        const request = AdaptiveContrast.takeNextRequest();
        if (request === null)
            return;

        root._activeRequest = request;
        const requestedUrl = String(request.wallpaperUrl);
        if (requestedUrl !== root._loadedUrl) {
            if (root._loadedUrl !== "")
                sampleCanvas.unloadImage(root._loadedUrl);
            root._loadedUrl = requestedUrl;
            sampleCanvas.loadImage(root._loadedUrl);
        }

        if (sampleCanvas.isImageLoaded(root._loadedUrl))
            sampleCanvas.requestPaint();
        else if (sampleCanvas.isImageError(root._loadedUrl))
            root.finishActive(-1);
    }

    function finishActive(luminance) {
        if (root._activeRequest === null)
            return;
        AdaptiveContrast.completeRequest(root._activeRequest.clientId, luminance);
        root._activeRequest = null;
        Qt.callLater(root.processNext);
    }

    Connections {
        target: AdaptiveContrast
        function onWorkAvailable() {
            root.processNext();
        }
    }

    Canvas {
        id: sampleCanvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative

        onAvailableChanged: {
            if (available)
                root.processNext();
        }
        onImageLoaded: {
            if (root._activeRequest !== null && isImageLoaded(root._loadedUrl))
                requestPaint();
            else if (root._activeRequest !== null && isImageError(root._loadedUrl))
                root.finishActive(-1);
        }
        onPaint: {
            const request = root._activeRequest;
            if (request === null || root.sourceWidth <= 0 || root.sourceHeight <= 0) {
                root.finishActive(-1);
                return;
            }

            const crop = AdaptiveContrastMath.coverSourceRect(
                request.normalizedRect,
                request.displaySize.width,
                request.displaySize.height,
                root.sourceWidth,
                root.sourceHeight
            );
            if (crop.width <= 0 || crop.height <= 0) {
                root.finishActive(-1);
                return;
            }

            const context = getContext("2d");
            context.clearRect(0, 0, width, height);
            context.drawImage(root._loadedUrl, crop.x, crop.y, crop.width, crop.height, 0, 0, width, height);
            const pixels = context.getImageData(0, 0, width, height);
            root.finishActive(AdaptiveContrastMath.averageLuminance(pixels.data));
        }
    }
}
