pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services
import Quickshell
import QtQuick

/**
 * Lightweight compatibility facade for the Anime/Booru extension.
 *
 * The facade may remain instantiated for the lifetime of the QML engine after its
 * first use, but the provider/request graph lives in BooruRuntime and is destroyed
 * whenever the anime-booru contribution is disabled or removed.
 */
Singleton {
    id: root

    signal tagSuggestion(string query, var suggestions)
    signal responseFinished()

    property var runtime: null
    property bool _syncingResponses: false
    property bool _syncingRunningRequests: false

    // Writable for compatibility with the external extension, which trims the list
    // by assigning Booru.responses directly after a response finishes.
    property var responses: []
    property int runningRequests: 0

    readonly property string currentProvider: Persistent.states.booru.provider
    readonly property var providers: root.runtime ? root.runtime.providers : ({})
    readonly property var providerList: root.runtime ? root.runtime.providerList : []
    readonly property var apiKeys: root.runtime ? root.runtime.apiKeys : ({})
    readonly property var booruResponseDataComponent: root.runtime ? root.runtime.booruResponseDataComponent : null
    readonly property string failMessage: root.runtime ? root.runtime.failMessage : ""

    function _animeBooruEnabled() {
        if (!ExtensionManager.ready)
            return false
        const pages = ExtensionManager.getContributionPoint("sidebarLeftPages")
        return pages.some(page => page.identifier === "anime-booru")
    }

    function _syncFacadeState() {
        root._syncingResponses = true
        root.responses = root.runtime ? root.runtime.responses : []
        root._syncingResponses = false

        root._syncingRunningRequests = true
        root.runningRequests = root.runtime ? root.runtime.runningRequests : 0
        root._syncingRunningRequests = false
    }

    function syncRuntime() {
        const shouldRun = root._animeBooruEnabled()

        if (shouldRun && !root.runtime) {
            const nextRuntime = runtimeComponent.createObject(root)
            if (!nextRuntime) {
                console.warn("[Booru] Failed to create destroyable runtime")
                return
            }
            root.runtime = nextRuntime
            root._syncFacadeState()
            return
        }

        if (!shouldRun && root.runtime) {
            const dyingRuntime = root.runtime
            // Disconnect facade bindings/signals before shutdown mutates runtime state.
            root.runtime = null
            root._syncFacadeState()
            dyingRuntime.shutdown()
            dyingRuntime.destroy()
        }
    }

    onResponsesChanged: {
        if (root._syncingResponses || !root.runtime)
            return
        root.runtime.replaceResponses(root.responses)
    }

    onRunningRequestsChanged: {
        if (root._syncingRunningRequests || !root.runtime)
            return
        root.runtime.runningRequests = root.runningRequests
    }

    Component.onCompleted: root.syncRuntime()

    Connections {
        target: ExtensionManager

        function onRefreshExtensions() { root.syncRuntime() }
        function onExtensionInstalled() { root.syncRuntime() }
        function onExtensionRemoved() { root.syncRuntime() }
        function onExtensionToggled() { root.syncRuntime() }
    }

    Connections {
        target: root.runtime
        ignoreUnknownSignals: true

        function onResponsesChanged() {
            root._syncingResponses = true
            root.responses = root.runtime ? root.runtime.responses : []
            root._syncingResponses = false
        }

        function onRunningRequestsChanged() {
            root._syncingRunningRequests = true
            root.runningRequests = root.runtime ? root.runtime.runningRequests : 0
            root._syncingRunningRequests = false
        }

        function onTagSuggestion(query, suggestions) {
            root.tagSuggestion(query, suggestions)
        }

        function onResponseFinished() {
            root.responseFinished()
        }
    }

    Component {
        id: runtimeComponent
        BooruRuntime {}
    }

    function getWorkingImageSource(url) {
        return root.runtime ? root.runtime.getWorkingImageSource(url) : url
    }

    function setProvider(provider) {
        if (root.runtime)
            root.runtime.setProvider(provider)
    }

    function clearResponses() {
        if (root.runtime)
            root.runtime.clearResponses()
        else
            root.responses = []
    }

    function addResponse(response) {
        if (root.runtime)
            root.runtime.addResponse(response)
    }

    function addSystemMessage(message) {
        if (root.runtime)
            root.runtime.addSystemMessage(message)
    }

    function resetApiKeys(provider) {
        if (root.runtime)
            root.runtime.resetApiKeys(provider)
    }

    function constructRequestUrl(tags, nsfw = true, limit = 20, page = 1) {
        return root.runtime ? root.runtime.constructRequestUrl(tags, nsfw, limit, page) : ""
    }

    function makeRequest(tags, nsfw = false, limit = 20, page = 1) {
        if (root.runtime)
            root.runtime.makeRequest(tags, nsfw, limit, page)
    }

    function triggerTagSearch(query) {
        return root.runtime ? root.runtime.triggerTagSearch(query) : undefined
    }
}
