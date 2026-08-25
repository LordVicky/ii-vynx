import QtQuick

// Stable registry proxy for a built-in plugin whose implementation lifetime is
// owned declaratively by Loader. The proxy itself never leaves the registry, so
// Settings, Apps, arbitration and host delegates keep one durable QObject while
// the implementation is loaded/unloaded behind it.
K4Plugin {
    id: root

    required property url source

    readonly property var instance: implementationLoader.item

    instantiated: instance !== null
    active: enabled && instance ? Boolean(instance.active) : false
    priority: instance ? Number(instance.priority) : 50
    transitorio: instance ? Boolean(instance.transitorio) : false

    islandWidth: instance ? Number(instance.islandWidth) : 300
    islandHeight: instance ? Number(instance.islandHeight) : 60
    view: instance ? instance.view : null
    viewLoaded: instance ? Boolean(instance.viewLoaded) : false

    grabKeyboard: instance ? Boolean(instance.grabKeyboard) : false
    optionalKeyboard: instance ? Boolean(instance.optionalKeyboard) : false
    keyboardOnHover: instance ? Boolean(instance.keyboardOnHover) : false

    handlesBackgroundTap: instance ? Boolean(instance.handlesBackgroundTap) : false
    closeOnHoverExit: instance ? Boolean(instance.closeOnHoverExit) : false
    hoverExitDelay: instance ? Number(instance.hoverExitDelay) : 700

    property var implementationLoader: Loader {
        active: root.enabled
        asynchronous: false
        source: root.source

        onStatusChanged: {
            if (status === Loader.Error)
                root.loadError = "Component failed to load"
            else if (status === Loader.Ready)
                root.loadError = ""
        }
    }

    function open() {
        if (instance && typeof instance.open === "function")
            instance.open()
    }

    function openApplication() {
        if (!enabled || !instance || typeof instance.openApplication !== "function")
            return false
        return instance.openApplication() !== false
    }

    function close() {
        if (instance && typeof instance.close === "function")
            instance.close()
    }

    onBackgroundTapped: {
        if (instance && typeof instance.backgroundTapped === "function")
            instance.backgroundTapped()
    }

    onHoverTimedOut: {
        if (instance && typeof instance.hoverTimedOut === "function")
            instance.hoverTimedOut()
    }
}
