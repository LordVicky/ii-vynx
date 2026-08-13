pragma Singleton

import Quickshell

Singleton {
    id: root

    property int _nextClientId: 1
    property var _pendingByClient: ({})
    property var _pendingOrder: []

    signal workAvailable
    signal sampleReady(int clientId, real luminance)

    function registerClient() {
        return root._nextClientId++;
    }

    function unregisterClient(clientId) {
        delete root._pendingByClient[clientId];
        root._pendingOrder = root._pendingOrder.filter(id => id !== clientId);
    }

    function requestSample(clientId, wallpaperUrl, normalizedRect, displaySize) {
        if (clientId < 0 || wallpaperUrl === "" || !normalizedRect || !displaySize)
            return;

        const alreadyPending = root._pendingByClient[clientId] !== undefined;
        root._pendingByClient[clientId] = {
            clientId,
            wallpaperUrl,
            normalizedRect,
            displaySize
        };
        if (!alreadyPending)
            root._pendingOrder.push(clientId);
        root.workAvailable();
    }

    function takeNextRequest() {
        while (root._pendingOrder.length > 0) {
            const order = root._pendingOrder.slice();
            const clientId = order.shift();
            root._pendingOrder = order;
            const request = root._pendingByClient[clientId];
            delete root._pendingByClient[clientId];
            if (request !== undefined)
                return request;
        }
        return null;
    }

    function completeRequest(clientId, luminance) {
        root.sampleReady(clientId, luminance);
    }
}
